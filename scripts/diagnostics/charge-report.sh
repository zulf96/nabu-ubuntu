#!/usr/bin/env bash
# charge-report.sh — تحليل منحنى الشحن من سجل nabu-charge.csv.
#
# يحسب جلسات الشحن (الفترات التي يكون فيها الشاحن موصولاً): نسبة البداية/النهاية،
# المدة، المعدّل %/ساعة، ومتوسط التيار.
#
# الاستخدام:
#   bash charge-report.sh                     # آخر 7 أيام
#   bash charge-report.sh --all               # كل السجل
#   bash charge-report.sh --days 30
#   bash charge-report.sh /path/to/nabu-charge.csv

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

LOG=/var/log/nabu-charge.csv
DAYS=7
while [ $# -gt 0 ]; do
  case "$1" in
    --all) DAYS=0 ;;
    --days) shift; DAYS="${1:-7}" ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "خيار غير معروف: $1" ;;
    *) LOG="$1" ;;
  esac
  shift
done

[ -r "$LOG" ] || die "لا أقرأ $LOG — ثبّت المسجّل: sudo bash scripts/post-install/install-charge-log.sh"
[ "$(wc -l < "$LOG")" -gt 1 ] || die "السجل فارغ — انتظر دقيقة بعد التثبيت"

hdr "السجل: $LOG"
info "عدد الأسطر: $(($(wc -l < "$LOG") - 1))"
info "أول قراءة:  $(sed -n '2p' "$LOG" | cut -d, -f1)"
info "آخر قراءة: $(tail -1 "$LOG" | cut -d, -f1)"

awk -F, -v days="$DAYS" '
function epoch(ts,   t) {
  t = ts
  gsub(/[-T:]/, " ", t)
  return mktime(t)
}
function dur(s) {
  if (s < 0) s = 0
  h = int(s/3600); m = int((s%3600)/60)
  if (h > 0) return h "س " m "د"
  if (m > 0) return m "د"
  return int(s) "ث"
}
NR == 1 { next }
{
  e = epoch($1)
  if (days > 0) {
    if (cutoff == 0) cutoff = e - days*86400
    if (e < cutoff) next
  }
  n++
  T[n]=e; C[n]=$2+0; S[n]=$3; I[n]=$4+0; ON[n]=$8+0; TP[n]=$9
}
END {
  if (n == 0) { print "لا بيانات في النطاق المطلوب."; exit }
  print ""
  printf "%-19s %5s %6s %9s %10s %11s\n", "بداية الشحنة", "من", "إلى", "المدة", "Δ%", "متوسط التيار"
  print "--------------------------------------------------------------------------"
  ins = 0; sess = 0; total_s = 0; total_dc = 0
  for (i = 1; i <= n; i++) {
    plug = (ON[i] == 1 || S[i] == "Charging" || S[i] == "Full")
    if (plug && !ins) { ins = 1; st = i }
    if (!plug && ins) {
      ins = 0; sess++
      en = i - 1
      secs = T[en] - T[st]
      dc = C[en] - C[st]
      avg = 0; c = 0
      for (j = st; j <= en; j++) if (I[j] < 0) { avg += I[j]; c++ }
      avg = c ? avg/c : 0
      rate = (secs > 0) ? dc/(secs/3600.0) : 0
      printf "%-19s %4d%% %5d%% %9s %+9.1f %8.0f mA  (%.1f%%/س)\n", strftime("%Y-%m-%d %H:%M", T[st]), C[st], C[en], dur(secs), dc, avg, rate
      total_s += secs; total_dc += dc
    }
  }
  if (ins) {
    sess++
    secs = T[n] - T[st]; dc = C[n] - C[st]
    avg = 0; c = 0
    for (j = st; j <= n; j++) if (I[j] < 0) { avg += I[j]; c++ }
    avg = c ? avg/c : 0
    rate = (secs > 0) ? dc/(secs/3600.0) : 0
    printf "%-19s %4d%% %5d%% %9s %+9.1f %8.0f mA  (%.1f%%/س) ← جارية\n", strftime("%Y-%m-%d %H:%M", T[st]), C[st], C[n], dur(secs), dc, avg, rate
    total_s += secs; total_dc += dc
  }
  print "--------------------------------------------------------------------------"
  printf "جلسات الشحن: %d | إجمالي زمن التوصيل: %s | صافي الشحن: %+d%%\n", sess, dur(total_s), total_dc
  if (total_s > 0) printf "المعدّل العام: %.1f%%/ساعة\n", total_dc/(total_s/3600.0)
}
' "$LOG"

hdr "إحصاءات عامة (كل السجل)"
awk -F, 'NR>1 && $2!=""{if(mx==""||$2>mx)mx=$2; if(mn==""||$2<mn)mn=$2; if($8==1)p++} END{printf "  أعلى نسبة: %s%% | أدنى نسبة: %s%% | أسطر شاحن موصول: %d\n", mx, mn, p+0}' "$LOG"
info "لحرارة البطارية الآن: cat /sys/class/power_supply/qcom-battery/temp  (بوحدة 0.1°م)"
