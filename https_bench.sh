#!/bin/bash
######################################################
# written by George Liu (eva2000) centminmod.com
# when ran with command
# curl -sL https://github.com/centminmod/centminmodbench/raw/master/https_bench.sh | bash
# setup & benchmark nginx http/2 https vhost
######################################################
# variables
#############
DT=$(date +"%d%m%y-%H%M%S")
VER='1.6'
SLEEP_TIME='10'
HTTPS_BENCHCLEANUP='y'
HTTPS_DUALCERT='y'
TEST_RSA='y'
TEST_ECDSA='y'
TESTRUNS='5'

# number of h2load threads to test with
# default = 1 to test 1 cpu core
HTWOLOAD_THREADS='1'

TESTA_USERS='100'
TESTA_REQUESTS='1000'
TESTB_USERS='300'
TESTB_REQUESTS='6000'

CMBEMAIL='n'
CMEBMAIL_ADDR=''
CENTMINLOGDIR='/root/centminlogs'

SHOWSTATS='n'
SARSTATS='n'
NGINX_STATS='n'
NON_CENTMINMOD='n'
NON_CENTMINMODTESTA='n'
NON_CENTMINMODTESTB='y'
###############################################################
vhostname=http2.domain.com
CNIP=$(curl -4s https://ipinfo.io/ip)
###############################################################
# Setup Colours
black='\E[30;40m'
red='\E[31;40m'
green='\E[32;40m'
yellow='\E[33;40m'
blue='\E[34;40m'
magenta='\E[35;40m'
cyan='\E[36;40m'
white='\E[37;40m'
 
boldblack='\E[1;30;40m'
boldred='\E[1;31;40m'
boldgreen='\E[1;32;40m'
boldyellow='\E[1;33;40m'
boldblue='\E[1;34;40m'
boldmagenta='\E[1;35;40m'
boldcyan='\E[1;36;40m'
boldwhite='\E[1;37;40m'
 
Reset="tput sgr0"      #  Reset text attributes to normal
                       #+ without clearing screen.
 
cecho ()                     # Coloured-echo.
                             # Argument $1 = message
                             # Argument $2 = color
{
message=$1
color=$2
echo -e "$color$message" ; $Reset
return
}
###############################################################
# functions
#############
mkdir -p "$CENTMINLOGDIR"

if [[ "$NON_CENTMINMOD" = [yY] ]]; then
  SARSTATS='n'
  HTTPS_BENCHCLEANUP='n'
  SLEEP_TIME='20'
fi

if [ -f https_bench.ini ]; then
  . https_bench.ini
fi

if [[ "$NON_CENTMINMOD" = [nN] ]]; then
  if  [ ! -d /usr/local/nginx/conf/conf.d ]; then
    echo
    echo "Centmin Mod directory not found"
    echo "/usr/local/nginx/conf/conf.d/ is missing"
    echo
    exit
  fi
fi

check_crypto() {
  get_crypto=$(nginx -V 2>&1 | grep 'built with' | egrep -io 'boringssl|openssl|libressl' | tr '[:upper:]' '[:lower:]')
}

stats() {
  if [[ "$SHOWSTATS" = [yY] ]]; then
    echo "-------------------------------------------------------------------------------------------"
    cpu_utilisation=$(sar -u 1 3 | tail -1 | while read avg cpu user nice sys io steal idle; do echo "cpu utilisation: user ${user}% nice ${nice}% system: ${sys}% iowait ${io}% steal ${steal}% idle ${idle}%"; done)
    echo "$cpu_utilisation"
    echo "-------------------------------------------------------------------------------------------"
  fi
}

sar_stats() {
  if [[ "$SARSTATS" = [yY] ]]; then
    if [[ "$(uname -m)" = 'x86_64' || "$(uname -m)" = 'aarch64' ]] && [[ -f /usr/lib64/sa/sa1 ]]; then
      SARCALL='/usr/lib64/sa/sa1'
    elif [[ "$(uname -m)" = 'x86_64' || "$(uname -m)" = 'aarch64' ]] && [[ -f /usr/lib/sysstat/sa1 ]]; then
      SARCALL='/usr/lib/sysstat/sa1'
    else
      SARCALL='/usr/lib/sa/sa1'
    fi
    SAR_STARTTIME=$(date +"%H:%M:%S")
    $SARCALL 1 &
    getsar_pid=$!
  fi
}

nginx_stats() {
  if [[ "$NGINX_STATS" = [yY] && -d "/home/nginx/domains/${vhostname}/log" ]]; then
    while true; do echo -n "$(date +"%H:%M:%S") "; curl -s http://127.0.0.1/nginx_status | sed -e 's|server ||g' | xargs | >> /home/nginx/domains/${vhostname}/log/nginx_status_${DT}.log; sleep 1; done &
    getngxstat_pid=$!
  fi
}

div() {
	cecho "-------------------------------------------------------------------------------------------" $boldgreen
}

s() {
	echo
}

baseinfo() {
  cecho "-------------------------------------------------------------------------------------------" $boldgreen
  cecho "System Information" $boldyellow
  cecho "-------------------------------------------------------------------------------------------" $boldgreen
  s

  uname -r
  s

  if [ -f /etc/redhat-release ]; then
    cat /etc/redhat-release
  elif [ -f /etc/lsb-release ]; then
    cat /etc/lsb-release
  fi
  s
  
  if [ -f /etc/centminmod-release ]; then
  echo -n "Centmin Mod "
  cat /etc/centminmod-release 2>&1 >/dev/null
  s
  fi
  
  div
  if [ ! -f /proc/user_beancounters ]; then
    CPUFLAGS=$(cat /proc/cpuinfo | grep '^flags' | cut -d: -f2 | awk 'NR==1')
    lscpu
    echo
    echo "CPU Flags"
    echo "$CPUFLAGS"    
  else
    CPUNAME=$(cat /proc/cpuinfo | grep "model name" | cut -d ":" -f2 | tr -s " " | head -n 1)
    CPUCOUNT=$(cat /proc/cpuinfo | grep "model name" | cut -d ":" -f2 | wc -l)
    CPUFLAGS=$(cat /proc/cpuinfo | grep '^flags' | cut -d: -f2 | awk 'NR==1')
    echo "CPU: $CPUCOUNT x$CPUNAME"
    uname -m
    echo
    echo "CPU Flags"
    echo "$CPUFLAGS"
  fi
  s

  if [ ! -f /proc/user_beancounters ]; then
  div
  lscpu -e
  s
  fi
  
  # cat /proc/cpuinfo
  # s
  
  div
  free -ml
  s
  
  if [[ "$NON_CENTMINMOD" = [nN] ]]; then
    div
    df -h
    s
  fi

  div
  if [ -f /usr/local/nginx/sbin/nginx ]; then
    /usr/local/nginx/sbin/nginx -V
  elif [ -f /usr/local/openresty/nginx/sbin/nginx ]; then
    /usr/local/openresty/nginx/sbin/nginx -V
  else
    nginx -V
  fi
  s
}

parsed() {
  # latency request
  echo
  # min
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-request:' | awk '{print $2}' > /tmp/latency-requests-min.txt
  # avg
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-request:' | awk '{print $4}' > /tmp/latency-requests-avg.txt
  # max
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-request:' | awk '{print $3}' > /tmp/latency-requests-max.txt
  paste -d ' ' /tmp/latency-requests-min.txt /tmp/latency-requests-avg.txt /tmp/latency-requests-max.txt > /tmp/latency-requests-parsed.txt

  # latency connect
  echo
  # min
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-connect:' | awk '{print $2}' > /tmp/latency-connect-min.txt
  # avg
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-connect:' | awk '{print $4}' > /tmp/latency-connect-avg.txt
  # max
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-connect:' | awk '{print $3}' > /tmp/latency-connect-max.txt
  paste -d ' ' /tmp/latency-connect-min.txt /tmp/latency-connect-avg.txt /tmp/latency-connect-max.txt > /tmp/latency-connect-parsed.txt

  # latency ttfb
  echo
  # min
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-ttfb:' | awk '{print $2}' > /tmp/latency-ttfb-min.txt
  # avg
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-ttfb:' | awk '{print $4}' > /tmp/latency-ttfb-avg.txt
  # max
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|time for request:|time-request:|g' -e 's|time for connect:|time-connect:|g' -e 's|time to 1st byte:|time-ttfb:|g' | grep 'time-ttfb:' | awk '{print $3}' > /tmp/latency-ttfb-max.txt
  paste -d ' ' /tmp/latency-ttfb-min.txt /tmp/latency-ttfb-avg.txt /tmp/latency-ttfb-max.txt > /tmp/latency-ttfb-parsed.txt

  # users
  echo
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|TLS Protocol:|Protocol:|g' -e 's|Server Temp Key|Server-Temp-Key|g' -e 's|Application protocol|Application-protocol|g' | grep -o '\-c.\{3\}' | grep -v '\-ciph' | sed -e 's|-c||g' -e 's| -||g' > /tmp/users.txt
  # requests
  echo
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' |  grep -A14 'h2load -t' | sed -e 's|TLS Protocol:|Protocol:|g' -e 's|Server Temp Key|Server-Temp-Key|g' -e 's|Application protocol|Application-protocol|g' | grep -o '\-n.\{4\}' | sed -e 's|-n||g' -e 's| ht||g' -e 's| h||g' > /tmp/requests.txt
  # encoding
  echo
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|TLS Protocol:|Protocol:|g' -e 's|Server Temp Key|Server-Temp-Key|g' -e 's|Application protocol|Application-protocol|g' | grep -o '\Accept-Encoding: .\{4\}' | sed -e 's|Accept-Encoding: ||g' > /tmp/encoding.txt
    # remove unwanted characters
  sed -i "s|'||g" /tmp/encoding.txt
  # started
  echo
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|TLS Protocol:|Protocol:|g' -e 's|Server Temp Key|Server-Temp-Key|g' -e 's|Application protocol|Application-protocol|g' | awk -F ', ' '/requests: / {print $2}' | sed -e 's| started||g' > /tmp/started.txt
  # succeeded
  echo
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|TLS Protocol:|Protocol:|g' -e 's|Server Temp Key|Server-Temp-Key|g' -e 's|Application protocol|Application-protocol|g' | awk -F ', ' '/requests: / {print $4}'| sed -e 's| succeeded||g' > /tmp/succeeded.txt
  # requests per sec
  echo
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|TLS Protocol:|Protocol:|g' -e 's|Server Temp Key|Server-Temp-Key|g' -e 's|Application protocol|Application-protocol|g' | awk -F ', ' '/finished in/ {print $2}' | sed -e 's| req\/s||g' | while read req; do if [ $req ]; then echo $req; else echo 0; fi; done > /tmp/rps.txt
  # protocol
  echo
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|TLS Protocol:|Protocol:|g' -e 's|Server Temp Key|Server-Temp-Key|g' -e 's|Application protocol|Application-protocol|g' | awk '/Protocol: / {print $2}' > /tmp/protocol.txt
  # cipher
  echo
  cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | grep -v 'Process Request Failure:' | grep -A14 'h2load -t' | sed -e 's|TLS Protocol:|Protocol:|g' -e 's|Server Temp Key|Server-Temp-Key|g' -e 's|Application protocol|Application-protocol|g' | awk '/Cipher: / {print $2}' > /tmp/cipher.txt
  echo "users requests req/s encoding cipher protocol started succeeded"
  paste -d ' ' /tmp/users.txt /tmp/requests.txt /tmp/rps.txt /tmp/encoding.txt /tmp/cipher.txt /tmp/protocol.txt /tmp/started.txt /tmp/succeeded.txt > /tmp/https_parsed.txt
  cat /tmp/https_parsed.txt

   if [[ "$NON_CENTMINMOD" = [nN] ]]; then
    if [[ -f $(which yum) && ! -f /usr/bin/datamash ]]; then
      yum -y -q install datamash
    fi
    if [[ -f /usr/bin/apt-get && ! -f /usr/bin/datamash ]]; then
      apt-get -y install datamash
    fi
    if [[ -f $(which yum) && ! -f /usr/bin/bc ]]; then
      yum -y -q install bc
    fi
    if [[ -f /usr/bin/apt-get && ! -f /usr/bin/bc ]]; then
      apt-get -y install bc
    fi
    parsed_sum=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 sum 1)
    parsed_sum=$(printf "%.0f\n" $parsed_sum)
    parsed_count=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 count 1)
    parsed_min=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 min 1)
    parsed_min=$(printf "%.3f\n" $parsed_min)
    # parsed_avg=$(($parsed_sum/$parsed_count))
    # parsed_avg=${parsed_avg:-0}
    parsed_max=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 max 1)
    parsed_max=$(printf "%.3f\n" $parsed_max)
    parsed_mean=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 mean 1)
    parsed_mean=$(printf "%.3f\n" $parsed_mean)
    parsed_stddev=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 sstdev 1)
    parsed_stddev=$(printf "%.3f\n" $parsed_stddev)
    parsed_started=$(cat /tmp/https_parsed.txt | awk '{print $7}' | datamash --no-strict --filler 0 mean 1)
    parsed_succeed=$(cat /tmp/https_parsed.txt | awk '{print $8}' | datamash --no-strict --filler 0 mean 1)
    # parsed_percsuccess=$((($parsed_succeed/$parsed_started)*100))
    parsed_percsuccess=$(echo "scale=2; $parsed_succeed/$parsed_started*100" | bc)
    parsed_percsuccess=$(printf "%.2f\n" $parsed_percsuccess)
    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load result summary"
    echo "min: avg: max: stddev: requests-succeeded:" > /tmp/https_parsed_datamash.txt
    echo "$parsed_min $parsed_mean $parsed_max $parsed_stddev $parsed_percsuccess" >> /tmp/https_parsed_datamash.txt
    cat /tmp/https_parsed_datamash.txt | column -t
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load result summary end"
  fi

  if [[ "$NON_CENTMINMOD" = [yY] ]]; then
    if [[ -f $(which yum) && ! -f /usr/bin/datamash ]]; then
      yum -y -q install datamash
    fi
    if [[ -f /usr/bin/apt-get && ! -f /usr/bin/datamash ]]; then
      apt-get -y install datamash
    fi
    if [[ -f $(which yum) && ! -f /usr/bin/bc ]]; then
      yum -y -q install bc
    fi
    if [[ -f /usr/bin/apt-get && ! -f /usr/bin/bc ]]; then
      apt-get -y install bc
    fi
    parsed_sum=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 sum 1)
    parsed_sum=$(printf "%.0f\n" $parsed_sum)
    parsed_count=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 count 1)
    parsed_min=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 min 1)
    parsed_min=$(printf "%.3f\n" $parsed_min)
    # parsed_avg=$(($parsed_sum/$parsed_count))
    # parsed_avg=${parsed_avg:-0}
    parsed_max=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 max 1)
    parsed_max=$(printf "%.3f\n" $parsed_max)
    parsed_mean=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 mean 1)
    parsed_mean=$(printf "%.3f\n" $parsed_mean)
    parsed_stddev=$(cat /tmp/https_parsed.txt | awk '{print $3}' | datamash --no-strict --filler 0 sstdev 1)
    parsed_stddev=$(printf "%.3f\n" $parsed_stddev)
    parsed_started=$(cat /tmp/https_parsed.txt | awk '{print $7}' | datamash --no-strict --filler 0 mean 1)
    parsed_succeed=$(cat /tmp/https_parsed.txt | awk '{print $8}' | datamash --no-strict --filler 0 mean 1)
    # parsed_percsuccess=$((($parsed_succeed/$parsed_started)*100))
    parsed_percsuccess=$(echo "scale=2; $parsed_succeed/$parsed_started*100" | bc)
    parsed_percsuccess=$(printf "%.2f\n" $parsed_percsuccess)
    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load result summary"
    echo "min: avg: max: stddev: requests-succeeded:" > /tmp/https_parsed_datamash.txt
    echo "$parsed_min $parsed_mean $parsed_max $parsed_stddev $parsed_percsuccess" >> /tmp/https_parsed_datamash.txt
    cat /tmp/https_parsed_datamash.txt | column -t
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load result summary end"

    echo
    echo "req-time-min req-time-avg req-time-max"
    cat /tmp/latency-requests-parsed.txt

    minreqtimeparsed_sum=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 sum 1)
    minreqtimeparsed_sum=$(printf "%.0f\n" $minreqtimeparsed_sum)
    minreqtimeparsed_count=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 count 1)
    minreqtimeparsed_min=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 min 1)
    minreqtimeparsed_min=$(printf "%.3f\n" $minreqtimeparsed_min)
    minreqtimeparsed_max=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 max 1)
    minreqtimeparsed_max=$(printf "%.3f\n" $minreqtimeparsed_max)
    minreqtimeparsed_mean=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 mean 1)
    minreqtimeparsed_mean=$(printf "%.3f\n" $minreqtimeparsed_mean)
    minreqtimeparsed_stddev=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 sstdev 1)
    minreqtimeparsed_stddev=$(printf "%.3f\n" $minreqtimeparsed_stddev)
    minreqtimeparsed_pca=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 perc:95 1)
    minreqtimeparsed_pca=$(printf "%.3f\n" $minreqtimeparsed_pca)
    minreqtimeparsed_pcb=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 perc:99 1)
    minreqtimeparsed_pcb=$(printf "%.3f\n" $minreqtimeparsed_pcb)

    avgreqtimeparsed_sum=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 sum 1)
    avgreqtimeparsed_sum=$(printf "%.0f\n" $avgreqtimeparsed_sum)
    avgreqtimeparsed_count=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 count 1)
    avgreqtimeparsed_min=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 min 1)
    avgreqtimeparsed_min=$(printf "%.3f\n" $avgreqtimeparsed_min)
    avgreqtimeparsed_max=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 max 1)
    avgreqtimeparsed_max=$(printf "%.3f\n" $avgreqtimeparsed_max)
    avgreqtimeparsed_mean=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 mean 1)
    avgreqtimeparsed_mean=$(printf "%.3f\n" $avgreqtimeparsed_mean)
    avgreqtimeparsed_stddev=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 sstdev 1)
    avgreqtimeparsed_stddev=$(printf "%.3f\n" $avgreqtimeparsed_stddev)
    avgreqtimeparsed_pca=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 perc:95 1)
    avgreqtimeparsed_pca=$(printf "%.3f\n" $avgreqtimeparsed_pca)
    avgreqtimeparsed_pcb=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 perc:99 1)
    avgreqtimeparsed_pcb=$(printf "%.3f\n" $avgreqtimeparsed_pcb)
  
    maxreqtimeparsed_sum=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 sum 1)
    maxreqtimeparsed_sum=$(printf "%.0f\n" $maxreqtimeparsed_sum)
    maxreqtimeparsed_count=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 count 1)
    maxreqtimeparsed_min=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 min 1)
    maxreqtimeparsed_min=$(printf "%.3f\n" $maxreqtimeparsed_min)
    maxreqtimeparsed_max=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 max 1)
    maxreqtimeparsed_max=$(printf "%.3f\n" $maxreqtimeparsed_max)
    maxreqtimeparsed_mean=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 mean 1)
    maxreqtimeparsed_mean=$(printf "%.3f\n" $maxreqtimeparsed_mean)
    maxreqtimeparsed_stddev=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 sstdev 1)
    maxreqtimeparsed_stddev=$(printf "%.3f\n" $maxreqtimeparsed_stddev)
    maxreqtimeparsed_pca=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 perc:95 1)
    maxreqtimeparsed_pca=$(printf "%.3f\n" $maxreqtimeparsed_pca)
    maxreqtimeparsed_pcb=$(cat /tmp/latency-requests-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 perc:99 1)
    maxreqtimeparsed_pcb=$(printf "%.3f\n" $maxreqtimeparsed_pcb)
    
    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load requests latency result summary"
    echo "req-min: req-avg: req-max: req-stddev: req-perc99-min: req-perc99-avg: req-perc99-max:" > /tmp/latency-requests-parsed_datamash.txt
    echo "$minreqtimeparsed_mean $avgreqtimeparsed_mean $maxreqtimeparsed_mean $avgreqtimeparsed_stddev $minreqtimeparsed_pcb $avgreqtimeparsed_pcb $maxreqtimeparsed_pcb" >> /tmp/latency-requests-parsed_datamash.txt
    cat /tmp/latency-requests-parsed_datamash.txt | column -t
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load requests latency result summary end"

    echo
    echo "connect-time-min connect-time-avg connect-time-max"
    cat /tmp/latency-connect-parsed.txt

    minconntimeparsed_sum=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 sum 1)
    minconntimeparsed_sum=$(printf "%.0f\n" $minconntimeparsed_sum)
    minconntimeparsed_count=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 count 1)
    minconntimeparsed_min=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 min 1)
    minconntimeparsed_min=$(printf "%.3f\n" $minconntimeparsed_min)
    minconntimeparsed_max=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 max 1)
    minconntimeparsed_max=$(printf "%.3f\n" $minconntimeparsed_max)
    minconntimeparsed_mean=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 mean 1)
    minconntimeparsed_mean=$(printf "%.3f\n" $minconntimeparsed_mean)
    minconntimeparsed_stddev=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 sstdev 1)
    minconntimeparsed_stddev=$(printf "%.3f\n" $minconntimeparsed_stddev)
    minconntimeparsed_pca=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 perc:95 1)
    minconntimeparsed_pca=$(printf "%.3f\n" $minconntimeparsed_pca)
    minconntimeparsed_pcb=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 perc:99 1)
    minconntimeparsed_pcb=$(printf "%.3f\n" $minconntimeparsed_pcb)

    avgconntimeparsed_sum=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 sum 1)
    avgconntimeparsed_sum=$(printf "%.0f\n" $avgconntimeparsed_sum)
    avgconntimeparsed_count=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 count 1)
    avgconntimeparsed_min=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 min 1)
    avgconntimeparsed_min=$(printf "%.3f\n" $avgconntimeparsed_min)
    avgconntimeparsed_max=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 max 1)
    avgconntimeparsed_max=$(printf "%.3f\n" $avgconntimeparsed_max)
    avgconntimeparsed_mean=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 mean 1)
    avgconntimeparsed_mean=$(printf "%.3f\n" $avgconntimeparsed_mean)
    avgconntimeparsed_stddev=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 sstdev 1)
    avgconntimeparsed_stddev=$(printf "%.3f\n" $avgconntimeparsed_stddev)
    avgconntimeparsed_pca=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 perc:95 1)
    avgconntimeparsed_pca=$(printf "%.3f\n" $avgconntimeparsed_pca)
    avgconntimeparsed_pcb=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 perc:99 1)
    avgconntimeparsed_pcb=$(printf "%.3f\n" $avgconntimeparsed_pcb)
  
    maxconntimeparsed_sum=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 sum 1)
    maxconntimeparsed_sum=$(printf "%.0f\n" $maxconntimeparsed_sum)
    maxconntimeparsed_count=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 count 1)
    maxconntimeparsed_min=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 min 1)
    maxconntimeparsed_min=$(printf "%.3f\n" $maxconntimeparsed_min)
    maxconntimeparsed_max=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 max 1)
    maxconntimeparsed_max=$(printf "%.3f\n" $maxconntimeparsed_max)
    maxconntimeparsed_mean=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 mean 1)
    maxconntimeparsed_mean=$(printf "%.3f\n" $maxconntimeparsed_mean)
    maxconntimeparsed_stddev=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 sstdev 1)
    maxconntimeparsed_stddev=$(printf "%.3f\n" $maxconntimeparsed_stddev)
    maxconntimeparsed_pca=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 perc:95 1)
    maxconntimeparsed_pca=$(printf "%.3f\n" $maxconntimeparsed_pca)
    maxconntimeparsed_pcb=$(cat /tmp/latency-connect-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 perc:99 1)
    maxconntimeparsed_pcb=$(printf "%.3f\n" $maxconntimeparsed_pcb)

    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load connect latency result summary"
    echo "connect-min: connect-avg: connect-max: connect-stddev: connect-perc99-min: connect-perc99-avg: connect-perc99-max:" > /tmp/latency-connect-parsed_datamash.txt
    echo "$minconntimeparsed_mean $avgconntimeparsed_mean $maxconntimeparsed_mean $avgconntimeparsed_stddev $minconntimeparsed_pcb $avgconntimeparsed_pcb $maxconntimeparsed_pcb" >> /tmp/latency-connect-parsed_datamash.txt
    cat /tmp/latency-connect-parsed_datamash.txt | column -t
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load connect latency result summary end"
  
    echo
    echo "ttfb-time-min ttfb-time-avg ttfb-time-max"
    cat /tmp/latency-ttfb-parsed.txt

    minttfbtimeparsed_sum=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 sum 1)
    minttfbtimeparsed_sum=$(printf "%.0f\n" $minttfbtimeparsed_sum)
    minttfbtimeparsed_count=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 count 1)
    minttfbtimeparsed_min=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 min 1)
    minttfbtimeparsed_min=$(printf "%.3f\n" $minttfbtimeparsed_min)
    minttfbtimeparsed_max=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 max 1)
    minttfbtimeparsed_max=$(printf "%.3f\n" $minttfbtimeparsed_max)
    minttfbtimeparsed_mean=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 mean 1)
    minttfbtimeparsed_mean=$(printf "%.3f\n" $minttfbtimeparsed_mean)
    minttfbtimeparsed_stddev=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 sstdev 1)
    minttfbtimeparsed_stddev=$(printf "%.3f\n" $minttfbtimeparsed_stddev)
    minttfbtimeparsed_pca=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 perc:95 1)
    minttfbtimeparsed_pca=$(printf "%.3f\n" $minttfbtimeparsed_pca)
    minttfbtimeparsed_pcb=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $1}' | datamash --no-strict --filler 0 perc:99 1)
    minttfbtimeparsed_pcb=$(printf "%.3f\n" $minttfbtimeparsed_pcb)

    avgttfbtimeparsed_sum=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 sum 1)
    avgttfbtimeparsed_sum=$(printf "%.0f\n" $avgttfbtimeparsed_sum)
    avgttfbtimeparsed_count=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 count 1)
    avgttfbtimeparsed_min=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 min 1)
    avgttfbtimeparsed_min=$(printf "%.3f\n" $avgttfbtimeparsed_min)
    avgttfbtimeparsed_max=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 max 1)
    avgttfbtimeparsed_max=$(printf "%.3f\n" $avgttfbtimeparsed_max)
    avgttfbtimeparsed_mean=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 mean 1)
    avgttfbtimeparsed_mean=$(printf "%.3f\n" $avgttfbtimeparsed_mean)
    avgttfbtimeparsed_stddev=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 sstdev 1)
    avgttfbtimeparsed_stddev=$(printf "%.3f\n" $avgttfbtimeparsed_stddev)
    avgttfbtimeparsed_pca=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 perc:95 1)
    avgttfbtimeparsed_pca=$(printf "%.3f\n" $avgttfbtimeparsed_pca)
    avgttfbtimeparsed_pcb=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $2}' | datamash --no-strict --filler 0 perc:99 1)
    avgttfbtimeparsed_pcb=$(printf "%.3f\n" $avgttfbtimeparsed_pcb)
  
    maxttfbtimeparsed_sum=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 sum 1)
    maxttfbtimeparsed_sum=$(printf "%.0f\n" $maxttfbtimeparsed_sum)
    maxttfbtimeparsed_count=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 count 1)
    maxttfbtimeparsed_min=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 min 1)
    maxttfbtimeparsed_min=$(printf "%.3f\n" $maxttfbtimeparsed_min)
    maxttfbtimeparsed_max=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 max 1)
    maxttfbtimeparsed_max=$(printf "%.3f\n" $maxttfbtimeparsed_max)
    maxttfbtimeparsed_mean=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 mean 1)
    maxttfbtimeparsed_mean=$(printf "%.3f\n" $maxttfbtimeparsed_mean)
    maxttfbtimeparsed_stddev=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 sstdev 1)
    maxttfbtimeparsed_stddev=$(printf "%.3f\n" $maxttfbtimeparsed_stddev)
    maxttfbtimeparsed_pca=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 perc:95 1)
    maxttfbtimeparsed_pca=$(printf "%.3f\n" $maxttfbtimeparsed_pca)
    maxttfbtimeparsed_pcb=$(cat /tmp/latency-ttfb-parsed.txt | sed -e 's|ms||g' -e 's|us||g' -e 's|s||g' | awk '{print $3}' | datamash --no-strict --filler 0 perc:99 1)
    maxttfbtimeparsed_pcb=$(printf "%.3f\n" $maxttfbtimeparsed_pcb)

    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load ttfb latency result summary"
    echo "ttfb-min: ttfb-avg: ttfb-max: ttfb-stddev: ttfb-perc99-min: ttfb-perc99-avg: ttfb-perc99-max:" > /tmp/latency-ttfb-parsed_datamash.txt
    echo "$minttfbtimeparsed_mean $avgttfbtimeparsed_mean $maxttfbtimeparsed_mean $avgttfbtimeparsed_stddev $minttfbtimeparsed_pcb $avgttfbtimeparsed_pcb $maxttfbtimeparsed_pcb" >> /tmp/latency-ttfb-parsed_datamash.txt
    cat /tmp/latency-ttfb-parsed_datamash.txt | column -t
    echo "-------------------------------------------------------------------------------------------"
    echo "h2load ttfb latency result summary end"

  fi
  rm -rf /tmp/users.txt /tmp/requests.txt /tmp/rps.txt /tmp/encoding.txt /tmp/cipher.txt /tmp/protocol.txt /tmp/started.txt /tmp/succeeded.txt /tmp/https_parsed.txt /tmp/https_parsed_datamash.txt
  rm -rf /tmp/latency-requests-min.txt /tmp/latency-requests-avg.txt /tmp/latency-requests-max.txt
  rm -rf /tmp/latency-connect-min.txt /tmp/latency-connect-avg.txt /tmp/latency-connect-max.txt
  rm -rf /tmp/latency-ttfb-min.txt /tmp/latency-ttfb-avg.txt /tmp/latency-ttfb-max.txt
  rm -rf /tmp/latency-requests-parsed.txt /tmp/latency-connect-parsed.txt /tmp/latency-connect-parsed.txt
}

