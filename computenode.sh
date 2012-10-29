#!/bin/bash

apt-get -y install nova-compute nova-network nova-api-metadata

read "Is your internal network card eth1? (y/n): " network
if network == y 
then
eth1=$(/sbin/ifconfig eth1| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')
else
eth1=$(/sbin/ifconfig eth0| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')
fi


. computeinfo
source computeinfo

echo "[DEFAULT]

# LOGS/STATE
verbose=True
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/run/lock/nova

# AUTHENTICATION
auth_strategy=keystone

# SCHEDULER
scheduler_driver=nova.scheduler.multi.MultiScheduler
compute_scheduler_driver=nova.scheduler.filter_scheduler.FilterScheduler

# CINDER
volume_api_class=nova.volume.cinder.API

# DATABASE
sql_connection=mysql://nova:$SERVICE_TOKEN@$node1/nova

# COMPUTE
libvirt_type=kvm
libvirt_use_virtio_for_bridges=True
start_guests_on_host_boot=True
resume_guests_state_on_host_boot=True
api_paste_config=/etc/nova/api-paste.ini
allow_admin_api=True
use_deprecated_auth=False
nova_url=http://$node1:8774/v1.1/
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf

# APIS
ec2_host=$node1
ec2_url=http://$node1:8773/services/Cloud
keystone_ec2_url=http://$node1:5000/v2.0/ec2tokens
s3_host=$node1
cc_host=$node1
metadata_host=$node1

# RABBITMQ
rabbit_host=$node1

# GLANCE
image_service=nova.image.glance.GlanceImageService
glance_api_servers=$node1:9292

# NETWORK
network_manager=nova.network.manager.FlatDHCPManager
force_dhcp_release=True
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
public_interface=eth0
flat_interface=eth1
flat_network_bridge=br100
fixed_range=$internal_range
network_size=$internal_size
flat_network_dhcp_start=$internal_start
flat_injected=False
connection_type=libvirt
multi_host=True

# NOVNC CONSOLE
novnc_enabled=True
novncproxy_base_url=http://$node1public:6080/vnc_auto.html

# Change vncserver_proxyclient_address and vncserver_listen to match each compute host
vncserver_proxyclient_address=$eth1
vncserver_listen=$eth1" > /etc/nova/nova.conf

cd /etc/init.d/; for i in $( ls nova-* ); do service $i restart; done
