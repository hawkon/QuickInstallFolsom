#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Run this as 'root'." 1>&2
   exit 1
fi
. ~/.bashrc
eth0=$(/sbin/ifconfig eth0| sed -n 's/.*inet *addr:\([0-9\.]*\).*/\1/p')

echo "Installing the OpenStack Dashboard"
apt-get -y install openstack-dashboard memcached
apt-get -y purge openstack-dashboard-ubuntu-theme


#LOGIN_URL='/auth/login/'
#LOGIN_REDIRECT_URL='/'
#" > /etc/openstack-dashboard/local_settings.py

#WSGIScriptAlias / /usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi
#" >/etc/apache2/conf.d/openstack-dashboard.conf



service apache2 restart; sudo service memcached restart

echo "Done, now access your interface at: http://$eth0/horizon with login admin/$SERVICE_TOKEN

If you have any issues, reboot your server and then run the following command once it is back up: cd /etc/init.d/; for i in \$( ls nova-* ); do service \$i restart; done


ONLY LOOK AT THE INFORMATION BELOW IF YOU HAVE ANOTHER SERVER WHICH YOU WANT TO RUN AS A COMPUTE NODE.
----------------------------
Want to add another server as a Compute node? Cool, there are some things you should consider though.
1. Make sure it is located on the same internal network, and if you gave this server 10.0.0.1 then be sure to give the compute node IP number 10.0.0.2
2. The compute node does not need more than 1 network card.
3. Download the git repository to the compute node
4. Move over computeinfo from node 1 and put it on the compute node and run: source computenode
5. Run: chmod +x computenode.sh
6. Run: ./computenode.sh"
