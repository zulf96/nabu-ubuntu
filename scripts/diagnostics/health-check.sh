#!/usr/bin/env bash
# health-check.sh — فحص شامل لصحة النظام على Xiaomi Pad 5 (nabu).
#
# الاستخدام:
#   sudo bash health-check.sh              # فحص كامل
#   sudo bash health-check.sh --charging   # قسم الشحن فقط (تفصيلي)
#   sudo bash health-check.sh --ufs        # فحص سرعة التخزين (يكتب ملفاً مؤقتاً)
#
# السكربت للقراءة فقط: لا يعدّل أي إعداد.

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

MODE="all"
UFS_TEST=0
for arg in "$@"; do
  case "$arg" in
    --charging) MODE="charging" ;;
    --ufs)      UFS_TEST=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "خيار غير معروف: $arg" ;;
  esac
done

require_root

FAILURES=0
note_fail() { FAILURES=$((FAILURES + 1)); }

# ─────────────────────────── الهوية ───────────────────────────
section_identity() {
  hdr "الجهاز والنظام"
  info "الطراز:      $(device_model)"
  if is_nabu; then ok "nabu (Xiaomi Pad 5)"; else warn "ليس nabu — بعض الفحوص غير منطبقة"; fi
  info "التوزيعة:    $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-?}")"
  info "النواة:      $(uname -r)"
  info "المعمارية:   $(uname -m)"
  info "مدة التشغيل: $(uptime -p 2>/dev/null)"
  info "سطر الأوامر: $(cat /proc/cmdline)"
}

# ─────────────────────────── الشحن ───────────────────────────
section_charging() {
  hdr "الشحن و USB-C"

  local tdev; tdev=$(typec_device)
  if [ -z "$tdev" ]; then
    bad "لم أجد جهاز typec في /sys/bus/platform/devices"
    note_fail
  elif typec_bound; then
    ok "typec مربوطة ($(basename "$tdev"))"
  else
    bad "typec غير مربوطة — الشحن لن يعمل"
    info "الحل: على 6.14.11 تأكد من fw_devlink=off ثم أعد التشغيل."
    note_fail
  fi

  info "منافذ typec: [$(ls /sys/class/typec/ 2>/dev/null | tr '\n' ' ')]"
  if [ -d /sys/class/typec/port0 ]; then
    info "power_role: $(cat /sys/class/typec/port0/power_role 2>/dev/null)"
    info "mode:       $(cat /sys/class/typec/port0/power_operation_mode 2>/dev/null)"
    [ -e /sys/class/typec/port0-partner ] && ok "شريك USB-C متصل" || info "لا شريك (لا شاحن)"
  fi

  if [ -r /sys/kernel/debug/devices_deferred ]; then
    local deferred; deferred=$(cat /sys/kernel/debug/devices_deferred 2>/dev/null)
    if [ -z "$deferred" ]; then ok "devices_deferred فارغ"
    else bad "أجهزة مؤجَّلة:"; printf '%s\n' "$deferred" | sed 's/^/      /'; note_fail; fi
  fi

  local chg; chg=$(detect_charger)
  local bat; bat=$(battery_dir)
  if [ -n "$chg" ]; then
    info "مُقرِّر الشحن: $chg"
    printf '      %-14s %s\n' \
      "status:"   "$(cat "/sys/class/power_supply/$chg/status" 2>/dev/null)" \
      "online:"   "$(cat "/sys/class/power_supply/$chg/online" 2>/dev/null)" \
      "usb_type:" "$(cat "/sys/class/power_supply/$chg/usb_type" 2>/dev/null)" \
      "current_max:" "$(cat "/sys/class/power_supply/$chg/current_max" 2>/dev/null)" \
      "current_now:" "$(cat "/sys/class/power_supply/$chg/current_now" 2>/dev/null)"
  else
    bad "لم أجد مُقرِّر شحن"; note_fail
  fi

  if [ -n "$bat" ]; then
    local cap status cur vol tmp
    cap=$(cat "$bat/capacity" 2>/dev/null)
    status=$(cat "$bat/status" 2>/dev/null)
    cur=$(cat "$bat/current_now" 2>/dev/null)
    vol=$(cat "$bat/voltage_now" 2>/dev/null)
    tmp=$(cat "$bat/temp" 2>/dev/null)
    info "البطارية: ${cap}% | $status | ${cur}µA | $(( ${vol:-0} / 1000 ))mV | $(( ${tmp:-0} / 10 ))°C"
    if [ "${cap:-0}" -ge 99 ] && [ "$status" = "Full" ]; then
      info "ملاحظة: ممتلئة — التيار القريب من الصفر طبيعي."
    fi
  fi

  ok "ملخص: $( [ -n "$chg" ] && cat "/sys/class/power_supply/$chg/online" 2>/dev/null || echo 0 ) (1 = شاحن موصول)"
}

