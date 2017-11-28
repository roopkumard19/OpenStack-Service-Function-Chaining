#!/bin/bash -e


SSH_KEYNAME="default"

# Project and security group names
PROJECT="demo"
SECGROUP="default"

echo "Flavor List"
echo
openstack flavor list -f value -c Name
echo
read -p "Enter the flavor name : " flavor
FLAVOR=$(openstack flavor list -f value -c Name |grep $flavor)
echo "You have selected the flavor as $FLAVOR"
echo
echo "Image List"
echo
openstack image list -f value -c Name
echo
read -p "Enter the image name : " image
IMAGE=$(openstack image list -f value -c Name|grep $image)
echo "You have selected the image as $image"

# Source credentials
#[[ -e ~/devstack/openrc ]] && source ~/devstack/openrc "${PROJECT}" "${PROJECT}"
#[[ -e ~/keystonerc_${PROJECT} ]] && source ~/keystonerc_${PROJECT}

FLAVOR=$(openstack flavor list -f value -c Name |grep $flavor)

IMAGE=$(openstack image list -f value -c Name|grep $image)

if [ "${SSH_KEYNAME}" = "default" ]
then
    [[ -e ~/.ssh/id_rsa ]] || ssh-keygen -f ~/.ssh/id_rsa
    if ! openstack keypair show default > /dev/null 2>&1
    then
        openstack keypair create --public-key ~/.ssh/id_rsa.pub default
    fi
else
    if ! openstack keypair show ${CUSTOM_SSH_KEYNAME} > /dev/null 2>&1
    then
        openstack keypair create --public-key <( echo ${CUSTOM_SSH_KEY} ) ${CUSTOM_SSH_KEYNAME}
    fi
fi

SECGROUP_RULES=$(openstack security group show "${SECGROUP}" -f value -c rules)
if echo "${SECGROUP_RULES}" | grep -q icmp
then 
    openstack security group rule create --proto icmp "${SECGROUP}"
fi
for port in 22 80
do
    if echo "${SECGROUP_RULES}" | grep -q "port_range_max='${port}', port_range_min='${port}'"
    then 
        openstack security group rule create --proto tcp --dst-port ${port} "${SECGROUP}"
    fi
done
