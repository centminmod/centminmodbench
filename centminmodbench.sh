#!/bin/bash
###############################################################
# benchmark script for centminmod.com users
###############################################################
SCRIPTNAME=centminmodbench.sh
VER=0.0.1
###############################################################
EMAIL='youremail@yourdomain.com'
DEBUG='y'

SEVERBEAR='n'
OPENSSLBENCH='y'
OPENSSL_NONSYSTEM='n'
OPENSSL_VERSION='1.0.1i'

MYSQLSLAP_SAVECSV='n'

RUN_UNIXBENCH='n'
UNIXBENCH_VER='5.1.3'
###############################################################
DT=`date +"%d%m%y-%H%M%S"`
OPENSSL_LINKFILE="openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_LINK="http://www.openssl.org/source/${OPENSSL_LINKFILE}"
CPUS=$(nproc)
BENCHDIR='/home/centminmodbench'
LOGDIR='/home/centminmodbench_logs'

MYSQLSLAP_DIR='/home/mysqlslap'
MYSQLDATADIR=$(mysqladmin var | tr -s ' ' | awk -F '| ' '/datadir/ {print $4}')

# mysqlslap default test settings
dbname=test # Database Name
engine=myisam # Storage Engine (myisam or innodb)
clients=8 # Concurrecy Level (number of clients)
uniqq=20 # Number of Unique queries to generate (dft = 10)
uniqwn=20 # Number of Unique Write queries to generate (dft = 10)
rowinserts=200 # Number of row inserts per thread (dft = 100)
it=10 # Iterations (number of runs)
secidx=5 # Number of Secondary Indexes
intcol=5 # Number of INT columns
charcol=5 # Number of VARCHAR Columns
queries=10000 # Number of Queries per client
###############################################################
if [ ! -f /etc/centos-release ] ; then
	cecho "$SCRIPTNAME is meant to be run on CentOS system only" $boldyellow
	exit
fi

if [ ! -d "$BENCHDIR" ]; then
	mkdir -p $BENCHDIR
fi

if [ ! -d "$LOGDIR" ]; then
	mkdir -p $LOGDIR
fi

if [[ ! -d ${MYSQLSLAP_DIR} ]]; then 
	mkdir -p ${MYSQLSLAP_DIR}
fi

if [[ ! -f /usr/bin/wget ]]; then
	yum -q -y install wget
fi

if [[ ! -f /usr/bin/nproc ]]; then
	yum -q -y install coreutils
fi

if [[ ! -f /usr/bin/lscpu ]]; then
	yum -q -y install util-linux-ng
fi
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

s() {
	echo
}

byline() {
	cecho "-------------------------------------------" $boldgreen
	cecho "$SCRIPTNAME $VER (centminmod.com)" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s
}

sbvultr() {
if [[ "$SERVERBEAR" = [yY] ]]; then

	cecho "-------------------------------------------" $boldgreen
	cecho "ServerBear.com Vultr Benchmarks" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

# 768MB VPS = 2419
# 1GB VPS = 2420
# 2GB VPS = 2421
# 4GB VPS = 2422
# 8GB VPS = 2423
# 16GB VPS = 2424
# 32GB VPS = 2425
# 48GB VPS = 2426
# 64GB VPS = 2427

	PLAINID='2423'
	wget -N https://raw.github.com/Crowd9/Benchmark/master/sb.sh&&bash sb.sh '10159' $PLAINID $EMAIL '' private
	
fi
}

opensslcompile() {

	if [[ ! -f "${BENCHDIR}/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl version" ]]; then
		cd ${BENCHDIR}/openssl-${OPENSSL_VERSION}
		#make clean 2>&1 >> /dev/null
		./config 2>&1 >> /dev/null
		make 2>&1 >> /dev/null
	fi
}

