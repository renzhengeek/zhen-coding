#!/bin/bash

# prepare loop devices with backend file
# @count: number of loop devices to create
prepare_loopdevs()
{
	local n=${1:-1}	

	printf "creating %d backend files\n" "$n"
	for i in $(seq 0 $((--n))); do
		dd if=/dev/zero of=loop$i.raw bs=1M count=1 >/dev/null 2>&1
	done

	printf "setting up %d loop devices\n" "$n"
	for i in $(seq 0 $((--n))); do
		losetup -f loop$i.raw
	done
}

if [ "$UID" -ne "0" ];then
	echo "please run as root."
	exit 1
fi

echo "### Test loop driver with backend files ### "
echo make and come into "testdir"...
mkdir -p testdir
cd testdir

echo "stop lvmetad..."
systemctl stop lvm2-lvmetad.service lvm2-lvmetad.socket

prepare_loopdevs 60

echo time pvscan --config "devices{filter=[\"r|/.*/|\", \"a|/dev/loop*|\"]}"
time pvscan --config "devices{filter=[\"r|/.*/|\", \"a|/dev/loop*|\"]}" 2>/dev/null

echo strace -T pvscan --config "devices{filter=[\"r|/.*/|\", \"a|/dev/loop*|\"]}" > strace_pvscan1.txt 2>&1
strace -T pvscan --config "devices{filter=[\"r|/.*/|\", \"a|/dev/loop*|\"]}" > strace_pvscan1.txt 2>&1

echo "Detach all loop devices."
losetup -D

echo "start lvmetad..."
systemctl start lvm2-lvmetad.service lvm2-lvmetad.socket
echo -e "### END ###\n\n"
