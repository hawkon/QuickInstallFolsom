#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Run this as 'root'." 1>&2
   exit 1
fi
. ~/.bashrc

echo "Setting up Cinder - Block Storage Service"
echo "Press the default N when you are asked if you want to replace the /etc/default/iscsitarget file!!!"
sleep 5
apt-get -y install cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms tgt
#echo "Dont mind the error you probably got now, we will run the installation one more time and all should be good."
#sleep 5
#apt-get -y install cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms tgt
echo "Packages installed!"
sed -i 's/false/true/g' /etc/default/iscsitarget

service iscsitarget restart
service open-iscsi restart



echo "#############
# Openstack #
#############

[composite:osapi_volume]
use = call:cinder.api.openstack.urlmap:urlmap_factory
/: osvolumeversions
/v1: openstack_volume_api_v1

[composite:openstack_volume_api_v1]
use = call:cinder.api.auth:pipeline_factory
noauth = faultwrap sizelimit noauth osapi_volume_app_v1
keystone = faultwrap sizelimit authtoken keystonecontext osapi_volume_app_v1
keystone_nolimit = faultwrap sizelimit authtoken keystonecontext osapi_volume_app_v1

[filter:faultwrap]
paste.filter_factory = cinder.api.openstack:FaultWrapper.factory

[filter:noauth]
paste.filter_factory = cinder.api.openstack.auth:NoAuthMiddleware.factory

[filter:sizelimit]
paste.filter_factory = cinder.api.sizelimit:RequestBodySizeLimiter.factory

[app:osapi_volume_app_v1]
paste.app_factory = cinder.api.openstack.volume:APIRouter.factory

[pipeline:osvolumeversions]
pipeline = faultwrap osvolumeversionapp

[app:osvolumeversionapp]
paste.app_factory = cinder.api.openstack.volume.versions:Versions.factory

##########
# Shared #
##########

[filter:keystonecontext]
paste.filter_factory = cinder.api.auth:CinderKeystoneContext.factory

[filter:authtoken]
paste.filter_factory = keystone.middleware.auth_token:filter_factory
service_protocol = http
service_host = $eth1
service_port = 5000
auth_host = $eth1
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = cinder
admin_password = $SERVICE_TOKEN" > /etc/cinder/api-paste.ini

echo "[DEFAULT]
rootwrap_config=/etc/cinder/rootwrap.conf
sql_connection = mysql://cinder:$MYSQL_PASSWORD@$eth1/cinder
api_paste_confg = /etc/cinder/api-paste.ini
iscsi_helper=ietadm
volume_name_template = volume-%s
volume_group = cinder-volumes
verbose = True
auth_strategy = keystone
#osapi_volume_listen_port=5900" > /etc/cinder/cinder.conf

# Populating the Cinder database
cinder-manage db sync

sleep 2

service cinder-volume restart
service cinder-api restart

echo "Now you need to do some manual things. What you need to do is set up a volume group called cinder-volumes where all the volumes for cinder will be stored, on a second harddrive.

This is an EXAMPLE, do not use these drive names unless you are CERTAIN they are correct for your system!
pvcreate /dev/cciss/c0d1p1
vgcreate cinder-volumes /dev/cciss/c0d1p1
# vgs
  VG             #PV #LV #SN Attr   VSize   VFree
  cinder-volumes   1   0   0 wz--n- 683.50g 683.50g
  kvm01            1   2   0 wz--n-  68.09g  34.71g

Once you are done, continue with folsom08.sh"
