#!/bin/bash

echo uniform workload
echo dataset $1

if [[ $6 == "init" ]]; then
	sudo time ./db_bench_"$3" \
	 -benchmarks="fillrandom" \
	 -num=$1 \
	 -threads=1 \
	 -key_size=48 \
	 -max_background_jobs=8 \
	 -histogram \
	 -statistics \
	 -use_existing_db=false \
	 -db=/home/jeongho/mnt \
	 -use_direct_io_for_flush_and_compaction=false \
	 -use_direct_reads=false \
	 
	echo after run...
	df -T | grep mnt

else
	#run
	sudo time ./db_bench_"$3" \
	 -benchmarks="updaterandom" \
	 -num=$1 \
	 -threads=1 \
	 -key_size=48 \
	 -max_background_jobs=8 \
	 -histogram \
	 -statistics \
	 -use_existing_db=true \
	 -db=/home/jeongho/mnt \
	 -use_direct_io_for_flush_and_compaction=false \
	 -use_direct_reads=false \
	 
	echo after run...
	df -T | grep mnt

fi