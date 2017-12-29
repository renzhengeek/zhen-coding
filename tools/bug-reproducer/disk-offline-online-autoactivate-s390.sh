#!/bin/bash

N=10
CCW=0156
VG=test-vg

while [[ $((--N)) -ge 0 ]]; do
   chccwdev -e $CCW
   echo === N=$N ===
   now=$(date +%s)
   while [[ $((now+10-$(date +%s))) -gt 0 ]]; do
      vgs $VG &>/dev/null && break
      usleep 100000
   done
   systemctl daemon-reload
   vgchange -a n "$VG" || break
   usleep 100000
   chccwdev -d $CCW
   usleep 100000
done
