centminmodbench.sh
===============

[![Join the chat at https://gitter.im/centminmod/centminmodbench](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/centminmod/centminmodbench?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
centminmodbench.sh Github short url link: http://bench.centminmod.com

Custom system benchmark script for Centmin Mod LEMP web stack users. 

Development is ongoing so please test only on test servers and not production live servers.

*Current Test Suite*

* disk dd, ioping, fio
* ping, mtr 
* memory bandwidth testing tmpfs ramdisk with disk dd and ioping
* single threaded wget bandwidth benchmarks
* parallel multi threaded axel bandwidth benchmarks [Centmin Mod stack only]
* OpenSSL system benchmark 
* test system entropy_avail (entropy pool availability - closer to 4096 bits = better randomness and SSL related performance vs closer to 0 kernel block at generating random data = poorer SSL performance) [mentioned](https://community.centminmod.com/threads/centmin-mod-nginx-vhost-spdy-ssl-generator-testing.990/)
* rngtest suite - check the randomness of data (currently disabled by default / not yet developed)
* Nginx static OpenSSL benchmarks  [Centmin Mod stack only]
* mysqlslap http://dev.mysql.com/doc/refman/5.6/en/mysqlslap.html
* PHP (php-fpm) Zend/bench.php & Zend/micro_bench.php [Centmin Mod stack only]
* UnixBench 5.1.3 (currently disabled by default)
* ServerBear.com tests (currently disabled by default / not yet developed)
* compression/decompression tests (not yet developed)

To run type in SSH window as root user:

    curl -sL https://github.com/centminmod/centminmodbench/raw/master/centminmodbench.sh | bash

If you want to download to server and run in SSH window as root user:

    mkdir -p /root/tools
    cd /root/tools
    wget -O centminmodbench.sh https://github.com/centminmod/centminmodbench/raw/master/centminmodbench.sh
    chmod +x centminmodbench.sh

To run script locally in SSH window as root user type:

    /root/tools/centminmodbench.sh

If you don't want SSH session's connection drop out to abort your benchmark run you can run the script via screen window by installing screen via YUM and then launch centminmodbench.sh via screen

    yum -y install screen
    screen -dmS bench 
    screen -r bench
    /root/tools/centminmodbench.sh

If your SSH session drops out, the script is still running via the screen session called bench. You can use this command to view available sessions:

     screen -ls

Sample output

    There is a screen on:
            2136.bench      (Detached)
    1 Socket in /var/run/screen/S-root.

To reattach the session named bench to continue with the benchmark or find the completed benchmark output, type:

    screen -r bench

To update script

    wget -O /root/tools/centminmodbench.sh https://github.com/centminmod/centminmodbench/raw/master/centminmodbench.sh

To remove centminmodbench.sh and log files

    /root/tools/centminmodbench.sh cleanup

Or manually remove the following directories and file

    /home/centminmodbench
    /home/centminmodbench_logs
    /home/mysqlslap
    /home/phpbench_logs
    /root/tools/centminmodbench.sh

Default log directories include:

* BENCHDIR='/home/centminmodbench' (source downloads location)
* LOGDIR='/home/centminmodbench_logs' (benchmark results logs)
* MYSQLSLAP_DIR='/home/mysqlslap' (mysqlslap results logs)
* PHPBENCHLOGDIR='/home/phpbench_logs' (PHP-FPM benchmark logs)

Variables you can alter within centminmodbench.sh. Note the bandwidth tests can be set regionally as well, so if you have no need for Asia tests, you can turn the Asian specific bandwidth tests off etc. UnixBench is turned off by default during testing of this script as it adds up to 30-60 minutes to test runs as seen at https://community.centminmod.com/threads/centminmodbench-sh-benchmark-script-for-centmin-mod-lemp-servers.1298/#post-5880.

    SEVERBEAR='n'
    OPENSSLBENCH='y'
    OPENSSL_NONSYSTEM='y'
    RUN_DISKDD='y'
    RUN_DISKIOPING='y'
    RUN_DISKFIO='y'
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
    UNIXBENCH_VER='5.1.3'

Google Spreadsheet Template
===============

To tabulate your own results, I created a Google Spreadsheet template you can download and customise for your own usage. It's currently prefilled with columns for 3 clouding hosting providers, DigitalOcean, Linode and Vultr.

https://docs.google.com/spreadsheets/d/1DnL5hzG4MrfDj10T5fiLLxnw0YKbbFrTVACy5xtW_H4/edit?usp=sharing

DigitalOcean vs Linode vs Vultr Benchmarks
===============
Using centminmodbench.sh, I tested 48GB RAM, 16 CPU core VPS servers for DigitalOcean, Linode and Vultr and posted results at https://community.centminmod.com/threads/digitalocean-vs-linode-vs-vultr-48gb-16-cpus-centminmodbench-sh-results.1389/

Dedicated Server Benchmarks
===============
Some sample centminmodbench.sh results from dedicated servers at https://community.centminmod.com/threads/centminmodbench-sh-for-dedicated-servers.1394/