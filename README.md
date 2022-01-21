# Start

To get started, first and foremost, the DNSCrypt-Proxy 2 binary is needed. Get the appropriate Linux binary from the [dnscrypt-proxy releases directory](https://github.com/jedisct1/dnscrypt-proxy/releases). The binary needs to match the architecture of your Ubiquiti device (e.g. the USG is `linux_mips64` and the ER-X is `linux_mipsle`). The binary comes with some sample configuration files. Configuration of dnscrypt-proxy requires that at a minimum `example-dnscrypt-proxy.toml` needs to be renamed to `dnscrypt-proxy.toml` (a suitable configuration file is provided here). By default, the binary expects the configuration files to be in the same directory by default; I chose to put the binary and the associated config files in the `/config/sbin/dnscrypt-proxy` directory.

A few support scripts are required:

**/config/scripts/post-config.d/dnscrypt.sh**

This sets up a persistent directory in the `/config` filesystem for dnsmasq to save the timestamp created by the dnssec-timestamp option, and then starts the dnscrypt-proxy process.

**/config/scripts/post-config.d/dnt-hup.sh**

This uses ntp's `ntp-wait` Perl script to HUP dnsmasq when ntp is in a synchronized state (which is useful if the `dnssec-no-timecheck` option is used for dnsmasq). The `ntp-wait` command can take quite a while to complete - I clocked it at about 19 minutes on a sample boot - which is why it's forced into the background, otherwise the boot process would block here.

# Device Configuration

Follow the instructions for the EdgeRouter or UniFi configuration, below.

**IMPORTANT NOTE:** The latest release of USG Firmware (4.4.55) removed support for DNSSEC in dnsmasq (thank you, @laszlojau):

> dnsmasq deprecated the crypto library currently used by USG for DNSSEC purposes. This does not impact any controller-generated configuration, and is all but unused on USG in general, but if you have DNSSEC enabled in config.gateway.json, you will need to remove that and force provision USG.

You can verify this by checking the compile options for dnsmasq on the USG:

```
/usr/sbin/dnsmasq -v | grep -Eo no-DNSSEC
no-DNSSEC
```

If the `no-DNSSEC` option is present, you need to remove the following commands from the `config.gateway.json` file on the CloudKey and reprovision:

```
proxy-dnssec
trust-anchor=.,20326,8,2,E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D
dnssec
dnssec-check-unsigned
dnssec-no-timecheck
```

## EdgeRouter Configuration

After the files are placed in the `/config` filesystem, perform the router configuration, including the dnsmasq configuration (note the delete command that's discussed in this thread to make sure there isn't a `server=127.0.0.1` line in `/etc/dnsmasq.conf` that overrides pointing to the dnscrypt-proxy server we have running on an unprivledged port):

```
configure
delete service dns forwarding system
set service dns forwarding cache-size 0
set service dns forwarding listen-on switch0
set service dns forwarding listen-on eth0
set service dns forwarding options domain-needed
set service dns forwarding options bogus-priv
set service dns forwarding options except-interface=eth1
set service dns forwarding options stop-dns-rebind
set service dns forwarding options 'server=127.0.0.1#5353'
set service dns forwarding options trust-anchor=.,20326,8,2,E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D
set service dns forwarding options dnssec
set service dns forwarding options dnssec-check-unsigned
set service dns forwarding options no-resolv
```

Choose one of the following configuration options (`dnssec-timestamp` **or** `dnssec-no-timecheck`):
 
```
set service dns forwarding options dnssec-timestamp=/config/var/run/dnsmasq/dnsmasq.time
```

**OR** if you are using the `/config/scripts/post-config.d/dnt-hup.sh` script (recommended)

```
set service dns forwarding options dnssec-no-timecheck
```

Commit changes to the running config and save the running config to `config.boot`:

```
commit
save
```

## USG Configuration

After the files are placed in the `/config` filesystem on the USG, the JSON configuration file needs to be put on the CloudKey. Although, like on the Edgerouter, the `/config` filesystem is protected against reboots and firware updates, the USG configuration made directly on the USG won't persist when reprovisioned by the CloudKey. So we need to use the [USG Advanced Configuration](https://help.ubnt.com/hc/en-us/articles/215458888-UniFi-USG-Advanced-Configuration) feature to make the configuration changes we would have made on the Edgerouter command-line.

Pay attention to the sites directory name, but if you're using the default site, the path below should be correct. Also note the configuration below adds in the configuration stanza for the UPNP service to allow mutiple XBoxes to connect to XBox Live without fighting over Port 3074, as they're prone to. It's not at all necessary for DNSCRYPT to work and can be left out, but it's handy to have if you have an XBox.

**/srv/unifi/data/sites/default/config.gateway.json**

This is a JSON fragment to set the necessary parameters on the USG when it's provisioned. It may need to be edited for your environment (e.g. IP addresses).

Once the `config.gateway.json` file is on the CloudKey in the correct directory, force the USG to reprovision, and you should be good to go.

# Finishing Up

Checking on the EdgeRouter/USG, you should see the `dnscrypt-proxy` process running when you perform a listing of running processes with the `ps -ef` command, and you should see diagnostic messages from the scripts and the `dnscrypt-proxy` process itself in the `/var/log/messages` log file (sample output from a USG is shown below):
 
```
Aug  3 02:41:00 USG dnscrypt-proxy[3514]: Source [public-resolvers.md] loaded
Aug  3 02:41:00 USG dnscrypt-proxy[3514]: dnscrypt-proxy 2.0.16
Aug  3 02:41:00 USG dnscrypt-proxy[3514]: Failed to install DNSCrypt client prox
y: Init already exists: /etc/init.d/dnscrypt-proxy
Aug  3 02:41:00 USG dnscrypt-proxy[3519]: Source [public-resolvers.md] loaded
Aug  3 02:41:00 USG dnscrypt-proxy[3519]: dnscrypt-proxy 2.0.16
Aug  3 02:41:00 USG dnscrypt-proxy[3519]: Service started
Aug  3 02:41:00 USG dnscrypt-proxy[3530]: Source [public-resolvers.md] loaded
Aug  3 02:41:00 USG dnscrypt-proxy[3530]: dnscrypt-proxy 2.0.16
Aug  3 02:41:00 USG dnscrypt-proxy[3530]: Now listening to 127.0.0.1:5353 [UDP]
Aug  3 02:41:00 USG dnscrypt-proxy[3530]: Now listening to 127.0.0.1:5353 [TCP]
Aug  3 02:41:00 USG logger: Waiting for ntpdate to synchronize time from 0.ubnt.
pool.ntp.org...
Aug  3 02:41:00 USG logger: Waiting for ntpd to synchronize...

[...]

Aug  3 02:55:51 USG logger: NTP OK! Sending SIGHUP to dnsmasq...
Aug  3 02:55:51 USG logger:  killed (pid 3355)
```
