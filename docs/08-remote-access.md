# 08 — التحكّم عن بُعد (SSH)

مفيد جداً لأن الجهاز لوحي: تكتب من حاسوبك بلوحة مفاتيح كاملة، وتُشخّص المشاكل
بسرعة. هذا المستند يوثّق الإعداد الذي استخدمناه فعلياً.

## 1. على الجهاز

```bash
sudo apt install -y openssh-server avahi-daemon
sudo systemctl enable --now ssh avahi-daemon
systemctl status ssh --no-pager | head -5
```

### اسم ثابت (mDNS) بدل IP متغيّر

IP الجهاز يتغيّر بعد كل إقلاع، لذا نستخدم `nabu.local`:

```bash
hostname                       # يجب أن يكون nabu (أو أي اسم)
getent hosts nabu.local        # من الجهاز نفسه
```

للتغيير:

```bash
sudo hostnamectl set-hostname nabu
sudo systemctl restart avahi-daemon
```

## 2. على الحاسوب

```bash
# 1) مفتاح خاص بهذا الجهاز (لا تعِد استخدام مفاتيحك الشخصية)
ssh-keygen -t ed25519 -f ~/.ssh/nabu_fix -N ""

# 2) نسخ المفتاح إلى الجهاز
ssh-copy-id -i ~/.ssh/nabu_fix.pub zulf@nabu.local

# 3) اختبار
ssh -i ~/.ssh/nabu_fix zulf@nabu.local 'uname -r'
```

### أمر اتصال محصّن (يُستخدم في السكربتات)

```bash
ssh -i ~/.ssh/nabu_fix \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes \
    -o ConnectTimeout=8 \
    zulf@nabu.local
```

### حلّ الاسم عند فشل mDNS

```bash
IP=$(getent hosts nabu.local | awk '{print $1}')
echo "$IP"
ssh -i ~/.ssh/nabu_fix "zulf@${IP:-nabu.local}" 'uptime'
```

## 3. sudo بلا كلمة مرور (لتشغيل السكربتات آلياً)

```bash
echo "zulf ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/010-zulf-nopasswd
sudo chmod 440 /etc/sudoers.d/010-zulf-nopasswd
sudo visudo -c          # تحقّق من الصحة
```

> افعل ذلك **فقط** على جهازك الشخصي في شبكة موثوقة.

## 4. قواعد جدار الحماية

```bash
sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp
sudo ufw status
```

## 5. وصفات جاهزة

### نسخ ملف إلى الجهاز

```bash
scp -i ~/.ssh/nabu_fix file.deb zulf@nabu.local:~/
```

### تشغيل سكربت عن بُعد

```bash
ssh -i ~/.ssh/nabu_fix zulf@nabu.local 'sudo bash ~/nabu-ubuntu/scripts/diagnostics/health-check.sh'
```

### إعادة تشغيل والانتظار حتى العودة

```bash
IP=$(getent hosts nabu.local | awk '{print $1}')
ssh -i ~/.ssh/nabu_fix "zulf@$IP" 'sudo systemctl reboot' || true
sleep 100
until getent hosts nabu.local >/dev/null; do sleep 5; done
ssh -i ~/.ssh/nabu_fix zulf@nabu.local 'uptime; uname -r'
```

### مراقبة الشحن مباشرة

```bash
ssh -i ~/.ssh/nabu_fix zulf@nabu.local \
  'while true; do date +%T; cat /sys/class/power_supply/qcom-battery/{capacity,status}; sleep 5; done'
```

### سحب تقرير الصحة إلى حاسوبك

```bash
ssh -i ~/.ssh/nabu_fix zulf@nabu.local 'sudo bash ~/nabu-ubuntu/scripts/diagnostics/health-check.sh' > nabu-report.txt
```

## 6. مشاكل شائعة

| المشكلة | الحل |
|---|---|
| `Connection refused` | `sudo systemctl status ssh` — الخدمة متوقفة |
| `Permission denied (publickey)` | `ssh-copy-id` مرة أخرى؛ تحقّق من `~/.ssh/authorized_keys` وصلاحياته (700/600) |
| `Could not resolve hostname` | avahi متوقف: `sudo systemctl restart avahi-daemon` |
| يتصل ثم ينقطع | عطّل السكون، أو استخدم `ServerAliveInterval 30` |
| تغيّر المفتاح المضيف | احذف السطر من `known_hosts` (لذلك نستخدم `UserKnownHostsFile=/dev/null`) |

### صلاحيات صحيحة للمجلد

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

→ التالي: [09-apps.md](09-apps.md) للتطبيقات على arm64.
