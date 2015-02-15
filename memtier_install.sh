#!/bin/bash
######################################################
# memtier redis/memcached benchmark tool installer for
# centminmod.com LEMP web stack servers
# written by George Liu (eva2000) vbtechsupport.com
######################################################
# variables
#############
DT=`date +"%d%m%y-%H%M%S"`
LIBEVENT_VERSION='2.0.21'
MEMTIER_VER='1.2.3'

DIR_TMP=/svr-setup
LIBEVENTLINKFILE="release-${LIBEVENT_VERSION}-stable.tar.gz"
LIBEVENTLINK="https://github.com/libevent/libevent/archive/${LIBEVENTLINKFILE}"
######################################################
# functions
#############
CENTOSVER=$(cat /etc/redhat-release | awk '{ print $3 }')

if [ "$CENTOSVER" == 'release' ]; then
    CENTOSVER=$(cat /etc/redhat-release | awk '{ print $4 }' | cut -d . -f1,2)
    if [[ "$(cat /etc/redhat-release | awk '{ print $4 }' | cut -d . -f1)" = '7' ]]; then
        CENTOS_SEVEN='7'
    fi
fi

if [ "$CENTOSVER" == 'Enterprise' ]; then
    CENTOSVER=$(cat /etc/redhat-release | awk '{ print $7 }')
    OLS='y'
fi

CENTOSVER=$(echo $CENTOSVER | cut -d . -f1)

if [ $(uname -m) == 'x86_64' ];
then
    LIBDIR='lib64'
else
    LIBDIR='lib'
fi

remi() {
if [ ! -f /etc/yum.repos.d/remi.repo ]; then
	if [[ "$CENTOSVER" = '6' ]]; then
		REMIFILE="remi-release-6.rpm"
		REMI="http://rpms.famillecollet.com/enterprise/${REMIFILE}"
	elif [[ "$CENTOSVER" = '6' ]]; then
		REMIFILE="remi-release-7.rpm"
		REMI="http://rpms.famillecollet.com/enterprise/${REMIFILE}"
	fi
	cd $DIR_TMP
	wget ${REMI}
	rpm -i $REMIFILE

ex -s /etc/yum.repos.d/remi.repo << EOF
:/\[remi/ , /gpgkey/
:a
priority=9
exclude=php* mysql*
.
:w
:q
EOF

fi
}

require() {
	echo
	echo "install yum packages"
	yum -q -y install autoconf automake make gcc-c++ install pcre-devel zlib-devel
	yum -q -y install libmemcached-devel --disableplugin=priorities --enablerepo=remi
	remi

	if [[ -z $(rpm -qa redis) ]]; then
		echo
		echo "install redis"
		yum -q -y install redis --disableplugin=priorities --enablerepo=remi
	
		echo
		echo "redis defaults"
		cat /etc/redis.conf | egrep '^appendfsync |^appendonly |^port |^tcp-backlog|^bind|^tcp-keepalive|^requirepass |^# 	maxclients'
	
		sed -i 's/tcp-backlog 511/tcp-backlog 8000/' /etc/redis.conf
		sed -i 's/appendonly no/appendonly yes/' /etc/redis.conf
	
		echo
		echo "redis tweaked"
		cat /etc/redis.conf | egrep '^appendfsync |^appendonly |^port |^tcp-backlog|^bind|^tcp-keepalive|^requirepass |^# 	maxclients'
		
		if [[ -z "$(grep ^vm.overcommit_memory /etc/sysctl.conf)" ]]; then
			echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
			echo
			sysctl -p
			echo
		fi
	
		service redis start
		chkconfig redis on
		redis-cli -v
		redis-server -v
	fi

	echo
	echo "install libevent"
    cd $DIR_TMP
    rm -rf release-${LIBEVENT_VERSION}-stable
    rm -rf libevent-release-${LIBEVENT_VERSION}-stable
    wget --no-check-certificate -cnv $LIBEVENTLINK
    tar xfz release-${LIBEVENT_VERSION}-stable.tar.gz
    cd libevent-release-${LIBEVENT_VERSION}-stable
    make clean
    ./autogen.sh
    ./configure --prefix=/usr/${LIBDIR}
    make -j2
    make install
    echo "/usr/${LIBDIR}/lib/" > /etc/ld.so.conf.d/libevent-i386.conf
	ldconfig
}

memtierinstall() {
	echo
	echo "install memtier_benchmark"
	cd $DIR_TMP
	rm -rf memtier*
	wget --no-check-certificate -cnv -O memtier-${MEMTIER_VER}.tar.gz https://github.com/RedisLabs/memtier_benchmark/archive/${MEMTIER_VER}.tar.gz
	tar xzf memtier-${MEMTIER_VER}.tar.gz
	cd memtier_benchmark-${MEMTIER_VER}
	autoreconf -ivf
	export PKG_CONFIG_PATH=/usr/${LIBDIR}/lib/pkgconfig:${PKG_CONFIG_PATH}
	make clean
	./configure
	make -j2
	make install
	echo
	memtier_benchmark --version | head -n1
	echo
	memtier_benchmark --help
	echo
	echo "example benchmark parameters"
	echo
	echo "memcached_text memtier_benchmark"
	echo "memtier_benchmark -P memcache_text -s 127.0.0.1 -p 11211 --random-data --data-size-range=4-204 --data-size-pattern=S --key-minimum=200 --key-maximum=400 --key-pattern=G:G --key-stddev=10 --key-median=300 2>&1 > memtier_benchmark.log; head -8 memtier_benchmark.log"
	echo ""
	echo "redis memtier_benchmark"
	echo "memtier_benchmark -P redis -s 127.0.0.1 -p 6379 --random-data --data-size-range=4-204 --data-size-pattern=S --key-minimum=200 --key-maximum=400 --key-pattern=G:G --key-stddev=10 --key-median=300 2>&1 > memtier_benchmark.redis.log; head -8 memtier_benchmark.redis.log"
	echo

}
######################################################
require
memtierinstall