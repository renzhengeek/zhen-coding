#!/bin/bash 
#
# Create partitions for given raw disk
# Usage: $0 <disk path, i.e. /dev/sda>

dev=$1

if [ -z $dev ]; then
	echo "Usage: $0 <disk path, i.e. /dev/sda>"
	exit 1	
fi

num_parts=$(parted --script $dev print | awk '/^[ 0-9]+/ { print $0 }' | wc -l)

echo "Selected device: $dev, number of parts: $num_parts"

for i in $(parted --script $dev print | awk '/^[ 0-9]+/ { print $1 }')
do
	echo parted --script $dev rm $i
	parted --script $dev rm $i
done

parted --script $dev print 
