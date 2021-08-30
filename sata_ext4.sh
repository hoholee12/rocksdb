#!/bin/bash


size=100
if [[ $1 != "" ]]; then
        size=$1
fi

./sata_partition.sh $(($size*1000))


#mnt
umount ~/mnt 2>/dev/null
mkfs.ext4 /dev/sdb1 -F
mount -t ext4 -o data=ordered /dev/sdb1 ~/mnt
chown jeongho:jeongho ~/mnt

#mnt2
umount ~/mnt2 2>/dev/null
mkfs.ext4 /dev/sdb2 -F
mount -t ext4 -o data=ordered /dev/sdb2 ~/mnt2
chown jeongho:jeongho ~/mnt

df -T | grep mnt
