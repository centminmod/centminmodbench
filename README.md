centminmodbench.sh
===============
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

If you want to enable UnixBench

    sed -i "s|RUN_UNIXBENCH=.*|RUN_UNIXBENCH='y'|" /root/tools/centminmodbench.sh

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

Centmin Mod Install + Benchmark Extended
===============

If you want to automate both Centmin Mod installation + centminmodbench.sh run + extended Nginx HTTP/2 HTTPS RSA 2048 bit + ECDSA 256bit SSL certificated based [h2load](https://nghttp2.org/documentation/h2load-howto.html) tests, zcat/pzcat log processing tests and redis benchmark tests, you can use the below commands. The Nginx HTTP/2 HTTPS h2load tests will test 4 sets of SSL Ciphers for `ECDHE-RSA-AES128-GCM-SHA256`, `ECDHE-RSA-AES256-GCM-SHA384`, `ECDHE-ECDSA-AES128-GCM-SHA256` and `ECDHE-ECDSA-AES256-GCM-SHA384`. This test may take over 60-120 minutes to complete depending on your server hardware specs i.e. number of cpu cores, cpu clock speed, memory bandwidth speed, disk I/O performance and network connectivity speed etc. As such test should be run in screen session so it survives SSH session disconnection. All of the scripts output and benchmark results will be logged into a file at `/root/tools/centminmod-benchmark-all-${DT}.log` where `${DT}` is date timestamp.

    mkdir -p /root/tools
    cd /root/tools
    wget -O installnbench2.sh https://github.com/centminmod/centminmodbench/raw/master/installnbench2.sh
    chmod +x installnbench2.sh
    yum -y install screen
    screen -dmS installnbench
    screen -r installnbench
    time /root/tools/installnbench2.sh

If your SSH session drops out, the script is still running via the screen session called bench. You can use this command to view available sessions:

     screen -ls

Sample output

    There is a screen on:
            2136.installnbench      (Detached)
    1 Socket in /var/run/screen/S-root.

To reattach the session named bench to continue with the benchmark or find the completed benchmark output, type:

    screen -r installnbench

To update script

    wget -O /root/tools/installnbench2.sh https://github.com/centminmod/centminmodbench/raw/master/installnbench2.sh

Nginx HTTP/2 HTTPS h2load Benchmarks
===============

If you want to run on existing Centmin Mod Nginx installs an extended Nginx HTTP/2 HTTPS RSA 2048 bit + ECDSA 256bit SSL certificated based [h2load](https://nghttp2.org/documentation/h2load-howto.html) tests, you can use the below commands. The Nginx HTTP/2 HTTPS h2load tests will test 4 sets of SSL Ciphers for `ECDHE-RSA-AES128-GCM-SHA256`, `ECDHE-RSA-AES256-GCM-SHA384`, `ECDHE-ECDSA-AES128-GCM-SHA256` and `ECDHE-ECDSA-AES256-GCM-SHA384`. This test will test gzip (and brotli if Nginx support is detected) HTTP compression load tests using h2load HTTP/2 HTTPS tester tool. These test should be run in screen session so it survives SSH session disconnection. All of the scripts output and benchmark results will be logged into a file at `/root/tools/https-benchmark-all-${DT}.log` where `${DT}` is date timestamp.

    mkdir -p /root/tools
    cd /root/tools
    wget -O https_bench.sh https://github.com/centminmod/centminmodbench/raw/master/https_bench.sh
    chmod +x https_bench.sh
    yum -y install screen
    screen -dmS httpsbench
    screen -r httpsbench
    time /root/tools/https_bench.sh

If your SSH session drops out, the script is still running via the screen session called bench. You can use this command to view available sessions:

     screen -ls

Sample output

    There is a screen on:
            2136.httpsbench      (Detached)
    1 Socket in /var/run/screen/S-root.

To reattach the session named bench to continue with the benchmark or find the completed benchmark output, type:

    screen -r httpsbench

To update script

    wget -O /root/tools/https_bench.sh https://github.com/centminmod/centminmodbench/raw/master/https_bench.sh

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