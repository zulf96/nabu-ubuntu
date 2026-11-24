#!/usr/bin/env bash
# set-default-kernel.sh — تغيير النواة الافتراضية في قائمة rEFInd بأمان.
#
# يعدّل default_selection فقط، ويأخذ نسخة احتياطية من refind.conf قبل التعديل.
#
# الاستخدام:
#   sudo bash set-default-kernel.sh 6.17.0
#   sudo bash set-default-kernel.sh 6.14.11
#   sudo bash set-default-kernel.sh --list
#
# ملاحظة: القيمة تُطابَق جزئياً باسم ملف النواة (6.17.0 يطابق
# 6.17.0-UFS-slowdown+.efi).

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

require_root

mnt=$(mount_esp) || die "تعذّر تركيب ESP. اكتشف القسم: lsblk -o NAME,PARTLABEL"
CONF="$mnt/EFI/BOOT/refind.conf"
[ -f "$CONF" ] || die "refind.conf غير موجود في $mnt/EFI/BOOT/"

list_kernels() {
  hdr "النوى المتاحة في $mnt/EFI/Ubuntu"
  local f
  for f in "$mnt"/EFI/Ubuntu/*.efi; do
    [ -e "$f" ] || continue
    # تجاهل النسخ الاحتياطية
    case "$(basename "$f")" in *.bak*|*.orig) continue ;; esac
    info "$(basename "$f" .efi)"
  done
  local cur
  cur=$(grep -E '^default_selection' "$CONF" 2>/dev/null | tail -1 | sed 's/^default_selection[[:space:]]*//')
  echo
  info "الافتراضية الحالية: ${cur:-غير محدّدة}"
}

if [ "${1:-}" = "--list" ] || [ $# -eq 0 ]; then
  list_kernels
  [ $# -eq 0 ] && { echo; info "الاستخدام: sudo bash $0 <إصدار النواة>"; }
  exit 0
fi

case "$1" in -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

KERNEL="$1"

# تحقق من وجود نواة مطابقة
MATCH=""
for f in "$mnt"/EFI/Ubuntu/*.efi; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in *.bak*|*.orig) continue ;; esac
  case "$(basename "$f" .efi)" in
    *"$KERNEL"*) MATCH=$(basename "$f" .efi); break ;;
  esac
done
[ -n "$MATCH" ] || { bad "لا توجد نواة مطابقة لـ «$KERNEL» في EFI/Ubuntu"; list_kernels; exit 1; }

hdr "تغيير النواة الافتراضية"
info "القيمة المطلوبة: $KERNEL"
info "أقرب مطابقة:    $MATCH"

STAMP=$(date +%Y%m%d%H%M%S)
BAK="$CONF.bak.$STAMP"
cp -a "$CONF" "$BAK" || die "فشل أخذ النسخة الاحتياطية"
ok "نسخة احتياطية: $BAK"

TMP=$(mktemp)
awk -v k="$KERNEL" '
  /^default_selection/ { if (!done) { print "default_selection " k; done=1 } ; next }
  { print }
  END { if (!done) print "default_selection " k }
' "$CONF" > "$TMP" || { rm -f "$TMP"; die "فشل التعديل"; }

# تحقّق قبل الاستبدال
grep -qE "^default_selection[[:space:]]+$KERNEL" "$TMP" \
  || { rm -f "$TMP"; die "النتيجة غير متوقّعة — أُلغي التعديل"; }

cat "$TMP" > "$CONF"
rm -f "$TMP"
sync

hdr "النتيجة"
grep -nE '^default_selection' "$CONF" | sed 's/^/      /'
if [ "$(grep -cE '^default_selection' "$CONF")" -gt 1 ]; then
  warn "يوجد أكثر من سطر default_selection — rEFInd يستخدم الأخير"
fi
ok "تم. أعد التشغيل لتجربة النواة الجديدة: sudo reboot"
info "للعودة: sudo bash $0 <النواة السابقة>  أو  cp \"$BAK\" \"$CONF\""
