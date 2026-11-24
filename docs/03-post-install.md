# 03 — ما بعد التثبيت

هذا المستند يحوّل أوبونتو الخام إلى نظام يومي مريح: تحديثات، لغة عربية، أدوات
تثبيت برامج رسومية، كروم، قسم البيانات، وقلم شاومي.

## 1. التحديثات الأولى

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y micro curl wget git htop neofetch
```

### اختصارات مفيدة (من upstream)

الملف `~/.bash_aliases` يأتي مُعدّاً من صورة TheMojoMan:

| اختصار | الأمر |
|---|---|
| `sau` | `sudo apt update` |
| `saug` | `sudo apt upgrade` |
| `sai <pkg>` | `sudo apt install` |
| `ssi <pkg>` | `sudo snap install` |

اعرضها بـ `cat ~/.bash_aliases`، وأضف اختصاراتك بـ `micro ~/.bash_aliases`.

---

## 2. اللغة العربية (واجهة إنجليزية + كتابة عربية)

السكربت الجاهز:

```bash
sudo bash scripts/post-install/setup-arabic.sh
```

يفعل التالي:

1. تثبيت `language-pack-ar` و`language-pack-gnome-ar`.
2. خطوط عربية: `fonts-kacst`، `fonts-hosny-amiri`، `fonts-sil-sheherazade`، Noto.
3. حزم الدعم الإضافية: `check-language-support -l ar`.
4. توليد locales: `ar_SA.UTF-8`، `ar_EG.UTF-8`، `ar_AE.UTF-8`.
5. إضافة تخطيط لوحة المفاتيح `ara` إلى GNOME (مع إبقاء الإنجليزية أولاً).
6. التحقق: `locale -a | grep ar` و `fc-list :lang=ar | wc -l`.

### التبديل بين اللغتين

- **`Super + Space`** للتبديل بين English / العربية.
- لضبط يدوي: الإعدادات ← Keyboard ← Input Sources.

> **ملاحظة مقصودة:** لا نغيّر لغة النظام إلى العربية — فقط نضيف دعم الكتابة والقراءة.
> هذا يمنع مشاكل اتجاه الواجهة في بعض التطبيقات.

---

## 3. أدوات تثبيت البرامج

```bash
sudo bash scripts/post-install/setup-deb-gui.sh
```

| الأداة | الوظيفة |
|---|---|
| **GDebi** | تثبيت ملفات `.deb` بالنقر المزدوج + سطر أوامر `gdebi` |
| **GNOME Software** | متجر رسومي (apt + flatpak) |
| **Flatpak** | تشغيل حزم `.flatpak` (arm64) |
| `file-roller`، `unzip`، `p7zip-full` | فكّ الضغط |

### متاجر إضافية اختيارية

```bash
sudo apt install -y plasma-discover    # KDE Discover
sudo apt install -y synaptic           # Synaptic
sudo apt install -y bleachbit          # تنظيف النظام
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

> **تحذير مهم:** تنزيل Flatpak من Flathub على هذا الجهاز بطيء جداً (122–400 بايت/ثانية).
> نزّل الحزم على حاسوبك ثم انقلها:
> ```bash
> # على الحاسوب
> flatpak install --arch=aarch64 --download-only flathub <app-id>
> # أو من flathub: رابط .flatpakref
> scp *.flatpak zulf@nabu.local:~/flatpak-bundles/
> # على الجهاز
> flatpak install --user ~/flatpak-bundles/*.flatpak
> ```

### حزم flatpak مُختبَرة على الجهاز

`Warehouse` (إدارة flatpak)، `Gear Lever` (إدارة AppImage)، `Papers` (قارئ PDF).

---

## 4. كروم / كروميوم على Wayland

على arm64 لا يوجد كروم رسمي من Google؛ استخدم **Chromium** أو **Brave arm64**:

```bash
sudo apt install -y chromium-browser
sudo bash scripts/post-install/setup-chrome-wayland.sh
```

السكربت يضيف لمُشغّل المتصفح:

```
--ozone-platform=wayland --enable-wayland-ime
```

- `--ozone-platform=wayland`: رسم أصلي بلا XWayland (أسرع وأخف).
- `--enable-wayland-ime`: **ضروري** ليعمل محرّك الإدخال (لوحة المفاتيح العربية، On-Screen Keyboard)
  داخل المتصفح.

> إن تعطّل المتصفح بعد التعديل، شغّله من الطرفية لرؤية الخطأ، أو احذف
> `~/.local/share/applications/*chrom*.desktop` للعودة.

---

## 5. قسم البيانات (`/media/data`)

القسم موجود من التثبيت لكنه غير مُركَّب افتراضياً:

```bash
sudo micro /etc/fstab
# أزل علامة # من السطر الأخير الخاص بـ data:
# PARTLABEL=data /media/data ext4 defaults 0 2
sudo systemctl daemon-reload
sudo mount -a
sudo chown -R "$USER:$USER" /media/data
```

### ربط مجلدات المنزل (اختياري)

```bash
mkdir -p /media/data/{Downloads,Pictures,Documents}
rmdir ~/Downloads ~/Pictures ~/Documents 2>/dev/null
ln -s /media/data/Downloads ~/Downloads
ln -s /media/data/Pictures  ~/Pictures
ln -s /media/data/Documents ~/Documents
```

---

## 6. قلم Xiaomi (Smart Pen)

| النواة | ما تحتاجه |
|---|---|
| `6.14.11` | يعمل مباشرة |
| `6.17.0` | `sudo modprobe idtp9418` (مُقرِّر شحن القلم) |

لتفعيله دائماً على 6.17:

```bash
echo idtp9418 | sudo tee /etc/modules-load.d/charge-stylus.conf
```

لعرض حالة شحن القلم: الإعدادات ← Bluetooth ← اضغط مطولاً على زر في القلم حتى يظهر
«Xiaomi Smart Pen» ثم اربطه، وستظهر حالة الشحن في «Connected Devices».

---

## 7. إعدادات موصى بها

### تقليل استهلاك البطارية

```bash
sudo apt install -y power-profiles-daemon
powerprofilesctl set balanced        # أو power-saver
```

### تحسين الخطوط على الشاشة عالية الدقة (2560×1600)

```bash
gsettings set org.gnome.desktop.interface text-scaling-factor 1.15
gsettings set org.gnome.desktop.interface scaling-factor 1
```

### تفعيل التحديثات التلقائية للأمان فقط

```bash
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## 8. قائمة تحقّق نهائية

```bash
# اللغة والخطوط
locale -a | grep -c ar_            # > 0
fc-list :lang=ar | wc -l           # > 20

# البرامج
command -v gdebi flatpak gnome-software chromium-browser

# البيانات
df -h /media/data

# الصحة العامة
sudo bash scripts/diagnostics/health-check.sh
```

→ التالي: [04-dualboot.md](04-dualboot.md) لضبط الإقلاع المزدوج مع أندرويد.