openssldownload() {

    cd $BENCHDIR

        cecho "Download ${OPENSSL_LINKFILE} ..." $boldyellow
    if [ -s ${OPENSSL_LINKFILE} ]; then
        cecho "openssl ${OPENSSL_VERSION} found, skipping download..." $boldgreen
    else
        wget -cnv ${OPENSSL_LINK} --tries=3
ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
	cecho "Error: ${OPENSSL_LINKFILE} download failed." $boldgreen
	exit #$ERROR
else 
         cecho "Download done." $boldyellow
	fi
    fi

tar xzf ${OPENSSL_LINKFILE} 
ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
	cecho "Error: ${OPENSSL_LINKFILE} extraction failed." $boldgreen
	exit #$ERROR
else 
         cecho "${OPENSSL_LINKFILE} valid file." $boldyellow
         opensslcompile
echo ""
	fi

}

opensslbench() {
if [[ "$OPENSSLBENCH" = [yY] ]]; then
	cecho "-------------------------------------------" $boldgreen
	cecho "OpenSSL System Benchmark" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s
	openssl version

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed rsa4096 -multi ${CPUS}" $boldyellow
	openssl speed rsa4096 -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed rsa2048 -multi ${CPUS}" $boldyellow
	openssl speed rsa2048 -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed ecdsap256 -multi ${CPUS}" $boldyellow
	openssl speed ecdsap256 -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed sha256 -multi ${CPUS}" $boldyellow
	openssl speed sha256 -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed sha1 -multi ${CPUS}" $boldyellow
	openssl speed sha1 -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed rc4 -multi ${CPUS}" $boldyellow
	openssl speed rc4 -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "oopenssl speed -evp aes128 -multi ${CPUS}" $boldyellow
	openssl speed -evp aes128 -multi ${CPUS}

	if [[ "$OPENSSL_NONSYSTEM" = [yY] ]]; then
		cecho "-------------------------------------------" $boldgreen
		cecho "Centmin Mod Nginx static OpenSSL Benchmark" $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		# not needed as testing Centmin Mod Nginx static OpenSSL version
		# openssldownload
		if [ -f /svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl ]; then
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl version
		
			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed rsa4096 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed rsa4096 -multi ${CPUS}
		
			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed rsa2048 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed rsa2048 -multi ${CPUS}
		
			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed ecdsap256 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed ecdsap256 -multi ${CPUS}
	
			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed sha256 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed sha256 -multi ${CPUS}
	
			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed sha1 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed sha1 -multi ${CPUS}
	
			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed rc4 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed rc4 -multi ${CPUS}

			cecho "-------------------------------------------" $boldgreen
			cecho "oopenssl speed -evp aes128 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed -evp aes128 -multi ${CPUS}
		fi
	fi
fi
}

baseinfo() {
	cecho "-------------------------------------------" $boldgreen
	cecho "System Information" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	uname -r
	s

	cat /etc/redhat-release
	s
	
	echo -n "Centmin Mod "
	cat /etc/centminmod-release
	s
	
	lscpu
	s

	lscpu -e
	s
	
	# cat /proc/cpuinfo
	# s
	
	free -ml
	s
	
	df -h
	s
}

