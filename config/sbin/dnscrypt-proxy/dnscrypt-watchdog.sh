#!/bin/sh

RESET_WHEN_FAIL_COUNT=5
SLEEP_INTERVAL=10s

/usr/bin/logger -p user.notice dnscrypt-watchdog: Starting...
/usr/bin/logger -p user.notice dnscrypt-watchdog: Sleeping for 3 minutes to wait for dnscrypt-proxy to ready up...
sleep 3m
/usr/bin/logger -p user.notice dnscrypt-watchdog: Ready.

fail_count=0
while true; do
    # Check if dnscrypt-proxy is running.
    if pgrep -F /var/run/dnscrypt-proxy.pid > /dev/null
    then
#        /usr/bin/logger -p user.notice dnscrypt-watchdog: dnscrypt-proxy process is OK, checking resolver...
        host 1.1.1.1 > /dev/null
        if [ $? -ne 0 ]
        then
            fail_count=$((fail_count + 1))
            /usr/bin/logger -p user.notice DNS check to www.quad9.net FAIL, count: $fail_count

            if [ $fail_count -ge ${RESET_WHEN_FAIL_COUNT} ]
	        then
                /usr/bin/logger -p user.notice Stopping dnscrypt-proxy...
                /config/sbin/dnscrypt-proxy/dnscrypt-proxy -service stop
                /usr/bin/logger -p user.notice Starting dnscrypt-proxy...
                /config/sbin/dnscrypt-proxy/dnscrypt-proxy -service start

                /usr/bin/logger -p user.notice Sending SIGHUP to dnsmasq...
                /usr/bin/pkill -SIGHUP -e -F /var/run/dnsmasq/dnsmasq.pid 2>&1 | logger -p user.notice

                fail_count=0
            fi
        else
#            /usr/bin/logger -p user.notice dnscrypt-watchdog: Resolver is OK.
            fail_count=0
        fi
    else
        /usr/bin/logger -p user.notice dnscrypt-watchdog WARNING: dnscrypt-proxy process DOA, restarting...
        /config/sbin/dnscrypt-proxy/dnscrypt-proxy -service start

        /usr/bin/logger -p user.notice dnscrypt-watchdog Sending SIGHUP to dnsmasq...
        /usr/bin/pkill -SIGHUP -e -F /var/run/dnsmasq/dnsmasq.pid 2>&1 | logger -p user.notice

        fail_count=0
    fi

#    /usr/bin/logger -p user.notice dnscrypt-watchdog: Sleeping for ${SLEEP_INTERVAL}...
    sleep ${SLEEP_INTERVAL}
done