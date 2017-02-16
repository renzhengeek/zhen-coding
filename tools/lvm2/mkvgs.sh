#!/bin/bash

dev=$1

parts_num=$(parted --script /dev/sdc print | awk '/Number/,0' | egrep -v "Number|^$" | wc -l)

part=1

while [ $parts_num -ge 1 ]
do
	echo pvcreate "$dev""$part"
	pvcreate "$dev""$part"

	echo vgcreate vg"$part" "$dev""$part"
	vgcreate vg"$part" "$dev""$part"

	lvcreate -ay -l 100%PVS --name lv"$part" vg"$part"

	part=$(expr $part + 1)
	parts_num=$(expr $parts_num - 1)
done

vgs
