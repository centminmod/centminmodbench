#!/bin/bash
###############################################################
# centminmodbench.sh
# https://github.com/centminmod/centminmodbench
# benchmark script for centminmod.com users
#
# merges several existing benchmark scripts I wrote already
# for mysqlslap and php bench.php and micro_bench.php
#
# disk dd, ioping and fio test parameters match those used
# for serverbear.com benchmark runs so they are comparable
#
# inspired by STH Linux benchmark script 
# https://github.com/STH-Dev/linux-bench
###############################################################
SCRIPTNAME=centminmodbench.sh
VER=0.0.1
###############################################################
EMAIL='youremail@yourdomain.com'
DEBUG='n'

SEVERBEAR='n'
OPENSSLBENCH='y'
OPENSSL_NONSYSTEM='y'
OPENSSL_VERSION='1.0.1i'

MYSQLSLAP_SAVECSV='n'

RUN_DISKDD='y'
RUN_DISKIOPING='y'
RUN_DISKFIO='y'
RUN_BANDWIDTHBENCH='y'
EUROPE_BANDWIDTHTESTS='y'
ASIA_BANDWIDTHTESTS='y'
AUSTRALIA_BANDWIDTHTESTS='y'
USA_BANDWIDTHTESTS='y'
RUN_PINGTESTS='y'
RUN_UNIXBENCH='n'
UNIXBENCH_VER='5.1.3'

SHOWPHPSTATS='n'
PHPVER=$(php -v | awk -F " " '{print $2}' | head -n1)

# Print output in a forum friendly [CODE] tag format
BBCODE='y'

# how many runs to do for bench.php & micro_bench.php
# the results will be averaged over that many runs
RUNS='3'

IOPING_VERSION=0.6
FIO_VERSION=2.0.9
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
clients=16 # Concurrecy Level (number of clients)
uniqq=25 # Number of Unique queries to generate (dft = 10)
uniqwn=25 # Number of Unique Write queries to generate (dft = 10)
rowinserts=500 # Number of row inserts per thread (dft = 100)
it=10 # Iterations (number of runs)
secidx=5 # Number of Secondary Indexes
intcol=5 # Number of INT columns
charcol=5 # Number of VARCHAR Columns
queries=15000 # Number of Queries per client

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

if [ ! -d "$PHPBENCHLOGDIR" ]; then
	mkdir -p $PHPBENCHLOGDIR
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

if [[ "$DEBUG" = [yY] ]]; then
	RUN_BANDWIDTHBENCH='n'
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

div() {
	cecho "----------------------------------------------" $boldgreen
}

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
	cecho "openssl speed rsa4096 rsa2048 ecdsap256 sha256 sha1 md5 rc4 aes-256-cbc aes-128-cbc -multi ${CPUS}" $boldyellow
	openssl speed rsa4096 rsa2048 ecdsap256 sha256 sha1 md5 rc4 aes-256-cbc aes-128-cbc -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed -evp aes256 -multi ${CPUS}" $boldyellow
	openssl speed -evp aes256 -multi ${CPUS}

	cecho "-------------------------------------------" $boldgreen
	cecho "openssl speed -evp aes128 -multi ${CPUS}" $boldyellow
	openssl speed -evp aes128 -multi ${CPUS}

	if [[ "$OPENSSL_NONSYSTEM" = [yY] ]]; then
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
        cecho "UnixBench${UNIXBENCH_VER}.tgz found, skipping download..." $boldgreen
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

cleanmem() {
	if [ ! -f /proc/user_beancounters ]; then
		sync && echo 3 > /proc/sys/vm/drop_caches > /dev/null
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
	cat /etc/redhat-release && uname -m
	echo "Centmin Mod $(cat /etc/centminmod-release)"
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

	rm sb-io-test 2>/dev/null
	# cd ..
	fi
}

diskioping() {

	if [[ "$RUN_DISKIOPING" = [yY] ]]; then
	cecho "-------------------------------------------" $boldgreen
	cecho "disk ioping tests" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	cd $BENCHDIR

        cecho "Download ioping-$IOPING_VERSION.tar.gz ..." $boldyellow
    if [ -s ioping-$IOPING_VERSION.tar.gz ]; then
        cecho "ioping-$IOPING_VERSION.tar.gz found, skipping download..." $boldgreen
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
	fi
}

diskfio() {
	if [[ "$RUN_DISKFIO" = [yY] ]]; then
	cecho "-------------------------------------------" $boldgreen
	cecho "disk FIO tests" $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s

	cd $BENCHDIR

        cecho "Download fio-$FIO_VERSION.tar.gz ..." $boldyellow
    if [ -s fio-$FIO_VERSION.tar.gz ]; then
        cecho "fio-$FIO_VERSION.tar.gz found, skipping download..." $boldgreen
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

s
	fi
}

