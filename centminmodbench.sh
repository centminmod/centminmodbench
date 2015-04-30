#!/bin/bash
###############################################################
# centminmodbench.sh
# https://github.com/centminmod/centminmodbench
# short url link: http://bench.centminmod.com
# benchmark script for centminmod.com users
#
# merges several existing benchmark scripts I wrote already
# for mysqlslap and php bench.php and micro_bench.php
#
# disk dd, ioping and fio test parameters match those used
# for serverbear.com benchmark runs so they are comparable
#
# add check for system entropy 
# http://crypto.stackexchange.com/questions/12571/good-entropy-source-for-generating-openssl-keys
#
# inspired by STH Linux benchmark script 
# https://github.com/STH-Dev/linux-bench
###############################################################
SCRIPTNAME=centminmodbench.sh
SCRIPTAUTHOR='George Liu (eva2000)'
SCRIPTSITE='http://centminmod.com'
SCRIPTGITHUB='http://bench.centminmod.com'
VER=0.5
###############################################################
EMAIL='youremail@yourdomain.com'
DEBUG='n'
AUTOREPORT='y'
TESTFILE='/home/gziptest/imdb.sql'

OPENSSL_VERSION='1.0.2a'
MYSQLSLAP_SAVECSV='n'

SEVERBEAR='n'
OPENSSLBENCH='y'
OPENSSL_NONSYSTEM='y'
RUN_DISKDD='y'
RUN_DISKIOPING='y'
RUN_DISKFIO='y'
RUN_RAMDISKDD='y'
RUN_RAMDISKIOPING='y'
RUN_RAMDISKFIO='n' # disabled as tmpfs not support direct=1/buffered=0
RUN_AXELBENCH='y'
RUN_BANDWIDTHBENCH='y'
RUN_VULTRTESTS='y'
EUROPE_BANDWIDTHTESTS='y'
ASIA_BANDWIDTHTESTS='y'
AUSTRALIA_BANDWIDTHTESTS='y'
USA_BANDWIDTHTESTS='y'
RUN_PINGTESTS='y'
RUN_MYSQLSLAP='y'
RUN_PHPTESTS='y'
RUN_UNIXBENCH='n'
RUN_MTRTESTS='y'
MTR_PACKETS='10'
RUN_ENTROPYTEST='y'
ENTROPY_RUNS='4'
ENTROPYSLEEP=10
RUN_RNGTEST='n'
UNIXBENCH_VER='5.1.3'

SHOWPHPSTATS='n'
PHPVER=$(php -v 2>&1 | awk -F " " '{print $2}' | head -n1)

# Print output in a forum friendly [CODE] tag format
BBCODE='y'

# how many runs to do for bench.php & micro_bench.php
# the results will be averaged over that many runs
RUNS='3'

IOPING_VERSION=0.6
FIO_VERSION=2.0.9

########################
# compression

# Max Compression level to test up to 
# values between 1 (lowest) to 9 (highest)
COMPLEVEL='3'

# Number of cpu threads for compression
CPUNO='4'

# sleep delay between runs after calling cleanmem
# echo 3 > /proc/sys/vm/drop_caches
# sleep 3
SLEEP='7'

# Whether test output times the decompression tests as well. 
# If set to 'n' then only the last compression test will show timed
# decompression test
DECOMPTIMED='y'

# Number of cpu threads for decompression
# some apps use alot of memory for decompression
# reducing cpu threads for decompression will lower
# max resource usage i.e. for lbzip2
DCPUNO='2'
REDUCETHREADS='y'

if [ $REDUCETHREADS == 'y' ]; then
DCOMPTHREADS=" -n$DCPUNO"
else
DCOMPTHREADS=''
fi

GZIPTEST='y'
BZIPTEST='y'
PIGZTEST='y'
LBZIPTEST='y'

# Enable or disable custom block size
# for pigz
PIGZBLKSIZE='n'
if [ "$PIGZBLKSIZE" == 'y' ]; then
	# default is 128KB
	PIGZBLOCKSIZE=' -b 128'
else
	PIGZBLOCKSIZE=''
fi

# Enable or disable custom block size
# for pbzip2
PBZIP2BLKSIZE='n'
if [ "$PBZIP2BLKSIZE" == 'y' ]; then
	# default is 9 = 9x100K = 900K
	PBZIP2BLOCKSIZE=' -b3'
else
	PBZIP2BLOCKSIZE=''
fi

# not working
LBZIP2BLKSIZE='n'
if [ "$LBZIP2BLKSIZE" == 'y' ]; then
	# default is 9 = 9x100K = 900K
	LBZIP2BLOCKSIZE=' -b3'
else
	LBZIP2BLOCKSIZE=''
fi

# Enable or disable custom block size
# for plzip
PLZIPBLKSIZE='n'
if [ "$PLZIPBLKSIZE" == 'y' ]; then
	# default is ???k
	PLZIPBLOCKSIZE=' -B 512k'
else
	PLZIPBLOCKSIZE=''
fi
###############################################################
DT=`date +"%d%m%y-%H%M%S"`
OPENSSL_LINKFILE="openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_LINK="http://www.openssl.org/source/${OPENSSL_LINKFILE}"
BENCHDIR='/home/centminmodbench'
RAMDISK_DIR='/ramdisk0'
LOGDIR='/home/centminmodbench_logs'
# where to download compression binaries for install
SRCDIR="$BENCHDIR"

MYSQLSLAP_DIR='/home/mysqlslap'
MYSQLDATADIR=$(mysqladmin var 2>&1 | tr -s ' ' | awk -F '| ' '/datadir/ {print $4}')

# mysqlslap default test settings
dbname=test # Database Name
engine=myisam # Storage Engine (myisam or innodb)
clients=64 # Concurrecy Level (number of clients)
uniqq=40 # Number of Unique queries to generate (dft = 10)
uniqwn=40 # Number of Unique Write queries to generate (dft = 10)
rowinserts=1000 # Number of row inserts per thread (dft = 100)
it=10 # Iterations (number of runs)
secidx=5 # Number of Secondary Indexes
intcol=5 # Number of INT columns
charcol=5 # Number of VARCHAR Columns
queries=25000 # Number of Queries per client

DIR_TMP='/svr-setup'
PHPBENCHLOGDIR='/home/phpbench_logs'
PHPBENCHLOGFILE="bench_${DT}.log"
PHPMICROBENCHLOGFILE="bench_micro_${DT}.log"
PHPBENCHLOG="${PHPBENCHLOGDIR}/${PHPBENCHLOGFILE}"
PHPMICROBENCHLOG="${PHPBENCHLOGDIR}/${PHPMICROBENCHLOGFILE}"

CLIENTIP=$(echo "${SSH_CLIENT%% *}")
SERVERIP=$(ip addr show | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -v 127.0.0.1)
HOSTNAME=$(hostname)
PROCESSNAME='php-fpm'

IOPING_DIR="${BENCHDIR}/ioping-${IOPING_VERSION}"
FIO_DIR="${BENCHDIR}/fio-${FIO_VERSION}"

if [ -f /proc/user_beancounters ]; then
	CPUS=$(grep "processor" /proc/cpuinfo |wc -l)
else
	CPUS=$(nproc)
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

if [ ! -f /etc/centos-release ] ; then
	cecho "$SCRIPTNAME is meant to be run on CentOS system only" $boldyellow
	exit
fi

if [ ! -d "$BENCHDIR" ]; then
	mkdir -p $BENCHDIR
fi

if [ ! -d /home/gziptest ]; then
	mkdir -p /home/gziptest
fi

if [ ! -d "$LOGDIR" ]; then
	mkdir -p $LOGDIR
fi

if [[ ! -d "${MYSQLSLAP_DIR}" ]]; then 
	mkdir -p ${MYSQLSLAP_DIR}
fi

if [ ! -d "$PHPBENCHLOGDIR" ]; then
	mkdir -p $PHPBENCHLOGDIR
fi

echo
echo "installing required packages..."
yum -y -q install nano bc unzip mtr util-linux-ng coreutils gcc cc libaio libaio-devel wget pigz lbzip2 rng-tools screen perl-Test-Simple perl-ExtUtils-MakeMaker perl-Time-HiRes perl-libwww-perl perl-Crypt-SSLeay perl-Net-SSLeay perl-LWP-Protocol-https patch
echo "required packages installed"
echo

