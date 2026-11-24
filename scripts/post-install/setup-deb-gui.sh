#!/usr/bin/env bash
# setup-deb-gui.sh — أدوات رسومية لتثبيت البرامج على أوبونتو arm64.
#
# يثبّت: GDebi (ملفات .deb)، GNOME Software، Flatpak + Flathub،
#         وأدوات فكّ الأرشيف.
#
# الاستخدام: sudo bash setup-deb-gui.sh

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

hdr "1) تحديث فهرس الحزم"
apt-get update -qq || warn "تعذّر تحديث الفهرس، سنكمل بالفهرس الحالي"

hdr "2) GDebi — تثبيت .deb بالنقر المزدوج"
apt-get install -y --no-install-recommends gdebi gdebi-core \
  || die "فشل تثبيت GDebi"

hdr "3) GNOME Software + Flatpak"
apt-get install -y gnome-software gnome-software-plugin-flatpak flatpak \
  || apt-get install -y gnome-software || warn "تعذّر تثبيت متجر GNOME"

hdr "4) أدوات فكّ الضغط"
apt-get install -y file-roller unzip p7zip-full || warn "بعض أدوات الأرشيف لم تُثبَّت"

hdr "5) ربط صيغة .deb بـ GDebi"
while IFS=: read -r u _ uid _ _ h _; do
  [ "$uid" -ge 1000 ] 2>/dev/null && [ "$uid" -lt 65534 ] || continue
  [ -d "$h" ] || continue
  sudo -u "$u" XDG_DATA_HOME="$h/.local/share" \
    xdg-mime default gdebi.desktop application/vnd.debian.binary-package 2>/dev/null \
    && ok "$u: .deb → GDebi" || warn "$u: تعذّر الربط (اضبطه يدوياً)"
done < /etc/passwd

hdr "6) التحقق"
for c in gdebi gdebi-gtk gnome-software flatpak; do
  command -v "$c" >/dev/null && ok "$c مثبّت" || warn "$c غير موجود"
done

hdr "7) إضافة Flathub"
flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null \
  && ok "Flathub مضاف" || warn "تعذّر إضافة Flathub (قد يكون مضافاً)"

info "تحذير: تنزيل Flatpak على هذا الجهاز بطيء جداً — نزّل الحزم على حاسوبك"
info "ثم انقلها:  scp app.flatpak user@nabu.local:~/  ثم  flatpak install --user app.flatpak"
