#!/bin/bash

dataset_size=4
if [[ $1 != "" ]]; then
	dataset_size=$1
fi
dataset=$((7255012*$dataset_size))

mkdir results 2>/dev/null

#for each workloads
# $1 = num
# $2 = workload type

# with ext4
echo testing ext4...
./nvme_ext4.sh

./run_wal.sh $dataset false
ddcount=0
mkdir /home/jeongho/mnt/stuffing
while true; do
dd if=/dev/zero of=/home/jeongho/mnt/stuffing/s$ddcount bs=1M count=$(($dataset_size*678)) >/dev/null 2>&1
if [[ $? != 0 ]]; then rm -rf /home/jeongho/mnt/stuffing/s$ddcount; break; fi
ddcount=$(($ddcount+1))
done

../blktrace_results/traceme_nvme.sh ext4 &
blkcheck=$!
echo begin check...
iostat > results/results_f2fs_walon_iostat_begin_"$x".txt
./run_wal2.sh $dataset false &> results/results_f2fs_walon_"$x".txt
iostat > results/results_f2fs_walon_iostat_end_"$x".txt

killall blktrace


#7255012 (1GB)
#43530074 (6GB)
#72550123 (10GB)
#116080197 (16GB)
#232160394 (32GB)
#464320788 (64GB)


