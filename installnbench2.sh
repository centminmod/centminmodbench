#!/bin/bash
######################################################
# written by George Liu (eva2000) centminmod.com
# when ran with command
# curl -sL https://github.com/centminmod/centminmodbench/raw/master/installnbench2.sh | bash
# runs 6 tasks
# 1) install latest Centmin Mod Beta LEMP stack
# 2) installs and runs centminmodbench.sh (UnixBench enabled)
# 3) install & run zcat/pzcat benchmarks
# 4) setup & benchmark nginx http/2 https vhost
# 5) redis benchmarks
# 6) sysbench benchmarks
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
cecho "6 tasks will be performaned which can take up to 90-120 mins" $boldyellow
cecho "1). install latest Centmin Mod Beta LEMP stack ~15-30 mins" $boldyellow
cecho "2). installs & runs centminmodbench.sh (UnixBench enabled) ~30-60 mins" $boldyellow
cecho "3). install & run zcat/pzcat benchmarks" $boldyellow
cecho "4). setup & benchmark nginx http/2 https vhost" $boldyellow
cecho "5). redis benchmarks" $boldyellow
cecho "6). sysbench benchmarks" $boldyellow
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
mkdir -p /root/tools
cd /root/tools
wget -O https_bench.sh https://github.com/centminmod/centminmodbench/raw/master/https_bench.sh
chmod +x https_bench.sh
time /root/tools/https_bench.sh

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
cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log" | grep -A9 ' SET ' | sed -e 's| milliseconds|ms|g' -e 's|====== ||' | awk '{print $1, $2, $3}' | sed -e 's| completed||' -e 's| parallel||' -e 's| ======| redis|' -e 's| bytes|bytes|' -e 's|keep alive: 1|1 keepalive|' -e 's| per|/s|' -e 's|<= |<=|g' | grep -v 'ms' | xargs | awk '{ for (i=1;i<=NF;i+=2) print $i" |" }' | xargs | sed -e 's|SET: \||\||' | tee "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-set.log"
echo "| --- | --- | --- | --- | --- | --- |" | tee -a "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-set.log"
cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log" | grep -A9 ' SET ' | sed -e 's| milliseconds|ms|g' -e 's|====== ||' | awk '{print $1, $2, $3}' | sed -e 's| completed||' -e 's| parallel||' -e 's| ======| redis|' -e 's| bytes|bytes|' -e 's|keep alive: 1|1 keepalive|' -e 's| per|/s|' -e 's|<= |<=|g' | grep -v 'ms' | xargs |  awk '{for (i=2; i<=NF; i+=2)print $i" |" }' | xargs | sed -e 's|SET |\| SET |' | tee -a "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-set.log"

s
cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log" | grep -A9 ' GET ' | sed -e 's| milliseconds|ms|g' -e 's|====== ||' | awk '{print $1, $2, $3}' | sed -e 's| completed||' -e 's| parallel||' -e 's| ======| redis|' -e 's| bytes|bytes|' -e 's|keep alive: 1|1 keepalive|' -e 's| per|/s|' -e 's|<= |<=|g' | grep -v 'ms' | xargs |  awk '{for (i=2; i<=NF; i+=2)print $i" |" }' | xargs | sed -e 's|redis |\| redis |' | tee "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-get.log"
echo "| --- | --- | --- | --- | --- | --- |" | tee -a "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-get.log"
cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log" | grep -A9 ' GET ' | sed -e 's| milliseconds|ms|g' -e 's|====== ||' | awk '{print $1, $2, $3}' | sed -e 's| completed||' -e 's| parallel||' -e 's| ======| redis|' -e 's| bytes|bytes|' -e 's|keep alive: 1|1 keepalive|' -e 's| per|/s|' -e 's|<= |<=|g' | grep -v 'ms' | xargs | awk '{ for (i=1;i<=NF;i+=2) print $i" |" }' | xargs | sed -e 's|GET |\| GET|' | tee -a "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-get.log"

