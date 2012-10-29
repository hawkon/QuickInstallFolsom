#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Run this as 'root'." 1>&2
   exit 1
fi

. ~/.bashrc
source ~/.bashrc

eth0=$(/sbin/ifconfig eth0| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')


echo "Installing keystone (identity service)"
apt-get -y install keystone python-keystone python-keystoneclient

echo "Editing the keystone config file"
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.orig
sed -e "
/^# admin_token =.*$/s/^.*$/admin_token = $SERVICE_TOKEN/
/^connection =.*$/s/^.*$/connection = mysql:\/\/keystone:$MYSQL_PASSWORD@$eth1\/keystone/
" -i /etc/keystone/keystone.conf

echo "Building DB and restarting Keystone"
service keystone restart
sleep 5
keystone-manage db_sync

echo "Now run ./folsom04.sh to populate the keystore"
