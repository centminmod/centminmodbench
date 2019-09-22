#!/bin/bash
################################################
# log per cpu thread cpu frequency via cpupower
################################################
logdir=/cpufreq
cpus=$(nproc)
cpus_seq=$((cpus-1))
cpumodelname=$(lscpu | awk -F ': ' '/Model name/ {print $2}' | sed -e 's|(R)||g' | xargs);
cpumodellabel=$(echo $cpumodelname | sed -e 's| |-|g');
dt=$(date +"%d%m%y-%H%M%S")
turbostat_enable='n'
cpupower_enable='y'

if [ ! -f /usr/bin/gnuplot ]; then
  yum -q -y install gnuplot
fi
if [ ! -d /usr/include/cairo ]; then
  yum -q -y install cairo-devel
fi
if [ ! -d /usr/include/pango-1.0 ]; then
  yum -q -y install pango-devel
fi
if [ ! -f /usr/bin/datamash ]; then
  if [ -z "$(rpm -qa epel-release | grep -o epel)" ]; then
    yum -q -y install epel-release
  fi
  yum -q -y install datamash
fi

getcpufreq() {
  statsmode=$1
if [ ! -d $logdir ]; then mkdir -p $logdir; fi
if [[ "$cpupower_enable" = [yY] && -f /usr/bin/cpupower ]] || [[ "$statsmode" = 'cpupower' && -f /usr/bin/cpupower ]]; then
  /usr/bin/cpupower monitor -m "Mperf" -i 1 | egrep -v 'Mperf|CPU' | cut -d\| -f1,4 | awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' > "${logdir}/log-${dt}.log"
  for cid in $(seq 0 $cpus_seq); do grep " ${cid}|" "${logdir}/log-${dt}.log" >> "${logdir}/${cid}.log"; done
fi
if [[ "$turbostat_enable" = [yY] && -f /usr/bin/turbostat ]] || [[ "$statsmode" = 'turbostat' && -f /usr/bin/turbostat ]]; then
  /usr/bin/turbostat -n1 -i1 | egrep -v 'CPU|\-'| awk '{print $2"|", $5}' | column -t | awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' > "${logdir}/log-${dt}.log"
  for cid in $(seq 0 $cpus_seq); do grep " ${cid}|" "${logdir}/log-${dt}.log" >> "${logdir}/${cid}.log"; done
fi
ls -lahrt "${logdir}" | egrep -v 'log-|.csv|datamash'
}

