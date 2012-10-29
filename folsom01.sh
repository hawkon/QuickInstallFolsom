#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Run this as 'root'." 1>&2
   exit 1
fi

echo "Installation process for OpenStack Folsom on Ubuntu 12.04.1 LTS!"
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/folsom main" > /etc/apt/sources.list.d/folsom.list
apt-get install ubuntu-cloud-keyring
apt-get update
apt-get upgrade

echo "--------------------------------------------
Now its time to set up the network.
We assume that you have two network cards on this machine. One should be an internal ip with a range of free IPs, and the other one should be an external IP with a range of free external IPs to use.
First make your /etc/network/interfaces look similar to this so one is for outside traffic and one for internal traffic:

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
 	address 60.41.162.132
	netmask 255.255.255.224
	network 60.41.162.128
	broadcast 60.41.162.159
	gateway 60.41.162.129
	dns-nameservers 8.8.8.8 8.8.4.4

auto eth1
iface eth1 inet static
        address 10.0.0.1
        netmask 255.255.255.0
        network 10.0.0.0
        broadcast 10.0.0.254

It's suggested to use 10.0.0.1 for your internal network.
Once that is set up, run /etc/init.d/networking restart and then run ./folsom02.sh"
