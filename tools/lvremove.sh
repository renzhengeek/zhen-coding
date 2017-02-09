#!/bin/bash

vgname=$1
vgexist=0

for vg in $(vgs -o vg_name --noheadings); do
	if [ "X$vgname" == "X$vg" ]; then
		vgexist=1
		break
	fi 
done

if [ $vgexist != 1 ];then
	echo "vg $1 not exist"
	echo "usage: $0 vg"
	exit 1
fi

for lv in $(lvs -o lv_name --noheading $vgname | grep -v guest); do
	lvremove -f $vgname/$lv
done