if [[ ! -f /usr/bin/cc || ! -f /usr/bin/gcc ]]; then
	cecho "installing required yum package (cc / gcc) ..." $boldyellow
	yum -q -y install cc gcc
fi

if [[ ! -f /usr/bin/wget ]]; then
	cecho "installing required yum package (wget) ..." $boldyellow
	yum -q -y install wget
fi

if [[ ! -f /usr/bin/nproc ]]; then
	cecho "installing required yum package (nproc) ..." $boldyellow
	yum -q -y install coreutils
fi

if [ ! -f /proc/user_beancounters ]; then
	if [[ ! -f /usr/bin/lscpu ]]; then
		cecho "installing required yum package (lscpu) ..." $boldyellow
		yum -q -y install util-linux-ng
	fi
fi

if [[ ! -f /usr/include/libaio.h ]]; then
	cecho "installing required yum package (libaio libaio-devel) ..." $boldyellow
	yum -q -y install libaio libaio-devel
fi

if [[ ! -f /usr/sbin/mtr ]]; then
	cecho "installing required yum package (mtr) ..." $boldyellow
	yum -q -y install mtr
fi

if [ -f /etc/yum.repos.d/epel.repo ]; then
	if [[ ! -f /usr/bin/pigz || ! -f /usr/bin/lbzip2 ]]; then
		cecho "installing required yum package (pigz / lbzip2) ..." $boldyellow
		yum -q -y install pigz lbzip2
	fi
fi

if [[ ! -f /usr/bin/rngtest ]]; then
	cecho "installing required yum package (rng-tools) ..." $boldyellow
	yum -q -y install rng-tools
fi

if [[ "$DEBUG" = [yY] ]]; then
	RUN_BANDWIDTHBENCH='n'
fi

if [[ ! -f /usr/bin/mysqlslap ]]; then
	RUN_MYSQLSLAP='n'
fi

# determine Centmin Mod Nginx static compiled
# OpenSSL version
OPENSSL_VERCHECK=$(nginx -V 2>&1 | grep -Eo "$OPENSSL_VERSION")
###############################################################
# functions

ramdisktest() {
	if [[ "$RUN_RAMDISKDD" = [yY] ]]; then

		if [[ "$(grep -qs ${RAMDISK_DIR} /proc/mounts)" ]]; then
			umount -l ${RAMDISK_DIR} 2>&1
			rm -rf ${RAMDISK_DIR}
		fi

	mkdir -p ${RAMDISK_DIR}
	mount -t tmpfs -o rw,size=160M tmpfs ${RAMDISK_DIR}
	cd ${RAMDISK_DIR}

	bbcodestart
	cecho "-------------------------------------------" $boldgreen
	cecho "ramdisk DD tests - memory bandwidth" $boldyellow
	cecho "-------------------------------------------" $boldgreen

	s
	cecho "dd if=/dev/zero of=sb-io-test bs=128k count=1k conv=fdatasync"	$boldyellow
	dd if=/dev/zero of=sb-io-test bs=128k count=1k conv=fdatasync
	
	s
	cecho "dd if=/dev/zero of=sb-io-test bs=8k count=16k conv=fdatasync" $boldyellow
	dd if=/dev/zero of=sb-io-test bs=8k count=16k conv=fdatasync

	s	
	cecho "dd if=/dev/zero of=sb-io-test bs=128k count=1k oflag=dsync" $boldyellow
	dd if=/dev/zero of=sb-io-test bs=128k count=1k oflag=dsync
	
	s
	cecho "dd if=/dev/zero of=sb-io-test bs=8k count=16k oflag=dsync" $boldyellow
	dd if=/dev/zero of=sb-io-test bs=8k count=16k oflag=dsync

	rm -rf sb-io-test 2>/dev/null
	# cd ..
	bbcodeend
	fi

	if [[ "$RUN_RAMDISKIOPING" = [yY] ]]; then
	bbcodestart
	cecho "-------------------------------------------" $boldgreen
	cecho "ramdisk ioping tests - memory bandwidth" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	cd ${RAMDISK_DIR}
	
        # cecho "Download ioping-$IOPING_VERSION.tar.gz ..." $boldyellow
    if [ -s ioping-$IOPING_VERSION.tar.gz ]; then
        # cecho "ioping-$IOPING_VERSION.tar.gz found, skipping download..." $boldgreen
        s
    else
        wget -cnv --no-check-certificate https://ioping.googlecode.com/files/ioping-$IOPING_VERSION.tar.gz --tries=3
ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
	cecho "Error: ioping-$IOPING_VERSION.tar.gz download failed." $boldgreen
	exit #$ERROR
else 
         cecho "Download done." $boldyellow
	fi
    fi

if [ ! -d ioping-$IOPING_VERSION ]; then
	tar xzf ioping-$IOPING_VERSION.tar.gz
	ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
		cecho "Error: ioping-$IOPING_VERSION.tar.gz extraction failed." $boldgreen
		exit #$ERROR
	else 
         cecho "ioping-$IOPING_VERSION.tar.gz valid file." $boldyellow
		echo ""
	fi
fi

	cd ${RAMDISK_DIR}/ioping-0.6

	cecho "Running IOPing I/O ramdisk benchmark..." $boldyellow
	if [ ! -f ioping ]; then
		make -j${CPUS} 2>&1
	fi
	s
	cecho "IOPing I/O: ./ioping -c 10 ." $boldyellow
	./ioping -c 10 .
	s
	cecho "IOPing seek rate: ./ioping -R ." $boldyellow
	./ioping -R .
	s
	cecho "IOPing sequential: ./ioping -RL ." $boldyellow
	./ioping -RL .
	s
	cecho "IOPing cached: ./ioping -RC ." $boldyellow
	./ioping -RC .
	s
	bbcodeend
	fi

	if [[ "$RUN_RAMDISKFIO" = [yY] ]]; then
	bbcodestart
	cecho "-------------------------------------------" $boldgreen
	cecho "ramdisk FIO tests - memory bandwidth" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	cd ${RAMDISK_DIR}

        # cecho "Download fio-$FIO_VERSION.tar.gz ..." $boldyellow
    if [ -s fio-$FIO_VERSION.tar.gz ]; then
        # cecho "fio-$FIO_VERSION.tar.gz found, skipping download..." $boldgreen
        s
    else
        wget -cnv --no-check-certificate https://github.com/Crowd9/Benchmark/raw/master/fio-$FIO_VERSION.tar.gz --tries=3
ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
	cecho "Error: fio-$FIO_VERSION.tar.gz download failed." $boldgreen
	exit #$ERROR
else 
         cecho "Download done." $boldyellow
	fi
    fi

if [ ! -d fio-$FIO_VERSION ]; then
	tar xzf fio-$FIO_VERSION.tar.gz
	ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
		cecho "Error: fio-$FIO_VERSION.tar.gz extraction failed." $boldgreen
		exit #$ERROR
	else 
         cecho "fio-$FIO_VERSION.tar.gz valid file." $boldyellow
		echo ""
	fi
fi

cat > ${RAMDISK_DIR}/fio-2.0.9/reads.ini << EOF
[global]
randrepeat=1
ioengine=libaio
bs=4k
ba=4k
size=128M
direct=1
gtod_reduce=1
norandommap
iodepth=64
numjobs=1

[randomreads]
startdelay=0
filename=sb-io-test
readwrite=randread
EOF

cat > ${RAMDISK_DIR}/fio-2.0.9/writes.ini << EOF
[global]
randrepeat=1
ioengine=libaio
bs=4k
ba=4k
size=128M
direct=1
gtod_reduce=1
norandommap
iodepth=64
numjobs=1

[randomwrites]
startdelay=0
filename=sb-io-test
readwrite=randwrite
EOF

cecho "Running FIO ramdisk benchmark..." $boldyellow
s
cd ${RAMDISK_DIR}/fio-2.0.9/
make -j${CPUS} 2>&1

s
cecho "FIO ramdisk random reads: " $boldyellow
./fio reads.ini

s
cecho "FIO ramdisk random writes: " $boldyellow
./fio writes.ini

rm sb-io-test 2>/dev/null
s
	bbcodeend
	fi
	
	umount -l ${RAMDISK_DIR}
	rm -rf ${RAMDISK_DIR}
}

bbcodestart() {
	if [[ "$BBCODE" = [yY] ]]; then
		echo "[CODE]"
	fi
}

