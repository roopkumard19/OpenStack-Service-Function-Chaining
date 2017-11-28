#!/bin/bash

. $(dirname "${BASH_SOURCE}")/custom.sh

# Disable port security (else packets would be rejected when exiting the service VMs)
openstack network set --enable-port-security private

# Create network ports for all VMs
for port in p1in p1out p2in p2out p3in p3out source_vm_port dest_vm_port
do
    openstack port create --network private "${port}"
done

# SFC VMs
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-group "${SECGROUP}" \
    --nic port-id="$(openstack port show -f value -c id p1in)" \
    --nic port-id="$(openstack port show -f value -c id p1out)" \
    vm1
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-group "${SECGROUP}" \
    --nic port-id="$(openstack port show -f value -c id p2in)" \
    --nic port-id="$(openstack port show -f value -c id p2out)" \
    vm2
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-group "${SECGROUP}" \
    --nic port-id="$(openstack port show -f value -c id p3in)" \
    --nic port-id="$(openstack port show -f value -c id p3out)" \
    vm3

# Demo VMs
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-group "${SECGROUP}" \
    --nic port-id="$(openstack port show -f value -c id source_vm_port)" \
    source_vm
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-group "${SECGROUP}" \
    --nic port-id="$(openstack port show -f value -c id dest_vm_port)" \
    dest_vm

# Sample classifier (to show additional parameters)
openstack sfc flow classifier create \
    --ethertype IPv4 \
    --source-ip-prefix 22.1.20.1/32 \
    --destination-ip-prefix 172.4.5.6/32 \
    --protocol tcp \
    --source-port 23:23 \
    --destination-port 100:100 \
    --logical-source-port source_vm_port \
    FC1

# Demo classifier (catch the web traffic from source_vm to dest_vm)
SOURCE_IP=$(openstack port show source_vm_port -f value -c fixed_ips|grep "ip_address='[0-9]*\."|cut -d"'" -f2)
DEST_IP=$(openstack port show dest_vm_port -f value -c fixed_ips|grep "ip_address='[0-9]*\."|cut -d"'" -f2)

FLOATING_IP_SOURCE=$(openstack floating ip create public -c floating_ip_address -f value)
FLOATING_IP_DESTN=$(openstack floating ip create public -c floating_ip_address -f value)
FLOATING_IP_SF1=$(openstack floating ip create public -c floating_ip_address -f value)
FLOATING_IP_SF2=$(openstack floating ip create public -c floating_ip_address -f value)
FLOATING_IP_SF3=$(openstack floating ip create public -c floating_ip_address -f value)

openstack server add floating ip source_vm $FLOATING_IP_SOURCE
openstack server add floating ip dest_vm $FLOATING_IP_DESTN
openstack server add floating ip vm1 $FLOATING_IP_SF1
openstack server add floating ip vm2 $FLOATING_IP_SF2
openstack server add floating ip vm3 $FLOATING_IP_SF3

openstack sfc flow classifier create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_IP}/32 \
    --destination-ip-prefix ${DEST_IP}/32 \
    --protocol tcp \
    --destination-port 80:80 \
    --logical-source-port source_vm_port \
    FC_demo

# Create the port pairs for all 3 VMs
openstack sfc port pair create --ingress=p1in --egress=p1out PP1
openstack sfc port pair create --ingress=p2in --egress=p2out PP2
openstack sfc port pair create --ingress=p3in --egress=p3out PP3

# And the port pair groups
openstack sfc port pair group create --port-pair PP1 --port-pair PP2 PG1
openstack sfc port pair group create --port-pair PP3 PG2

# The complete chain
openstack sfc port chain create --port-pair-group PG1 --port-pair-group PG2 --flow-classifier FC1 --flow-classifier FC_demo PC1

# Start a basic demo web server
ssh cirros@${FLOATING_IP_DESTN} -y 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $(hostname)" | sudo nc -l -p 80 ; done&'

# On service VMs, enable eth1 interface and add static routing
for float_ip in ${FLOATING_IP_SF1} ${FLOATING_IP_SF2} ${FLOATING_IP_SF3}
do
    ssh -T cirros@${float_ip} -y <<EOF
sudo sh -c 'echo "auto eth1" >> /etc/network/interfaces'
sudo sh -c 'echo "iface eth1 inet dhcp" >> /etc/network/interfaces'
sudo /etc/init.d/S40network restart
sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo ip route add ${SOURCE_IP} dev eth0
sudo ip route add ${DEST_IP} dev eth1

EOF
done
