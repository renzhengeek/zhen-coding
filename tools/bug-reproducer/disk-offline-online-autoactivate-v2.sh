#!/bin/bash

pgrep -a udevadm | grep -q monitor
if [ $? -eq 0 ];then
	echo "udevadm monitor is already running."
else
	udevadm monitor -u -s block &
fi

dev1=/dev/sdb
dev2=/dev/sdd
dev_t1=8:17
dev_t2=8:49
dev=
dev_t=

host=host1

count=100
i=0
vg=vg1

online_dev ()
{
	echo "echo - - - >/sys/class/scsi_host/$host/scan"
	echo '- - -' >/sys/class/scsi_host/$host/scan
}

offline_dev()
{
	echo "echo 1 >/sys/block/$(basename $dev)/device/delete"
	echo 1 >/sys/block/$(basename $dev)/device/delete
}

while [[ $((++i)) -lt $count ]]; do

	online_dev
	
	sleep 1

	udevadm settle
	pvs 2>&1 | grep error
	if [ $? -eq 0 ]; then
		echo "Abort!"
		exit
	fi

	if [ -b $dev1 ]; then
		dev=$dev1
		dev_t=$dev_t1
	else
		dev=$dev2
		dev_t=$dev_t2
	fi

	echo === count=$i, dev=$dev ===
	
	echo "udevadm info ${dev}1 | grep SYSTEMD"
	udevadm info ${dev}1 | grep SYSTEMD
	if [ -b $dev1 ]; then
		echo "python -c 'open(\"/dev/sdb1\", \"w\")'"
		python -c 'open("/dev/sdb1", "w")'
	else
		echo "python -c 'open(\"/dev/sdd1\", \"w\")'"
		python -c 'open("/dev/sdd1", "w")'
	fi
	echo udevadm info ${dev}1 | grep SYSTEMD
	udevadm info ${dev}1 | grep SYSTEMD

	echo systemctl show -p ActiveState -p BoundBy -p Following dev-block-${dev_t}.device
 	systemctl show -p ActiveState -p BoundBy -p Following dev-block-${dev_t}.device
	echo systemctl daemon-reload
	systemctl daemon-reload
	echo systemctl show -p ActiveState -p BoundBy -p Following dev-block-${dev_t}.device
 	systemctl show -p ActiveState -p BoundBy -p Following dev-block-${dev_t}.device

	sleep 1
	echo "echo 3 >/proc/sys/vm/drop_caches"
	echo 3 >/proc/sys/vm/drop_caches

	sleep 1
	echo "echo transport-offline >/sys/block/$(basename $dev)/device/state"
	echo transport-offline >/sys/block/$(basename $dev)/device/state

	sleep 1
	if [ -b $dev1 ]; then
		echo python -c 'open("/dev/sdb1", "w")'
		ls -l /dev/sdb1
		python -c 'open("/dev/sdb1", "w")'
	else
		echo python -c 'open("/dev/sdd1", "w")'
		ls -l /dev/sdd1
		python -c 'open("/dev/sdd1", "w")'
	fi

	sleep 1
	echo "echo running >/sys/block/$(basename $dev)/device/state"
	echo running >/sys/block/$(basename $dev)/device/state

	pvs

	offline_dev
	udevadm settle
	echo systemctl show -p ActiveState -p BindsTo lvm2-pvscan@${dev_t}.service
	systemctl show -p ActiveState -p BindsTo lvm2-pvscan@${dev_t}.service
done
