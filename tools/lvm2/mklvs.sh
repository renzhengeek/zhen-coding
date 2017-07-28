#!/bin/bash 
#
# Exercise LVM on large number of PVs

# Physical disks where many partitions reside on
disks=(/dev/sdb /dev/sdc)

# Arry to collect all partitions from different disks
parts=
num_parts=0

get_parts()
{
	disk=$1

	for part in $(lsblk --list --paths --noheadings -o name "$disk")
	do
		if [ "$part" = "$disk" ] ; then
			continue
		fi
		((num_parts++))
		parts+=("$part")
		
		echo "Adding ${num_parts}th partition: $part"
	done
}

for disk in "${disks[@]}"
do
	get_parts "$disk"
done

echo "We've got $num_parts partitions."
###

# how many PVs in a VG
pvs_in_each_vg=16
num_vg=$((num_parts / pvs_in_each_vg))

#echo "parts: ${parts[@]}"

start=1

for i in $(seq 1 $num_vg)
do
	pv_list=("${parts[@]:$start:$pvs_in_each_vg}")

	vgcreate testvg"$i" ${pv_list[@]}

	pv_list=()
	start=$((start + pvs_in_each_vg))
done

echo "We've create $num_vg VGs."
###

# create, format, and mount one LV per VG
for i in $(seq 1 $num_vg)
do
	lvcreate -n testvg"$i"-lv"$i" -L14G testvg"$i"
	
#	mkfs.ext2 /dev/testvg"$i"/testvg"$i"-lv"$i"

#	mkdir -p /mnt/test"$i"		
#	mount /dev/testvg"$i"/testvg"$i"-lv"$i" /mnt/test"$i" 
done
