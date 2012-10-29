#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Run this as 'root'." 1>&2
   exit 1
fi
. ~/.bashrc

eth0=$(/sbin/ifconfig eth0| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')
echo "Primary public eth0 interface IP: $eth0"
echo "Secondary internal eth1 interface IP: $eth1"
echo "----------------------------------------------------------------------"
read -p "Enter the internal network range (eg. 10.0.0.128/25): " internal_range
read -p "Enter the amount of IPs available in your range (eg. 128 for /25): " internal_size
read -p "Enter the internal IP you want to start from (eg. 10.0.0.130): " internal_start
read -p "Enter the public network range (eg. 60.54.123.128/27): " public_range

echo "Installing kvm and libvirt"

echo "node1public=$eth0
internal_range=$internal_range
internal_size=$internal_size
internal_start=$internal_start
public_range=$public_range
node1=$eth1" > computeinfo

apt-get -y install kvm libvirt-bin pm-utils

echo "cgroup_device_acl = [
\"/dev/null\", \"/dev/full\", \"/dev/zero\",
\"/dev/random\", \"/dev/urandom\",
\"/dev/ptmx\", \"/dev/kvm\", \"/dev/kqemu\",
\"/dev/rtc\", \"/dev/hpet\", \"/dev/net/tun\"
]" >> /etc/libvirt/qemu.conf

virsh net-destroy default
virsh net-undefine default

echo "listen_tls = 0
listen_tcp = 1
auth_tcp = \"none\"" >> /etc/libvirt/libvirtd.conf

sed -i 's/env\ libvirtd\_opts\=\"\-d\"/env\ libvirtd_opts\=\"\-d\ \-l\"/g' /etc/init/libvirt-bin.conf
sed -i 's/libvirtd\_opts\=\"\-d\"/libvirtd\_opts\=\"\-d\ \-l"/g' /etc/default/libvirt-bin

service libvirt-bin restart

echo "#!/bin/sh
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
exit 0" > /etc/network/if-pre-up.d/iptablesload
chmod +x /etc/network/if-pre-up.d/iptablesload


apt-get -y install nova-api nova-cert nova-compute nova-compute-kvm nova-doc nova-network nova-scheduler novnc nova-consoleauth nova-ajax-console-proxy nova-novncproxy

echo "Updating Nova config"
echo "
[DEFAULT]

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
#osapi_volume_listen_port=5900

# DATABASE
sql_connection=mysql://nova:$MYSQL_PASSWORD@$eth1/nova

# COMPUTE
libvirt_type=kvm
libvirt_use_virtio_for_bridges=True
start_guests_on_host_boot=True
resume_guests_state_on_host_boot=True
api_paste_config=/etc/nova/api-paste.ini
allow_admin_api=True
use_deprecated_auth=False
nova_url=http://$eth1:8774/v1.1/
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf

# APIS
ec2_host=$eth1
ec2_url=http://$eth1:8773/services/Cloud
keystone_ec2_url=http://$eth1:5000/v2.0/ec2tokens
s3_host=$eth1
cc_host=$eth1
metadata_host=$eth1
#metadata_listen=0.0.0.0
enabled_apis=ec2,osapi_compute,metadata

# RABBITMQ
rabbit_host=$eth1

# GLANCE
image_service=nova.image.glance.GlanceImageService
glance_api_servers=$eth1:9292

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
novncproxy_base_url=http://$eth0:6080/vnc_auto.html
vncserver_proxyclient_address=$eth1
vncserver_listen=$eth1" > /etc/nova/nova.conf


sed -e "
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,nova,g;
s,127.0.0.1,$eth1,g;
s,%SERVICE_PASSWORD%,$SERVICE_TOKEN,g;
" -i /etc/nova/api-paste.ini


chown -R nova. /etc/nova
chmod 644 /etc/nova/nova.conf

echo "nova ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

nova-manage db sync

echo "ISCSITARGET_ENABLE=true" >/etc/default/iscsitarget

cd /etc/init.d/; for i in $( ls nova-* ); do service $i restart; done 

service open-iscsi restart


nova-manage network create private --fixed_range_v4=$internal_range --num_networks=1 --bridge=br100 --bridge_interface=eth1 --vlan=1 --network_size=$internal_size --multi_host=T
nova-manage floating create --ip_range=$public_range

nova-manage service list

echo "Done with Nova! If you want to delete any IPs from the public range, run nova-manage floating list and then nova-manage floating delete 60.54.123.128 or whichever IP youve want to delete
Run folsom07.sh once you feel ready to install Cinder."
