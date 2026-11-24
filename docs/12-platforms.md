# 12 — العمل من لينكس ومن ويندوز

> كل خطوات التثبيت تُنفَّذ من **حاسوب** (لينكس أو ويندوز) عبر كابل USB، ثم يكمل الجهاز
> العمل بنفسه. هذا المستند يعطي المسار الكامل لكل نظام، مع الفروق والمشاكل الخاصة بكل واحد.

## 1. ما يُنفَّذ أين؟

| المرحلة | الحاسوب | التابلت |
|---|---|---|
| تنزيل الملفات وفكّ `xz` | ✅ | — |
| `adb` / `fastboot` (نسخ احتياطي، TWRP، كتابة الصورة، sideload) | ✅ | — |
| تشغيل `setup_ubuntu.sh` | يُرسَل من الحاسوب | ✅ داخل TWRP |
| أول إقلاع وإعداد المستخدم | — | ✅ |
| سكربتات ما بعد التثبيت والتشخيص | ✅ عبر SSH | ✅ تُنفَّذ فعلياً |

> **قاعدة:** أي أمر يبدأ بـ `sudo` في هذا المستودع يُنفَّذ **على التابلت** (بعد تثبيت أوبونتو)،
> وليس على حاسوبك — إلا أوامر `fastboot`/`adb` فهي على الحاسوب.

---

## 2. تجهيز الحاسوب

### 2.1 لينكس (Ubuntu/Debian/Fedora/Arch)

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install -y android-sdk-platform-tools-common adb fastboot xz-utils unzip curl rsync

# Fedora
sudo dnf install -y android-tools xz unzip curl rsync

# Arch
sudo pacman -S --needed android-tools xz unzip curl rsync
```

**قاعدة udev** (بدونها يظهر `no permissions`):

```bash
sudo tee /etc/udev/rules.d/51-android.rules >/dev/null <<'EOF'
# Xiaomi
SUBSYSTEM=="usb", ATTR{idVendor}=="2717", MODE="0666", GROUP="plugdev"
# Google / Fastboot
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"
# Qualcomm EDL
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", MODE="0666", GROUP="plugdev"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG plugdev "$USER"   # ثم سجّل الخروج والدخول
```

**أوقف ModemManager** أثناء العمل (يسرق منفذ USB):

```bash
sudo systemctl stop ModemManager
```

**تحقّق:**

```bash
adb version
fastboot --version
```

### 2.2 ويندوز 10/11

1. نزّل **Platform Tools** الرسمي:
   <https://dl.google.com/android/repository/platform-tools-latest-windows.zip>
2. فكّه إلى `C:\platform-tools` (بدون مسافات في المسار).
3. أضفه إلى `PATH`:
   - ابحث عن «متغيرات البيئة» → `Path` → تعديل → جديد → `C:\platform-tools`.
4. أغلق PowerShell وافتحه من جديد، ثم:

```powershell
adb version
fastboot --version
```

**تعريف السائق** إن لم يظهر الجهاز في `fastboot devices`:

1. وصّل التابلت في وضع Fastboot.
2. `Win + X` → «إدارة الأجهزة» (Device Manager).
3. ابحث عن جهاز بعلامة تعجّب (غالباً `Android` أو `nabu`).
4. زر يمين → «تحديث برنامج التشغيل» → «البحث في الحاسوب» → «اختيار من قائمة».
5. اختر **Android Bootloader Interface** (من حزمة Google USB Driver:
   <https://developer.android.com/studio/run/win-usb>) أو ثبّت **Mi Flash / Mi Unlock**
   مرة واحدة لتثبيت سائقات شاومي.
6. إن رفض ويندوز التعريف: أعد التشغيل مع `Shift` → استكشاف الأخطاء → خيارات متقدمة →
   إعدادات بدء التشغيل → تعطيل «فرض توقيع برنامج التشغيل».
7. بديل أخير: [Zadig](https://zadig.akeo.ie/) → اختر الجهاز → **WinUSB**.

> **لا تستخدم WSL للفلاش** افتراضياً: USB لا يُمرَّر إليه. إن أصررت، ثبّت
> [usbipd-win](https://github.com/dorssel/usbipd-win) واربط الجهاز بـ `usbipd attach`،
> لكن المسار الأصلي في PowerShell أكثر موثوقية.

---

## 3. المسار الكامل — لينكس

```bash
# 0) مجلد العمل
mkdir -p ~/nabu && cd ~/nabu

