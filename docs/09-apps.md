# 09 — التطبيقات على arm64

الجهاز **arm64**، وليس كل برنامج له نسخة. هذا المستند يوفّر الوقت: ما يعمل،
ما لا يعمل، وكيف تتعامل مع كل نوع حزمة.

## 1. أنواع الحزم وترتيب التفضيل

| النوع | الأفضلية | كيف |
|---|---|---|
| `.deb` من مستودع أوبونتو | ⭐⭐⭐ | `sudo apt install pkg` |
| Flatpak (arm64) | ⭐⭐ | `flatpak install ...` |
| Snap | ⭐⭐ | `snap install ...` |
| AppImage (aarch64) | ⭐ | `chmod +x` + Gear Lever |
| `.deb` خارجي | ⭐ | `sudo gdebi file.deb` |
| مصدر (compile) | ✗ غالباً | يحتاج `build-essential` + وقت طويل |

**قاعدة ذهبية:** تحقّق من المعمارية قبل التنزيل:

```bash
dpkg --print-architecture          # arm64
dpkg -I file.deb | grep Architecture
file App.AppImage                  # يجب أن يظهر aarch64 / ARM
```

## 2. ما جُرِّب ويعمل

| التطبيق | الطريقة |
|---|---|
| Chromium | `sudo apt install chromium-browser` |
| Brave (arm64) | مستودع Brave الرسمي |
| LibreOffice | `sudo apt install libreoffice` |
| GIMP / Krita | `sudo apt install gimp krita` |
| Blender | `sudo apt install blender` |
| VLC | `sudo apt install vlc` |
| Telegram | `sudo snap install telegram-desktop` |
| LocalSend | `sudo snap install localsend` |
| VS Code | حزمة `.deb` arm64 من Microsoft |
| Godot | ثنائيات arm64 (مثل `TheMojoMan/godot-arm64`) |
| GDebi / Synaptic / Discover | لتثبيت البرامج رسومياً |
| BleachBit | تنظيف النظام |
| Warehouse / Gear Lever / Papers | Flatpak arm64 (نُقلت يدوياً) |

## 3. ما لا يعمل (أو يحتاج حلولاً)

| الحالة | السبب | البديل |
|---|---|---|
| **WoeUSB-ng** | فشل البناء: لا مُترجِم C، ومكتبات wxWidgets ناقصة، وصلاحيات `/usr/local/bin` | لا بديل مباشر على arm64 |
| برامج ويندوز `.exe` | معمارية مختلفة | Wine/box86 (دعم جزئي)، أو جهاز آخر |
| أدوات `.deb` بـ `amd64` | معمارية خاطئة | ابحث عن `arm64` أو flatpak |
| بعض برامج Electron | لا تصدر arm64 | Chromium + web app |
| **PdfCraft / WordCraft / GridCraft / DesignCraft / omniGet** | لا يوجد مُثبِّت arm64 | انتظر الدعم أو استخدم بدائل مفتوحة |

> **تجربتنا:** حاولنا بناء `WoeUSB-ng` من المصدر وفشل في ثلاث نقاط مختلفة.
> لا تُضِع وقتك فيه على arm64.

## 4. Flatpak: النقل اليدوي (مهم جداً)

تنزيل Flatpak من Flathub **على الجهاز** بطيء جداً (122–400 بايت/ثانية!).
الحل: نزّل على حاسوبك ثم انقل.

### على الحاسوب (x86_64 أو أي معمارية)

```bash
# حمّل فقط لمعمارية arm64
flatpak install --arch=aarch64 --download-only flathub org.gimp.GIMP
```

### الحزم الناتجة

```
/var/lib/flatpak/repo/objects/...      ← كائنات
/var/lib/flatpak/app/...               ← غير قابل للنقل مباشرة
```

الطريقة العملية: استخدم `flatpak build-bundle` بعد تنزيل التطبيق على حاسوب
لديه نفس المعمارية، أو استخدم مستودع `--arch=aarch64` مع:

```bash
# على الحاسوب (بعد --download-only)
flatpak build-bundle --arch=aarch64 /var/lib/flatpak/repo app.flatpak org.gimp.GIMP
```

### على الجهاز

```bash
scp -i ~/.ssh/nabu_fix *.flatpak zulf@nabu.local:~/flatpak-bundles/
flatpak install --user ~/flatpak-bundles/app.flatpak
flatpak list --app
```

> بديل أبسط: بعض التطبيقات تُوفّر `.flatpakref` — لكن التنزيل على الجهاز سيبقى بطيئاً.

## 5. تثبيت ملف `.deb` خارجي

```bash
sudo apt install -y gdebi
sudo gdebi package_arm64.deb
# عند أخطاء اعتماديات:
sudo apt install -f
```

### ربط `.deb` بـ GDebi للنقر المزدوج

```bash
sudo bash scripts/post-install/setup-deb-gui.sh
```

## 6. AppImage

```bash
chmod +x App.AppImage
./App.AppImage
```

إن ظهر خطأ `FUSE`:

```bash
sudo apt install -y libfuse2
# أو
./App.AppImage --appimage-extract-and-run
```

إدارة رسومية: ثبّت **Gear Lever** من Flatpak.

## 7. المتصفحات على Wayland

```bash
sudo bash scripts/post-install/setup-chrome-wayland.sh
```

يضيف `--ozone-platform=wayland --enable-wayland-ime`، وهو **ضروري** لعمل لوحة
المفاتيح العربية داخل المتصفح.

## 8. إدارة الحزم بسرعة

```bash
# بحث
apt search <term>
apt-cache policy <pkg>

# ما هو مثبّت؟
dpkg -l | grep <pkg>

# ما مالك ملف؟
dpkg -S /usr/bin/foo

# حجم الحزم
dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n | tail -15

# تنظيف
sudo apt autoremove --purge
sudo apt clean
```

→ المرجع النهائي: [10-cheatsheet.md](10-cheatsheet.md).
