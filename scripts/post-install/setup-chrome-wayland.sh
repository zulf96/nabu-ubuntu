#!/usr/bin/env bash
# setup-chrome-wayland.sh — تشغيل متصفح Chromium/Chrome على Wayland مع IME.
#
# لماذا؟ على Wayland يحتاج المتصفح إلى:
#   --ozone-platform=wayland   (رسم أصلي، أسرع وأخف من XWayland)
#   --enable-wayland-ime       (ضروري لعمل لوحة المفاتيح العربية داخل المتصفح)
#
# الاستخدام:
#   bash setup-chrome-wayland.sh            # يعدّل مُشغّلات المستخدم الحالي
#   bash setup-chrome-wayland.sh --revert   # يحذف التعديلات
#   bash setup-chrome-wayland.sh --user zulf

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

REVERT=0
USER_NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --revert) REVERT=1 ;;
    --user) shift; USER_NAME="${1:-}" ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
  shift
done
[ -n "$USER_NAME" ] || USER_NAME=$(target_user)
UHOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
[ -d "$UHOME" ] || die "منزل المستخدم غير موجود: $UHOME"

APPS="$UHOME/.local/share/applications"
ENTRIES=$(grep -rlE '^Exec=.*(chromium|google-chrome|brave-browser)' \
          /usr/share/applications "$APPS" 2>/dev/null || true)

if [ -z "$ENTRIES" ]; then
  warn "لم أجد ملف .desktop لأي متصفح Chromium/Chrome/Brave."
  info "ثبّت أولاً: sudo apt install chromium-browser"
  exit 1
fi

mkdir -p "$APPS"

if [ "$REVERT" -eq 1 ]; then
  hdr "إزالة التعديلات"
  n=0
  for e in $ENTRIES; do
    base=$(basename "$e")
    if [ -f "$APPS/$base" ]; then rm -f "$APPS/$base"; n=$((n+1)); fi
  done
  ok "أُزيل $n ملف(ات) تجاوز — عادت الإعدادات الأصلية"
  update-desktop-database "$APPS" 2>/dev/null || true
  exit 0
fi

hdr "إضافة أعلام Wayland + IME"
for e in $ENTRIES; do
  base=$(basename "$e")
  # استخدم ملف التجاوز الخاص بالمستخدم بدل تعديل ملفات النظام
  awk -v flags="--ozone-platform=wayland --enable-wayland-ime" '
    BEGIN { done=0 }
    /^Exec=/ && !done {
      line=$0
      sub(/^Exec=/, "", line)
      print "Exec=" line " " flags
      done=1
      next
    }
    { print }
  ' "$e" > "$APPS/$base"
  ok "$base"
done
update-desktop-database "$APPS" 2>/dev/null || true

hdr "ملاحظات"
info "إن تعطّل المتصفح: شغّله من الطرفية لرؤية الخطأ، أو:"
info "  bash setup-chrome-wayland.sh --revert"
info "الأعلام المضافة: --ozone-platform=wayland --enable-wayland-ime"
