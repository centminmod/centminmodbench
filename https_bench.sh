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
SLEEP_TIME='20'
HTTPS_BENCHCLEANUP='y'

CMBEMAIL='n'
CMEBMAIL_ADDR=''
CENTMINLOGDIR='/root/centminlogs'
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

div() {
	cecho "----------------------------------------------" $boldgreen
}

s() {
	echo
}

https_benchmark() {
s
div
cecho "setup & benchmark nginx http/2 https vhost: https://$vhostname" $boldyellow
div
s
echo "$(curl -4s ipinfo.io/ip) $vhostname" >> /etc/hosts
s
echo "nv -d $vhostname -s y -u \"ftpu\$(pwgen -1cnys 31)\""
nv -d $vhostname -s y -u "ftpu$(pwgen -1cnys 31)"
s

if [ ! -f /usr/bin/h2load ]; then
echo "yum -y install nghttp2"
yum -y install nghttp2
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
ngxrestart >/dev/null 2>&1

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
}

cleanup() {
  if [[ "$HTTPS_BENCHCLEANUP" = [yY] ]]; then
    s
    echo "clean up https://$vhostname"
    cecho "pure-pw userdel $ftpuser" $boldwhite
    pure-pw userdel $ftpuser
    cecho "rm -rf /usr/local/nginx/conf/conf.d/$vhostname.conf" $boldwhite
    rm -rf /usr/local/nginx/conf/conf.d/$vhostname.conf
    cecho "rm -rf /usr/local/nginx/conf/conf.d/${vhostname}.ssl.conf" $boldwhite
    rm -rf /usr/local/nginx/conf/conf.d/${vhostname}.ssl.conf
    cecho "rm -rf /usr/local/nginx/conf/ssl/${vhostname}/${vhostname}.crt" $boldwhite
    rm -rf /usr/local/nginx/conf/ssl/${vhostname}/${vhostname}.crt
    cecho "rm -rf /usr/local/nginx/conf/ssl/${vhostname}/${vhostname}.key" $boldwhite
    rm -rf /usr/local/nginx/conf/ssl/${vhostname}/${vhostname}.key
    cecho "rm -rf /usr/local/nginx/conf/ssl/${vhostname}/${vhostname}.csr" $boldwhite
    rm -rf /usr/local/nginx/conf/ssl/${vhostname}/${vhostname}.csr
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
    cecho "service nginx restart" $boldwhite
    ngxrestart >/dev/null 2>&1
  fi
}

######################################################
starttime=$(TZ=UTC date +%s.%N)
{
  https_benchmark
  cleanup
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