bbcodeend() {
	if [[ "$BBCODE" = [yY] ]]; then
		echo "[/CODE]"
	fi
}

div() {
	cecho "----------------------------------------------" $boldgreen
}

s() {
	echo
}

byline() {
	cecho "-------------------------------------------" $boldgreen
	cecho "$SCRIPTNAME $VER" $boldyellow
	cecho "$SCRIPTGITHUB" $boldyellow
	cecho "written by: $SCRIPTAUTHOR" $boldyellow
	cecho "$SCRIPTSITE" $boldyellow
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

entropycheck() {
if [[ "$RUN_ENTROPYTEST" = [yY] ]]; then
	bbcodestart
	cecho "-------------------------------------------" $boldgreen
	cecho "Check system entropy pool availability" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s
	for ((i = 0 ; i < $ENTROPY_RUNS ; i++)); do
		echo -n "entropy_avail: "; cat /proc/sys/kernel/random/entropy_avail
		sleep $ENTROPYSLEEP
	done
	if [[ "$RUN_RNGTEST" = [yY] ]]; then
		s
		cat /dev/random | rngtest -c 1000
		s
	fi
	bbcodeend
fi
}

opensslbench() {
if [[ "$OPENSSLBENCH" = [yY] ]]; then
	bbcodestart
	cecho "-------------------------------------------" $boldgreen
	cecho "OpenSSL System Benchmark" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s
	openssl version

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed rsa4096 rsa2048 ecdsap256 sha256 sha1 md5 rc4 aes-256-cbc aes-128-cbc -multi ${CPUS}" $boldyellow
	openssl speed rsa4096 rsa2048 ecdsap256 sha256 sha1 md5 rc4 aes-256-cbc aes-128-cbc -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed -evp aes256 -multi ${CPUS}" $boldyellow
	openssl speed -evp aes256 -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed -evp aes128 -multi ${CPUS}" $boldyellow
	openssl speed -evp aes128 -multi ${CPUS}

	if [[ "$OPENSSL_NONSYSTEM" = [yY] ]]; then
		if [[ -f /etc/centminmod-release && "$OPENSSL_VERCHECK" ]]; then
		s
		cecho "-------------------------------------------" $boldgreen
		cecho "Centmin Mod Nginx static OpenSSL Benchmark" $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		# not needed as testing Centmin Mod Nginx static OpenSSL version
		# openssldownload
			if [ -f /svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl ]; then
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl version
		
			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed rsa4096 rsa2048 ecdsap256 sha256 sha1 md5 rc4 aes-256-cbc aes-128-cbc -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed rsa4096 rsa2048 ecdsap256 sha256 sha1 md5 rc4 aes-256-cbc aes-128-cbc -multi ${CPUS}

			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed -evp aes256 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed -evp aes256 -multi ${CPUS}
		
			cecho "-------------------------------------------" $boldgreen
			cecho "openssl speed -evp aes128 -multi ${CPUS}" $boldyellow
			/svr-setup/openssl-${OPENSSL_VERSION}/.openssl/bin/openssl speed -evp aes128 -multi ${CPUS}
			fi
		fi
	fi
	bbcodeend
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
	
	if [ -f /etc/centminmod-release ]; then
	echo -n "Centmin Mod "
	cat /etc/centminmod-release 2>&1 >/dev/null
	s
	fi
	
	div
	if [ ! -f /proc/user_beancounters ]; then
		lscpu
	else
		CPUNAME=$(cat /proc/cpuinfo | grep "model name" | cut -d ":" -f2 | tr -s " " | head -n 1)
		CPUCOUNT=$(cat /proc/cpuinfo | grep "model name" | cut -d ":" -f2 | wc -l)
		echo "CPU: $CPUCOUNT x$CPUNAME"
		uname -m
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
}

mysqlslapper() {
if [[ "$RUN_MYSQLSLAP" = [yY] ]]; then
	bbcodestart
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
	
	cecho "mysqlslap --auto-generate-sql --auto-generate-sql-add-autoincrement --auto-generate-sql-secondary-indexes=$secidx --number-int-cols=$intcol --number-char-cols=$charcol --number-of-queries=$queries --auto-generate-sql-unique-query-number=$uniqq --auto-generate-sql-unique-write-number=$uniqwn --auto-generate-sql-write-number=$rowinserts --concurrency=$clients --iterations=$it --engine=$engine $CSVFILE" $boldyellow

	mysqlslap --auto-generate-sql --auto-generate-sql-add-autoincrement --auto-generate-sql-secondary-indexes=$secidx --number-int-cols=$intcol --number-char-cols=$charcol --number-of-queries=$queries --auto-generate-sql-unique-query-number=$uniqq --auto-generate-sql-unique-write-number=$uniqwn --auto-generate-sql-write-number=$rowinserts --concurrency=$clients --iterations=$it --engine=$engine $CSVFILE
	
	if [[ "$MYSQLSLAP_SAVECSV" = [yY] ]]
		then echo -e "\nls -lahrt ${MYSQLSLAP_DIR}/"
		ls -lahrt ${MYSQLSLAP_DIR}/
	fi

	if [[ -d "${MYSQLDATADIR}test" ]]; then
		echo Y | mysqladmin drop $dbname
	fi
	bbcodeend
fi
}

# UnixBench 5.1.3
ubench()
{
	if [[ "$RUN_UNIXBENCH" = [yY] ]]; then
		bbcodestart
		cecho "-------------------------------------------" $boldgreen
		cecho "Building UnixBench" $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		cd $BENCHDIR

        cecho "Download UnixBench${UNIXBENCH_VER}.tgz ..." $boldyellow
    if [ -s UnixBench${UNIXBENCH_VER}.tgz ]; then
        # cecho "UnixBench${UNIXBENCH_VER}.tgz found, skipping download..." $boldgreen
        s
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
		make -j${CPUS} 2>&1
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
		bbcodeend
	fi
}

cleanmem() {
	if [ ! -f /proc/user_beancounters ]; then
		sync && echo 3 > /proc/sys/vm/drop_caches > /dev/null
		sleep $SLEEP
	fi
}

phpmem() {
	if [[ "$SHOWPHPSTATS" = [yY] ]]; then
		
		p=${PROCESSNAME}
		ps -C $p -O rss | gawk '{ count ++; sum += $2 }; END {count --; print "[php stats]: Number of processes =",count; print "[php stats]: Memory usage per process =",sum/1024/count, "MB"; print "[php stats]: TOTAL memory usage =", sum/1024, "MB" ;};'
		
	fi
}

restartphp() {
	service php-fpm restart 2>&1 >/dev/null
	cleanmem
	sleep 4
}

phpi() {
	{
	cecho "-------------------------------------------" $boldgreen
	cecho "System PHP Info" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	CPUNAME=$(cat /proc/cpuinfo | grep "model name" | cut -d ":" -f2 | tr -s " " | head -n 1)
	CPUCOUNT=$(cat /proc/cpuinfo | grep "model name" | cut -d ":" -f2 | wc -l)
	echo "CPU: $CPUCOUNT x$CPUNAME"
	# cat /etc/redhat-release && uname -m
	# echo "Centmin Mod $(cat /etc/centminmod-release)"
	free -ml
	
	
	echo "----------------------------------------------"
	php -v
	
	
	echo "----------------------------------------------"
	php --ini
	
	
	echo "----------------------------------------------"
	php -m
	
	
	echo "----------------------------------------------"
	# php -i
	
	} 2>&1 | tee ${PHPBENCHLOGDIR}/bench_phpinfo_${DT}.log
	sed -i "s/$CLIENTIP/ipaddress/g" ${PHPBENCHLOGDIR}/bench_phpinfo_${DT}.log 2>/dev/null
	sed -i "s/$SERVERIP/serverip/g" ${PHPBENCHLOGDIR}/bench_phpinfo_${DT}.log 2>/dev/null
	sed -i "s/$HOSTNAME/hostname/g" ${PHPBENCHLOGDIR}/bench_phpinfo_${DT}.log 2>/dev/null
}

changedir() {
	cd ${DIR_TMP}/php-${PHPVER}
}

fbench() {
	cecho "-------------------------------------------" $boldgreen
	cecho "Run PHP test Zend/bench.php" $boldyellow
	cecho "-------------------------------------------" $boldgreen

	changedir
	touch $PHPBENCHLOG
	echo -e "\n$(date)" >> $PHPBENCHLOG
	for ((i = 0 ; i < $RUNS ; i++)); do
		{
		echo
		
		/usr/bin/time --format='real: %es user: %Us sys: %Ss cpu: %P maxmem: %M KB cswaits: %w' php Zend/bench.php
		
		phpmem
		} 2>&1 | tee -a $PHPBENCHLOG
	done
	TOTAL=$(awk '/Total/ {print $2}' $PHPBENCHLOG)
	AVG=$(awk '/Total/ {print $2}' $PHPBENCHLOG | awk '{ sum += $1 } END { if (NR > 0) printf "%.4f\n", sum / NR }')
	TIMEREAL=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPBENCHLOG | awk '{ sum += $2 } END { if (NR > 0) printf "%.2f\n", sum / NR }')
	TIMEUSER=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPBENCHLOG | awk '{ sum += $4 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	TIMESYS=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPBENCHLOG | awk '{ sum += $6 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	TIMECPU=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPBENCHLOG | awk '{ sum += $8 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	TIMEMEM=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPBENCHLOG | awk '{ sum += $10 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	TIMECS=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPBENCHLOG | awk '{ sum += $13 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	echo 
	
	echo -e "bench.php results from $RUNS runs\n$TOTAL"
	echo
	echo "bench.php avg: $AVG"
	echo "Avg: real: ${TIMEREAL}s user: ${TIMEUSER}s sys: ${TIMESYS}s cpu: ${TIMECPU}% maxmem: ${TIMEMEM}KB cswaits: ${TIMECS}"
	echo "created results log at $PHPBENCHLOG"
	echo "server PHP info log at ${PHPBENCHLOGDIR}/bench_phpinfo_${DT}.log"
	
	echo
}

fmicrobench() {
	cecho "-------------------------------------------" $boldgreen
	cecho "Run PHP test Zend/micro_bench.php" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	
	changedir
	touch $PHPMICROBENCHLOG
	echo -e "\n$(date)" >> $PHPMICROBENCHLOG
	for ((i = 0 ; i < $RUNS ; i++)); do
		{
		echo
		
		/usr/bin/time --format='real: %es user: %Us sys: %Ss cpu: %P maxmem: %M KB cswaits: %w' php Zend/micro_bench.php
		
		phpmem
		} 2>&1 | tee -a $PHPMICROBENCHLOG
	done
	MTOTAL=$(awk '/Total/ {print $2}' $PHPMICROBENCHLOG)
	MAVG=$(awk '/Total/ {print $2}' $PHPMICROBENCHLOG | awk '{ sum += $1 } END { if (NR > 0) printf "%.4f\n", sum / NR }')
	MTIMEREAL=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPMICROBENCHLOG | awk '{ sum += $2 } END { if (NR > 0) printf "%.2f\n", sum / NR }')
	MTIMEUSER=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPMICROBENCHLOG | awk '{ sum += $4 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	MTIMESYS=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPMICROBENCHLOG | awk '{ sum += $6 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	MTIMECPU=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPMICROBENCHLOG | awk '{ sum += $8 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	MTIMEMEM=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPMICROBENCHLOG | awk '{ sum += $10 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	MTIMECS=$(echo $TOTAL | awk '/maxmem:/ {print $0}' $PHPMICROBENCHLOG | awk '{ sum += $13 } END { if (NR > 0) printf "%.2f\n", sum / NR }' )
	echo 
	
	echo -e "micro_bench.php results from $RUNS runs\n$MTOTAL"
	echo
	echo "micro_bench.php avg: $MAVG"
	echo "Avg: real: ${MTIMEREAL}s user: ${MTIMEUSER}s sys: ${MTIMESYS}s cpu: ${MTIMECPU}% maxmem: ${MTIMEMEM}KB cswaits: ${MTIMECS}"
	echo "created results log at $PHPMICROBENCHLOG"
	echo "server PHP info log at ${PHPBENCHLOGDIR}/bench_phpinfo_${DT}.log"
	
	echo
}

diskdd() {

	if [[ "$RUN_DISKDD" = [yY] ]]; then
	bbcodestart
	cecho "-------------------------------------------" $boldgreen
	cecho "disk DD tests" $boldyellow
	cecho "-------------------------------------------" $boldgreen

	s
	cecho "dd if=/dev/zero of=sb-io-test bs=1M count=1k conv=fdatasync"	$boldyellow
	dd if=/dev/zero of=sb-io-test bs=1M count=1k conv=fdatasync
	
	s
	cecho "dd if=/dev/zero of=sb-io-test bs=64k count=16k conv=fdatasync" $boldyellow
	dd if=/dev/zero of=sb-io-test bs=64k count=16k conv=fdatasync

	s	
	cecho "dd if=/dev/zero of=sb-io-test bs=1M count=1k oflag=dsync" $boldyellow
	dd if=/dev/zero of=sb-io-test bs=1M count=1k oflag=dsync
	
	s
	cecho "dd if=/dev/zero of=sb-io-test bs=64k count=16k oflag=dsync" $boldyellow
	dd if=/dev/zero of=sb-io-test bs=64k count=16k oflag=dsync

	rm -rf sb-io-test 2>/dev/null
	# cd ..
	bbcodeend
	fi
}

diskioping() {

	if [[ "$RUN_DISKIOPING" = [yY] ]]; then
	bbcodestart
	cecho "-------------------------------------------" $boldgreen
	cecho "disk ioping tests" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	cd $BENCHDIR

        # cecho "Download ioping-$IOPING_VERSION.tar.gz ..." $boldyellow
    if [ -s ioping-$IOPING_VERSION.tar.gz ]; then
        # cecho "ioping-$IOPING_VERSION.tar.gz found, skipping download..." $boldgreen
        s
    else
        wget -cnv --no-check-certificate https://ioping.googlecode.com/files/ioping-$IOPING_VERSION.tar.gz --tries=3
ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
	cecho "Error: ioping-$IOPING_VERSION.tar.gz download failed." $boldgreen
	exit #$ERROR
else 
         cecho "Download done." $boldyellow
	fi
    fi

if [ ! -d ioping-$IOPING_VERSION ]; then
	tar xzf ioping-$IOPING_VERSION.tar.gz
	ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
		cecho "Error: ioping-$IOPING_VERSION.tar.gz extraction failed." $boldgreen
		exit #$ERROR
	else 
         cecho "ioping-$IOPING_VERSION.tar.gz valid file." $boldyellow
		echo ""
	fi
fi

	cecho "Running IOPing I/O benchmark..." $boldyellow
	cd $IOPING_DIR
	if [ ! -f ioping ]; then
		make -j${CPUS} 2>&1
	fi
	s
	cecho "IOPing I/O: ./ioping -c 10 ." $boldyellow
	./ioping -c 10 .
	s
	cecho "IOPing seek rate: ./ioping -RD ." $boldyellow
	./ioping -RD .
	s
	cecho "IOPing sequential: ./ioping -RL ." $boldyellow
	./ioping -RL .
	s
	cecho "IOPing cached: ./ioping -RC ." $boldyellow
	./ioping -RC .
	s
	bbcodeend
	fi	
}

diskfio() {
	if [[ "$RUN_DISKFIO" = [yY] ]]; then
	bbcodestart
	cecho "-------------------------------------------" $boldgreen
	cecho "disk FIO tests" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	cd $BENCHDIR

        # cecho "Download fio-$FIO_VERSION.tar.gz ..." $boldyellow
    if [ -s fio-$FIO_VERSION.tar.gz ]; then
        # cecho "fio-$FIO_VERSION.tar.gz found, skipping download..." $boldgreen
        s
    else
        wget -cnv --no-check-certificate https://github.com/Crowd9/Benchmark/raw/master/fio-$FIO_VERSION.tar.gz --tries=3
ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
	cecho "Error: fio-$FIO_VERSION.tar.gz download failed." $boldgreen
	exit #$ERROR
else 
         cecho "Download done." $boldyellow
	fi
    fi

if [ ! -d fio-$FIO_VERSION ]; then
	tar xzf fio-$FIO_VERSION.tar.gz
	ERROR=$?
	if [[ "$ERROR" != '0' ]]; then
		cecho "Error: fio-$FIO_VERSION.tar.gz extraction failed." $boldgreen
		exit #$ERROR
	else 
         cecho "fio-$FIO_VERSION.tar.gz valid file." $boldyellow
		echo ""
	fi
fi

cat > $FIO_DIR/reads.ini << EOF
[global]
randrepeat=1
ioengine=libaio
bs=4k
ba=4k
size=1G
direct=1
gtod_reduce=1
norandommap
iodepth=64
numjobs=1

[randomreads]
startdelay=0
filename=sb-io-test
readwrite=randread
EOF

cat > $FIO_DIR/writes.ini << EOF
[global]
randrepeat=1
ioengine=libaio
bs=4k
ba=4k
size=1G
direct=1
gtod_reduce=1
norandommap
iodepth=64
numjobs=1

[randomwrites]
startdelay=0
filename=sb-io-test
readwrite=randwrite
EOF

cecho "Running FIO benchmark..." $boldyellow
s
cd $FIO_DIR
make -j${CPUS} 2>&1

s
cecho "FIO random reads: " $boldyellow
./fio reads.ini

s
cecho "FIO random writes: " $boldyellow
./fio writes.ini

rm -rf sb-io-test 2>/dev/null
s
	bbcodeend
	fi
}

download_benchmark() {
  cecho "Download from $1 ($2)" $boldyellow
  DOWNLOAD_SPEED=`wget --timeout=300 -O /dev/null $2 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}'`
  # cecho "Got $DOWNLOAD_SPEED" $boldyellow
  cecho "Download $1: $DOWNLOAD_SPEED" $boldyellow 2>&1 
}

bandwidthbench() {
	if [[ "$RUN_BANDWIDTHBENCH" = [yY] ]]; then
	bbcodestart
	s
	cecho "-------------------------------------------" $boldgreen
	cecho "Running bandwidth benchmark..." $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s
	
		div
		download_benchmark 'Cachefly' 'http://cachefly.cachefly.net/100mb.test'
		
		if [[ "$USA_BANDWIDTHTESTS" = [yY] ]]; then
		s
		cecho "-------------------------------------------" $boldgreen
		cecho "USA bandwidth tests..." $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		div
		download_benchmark 'Linode, Atlanta, GA, USA' 'http://speedtest.atlanta.linode.com/100MB-atlanta.bin'
		div
		download_benchmark 'Linode, Dallas, TX, USA' 'http://speedtest.dallas.linode.com/100MB-dallas.bin'
		div
		download_benchmark 'Leaseweb, Manassas, VA, USA' 'http://mirror.us.leaseweb.net/speedtest/100mb.bin'
		div
		download_benchmark 'Softlayer, Seattle, WA, USA' 'http://speedtest.sea01.softlayer.com/downloads/test100.zip'
		div
		download_benchmark 'Softlayer, San Jose, CA, USA' 'http://speedtest.sjc01.softlayer.com/downloads/test100.zip'
		div
		download_benchmark 'Softlayer, Washington, DC, USA' 'http://speedtest.wdc01.softlayer.com/downloads/test100.zip'
		div
		download_benchmark 'VersaWeb, Las Vegas, Nevada' 'http://199.47.210.50/100mbtest.bin'
		div
		download_benchmark 'OVH, BHS, Canada' 'http://bhs.proof.ovh.net/files/100Mio.dat'
			if [[ "$RUN_VULTRTESTS" = [yY] ]]; then
			div
			download_benchmark 'Vultr, Los Angeles, California' 'http://lax-ca-us-ping.vultr.com/vultr.com.100MB.bin'
			div
			download_benchmark 'Vultr, Seattle, Washington' 'http://wa-us-ping.vultr.com/vultr.com.100MB.bin'
			div
			download_benchmark 'Vultr, Dallas, Texas' 'http://tx-us-ping.vultr.com/vultr.com.100MB.bin'
			div
			download_benchmark 'Vultr, Chicago, Illinois' 'http://il-us-ping.vultr.com/vultr.com.100MB.bin'
			div
			download_benchmark 'Vultr, Atlanta, Georgia' 'http://ga-us-ping.vultr.com/vultr.com.100MB.bin'
			div
			download_benchmark 'Vultr, Miami, Florida' 'http://fl-us-ping.vultr.com/vultr.com.100MB.bin'
			div
			download_benchmark 'Vultr, New York / New Jersey' 'http://nj-us-ping.vultr.com/vultr.com.100MB.bin'
			fi
		fi

		if [[ "$ASIA_BANDWIDTHTESTS" = [yY] ]]; then
		s
		cecho "-------------------------------------------" $boldgreen
		cecho "Asia bandwidth tests..." $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		div
		download_benchmark 'Linode, Tokyo, JP' 'http://speedtest.tokyo.linode.com/100MB-tokyo.bin'
		div
		download_benchmark 'Softlayer, Singapore' 'http://speedtest.sng01.softlayer.com/downloads/test100.zip'
			if [[ "$RUN_VULTRTESTS" = [yY] ]]; then
			div
			download_benchmark 'Vultr, Tokyo, Japan' 'http://hnd-jp-ping.vultr.com/vultr.com.100MB.bin'
			fi
		fi
		
		if [[ "$EUROPE_BANDWIDTHTESTS" = [yY] ]]; then
		s
		cecho "-------------------------------------------" $boldgreen
		cecho "Europe bandwidth tests..." $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		div
		download_benchmark 'Linode, London, UK' 'http://speedtest.london.linode.com/100MB-london.bin'
		div
		download_benchmark 'OVH, Paris, France' 'http://proof.ovh.net/files/100Mio.dat'
		div
		download_benchmark 'SmartDC, Rotterdam, Netherlands' 'http://mirror.i3d.net/100mb.bin'
			if [[ "$RUN_VULTRTESTS" = [yY] ]]; then
			div
			download_benchmark 'Vultr, Amsterdam, Netherlands' 'http://ams-nl-ping.vultr.com/vultr.com.100MB.bin'
			div
			download_benchmark 'Vultr, London, UK' 'http://lon-gb-ping.vultr.com/vultr.com.100MB.bin'
			div
			download_benchmark 'Vultr, Paris, France' 'http://par-fr-ping.vultr.com/vultr.com.100MB.bin'
			fi
		fi
			
		if [[ "$AUSTRALIA_BANDWIDTHTESTS" = [yY] ]]; then
		s
		cecho "-------------------------------------------" $boldgreen
		cecho "Australia bandwidth tests..." $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
			if [[ "$RUN_VULTRTESTS" = [yY] ]]; then
			div
			download_benchmark 'Vultr, Sydney, Australia' 'http://syd-au-ping.vultr.com/vultr.com.100MB.bin'
			fi
		fi
		bbcodeend	
	fi
}

pingtests() {
	if [[ "$RUN_PINGTESTS" = [yY] ]]; then
	bbcodestart
	s
	cecho "-------------------------------------------" $boldgreen
	cecho "Running ping tests..." $boldyellow
	cecho "-------------------------------------------" $boldgreen

	s
	div
	cecho "Pings (cachefly.cachefly.net):" $boldyellow
	ping -c 3 cachefly.cachefly.net 2>&1

	s
	div
	cecho "Pings (syd-au-ping.vultr.com):" $boldyellow
	ping -c 3 syd-au-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (hnd-jp-ping.vultr.com):" $boldyellow
	ping -c 3 hnd-jp-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (lax-ca-us-ping.vultr.com):" $boldyellow
	ping -c 3 lax-ca-us-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (wa-us-ping.vultr.com):" $boldyellow
	ping -c 3 wa-us-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (tx-us-ping.vultr.com):" $boldyellow
	ping -c 3 tx-us-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (il-us-ping.vultr.com):" $boldyellow
	ping -c 3 il-us-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (ga-us-ping.vultr.com):" $boldyellow
	ping -c 3 ga-us-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (fl-us-ping.vultr.com):" $boldyellow
	ping -c 3 fl-us-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (nj-us-ping.vultr.com):" $boldyellow
	ping -c 3 nj-us-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (fra-de-ping.vultr.com):" $boldyellow
	ping -c 3 fra-de-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (ams-nl-ping.vultr.com):" $boldyellow
	ping -c 3 ams-nl-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (lon-gb-ping.vultr.com):" $boldyellow
	ping -c 3 lon-gb-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (par-fr-ping.vultr.com):" $boldyellow
	ping -c 3 par-fr-ping.vultr.com 2>&1

	s
	div
	cecho "Pings (VersaWeb Las Vegas):" $boldyellow
	ping -c 3 199.47.210.50 2>&1

	s
	div
	cecho "Pings (VersaWeb Seattle):" $boldyellow
	ping -c 3 76.164.234.1 2>&1

	s
	div
	cecho "Pings (OVH Canada):" $boldyellow
	ping -c 3 bhs.proof.ovh.net 2>&1

	s
	bbcodeend
	fi
}

# add MTR tests
# https://www.linode.com/docs/networking/diagnosing-network-issues-with-mtr
mtrtests() {
	if [[ "$RUN_MTRTESTS" = [yY] ]]; then
	bbcodestart
	s
	cecho "-------------------------------------------" $boldgreen
	cecho "Running mtr tests..." $boldyellow
	cecho "-------------------------------------------" $boldgreen

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} cachefly.cachefly.net" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} cachefly.cachefly.net 2>&1

    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} speedtest.atlanta.linode.com" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} speedtest.atlanta.linode.com 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} speedtest.dallas.linode.com" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} speedtest.dallas.linode.com 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} mirror.us.leaseweb.net" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} mirror.us.leaseweb.net 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} speedtest.sea01.softlayer.com" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} speedtest.sea01.softlayer.com 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} speedtest.sjc01.softlayer.com" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} speedtest.sjc01.softlayer.com 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} speedtest.wdc01.softlayer.com" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} speedtest.wdc01.softlayer.com 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} speedtest.tokyo.linode.com" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} speedtest.tokyo.linode.com 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} speedtest.sng01.softlayer.com" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} speedtest.sng01.softlayer.com 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} speedtest.london.linode.com" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} speedtest.london.linode.com 2>&1
    
    s
    div
    cecho "mtr --report --report-cycles=${MTR_PACKETS} mirror.i3d.net" $boldyellow
    mtr --report --report-cycles=${MTR_PACKETS} mirror.i3d.net 2>&1
    
	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} syd-au-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} syd-au-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} hnd-jp-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} hnd-jp-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} lax-ca-us-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} lax-ca-us-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} wa-us-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} wa-us-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} tx-us-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} tx-us-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} il-us-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} il-us-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} ga-us-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} ga-us-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} fl-us-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} fl-us-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} nj-us-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} nj-us-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} fra-de-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} fra-de-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} ams-nl-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} ams-nl-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} lon-gb-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} lon-gb-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} par-fr-ping.vultr.com" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} par-fr-ping.vultr.com 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} VersaWeb Las Vegas" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} 199.47.210.50 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} VersaWeb Seattle" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} 76.164.234.1 2>&1

	s
	div
	cecho "mtr --report --report-cycles=${MTR_PACKETS} OVH Canada" $boldyellow
	mtr --report --report-cycles=${MTR_PACKETS} bhs.proof.ovh.net 2>&1

	s
	bbcodeend
	fi
}

