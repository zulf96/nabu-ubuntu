#!/usr/bin/env bash
# setup-arabic.sh — إضافة اللغة العربية والخطوط وتخطيط لوحة المفاتيح.
#
# الهدف: قراءة وكتابة عربية كاملة، مع إبقاء واجهة النظام إنجليزية
# (لتفادي مشاكل اتجاه الواجهة في بعض التطبيقات).
#
# الاستخدام:
#   sudo bash setup-arabic.sh
#   sudo bash setup-arabic.sh --user zulf     # لمستخدم غير الحالي
#
# يعمل على أوبونتو 24.04+ (GNOME/Wayland). للقراءة/الكتابة فقط.

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

require_root

USER_NAME=""
for arg in "$@"; do
  case "$arg" in
    --user) shift; USER_NAME="${1:-}"; [ -n "$USER_NAME" ] || die "استخدم: --user <name>" ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done
[ -n "$USER_NAME" ] || USER_NAME=$(target_user)
getent passwd "$USER_NAME" >/dev/null || die "المستخدم غير موجود: $USER_NAME"

UHOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
UUID_N=$(id -u "$USER_NAME")
BUS="unix:path=/run/user/${UUID_N}/bus"

as_user() {
  sudo -u "$USER_NAME" env \
    DBUS_SESSION_BUS_ADDRESS="$BUS" \
    XDG_RUNTIME_DIR="/run/user/${UUID_N}" \
    HOME="$UHOME" "$@"
}

export DEBIAN_FRONTEND=noninteractive

hdr "1) حزم اللغة العربية"
apt-get install -y language-pack-ar language-pack-ar-base \
                   language-pack-gnome-ar language-pack-gnome-ar-base \
  || die "فشل تثبيت حزم اللغة"

hdr "2) الخطوط العربية"
apt-get install -y fonts-kacst fonts-hosny-amiri fonts-sil-scheherazade \
                   fonts-noto-core fonts-noto-color-emoji || warn "بعض الخطوط لم تُثبَّت"

hdr "3) حزم الدعم الإضافية (تدقيق إملائي، قواميس)"
extra=$(check-language-support -l ar 2>/dev/null || true)
if [ -n "$extra" ]; then
  # shellcheck disable=SC2086
  apt-get install -y $extra || warn "بعض حزم الدعم لم تُثبَّت"
else
  info "لا توجد حزم دعم إضافية"
fi

hdr "4) توليد locales العربية"
for L in ar_SA.UTF-8 ar_EG.UTF-8 ar_AE.UTF-8; do
  if grep -qE "^[#[:space:]]*${L}[[:space:]]+UTF-8" /etc/locale.gen 2>/dev/null; then
    sed -i "s|^#*[[:space:]]*${L}[[:space:]]\+UTF-8|${L} UTF-8|" /etc/locale.gen
  else
    echo "${L} UTF-8" >> /etc/locale.gen
  fi
done
locale-gen 2>&1 | tail -5

hdr "5) تخطيط لوحة المفاتيح العربي في GNOME"
current=$(as_user gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || echo "[]")
info "الحالي: $current"

if printf '%s' "$current" | grep -q "'ara'"; then
  ok "العربية موجودة مسبقاً"
else
  case "$current" in
    "@as []"|"[]"|"") new="[('xkb', 'ara')]" ;;
    *) new=$(printf '%s' "$current" | sed "s/\]$/, ('xkb', 'ara')]/") ;;
  esac
  as_user gsettings set org.gnome.desktop.input-sources sources "$new" \
    && ok "أُضيف تخطيط ara" || warn "تعذّر تعديل gsettings (هل الحصة الرسومية تعمل؟)"
  info "الجديد: $(as_user gsettings get org.gnome.desktop.input-sources sources 2>/dev/null)"
fi

hdr "6) مفاتيح التبديل (Super+Space افتراضياً في GNOME)"
as_user gsettings get org.gnome.desktop.wm.keybindings switch-input-source 2>/dev/null
as_user gsettings get org.gnome.desktop.wm.keybindings switch-input-source-backward 2>/dev/null

hdr "7) التحقق"
info "locales عربية: $(locale -a 2>/dev/null | grep -ci '^ar')"
info "عدد الخطوط العربية: $(fc-list :lang=ar 2>/dev/null | wc -l)"
info "تخطيطات لوحة المفاتيح: $(as_user gsettings get org.gnome.desktop.input-sources sources 2>/dev/null)"

if [ "$(locale -a 2>/dev/null | grep -ci '^ar')" -gt 0 ] \
   && [ "$(fc-list :lang=ar 2>/dev/null | wc -l)" -gt 0 ]; then
  ok "اللغة العربية جاهزة — بدّل بـ Super+Space"
else
  warn "تحقّق يدوياً: locale -a | grep ar  و  fc-list :lang=ar"
fi
