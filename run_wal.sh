#!/bin/bash

repeat=$1
dataset_size=4
if [[ $2 != "" ]]; then
	dataset_size=$2
fi
dataset=$((7255012*$dataset_size))

mkdir results 2>/dev/null

#for each workloads
# $1 = num
# $2 = workload type

for x in $(seq 1 $repeat); do
	echo testing ext4...

	#./nvme_ext4.sh $dataset_size
	# move wal to mnt2
	#iostat > results/results_ext4_waloff_iostat_begin_"$x".txt
	#sudo ./check_mem.sh > results/results_ext4_waloff_memcheck_"$x".txt &
	#memcheck=$!
	#sudo ./run_wal2.sh $dataset true &> results/results_ext4_waloff_"$x".txt
	#sudo kill -9 $memcheck
	#iostat > results/results_ext4_waloff_iostat_end_"$x".txt

	./nvme_ext4.sh
	# dont move
	iostat > results/results_ext4_walon_iostat_begin_"$x".txt
	sudo ./check_mem.sh > results/results_ext4_walon_memcheck_"$x".txt &
	memcheck=$!
	sudo ./run_wal2.sh $dataset false &> results/results_ext4_walon_"$x".txt
	sudo kill -9 $memcheck
	iostat > results/results_ext4_walon_iostat_end_"$x".txt


	echo testing f2fs...

	#./nvme_f2fs.sh $dataset_size
	# move wal to mnt2
	#iostat > results/results_f2fs_waloff_iostat_begin_"$x".txt
	#sudo ./check_mem.sh > results/results_f2fs_waloff_memcheck_"$x".txt &
	#memcheck=$!
	#sudo ./run_wal2.sh $dataset true &> results/results_f2fs_waloff_"$x".txt
	#sudo kill -9 $memcheck
	#iostat > results/results_f2fs_waloff_iostat_end_"$x".txt

	./nvme_f2fs.sh
	# dont move
	iostat > results/results_f2fs_walon_iostat_begin_"$x".txt
	sudo ./check_mem.sh > results/results_f2fs_walon_memcheck_"$x".txt &
	memcheck=$!
	sudo ./run_wal2.sh $dataset false &> results/results_f2fs_walon_"$x".txt
	sudo kill -9 $memcheck
	iostat > results/results_f2fs_walon_iostat_end_"$x".txt


	echo "$x"th repeat complete.
done

#7255012 (1GB)
#43530074 (6GB)
#72550123 (10GB)
#116080197 (16GB)
#232160394 (32GB)
#464320788 (64GB)


