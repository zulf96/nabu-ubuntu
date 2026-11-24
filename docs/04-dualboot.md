# 04 — الإقلاع المزدوج مع أندرويد

الهدف: عند كل تشغيل تظهر قائمة (rEFInd) تختار منها **Ubuntu** أو **Android**.

```
┌──────────────────────────────┐
│  rEFInd  (5 ثوانٍ)           │
│   • 6.17.0   ← افتراضي       │
│   • 6.14.11                  │
│   • Reboot to Android        │
└──────────────────────────────┘
```

## 1. كيف يعمل؟

```
البوتلودر (مُرقَّع بـ DBPK)
        │
        ├── يقرأ ESP → EFI/BOOT/bootaa64.efi  (rEFInd)
        │        ├── EFI/Ubuntu/6.17.0....efi   → Ubuntu
        │        └── EFI/android/Reboot2Android.efi → يضع تعليمات pstore ثم يعيد التشغيل
        │                                              إلى boot_b (أندرويد)
        └── خريطة الذاكرة المشتركة (StackBase 0x9FC00000)
```

`DualBootKernelPatcher` (من `installer_bootmanager_NOSB.zip`) يُرقّع نواة أندرويد
لتتجنّب منطقة الذاكرة التي تستخدمها UEFI، و`ShellCode.NabuPStore.bin` هي
التعليمات التي تُنفَّذ عند اختيار أندرويد.

## 2. ملفات الإقلاع على ESP

```bash
sudo mount /dev/sda31 /mnt/esp     # اكتشف القسم: lsblk -o NAME,PARTLABEL
sudo find /mnt/esp -maxdepth 2
```

```
/mnt/esp
├── EFI/BOOT/
│   ├── bootaa64.efi          ← rEFInd
│   ├── refind.conf           ← الإعدادات
│   ├── icons/                ← أيقونات القائمة
│   └── themes/
├── EFI/Ubuntu/
│   ├── 6.14.11.efi           (مُرقَّع: fw_devlink=off)
│   ├── 6.17.0-UFS-slowdown+.efi
│   └── 7.3.5-krjy.efi        (نواة بديلة اختيارية)
└── EFI/android/
    ├── Reboot2Android.efi    ← المدخل المستخدم
    └── AndroidBootPkg.efi
```

## 3. إعدادات rEFInd المهمة

`/mnt/esp/EFI/BOOT/refind.conf`:

```nginx
timeout 5                 # مدة عرض القائمة (ثانية)
use_nvram false           # لا تكتب في NVRAM
rotation 3                # دوران الشاشة 270° — إلزامي على nabu وإلا ظهرت مقلوبة

default_selection 6.17.0  # النواة الافتراضية (مطابقة جزئية للاسم)
timeout 5

menuentry "Reboot to Android" {
    icon /EFI/BOOT/icons/os_android.png
    loader /EFI/android/Reboot2Android.efi
}
```

### تغيير النواة الافتراضية

```bash
sudo bash scripts/boot/set-default-kernel.sh 6.17.0
# أو
sudo bash scripts/boot/set-default-kernel.sh 6.14.11
```

السكربت:
1. يكتشف ESP ويُركّبه.
2. **يأخذ نسخة احتياطية** `refind.conf.bak.<timestamp>`.
3. يعدّل `default_selection` فقط.
4. يتحقق من النتيجة ويطبع القائمة.

### إضافة مدخل أندرويد إن لم يكن موجوداً

```bash
sudo bash scripts/boot/install-android-entry.sh
```

ينسخ `Reboot2Android.efi` إلى `EFI/android/` ويضيف `menuentry` إن لم يكن موجوداً.

---

## 4. الإقلاع إلى أندرويد

1. أعد تشغيل التابلت.
2. في rEFInd اختر **«Reboot to Android»**.
3. سيعيد الجهاز التشغيل تلقائياً إلى `boot_b` ويُقلع أندرويد.

> أول إقلاع لأندرويد بعد التثبيت قد يأخذ وقتاً أطول (تحقق/تحسين التطبيقات).

### إن لم يُقلع أندرويد

| السبب المحتمل | الفحص | الحل |
|---|---|---|
| `boot_b` تالف/غير مُرقَّع | `fastboot getvar slot` | أعد تشغيل `installer_bootmanager_NOSB.zip` عبر sideload |
| صورة `boot_b` خاطئة | سجل الإقلاع | استعد النسخة الاحتياطية (أدناه) |
| البوتلودر غير مُرقَّع | rEFInd لا يظهر أصلاً | كرّر [الخطوة 6 من التثبيت](02-install.md#6-تصحيح-البوتلودر-dbpk-bootmanager) |

### استعادة `boot_b` من النسخة الاحتياطية

```bash
# 1) ادخل Fastboot (Volume Down + كابل)
fastboot devices

# 2) اكتب النسخة الاحتياطية
fastboot flash boot_b ~/nabu-backups/boot_b_backup.img

# 3) أعد التشغيل
fastboot reboot
```

> **ملاحظة:** النسخة الاحتياطية يجب أن تكون **بعد** ترقيع DBPK، وإلا فقد لا يعمل
> الإقلاع المزدوج. ملف `boot_b_backup.img` على جهازنا هو النسخة **الأصلية**
> التي استُعيدت ثم أُعيد ترقيعها بـ sideload.

### التحقّق من الشريحة النشطة

```bash
fastboot getvar current-slot     # a أو b
```

---

## 5. تحديث النواة دون كسر الإقلاع

كل نواة في هذا النظام تُثبَّت كملف `.efi` في `EFI/Ubuntu/` + وحدات في `/lib/modules/`.

```bash
# عرض النوى المتاحة
ls -1 /mnt/esp/EFI/Ubuntu/*.efi
ls -d /lib/modules/*/ | xargs -n1 basename

# بعد تثبيت نواة جديدة من PPA
sudo apt update
sudo apt install --only-upgrade xiaomi-nabu-linux-6.17
# ثم تحقّق من ظهور ملف .efi جديد وحدّث default_selection إن لزم
```

> ⚠️ **لا تحذف** نواة تعمل حالياً. اترك دائماً نواتين على الأقل في القائمة.

---

## 6. نصائح أمان

- **لا تُعِد تقسيم ESP** ولا تحذف `EFI/BOOT`.
- خُذ نسخة من `refind.conf` بعد كل تعديل ناجح.
- لا تُشغّل `fastboot flash boot_a/boot_b` إلا وأنت تعرف ما تفعل.
- بعد أي تغيير في الإقلاع: جرّب الإقلاعين (Ubuntu + Android) قبل أن تطمئن.

→ التالي: [05-kernels.md](05-kernels.md) لفهم الفرق بين النواتين.
صورة إقلاع أندرويد الجذرية (Magisk) وروابطها: [11-downloads.md](11-downloads.md).