https_benchmark() {
  if [[ "$NON_CENTMINMOD" = [nN] ]]; then
    s
    div
    cecho "setup & benchmark nginx http/2 https vhost: https://$vhostname" $boldyellow
    div
    s
    cecho "setup temp entry in /etc/hosts" $boldyellow
    if [[ -f /usr/bin/systemd-detect-virt && "$(/usr/bin/systemd-detect-virt)" = 'lxc' ]]; then
      # for lxd guest containers
      SERVERIP=$(hostname -I | awk '{print $1}')
    else
      SERVERIP=$(curl -4s https://ipinfo.io/ip)
    fi
  fi

if [[ "$NON_CENTMINMOD" = [nN] ]]; then
  if [[ ! $(grep "$SERVERIP $vhostname #h2load" /etc/hosts) ]]; then
    echo "$SERVERIP $vhostname #h2load" >> /etc/hosts
  fi
  grep 'h2load' /etc/hosts | sed -e "s|$SERVERIP|server-ip-mask|"
  s
  if [[ "$(ps aufx | grep -v grep | grep 'pure-ftpd' 2>&1>/dev/null; echo $?)" = '0' && ! -f /usr/local/nginx/conf/ssl_ecc.conf ]]; then
    echo "nv -d $vhostname -s y -u \"ftpu\$(pwgen -1cnys 31)\""
    echo
    echo "creating http2.domain.com Nginx vhost..."
    nv -d $vhostname -s y -u "ftpu$(pwgen -1cnys 31)" 2>&1 | sed -e "s|$CNIP|xxx.xxx.xxx.xxx|g" -e 's|FTP username created for http2.domain.com : .*|FTP username created for http2.domain.com : ******|g' -e 's|FTP password created for http2.domain.com : .*|FTP password created for http2.domain.com : ******|g'
  elif [[ ! -f /usr/local/nginx/conf/ssl_ecc.conf ]]; then
    echo "nv -d $vhostname -s y"
    echo
    echo "creating http2.domain.com Nginx vhost..."
    nv -d $vhostname -s y 2>&1 | sed -e "s|$CNIP|xxx.xxx.xxx.xxx|g" -e 's|FTP username created for http2.domain.com : .*|FTP username created for http2.domain.com : ******|g' -e 's|FTP password created for http2.domain.com : .*|FTP password created for http2.domain.com : ******|g'
  fi
  s
  
  if [ ! -f /usr/bin/h2load ]; then
  echo "yum -y -q install nghttp2"
  yum -y -q install nghttp2
  s
  fi
  
  if [ ! -f "/usr/local/nginx/conf/ssl/${vhostname}/${vhostname}-ecc.crt" ]; then
    echo "setup ECDSA SSL self-signed certificate"
    s
    SELFSIGNEDSSL_C='US'
    SELFSIGNEDSSL_ST='California'
    SELFSIGNEDSSL_L='Los Angeles'
    SELFSIGNEDSSL_O='HTTPS TEST ORG'
    SELFSIGNEDSSL_OU='HTTPS TEST ORG UNIT'

# self-signed ssl cert with SANs
cat > /tmp/req.cnf <<EOF
[req]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt = no
[req_distinguished_name]
C = ${SELFSIGNEDSSL_C}
ST = ${SELFSIGNEDSSL_ST}
L = ${SELFSIGNEDSSL_L}
O = ${vhostname}
OU = ${vhostname}
CN = ${vhostname}
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${vhostname}
DNS.2 = www.${vhostname}
EOF

cat > /tmp/v3ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${vhostname}
DNS.2 = www.${vhostname}
EOF
    
    cd /usr/local/nginx/conf/ssl/${vhostname}
    curve=prime256v1
    echo "openssl ecparam -out ${vhostname}-ecc.key -name $curve -genkey"
    openssl ecparam -out ${vhostname}-ecc.key -name $curve -genkey
    echo "openssl req -new -sha256 -key ${vhostname}-ecc.key -nodes -out ${vhostname}-ecc.csr -config /tmp/req.cnf"
    openssl req -new -sha256 -key ${vhostname}-ecc.key -nodes -out ${vhostname}-ecc.csr -config /tmp/req.cnf
    # echo "openssl req -new -sha256 -key ${vhostname}-ecc.key -nodes -out ${vhostname}-ecc.csr -subj \"/C=${SELFSIGNEDSSL_C}/ST=${SELFSIGNEDSSL_ST}/L=${SELFSIGNEDSSL_L}/O=${SELFSIGNEDSSL_O}/OU=${SELFSIGNEDSSL_OU}/CN=${vhostname}\""
    # openssl req -new -sha256 -key ${vhostname}-ecc.key -nodes -out ${vhostname}-ecc.csr -subj "/C=${SELFSIGNEDSSL_C}/ST=${SELFSIGNEDSSL_ST}/L=${SELFSIGNEDSSL_L}/O=${SELFSIGNEDSSL_O}/OU=${SELFSIGNEDSSL_OU}/CN=${vhostname}"
    openssl req -noout -text -in ${vhostname}-ecc.csr | grep DNS
    echo "openssl x509 -req -days 36500 -sha256 -in ${vhostname}-ecc.csr -signkey ${vhostname}-ecc.key -out ${vhostname}-ecc.crt -extfile /tmp/v3ext.cnf"
    openssl x509 -req -days 36500 -sha256 -in ${vhostname}-ecc.csr -signkey ${vhostname}-ecc.key -out ${vhostname}-ecc.crt -extfile /tmp/v3ext.cnf
    s
    ls -lah /usr/local/nginx/conf/ssl/${vhostname}
    s
    
    echo "  ssl_certificate      /usr/local/nginx/conf/ssl/${vhostname}/${vhostname}-ecc.crt;
      ssl_certificate_key  /usr/local/nginx/conf/ssl/${vhostname}/${vhostname}-ecc.key;" > /usr/local/nginx/conf/ssl_ecc.conf
    cat /usr/local/nginx/conf/ssl_ecc.conf
    
    if [[ ! "$(grep 'ssl_ecc.conf' /usr/local/nginx/conf/conf.d/${vhostname}.ssl.conf)" ]]; then
    sed -i "s|include \/usr\/local\/nginx\/conf\/ssl_include.conf;|\ninclude \/usr\/local\/nginx\/conf\/ssl_include.conf;\ninclude \/usr\/local\/nginx\/conf\/ssl_ecc.conf;|" /usr/local/nginx/conf/conf.d/${vhostname}.ssl.conf
    fi
    ngxrestart >/dev/null 2>&1
  fi
fi # NON_CENTMINMOD = N

{
baseinfo
s
echo "-------------------------------------------------------------------------------------------"
echo "h2load --version"
h2load --version
echo "-------------------------------------------------------------------------------------------"
if [[ "$NON_CENTMINMOD" = [nN] ]]; then
  if [[ "$TEST_RSA" = [yY] ]]; then
    s
    nginx_stats
    sar_stats
    stats
    check_crypto
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
    s
    # nginx_stats
    # sar_stats
    # stats
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
  fi
  if [[ "$TEST_ECDSA" = [yY] ]]; then
    s
    # nginx_stats
    # sar_stats
    # stats
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
    s
    # nginx_stats
    # sar_stats
    # stats
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
  fi
fi
  testa_gziprepeat() {
  s
  echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
  h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
  ngxrestart >/dev/null 2>&1
  sleep $SLEEP_TIME
  echo "-------------------------------------------------------------------------------------------"
  }
  if [[ "$NON_CENTMINMODTESTA" = [yY] && "$NON_CENTMINMOD" = [yY] ]]; then
    for (( i=1; i<=$TESTRUNS; i++ ))
      do
      nginx_stats
      sar_stats
      stats
      check_crypto
      echo "Test Run: $i ($(hostname -s)) $SAR_STARTTIME"
      testa_gziprepeat
      if [[ "$SARSTATS" = [yY] ]]; then
        kill $getsar_pid
        wait $getsar_pid 2>/dev/null
      fi
    done
  fi
if [[ "$NON_CENTMINMOD" = [nN] ]]; then
  if [[ "$TEST_RSA" = [yY] ]]; then
    s
    # nginx_stats
    # sar_stats
    # stats
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
    s
    # nginx_stats
    # sar_stats
    # stats
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
  fi
  if [[ "$TEST_ECDSA" = [yY] ]]; then
    s
    # nginx_stats
    # sar_stats
    # stats
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
    s
    # nginx_stats
    # sar_stats
    # stats
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
  fi
fi
  testb_gziprepeat() {
  s
  echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
  h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
  ngxrestart >/dev/null 2>&1
  sleep $SLEEP_TIME
  echo "-------------------------------------------------------------------------------------------"
  }
  if [[ "$NON_CENTMINMODTESTB" = [yY] && "$NON_CENTMINMOD" = [yY] ]]; then
    for (( i=1; i<=$TESTRUNS; i++ ))
      do
      nginx_stats
      sar_stats
      stats
      check_crypto
      echo "Test Run: $i ($(hostname -s)) $SAR_STARTTIME"
      testb_gziprepeat
      if [[ "$SARSTATS" = [yY] ]]; then
        kill $getsar_pid
        wait $getsar_pid 2>/dev/null
      fi
    done
  fi
if [[ "$(nginx -V 2>&1 | grep -o 'brotli')" = 'brotli' ]]; then
  if [[ "$NON_CENTMINMOD" = [nN] ]]; then
    if [[ "$TEST_RSA" = [yY] ]]; then
      s
      stats
      check_crypto
      echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
      h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
      ngxrestart >/dev/null 2>&1
      sleep $SLEEP_TIME
      echo "-------------------------------------------------------------------------------------------"
      s
      stats
      check_crypto
      echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
      h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
      ngxrestart >/dev/null 2>&1
      sleep $SLEEP_TIME
      echo "-------------------------------------------------------------------------------------------"
    fi
    if [[ "$TEST_ECDSA" = [yY] ]]; then
      s
      stats
      check_crypto
      echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
      h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
      ngxrestart >/dev/null 2>&1
      sleep $SLEEP_TIME
      echo "-------------------------------------------------------------------------------------------"
      s
      stats
      check_crypto
      echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
      h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
      ngxrestart >/dev/null 2>&1
      sleep $SLEEP_TIME
      echo "-------------------------------------------------------------------------------------------"
    fi
  fi
  testa_brrepeat() {
  s
  echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile}"
  h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
  ngxrestart >/dev/null 2>&1
  sleep $SLEEP_TIME
  echo "-------------------------------------------------------------------------------------------"
  }
  if [[ "$NON_CENTMINMODTESTA" = [yY] && "$NON_CENTMINMOD" = [yY] ]]; then
    for (( i=1; i<=$TESTRUNS; i++ ))
      do
      nginx_stats
      sar_stats
      stats
      check_crypto
      echo "Test Run: $i ($(hostname -s)) $SAR_STARTTIME"
      testa_brrepeat
      if [[ "$SARSTATS" = [yY] ]]; then
        kill $getsar_pid
        wait $getsar_pid 2>/dev/null
      fi
    done
  fi
if [[ "$NON_CENTMINMOD" = [nN] ]]; then
  if [[ "$TEST_RSA" = [yY] ]]; then
    s
    nginx_stats
    sar_stats
    stats
    check_crypto
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
    s
    nginx_stats
    sar_stats
    stats
    check_crypto
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
  fi
  if [[ "$TEST_ECDSA" = [yY] ]]; then
    s
    nginx_stats
    sar_stats
    stats
    check_crypto
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
    s
    nginx_stats
    sar_stats
    stats
    check_crypto
    echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
    h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
    ngxrestart >/dev/null 2>&1
    sleep $SLEEP_TIME
    echo "-------------------------------------------------------------------------------------------"
  fi
fi
  testb_brrepeat() {
  s
  echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile}"
  h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname/${htwo_testfile} | egrep -v 'progress: |starting|spawning'
  ngxrestart >/dev/null 2>&1
  sleep $SLEEP_TIME
  echo "-------------------------------------------------------------------------------------------"
  }
  if [[ "$NON_CENTMINMODTESTB" = [yY] && "$NON_CENTMINMOD" = [yY] ]]; then
    for (( i=1; i<=$TESTRUNS; i++ ))
      do
      nginx_stats
      sar_stats
      stats
      check_crypto
      echo "Test Run: $i ($(hostname -s)) $SAR_STARTTIME"
      testb_brrepeat
      if [[ "$SARSTATS" = [yY] ]]; then
        kill $getsar_pid
        wait $getsar_pid 2>/dev/null
      fi
    done
  fi
fi
if [[ "$SARSTATS" = [yY] ]]; then
  kill $getsar_pid
  wait $getsar_pid 2>/dev/null
fi
if [[ "$NGINX_STATS" = [yY] && -d "/home/nginx/domains/${vhostname}/log" ]]; then
  kill $getngxstat_pid
  wait $getngxstat_pid 2>/dev/null
fi
if [[ "$NON_CENTMINMOD" = [nN] && "$SARSTATS" = [yY] ]]; then
  s
  echo "-------------------------------------------------------------------------------------------"
  echo "h2load load statistics"
  echo "-------------------------------------------------------------------------------------------"
  echo "sar -q -s $SAR_STARTTIME"
  sar -q -s $SAR_STARTTIME | sed -e "s|$(hostname -f)|hostname|"
  echo "-------------------------------------------------------------------------------------------"
  echo "sar -r -s $SAR_STARTTIME"
  sar -r -s $SAR_STARTTIME | sed -e "s|$(hostname -f)|hostname|"
  echo "-------------------------------------------------------------------------------------------"
fi
s
if [[ "$NON_CENTMINMOD" = [nN] ]]; then
  echo "h2load tests completed using temp /etc/hosts entry:"
  grep 'h2load' /etc/hosts | sed -e "s|$SERVERIP|server-ip-mask|"
  if [ -d /usr/local/src/centminmod/.git ]; then
    s
    echo "centmin mod local code last commit:"
    pushd /usr/local/src/centminmod >/dev/null 2>&1
    git log --pretty="%n%h %an %aD %n%s" -1
    popd >/dev/null 2>&1
  fi
fi
} 2>&1 | tee "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log"

