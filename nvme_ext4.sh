#!/bin/bash


size=100
if [[ $1 != "" ]]; then
        size=$1
fi

./nvme_partition.sh $(($size*1000))


#mnt
umount ~/mnt 2>/dev/null
mkfs.ext4 /dev/nvme0n1p1 -F
mount -t ext4 -o data=ordered /dev/nvme0n1p1 ~/mnt
chown jeongho:jeongho ~/mnt

#mnt2
umount ~/mnt2 2>/dev/null
mkfs.ext4 /dev/nvme0n1p2 -F
mount -t ext4 -o data=ordered /dev/nvme0n1p2 ~/mnt2
chown jeongho:jeongho ~/mnt

df -T | grep mnt
