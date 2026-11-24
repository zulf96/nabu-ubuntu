<p align="center">
  <img alt="Device" src="https://img.shields.io/badge/device-Xiaomi%20Pad%205%20(nabu)-blue">
  <img alt="Ubuntu" src="https://img.shields.io/badge/Ubuntu-26.04.1%20LTS%20arm64-E95420">
  <img alt="Kernels" src="https://img.shields.io/badge/kernels-6.14.11%20%7C%206.17.0-green">
  <img alt="Status" src="https://img.shields.io/badge/status-tested%20on%20real%20hardware-success">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-lightgrey">
</p>

# Ubuntu on Xiaomi Pad 5 (nabu) — English summary

> **العربية هي اللغة الأساسية للمشروع.** هذا ملف تلخيصي بالإنجليزية؛
> الدليل الكامل بالعربية في [README.md](README.md).

A complete, field-tested guide to running **Ubuntu 26.04.1 LTS (arm64)** on the
**Xiaomi Pad 5** (codename `nabu`, Snapdragon 860 / SM8150), including:

- **Step-by-step installation** — bootloader unlock, TWRP, partitioning, flashing,
  DBPK bootmanager patching ([docs/02-install.md](docs/02-install.md)).
- **Post-install setup** — updates, Arabic language/fonts (English UI kept),
  package tools, Chromium on Wayland ([docs/03-post-install.md](docs/03-post-install.md)).
- **Dual boot with Android** — rEFInd menu entry + recovery path
  ([docs/04-dualboot.md](docs/04-dualboot.md)).
- **Kernel comparison** — `6.14.11` vs `6.17.0`, when to use each
  ([docs/05-kernels.md](docs/05-kernels.md)).
- **Charging investigation** — full root-cause analysis of the `typec`
  `-EPROBE_DEFER` bug and the `ln8000_charger` hot-plug bug, plus a permanent
  charge logger ([docs/06-charging.md](docs/06-charging.md)).
- **Troubleshooting** — black screen, gdm3, Wi-Fi, audio, stylus, storage
  ([docs/07-troubleshooting.md](docs/07-troubleshooting.md)).
- **Remote access over SSH** ([docs/08-remote-access.md](docs/08-remote-access.md)).
- **arm64 app notes** ([docs/09-apps.md](docs/09-apps.md)) and a
  [command cheat sheet](docs/10-cheatsheet.md).
- **All download links** — system image, TWRP, bootmanager, kernels, rooted
  Android boot image, with sizes and SHA-256 ([docs/11-downloads.md](docs/11-downloads.md)).
- **Linux and Windows host workflows** — tooling, full command sequences, and
  per-OS pitfalls ([docs/12-platforms.md](docs/12-platforms.md)).

## TL;DR results

| Component | Status |
|---|---|
| Boot (Ubuntu 26.04.1) | ✅ rEFInd with kernel entries + Android entry |
| Display / touch / NVT pen | ✅ |
| Xiaomi keyboard & mouse | ✅ |
| Wi-Fi (ath10k, 5 GHz/80 MHz) | ✅ |
| Audio (WCD934x + CS35L41) | ✅ |
| s2idle | ✅ (may need an extra power-button press) |
| UFS throughput | ✅ 1.7 GB/s write, 4.8 GB/s read |
| Charging on **6.17.0** | ✅ hot-plug works, capped at ~6 W (1.2 A) |
| Charging on **6.14.11** | ⚠️ only if the charger is plugged **before** boot (`ln8000` bug) |
| Dual boot with Android | ✅ via `Reboot2Android.efi` |

## Quick start

```bash
git clone https://github.com/<USER>/nabu-ubuntu.git
cd nabu-ubuntu

sudo bash scripts/diagnostics/health-check.sh            # read-only health check
sudo bash scripts/diagnostics/health-check.sh --charging # charging deep dive
sudo bash scripts/post-install/setup-arabic.sh           # Arabic input, English UI
sudo bash scripts/post-install/install-charge-log.sh     # 1-minute charge logger
```

Installation itself starts at [docs/02-install.md](docs/02-install.md).

## Safety rules learned the hard way

- **Never** `unbind` the `ln8000_charger` driver manually — it triggers a kernel
  oops (`NULL pointer dereference`, `Oops: 96000004`). See
  [docs/06-charging.md](docs/06-charging.md).
- Keep **at least two kernels** in the rEFInd menu. `6.17.0` may black-screen on
  some UFS variants; `6.14.11` boots everywhere.
- Kernel command lines are **embedded in the `.efi` stub** — edit them only with
  `scripts/boot/patch-kernel-cmdline.sh` (length-preserving, with backup).
- Back up `boot_b` before touching Android.

## Credits

[TheMojoMan/xiaomi-nabu](https://github.com/TheMojoMan/xiaomi-nabu) ·
[rodriguezst/nabu-dualboot-img](https://github.com/rodriguezst/nabu-dualboot-img) ·
[ArKT-7 TWRP](https://github.com/ArKT-7/twrp_device_xiaomi_nabu) ·
[map220v/sm8150-mainline](https://github.com/map220v/sm8150-mainline) ·
[t.me/nabulinux](https://t.me/nabulinux)

## License

[MIT](LICENSE).
