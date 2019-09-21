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

if [ ! -f /usr/bin/gnuplot ]; then
  yum -q -y install gnuplot
fi
if [ ! -d /usr/include/cairo ]; then
  yum -q -y install cairo-devel
fi
if [ ! -d /usr/include/pango-1.0 ]; then
  yum -q -y install pango-devel
fi

getcpufreq() {
if [ ! -d $logdir ]; then mkdir -p $logdir; fi
if [ -f /usr/bin/cpupower ]; then
/usr/bin/cpupower monitor -m "Mperf" -i 1 | egrep -v 'Mperf|CPU' | cut -d\| -f1,4 | awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' > "${logdir}/log-${dt}.log"
for cid in $(seq 0 $cpus_seq); do grep " ${cid}|" "${logdir}/log-${dt}.log" >> "${logdir}/${cid}.log"; done
fi
ls -lahrt "${logdir}" | egrep -v 'log-|.csv'
}

clear() {
  rm -rf ${logdir}/*
}

csv_parse() {
  for cid in $(seq 0 $cpus_seq); do 
    awk '{print $1,$2,$4}'  "${logdir}/${cid}.log" >> "${logdir}/${cid}.csv"
  done
}

generate_gnuplot() {
  cpuid=$1
echo '#!/usr/bin/gnuplot' > cpufreq-${cpuid}.gplot
echo "reset

# Terminal config
set terminal pngcairo enhanced font 'Verdana,8'
set output '${logdir}/cpufreq-${cpuid}.png'
set title \"$cpumodelname CPU ${cpuid} Frequency\"
set key bmargin

# Line style
set style line 1 lc rgb '#e74c3c' pt 1 ps 1 lt 1 lw 2 # line1

# Axis configuration
set style line 11 lc rgb '#2c3e50' lt 1 lw 1.5 # Axis line
set border 3 back ls 11
set tics nomirror
set autoscale xy
set xdata time
set timefmt \"%Y-%m-%d %H:%M:%S\"
set xlabel \"Time\"
set ylabel \"CPU ${cpuid} Frequency\"

# Background grid
set style line 11 lc rgb '#aeb6bf' lt 0 lw 2
set grid back ls 11

# Begin plotting
plot '${logdir}/${cpuid}.csv' using 1:3 title 'Mhz' with l ls 1, \\
" >> cpufreq-${cpuid}.gplot
cat cpufreq-${cpuid}.gplot
gnuplot cpufreq-${cpuid}.gplot
}

plot_charts() {
  for cid in $(seq 0 $cpus_seq); do
    echo
    echo "generating chart for cpu $cid frequency"
    generate_gnuplot "$cid"
    echo
  done
}

case "$1" in
  freq )
    getcpufreq
    ;;
  plot )
    csv_parse
    plot_charts
    ;;
  clear )
    clear
    ;;
  * )
    echo "$0 {freq|plot|clear}"
    ;;
esac