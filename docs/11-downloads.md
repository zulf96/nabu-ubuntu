# 11 — روابط التحميل الكاملة

> كل ملفات المشروع في مكان واحد: صورة النظام، أدوات التثبيت، النوى، صورة إقلاع أندرويد،
> وملفات المستودع نفسها — مع الأحجام والبصمات وطريقة التحقق.

## 0. أدوات الحاسوب (لينكس/ويندوز)

| الأداة | لينكس | ويندوز |
|---|---|---|
| Platform Tools (adb/fastboot) | حزمة `android-tools-adb`/`android-tools-fastboot` | [ZIP رسمي](https://dl.google.com/android/repository/platform-tools-latest-windows.zip) |
| 7-Zip (فكّ xz على ويندوز) | لا يحتاج (`xz` مدمج) | [تحميل](https://www.7-zip.org/download.html) |
| تعريف Fastboot | قواعد udev (في [12-platforms.md](12-platforms.md)) | [Google USB Driver](https://developer.android.com/studio/run/win-usb) أو [Zadig](https://zadig.akeo.ie/) |
| فتح البوتلودر | غير رسمي | [Mi Unlock](https://en.miui.com/unlock/download_en.html) |
| تمرير USB إلى WSL (اختياري) | — | [usbipd-win](https://github.com/dorssel/usbipd-win) |

> دليل التجهيز خطوة بخطوة لكل نظام: [12-platforms.md](12-platforms.md).

---

## 1. ملفات التثبيت الرسمية (Ubuntu 26.04 لنابو)

المصدر: [إصدار `ubuntu-26.04-v1.0.0`](https://github.com/TheMojoMan/xiaomi-nabu/releases/tag/ubuntu-26.04-v1.0.0)
على مستودع [TheMojoMan/xiaomi-nabu](https://github.com/TheMojoMan/xiaomi-nabu).

| # | الملف | الحجم | الاستخدام | التحميل |
|---|---|---|---|---|
| 1 | `ubuntu-26.04-xiaomi-nabu.img.xz` | 1.78 GB | صورة النظام كاملة (تُفكّ بـ `xz -d`) | [تحميل](https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/ubuntu-26.04-xiaomi-nabu.img.xz) |
| 2 | `V4-MODDED-TWRP-LINUX.img` | 50 MB | TWRP معدّل للتقسيم والإصلاح | [تحميل](https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/V4-MODDED-TWRP-LINUX.img) |
| 3 | `installer_bootmanager_NOSB.zip` | 4.9 MB | DBPK Bootmanager — تصحيح الإقلاع (sideload) | [تحميل](https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/installer_bootmanager_NOSB.zip) |
| 4 | `efi.tar` | 70.1 MB | حزمة ESP الجاهزة (rEFInd + النواة 6.14.11 + أدوات) | [تحميل](https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/efi.tar) |
| 5 | `setup_ubuntu.sh` | 3 KB | سكربت تقسيم القرص (يُشغَّل داخل TWRP) | [تحميل](https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/setup_ubuntu.sh) |

```bash
# تحميل الخمسة دفعة واحدة
BASE=https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0
for f in ubuntu-26.04-xiaomi-nabu.img.xz V4-MODDED-TWRP-LINUX.img \
         installer_bootmanager_NOSB.zip efi.tar setup_ubuntu.sh; do
  curl -LO "$BASE/$f"
done
```

### ملفات الإقلاع المتعدد (اختيارية)

| الملف | الحجم | الاستخدام | التحميل |
|---|---|---|---|
| `esp.img` | 38.1 MB | صورة ESP جاهزة (38MB) | [تحميل](https://github.com/TheMojoMan/xiaomi-nabu/releases/download/nabu-multiboot/esp.img) |
| `esp.tar` | 33.4 MB | محتوى ESP كملفات | [تحميل](https://github.com/TheMojoMan/xiaomi-nabu/releases/download/nabu-multiboot/esp.tar) |
| `installer_bootmanager_NOSB.zip` | 4.9 MB | نفس مدير الإقلاع (إصدار 2025) | [تحميل](https://github.com/TheMojoMan/xiaomi-nabu/releases/download/nabu-multiboot/installer_bootmanager_NOSB.zip) |

> صفحة الإصدار: [nabu-multiboot](https://github.com/TheMojoMan/xiaomi-nabu/releases/tag/nabu-multiboot)

---

## 2. النوى الجاهزة (EFI) — من مستودعنا

| النواة | الحجم | الحالة | SHA-256 | التحميل |
|---|---|---|---|---|
| `6.17.0-UFS-slowdown+.efi` | 36 MB | ✅ الافتراضية — شحن التوصيل الساخن يعمل | `ccf0b29d7c1cf067523bdf6ec6ff108d4454360090d7a4e39969a771e4d041ac` | [تحميل](https://github.com/zulf96/nabu-ubuntu/releases/download/nabu-kernels/6.17.0-UFS-slowdown+.efi) |
| `6.14.11.efi` | 31 MB | ⚠️ احتياطية — `fw_devlink=off`، لكن شحن التوصيل الساخن معطوب | `a31096f542cd0eaae1028cd42ae60694a143d5166a47d885982fed5c8277e19c` | [تحميل](https://github.com/zulf96/nabu-ubuntu/releases/download/nabu-kernels/6.14.11.efi) |

```bash
# تركيب نواة
sudo mount /dev/sda31 /mnt/esp
sudo cp 6.17.0-UFS-slowdown+.efi /mnt/esp/EFI/Ubuntu/
sudo bash scripts/boot/set-default-kernel.sh 6.17.0
```

> التفاصيل والمقارنة: [docs/05-kernels.md](05-kernels.md). **لا تحذف نواة تعمل** قبل تجربة الجديدة.

---

## 3. صورة إقلاع أندرويد (HyperOS 1.0.1 Global + Magisk v27)

| الملف | الحجم | SHA-256 | التحميل |
|---|---|---|---|
| `Boot_HyperOS1.0.1_GlobalOriginal_PatchmagiskV27_by-Artoseven.img` | 128 MB | `5a5d77fc87457d8c8c1e446b842283fc96da3582727a6e56bd9b9430fab3d8a4` | [تحميل](https://github.com/zulf96/nabu-ubuntu/releases/download/nabu-android-boot/Boot_HyperOS1.0.1_GlobalOriginal_PatchmagiskV27_by-Artoseven.img) |

**ما هي؟** صورة قسم `boot` الأصلية لـ HyperOS 1.0.1 **Global**، مُرقّاة مسبقاً بـ Magisk v27
(بواسطة Artoseven). الغرض منها **جذر أندرويد فقط** — لا علاقة لها بأوبونتو ولا بنواة Linux.

> ⚠️ **تحذيرات إلزامية**
>
> 1. هذه الصورة **لأندرويد فقط**. كتابتها على قسم Linux أو على ESP تُعطّب الإقلاع.
> 2. لا تفلشها إلا إذا كان أندرويد لديك **HyperOS 1.0.1 Global** بنفس البنية؛ غير ذلك = أندرويد لا يُقلع.
> 3. على الأجهزة ذات الفتحتين (A/B) اكتبها على **الفتحة النشطة** التي يُقلع منها أندرويد:
>    ```bash
>    fastboot getvar current-slot     # مثل: b
>    fastboot flash boot_b Boot_HyperOS1.0.1_GlobalOriginal_PatchmagiskV27_by-Artoseven.img
>    ```
> 4. **خُذ نسخة احتياطية أولاً** من قسم الإقلاع الحالي:
>    ```bash
>    fastboot fetch boot_b /tmp/boot_b_backup.img   # أو من TWRP: dd if=/dev/block/by-name/boot_b
>    ```
> 5. إعادة الجذر لا تؤثر على مدخل «Reboot to Android» في rEFInd، لكن صورة إقلاع خاطئة تجعل
>    ذلك المدخل يفشل — والعلاج إعادة كتابة النسخة الاحتياطية.

---

## 4. المستودع كاملاً

| الطريقة | الرابط |
|---|---|
| استنساخ Git | `git clone https://github.com/zulf96/nabu-ubuntu.git` |
| أرشيف ZIP | [main.zip](https://github.com/zulf96/nabu-ubuntu/archive/refs/heads/main.zip) (70 KB) |
| صفحة المستودع | [github.com/zulf96/nabu-ubuntu](https://github.com/zulf96/nabu-ubuntu) |

### الملفات المفردة (روابط مباشرة)

القاعدة: `https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/`

<details>
<summary><b>المستندات والإعدادات (21 ملفاً)</b></summary>

| الملف | الرابط |
|---|---|
| `README.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/README.md) |
| `README.en.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/README.en.md) |
| `CONTRIBUTING.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/CONTRIBUTING.md) |
| `CHANGELOG.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/CHANGELOG.md) |
| `LICENSE` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/LICENSE) |
| `Makefile` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/Makefile) |
| `.editorconfig` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/.editorconfig) |
| `.gitignore` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/.gitignore) |
| `assets/boot-flow.svg` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/assets/boot-flow.svg) |
| `tools/check-links.py` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/tools/check-links.py) |
| `tests/fixtures/sample-charge.csv` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/tests/fixtures/sample-charge.csv) |
| `.github/workflows/ci.yml` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/.github/workflows/ci.yml) |
| `docs/00-overview.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/00-overview.md) |
| `docs/01-prerequisites.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/01-prerequisites.md) |
| `docs/02-install.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/02-install.md) |
| `docs/03-post-install.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/03-post-install.md) |
| `docs/04-dualboot.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/04-dualboot.md) |
| `docs/05-kernels.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/05-kernels.md) |
| `docs/06-charging.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/06-charging.md) |
| `docs/07-troubleshooting.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/07-troubleshooting.md) |
| `docs/08-remote-access.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/08-remote-access.md) |
| `docs/09-apps.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/09-apps.md) |
| `docs/10-cheatsheet.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/10-cheatsheet.md) |
| `docs/11-downloads.md` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/docs/11-downloads.md) |

</details>

<details>
<summary><b>السكربتات (11 ملفاً)</b></summary>

| الملف | الرابط |
|---|---|
| `scripts/lib/common.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/lib/common.sh) |
| `scripts/boot/set-default-kernel.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/boot/set-default-kernel.sh) |
| `scripts/boot/patch-kernel-cmdline.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/boot/patch-kernel-cmdline.sh) |
| `scripts/boot/install-android-entry.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/boot/install-android-entry.sh) |
| `scripts/boot/Reboot2Android.efi` | [تحميل](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/boot/Reboot2Android.efi) |
| `scripts/diagnostics/health-check.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/diagnostics/health-check.sh) |
| `scripts/diagnostics/charge-report.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/diagnostics/charge-report.sh) |
| `scripts/diagnostics/typec-watchdog.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/diagnostics/typec-watchdog.sh) |
| `scripts/post-install/setup-arabic.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/post-install/setup-arabic.sh) |
| `scripts/post-install/setup-deb-gui.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/post-install/setup-deb-gui.sh) |
| `scripts/post-install/setup-chrome-wayland.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/post-install/setup-chrome-wayland.sh) |
| `scripts/post-install/install-charge-log.sh` | [فتح](https://raw.githubusercontent.com/zulf96/nabu-ubuntu/main/scripts/post-install/install-charge-log.sh) |

</details>

---

## 5. التحقق بعد التحميل

```bash
# صورة النظام: فحص سلامة الأرشيف المضغوط
xz -t ubuntu-26.04-xiaomi-nabu.img.xz && echo "IMG OK"

