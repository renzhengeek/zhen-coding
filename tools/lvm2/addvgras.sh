#!/bin/bash
#
# Add volume group resource agent
# Usage: $0 <vg start id, i.e. 1> <vg end id, i.e. 10>

start=$1
end=$2

for i in $(seq $start $end)
do

crm configure primitive vg"$i" LVM \
        params volgrpname=vg"$i" exclusive=true \
        op start timeout=100 interval=0 \
        op stop timeout=40 interval=0 \
        op monitor interval=60 timeout=240

crm configure  order base_first_vg"$i" inf: base-clone vg"$i"

if test $(expr $i % 2) -eq 0 ;then
	node=bj-ha-5
else
	node=bj-ha-3
fi
crm configure  location cli-prefer-vg"$i" vg"$i" role=Started inf: "$node"

done

crm configure show
