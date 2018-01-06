#!/usr/bin/env bash
set -euo pipefail
# Created by clickwir on 1/5/2018
#
# Get the current list of local hostnames to the other PiHole
# You'll need to setup SSH to login with passwordless keys
# 'ssh-keygen' enter-enter-enter
# 'ssh-copy-id root@server'
[ $EUID -ne 0 ] && { printf "This probably needs to run as root. Maybe sudo?\n"; exit 1; }

# Variables
# Remote server we are sending the list to
rem_server=10.1.0.2
clock=$(date)
work_dir=/opt

# Setup a log
log="$work_dir"/pihole_host_sync.log
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
echo "Starting at "$clock" :: Pushing hosts to "$rem_server""

# Check variables for being empty
[[ -z "$rem_server" || -z "$clock" || -z "$work_dir" ]] && { printf "\nServer is not specified. Must quit.\n"; exit 1; }


# Get the IP and host name from the current PiHole dnsmasq DHCP file
if [ -f /etc/dnsmasq.d/04-pihole-static-dhcp.conf ]; then
    awk -F ',' '{print $2,$3}' /etc/dnsmasq.d/04-pihole-static-dhcp.conf | sort > "$work_dir"/hosts.local.list
else
    printf "\nPiHole Static DHCP file not found. Nothing to pull from.\n"
    exit 1
fi

# Send the list to the other server
if [ -f "$work_dir"/hosts.local.list ]; then
    scp "$work_dir"/hosts.local.list root@"$rem_server":/etc/pihole/hosts.local.list
    # Copy myself to the remote server. (TODO: look up definition of virus)
    scp "${0}" root@"$rem_server":"$work_dir"/"${0##*/}"
else
    printf "\nOdd, cannot access/find file that should have just been created. Better exit, somethings not right.\n"
    exit 1
fi

# Create remote dnsmasq conf file
# This file tells dnsmasq to use the new hosts file
# Then restart dnsmasq
ssh root@"$rem_server" 'echo "# Adding my own local list of machines" > /etc/dnsmasq.d/50-pihole-local.conf; echo "addn-hosts=/etc/pihole/hosts.local.list" >> /etc/dnsmasq.d/50-pihole-local.conf; service dnsmasq restart'

echo "Finished at "$clock" :: Pushing hosts to "$rem_server""
