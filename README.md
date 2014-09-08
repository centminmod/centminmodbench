centminmodbench.sh
===============

Custom system benchmark script for Centmin Mod LEMP web stack users. 

Development is ongoing so please test only on test servers and not production live servers.

*Current Test Suite*

* OpenSSL system benchmark + Nginx static OpenSSL benchmarks
* mysqlslap http://dev.mysql.com/doc/refman/5.6/en/mysqlslap.html
* PHP (php-fpm) Zend/bench.php & Zend/micro_bench.php
* UnixBench 5.1.3 (currently disabled by default)
* ServerBear.com tests (currently disabled by default)

To run type in SSH window as root user:

    curl -sL https://github.com/centminmod/centminmodbench/raw/master/centminmodbench.sh | bash

If you want to download to server and run in SSH window as root user:

    mkdir /root/tools && cd /root/tools
    wget -O centminmodbench.sh https://github.com/centminmod/centminmodbench/raw/master/centminmodbench.sh
    chmod +x centminmodbench.sh

To run script locally in SSH window as root user type:

    /root/tools/centminmodbench.sh

Default log directories include:

* BENCHDIR='/home/centminmodbench' (source downloads location)
* LOGDIR='/home/centminmodbench_logs' (benchmark results logs)
* MYSQLSLAP_DIR='/home/mysqlslap' (mysqlslap results logs)
* PHPBENCHLOGDIR='/home/phpbench_logs' (PHP-FPM benchmark logs)
