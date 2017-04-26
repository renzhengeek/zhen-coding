#!/bin/bash

PWD=$(pwd)
LOG=${PWD}/snapshot-merge.log
COUNT=1
VM_IP=147.2.207.144

rounds=1000
retry=30
vm=eric-sle11-sp3

log()
{	
	echo "Loop#${COUNT}: $*" >> ${LOG}
}

ssh_vm_dox()
{
	ssh root@${VM_IP} "$*"
}

wait_vm_running()
{
	local count=1

	while [ "$count" -lt "$retry" ]
	do	
		state=$(virsh domstate ${vm} | sed '/^$/d')
		if [ X"$state" != X"running" ] ; then
			log "$vm is not running."
			exit 1
		fi

		host=$(ssh -o ConnectTimeout=10 'root@147.2.207.144' hostname)
		if [ X"$host" == X"sle11sp3" ] ; then
			log "connected to $host via ssh"
			break
		fi

		sleep 1
		count=$((count++))
	done

	if [ $count -eq $retry ] ; then
		log "FATAL: timeout to login $vm!!!"
		exit 1
	fi
}

rm -rf $LOG

while [ $COUNT -lt $rounds ]
do
	wait_vm_running
	
	sleep 30

	reply=$(ssh_vm_dox "ls /addfile")
	if [ "$reply" == "/addfile" ] ; then
		log "failed to merge snapshot"
		exit 1
	fi
	
	reply=$(ssh_vm_dox "lvcreate -pr -L 1G --snapshot --name testsnap rootvg/rootlv")
	log $reply

	reply=$(ssh_vm_dox "dd if=/dev/zero of=/addfile bs=1024 count=1000")
	log $reply

	reply=$(ssh_vm_dox "lvconvert --merge rootvg/testsnap")	
	log $reply
	
	ssh_vm_dox reboot
	log "reboot"
	
	sleep 30

	((COUNT++))
done