ended() {
	s
	cecho "-------------------------------------------" $boldgreen
	cecho "$SCRIPTNAME completed" $boldyellow
	cecho "-------------------------------------------" $boldgreen
}
########################
# compression

funct_pigzinstall() {

if [ ! -f /usr/bin/pigz ]; then

cd $SRCDIR

if [ -s pigz-2.3.tar.gz ]; then
  cecho "pigz-2.3.tar.gz [found]" $boldyellow
  else
  cecho "Error: pigz-2.3.tar.gz not found!!!download now......" $boldyellow
  wget -q --no-check-certificate https://github.com/madler/pigz/tarball/v2.3 -O  pigz-2.3.tar.gz --tries=3
fi

tar xzf pigz-2.3.tar.gz
#cd pigz-2.3
cd madler-pigz*
make -j${CPUS} 2>&1
cp pigz unpigz /usr/bin
ls -lh /usr/bin | grep pigz

fi

}

funct_pbzip2install() {

if [ ! -f /usr/bin/pbzip2 ]; then

cd $SRCDIR

if [ -s pbzip2-1.1.8.tar.gz ]; then
  cecho "pbzip2-1.1.8.tar.gz [found]" $boldyellow
  else
  cecho "Error: pbzip2-1.1.8.tar.gz not found!!!download now......" $boldyellow
  wget -q http://compression.ca/pbzip2/pbzip2-1.1.8.tar.gz --tries=3
fi

tar xzf pbzip2-1.1.8.tar.gz
cd pbzip2-1.1.8
make -j${CPUS} 2>&1
cp pbzip2 /usr/bin

fi

}