echo
{
parsed
} 2>&1 | sed '/^\s*$/d' | tee -a "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log"

}

cleanup() {
  if [[ "$HTTPS_BENCHCLEANUP" = [yY] ]]; then
    s
    echo "clean up https://$vhostname"
    if [[ "$(ps aufx | grep -v grep | grep 'pure-ftpd' 2>&1>/dev/null; echo $?)" = '0' ]]; then
      cecho "pure-pw userdel $ftpuser" $boldwhite
      pure-pw userdel $ftpuser
    fi
    cecho "rm -rf /usr/local/nginx/conf/conf.d/$vhostname.conf" $boldwhite
    rm -rf /usr/local/nginx/conf/conf.d/$vhostname.conf
    cecho "rm -rf /usr/local/nginx/conf/conf.d/${vhostname}.ssl.conf" $boldwhite
    rm -rf /usr/local/nginx/conf/conf.d/${vhostname}.ssl.conf
    cecho "rm -rf /usr/local/nginx/conf/ssl/${vhostname}" $boldwhite
    rm -rf /usr/local/nginx/conf/ssl/${vhostname}
    cecho "rm -rf /usr/local/nginx/conf/ssl_ecc.conf" $boldwhite
    rm -rf /usr/local/nginx/conf/ssl_ecc.conf
    cecho "rm -rf /home/nginx/domains/$vhostname" $boldwhite
    rm -rf /home/nginx/domains/$vhostname
    #cecho "rm -rf /root/.acme.sh/$vhostname" $boldwhite
    #rm -rf /root/.acme.sh/$vhostname
    #cecho "rm -rf /root/.acme.sh/${vhostname}_ecc" $boldwhite
    #rm -rf /root/.acme.sh/${vhostname}_ecc
    cecho "rm -rf /usr/local/nginx/conf/pre-staticfiles-local-${vhostname}.conf" $boldwhite
    rm -rf /usr/local/nginx/conf/pre-staticfiles-local-${vhostname}.conf
    s
    sed -i '/#h2load/d' /etc/hosts
    cecho "service nginx restart" $boldwhite
    ngxrestart >/dev/null 2>&1
  fi
}

trap cleanup SIGHUP SIGINT SIGTERM

######################################################
starttime=$(TZ=UTC date +%s.%N)
{
  https_benchmark
  cleanup
  s
  echo "benchmark run complete"
  echo "result log: ${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log"
} 2>&1 | tee "${CENTMINLOGDIR}/https-benchmark-all-${DT}.log"

endtime=$(TZ=UTC date +%s.%N)

INSTALLTIME=$(echo "scale=2;$endtime - $starttime"|bc )
echo "" >> "${CENTMINLOGDIR}/https-benchmark-all-${DT}.log"
echo "https_bench.sh Total Run Time: $INSTALLTIME seconds" >> "${CENTMINLOGDIR}/https-benchmark-all-${DT}.log"

if [[ "$CMBEMAIL" = [yY] ]]; then
  echo "https_bench.sh completed for $(hostname -f)" | mail -s "$(hostname -f) https_bench.sh completed $(date)" $CMEBMAIL_ADDR
fi

exit