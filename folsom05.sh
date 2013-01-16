#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Run this as 'root'." 1>&2
   exit 1
fi
. ~/.bashrc

echo "Installing Glance"
apt-get -y install glance python-glanceclient python-glance

echo "Setting up Glance config files"
cp /etc/glance/glance-api-paste.ini /etc/glance/glance-api-paste.ini.orig
cp /etc/glance/glance-registry-paste.ini /etc/glance/glance-registry-paste.ini.orig
cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.orig
cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.orig

echo "service_protocol = http
auth_host = $eth1
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = $SERVICE_TOKEN" >> /etc/glance/glance-api-paste.ini

echo "service_protocol = http
auth_host = $eth1
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = $SERVICE_TOKEN" >> /etc/glance/glance-registry-paste.ini

sed -e "
/^sql_connection =.*$/s/^.*$/sql_connection = mysql\:\/\/glance\:$MYSQL_PASSWORD\@$eth1\/glance/
" -i /etc/glance/glance-api.conf
sed -i 's/\#flavor\=/flavor\ \=\ keystone/g' /etc/glance/glance-api.conf

sed -e "
/^sql_connection =.*$/s/^.*$/sql_connection = mysql\:\/\/glance\:$MYSQL_PASSWORD\@$eth1\/glance/
" -i /etc/glance/glance-registry.conf
sed -i 's/\#flavor\=/flavor\ \=\ keystone/g' /etc/glance/glance-registry.conf

glance-manage version_control 0

glance-manage db_sync
sleep 5
service glance-api restart; service glance-registry restart
sleep 5
echo "Done! Now downloading and installing Ubuntu image"
# add ubuntu image

if [ -f images/precise-server-cloudimg-amd64-disk1.img ]
then
  glance image-create --name "Ubuntu 12.04 LTS" --is-public true --container-format bare --disk-format qcow2 < images/precise-server-cloudimg-amd64-disk1.img
else
  wget http://uec-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img
  mkdir images
  mv precise-server-cloudimg-amd64-disk1.img images/
  glance image-create --name "Ubuntu 12.04 LTS" --is-public true --container-format bare --disk-format qcow2 < images/precise-server-cloudimg-amd64-disk1.img
fi
# add centos image
#if [ -f images/centos60_x86_64.qcow2 ]
#then
#  glance image-create --name "CentOS 6" --is-public true --container-format bare --disk-format qcow2 < images/precise-server-cloudimg-amd64-disk1.img
#else
#  wget http://c250663.r63.cf1.rackcdn.com/centos60_x86_64.qcow2
#  mv centos60_x86_64.qcow2 images/
#  glance image-create --name "CentOS 6" --is-public true --container-format bare --disk-format qcow2 < images/centos60_x86_64.qcow2
#fi
glance index
echo "You should continue with ./folsom06.sh if you see Ubuntu in the list above."
