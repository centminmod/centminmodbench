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

If you want to automate both Centmin Mod installation + centminmodbench.sh run + extended Nginx HTTP/2 HTTPS RSA 2048 bit + ECDSA 256bit SSL certificated based [h2load](https://nghttp2.org/documentation/h2load-howto.html) tests, zcat/pzcat log processing tests and redis benchmark tests, you can use the below commands. The Nginx HTTP/2 HTTPS h2load tests will test 4 sets of SSL Ciphers for `ECDHE-RSA-AES128-GCM-SHA256`, `ECDHE-RSA-AES256-GCM-SHA384`, `ECDHE-ECDSA-AES128-GCM-SHA256` and `ECDHE-ECDSA-AES256-GCM-SHA384`. This test may take over 60-120 minutes to complete depending on your server hardware specs i.e. number of cpu cores, cpu clock speed, memory bandwidth speed, disk I/O performance and network connectivity speed etc. As such test should be run in screen session so it survives SSH session disconnection. All of the scripts output and benchmark results will be logged into a file at `/root/centminlogs/centminmod-benchmark-all-${DT}.log` where `${DT}` is date timestamp.

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

* If you want to run on existing Centmin Mod Nginx installs an extended Nginx HTTP/2 HTTPS RSA 2048 bit + ECDSA 256bit SSL certificated based [h2load](https://nghttp2.org/documentation/h2load-howto.html) tests, you can use the below commands.
* h2load HTTP/2 HTTPS load test tool will be run single threaded so tests only 1 cpu core of the system.
* https_bench.sh will create a dummy Nginx HTTP/2 HTTPS vhost called http2.domain.com and setup both self-signed RSA 2048bit and ECDSA 256bit SSL certificates on the dummy Nginx vhost to run h2load HTTP/2 HTTPS load tests against. After https_bench.sh completes, it will automatically remove the http2.domain.com dummy Nginx vhost site and all SSL certificates.
* The Nginx HTTP/2 HTTPS h2load tests will test 4 sets of SSL Ciphers for `ECDHE-RSA-AES128-GCM-SHA256`, `ECDHE-RSA-AES256-GCM-SHA384`, `ECDHE-ECDSA-AES128-GCM-SHA256` and `ECDHE-ECDSA-AES256-GCM-SHA384`. 
* This test will test gzip (and brotli if Nginx support is detected) HTTP compression load tests using h2load HTTP/2 HTTPS tester tool. 
* These test should be run in screen session so it survives SSH session disconnection. 
* All of the scripts output and benchmark results will be logged into a file at `/root/centminlogs/h2load-nginx-https-${DT}.log` where `${DT}` is date timestamp.

### h2load HTTP/2 HTTPS load test configurations

There's 8x h2load test configurations in total:

* h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c100 -n1000 https://http2.domain.com
* h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c100 -n1000 https://http2.domain.com
* h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c100 -n1000 https://http2.domain.com
* h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c100 -n1000 https://http2.domain.com
* h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c300 -n6000 https://http2.domain.com
* h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c300 -n6000 https://http2.domain.com
* h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c300 -n6000 https://http2.domain.com
* h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c300 -n6000 https://http2.domain.com

#### Install Commands

Note: if you already have a Nginx vhost called `http2.domain.com`, you can edit `/root/tools/https_bench.sh` script's variable `vhostname=http2.domain.com` changing it before running `https_bench.sh`.

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

#### Disable Auto Removal Of http2.domain.com

`https_bench.sh` script by default auto removes the test HTTP/2 HTTPS site `http2.domain.com` at end of script run. But if you want to do further manual tests on that site you can disable the auto removal routine. 

To disable auto removal routine, edit `/root/tools/https_bench.sh` variable `HTTPS_BENCHCLEANUP='y'` change it to `HTTPS_BENCHCLEANUP='n'` by overriding it in a separately created file persistent config file at `/root/tools/https_bench.ini`

    echo "HTTPS_BENCHCLEANUP='n'" > /root/tools/https_bench.ini

Setting `HTTPS_BENCHCLEANUP='n'` will disable auto removal of test `http2.domain.com` nginx vhost site leaving it available after `https_bench.sh` run for manual testing
then run it `https_bench.sh` once to create test `http2.domain.com` site. Note `http2.domain.com` is setup with self-signed untrusted SSL certificates.

If you also want to disable sar stats logging

    echo "SARSTATS='n'" >> /root/tools/https_bench.ini

#### Example Nginx HTTP/2 HTTPS h2load benchmarks

Intel Core i7 4790K CentOS 7.5 64bit with Centmin Mod Nginx 1.13.12 compiled with GCC 8.1.0 Compiler

`ECDHE-RSA-AES128-GCM-SHA256` and `ECDHE-RSA-AES256-GCM-SHA384` ssl cipher tests

```
h2load --ciphers=ECDHE-RSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c300 -n6000 https://http2.domain.com
TLS Protocol: TLSv1.2
Cipher: ECDHE-RSA-AES128-GCM-SHA256
Server Temp Key: ECDH P-256 256 bits
Application protocol: h2

finished in 360.06ms, 16664.12 req/s, 38.56MB/s
requests: 6000 total, 6000 started, 6000 done, 6000 succeeded, 0 failed, 0 errored, 0 timeout
status codes: 6000 2xx, 0 3xx, 0 4xx, 0 5xx
traffic: 13.88MB (14558700) total, 1.79MB (1878000) headers (space savings 15.41%), 11.98MB (12558000) data
                     min         max         mean         sd        +/- sd
time for request:      768us     51.35ms      8.34ms      4.70ms    86.87%
time for connect:   101.90ms    180.62ms    146.54ms     14.58ms    80.67%
time to 1st byte:   142.49ms    187.30ms    161.65ms      9.33ms    58.67%
req/s           :      55.80       75.02       64.10        4.57    64.67%
-------------------------------------------------------------------------------------------

h2load --ciphers=ECDHE-RSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c300 -n6000 https://http2.domain.com
TLS Protocol: TLSv1.2
Cipher: ECDHE-RSA-AES256-GCM-SHA384
Server Temp Key: ECDH P-256 256 bits
Application protocol: h2

finished in 361.96ms, 16576.65 req/s, 38.34MB/s
requests: 6000 total, 6000 started, 6000 done, 6000 succeeded, 0 failed, 0 errored, 0 timeout
status codes: 6000 2xx, 0 3xx, 0 4xx, 0 5xx
traffic: 13.88MB (14552700) total, 1.79MB (1872000) headers (space savings 15.68%), 11.98MB (12558000) data
                     min         max         mean         sd        +/- sd
time for request:      335us     48.39ms      9.21ms      4.48ms    83.15%
time for connect:    94.94ms    184.70ms    148.47ms     14.47ms    81.67%
time to 1st byte:   143.36ms    195.41ms    166.62ms     10.77ms    55.33%
req/s           :      55.65       68.78       60.21        2.68    74.00%
```

`ECDHE-ECDSA-AES128-GCM-SHA256` and `ECDHE-ECDSA-AES256-GCM-SHA384` ssl ciphers tests

```
h2load --ciphers=ECDHE-ECDSA-AES128-GCM-SHA256 -H 'Accept-Encoding: gzip' -c300 -n6000 https://http2.domain.com
TLS Protocol: TLSv1.2
Cipher: ECDHE-ECDSA-AES128-GCM-SHA256
Server Temp Key: ECDH P-256 256 bits
Application protocol: h2

finished in 374.88ms, 16005.08 req/s, 37.04MB/s
requests: 6000 total, 6000 started, 6000 done, 6000 succeeded, 0 failed, 0 errored, 0 timeout
status codes: 6000 2xx, 0 3xx, 0 4xx, 0 5xx
traffic: 13.88MB (14558700) total, 1.79MB (1878000) headers (space savings 15.41%), 11.98MB (12558000) data
                     min         max         mean         sd        +/- sd
time for request:     1.32ms     61.08ms      9.21ms      9.02ms    96.58%
time for connect:   101.72ms    173.85ms    139.61ms     27.55ms    48.00%
time to 1st byte:   162.83ms    185.36ms    176.00ms      7.35ms    68.00%
req/s           :      53.90       75.51       62.17        5.27    68.67%
-------------------------------------------------------------------------------------------

h2load --ciphers=ECDHE-ECDSA-AES256-GCM-SHA384 -H 'Accept-Encoding: gzip' -c300 -n6000 https://http2.domain.com
TLS Protocol: TLSv1.2
Cipher: ECDHE-ECDSA-AES256-GCM-SHA384
Server Temp Key: ECDH P-256 256 bits
Application protocol: h2

finished in 368.49ms, 16282.84 req/s, 37.68MB/s
requests: 6000 total, 6000 started, 6000 done, 6000 succeeded, 0 failed, 0 errored, 0 timeout
status codes: 6000 2xx, 0 3xx, 0 4xx, 0 5xx
traffic: 13.88MB (14558700) total, 1.79MB (1878000) headers (space savings 15.41%), 11.98MB (12558000) data
                     min         max         mean         sd        +/- sd
time for request:      514us     66.87ms      9.40ms     10.47ms    96.15%
time for connect:    94.87ms    173.58ms    136.49ms     30.58ms    51.33%
time to 1st byte:   161.75ms    184.13ms    176.00ms      7.00ms    71.67%
req/s           :      55.38       71.86       61.91        4.31    58.67%
```

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