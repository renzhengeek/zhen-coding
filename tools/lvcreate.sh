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

vfree=$(vgs -o vg_free --units g --noheadings $vgname)
vfree=$(echo $vfree | cut -d. -f1)

lvsize=10
i=1

while [ $vfree -ge $lvsize ]
do
	echo lvcreate --size $lvsize --name lv$i $vgname
	lvcreate --size $lvsize --name lv$i $vgname

	i=$(expr $i + 1)
	vfree=$(expr $vfree - $lvsize)
done
