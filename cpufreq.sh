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
turbostat_enable='y'
turbostat_stress='n'
turbostat_stress_interval='1'
cpupower_enable='n'

if [ ! -f /usr/bin/stress ]; then
  yum -q -y install stress
fi
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
  stresscheck=$2
  stress_cores=$3
if [ ! -d $logdir ]; then mkdir -p $logdir; fi
if [[ "$cpupower_enable" = [yY] && -f /usr/bin/cpupower ]] || [[ "$statsmode" = 'cpupower' && -f /usr/bin/cpupower ]]; then
  /usr/bin/cpupower monitor -m "Mperf" -i 1 > "${logdir}/fulllog-${dt}.log"
  cat "${logdir}/fulllog-${dt}.log" | egrep -v 'Mperf|CPU' | cut -d\| -f1,4 | awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' > "${logdir}/log-${dt}.log"
  for cid in $(seq -s " " 0 $cpus_seq); do grep " ${cid}|" "${logdir}/log-${dt}.log" >> "${logdir}/${cid}.log"; done
fi
if [[ "$turbostat_enable" = [yY] && -f /usr/bin/turbostat ]] || [[ "$statsmode" = 'turbostat' && -f /usr/bin/turbostat ]]; then
  if [[ "$turbostat_stress" = [yY] || "$stresscheck" = 'stress' ]]; then
    if [[ "$stress_cores" -eq 1 ]]; then
      stress_cpus='1'
    fi
    stress_label="\\n\\nload test: stress -c $stress_cpus -t $turbostat_stress_interval"
    echo "$stress_label" > "${logdir}/stress-label.log"
    # echo > "${logdir}/stress-label.log"
    /usr/bin/turbostat -o "${logdir}/fulllog-${dt}.log" stress -c "$cpus" -t "$turbostat_stress_interval"
    cat "${logdir}/fulllog-${dt}.log" | egrep -v 'CPU|\-|stress|sec'| awk '{print $2"|", $5}' | column -t | awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' > "${logdir}/log-${dt}.log"
  else
    stress_label=""
    echo > "${logdir}/stress-label.log"
    /usr/bin/turbostat -n1 -i1 > "${logdir}/fulllog-${dt}.log"
    cat "${logdir}/fulllog-${dt}.log" | egrep -v 'CPU|\-|stress|sec'| awk '{print $2"|", $5}' | column -t | awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' > "${logdir}/log-${dt}.log"
  fi
  for cid in $(seq -s " " 0 $cpus_seq); do grep " ${cid}|" "${logdir}/log-${dt}.log" >> "${logdir}/${cid}.log"; done
fi
ls -lAhrt "${logdir}" | egrep -v 'log-|.csv|datamash|cpufreq-|stress'
}

