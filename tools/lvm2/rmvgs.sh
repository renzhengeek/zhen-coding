#!/bin/bash

dev=$1

parts_num=$(parted --script /dev/sdc print | awk '/Number/,0' | egrep -v "Number|^$" | wc -l)

part=1

while [ $parts_num -ge 1 ]
do
	echo vgremove --force vg"$part"
	vgremove --force vg"$part"

	echo pvremove --force --yes "$dev""$part"
	pvremove --force --yes "$dev""$part"

	part=$(expr $part + 1)
	parts_num=$(expr $parts_num - 1)
done

vgs
pvs
