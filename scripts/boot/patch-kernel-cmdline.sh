#!/usr/bin/env bash
# patch-kernel-cmdline.sh — تعديل سطر أوامر النواة المضمَّن داخل ملف .efi.
#
# ⚠️ لماذا سكربت وليس تحريراً يدوياً؟
#   سطر الأوامر مخزَّن كسلسلة NUL-terminated داخل EFI stub. تغيير الطول
#   يُفسد بنية الملف لأن الحقول المجاورة تعتمد على الإزاحة. هذا السكربت
#   يبحث عن السلسلة، ويستبدلها **بطول محفوظ** (حشو بمسافات)، ويأخذ نسخة.
#
# الاستخدام:
#   sudo bash patch-kernel-cmdline.sh --show
#   sudo bash patch-kernel-cmdline.sh --set fw_devlink=off
#   sudo bash patch-kernel-cmdline.sh --set "root=PARTLABEL=linux rw fw_devlink=off"
#   sudo bash patch-kernel-cmdline.sh --revert
#   sudo bash patch-kernel-cmdline.sh --file /mnt/esp/EFI/Ubuntu/6.14.11.efi --show
#
# الافتراضي: /mnt/esp/EFI/Ubuntu/6.14.11.efi (لأن 6.17 لا يحتاج ترقيعاً).

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

require_root

TARGET=""
MODE=""
VALUE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --show)   MODE=show ;;
    --revert) MODE=revert ;;
    --set)    MODE=set; shift; VALUE="${1:-}"; [ -n "$VALUE" ] || die "--set يحتاج قيمة" ;;
    --file)   shift; TARGET="${1:-}" ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "خيار غير معروف: $1" ;;
  esac
  shift
done
[ -n "$MODE" ] || die "حدّد عملية: --show | --set | --revert"

if [ -z "$TARGET" ]; then
  if mnt=$(mount_esp 2>/dev/null) && [ -f "$mnt/EFI/Ubuntu/6.14.11.efi" ]; then
    TARGET="$mnt/EFI/Ubuntu/6.14.11.efi"
  else
    die "لم أجد 6.14.11.efi — استخدم --file /path/to/kernel.efi"
  fi
fi
[ -f "$TARGET" ] || die "الملف غير موجود: $TARGET"

command -v python3 >/dev/null || die "python3 مطلوب (sudo apt install python3)"

read_cmdline() {
  python3 - "$TARGET" <<'PY'
import sys
path = sys.argv[1]
data = open(path, "rb").read()
needle = b"root=PARTLABEL="
off = data.find(needle)
if off < 0:
    needle = b"root=/dev/"
    off = data.find(needle)
if off < 0:
    print("__NOT_FOUND__")
    sys.exit(3)
end = data.find(b"\x00", off)
if end < 0:
    end = min(len(data), off + 512)
print(f"{off}\t{data[off:end].decode('utf-8', 'replace')}")
PY
}

case "$MODE" in
  show)
    hdr "سطر الأوامر داخل $(basename "$TARGET")"
    out=$(read_cmdline) || die "لم أجد سلسلة root= داخل الملف"
    printf '      offset: %s\n' "$(printf '%s' "$out" | cut -f1)"
    printf '      cmdline: %s\n' "$(printf '%s' "$out" | cut -f2-)"
    ;;
  revert)
    hdr "استرجاع نسخة احتياطية"
    BAK=$(ls -1t "$TARGET".bak.* 2>/dev/null | head -1 || true)
    [ -n "$BAK" ] || die "لا توجد نسخة احتياطية ($TARGET.bak.*)"
    cp -a "$BAK" "$TARGET" || die "فشل النسخ"
    ok "استُعيدت: $BAK"
    info "تحقّق بعد الإقلاع: cat /proc/cmdline"
    ;;
  set)
    hdr "تعديل سطر الأوامر"
    out=$(read_cmdline) || die "لم أجد سلسلة root= داخل الملف"
    OFF=$(printf '%s' "$out" | cut -f1)
    OLD=$(printf '%s' "$out" | cut -f2-)
    info "القديم ($(printf '%s' "$OLD" | wc -c) بايت): $OLD"

    # إن كانت القيمة تحتوي '=' بلا مسافات، فهي زوج key=value يُستبدل/يُضاف
    if printf '%s' "$VALUE" | grep -qE '^[A-Za-z0-9_.-]+=' && ! printf '%s' "$VALUE" | grep -q ' '; then
      KEY=${VALUE%%=*}
      NEW=$(python3 - "$OLD" "$VALUE" "$KEY" <<'PY'
import sys
old, pair, key = sys.argv[1], sys.argv[2], sys.argv[3]
toks = old.split()
out, found = [], False
for t in toks:
    if t.split("=", 1)[0] == key:
        out.append(pair); found = True
    else:
        out.append(t)
if not found:
    out.append(pair)
print(" ".join(out))
PY
)
    else
      NEW="$VALUE"
    fi

    info "الجديد: $NEW"

    STAMP=$(date +%Y%m%d%H%M%S)
    BAK="$TARGET.bak.$STAMP"
    cp -a "$TARGET" "$BAK" || die "فشل أخذ النسخة الاحتياطية"
    ok "نسخة احتياطية: $BAK"

    # تعديل بطول محفوظ
    python3 - "$TARGET" "$OFF" "$OLD" "$NEW" <<'PY'
import sys
path, off, old, new = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
data = bytearray(open(path, "rb").read())
ob = old.encode()
nb = new.encode()
if data[off:off+len(ob)] != ob:
    print("خطأ: المحتوى عند الإزاحة لا يطابق المتوقَّع — أُلغي التعديل", file=sys.stderr)
    sys.exit(2)
if len(nb) > len(ob):
    print(f"خطأ: السطر الجديد أطول ({len(nb)} > {len(ob)} بايت) — الطول يجب أن يبقى محفوظاً", file=sys.stderr)
    sys.exit(3)
padded = nb + b" " * (len(ob) - len(nb))
data[off:off+len(ob)] = padded
open(path, "wb").write(data)
print(f"OK: كُتب {len(padded)} بايت (حشو {len(ob)-len(nb)} مسافة)")
PY
    rc=$?
    [ $rc -eq 0 ] || { rm -f "$BAK"; die "فشل التعديل (كود $rc) — لم يتغيّر الملف"; }

    hdr "التحقق"
    out2=$(read_cmdline) || die "تعذّر قراءة النتيجة"
    info "الآن: $(printf '%s' "$out2" | cut -f2-)"
    info "بعد الإقلاع تحقّق: cat /proc/cmdline"
    ;;
esac
