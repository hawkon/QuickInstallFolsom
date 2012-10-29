#!/bin/sh
#
# Mainly inspired by https://github.com/openstack/keystone/blob/master/tools/sample_data.sh

# Modified by Bilel Msekni / Institut Telecom
#
# Support: openstack@lists.launchpad.net
# License: Apache Software License (ASL) 2.0
#
HOST_IP=$eth1
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$SERVICE_TOKEN}
SERVICE_PASSWORD=${SERVICE_PASSWORD:-$SERVICE_TOKEN}
export SERVICE_ENDPOINT="http://${HOST_IP}:35357/v2.0"
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}

get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

# Tenants
ADMIN_TENANT=$(get_id keystone tenant-create --name=admin)
SERVICE_TENANT=$(get_id keystone tenant-create --name=$SERVICE_TENANT_NAME)


# Users
ADMIN_USER=$(get_id keystone user-create --name=admin --pass="$ADMIN_PASSWORD" --email=admin@domain.com)


# Roles
ADMIN_ROLE=$(get_id keystone role-create --name=admin)
KEYSTONEADMIN_ROLE=$(get_id keystone role-create --name=KeystoneAdmin)
KEYSTONESERVICE_ROLE=$(get_id keystone role-create --name=KeystoneServiceAdmin)

# Add Roles to Users in Tenants
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONEADMIN_ROLE --tenant-id $ADMIN_TENANT
keystone user-role-add --user-id $ADMIN_USER --role-id $KEYSTONESERVICE_ROLE --tenant-id $ADMIN_TENANT

# The Member role is used by Horizon and Swift
MEMBER_ROLE=$(get_id keystone role-create --name=Member)

# Configure service users/roles
NOVA_USER=$(get_id keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=nova@domain.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $NOVA_USER --role-id $ADMIN_ROLE

GLANCE_USER=$(get_id keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=glance@domain.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $GLANCE_USER --role-id $ADMIN_ROLE

CINDER_USER=$(get_id keystone user-create --name=cinder --pass="$SERVICE_PASSWORD" --tenant-id $SERVICE_TENANT --email=cinder@domain.com)
keystone user-role-add --tenant-id $SERVICE_TENANT --user-id $CINDER_USER --role-id $ADMIN_ROLE

# Keystone basic Endpoints

# MySQL definitions
MYSQL_USER=keystone
MYSQL_DATABASE=keystone
MYSQL_HOST=${HOST_IP}

# Keystone definitions
KEYSTONE_REGION=RegionOne
export SERVICE_ENDPOINT="http://${HOST_IP}:35357/v2.0"

while getopts "u:D:p:m:K:R:E:T:vh" opt; do
  case $opt in
    u)
      MYSQL_USER=$OPTARG
      ;;
    D)
      MYSQL_DATABASE=$OPTARG
      ;;
    p)
      MYSQL_PASSWORD=$OPTARG
      ;;
    m)
      MYSQL_HOST=$OPTARG
      ;;
    K)
      MASTER=$OPTARG
      ;;
    R)
      KEYSTONE_REGION=$OPTARG
      ;;
    E)
      export SERVICE_ENDPOINT=$OPTARG
      ;;
    T)
      export SERVICE_TOKEN=$OPTARG
      ;;
    v)
      set -x
      ;;
    h)
      cat <<EOF
Usage: $0 [-m mysql_hostname] [-u mysql_username] [-D mysql_database] [-p mysql_password]
       [-K keystone_master ] [ -R keystone_region ] [ -E keystone_endpoint_url ]
       [ -T keystone_token ]

Add -v for verbose mode, -h to display this message.
EOF
      exit 0
      ;;
    \?)
      echo "Unknown option -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

if [ -z "$KEYSTONE_REGION" ]; then
  echo "Keystone region not set. Please set with -R option or set KEYSTONE_REGION variable." >&2
  missing_args="true"
fi

if [ -z "$SERVICE_TOKEN" ]; then
  echo "Keystone service token not set. Please set with -T option or set SERVICE_TOKEN variable." >&2
  missing_args="true"
fi

if [ -z "$SERVICE_ENDPOINT" ]; then
  echo "Keystone service endpoint not set. Please set with -E option or set SERVICE_ENDPOINT variable." >&2
  missing_args="true"
fi

if [ -z "$MYSQL_PASSWORD" ]; then
  echo "MySQL password not set. Please set with -p option or set MYSQL_PASSWORD variable." >&2
  missing_args="true"
fi

if [ -n "$missing_args" ]; then
  exit 1
fi

keystone service-create --name nova --type compute --description 'OpenStack Compute Service'
keystone service-create --name cinder --type volume --description 'OpenStack Volume Service'
keystone service-create --name glance --type image --description 'OpenStack Image Service'
keystone service-create --name keystone --type identity --description 'OpenStack Identity'
keystone service-create --name ec2 --type ec2 --description 'OpenStack EC2 service'

create_endpoint () {
  case $1 in
    compute)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8774/v2/$(tenant_id)s'
    ;;
    volume)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s' --adminurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s' --internalurl 'http://'"$HOST_IP"':8776/v1/$(tenant_id)s'
    ;;
    image)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$HOST_IP"':9292/v2' --adminurl 'http://'"$HOST_IP"':9292/v2' --internalurl 'http://'"$HOST_IP"':9292/v2'
    ;;
    identity)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$HOST_IP"':5000/v2.0' --adminurl 'http://'"$HOST_IP"':35357/v2.0' --internalurl 'http://'"$HOST_IP"':5000/v2.0'
    ;;
    ec2)
    keystone endpoint-create --region $KEYSTONE_REGION --service-id $2 --publicurl 'http://'"$HOST_IP"':8773/services/Cloud' --adminurl 'http://'"$HOST_IP"':8773/services/Admin' --internalurl 'http://'"$HOST_IP"':8773/services/Cloud'
    ;;
  esac
}

for i in compute volume image object-store identity ec2; do
  id=`mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -ss -e "SELECT id FROM service WHERE type='"$i"';"` || exit 1
  create_endpoint $i $id
done

echo "You can now try to list your identity services by running the following commands:
keystone tenant-list
keystone user-list
keystone role-list
keystone service-list
keystone endpoint-list

Then move on to ./folsom05.sh"
