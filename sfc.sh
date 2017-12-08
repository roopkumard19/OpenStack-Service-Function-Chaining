#!/bin/bash

openstack sfc flow classifier create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_VM}/32 \
    --destination-ip-prefix ${DEST_VM}/32 \
    --protocol icmp \
    --logical-source-port source_vm_port \
    --logical-destination-port dest_vm \
    FC1

openstack sfc flow classifier create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_VM_2}/32 \
    --destination-ip-prefix ${DEST_VM}/32 \
    --protocol tcp \
    --destination-port 80 \
    --logical-source-port source_vm_port \
    --logical-destination-port dest_vm \
    FC2

# Create the port pairs for all 3 VMs
openstack sfc port pair create --ingress=p1in --egress=p1out PP1
openstack sfc port pair create --ingress=p2in --egress=p2out PP2

# And the port pair groups
openstack sfc port pair group create --port-pair PP1 IDS
openstack sfc port pair group create --port-pair PP2 FW

# The complete chain
openstack sfc port chain create --port-pair-group IDS --flow-classifier FC1 PC1
openstack sfc port chain create --port-pair-group FW --flow-classifier FC1 PC2

# Start a basic demo web server
ssh ubuntu@${FLOATING_IP_DESTN} -y 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $(hostname)" | sudo nc -l -p 80 ; done&'

# Inject Intrusion Detection System configuration into the IDS VM
ssh -T ubuntu@${FLOATING_IP_IDS} -y
sudo sh -c 'echo "auto eth1" >> /etc/network/interfaces'
sudo sh -c 'echo "iface eth1 inet dhcp" >> /etc/network/interfaces'
sudo /etc/init.d/networking restart && sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo ip route add ${SOURCE_VM} dev eth0 && sudo ip route add ${DEST_VM} dev eth1
. $(dirname "${BASH_SOURCE}")/ids.sh

# Inject Firewall configuration into the FW VM
ssh -T cirros@${FLOATING_IP_FW} -y
sudo sh -c 'echo "auto eth1" >> /etc/network/interfaces'
sudo sh -c 'echo "iface eth1 inet dhcp" >> /etc/network/interfaces'
sudo /etc/init.d/networking restart && sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo ip route add ${SOURCE_VM_2} dev eth0 && sudo ip route add ${DEST_VM} dev eth1
. $(dirname "${BASH_SOURCE}")/fw.sh