# ─────────────────────────── الإقلاع ───────────────────────────
section_boot() {
  hdr "الإقلاع و ESP"
  local mnt; mnt=$(mount_esp)
  if [ -z "$mnt" ]; then warn "تعذّر تركيب ESP (قد يكون غير مركّب)"; return; fi
  info "ESP على: $mnt"
  [ -f "$mnt/EFI/BOOT/refind.conf" ] && ok "refind.conf موجود" || { bad "refind.conf مفقود"; note_fail; }
  info "النوى: $(ls "$mnt/EFI/Ubuntu"/*.efi 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')"
  local def; def=$(grep -E '^default_selection' "$mnt/EFI/BOOT/refind.conf" 2>/dev/null | tail -1)
  [ -n "$def" ] && info "الافتراضية: ${def#default_selection }"
  [ -f "$mnt/EFI/android/Reboot2Android.efi" ] && ok "مدخل أندرويد موجود" || warn "مدخل أندرويد غير مثبَّت"
}

# ─────────────────────────── الشبكة ───────────────────────────
section_network() {
  hdr "الشبكة"
  if command -v nmcli >/dev/null; then
    local state conn
    state=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2=="wifi"{print $3; exit}')
    conn=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1; exit}')
    [ "$state" = "connected" ] && ok "واي فاي متصل: ${conn:-?}" || warn "واي فاي: ${state:-غير معروف}"
    info "العنوان: $(ip -br addr show 2>/dev/null | awk '$1!="lo"{printf "%s ", $3}')"
    info "mDNS: $(getent ahostsv4 "$(hostname).local" 2>/dev/null | awk 'NR==1{print $1}')"
  else
    warn "nmcli غير متوفر"
  fi
}

# ─────────────────────────── الصوت والإدخال ───────────────────────────
section_audio_input() {
  hdr "الصوت والإدخال"
  if command -v aplay >/dev/null; then
    local cards; cards=$(aplay -l 2>/dev/null | grep -c '^card')
    [ "${cards:-0}" -gt 0 ] && ok "بطاقات صوت: $cards" || warn "لا بطاقات صوت"
  else
    warn "alsa-utils غير مثبّت (apt install alsa-utils)"
  fi
  local inputs
  inputs=$(grep -h . /sys/class/input/input*/name 2>/dev/null | sed 's/^input[0-9]*\/name://' | sort -u | tr '\n' ',')
  info "أجهزة الإدخال: $inputs"
  for dev in NVTCapacitiveTouchScreen "Xiaomi Pad Keyboard" NVTCapacitivePen; do
    printf '%s' "$inputs" | grep -q "$dev" && ok "$dev" || warn "$dev غير موجود"
  done
}

# ─────────────────────────── الحرارة والخدمات ───────────────────────────
section_health() {
  hdr "الحرارة والخدمات"
  local max=0 t
  for z in /sys/class/thermal/thermal_zone*/temp; do
    t=$(cat "$z" 2>/dev/null || echo 0)
    [ "$t" -gt "$max" ] 2>/dev/null && max=$t
  done
  if [ "$max" -gt 60000 ]; then warn "أعلى حرارة: $((max / 1000))°C"
  else ok "أعلى حرارة: $((max / 1000))°C"; fi

  local failed; failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
  [ "${failed:-0}" -eq 0 ] && ok "لا خدمات فاشلة" || { warn "$failed خدمة فاشلة"; systemctl --failed --no-legend | sed 's/^/      /'; }

  local oops; oops=$(dmesg 2>/dev/null | grep -c 'Unable to handle')
  [ "${oops:-0}" -eq 0 ] && ok "لا أخطاء Oops منذ الإقلاع" || warn "$oops خطأ Oops في السجل"
}

# ─────────────────────────── التخزين ───────────────────────────
section_storage() {
  hdr "التخزين"
  info "$(df -h / 2>/dev/null | tail -1 | awk '{printf "الجذر: %s مستخدم من %s (%s)", $3, $2, $5}')"
  if [ "$UFS_TEST" -eq 1 ]; then
    local f=/tmp/.nabu-ufs-test
    info "اختبار كتابة/قراءة 200MB..."
    local w r
    w=$(dd if=/dev/zero of="$f" bs=1M count=200 conv=fdatasync 2>&1 | tail -1 | grep -oE '[0-9.]+ [GM]B/s' || echo "?")
    sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    r=$(dd if="$f" of=/dev/null bs=1M iflag=direct 2>&1 | tail -1 | grep -oE '[0-9.]+ [GM]B/s' || echo "?")
    rm -f "$f"
    ok "كتابة: $w | قراءة: $r"
  else
    info "(أضف --ufs لقياس سرعة التخزين)"
  fi
}

# ─────────────────────────── التنفيذ ───────────────────────────
case "$MODE" in
  charging)
    section_identity
    section_charging
    ;;
  all)
    section_identity
    section_charging
    section_boot
    section_network
    section_audio_input
    section_health
    section_storage
    ;;
esac

hdr "الخلاصة"
if [ "$FAILURES" -eq 0 ]; then
  ok "كل الفحوص الحرجة سليمة."
else
  bad "$FAILURES مشكلة حرجة — راجع docs/06-charging.md و docs/07-troubleshooting.md"
fi
exit 0
