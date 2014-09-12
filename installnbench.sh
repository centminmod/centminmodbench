#!/bin/bash
######################################################
# written by George Liu (eva2000) centminmod.com
# when ran with command
# curl -sL https://github.com/centminmod/centminmodbench/raw/master/installnbench.sh | bash
# runs 2 tasks
# 1) install latest Centmin Mod .08 beta01 LEMP stack
# 2) installs and runs centminmodbench.sh (UnixBench enabled)
######################################################
# variables
#############
DT=`date +"%d%m%y-%H%M%S"`


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

div() {
	cecho "----------------------------------------------" $boldgreen
}

s() {
	echo
}

benchninstall() {

s
div
cecho "2 tasks will be performaned which can take up to 45-90 mins" $boldyellow
cecho "1). install latest Centmin Mod .08 beta01 LEMP stack ~15-30 mins" $boldyellow
cecho "2). installs & runs centminmodbench.sh (UnixBench enabled) ~30-60 mins" $boldyellow
div
s

s
div
cecho "installing Centmin Mod .08 beta01 LEMP stack" $boldyellow
cecho "will take ~15-30 minutes" $boldyellow
div
s
curl -sL https://gist.github.com/centminmod/dbe765784e03bc4b0d40/raw/installer.sh | bash

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

}

######################################################
benchninstall

exit