funct_lbzip2install() {

if [ ! -f /usr/local/bin/lbzip2 ]; then

cd $SRCDIR

if [ -s lbzip2-2.5.tar.gz ]; then
  cecho "lbzip2-2.5.tar.gz [found]" $boldyellow
  else
  cecho "Error: lbzip2-2.5.tar.gz not found!!!download now......" $boldyellow
  wget -q --no-check-certificate https://github.com/downloads/kjn/lbzip2/lbzip2-2.5.tar.gz --tries=3
fi

tar xzf lbzip2-2.5.tar.gz
cd lbzip2-2.5
./configure 2>&1
make -j${CPUS} 2>&1
make install 2>&1

fi

}

funct_lzipinstall() {

if [ ! -f /usr/local/bin/lzip ]; then

cd $SRCDIR

if [ -s lzip-1.16.tar.gz ]; then
  cecho "lzip-1.16.tar.gz [found]" $boldyellow
  else
  cecho "Error: lzip-1.16.tar.gz not found!!!download now......" $boldyellow
  wget -q http://download.savannah.gnu.org/releases/lzip/lzip-1.16.tar.gz --tries=3
fi

tar xzf lzip-1.16.tar.gz
cd lzip-1.16
./configure 2>&1
make -j${CPUS} 2>&1
make install 2>&1

fi

}

