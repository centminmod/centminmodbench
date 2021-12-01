#!/bin/bash
######################################################
# written by George Liu (eva2000) centminmod.com
# when ran with command
# curl -sL https://github.com/centminmod/centminmodbench/raw/master/installnbench.sh | bash
# runs 3 tasks
# 1) install latest Centmin Mod Beta LEMP stack
# 2) installs and runs centminmodbench.sh (UnixBench enabled)
# 3) install & run zcat/pzcat benchmarks
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

if [ ! -d "$CENTMINLOGDIR" ]; then
  mkdir -p $CENTMINLOGDIR
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
cecho "3 tasks will be performaned which can take up to 45-90 mins" $boldyellow
cecho "1). install latest Centmin Mod Beta LEMP stack ~15-30 mins" $boldyellow
cecho "2). installs & runs centminmodbench.sh (UnixBench enabled) ~30-60 mins" $boldyellow
cecho "3). install & run zcat/pzcat benchmarks" $boldyellow
div
s

s
div
cecho "installing Centmin Mod Beta LEMP stack" $boldyellow
cecho "will take ~15-30 minutes" $boldyellow
div
s
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

}

######################################################
starttime=$(TZ=UTC date +%s.%N)
{
  benchninstall
} 2>&1 | tee "${CENTMINLOGDIR}/centminmod-benchmark-all-${DT}.log"

endtime=$(TZ=UTC date +%s.%N)

INSTALLTIME=$(echo "scale=2;$endtime - $starttime"|bc )
echo "" >> "${CENTMINLOGDIR}/centminmod-benchmark-all-${DT}.log"
echo "installnbench.sh Total Run Time: $INSTALLTIME seconds" >> "${CENTMINLOGDIR}/centminmod-benchmark-all-${DT}.log"

if [[ "$CMBEMAIL" = [yY] ]]; then
  echo "installnbench.sh completed for $(hostname -f)" | mail -s "$(hostname -f) installnbench.sh completed $(date)" $CMEBMAIL_ADDR
fi

exit