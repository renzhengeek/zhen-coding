#!/bin/bash 
#
# Create partitions for given raw disk
# Usage: $0 <disk path, i.e. /dev/sda>

dev=$1

size=$(lsblk --nodeps --noheadings -o SIZE $dev)
unit=$(echo $size | grep -o "[M|G|T]$")

test -n "$unit" || { echo "Too small device?"; exit 1;}
# trim the float and unit parts
size=$(echo $size | cut -d'.' -f1)

if [ "$unit" = "T" ]
then
	size=$((size * 1024))
	echo a
elif [ "$unit" = "M" ]
then
	size=$((size / 1024))
	test $size -lt 1 && { echo "Too small device?"; exit 1;}
	echo a
fi

echo "Size of $dev: ${size}G"

# each partition is 1G
part_size=1

parted --script $dev mklabel gpt

start=252
end=$((start + part_size))

while [ $size -ge $part_size ]
do
	echo parted --script $dev mkpart primary "$start"G "$end"G
	parted --script $dev mkpart primary "$start"G "$end"G

	start=$end
	end=$((start + part_size))
	
	size=$((size - part_size))
done

parted --script $dev print 
