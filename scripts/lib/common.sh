#!/usr/bin/env bash
# دوال مشتركة لكل سكربتات nabu-ubuntu.
# تُستدعى بـ:  . "$(dirname "$0")/../lib/common.sh"

# لا نستخدم set -e كي لا تتوقف السكربتات عند غياب ملف sysfs اختياري.
set -uo pipefail

# ---------- الألوان ----------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

# ---------- سجل ----------
log()  { printf '%s\n' "${C_BLUE}==>${C_RESET} $*"; }
ok()   { printf '%s\n' "  ${C_GREEN}✓${C_RESET} $*"; }
warn() { printf '%s\n' "  ${C_YELLOW}⚠${C_RESET} $*"; }
bad()  { printf '%s\n' "  ${C_RED}✗${C_RESET} $*"; }
info() { printf '%s\n' "    $*"; }
die()  { printf '%s\n' "${C_RED}خطأ:${C_RESET} $*" >&2; exit 1; }

hdr() {
  printf '\n%s\n' "${C_BOLD}────────────────────────────────────────────${C_RESET}"
  printf '%s\n'   "${C_BOLD} $*${C_RESET}"
  printf '%s\n'   "${C_BOLD}────────────────────────────────────────────${C_RESET}"
}

# ---------- صلاحيات ----------
require_root() {
  [ "$(id -u)" -eq 0 ] || die "شغّل السكربت بصلاحيات الجذر: sudo bash $0 $*"
}

# المستخدم الحقيقي (حتى تحت sudo)
target_user() {
  printf '%s' "${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
}
target_home() {
  getent passwd "$(target_user)" | cut -d: -f6
}

# ---------- الكشف عن الجهاز ----------
is_nabu() {
  local model
  model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || true)
  case "$model" in
    *[Nn]abu*|*"Xiaomi Pad 5"*) return 0 ;;
  esac
  return 1
}

device_model() {
  tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "غير معروف"
}

# ---------- ESP ----------
find_esp_device() {
  local dev
  dev=$(lsblk -no PATH,PARTLABEL 2>/dev/null | awk '$2=="esp"{print $1; exit}')
  if [ -z "$dev" ]; then
    dev=$(blkid -t PARTLABEL=esp -o device 2>/dev/null | head -1)
  fi
  printf '%s' "$dev"
}

# يطبع مسار التركيب عند النجاح
mount_esp() {
  local mnt="${ESP_MOUNT:-/mnt/esp}" dev
  mkdir -p "$mnt" || return 1
  if mountpoint -q "$mnt"; then
    printf '%s' "$mnt"; return 0
  fi
  dev=$(find_esp_device)
  [ -n "$dev" ] || { warn "لم أجد قسماً باسم ESP (PARTLABEL=esp)."; return 1; }
  mount "$dev" "$mnt" 2>/dev/null || { warn "فشل تركيب $dev على $mnt"; return 1; }
  printf '%s' "$mnt"
}

# ---------- مصادر الطاقة ----------
detect_charger() {
  local d
  for c in pm8150b-charger ln8000-charger; do
    [ -d "/sys/class/power_supply/$c" ] && { printf '%s' "$c"; return 0; }
  done
  for d in /sys/class/power_supply/*; do
    [ -d "$d" ] || continue
    [ "$(cat "$d/type" 2>/dev/null)" = "USB" ] && { basename "$d"; return 0; }
  done
  printf ''
}

battery_dir() {
  local d
  for d in /sys/class/power_supply/*; do
    [ -d "$d" ] || continue
    [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] && { printf '%s' "$d"; return 0; }
  done
  printf ''
}

# ---------- typec ----------
typec_device() {
  local p
  for p in /sys/bus/platform/devices/*typec*; do
    [ -e "$p" ] && { printf '%s' "$p"; return 0; }
  done
  printf ''
}

typec_bound() {
  local d; d=$(typec_device)
  [ -n "$d" ] && [ -L "$d/driver" ]
}

# ---------- ألوان مساعدة ----------
bool_ok() { if "$@" >/dev/null 2>&1; then ok "نعم"; else bad "لا"; fi; }