funct_plzipinstall() {

if [ ! -f /usr/local/bin/plzip ]; then

cd $SRCDIR

if [ -s lzlib-1.6.tar.gz ]; then
  cecho "lzlib-1.6.tar.gz [found]" $boldyellow
  else
  cecho "Error: lzlib-1.6.tar.gz not found!!!download now......" $boldyellow
  wget -q http://download.savannah.gnu.org/releases/lzip/lzlib-1.6.tar.gz --tries=3
fi

if [ -s plzip-1.1.tar.gz ]; then
  cecho "plzip-1.1.tar.gz [found]" $boldyellow
  else
  cecho "Error: plzip-1.1.tar.gz not found!!!download now......" $boldyellow
  wget -q http://download.savannah.gnu.org/releases/lzip/plzip-1.1.tar.gz --tries=3
fi

tar xzf lzlib-1.6.tar.gz
cd lzlib-1.6
./configure 2>&1
make -j${CPUS} 2>&1
make install 2>&1

cd ../

tar xzf plzip-1.1.tar.gz
cd plzip-1.1
./configure 2>&1
make -j${CPUS} 2>&1
make install 2>&1

fi

}

funct_p7zipinstall() {

if [ ! -f /usr/local/bin/7za ]; then

cd $SRCDIR

if [ -s z922.tar.bz2 ]; then
  cecho "z922.tar.bz2 [found]" $boldyellow
  else
  cecho "Error: z922.tar.bz2 not found!!!download now......" $boldyellow
  wget -q http://aarnet.dl.sourceforge.net/project/p7zip/p7zip/9.20.1/z922.tar.bz2 --tries=3
fi

bzip2 -d z922.tar.bz2
tar xf z922.tar.tar
cd p7zip_9.22
./install.sh 2>&1
make -j${CPUS} 2>&1
make install 2>&1

fi

}

funct_xzinstall() {

if [ ! -f /usr/bin/xz ]; then

cd $SRCDIR

if [ -s xz-5.0.5.tar.gz ]; then
  cecho "xz-5.0.5.tar.gz [found]" $boldyellow
  else
  cecho "Error: xz-5.0.5.tar.gz not found!!!download now......" $boldyellow
  wget -q http://tukaani.org/xz/xz-5.0.5.tar.gz --tries=3
fi

tar xzf xz-5.0.5.tar.gz
cd xz-5.0.5
# bash autogen.sh 2>&1
./configure 2>&1
make -j${CPUS} 2>&1
make install 2>&1

fi

}

