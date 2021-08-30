#!/bin/bash
size=100000
if [[ $1 != "" ]]; then
	size=$1
fi
sudo fuser -ck ~/mnt
sudo fuser -ck ~/mnt2
sudo umount ~/mnt
sudo umount ~/mnt2
sudo parted /dev/nvme0n1 rm 1 -s
sudo parted /dev/nvme0n1 rm 2 -s
sudo parted /dev/nvme0n1 mkpart primary 1MB "$(($size+1))"MB -s
sudo parted /dev/nvme0n1 mkpart primary "$(($size+1))"MB "$(($size*2+1))"MB -s
sync