clear_logs() {
  rm -rf ${logdir}/*
}

csv_parse() {
  for cid in $(seq 0 $cpus_seq); do
    awk '{print $1,$2,$4}'  "${logdir}/${cid}.log" >> "${logdir}/${cid}.csv"
  done
}

csv_stats() {
  datamash_dt=$(date +"%d%m%y-%H%M%S")
  for cid in $(seq 0 $cpus_seq); do
    parsed_min=$(awk '{print $4}' "${logdir}/${cid}.log" | datamash --no-strict --filler 0 min 1)
    parsed_min=$(printf "%.0f\n" $parsed_min)
    parsed_max=$(awk '{print $4}' "${logdir}/${cid}.log" | datamash --no-strict --filler 0 max 1)
    parsed_max=$(printf "%.0f\n" $parsed_max)
    parsed_mean=$(awk '{print $4}' "${logdir}/${cid}.log" | datamash --no-strict -R 1 --filler 0 mean 1)
    parsed_mean=$(printf "%.0f\n" $parsed_mean)
    echo "cpu ${cid} min frequency: $parsed_min" >> "${logdir}/datamash-${cid}-min-${datamash_dt}.log"
    echo "cpu ${cid} avg frequency: $parsed_mean" >> "${logdir}/datamash-${cid}-avg-${datamash_dt}.log"
    echo "cpu ${cid} max frequency: $parsed_max" >> "${logdir}/datamash-${cid}-max-${datamash_dt}.log"
    echo "cat ${logdir}/datamash-${cid}-min-${datamash_dt}.log"
    cat "${logdir}/datamash-${cid}-min-${datamash_dt}.log"
    echo "cat ${logdir}/datamash-${cid}-avg-${datamash_dt}.log"
    cat "${logdir}/datamash-${cid}-avg-${datamash_dt}.log"
    echo "cat ${logdir}/datamash-${cid}-max-${datamash_dt}.log"
    cat "${logdir}/datamash-${cid}-max-${datamash_dt}.log"
  done
}

generate_gnuplot() {
  cpuid=$1
  fmin=$2
  favg=$3
  fmax=$4
  fmin_count=$5
  favg_count=$6
  fmax_count=$7

  # dynamic set xtic value according to number data points collected
  # if less than 300 data points collected then use 1 min xtics
  # if more than 300 but less than 600 data points collected then use 5 min xtics
  # if more than 600 data points then user 15 min xtics
  if [ "$fmin_count" -lt 600 ]; then
    xtics_set=1
  elif [[ "$fmin_count" -ge 600 && "$fmin_count" -le 900 ]]; then
    xtics_set=5
  elif [[ "$fmin_count" -ge 900 && "$fmin_count" -le 10800 ]]; then
    xtics_set=15
  else
    xtics_set=30
  fi

echo '#!/usr/bin/gnuplot' > cpufreq-${cpuid}.gplot
echo "reset

# Terminal config
set terminal pngcairo size 900,600 enhanced font 'Verdana,8'
set output '${logdir}/cpufreq-${cpuid}.png'
set title \"$cpumodelname CPU ${cpuid} Frequency\nby George Liu (centminmod.com)\n\nCPU ${cpuid} Frequency (Mhz) Min: $fmin   Avg: $favg   Max: $fmax\"
# set key bmargin
set key left top

# Line style
#set style line 1 lc rgb '#e74c3c' pt 1 ps 1 lt 1 lw 2 # line1
set style line 1 lc rgb '#e41a1c' pt 1 ps 1 lt 1 lw 1 # line1

# Axis configuration
#set style line 11 lc rgb '#2c3e50' lt 1 lw 1.5 # Axis line
set style line 11 lc rgb '#808080' lt 1 lw 1.5 # Axis line
set border 3 back ls 11
set tics nomirror
set autoscale xy
set xdata time
set timefmt \"%Y-%m-%d %H:%M:%S\"
set format x \"%H:%M\"
set xtics ${xtics_set}*60
set xlabel \"Time\"
set ylabel \"CPU ${cpuid} Frequency\"

# Background grid
set style line 11 lc rgb '#aeb6bf' lt 0 lw 2
set grid back ls 11

# Custom min, avg, max frequency values
# set label 'Min: $fmin' at 0.5,-0.35
# set label 'Avg: $favg' at 0.5,-0.25
# set label 'Max: $fmax' at 0.5,-0.15

# Statistics
# A_min, A_max, A_median
# stats '${logdir}/${cpuid}.csv' using 3 name "STATSA"
# set yrange [STATSA_min_x:STATSA_max_x]
# set label 1 "Maximun" at STATSA_pos_max_y, STATSA_max_y offset 1,-0.5
# set label 2 "Minimun" at STATSA_pos_min_y, STATSA_min_y offset 1,0.5

# Begin plotting
plot '${logdir}/${cpuid}.csv' using 1:3 title 'Mhz' with l ls 1, \\
     # STATSA_min_y w l lc rgb"#00ffff" notitle, \\
     # STATSA_max_y w l lc rgb"#00ffff" notitle
" >> cpufreq-${cpuid}.gplot
cat cpufreq-${cpuid}.gplot
gnuplot cpufreq-${cpuid}.gplot
}

plot_charts() {
  for cid in $(seq 0 $cpus_seq); do
    echo
    echo "generating chart for cpu $cid frequency"
    # calculate cpu frequency min, avg, max
    cpumin=$(awk '{print $5}' ${logdir}/datamash-${cid}-min-${datamash_dt}.log)
    cpumin_count=$(wc -l < ${logdir}/${cpuid}.csv)
    cpuavg=$(awk '{print $5}' ${logdir}/datamash-${cid}-avg-${datamash_dt}.log)
    cpuavg_count=$(wc -l < ${logdir}/${cpuid}.csv)
    cpumax=$(awk '{print $5}' ${logdir}/datamash-${cid}-max-${datamash_dt}.log)
    cpumax_count=$(wc -l < ${logdir}/${cpuid}.csv)
    generate_gnuplot "$cid" "$cpumin" "$cpuavg" "$cpumax" "$cpumin_count" "$cpuavg_count" "$cpumax_count"
    echo
  done
}

case "$1" in
  freq )
    getcpufreq
    ;;
  freq-cpupower )
    getcpufreq cpupower
    ;;
  freq-turbostat )
    getcpufreq turbostat
    ;;
  plot )
    csv_parse
    csv_stats
    plot_charts
    ;;
  clear )
    clear_logs
    ;;
  * )
    echo "$0 {freq|freq-cpupower|freq-turbostat|plot|clear}"
    ;;
esac