s
cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log" | grep -A9 ' LPUSH ' | sed -e 's| milliseconds|ms|g' -e 's|====== ||' | awk '{print $1, $2, $3}' | sed -e 's| completed||' -e 's| parallel||' -e 's| ======| redis|' -e 's| bytes|bytes|' -e 's|keep alive: 1|1 keepalive|' -e 's| per|/s|' -e 's|<= |<=|g' | grep -v 'ms' | xargs |  awk '{for (i=2; i<=NF; i+=2)print $i" |" }' | xargs | sed -e 's|LPUSH |\| LPUSH |' -e 's|redis |\| redis |' | tee "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-lpush.log"
echo "| --- | --- | --- | --- | --- | --- |" | tee -a "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-lpush.log"
cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log" | grep -A9 ' LPUSH ' | sed -e 's| milliseconds|ms|g' -e 's|====== ||' | awk '{print $1, $2, $3}' | sed -e 's| completed||' -e 's| parallel||' -e 's| ======| redis|' -e 's| bytes|bytes|' -e 's|keep alive: 1|1 keepalive|' -e 's| per|/s|' -e 's|<= |<=|g' | grep -v 'ms' | xargs | awk '{ for (i=1;i<=NF;i+=2) print $i" |" }' | xargs | sed -e 's|LPUSH |\| LPUSH |' | tee -a "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-lpush.log"

s
cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log" | grep -A9 ' LPOP ' | sed -e 's| milliseconds|ms|g' -e 's|====== ||' | awk '{print $1, $2, $3}' | sed -e 's| completed||' -e 's| parallel||' -e 's| ======| redis|' -e 's| bytes|bytes|' -e 's|keep alive: 1|1 keepalive|' -e 's| per|/s|' -e 's|<= |<=|g' | grep -v 'ms' | xargs | awk '{ for (i=1;i<=NF;i+=2) print $i" |" }' | xargs | sed -e 's|LPOP: \||\||' | tee "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-lpop.log"
echo "| --- | --- | --- | --- | --- | --- |" | tee -a "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-lpop.log"
cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}.log" | grep -A9 ' LPOP ' | sed -e 's| milliseconds|ms|g' -e 's|====== ||' | awk '{print $1, $2, $3}' | sed -e 's| completed||' -e 's| parallel||' -e 's| ======| redis|' -e 's| bytes|bytes|' -e 's|keep alive: 1|1 keepalive|' -e 's| per|/s|' -e 's|<= |<=|g' | grep -v 'ms' | xargs |  awk '{for (i=2; i<=NF; i+=2)print $i" |" }' | xargs | sed -e 's|LPOP |\| LPOP |' | tee -a "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-lpop.log"

s
{
head -n1 "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-set.log"
echo "| --- | --- | --- | --- | --- | --- |"
tail -1 "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-set.log"
tail -1 "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-get.log"
tail -1 "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-lpush.log"
tail -1 "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-lpop.log"
} 2>&1 | tee "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-table.log"
s

cat "${CENTMINLOGDIR}/centminmod-benchmark-redis-tests-${DT}-markdown-table.log" | grep -v '\-\-\-' | sed -e 's| \| |,|g' -e 's|\:||g' -e 's|\|||g' -e 's| ||'
s

s
div
cecho "sysbench benchmark" $boldyellow
div
s
mkdir -p /root/tools
cd /root/tools
wget -O sysbench.sh https://github.com/centminmod/centminmod-sysbench/raw/master/sysbench.sh
chmod +x sysbench.sh
echo
echo "/root/tools/sysbench.sh install"
/root/tools/sysbench.sh install
echo
echo "/root/tools/sysbench.sh cpu"
/root/tools/sysbench.sh cpu
echo
echo "/root/tools/sysbench.sh mem"
/root/tools/sysbench.sh mem
echo
echo "/root/tools/sysbench.sh file"
/root/tools/sysbench.sh file
echo
echo "/root/tools/sysbench.sh mysql"
/root/tools/sysbench.sh mysql

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