# الحزم
unzip -t installer_bootmanager_NOSB.zip
tar -tf efi.tar >/dev/null && echo "EFI OK"

# النوى وصورة أندرويد (قارن بالبصمات أعلاه)
sha256sum 6.17.0-UFS-slowdown+.efi 6.14.11.efi
sha256sum Boot_HyperOS1.0.1_GlobalOriginal_PatchmagiskV27_by-Artoseven.img
```

## 6. أحجام وأين تُوضع

| الملف | مكانه بعد التحميل | يُنسخ إلى |
|---|---|---|
| `ubuntu-26.04-xiaomi-nabu.img.xz` | الحاسوب | يُفكّ ثم يُكتب بـ `fastboot flash linux` |
| `V4-MODDED-TWRP-LINUX.img` | الحاسوب | `fastboot boot` (بدون كتابة) |
| `installer_bootmanager_NOSB.zip` | الحاسوب | يُرسل للجهاز عبر `adb sideload` |
| `efi.tar` | الحاسوب | يُفكّ إلى ESP (`/mnt/esp`) |
| `6.17.0-UFS-slowdown+.efi` | الحاسوب | `/mnt/esp/EFI/Ubuntu/` |
| `6.14.11.efi` | الحاسوب | `/mnt/esp/EFI/Ubuntu/` |
| `Boot_..._by-Artoseven.img` | الحاسوب | قسم `boot` في أندرويد فقط |

> روابط التثبيت التفصيلية خطوة بخطوة: [docs/02-install.md](02-install.md).