clear_logs() {
  rm -rf ${logdir}/*
}

csv_parse() {
  for cid in $(seq -s " " 0 $cpus_seq); do
    echo > "${logdir}/${cid}.csv"
    awk '{print $1,$2,$4}'  "${logdir}/${cid}.log" >> "${logdir}/${cid}.csv"
  done
}

csv_stats() {
  datamash_dt=$(date +"%d%m%y-%H%M%S")
  for cid in $(seq -s " " 0 $cpus_seq); do
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

  stress_label=$(cat "${logdir}/stress-label.log")

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

# generate individual cpu thread charts
echo '#!/usr/bin/gnuplot' > cpufreq-${cpuid}.gplot
echo "reset

# Terminal config
set terminal pngcairo size 900,600 enhanced font 'Verdana,8'
set output '${logdir}/cpufreq-${cpuid}.png'
set title \"$cpumodelname CPU ${cpuid} Frequency\nby George Liu (centminmod.com)\n\nCPU ${cpuid} Frequency (Mhz) Min: ${fmin}   Avg: ${favg}   Max: ${fmax}${stress_label}\"
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

generate_gnuplot_all() {
  stress_label=$(cat "${logdir}/stress-label.log")

# generate all cpu threads chart
echo '#!/usr/bin/gnuplot' > cpufreq-all.gplot
echo "reset

# Terminal config
set terminal pngcairo size 1000,1000 enhanced font 'Verdana,8'
set output '${logdir}/cpufreq-all.png'
set multiplot layout $(($cpus/2)), 2 title \"$cpumodelname CPU Frequency\nby George Liu (centminmod.com)${stress_label}\"
" >> cpufreq-all.gplot

cpus_matched=$(lscpu --all --extended | grep -v CPU | awk '{print $4,$1}' | tail -$(($(nproc)/2)))

# older intel cpu check
if [[ "$(echo $cpus_matched | grep -w 0)" != '0' ]]; then
  #   cpus_matched=$(lscpu --all --extended | grep -v CPU | awk '{print $4,$1}' | sed -n '0~2p')
  cpus_matched=$(seq -s " " 0 $cpus_seq)
fi
echo
echo $cpus_matched
echo

# generate each cpu plot
for cpuid_all in $cpus_matched; do
  fmin=$(cat "${logdir}/${cpuid_all}-min.log")
  favg=$(cat "${logdir}/${cpuid_all}-avg.log")
  fmax=$(cat "${logdir}/${cpuid_all}-max.log")
  cpumin_count=$(wc -l < ${logdir}/${cpuid_all}.log)
  cpuavg_count=$(wc -l < ${logdir}/${cpuid_all}.log)
  cpumax_count=$(wc -l < ${logdir}/${cpuid_all}.log)

  # dynamic set xtic value according to number data points collected
  # if less than 300 data points collected then use 1 min xtics
  # if more than 300 but less than 600 data points collected then use 5 min xtics
  # if more than 600 data points then user 15 min xtics
  if [ "$fmin_count" -lt 600 ]; then
    xtics_set_all=1
  elif [[ "$fmin_count" -ge 600 && "$fmin_count" -le 900 ]]; then
    xtics_set_all=5
  elif [[ "$fmin_count" -ge 900 && "$fmin_count" -le 10800 ]]; then
    xtics_set_all=15
  else
    xtics_set_all=30
  fi

  # dynamically adjust ytics value if range is less than 100
  if [[ "$(($fmax-$fmin))" -le '25' ]]; then
    ytics_interval='set ytics 10'
  elif [[ "$(($fmax-$fmin))" -gt '25' && "$(($fmax-$fmin))" -le '50' ]]; then
    ytics_interval='set ytics 10'
  elif [[ "$(($fmax-$fmin))" -gt '51' && "$(($fmax-$fmin))" -le '100' ]]; then
    ytics_interval='set ytics 25'
  else
    ytics_interval='#set ytics 100'
  fi

echo "
#############
### chart ${cpuid_all}
set title \"CPU ${cpuid_all} Frequency (Mhz) Min: ${fmin}   Avg: ${favg}   Max: ${fmax}\" font \", 7\"
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
set xtics ${xtics_set_all}*60 font \", 7\"
$ytics_interval font \", 7\"
# set xlabel \"Time\"
# set ylabel \"CPU ${cpuid_all} Frequency\"
unset key

# Background grid
set style line 11 lc rgb '#aeb6bf' lt 0 lw 2
set grid back ls 11

# Begin plotting
plot '${logdir}/${cpuid_all}.csv' using 1:3 title 'Mhz' with l ls 1, \\
" >> cpufreq-all.gplot
done

echo "
unset multiplot" >> cpufreq-all.gplot

cat cpufreq-all.gplot
gnuplot cpufreq-all.gplot
}

plot_charts() {
  for cid in $(seq -s " " 0 $cpus_seq); do
    echo
    echo "generating chart for cpu $cid frequency"
    # calculate cpu frequency min, avg, max
    cpumin=$(awk '{print $5}' ${logdir}/datamash-${cid}-min-${datamash_dt}.log)
    cpumin_count=$(wc -l < ${logdir}/${cid}.log)
    cpuavg=$(awk '{print $5}' ${logdir}/datamash-${cid}-avg-${datamash_dt}.log)
    cpuavg_count=$(wc -l < ${logdir}/${cid}.log)
    cpumax=$(awk '{print $5}' ${logdir}/datamash-${cid}-max-${datamash_dt}.log)
    cpumax_count=$(wc -l < ${logdir}/${cid}.log)
    # generate log files for each cpu threads min, avg, max values
    echo "$cpumin" > "${logdir}/${cid}-min.log"
    echo "$cpuavg" > "${logdir}/${cid}-avg.log"
    echo "$cpumax" > "${logdir}/${cid}-max.log"
    generate_gnuplot "$cid" "$cpumin" "$cpuavg" "$cpumax" "$cpumin_count" "$cpuavg_count" "$cpumax_count"
    echo
  done
  generate_gnuplot_all
  echo
}

autoplot() {
  sleep 3
  csv_parse
  csv_stats
  plot_charts
}

# trap autoplot SIGHUP SIGINT SIGTERM

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
  freq-turbostat-stress )
    getcpufreq turbostat stress
    ;;
  freq-turbostat-stress-1 )
    getcpufreq turbostat stress 1
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
    echo "$0 {freq|freq-cpupower|freq-turbostat|freq-turbostat-stress|freq-turbostat-stress-1|plot|clear}"
    ;;
esac