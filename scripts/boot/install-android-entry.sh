#!/usr/bin/env bash
# install-android-entry.sh — إضافة مدخل «Reboot to Android» إلى rEFInd.
#
# ينسخ Reboot2Android.efi إلى ESP ويضيف menuentry إن لم يكن موجوداً.
# يأخذ نسخة احتياطية من refind.conf قبل أي تعديل.
#
# الاستخدام:
#   sudo bash install-android-entry.sh
#   sudo bash install-android-entry.sh --check   # فحص فقط، بلا تعديل

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

require_root

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

SRC="$SCRIPT_DIR/Reboot2Android.efi"
[ -f "$SRC" ] || die "ملف Reboot2Android.efi غير موجود بجانب السكربت ($SRC)"

mnt=$(mount_esp) || die "تعذّر تركيب ESP"
CONF="$mnt/EFI/BOOT/refind.conf"
[ -f "$CONF" ] || die "refind.conf غير موجود في $mnt/EFI/BOOT/"

hdr "فحص الحالة الحالية"
if [ -f "$mnt/EFI/android/Reboot2Android.efi" ]; then
  ok "الملف موجود: EFI/android/Reboot2Android.efi"
else
  warn "الملف غير موجود: EFI/android/Reboot2Android.efi"
fi

if grep -qE 'Reboot2Android\.efi' "$CONF"; then
  ok "المدخل موجود في refind.conf"
  grep -nE -A3 'Reboot2Android\.efi' "$CONF" | sed 's/^/      /'
  [ "$CHECK" -eq 1 ] && exit 0
else
  warn "المدخل غير موجود في refind.conf"
  [ "$CHECK" -eq 1 ] && { info "شغّل بلا --check لإضافته"; exit 0; }
fi

if [ "$CHECK" -eq 1 ]; then exit 0; fi

hdr "نسخ الملف إلى ESP"
mkdir -p "$mnt/EFI/android"
cp -f "$SRC" "$mnt/EFI/android/Reboot2Android.efi" || die "فشل النسخ"
chmod 644 "$mnt/EFI/android/Reboot2Android.efi" 2>/dev/null || true
ok "نُسخ Reboot2Android.efi"

if grep -qE 'Reboot2Android\.efi' "$CONF"; then
  ok "المدخل موجود مسبقاً — لم أعدّل refind.conf"
else
  hdr "إضافة menuentry"
  STAMP=$(date +%Y%m%d%H%M%S)
  BAK="$CONF.bak.$STAMP"
  cp -a "$CONF" "$BAK" || die "فشل النسخة الاحتياطية"
  ok "نسخة احتياطية: $BAK"

  # أيقونة اختيارية إن وُجدت
  ICON_LINE=""
  [ -f "$mnt/EFI/BOOT/icons/os_android.png" ] && ICON_LINE='    icon /EFI/BOOT/icons/os_android.png'

  {
    echo ""
    echo "# --- Dual boot: Android entry (DBPK bootmanager mode) ---"
    echo 'menuentry "Reboot to Android" {'
    [ -n "$ICON_LINE" ] && echo "$ICON_LINE"
    echo '    loader /EFI/android/Reboot2Android.efi'
    echo '}'
  } >> "$CONF"

  sync
  hdr "النتيجة"
  tail -8 "$CONF" | sed 's/^/      /'
  ok "أُضيف المدخل"
fi

info "أعد التشغيل ثم اختر «Reboot to Android» من قائمة rEFInd."
info "إن لم يُقلع أندرويد: أعد sideload لـ installer_bootmanager_NOSB.zip من TWRP."
