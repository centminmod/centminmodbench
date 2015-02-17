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
TWEMPERF_VER='0.1.1'
MEMTIER_VER='1.2.3'
PHPREDIS_VER='2.2.7'

DIR_TMP=/svr-setup
CONFIGSCANDIR='/etc/centminmod/php.d'
LIBEVENTLINKFILE="release-${LIBEVENT_VERSION}-stable.tar.gz"
LIBEVENTLINK="https://github.com/libevent/libevent/archive/${LIBEVENTLINKFILE}"
TWEMPERF_LINKFILE="twemperf-${TWEMPERF_VER}.tar.gz"
TWEMPERF_LINK="https://github.com/twitter/twemperf/archive/v${TWEMPERF_VER}.tar.gz"
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
		redis-cli INFO KEYSPACE
	
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
    wget --no-check-certificate -cnv $LIBEVENTLINK --tries=3
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

twemperfinstall() {
	echo
	echo "install twemperf"
	cd $DIR_TMP
	wget --no-check-certificate -cnv -O ${TWEMPERF_LINKFILE} ${TWEMPERF_LINK} --tries=3
	tar xzf ${TWEMPERF_LINKFILE}
	cd twemperf-${TWEMPERF_VER}
	make clean
	autoreconf -fvi
	./configure
	make -j2
	make install
	echo
	echo "mcperf -V"
	mcperf -V
	echo
	echo "example benchmark parameters"
	echo
	echo "1000 connections to memcached server 127.0.0.1 11211"
	echo "connections rate = 1000 conns/sec and per connection"
	echo "sends 10 'set' requests at 1000 reqs/sec with item sizes"
	echo "via uniform distribution in the interval of [1,16) bytes"
	echo "mcperf -s 127.0.0.1 -p 11211 --linger=0 --timeout=5 --conn-rate=1000 --call-rate=1000 --num-calls=10 --num-conns=1000 --sizes=u1,16"	
	echo
	echo "mcperf -s 127.0.0.1 -p 11211 --num-conns=100 --conn-rate=1000 --sizes=0.01 --num-calls=10000"
}

memtierinstall() {
	echo
	echo "install memtier_benchmark"
	cd $DIR_TMP
	rm -rf memtier*
	wget --no-check-certificate -cnv -O memtier-${MEMTIER_VER}.tar.gz https://github.com/RedisLabs/memtier_benchmark/archive/${MEMTIER_VER}.tar.gz --tries=3
	tar xzf memtier-${MEMTIER_VER}.tar.gz
	cd memtier_benchmark-${MEMTIER_VER}
	autoreconf -ivf
	export PKG_CONFIG_PATH=/usr/${LIBDIR}/lib/pkgconfig:${PKG_CONFIG_PATH}
	make clean
	./configure
	make -j2
	make install
	ln -s /usr/local/bin/memtier_benchmark /usr/bin/memtier_benchmark
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

phpredis() {
	echo
	echo "install phpredis PHP extension"
	cd $DIR_TMP
	wget --no-check-certificate -cnv -O phpredis-${PHPREDIS_VER}.tar.gz https://github.com/phpredis/phpredis/archive/${PHPREDIS_VER}.tar.gz --tries=3
	tar xvf phpredis-${PHPREDIS_VER}.tar.gz
	cd phpredis-${PHPREDIS_VER}
	make clean
	/usr/local/bin/phpize
	if [[ -z "$(php --ri igbinary 2>&1 | grep 'not present')" ]]; then
		./configure --with-php-config=/usr/local/bin/php-config --enable-redis-igbinary
	else
		./configure --with-php-config=/usr/local/bin/php-config
	fi
	make -j2
	make install

	PHPEXTDIRD=`cat /usr/local/bin/php-config | awk '/^extension_dir/ {extdir=$1} END {gsub(/\047|extension_dir|=|)/,"",extdir); print extdir}'`
	touch ${CONFIGSCANDIR}/phpredis.ini
 
cat > "${CONFIGSCANDIR}/phpredis.ini" <<EOF
extension=${PHPEXTDIRD}/redis.so
EOF
	
	echo
	cat ${CONFIGSCANDIR}/phpredis.ini

	echo
	service php-fpm restart

	echo "php --ini"
	php --ini

	echo "php --ri redis"
	php --ri redis

}

redisinfo() {
	echo 
	echo "install redisinfo.sh"
	mkdir -p /root/tools
	cd /root/tools
	rm -rf redisinfo.sh
	wget --no-check-certificate -cnv -O redisinfo.sh https://gist.githubusercontent.com/centminmod/e304bb0d80571c566f24/raw/redisinfo.sh --tries=3
	chmod +x redisinfo.sh
	echo "installed /root/tools/redisinfo.sh"
	echo
}
######################################################
require
memtierinstall
twemperfinstall
phpredis
redisinfo