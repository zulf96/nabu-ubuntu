#!/usr/bin/env bash
# install-charge-log.sh — تثبيت مسجّل دائم لحالة الشحن (سطر كل دقيقة).
#
# يكتب إلى /var/log/nabu-charge.csv بالحقول:
#   ts,cap,status,ibat_ma,vbat_mv,chg_name,chg_status,chg_online,chg_type,typec_partner
#
# يعمل تلقائياً بعد كل إقلاع عبر systemd timer.
#
# الاستخدام:
#   sudo bash install-charge-log.sh            # تثبيت/تحديث
#   sudo bash install-charge-log.sh --remove   # إزالة
#
# صُمِّم ليعمل على النواتين (يكتشف pm8150b أو ln8000 تلقائياً).

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

require_root

BIN=/usr/local/bin/nabu-charge-log.sh
SVC=/etc/systemd/system/nabu-charge-log.service
TMR=/etc/systemd/system/nabu-charge-log.timer
LOG=/var/log/nabu-charge.csv

if [ "${1:-}" = "--remove" ]; then
  hdr "إزالة مسجّل الشحن"
  systemctl disable --now nabu-charge-log.timer 2>/dev/null || true
  rm -f "$SVC" "$TMR" "$BIN"
  systemctl daemon-reload
  ok "أُزيلت الخدمة (السجل $LOG تُرك كما هو)"
  exit 0
fi

[ -e /sys/class/power_supply ] || die "لا يوجد /sys/class/power_supply — هل هذا جهاز nabu؟"

hdr "1) كتابة المسجّل في $BIN"
cat > "$BIN" <<'LOGGER'
#!/bin/sh
# nabu-charge-log.sh — يُنفَّذ كل دقيقة بواسطة systemd timer.
LOG=/var/log/nabu-charge.csv
PS=/sys/class/power_supply
[ -f "$LOG" ] || echo "ts,cap,status,ibat_ma,vbat_mv,chg_name,chg_status,chg_online,chg_type,typec_partner" > "$LOG"

cap=$(cat "$PS/qcom-battery/capacity" 2>/dev/null)
st=$(cat "$PS/qcom-battery/status" 2>/dev/null)
i=$(( $(cat "$PS/qcom-battery/current_now" 2>/dev/null || echo 0) / 1000 ))
v=$(( $(cat "$PS/qcom-battery/voltage_now" 2>/dev/null || echo 0) / 1000 ))

chg=""
for d in pm8150b-charger ln8000-charger; do
  [ -e "$PS/$d" ] && { chg=$d; break; }
done
if [ -z "$chg" ]; then
  for d in "$PS"/*; do
    [ "$(cat "$d/type" 2>/dev/null)" = "USB" ] && { chg=$(basename "$d"); break; }
  done
fi

cs=$(tr -d ' ' < "$PS/$chg/status" 2>/dev/null)
co=$(cat "$PS/$chg/online" 2>/dev/null)
ct=$(tr ',' ' ' < "$PS/$chg/usb_type" 2>/dev/null)
tp=$(ls /sys/class/typec/ 2>/dev/null | grep -c partner)

echo "$(date +%FT%T),$cap,$st,$i,$v,$chg,$cs,$co,$ct,$tp" >> "$LOG"
LOGGER
chmod 755 "$BIN"
ok "المسجّل جاهز"

hdr "2) وحدة systemd + مؤقّت"
cat > "$SVC" <<'UNIT'
[Unit]
Description=Nabu charging diagnostics logger
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nabu-charge-log.sh
UNIT

cat > "$TMR" <<'UNIT'
[Unit]
Description=Run nabu charging logger every minute

[Timer]
OnBootSec=45
OnUnitActiveSec=60
AccuracySec=10

[Install]
WantedBy=timers.target
UNIT

hdr "3) التفعيل"
systemctl daemon-reload
systemctl enable --now nabu-charge-log.timer \
  && ok "nabu-charge-log.timer يعمل" || warn "تعذّر تفعيل المؤقّت"

# سطر أولي فوري
"$BIN" && ok "أُضيف سطر أولي إلى $LOG"

hdr "التحقق"
systemctl status nabu-charge-log.timer --no-pager 2>/dev/null | head -5
info "السجل: $LOG"
info "آخر الأسطر:"
tail -3 "$LOG" 2>/dev/null | sed 's/^/      /'
info "للتحليل:  bash scripts/diagnostics/charge-report.sh"