compressinstall() {
	if [ -f /etc/centminmod-release ]; then
		s
		cecho "-------------------------------------------" $boldgreen
		cecho "Install Compression Tools..." $boldyellow
		cecho "-------------------------------------------" $boldgreen
		s
		div
		funct_pigzinstall
		div
		funct_pbzip2install
		div
		funct_lbzip2install
		div
		funct_lzipinstall
		div
		funct_plzipinstall
		div
		funct_p7zipinstall
		div
		funct_xzinstall
		s
	fi
}


################################
funct_levelgzip() {

APP='gzip'

if [ -f $TESTFILE.gz ]; then
echo "detected already compressed target file: $TESTFILE.gz"
echo "decompress before doing compression tests"
echo "$APP -d $TESTFILE.gz"
$APP -d $TESTFILE.gz
cleanmem
# echo "aborting script... please rerun"
# exit
else

echo "### $APP compression/decompression test"
for i in $(seq 1 $COMPLEVEL) ; do
  echo "------------------------------------------------------------------------------"
  echo " [compress lvl: $i ] $APP --rsyncable -$i $TESTFILE"
  echo -n " [compress stats:] "
  /usr/bin/time --format='real: %es cpu: %P maxmem: %M KB cswaits: %w' $APP --rsyncable -$i $TESTFILE

COMPSIZE=`ls -lak $TESTFILE.gz | awk '{ print $5 }'`
LSFILE=`ls -lak $TESTFILE.gz | awk '{ print $9 }'`
COMPPERC=`echo $((${COMPSIZE}*100/${TESTFILESIZE}))`
  echo " compression ratio: ${COMPPERC}% $COMPSIZE / $TESTFILESIZE KB"

if [[ "$i" = "$COMPLEVEL" || "$DECOMPTIMED" = 'y' ]]; then
cleanmem
  echo "------------------------------------------------------------------------------"
  echo " [decompress] $APP -d $TESTFILE.gz"
  echo -n " [decompress stats:] "
  /usr/bin/time --format='real: %es cpu: %P maxmem: %M KB cswaits: %w' $APP -d $TESTFILE.gz

else
$APP -d $TESTFILE.gz
fi

cleanmem

done

fi

}

################################
funct_levelbzip2() {

APP='bzip2'

if [ -f $TESTFILE.bz2 ]; then
echo "detected already compressed target file: $TESTFILE.bz2"
echo "decompress before doing compression tests"
echo "$APP -df $TESTFILE.bz2"
$APP -df $TESTFILE.bz2
cleanmem
# echo "aborting script... please rerun"
# exit
else

echo "### $APP compression/decompression test"
for i in $(seq 1 $COMPLEVEL) ; do
  echo "------------------------------------------------------------------------------"
  echo " [compress lvl: $i ] $APP -$i $TESTFILE"
  echo -n " [compress stats:] "
  /usr/bin/time --format='real: %es cpu: %P maxmem: %M KB cswaits: %w' $APP -$i $TESTFILE

COMPSIZE=`ls -lak $TESTFILE.bz2 | awk '{ print $5 }'`
LSFILE=`ls -lak $TESTFILE.bz2 | awk '{ print $9 }'`
COMPPERC=`echo $((${COMPSIZE}*100/${TESTFILESIZE}))`
  echo " compression ratio: ${COMPPERC}% $COMPSIZE / $TESTFILESIZE KB"

if [[ "$i" = "$COMPLEVEL" || "$DECOMPTIMED" = 'y' ]]; then
cleanmem
  echo "------------------------------------------------------------------------------"
  echo " [decompress] $APP -d $TESTFILE.bz2"
  echo -n " [decompress stats:] "
  /usr/bin/time --format='real: %es cpu: %P maxmem: %M KB cswaits: %w' $APP -d $TESTFILE.bz2

else
$APP -d $TESTFILE.bz2
fi

cleanmem

done

fi

}

################################
funct_levelpigz() {

APP='pigz'

if [ -f $TESTFILE.gz ]; then
echo "detected already compressed target file: $TESTFILE.gz"
echo "decompress before doing compression tests"
echo "$APP -d $TESTFILE.gz"
$APP -d $TESTFILE.gz
cleanmem
# echo "aborting script... please rerun"
# exit
else

echo "### $APP compression/decompression test"
for i in $(seq 1 $COMPLEVEL) ; do
  echo "------------------------------------------------------------------------------"
  echo " [compress lvl: $i ] $APP -R -${i}$PIGZBLOCKSIZE $TESTFILE"
  echo -n " [compress stats:] "
  /usr/bin/time --format='real: %es cpu: %P maxmem: %M KB cswaits: %w' $APP -R -${i}$PIGZBLOCKSIZE $TESTFILE

COMPSIZE=`ls -lak $TESTFILE.gz | awk '{ print $5 }'`
LSFILE=`ls -lak $TESTFILE.gz | awk '{ print $9 }'`
COMPPERC=`echo $((${COMPSIZE}*100/${TESTFILESIZE}))`
  echo " compression ratio: ${COMPPERC}% $COMPSIZE / $TESTFILESIZE KB"

if [[ "$i" = "$COMPLEVEL" || "$DECOMPTIMED" = 'y' ]]; then
cleanmem
  echo "------------------------------------------------------------------------------"
  echo " [decompress] $APP -d $TESTFILE.gz"
  echo -n " [decompress stats:] "
  /usr/bin/time --format='real: %es cpu: %P maxmem: %M KB cswaits: %w' $APP -d $TESTFILE.gz

else
$APP -d $TESTFILE.gz
fi

cleanmem

done

fi

}

################################
funct_levellbzip2() {

APP='lbzip2'

if [ -f $TESTFILE.bz2 ]; then
echo "detected already compressed target file: $TESTFILE.bz2"
echo "decompress before doing compression tests"
echo "$APP -d $TESTFILE.bz2"
$APP -d $TESTFILE.bz2
cleanmem
# echo "aborting script... please rerun"
# exit
else

echo "### $APP compression/decompression test"
for i in $(seq 1 $COMPLEVEL) ; do
  echo "------------------------------------------------------------------------------"
  echo " [compress lvl: $i ] $APP -${i}$LBZIP2BLOCKSIZE $TESTFILE"
  echo -n " [compress stats:] "
  /usr/bin/time --format='real: %es cpu: %P maxmem: %M KB cswaits: %w' $APP -${i}$LBZIP2BLOCKSIZE $TESTFILE

COMPSIZE=`ls -lak $TESTFILE.bz2 | awk '{ print $5 }'`
LSFILE=`ls -lak $TESTFILE.bz2 | awk '{ print $9 }'`
COMPPERC=`echo $((${COMPSIZE}*100/${TESTFILESIZE}))`
  echo " compression ratio: ${COMPPERC}% $COMPSIZE / $TESTFILESIZE KB"

if [[ "$i" = "$COMPLEVEL" || "$DECOMPTIMED" = 'y' ]]; then
cleanmem
  echo "------------------------------------------------------------------------------"
  echo " [decompress] $APP -d$DCOMPTHREADS $TESTFILE.bz2"
  echo -n " [decompress stats:] "
  /usr/bin/time --format='real: %es cpu: %P maxmem: %M KB cswaits: %w' $APP -d$DCOMPTHREADS $TESTFILE.bz2

  rm -rf $TESTFILE.bz2

else
$APP -d$DCOMPTHREADS $TESTFILE.bz2
  rm -rf $TESTFILE.bz2
fi

cleanmem

done

fi

}

########################

