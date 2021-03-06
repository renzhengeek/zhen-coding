#!/bin/bash

DEBUG=

# Steps:
# git checkout -b sles/12-sp2
# git reset --hard v2_02_120
# rpm2git.sh /home/eric/suse/ibs/home:ZRen:branches:OBS_Maintained:lvm2/lvm2.SUSE_SLE-12-SP2_Update/lvm2.spec
usage()
{ 
          echo "usage: $0 [-D] <rpm spec>"
}

debug()
{
          if [ x"$DEBUG" == x"1" ];then
                    echo "$*"
          fi
}

while getopts "Dh" options; do
          case $options in
          D) DEBUG=1;;
          h) usage; exit 1;;
          *) usage; exit 1;;
          esac
done

shift $(($OPTIND -1))
PKG_SPEC=$1

if [[ $PKG_SPEC != *.spec ]]
then
          usage
          exit 1
fi

PKG_DIR=$(dirname $PKG_SPEC)

git status > /dev/null 2>&1
if [ $? -ne 0 ]
then
          echo "Invalid git repo!"  
          echo "Please run in a git repo."
          exit 1
fi

DUMP=$(git status -s)
if [ -n "$DUMP" ]
then
          echo "Git repo is not clean!"  
          exit 1
fi

# example:
# Patch72:        libdm-iface-not-output-error-message-inside-retry-loop.patch

NUM_PATCH=$(grep "^Patch" $PKG_SPEC | wc -l)
i=1

sed -n -r 's/^Patch[0-9]*:[[:space:]]+(.*(diff|patch))/\1/p' < $PKG_SPEC | while read PATCH
do
          echo "[$i/$NUM_PATCH] $PATCH"

          debug "git apply $PKG_DIR/$PATCH"
          patch -p1 < $PKG_DIR/$PATCH > /dev/null

          debug "git add ."
          git add . > /dev/null
          debug "git commit -m \"add $PATCH\""
          git commit -m "add $PATCH" > /dev/null

          if [ $? -ne 0 ]
          then
                    echo "We are in trouble now!"
                    exit 1
          fi

          i=$((i+1))
done

test ! $NUM_PATCH -eq $((i-1)) && echo "\n WARN: You may have patch files not ended with [patch|diff] in spec file."
