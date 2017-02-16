#!/bin/bash
#
# Create partitions for given raw disk
# Usage: $0 <disk path, i.e. /dev/sda>

dev=$1

size=$(lsblk --noheadings -o SIZE $dev)
# trim the float part
size=${size%.*}

# each partition is 10G
part_size=10

parted --script $dev mklabel gpt

start=1
end=$(expr $start + 10)

while [ $size -ge $part_size ]
do
	echo parted --script $dev mkpart primary "$start"G "$end"G
	parted --script $dev mkpart primary "$start"G "$end"G

	start=$end
	end=$(expr $start + 10)
	
	size=$(expr $size - 10)
done

parted --script $dev print 
