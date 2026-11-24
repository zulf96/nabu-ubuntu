# 07 — الأعطال الشائعة والحلول

> كل حل هنا مقترن بسببه. إن لم ينفع حلّ، انتقل للقسم الذي يليه ولا تُعِد خطوات
> التثبيت من الصفر.

## 1. الإقلاع والشاشة

### شاشة سوداء بعد قائمة rEFInd

**السبب:** النواة `6.17` لا تُقلع على بعض الأجهزة (خصوصاً Samsung UFS).

**الحل:**
1. اضغط زر الطاقة مطولاً 10–15 ثانية حتى ينطفئ.
2. شغّل واختر **`6.14.11`** من القائمة.
3. اجعلها الافتراضية: `sudo bash scripts/boot/set-default-kernel.sh 6.14.11`.

### الشاشة مقلوبة أو صورة معكوسة

في `/mnt/esp/EFI/BOOT/refind.conf` يجب أن يوجد:

```nginx
rotation 3
```

القيم الأخرى (0/1/2) تدوّر الشاشة بزوايا مختلفة.

### الجهاز يقف على شعار شاومي ولا يظهر rEFInd

- تصحيح البوتلودر لم يكتمل → أعد [الخطوة 6](02-install.md#6-تصحيح-البوتلودر-dbpk-bootmanager).
- أو ملف `EFI/BOOT/bootaa64.efi` مفقود → أعد نسخ `efi.tar`.

### تعليق عند «session-N.scope» أثناء الإغلاق

- انتظر 90 ثانية (مهلة systemd الافتراضية)، أو اضغط زر الطاقة 10–15 ثانية.

---

## 2. سطح المكتب (GNOME)

### شاشة سوداء بعد تسجيل الدخول / تعليق gdm3

**السبب:** تغييرات في إدارة الطاقة أو logind أو gsettings يمكن أن تُفقد gdm3
إعداده للشاشة.

**الحل الفوري:**

```bash
sudo systemctl restart gdm3
```

> في اختبارنا، إصلاح واحد بهذا الأمر أعاد الصورة. **وأُعيدت كل تغييرات
> زر الطاقة/logind/gsettings إلى قيمها السابقة** لأنها كانت السبب.

### الدخول بحلقة (يعود لشاشة الدخول)

```bash
# من TTY: Ctrl+Alt+F3
df -h                    # القرص ممتلئ؟
ls -ld ~/.Xauthority ~/.config
sudo chown -R "$USER:$USER" ~
```

### العربية لا تظهر في قائمة اللغات

```bash
sudo bash scripts/post-install/setup-arabic.sh
gsettings get org.gnome.desktop.input-sources sources
```

### لصق/نسخ لا يعمل بين التطبيقات

تأكد أنك في جلسة Wayland:

```bash
echo $XDG_SESSION_TYPE        # wayland
```

---

## 3. الشبكة

### الواي فاي مفقود بعد السكون

```bash
sudo modprobe -r ath10k_snoc && sudo modprobe ath10k_snoc
nmcli device status
```

إن تكرّر، عطّل السكون التلقائي مؤقتاً:

```bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
```

### العنوان يتغيّر كل إقلاع (للـ SSH)

استخدم mDNS بدل IP:

```bash
getent hosts nabu.local
```

### لا اتصال بعد الإقلاع

```bash
nmcli radio wifi on
sudo systemctl restart NetworkManager
rfkill list
```

---

## 4. الصوت

### لا صوت من المكبّر

```bash
# اعرض البطاقات
aplay -l

# اختر مخرجاً افتراضياً
wpctl status
wpctl set-default <ID>
```

على هذا الجهاز: البطاقة `Xiaomi Pad 5` (WCD934x + CS35L41)، وتظهر تحذيرات
`wcd934x_mbhc_get_result_params: Impedance detect ramp error` عند عدم وجود سماعة —
**تحذير غير ضار**.

### الميكروفون لا يعمل في التطبيقات

تحقق من `pactl list sources short` واختر المصدر الصحيح في إعدادات التطبيق.

---

## 5. اللمس والقلم

| العرض | الحل |
|---|---|
| اللمس لا يعمل | `grep -H . /sys/class/input/input*/name` — يجب أن يظهر `NVTCapacitiveTouchScreen` |
| القلم لا يشحن (6.17) | `sudo modprobe idtp9418` ثم ثبّته دائماً |
| المؤشر يقفز | جرّب `libinput debug-events` لتشخيص الجهاز |
| لوحة مفاتيح شاومي لا تعمل | يجب أن تظهر `Xiaomi Pad Keyboard` — أعد توصيلها مغناطيسياً |

---

## 6. الطاقة والشحن

### الشاحن يُوصَل بعد الإقلاع ولا يشحن

- على `6.14.11`: **عطل معروف**. أعد التشغيل، أو انتقل إلى `6.17.0`.
- على `6.17.0`: تحقّق بـ `sudo bash scripts/diagnostics/health-check.sh --charging`.

### البطارية عالقة عند 99%

طبيعي عند الامتلاء: `pm8150b-charger/status = Full`، الجهد ≈ 4.41V.
للتأكد من أن الشاحن يُغذّي الجهاز: شغّل حملاً لثوانٍ وراقب أن النسبة لا تنخفض.

### الجهاز يسخن أثناء الشحن

- طبيعي أن ترتفع الحرارة 3–6°C. إن تجاوزت 45°C للبطارية، افصل الشاحن.
- `cat /sys/class/power_supply/qcom-battery/temp` (بوحدة 0.1°C).

### السكون لا يستيقظ

اضغط زر الطاقة مرة أخرى. إن تكرّر، عطّل السكون التلقائي (انظر 3).

---

## 7. التخزين

### `/media/data` غير موجود

```bash
sudo mount -a
lsblk -o NAME,PARTLABEL,MOUNTPOINT
# إن لم يكن في fstab: أضف السطر وأزل #
```

### لا أملك صلاحية الكتابة على البيانات

```bash
sudo chown -R "$USER:$USER" /media/data
```

### القرص ممتلئ

```bash
sudo apt clean
sudo journalctl --vacuum-size=200M
sudo bleachbit    # إن كان مثبّتاً
```

---

## 8. البرامج

### `.deb` لا يُثبَّت

```bash
sudo apt install -f
sudo gdebi package.deb
```

### خطأ «wrong architecture»

الحزمة `amd64` — تحتاج نسخة `arm64`:

```bash
dpkg --print-architecture     # arm64
dpkg -I package.deb | grep Architecture
```

### تطبيق AppImage لا يعمل

```bash
chmod +x app.AppImage
./app.AppImage
# أو ثبّت Gear Lever من flatpak لإدارتها رسومياً
```

### Snap بطيء أو يفشل

```bash
snap changes
sudo systemctl restart snapd
```

---

## 9. الإقلاع المزدوج

### لا أستطيع العودة إلى أندرويد

1. اختر «Reboot to Android» من rEFInd.
2. إن فشل: ادخل Fastboot واستعد النسخة:
   ```bash
   fastboot flash boot_b ~/nabu-backups/boot_b_backup.img
   ```

### Ubuntu لم تُقلع بعد تثبيت أندرويد جديد

تحديث أندرويد (OTA) قد يُعيد كتابة `boot_b` ويزيل ترقيع DBPK. الحل: أعد
`sideload installer_bootmanager_NOSB.zip` من TWRP.

---

## 10. عند الطلب للمساعدة

اجمع هذه المعلومات أولاً — توفّر وقتاً كبيراً:

```bash
sudo bash scripts/diagnostics/health-check.sh > ~/nabu-report.txt 2>&1
uname -a >> ~/nabu-report.txt
sudo dmesg | tail -100 >> ~/nabu-report.txt
```

→ المرجع السريع للأوامر: [10-cheatsheet.md](10-cheatsheet.md).