# 1) تنزيل الملفات (روابط docs/11-downloads.md)
BASE=https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0
curl -LO "$BASE/ubuntu-26.04-xiaomi-nabu.img.xz"
curl -LO "$BASE/V4-MODDED-TWRP-LINUX.img"
curl -LO "$BASE/installer_bootmanager_NOSB.zip"
curl -LO "$BASE/setup_ubuntu.sh"

# 2) فكّ الصورة (يحتاج ~8GB مساحة وذاكرة كافية)
xz -d -T0 -k ubuntu-26.04-xiaomi-nabu.img.xz
ls -lh ubuntu-26.04-xiaomi-nabu.img

# 3) تحقّق من الاتصال
adb devices                 # في أندرويد، مع تفعيل تصحيح USB
adb reboot bootloader
fastboot devices            # يجب أن يظهر الرقم

# 4) نسخة احتياطية لقسم إقلاع أندرويد
fastboot getvar current-slot
fastboot fetch boot_b /tmp/boot_b_backup.img || \
  echo "fetch غير مدعوم — انسخ القسم من TWRP بالأمر الموجود في docs/01-prerequisites.md"

# 5) TWRP مؤقت
fastboot boot V4-MODDED-TWRP-LINUX.img

# 6) انسخ الملفات إلى /tmp داخل TWRP
adb push setup_ubuntu.sh /tmp/
adb shell ls -l /tmp/setup_ubuntu.sh

# 7) في TWRP: Advanced ← Terminal، ثم:
#    sh /tmp/setup_ubuntu.sh

# 8) بعد انتهاء التقسيم: أعد الإقلاع إلى Fastboot
adb reboot bootloader
fastboot devices
fastboot flash linux ubuntu-26.04-xiaomi-nabu.img

# 9) تصحيح مدير الإقلاع
fastboot boot V4-MODDED-TWRP-LINUX.img
# في TWRP: Advanced ← ADB Sideload ← Swipe
adb sideload installer_bootmanager_NOSB.zip

# 10) أول إقلاع
fastboot reboot
```

---

## 4. المسار الكامل — ويندوز (PowerShell)

```powershell
# 0) مجلد العمل
New-Item -ItemType Directory -Force C:\nabu | Out-Null
Set-Location C:\nabu

# 1) التنزيل
$BASE = "https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0"
Invoke-WebRequest "$BASE/ubuntu-26.04-xiaomi-nabu.img.xz" -OutFile "ubuntu-26.04-xiaomi-nabu.img.xz"
Invoke-WebRequest "$BASE/V4-MODDED-TWRP-LINUX.img"      -OutFile "V4-MODDED-TWRP-LINUX.img"
Invoke-WebRequest "$BASE/installer_bootmanager_NOSB.zip" -OutFile "installer_bootmanager_NOSB.zip"
Invoke-WebRequest "$BASE/setup_ubuntu.sh"               -OutFile "setup_ubuntu.sh"

# 2) فكّ xz — الطريقة الأسهل: 7-Zip (زر يمين ← Extract Here)
#    أو عبر tar المدمج في ويندوز 10/11:
tar -xf .\ubuntu-26.04-xiaomi-nabu.img.xz
Get-ChildItem ubuntu-26.04-xiaomi-nabu.img

# 3) تحقّق (لازم يكون adb/fastboot في PATH)
adb devices
adb reboot bootloader
fastboot devices

# 4) نسخة احتياطية
fastboot getvar current-slot
fastboot fetch boot_b C:\nabu\boot_b_backup.img

# 5) TWRP
fastboot boot .\V4-MODDED-TWRP-LINUX.img

