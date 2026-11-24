#!/usr/bin/env bash
# typec-watchdog.sh — فحص حالة typec (قراءة فقط).
#
# ⚠️ هذا السكربت **لا يحاول** إعادة ربط (bind/unbind) أي مُقرِّر:
#    - إعادة ربط typec يدوياً ترجع EAGAIN ولا تنجح.
#    - إعادة ربط ln8000_charger **تُسقط النواة** (Oops في مسار remove).
#    الحل الحقيقي: إعادة تشغيل، أو استخدام نواة 6.17.0.
#
# الاستخدام:
#   bash typec-watchdog.sh           # فحص مرة واحدة (+ كود خروج)
#   bash typec-watchdog.sh --service # للاستخدام مع systemd timer (تسجيل فقط)
#
# كود الخروج: 0 = سليم، 1 = typec غير مربوطة، 2 = لا يوجد جهاز typec.

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

SERVICE=0
[ "${1:-}" = "--service" ] && SERVICE=1

log() {
  if command -v logger >/dev/null; then logger -t typec-watchdog -- "$*"; fi
  printf '%s %s\n' "$(date '+%F %T')" "$*"
}

tdev=$(typec_device)
if [ -z "$tdev" ]; then
  log "FAIL: لم أجد جهاز typec على الناقل — عادةً يعني أن النواة لا تُنشئه."
  exit 2
fi

if typec_bound && [ -d /sys/class/typec/port0 ]; then
  log "OK: typec مربوطة ($(basename "$tdev")) والمنفذ port0 ظاهر."
  [ "$SERVICE" -eq 1 ] && exit 0
  echo
  info "power_role: $(cat /sys/class/typec/port0/power_role 2>/dev/null)"
  info "mode:       $(cat /sys/class/typec/port0/power_operation_mode 2>/dev/null)"
  info "partner:    $([ -e /sys/class/typec/port0-partner ] && echo موجود || echo 'لا يوجد (لا شاحن)')"
  exit 0
fi

log "PROBLEM: typec غير مربوطة (driver=$(readlink -f "$tdev/driver" 2>/dev/null || echo none))."
if [ -r /sys/kernel/debug/devices_deferred ]; then
  log "devices_deferred: $(tr '\n' ' ' < /sys/kernel/debug/devices_deferred)"
fi
log "الحل: أعد التشغيل. على 6.14.11 تحقّق أولاً من fw_devlink=off في /proc/cmdline."
log "لا تحاول unbind/bind يدوياً — ln8000 يُسقط النواة."
exit 1
