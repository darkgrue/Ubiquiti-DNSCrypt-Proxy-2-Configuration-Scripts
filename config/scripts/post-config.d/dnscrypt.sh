#!/bin/sh

# Check that persistent (/config filesystem) var directory exists, if not, create it and set ownership
if [ ! -d /config/var/run/dnsmasq ]; then
    /bin/mkdir -p /config/var/run/dnsmasq;
    /bin/chown dnsmasq /config/var/run/dnsmasq;
fi;

/config/sbin/dnscrypt-proxy/dnscrypt-proxy -service install
/config/sbin/dnscrypt-proxy/dnscrypt-proxy -service start

# Start watchdog
#(/config/sbin/dnscrypt-proxy/dnscrypt-watchdog.sh) &

exit 0