# 6) إرسال سكربت التقسيم
adb push .\setup_ubuntu.sh /tmp/
# ثم داخل TWRP: Advanced ← Terminal ← sh /tmp/setup_ubuntu.sh

# 7) كتابة النظام (قد تأخذ 5–15 دقيقة)
adb reboot bootloader
fastboot flash linux .\ubuntu-26.04-xiaomi-nabu.img

# 8) تصحيح الإقلاع
fastboot boot .\V4-MODDED-TWRP-LINUX.img
# TWRP: Advanced ← ADB Sideload ← Swipe
adb sideload .\installer_bootmanager_NOSB.zip

# 9) إعادة التشغيل
fastboot reboot
```

> **PowerShell:** اكتب `.\fastboot.exe` إن لم يكن المجلد في `PATH`، وضع المسارات بين
> علامتي اقتباس إذا احتوت مسافات: `fastboot boot "C:\My Files\V4....img"`.

---

## 5. الفروق الجوهرية بين النظامين

| المهمة | لينكس | ويندوز |
|---|---|---|
| تنصيب الأدوات | `apt`/`dnf`/`pacman` | تنزيل ZIP + `PATH` + تعريف |
| صلاحيات USB | udev + `plugdev` | سائق Android Bootloader / Zadig |
| تعارض ModemManager | `systemctl stop ModemManager` | غير موجود |
| فكّ `xz` | `xz -d -T0 -k` | 7-Zip أو `tar -xf` |
| نسخ مجلد | `rsync -a` | `robocopy` أو `scp -r` |
| بصمة ملف | `sha256sum` | `Get-FileHash -Algorithm SHA256` |
| متابعة سجل | `tail -f` | `Get-Content -Wait` |
| بحث في نص | `grep` | `Select-String` |
| SSH | مدمج | مدمج في ويندوز 10/11 (OpenSSH Client) |
| اسم `.local` (mDNS) | يعمل مباشرة | يحتاج Bonjour، وإلا استخدم IP |
| Mi Unlock (فتح البوتلودر) | غير رسمي/غير مدعوم | ✅ الرسمي |

### مكافئات سريعة

```bash
# لينكس
sha256sum 6.17.0-UFS-slowdown+.efi
scp -r nabu-ubuntu zulf@nabu.local:~/
ssh zulf@nabu.local 'sudo bash ~/nabu-ubuntu/scripts/diagnostics/health-check.sh'
```

```powershell
# ويندوز
Get-FileHash .\6.17.0-UFS-slowdown+.efi -Algorithm SHA256
scp -r .\nabu-ubuntu zulf@192.168.0.50:~/
ssh zulf@192.168.0.50 "sudo bash ~/nabu-ubuntu/scripts/diagnostics/health-check.sh"
```

> على ويندوز استخدم **IP الجهاز** بدل `nabu.local` إن لم يكن Bonjour مثبتاً
> (تجد IP في إعدادات الراوتر أو من شاشة الجهاز: `hostname -I`).

---

## 6. إدارة الجهاز من الحاسوب بعد التثبيت

### لينكس

```bash
# نسخ المستودع إلى التابلت
rsync -av --exclude .git ./nabu-ubuntu/ zulf@nabu.local:~/

# تشغيل فحص شامل عن بُعد
ssh zulf@nabu.local 'sudo bash ~/nabu-ubuntu/scripts/diagnostics/health-check.sh'

# سحب سجل الشحن
scp zulf@nabu.local:/var/log/nabu-charge.csv ./nabu-charge.csv

# تغيير النواة الافتراضية عن بُعد
ssh zulf@nabu.local 'sudo bash ~/nabu-ubuntu/scripts/boot/set-default-kernel.sh 6.17.0'
```

### ويندوز

```powershell
# نسخ المستودع
scp -r .\nabu-ubuntu zulf@192.168.0.50:~/

# تشغيل الفحص عن بُعد
ssh zulf@192.168.0.50 "sudo bash ~/nabu-ubuntu/scripts/diagnostics/health-check.sh"

