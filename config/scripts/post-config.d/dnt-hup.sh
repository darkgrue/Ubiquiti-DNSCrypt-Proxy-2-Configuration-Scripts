#!/bin/sh

(
  # -b
  # Force the time to be stepped using the settimeofday() system call, rather
  # than slewed (default) using the adjtime() system call. This option should
  # be used when called from a startup file at boot time.
  # -u
  # Use an unprivileged port to send the packets from. This option is useful
  # when you are behind a firewall that blocks incoming traffic to privileged
  # ports, and you want to synchronize with hosts beyond the firewall. The -d
  # option always uses unprivileged ports.
  # -s
  # Log actions by way of the syslog(3C) facility rather than to the standard
  # output -- a useful option when running the program from cron(1M).
  /usr/bin/logger -p user.notice Waiting for ntpdate to synchronize time from 0.ubnt.pool.ntp.org...
  /usr/sbin/ntpdate -bus `/usr/bin/host 0.ubnt.pool.ntp.org 1.1.1.1 | /usr/bin/awk '/has address/ { print $4 ; exit }'`
) &

(
  # dnssec-no-timecheck
  # DNSSEC signatures are only valid for specified time windows, and should
  # be rejected outside those windows. This generates an interesting
  # chicken-and-egg problem for machines which don't have a hardware real
  # time clock. For these machines to determine the correct time typically
  # requires use of NTP and therefore DNS, but validating DNS requires that
  # the correct time is already known. Setting this flag removes the
  # time-window checks (but not other DNSSEC validation.) only until the
  # dnsmasq process receives SIGHUP. The intention is that dnsmasq should
  # be started with this flag when the platform determines that reliable
  # time is not currently available. As soon as reliable time is
  # established, a SIGHUP should be sent to dnsmasq, which enables time
  # checking, and purges the cache of DNS records which have not been
  # throughly checked.

  # The ntp-wait program blocks until ntpd is in synchronized state. This
  # can be useful at boot time, to delay the boot sequence until after
  # "ntpd -g" has set the time.
  /usr/bin/logger -p user.notice Waiting for ntpd to synchronize...
  /usr/sbin/ntp-wait -n 1000 -s 6

  if [ $? -eq 0 ]
  then
    /usr/bin/logger -p user.notice NTP OK! Sending SIGHUP to dnsmasq...
    /usr/bin/pkill -SIGHUP -e -F /var/run/dnsmasq/dnsmasq.pid 2>&1 | logger -p user.notice
    exit 0
  else
    /usr/bin/logger -p user.notice Could not synchronize time. Giving up. DNSSEC signatures are not timechecked.
    exit 1
  fi
) &
