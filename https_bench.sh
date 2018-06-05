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
VER='0.3'
SLEEP_TIME='20'
HTTPS_BENCHCLEANUP='y'

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
SARSTATS='y'
NGINX_STATS='n'
###############################################################
vhostname=http2.domain.com
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
if [ ! -d /usr/local/nginx/conf/conf.d ]; then
  echo
  echo "Centmin Mod directory not found"
  echo "/usr/local/nginx/conf/conf.d/ is missing"
  echo
  exit
fi

if [ -f https_bench.ini ]; then
  . https_bench.ini
fi

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
    if [[ "$(uname -m)" = 'x86_64' || "$(uname -m)" = 'aarch64' ]]; then
      SARCALL='/usr/lib64/sa/sa1'
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

  cat /etc/redhat-release
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
  
  div
  df -h
  s

  div
  nginx -V
  s
}

https_benchmark() {
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

if [[ ! $(grep "$SERVERIP $vhostname #h2load" /etc/hosts) ]]; then
  echo "$SERVERIP $vhostname #h2load" >> /etc/hosts
fi
grep 'h2load' /etc/hosts | sed -e "s|$SERVERIP|server-ip-mask|"
s
if [[ "$(ps aufx | grep -v grep | grep 'pure-ftpd' 2>&1>/dev/null; echo $?)" = '0' && ! -f /usr/local/nginx/conf/ssl_ecc.conf ]]; then
  echo "nv -d $vhostname -s y -u \"ftpu\$(pwgen -1cnys 31)\""
  nv -d $vhostname -s y -u "ftpu$(pwgen -1cnys 31)"
elif [[ ! -f /usr/local/nginx/conf/ssl_ecc.conf ]]; then
  echo "nv -d $vhostname -s y"
  nv -d $vhostname -s y
fi
s

if [ ! -f /usr/bin/h2load ]; then
echo "yum -y -q install nghttp2"
yum -y -q install nghttp2
s
fi

echo "setup ECDSA SSL self-signed certificate"
s
SELFSIGNEDSSL_C='US'
SELFSIGNEDSSL_ST='California'
SELFSIGNEDSSL_L='Los Angeles'
SELFSIGNEDSSL_O='HTTPS TEST ORG'
SELFSIGNEDSSL_OU='HTTPS TEST ORG UNIT'

cd /usr/local/nginx/conf/ssl/${vhostname}
curve=prime256v1
echo "openssl ecparam -out ${vhostname}-ecc.key -name $curve -genkey"
openssl ecparam -out ${vhostname}-ecc.key -name $curve -genkey
echo "openssl req -new -sha256 -key ${vhostname}-ecc.key -nodes -out ${vhostname}-ecc.csr -subj \"/C=${SELFSIGNEDSSL_C}/ST=${SELFSIGNEDSSL_ST}/L=${SELFSIGNEDSSL_L}/O=${SELFSIGNEDSSL_O}/OU=${SELFSIGNEDSSL_OU}/CN=${vhostname}\""
openssl req -new -sha256 -key ${vhostname}-ecc.key -nodes -out ${vhostname}-ecc.csr -subj "/C=${SELFSIGNEDSSL_C}/ST=${SELFSIGNEDSSL_ST}/L=${SELFSIGNEDSSL_L}/O=${SELFSIGNEDSSL_O}/OU=${SELFSIGNEDSSL_OU}/CN=${vhostname}"
echo "openssl x509 -req -days 36500 -sha256 -in ${vhostname}-ecc.csr -signkey ${vhostname}-ecc.key -out ${vhostname}-ecc.crt"
openssl x509 -req -days 36500 -sha256 -in ${vhostname}-ecc.csr -signkey ${vhostname}-ecc.key -out ${vhostname}-ecc.crt
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

{
baseinfo
s
echo "-------------------------------------------------------------------------------------------"
echo "h2load --version"
h2load --version
echo "-------------------------------------------------------------------------------------------"
s
nginx_stats
sar_stats
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
stats
if [[ "$(nginx -V 2>&1 | grep -o 'brotli')" = 'brotli' ]]; then
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTA_USERS} -n${TESTA_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "-------------------------------------------------------------------------------------------"
s
stats
echo "h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname"
h2load -t${HTWOLOAD_THREADS} --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c${TESTB_USERS} -n${TESTB_REQUESTS} https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
stats
fi
if [[ "$SARSTATS" = [yY] ]]; then
  kill $getsar_pid
  wait $getsar_pid 2>/dev/null
fi
if [[ "$NGINX_STATS" = [yY] && -d "/home/nginx/domains/${vhostname}/log" ]]; then
  kill $getngxstat_pid
  wait $getngxstat_pid 2>/dev/null
fi
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
s
echo "h2load tests completed using temp /etc/hosts entry:"
grep 'h2load' /etc/hosts | sed -e "s|$SERVERIP|server-ip-mask|"
if [ -d /usr/local/src/centminmod/.git ]; then
  s
  echo "centmin mod local code last commit:"
  pushd /usr/local/src/centminmod >/dev/null 2>&1
  git log --pretty="%n%h %an %aD %n%s" -1
  popd >/dev/null 2>&1
fi
} 2>&1 | tee "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log"

# s
# cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | egrep -v 'progress: |starting|spawning'
# s
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