# سحب سجل الشحن
scp zulf@192.168.0.50:/var/log/nabu-charge.csv .\nabu-charge.csv
```

بدائل واجهة رسومية على ويندوز: **WinSCP** لنقل الملفات، و**PuTTY** للطرفية.
مفاتيح SSH على ويندوز: `ssh-keygen -t ed25519` ثم `type $env:USERPROFILE\.ssh\id_ed25519.pub`
وأضف الناتج إلى `~/.ssh/authorized_keys` على التابلت.

---

## 7. مشاكل شائعة خاصة بكل نظام

### لينكس

| العرض | السبب | الحل |
|---|---|---|
| `no permissions (missing udev rules?)` | قواعد udev | أعد الخطوة 2.1 وسجّل الدخول من جديد |
| `fastboot devices` فارغ | ModemManager أو كابل شحن فقط | `sudo systemctl stop ModemManager` وكابل بيانات |
| `fastboot` يعلّق عند `waiting for device` | منفذ USB 3/Hub | منفذ مباشر على اللوحة، USB 2.0 إن أمكن |
| `xz: Cannot allocate memory` | خيوط كثيرة | `xz -d -T2` |
| الجهاز يختفي أثناء الفلاش | Auto-suspend | `sudo sh -c 'echo -1 > /sys/bus/usb/devices/*/power/autosuspend'` |

### ويندوز

| العرض | السبب | الحل |
|---|---|---|
| `fastboot` غير معروف | ليس في `PATH` | أعد فتح PowerShell بعد التعديل، أو `.\fastboot.exe` |
| `waiting for any device` | سائق غير مثبّت | تعريف Android Bootloader Interface (خطوة 2.2) |
| الجهاز يظهر ثم يختفي | منفذ/Hub | منفذ مباشر، وتعطيل «السماح للكمبيوتر بإيقاف تشغيل الجهاز» |
| `Access is denied` | برنامج آخر يحتجز adb | أغلق Mi Flash/HiSuite، ثم `adb kill-server` |
| اسم `.local` لا يُحلّ | لا يوجد mDNS | استخدم IP |
| سكربت `.sh` لا يعمل | سطر أوامر خاطئ | شغّله على التابلت عبر `ssh`، لا في PowerShell |
| `tar` لا يفكّ xz | إصدار قديم | استخدم 7-Zip |

> **تحذير:** لا تفتح ملفات `.sh` في Notepad وتحفظها — سيحوّل الأسطر إلى CRLF ويفشل
> Bash على الجهاز. استخدم VS Code مع `LF`.

---

## 8. تحذيرات مشتركة

- **Mi Unlock رسمي على ويندوز فقط.** من لينكس تحتاج جهاز ويندوز (أو جهازاً افتراضياً
  مع تمرير USB) — لا تحاول أدوات غير رسمية على جهازك الأساسي.
- **لا تفلش** `boot` أو `boot_a/boot_b` إلا لصورة أندرويد مطابقة لنسختك.
- **لا تكتب** صورة أوبونتو على أقسام أندرويد، ولا العكس.
- بعد أي تغيير في الإقلاع، جرّب **النظامين** قبل الاعتماد عليه.
- احتفظ دائماً بنسخة من `refind.conf` وقسم `boot` الاحتياطي خارج الجهاز.

---

## 9. التحقق النهائي (من أي نظام)

على الحاسوب:

```bash
fastboot getvar unlocked      # unlocked: yes
fastboot getvar product       # nabu
```

على التابلت بعد أول إقلاع:

```bash
uname -r                      # 6.17.0-... أو 6.14.11-...
cat /proc/cmdline
ls /mnt/esp/EFI/Ubuntu/       # ملفات النوى
sudo bash ~/nabu-ubuntu/scripts/diagnostics/health-check.sh
```

→ روابط كل ما سبق: [11-downloads.md](11-downloads.md) · الخطوات التفصيلية:
[02-install.md](02-install.md) · الأعطال: [07-troubleshooting.md](07-troubleshooting.md).
