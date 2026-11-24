# 10 — ورقة الأوامر المرجعية

كل ما تحتاجه في صفحات قليلة. انسخ والصق.

## النظام والمعلومات

```bash
uname -r                                  # إصدار النواة
cat /proc/cmdline                         # سطر أوامر النواة
cat /etc/os-release | head -3             # إصدار التوزيعة
uptime -p                                 # مدة التشغيل
free -h                                   # الذاكرة
df -h /                                   # القرص
lsblk -o NAME,SIZE,PARTLABEL,MOUNTPOINT   # الأقسام
```

## ESP و rEFInd

```bash
sudo mount /dev/sda31 /mnt/esp            # اكتشف القسم أولاً بـ lsblk
ls /mnt/esp/EFI/Ubuntu/                   # النوى المتاحة
sudo nano /mnt/esp/EFI/BOOT/refind.conf   # الإعدادات
sudo umount /mnt/esp
```

```bash
# تغيير الافتراضية (يأخذ نسخة احتياطية)
sudo bash scripts/boot/set-default-kernel.sh 6.17.0
sudo bash scripts/boot/set-default-kernel.sh 6.14.11
```

## الشحن و USB-C

```bash
ls /sys/class/typec/                                   # port0 موجود = سليم
cat /sys/class/typec/port0/power_role                  # source [sink]
cat /sys/class/typec/port0/power_operation_mode        # 3.0A
sudo cat /sys/kernel/debug/devices_deferred            # يجب أن يكون فارغاً

# حالة البطارية
cat /sys/class/power_supply/qcom-battery/{capacity,status,current_now,voltage_now,temp}

# الشاحن
C=$(ls /sys/class/power_supply | grep -E 'pm8150b|ln8000' | head -1)
cat /sys/class/power_supply/$C/{status,online,usb_type,current_max,current_now}
```

```bash
sudo bash scripts/diagnostics/health-check.sh --charging
sudo bash scripts/post-install/install-charge-log.sh
bash scripts/diagnostics/charge-report.sh
sudo tail -20 /var/log/nabu-charge.csv
```

## تعديل سطر أوامر النواة

```bash
sudo bash scripts/boot/patch-kernel-cmdline.sh --show
sudo bash scripts/boot/patch-kernel-cmdline.sh --set fw_devlink=off
sudo bash scripts/boot/patch-kernel-cmdline.sh --revert
```

## الشبكة

```bash
nmcli device status
nmcli device wifi list
nmcli device wifi connect "SSID" password "PASS"
nmcli radio wifi off && nmcli radio wifi on
ip -br addr
getent hosts nabu.local
```

## الصوت

```bash
aplay -l
wpctl status
wpctl set-default <ID>
pactl list short sinks
```

## الإدخال (لمس/قلم/لوحة مفاتيح)

```bash
grep -H . /sys/class/input/input*/name
libinput list-devices | head -40
libinput debug-events          # Ctrl+C للخروج
```

## الطاقة

```bash
cat /sys/power/state           # freeze mem
cat /sys/power/mem_sleep       # [s2idle]
powerprofilesctl get
upower -i $(upower -e | grep -i bat | head -1) | head -12
```

## الخدمات والسجلات

```bash
systemctl --failed
systemctl status ssh --no-pager
sudo journalctl -b -p err --no-pager | tail -30
sudo dmesg -T --level=err,crit,alert | tail -30
sudo journalctl -u gdm3 -b --no-pager | tail -30
```

## GNOME / اللغة

```bash
gsettings get org.gnome.desktop.input-sources sources
gsettings set org.gnome.desktop.interface text-scaling-factor 1.15
locale -a | grep ar_
fc-list :lang=ar | wc -l
localectl status
```

## إدارة الحزم

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y <pkg>
sudo apt autoremove --purge && sudo apt clean
sudo gdebi file_arm64.deb
flatpak list --app
flatpak install --user file.flatpak
snap list
```

## SSH

```bash
ssh -i ~/.ssh/nabu_fix zulf@nabu.local
scp -i ~/.ssh/nabu_fix file zulf@nabu.local:~/
IP=$(getent hosts nabu.local | awk '{print $1}')
```

## Fastboot / ADB

```bash
fastboot devices
fastboot getvar unlocked
fastboot getvar current-slot
fastboot boot V4-MODDED-TWRP-LINUX.img
fastboot flash linux ubuntu-26.04-xiaomi-nabu.img
fastboot flash boot_b ~/nabu-backups/boot_b_backup.img

adb devices
adb push setup_ubuntu.sh /tmp/
adb shell "chmod +x /tmp/setup_ubuntu.sh && /tmp/setup_ubuntu.sh"
adb sideload installer_bootmanager_NOSB.zip
```

## استكشاف سريع

```bash
# ما الذي يستهلك البطارية؟
powertop --auto-tune          # (بحذر) أو:
top -o %CPU

# ما الجهاز الذي يشغل منفذاً؟
sudo fuser -v /dev/snd/*

# هل الوحدة محمّلة؟
lsmod | grep -E 'ln8000|ath10k|nt36523'

# معلومات الوحدة
modinfo ln8000_charger | head -6
```

## نسخ احتياطي سريع

```bash
# مهم: احفظ ملفات الإقلاع والإعدادات
sudo tar czf ~/nabu-boot-backup-$(date +%F).tar.gz \
  /mnt/esp/EFI/BOOT/refind.conf \
  /mnt/esp/EFI/Ubuntu/*.efi 2>/dev/null

# مفتاح اندرويد
adb pull /sdcard/boot_b.img .
sha256sum boot_b.img
```
