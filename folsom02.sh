#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Run this as 'root'." 1>&2
   exit 1
fi

eth0=$(/sbin/ifconfig eth0| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')
baseaddr="$(echo $eth1 | cut -d. -f1-3)"
lsv="$(echo $eth1 | cut -d. -f4)"
lsv=$(( $lsv + 1 ))
computeip=$lsv
computeip=$baseaddr.$computeip

echo "Setting up vlan, bridge-utils, ntp, rabbitmq, mysql-server and python-mysqldb. Please pick a alphanumeric password (meaning no "!", "#" etc)."
sleep 5
apt-get -y install vlan bridge-utils ntp mysql-server python-mysqldb rabbitmq-server

echo "Activating ip_forwarding in /etc/sysctl.conf"
cp /etc/sysctl.conf /etc/sysctrl.conf.orig
sed -i 's/\#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
echo "Reloading sysctl."
sysctl -p

echo "Setting up ntp.conf"
cp /etc/ntp.conf /etc/ntp.conf.orig
sed -i 's/server ntp.ubuntu.com/server ntp.ubuntu.com\nserver 127.127.1.0\nfudge 127.127.1.0 stratum 10/g' /etc/ntp.conf

echo "Restarting ntp"
service ntp restart

cp ~/.bashrc ~/.bashrc.orig

echo "Setting passwords. MAKE SURE YOU ONLY USE ALPHANUMERIC PASSWORDS OR THINGS WILL _NOT_ WORK!"
read -p "Enter a password to be used for the OpenStack services MySQL databases/users (nova, glance, keystone, cinder): " mysqlpassword
read -p "Enter a token for the OpenStack services to auth with keystone and the admin GUI: " token
read -p "Enter the email address for service accounts (nova, glance, keystone, cinder): " email
read -p "Enter the IP you picked for eth1 (eq. 10.0.0.1): " internalip

cat >> ~/.bashrc <<EOF
export EMAIL_FOLSOM=$email
export MYSQL_PASSWORD=$mysqlpassword
export SERVICE_TOKEN=$token
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$token
export eth1=$internalip
export OS_AUTH_URL="http://$internalip:5000/v2.0/"
export SERVICE_ENDPOINT="http://$internalip:35357/v2.0/"
EOF

eth1=$internalip
baseaddr="$(echo $eth1 | cut -d. -f1-3)"
lsv="$(echo $eth1 | cut -d. -f4)"
lsv=$(( $lsv + 1 ))
computeip=$lsv
computeip=$baseaddr.$computeip

sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf

service mysql restart

mysql -u root -p <<EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'$computeip' IDENTIFIED BY '$mysqlpassword';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'$eth1' IDENTIFIED BY '$mysqlpassword';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$mysqlpassword';
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'$eth1' IDENTIFIED BY '$mysqlpassword';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$mysqlpassword';
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'$eth1' IDENTIFIED BY '$mysqlpassword';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$mysqlpassword';
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'$eth1' IDENTIFIED BY '$mysqlpassword';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$mysqlpassword';
EOF

echo "Now run source ~/.bashrc and then ./folsom03.sh"
