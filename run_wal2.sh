#!/bin/bash

echo uniform workload
echo dataset $1

movewal=""
if [[ "$2" == "true" ]]; then
	movewal="-wal_dir=/home/jeongho/mnt2"
fi

#run
sudo time ./db_bench \
 -benchmarks="updaterandom" \
 -num=$1 \
 -threads=1 \
 -histogram \
 -statistics \
 -use_existing_db=true \
 -db=/home/jeongho/mnt \
 -key_size=48 \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \
 $movewal \
 
echo after run...
df -T | grep mnt
