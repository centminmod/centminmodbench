#!/bin/bash
######################################################
# written by George Liu (eva2000) centminmod.com
# when ran with command
# curl -sL https://github.com/centminmod/centminmodbench/raw/master/installnbench2.sh | bash
# runs 5 tasks
# 1) install latest Centmin Mod Beta LEMP stack
# 2) installs and runs centminmodbench.sh (UnixBench enabled)
# 3) install & run zcat/pzcat benchmarks
# 4) setup & benchmark nginx http/2 https vhost
# 5) redis benchmarks
######################################################
# variables
#############
DT=$(date +"%d%m%y-%H%M%S")
SLEEP_TIME='20'

CMBEMAIL='n'
CMEBMAIL_ADDR=''
CENTMINLOGDIR='/root/centminlogs'
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

if [ -f centminmodbench.ini ]; then
  . centminmodbench.ini
fi

div() {
	cecho "----------------------------------------------" $boldgreen
}

s() {
	echo
}

benchninstall() {

s
div
cecho "5 tasks will be performaned which can take up to 45-90 mins" $boldyellow
cecho "1). install latest Centmin Mod Beta LEMP stack ~15-30 mins" $boldyellow
cecho "2). installs & runs centminmodbench.sh (UnixBench enabled) ~30-60 mins" $boldyellow
cecho "3). install & run zcat/pzcat benchmarks" $boldyellow
cecho "4). setup & benchmark nginx http/2 https vhost" $boldyellow
cecho "5). redis benchmarks" $boldyellow
div
s

s
div
cecho "installing Centmin Mod Beta LEMP stack" $boldyellow
cecho "will take ~15-30 minutes" $boldyellow
div
s
echo "yum -y update; curl -O https://centminmod.com/betainstaller.sh && chmod 0700 betainstaller.sh && bash betainstaller.sh"
yum -y update; curl -O https://centminmod.com/betainstaller.sh && chmod 0700 betainstaller.sh && bash betainstaller.sh

s
div
cecho "installing centminmodbench.sh & running benchmarks" $boldyellow
cecho "will take ~30-60 minutes" $boldyellow
div
s
mkdir -p /root/tools
cd /root/tools
wget -O centminmodbench.sh https://github.com/centminmod/centminmodbench/raw/master/centminmodbench.sh
chmod +x centminmodbench.sh
sed -i "s/RUN_UNIXBENCH='n'/RUN_UNIXBENCH='y'/g" centminmodbench.sh
./centminmodbench.sh

s
div
cecho "install & run zcat/pzcat benchmarks" $boldyellow
cecho "https://community.centminmod.com/threads/14650/" $boldyellow
div
s
mkdir -p /root/tools
cd /root/tools
git clone https://github.com/centminmod/fake-access-logs
cd fake-access-logs
./test.sh zcat
if [ "$(nproc)" -ge 2 ]; then
./test.sh pzcat
fi

s
div
cecho "setup & benchmark nginx http/2 https vhost" $boldyellow
div
s
vhostname=http2.domain.com
echo "$(curl -4s ipinfo.io/ip) $vhostname" >> /etc/hosts
s
echo "nv -d $vhostname -s y -u \"ftpu\$(pwgen -1cnys 31)\""
nv -d $vhostname -s y -u "ftpu$(pwgen -1cnys 31)"
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

sed -i "s|include \/usr\/local\/nginx\/conf\/ssl_include.conf;|\ninclude \/usr\/local\/nginx\/conf\/ssl_include.conf;\ninclude \/usr\/local\/nginx\/conf\/ssl_ecc.conf;|" /usr/local/nginx/conf/conf.d/${vhostname}.ssl.conf
ngxreload >/dev/null 2>&1

{
s
echo "------------------------------------------------------------------------"
echo "h2load --version"
h2load --version
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c100 -n1000 https://$vhostname"
h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c100 -n1000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c100 -n1000 https://$vhostname"
h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c100 -n1000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c100 -n1000 https://$vhostname"
h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c100 -n1000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c100 -n1000 https://$vhostname"
h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c100 -n1000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c200 -n5000 https://$vhostname"
h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c200 -n5000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c200 -n5000 https://$vhostname"
h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c200 -n5000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c200 -n5000 https://$vhostname"
h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c200 -n5000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c200 -n5000 https://$vhostname"
h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c200 -n5000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
if [[ "$(nginx -V 2>&1 | grep -o 'brotli')" = 'brotli' ]]; then
s
echo "h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c100 -n1000 https://$vhostname"
h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c100 -n1000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c100 -n1000 https://$vhostname"
h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c100 -n1000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c100 -n1000 https://$vhostname"
h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c100 -n1000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c100 -n1000 https://$vhostname"
h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c100 -n1000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c200 -n5000 https://$vhostname"
h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c200 -n5000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c200 -n5000 https://$vhostname"
h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c200 -n5000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c200 -n5000 https://$vhostname"
h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: br' -c200 -n5000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
echo "------------------------------------------------------------------------"
s
echo "h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c200 -n5000 https://$vhostname"
h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: br' -c200 -n5000 https://$vhostname | egrep -v 'progress: |starting|spawning'
ngxrestart >/dev/null 2>&1
sleep $SLEEP_TIME
fi
} 2>&1 | tee "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log"

# s
# cat "${CENTMINLOGDIR}/h2load-nginx-https-${DT}.log" | egrep -v 'progress: |starting|spawning'
# s

s
div
cecho "redis benchmarks" $boldyellow
div
s
mkdir -p /root/tools
cd /root/tools
git clone https://github.com/centminmod/centminmod-redis
cd centminmod-redis
if [ ! -f /usr/bin/redis-server ]; then ./redis-install.sh install; fi
service redis restart
s
{
echo "/usr/bin/redis-benchmark -h 127.0.0.1 -p 6379 -n 1000 -r 1000 -t get,set,lpush,lpop -P 1000 -c 100"
/usr/bin/redis-benchmark -h 127.0.0.1 -p 6379 -n 1000 -r 1000 -t get,set,lpush,lpop -P 1000 -c 100
} 2>&1 | tee "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log"
s

s
echo "benchmark run complete"
}

######################################################
starttime=$(TZ=UTC date +%s.%N)
{
  benchninstall
} 2>&1 | tee "${CENTMINLOGDIR}/centminmod-benchmark-all-${DT}.log"

endtime=$(TZ=UTC date +%s.%N)

INSTALLTIME=$(echo "scale=2;$endtime - $starttime"|bc )
echo "" >> "${CENTMINLOGDIR}/centminmod-benchmark-all-${DT}.log"
echo "installnbench2.sh Total Run Time: $INSTALLTIME seconds" >> "${CENTMINLOGDIR}/centminmod-benchmark-all-${DT}.log"

if [[ "$CMBEMAIL" = [yY] ]]; then
  echo "installnbench2.sh completed for $(hostname -f)" | mail -s "$(hostname -f) installnbench2.sh completed $(date)" $CMEBMAIL_ADDR
fi

exit