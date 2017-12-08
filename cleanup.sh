#!/bin/bash

#Change the parameters according to your needs. Don't change the order of execution!
openstack sfc port chain delete PC1
openstack sfc port pair group delete PG1
openstack sfc port pair group delete PG2
openstack sfc port pair delete PP1
openstack sfc port pair delete PP2
openstack sfc port pair delete PP3
openstack sfc flow classifier delete FC_demo
openstack sfc flow classifier delete FC1
tmpfile=$(mktemp /tmp/floatip.XXX)
openstack floating ip list | awk '{ print $4 }' | tail -n+4 | head -n-1 > /tmp/floatip.txt
for i in /tmp/floatip.txt
do
openstack floating ip unset --port $i
done
rm "$tmpfile"
tmpfile=$(mktemp /tmp/floatip.XXX)
openstack floating ip list | awk '{ print $4 }' | tail -n+4 | head -n-1 > /tmp/floatip.txt
for i in /tmp/floatip.txt
do
openstack floating ip delete $i
done
rm "$tmpfile"
openstack port delete p1in p1out p2in p2out p3in p3out source_vm_port dest_vm_port
openstack server delete vm1 vm2 vm3 source_vm dest_vm