download_benchmark() {
  cecho "Benchmarking download from $1 ($2)" $boldyellow
  DOWNLOAD_SPEED=`wget -O /dev/null $2 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}'`
  # cecho "Got $DOWNLOAD_SPEED" $boldyellow
  cecho "Download $1: $DOWNLOAD_SPEED" $boldyellow 2>&1 
}

bandwidthbench() {
	if [[ "$RUN_BANDWIDTHBENCH" = [yY] ]]; then
	s
	cecho "-------------------------------------------" $boldgreen
	cecho "Running bandwidth benchmark..." $boldyellow
	cecho "-------------------------------------------" $boldgreen
	s
	
		div
		download_benchmark 'Cachefly' 'http://cachefly.cachefly.net/100mb.test'
		
		if [[ "$USA_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Linode, Atlanta, GA, USA' 'http://speedtest.atlanta.linode.com/100MB-atlanta.bin'
		div
		download_benchmark 'Linode, Dallas, TX, USA' 'http://speedtest.dallas.linode.com/100MB-dallas.bin'
		fi

		if [[ "$ASIA_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Linode, Tokyo, JP' 'http://speedtest.tokyo.linode.com/100MB-tokyo.bin'
		fi
		
		if [[ "$EUROPE_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Linode, London, UK' 'http://speedtest.london.linode.com/100MB-london.bin'
		div
		download_benchmark 'OVH, Paris, France' 'http://proof.ovh.net/files/100Mio.dat'
		div
		download_benchmark 'SmartDC, Rotterdam, Netherlands' 'http://mirror.i3d.net/100mb.bin'
		div
		download_benchmark 'Hetzner, Nuernberg, Germany' 'http://hetzner.de/100MB.iso'
		fi
		
		if [[ "$AUSTRALIA_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'iiNet, Perth, WA, Australia' 'http://ftp.iinet.net.au/test100MB.dat'
		div# 
		download_benchmark 'MammothVPS, Sydney, Australia' 'http://www.mammothvpscustomer.com/test100MB.dat'
		fi
		
		# if [[ "$EUROPE_BANDWIDTHTESTS" = [yY] ]]; then
		div# 
		download_benchmark 'Leaseweb, Haarlem, NL' 'http://mirror.nl.leaseweb.net/speedtest/100mb.bin'
		# fi
		
		if [[ "$USA_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Leaseweb, Manassas, VA, USA' 'http://mirror.us.leaseweb.net/speedtest/100mb.bin'
		fi
		
		if [[ "$ASIA_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Softlayer, Singapore' 'http://speedtest.sng01.softlayer.com/downloads/test100.zip'
		fi
		
		if [[ "$USA_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Softlayer, Seattle, WA, USA' 'http://speedtest.sea01.softlayer.com/downloads/test100.zip'
		div
		download_benchmark 'Softlayer, San Jose, CA, USA' 'http://speedtest.sjc01.softlayer.com/downloads/test100.zip'
		div
		download_benchmark 'Softlayer, Washington, DC, USA' 'http://speedtest.wdc01.softlayer.com/downloads/test100.zip'
		fi
		
		if [[ "$AUSTRALIA_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Vultr, Sydney, Australia' 'http://syd-au-ping.vultr.com/vultr.com.100MB.bin'
		fi
		
		if [[ "$ASIA_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Vultr, Tokyo, Japan' 'http://hnd-jp-ping.vultr.com/vultr.com.100MB.bin'
		fi
		
		if [[ "$USA_BANDWIDTHTESTS" = [yY] ]]; then
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
		
		if [[ "$EUROPE_BANDWIDTHTESTS" = [yY] ]]; then
		div
		download_benchmark 'Vultr, Frankfurt, Germany' 'http://fra-de-ping.vultr.com/vultr.com.100MB.bin'
		div
		download_benchmark 'Vultr, Amsterdam, Netherlands' 'http://ams-nl-ping.vultr.com/vultr.com.100MB.bin'
		div
		download_benchmark 'Vultr, London, UK' 'http://lon-gb-ping.vultr.com/vultr.com.100MB.bin'
		div
		download_benchmark 'Vultr, Paris, France' 'http://par-fr-ping.vultr.com/vultr.com.100MB.bin'
		fi
	fi
}

pingtests() {
	if [[ "$RUN_PINGTESTS" = [yY] ]]; then
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
	bbcodestart
	byline
	baseinfo
	diskioping
	diskdd
	diskfio
	bandwidthbench
	pingtests
	opensslbench
	mysqlslapper

	phpi
	restartphp
	fbench
	restartphp
	fmicrobench
	
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
	bbcodeend
} 2>&1 | tee ${LOGDIR}/centminmodbench_results_${DT}.log

endtime=$(date +%s.%N)

INSTALLTIME=$(echo "scale=2;$endtime - $starttime"|bc )
echo "" >> ${LOGDIR}/centminmodbench_results_${DT}.log
echo "$SCRIPTNAME Total Run Time: $INSTALLTIME seconds" >> ${LOGDIR}/centminmodbench_results_${DT}.log
exit