#!/bin/bash

echo fillrandom
echo dataset $((9039*$1))

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

mkdir results
#generate l0
sudo time ./db_bench_l1 \
 -benchmarks="fillrandom,stats" \
 -num=$((9039*$1)) \
 -threads=1 \
 -histogram \
 -statistics \
 -db=/home/jeongho/mnt/ \
 -use_direct_io_for_flush_and_compaction=true \
 -use_direct_reads=true \
 -level0_slowdown_writes_trigger=1000 \
 -level0_stop_writes_trigger=1000 \
 -level0_file_num_compaction_trigger=1000 \
 -max_bytes_for_level_base=10485760000 \
 &> results/fillrandom.txt \

# -db_write_buffer_size=$((1024*1024*13)) \

echo after run...
df -T | grep mnt

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
