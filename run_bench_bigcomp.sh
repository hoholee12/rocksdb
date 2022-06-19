#!/bin/bash

echo "$3" on "$2"
echo dataset $((9039*$1))
dataset=$((9039*$1))

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

if [[ $3 == "seekrandom" ]]; then
	dataset=$(($dataset/50))
fi

#run
sudo time ./db_bench_l1 \
 -benchmarks="$3,stats" \
 -num=$dataset \
 -threads=1 \
 -histogram \
 -statistics \
 -use_existing_db=true \
 -db=/home/jeongho/mnt \
 -use_direct_io_for_flush_and_compaction=true \
 -use_direct_reads=true \
 -level0_slowdown_writes_trigger=1000 \
 -level0_stop_writes_trigger=1000 \
 -level0_file_num_compaction_trigger=1000 \
 -max_bytes_for_level_base=10485760000 \
 -seek_nexts=50 \
 &> results/"$3"_on_"$2".txt \
 
echo after run...
df -T | grep mnt
