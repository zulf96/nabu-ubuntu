# 01 — المتطلبات والتحضير

> ⚠️ **اقرأ هذا المستند كاملاً، ثم المستند التالي، قبل أن تلمس أي شيء.**

## 1. العتاد والبرامج المطلوبة

| العنصر | التفاصيل |
|---|---|
| Xiaomi Pad 5 (nabu) | أي نسخة (6/128 أو 6/256) |
| حاسوب | Windows / macOS / Linux، مع كابل USB **بيانات** (ليس شحناً فقط) |
| مساحة تخزين | ~8GB لملفات التثبيت على الحاسوب |
| شاحن | الشاحن الأصلي (يُستخدم لاحقاً في اختبار الشحن) |
| إنترنت | للجهاز بعد التثبيت (واي فاي) |

### أدوات الحاسوب

- **ADB + Fastboot**:
  - لينكس: `sudo apt install android-tools-adb android-tools-fastboot` (وغيرها في [12-platforms.md](12-platforms.md))
  - ويندوز: [Platform Tools](https://dl.google.com/android/repository/platform-tools-latest-windows.zip)
    + تعريف Android Bootloader Interface
  - تحقّق: `adb version` و `fastboot --version`
- **فكّ ضغط xz**: `xz -d` (لينكس) أو 7-Zip (ويندوز) أو The Unarchiver (macOS).

> المسار الكامل من **لينكس** ومن **ويندوز** (تجهيز الأدوات، udev/السوائق، أوامر جاهزة،
> ومشاكل كل نظام): [12-platforms.md](12-platforms.md).

## 2. فتح البوتلودر (مرة واحدة في العمر)

> ⚠️ **فتح البوتلودر يمسح كل بيانات الجهاز** ويُصفّر الضمان.

1. في أندرويد: الإعدادات ← حول الجهاز ← اضغط «MIUI version» 7 مرات لتفعيل خيارات المطوّر.
2. الإعدادات ← خيارات إضافية ← خيارات المطوّر ← «حالة فتح Mi Unlock» ← اربط الحساب.
3. على الحاسوب: نزّل **Mi Unlock** الرسمي، سجّل دخول بنفس الحساب، واتبع التعليمات.
4. شاومي تفرض **مهلة انتظار (عادة 168 ساعة)** بين ربط الحساب وبين السماح بالفتح.
5. بعد انتهاء المهلة: أطفئ التابلت، ثم **اضغط مطولاً زر خفض الصوت** وصله بالحاسوب → وضع Fastboot.
6. في Mi Unlock اضغط «Unlock» وانتظر انتهاء العملية (يمسح كل شيء).

**تحقّق:**

```bash
fastboot devices          # يجب أن يظهر رقم الجهاز
fastboot getvar unlocked  # unlocked: yes
```

## 3. الملفات التي تُنزَّل

كلها من إصدارات upstream الرسمية:

| الملف | الوظيفة | المصدر |
|---|---|---|
| `V4-MODDED-TWRP-LINUX.img` | TWRP معدّل يرى قرص لينكس | [ArKT-7](https://github.com/ArKT-7/twrp_device_xiaomi_nabu/releases/tag/mod_linux) |
| `efi.tar` | ملفات الإقلاع (rEFInd والنواة) | إصدارات TheMojoMan |
| `setup_ubuntu.sh` | تقسيم القرص ونسخ ملفات الإقلاع | TheMojoMan |
| `ubuntu-26.04-xiaomi-nabu.img.xz` | نظام الملفات الجذر (مضغوط) | TheMojoMan |
| `installer_bootmanager_NOSB.zip` | تصحيح البوتلودر ليعرف لينكس + أندرويد | [rodriguezst](https://github.com/rodriguezst/nabu-dualboot-img) |

روابط التنزيل المباشرة (إصدار `ubuntu-26.04-v1.0.0`):

```
https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/V4-MODDED-TWRP-LINUX.img
https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/efi.tar
https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/setup_ubuntu.sh
https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/ubuntu-26.04-xiaomi-nabu.img.xz
https://github.com/TheMojoMan/xiaomi-nabu/releases/download/ubuntu-26.04-v1.0.0/installer_bootmanager_NOSB.zip
```

### فكّ ضغط الصورة (إلزامي)

```bash
xz -d ubuntu-26.04-xiaomi-nabu.img.xz
# الناتج: ubuntu-26.04-xiaomi-nabu.img
```

> إن حاولت `fastboot flash` على ملف `.xz` سيُكتب ملف مضغوط ويصبح الجهاز غير قابل للإقلاع.

## 4. النسخ الاحتياطي (لا تتجاوز هذه الخطوة)

### ما يجب حفظه

1. **صور أندرويد الأصلية** — خصوصاً `boot_b` (استُخدمت فعلياً في رحلة هذا المشروع لاستعادة أندرويد):
   ```bash
   adb shell "su -c 'dd if=/dev/block/by-name/boot_b of=/sdcard/boot_b.img'"
   adb pull /sdcard/boot_b.img ./boot_b_backup.img
   ```
   > على جهازنا حُفظت في `~/nabu-backups/boot_b_backup.img`.
2. **الصور الخاصة بالجهاز** (`persist`، `modem`، `vbmeta`) إن أمكن.
3. **ملفاتك الشخصية** (صور، مستندات، واتساب…) عبر USB أو النسخ السحابي.

### تحقّق من سلامة النسخة

```bash
ls -lh boot_b_backup.img
sha256sum boot_b_backup.img | tee boot_b_backup.sha256
```

## 5. توقّعات واقعية قبل البدء

| ما يعمل جيداً | ما يعمل بقيود |
|---|---|
| الشاشة، اللمس، القلم، لوحة مفاتيح شاومي | السكون: أحياناً تحتاج ضغطة زر إضافية |
| الواي فاي 5GHz، البلوتوث | الشحن: أبطأ من أندرويد (6–15W) |
| الصوت، الميكروفون | كاميرا/مستشعرات: دعم جزئي |
| الإقلاع المزدوج مع أندرويد | بعض تطبيقات arm64 غير متوفرة |

## 6. بعد التحضير

→ انتقل إلى [02-install.md](02-install.md).
