#!/bin/bash

./nvme_partition.sh

#mnt
umount ~/mnt 2>/dev/null
sleep 1
mkfs.ext4 /dev/nvme0n1p1 -F
mount -t ext4 -o data=ordered /dev/nvme0n1p1 ~/mnt
chown jeongho:jeongho ~/mnt

df -T | grep mnt
