# pihole_host_sync
Get current list of hostnames from PiHole's static DHCP and send it to another server.

If you are using PiHole (dnsmasq) as your DHCP server and have static entries and you have another PiHole (so you have a seconary DNS server on your network), it would be nice if both PiHoles could resolve the local addresses.

This script should do all of that for you. 
Tested on Ubuntu 16.04, PiHole 3.2.1, dnsmasq 2.75