axel_benchmark() {
  cecho "Axel Download from $1 ($2)" $boldyellow
  SFILENAME=$(echo ${2##*/})
  DOWNLOAD_SPEED=$(axel -a $2 2>&1 | awk '/Downloaded/ {speed=$7 $8} END {gsub(/\(|\)|KB\/s/,"",speed); print speed}')
  SPEEDMB=$(echo "scale=2;${DOWNLOAD_SPEED}/1024" | bc)
  cecho "Axel Download $1: ${SPEEDMB}MB/s" $boldyellow 2>&1
  rm -rf $SFILENAME
}


axelbench() {
  if [[ "$RUN_AXELBENCH" = [yY] ]]; then
  bbcodestart
  s
  cecho "-------------------------------------------" $boldgreen
  cecho "Running Axel multi-threaded bandwidth benchmark..." $boldyellow
  cecho "-------------------------------------------" $boldgreen
  s
  
    div
    axel_benchmark 'Cachefly' 'http://cachefly.cachefly.net/100mb.test'
    
    if [[ "$USA_BANDWIDTHTESTS" = [yY] ]]; then
    s
    cecho "-------------------------------------------" $boldgreen
    cecho "USA bandwidth tests..." $boldyellow
    cecho "-------------------------------------------" $boldgreen
    s
    div
    axel_benchmark 'Linode, Atlanta, GA, USA' 'http://speedtest.atlanta.linode.com/100MB-atlanta.bin'
    div
    axel_benchmark 'Linode, Dallas, TX, USA' 'http://speedtest.dallas.linode.com/100MB-dallas.bin'
    div
    axel_benchmark 'Leaseweb, Manassas, VA, USA' 'http://mirror.us.leaseweb.net/speedtest/100mb.bin'
    div
    axel_benchmark 'Softlayer, Seattle, WA, USA' 'http://speedtest.sea01.softlayer.com/downloads/test100.zip'
    div
    axel_benchmark 'Softlayer, San Jose, CA, USA' 'http://speedtest.sjc01.softlayer.com/downloads/test100.zip'
    div
    axel_benchmark 'Softlayer, Washington, DC, USA' 'http://speedtest.wdc01.softlayer.com/downloads/test100.zip'
    div
    axel_benchmark 'VersaWeb, Las Vegas, Nevada' 'http://199.47.210.50/100mbtest.bin'
    div
    axel_benchmark 'OVH, BHS, Canada' 'http://bhs.proof.ovh.net/files/100Mio.dat'
      if [[ "$RUN_VULTRTESTS" = [yY] ]]; then
      div
      axel_benchmark 'Vultr, Los Angeles, California' 'http://lax-ca-us-ping.vultr.com/vultr.com.100MB.bin'
      div
      axel_benchmark 'Vultr, Seattle, Washington' 'http://wa-us-ping.vultr.com/vultr.com.100MB.bin'
      div
      axel_benchmark 'Vultr, Dallas, Texas' 'http://tx-us-ping.vultr.com/vultr.com.100MB.bin'
      div
      axel_benchmark 'Vultr, Chicago, Illinois' 'http://il-us-ping.vultr.com/vultr.com.100MB.bin'
      div
      axel_benchmark 'Vultr, Atlanta, Georgia' 'http://ga-us-ping.vultr.com/vultr.com.100MB.bin'
      div
      axel_benchmark 'Vultr, Miami, Florida' 'http://fl-us-ping.vultr.com/vultr.com.100MB.bin'
      div
      axel_benchmark 'Vultr, New York / New Jersey' 'http://nj-us-ping.vultr.com/vultr.com.100MB.bin'
      fi
    fi

    if [[ "$ASIA_BANDWIDTHTESTS" = [yY] ]]; then
    s
    cecho "-------------------------------------------" $boldgreen
    cecho "Asia bandwidth tests..." $boldyellow
    cecho "-------------------------------------------" $boldgreen
    s
    div
    axel_benchmark 'Linode, Tokyo, JP' 'http://speedtest.tokyo.linode.com/100MB-tokyo.bin'
    div
    axel_benchmark 'Softlayer, Singapore' 'http://speedtest.sng01.softlayer.com/downloads/test100.zip'
      if [[ "$RUN_VULTRTESTS" = [yY] ]]; then
      div
      axel_benchmark 'Vultr, Tokyo, Japan' 'http://hnd-jp-ping.vultr.com/vultr.com.100MB.bin'
      fi
    fi
    
    if [[ "$EUROPE_BANDWIDTHTESTS" = [yY] ]]; then
    s
    cecho "-------------------------------------------" $boldgreen
    cecho "Europe bandwidth tests..." $boldyellow
    cecho "-------------------------------------------" $boldgreen
    s
    div
    axel_benchmark 'Linode, London, UK' 'http://speedtest.london.linode.com/100MB-london.bin'
    div
    axel_benchmark 'OVH, Paris, France' 'http://proof.ovh.net/files/100Mio.dat'
    div
    axel_benchmark 'SmartDC, Rotterdam, Netherlands' 'http://mirror.i3d.net/100mb.bin'
      if [[ "$RUN_VULTRTESTS" = [yY] ]]; then
      div
      axel_benchmark 'Vultr, Amsterdam, Netherlands' 'http://ams-nl-ping.vultr.com/vultr.com.100MB.bin'
      div
      axel_benchmark 'Vultr, London, UK' 'http://lon-gb-ping.vultr.com/vultr.com.100MB.bin'
      div
      axel_benchmark 'Vultr, Paris, France' 'http://par-fr-ping.vultr.com/vultr.com.100MB.bin'
      fi
    fi
      
    if [[ "$AUSTRALIA_BANDWIDTHTESTS" = [yY] ]]; then
    s
    cecho "-------------------------------------------" $boldgreen
    cecho "Australia bandwidth tests..." $boldyellow
    cecho "-------------------------------------------" $boldgreen
    s
      if [[ "$RUN_VULTRTESTS" = [yY] ]]; then
      div
      axel_benchmark 'Vultr, Sydney, Australia' 'http://syd-au-ping.vultr.com/vultr.com.100MB.bin'
      fi
    fi
    bbcodeend 
  fi
}

########################

if [[ "$1" = cleanup ]]; then
  rm -rf /home/centminmodbench
  rm -rf /home/centminmodbench_logs
  rm -rf /home/mysqlslap
  rm -rf /home/phpbench_logs
  rm -rf /home/gziptest
  s
  div
  cecho "cleaned up folders and logs" $boldyellow
  cecho "manually remove the file to complete process:" $boldyellow
  cecho "/root/tools/centminmodbench.sh" $boldyellow
  div
  exit
  s
fi

# cecho "starting..." $boldyellow

starttime=$(date +%s.%N)
{
	bbcodestart
	byline
	baseinfo
	bbcodeend
	
	diskioping
	diskdd
	diskfio
	ramdisktest
	
	bandwidthbench

	if [ -f /etc/centminmod-release ]; then
		axelbench
	fi

	pingtests
	mtrtests
	
	entropycheck
	opensslbench
		
	mysqlslapper
		
	if [ -f /etc/centminmod-release ]; then
		if [[ "$RUN_PHPTESTS" = [yY] ]]; then
		bbcodestart
		phpi
		restartphp
		fbench
		restartphp
		fmicrobench
		bbcodeend
		fi
	fi
		
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

if [[ "$AUTOREPORT" != [yY] ]]; then
	########################
	# sanitise output
	s
	cecho "----------------------------------------------------" $boldgreen
	cecho "Sanitising Results..." $boldyellow
	cecho "Generating Public Report Log you can share..." $boldyellow
	cecho "at: ${LOGDIR}/_publicreport_${DT}.log" $boldyellow
	cecho "----------------------------------------------------" $boldgreen
	cecho "View Public Report type in SSH window (copy/paste & run):" $boldyellow
	s
	echo "clear && printf '\e[3J'; cat ${LOGDIR}/_publicreport_${DT}.log"
	cecho "----------------------------------------------------" $boldgreen
	s

	cat ${LOGDIR}/centminmodbench_results_${DT}.log | egrep -v ' CC |ccache gcc|+DT:|+R:|+DTP:|+R1:|+R2:|+R5:|+R6|Forked child|Got:|make: Nothing|DEP .depend' | sed -e "s/$HOSTNAME/hostname/g" | perl -pe 's/\x1b.*?[mGKH]//g' > ${LOGDIR}/_publicreport_${DT}.log 2>&1
else
	cat ${LOGDIR}/centminmodbench_results_${DT}.log | egrep -v ' CC |ccache gcc|+DT:|+R:|+DTP:|+R1:|+R2:|+R5:|+R6|Forked child|Got:|make: Nothing|DEP .depend' | sed -e "s/$HOSTNAME/hostname/g" | perl -pe 's/\x1b.*?[mGKH]//g' > ${LOGDIR}/_publicreport_${DT}.log 2>&1

	clear && printf '\e[3J'; cat ${LOGDIR}/_publicreport_${DT}.log
	s
	cecho "----------------------------------------------------" $boldgreen
	cecho "Generated Public Report Log you can share..." $boldyellow
	cecho "at: ${LOGDIR}/_publicreport_${DT}.log" $boldyellow
	cecho "----------------------------------------------------" $boldgreen
	s
fi

exit