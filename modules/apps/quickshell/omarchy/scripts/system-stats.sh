set -euo pipefail

case "${1:-}" in
  "") ;;
  --bar-widget)
    awk 'NR==1 { total=0; for(i=2;i<=NF;i++)total+=$i; print "cpu\t" $5 "\t" total }' /proc/stat
    awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "memory\t%.2f\n",(t-a)*100/t}' /proc/meminfo
    awk '{print "load\t" $1}' /proc/loadavg
    exit ;;
  *) echo "Usage: system-stats [--bar-widget]" >&2; exit 2 ;;
esac
read -r _ u n s i w q sq st _ < /proc/stat; total1=$((u+n+s+i+w+q+sq+st)); idle1=$((i+w)); sleep 0.1
read -r _ u n s i w q sq st _ < /proc/stat; total2=$((u+n+s+i+w+q+sq+st)); idle2=$((i+w))
cpu=$(awk -v t=$((total2-total1)) -v i=$((idle2-idle1)) 'BEGIN{if(t)printf "%.0f%%",100*(t-i)/t;else print "0%"}')
awk -v cpu="$cpu" '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "cpu\t%s\nmemory\t%.1fGB / %.1fGB\n",cpu,(t-a)/1048576,t/1048576}' /proc/meminfo
