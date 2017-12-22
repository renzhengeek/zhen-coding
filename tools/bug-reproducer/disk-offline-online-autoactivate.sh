#!/bin/bash

N=50
#CCW=0156
disk=sdc

# vgcreate vg1 /dev/sdc
# lvcreate -L1G -n lv1 vg1
VG=vg1

while [[ $((--N)) -ge 0 ]]; do
   #chccwdev -e $CCW
   rescan-scsi-bus.sh -a >/dev/null 2>&1
   echo === N=$N ===
   now=$(date +%s)
   while [[ $((now+10-$(date +%s))) -gt 0 ]]; do
      vgs $VG &>/dev/null && break
      usleep 100000
   done
   # the key to reproduce this issue
   systemctl daemon-reload
   vgchange -a n "$VG" || break
   usleep 100000
   #chccwdev -d $CCW
   echo 1 > /sys/block/$disk/device/delete
   usleep 100000
done
