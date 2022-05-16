#!/bin/bash

mkdir results 2>/dev/null

#use sata_f2fs.sh sata_ext4.sh sata_f2fs_ext.sh

freespace=10240

function init(){
echo fillbackup
if [[ ! -d /home/jeongho/mntbackup2/fillbackup ]]; then
	mkdir /home/jeongho/mntbackup2/fillbackup
	./sata_f2fs.sh
	dd if=/dev/zero of=/home/jeongho/mnt/s0 bs=1M count=$freespace
	./fill_yesim.sh $((9256395*500))
	mv /home/jeongho/mnt/fill/* /home/jeongho/mntbackup2/fillbackup
fi
}

init


for i in 128; do
	./sata_f2fs_ext.sh
	cp /home/jeongho/mntbackup2/fillbackup/* /home/jeongho/mnt/
	dd if=/dev/zero of=/home/jeongho/mnt/filltemp bs=1M count=28672
	./run_bench_yesim_old.sh $((9256395*$i)) f2fs_ext_hotcold
		
	./sata_ext4.sh
	cp /home/jeongho/mntbackup2/fillbackup/* /home/jeongho/mnt/
	dd if=/dev/zero of=/home/jeongho/mnt/filltemp bs=1M count=28672
	./run_bench_yesim_old.sh $((9256395*$i)) ext4
	
	./sata_f2fs.sh
	cp /home/jeongho/mntbackup2/fillbackup/* /home/jeongho/mnt/
	dd if=/dev/zero of=/home/jeongho/mnt/filltemp bs=1M count=28672
	./run_bench_yesim_old.sh $((9256395*$i)) f2fs
done

#default key 16 bytes value 100bytes
#9256395 (1GB)
