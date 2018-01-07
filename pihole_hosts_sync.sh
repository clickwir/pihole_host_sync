#!/usr/bin/env bash
set -euo pipefail
# Created by clickwir on 1/5/2018
# GPL V3.0
##
# Get the current list of local hostnames to the other PiHole
# You'll need to setup SSH to login with passwordless keys
# 'ssh-keygen' enter-enter-enter
# 'ssh-copy-id root@server'
[ $EUID -ne 0 ] && { printf "This probably needs to run as root. Maybe sudo?\n"; exit 1; }

# Variables
# Remote server we are sending the list to
rem_server=root@10.1.0.2
clock=$(date)
work_dir=$(mktemp -d)
conf="$work_dir"/50-pihole-local.conf
update_self=yes

enable_log=no

if [ "$enable_log" = "yes" ]; then
    # Setup a log
    # Make sure this script is in a good dir for logging
    # eg, not a /etc/cron.daily location
    log=/tmp/pihole_hosts_sync.log
    if [ ! -f "$log" ]; then
        touch "$log"
        exec 19>"$log"
        export BASH_XTRACEFD=19
        set -x
    else
        savelog -n -c 7 "$log"
        exec 19>"$log"
        export BASH_XTRACEFD=19
        set -x
    fi
fi

echo "Starting at "$clock" :: Pushing hosts to "$rem_server""

# Check variables for being empty
[[ -z "$rem_server" || -z "$clock" || -z "$work_dir" || -z "$conf" || -z "$update_self" ]] && { printf "\nServer is not specified. Must quit.\n"; exit 1; }


# Get the IP and host name from the current PiHole dnsmasq DHCP file
if [ -f /etc/dnsmasq.d/04-pihole-static-dhcp.conf ]; then
    awk -F ',' '{print $2,$3}' /etc/dnsmasq.d/04-pihole-static-dhcp.conf | sort > "$work_dir"/hosts.local.list
else
    printf "\nPiHole Static DHCP file not found. Nothing to pull from.\n"
    exit 1
fi

# Send the list to the other server
if [ -f "$work_dir"/hosts.local.list ]; then
    scp "$work_dir"/hosts.local.list "$rem_server":/etc/pihole/hosts.local.list
    # Copy myself to the remote server. (TODO: look up definition of virus)
    scp "${0}" "$rem_server":/opt/"${0##*/}"
else
    printf "\nOdd, cannot access/find file that should have just been created. Better exit, somethings not right.\n"
    exit 1
fi

# Create remote dnsmasq conf file
# This file tells dnsmasq to use the new hosts file and domain
#if [ ! -f "$conf" ]; then
    domain=$(grep domain /etc/dnsmasq.d/02-pihole-dhcp.conf)
    echo "# Adding my own local list of machines" > "$conf"
    # Following 2 lines are needed so both "host" and "host.domain" resolve
    # If left out, things like "plex" will resolve. But "plex.local" will not.
    echo "$domain" >> "$conf"
    echo "expand-hosts" >> "$conf"
    echo "addn-hosts=/etc/pihole/hosts.local.list" >> "$conf"
    scp "$conf" "$rem_server":/etc/dnsmasq.d/
#fi

# Then restart dnsmasq
ssh "$rem_server" 'service dnsmasq restart'


# Possible bug workaround
# System that does DHCP doesn't do DNS unless client gets DHCP lease
# DNS should resolve either way. This should help make sure it does.
if [ "$update_self" = "yes" ]; then
    cp "$work_dir"/hosts.local.list /etc/pihole/hosts.local.list
    cp "$conf" /etc/dnsmasq.d/
    service dnsmasq restart
fi

# Cleanup
rm -rf "$work_dir"

echo "Finished at "$clock" :: Pushing hosts to "$rem_server""