mysqlslapper() {
	cecho "-------------------------------------------" $boldgreen
	cecho "Running mysqlslap" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	if [[ ! -d "${MYSQLDATADIR}test" ]]; then
		mysqladmin create $dbname
	fi

	if [[ "$MYSQLSLAP_SAVECSV" = [yY] ]]
		then CSVFILE="--csv=${MYSQLSLAP_DIR}/mysqlslap_$DT.csv"
	else 
		CSVFILE=""
	fi
	
	cecho "mysqlslap --auto-generate-sql --auto-generate-sql-add-autoincrement --auto-generate-sql-secondary-indexes=$secidx --number-int-cols=$intcol --number-char-cols=$charcol --number-of-queries=$queries --auto-generate-sql-unique-query-number=$uniqq --auto-generate-sql-unique-write-number=$uniqwn --auto-generate-sql-write-number=$rowinserts --concurrency=$clients --iterations=$it --engine=$engine -vv $CSVFILE" $boldyellow

	mysqlslap --auto-generate-sql --auto-generate-sql-add-autoincrement --auto-generate-sql-secondary-indexes=$secidx --number-int-cols=$intcol --number-char-cols=$charcol --number-of-queries=$queries --auto-generate-sql-unique-query-number=$uniqq --auto-generate-sql-unique-write-number=$uniqwn --auto-generate-sql-write-number=$rowinserts --concurrency=$clients --iterations=$it --engine=$engine -vv $CSVFILE
	
	if [[ "$MYSQLSLAP_SAVECSV" = [yY] ]]
		then echo -e "\nls -lahrt ${MYSQLSLAP_DIR}/"
		ls -lahrt ${MYSQLSLAP_DIR}/
	fi

	if [[ -d "${MYSQLDATADIR}test" ]]; then
		echo Y | mysqladmin drop $dbname
	fi
}

# UnixBench 5.1.3
ubench()
{
	if [[ "$RUN_UNIXBENCH" = [yY] ]]; then
		cecho "-------------------------------------------" $boldgreen
		cecho "Building UnixBench" $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		cd $BENCHDIR

        cecho "Download UnixBench${UNIXBENCH_VER}.tgz ..." $boldyellow
    if [ -s UnixBench${UNIXBENCH_VER}.tgz ]; then
        cecho "openssl ${OPENSSL_VERSION} found, skipping download..." $boldgreen
    else
        wget -cnv https://byte-unixbench.googlecode.com/files/UnixBench${UNIXBENCH_VER}.tgz --tries=3
ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
	cecho "Error: UnixBench${UNIXBENCH_VER}.tgz download failed." $boldgreen
	exit #$ERROR
else 
         cecho "Download done." $boldyellow
	fi
    fi

if [ ! -d UnixBench ]; then
	tar xzf UnixBench${UNIXBENCH_VER}.tgz
	ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
		cecho "Error: UnixBench${UNIXBENCH_VER}.tgz extraction failed." $boldgreen
		exit #$ERROR
	else 
         cecho "UnixBench${UNIXBENCH_VER}.tgz valid file." $boldyellow
		echo ""
	fi
fi
		wget -cnv https://gist.githubusercontent.com/centminmod/7bea01c6698377d1345a/raw/unixbench.patch
				
		cd UnixBench 
		mv ../unixbench.patch .	
		make -j${CPUS}
		patch Run unixbench.patch

		cecho "-------------------------------------------" $boldgreen
		cecho "Running UnixBench" $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		if [[ "$DEBUG" = [yY] ]]; then
			./Run shell1
		else
			./Run dhry2reg whetstone-double syscall pipe context1 spawn execl shell1 shell8 shell16
		fi
		cd $BENCHDIR
		# rm -rf UnixBench* unixbench.patch
		rm -rf UnixBench
	fi
}

ended() {
	s
	cecho "-------------------------------------------" $boldgreen
	cecho "$SCRIPTNAME completed" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s
}

#####################
starttime=$(date +%s.%N)
{
	byline
	baseinfo
	opensslbench
	mysqlslapper
	ubench
	
	if [[ "$1" = 'vultr' ]]; then
		sbvultr
	fi
	
	if [[ "$1" = 'do' ]]; then
		sbdo
	fi
	
	if [[ "$1" = 'linode' ]]; then
		sblinode
	fi
	
	if [[ "$1" = 'ramnode' ]]; then
		sbramnode
	fi

	ended
} 2>&1 | tee ${LOGDIR}/centminmodbench_results_${DT}.log

endtime=$(date +%s.%N)

INSTALLTIME=$(echo "scale=2;$endtime - $starttime"|bc )
echo "" >> ${LOGDIR}/centminmodbench_results_${DT}.log
echo "$SCRIPTNAME Total Run Time: $INSTALLTIME seconds" >> ${LOGDIR}/centminmodbench_results_${DT}.log
exit