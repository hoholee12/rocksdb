#!/bin/bash

echo uniform workload
echo dataset $1

mkdir /home/jeongho/mnt/fill
#generate l0
sudo time ./db_bench_"$2" \
 -benchmarks="fillrandom" \
 -num=$1 \
 -threads=1 \
 -histogram \
 -statistics \
 -db=/home/jeongho/mnt/fill \
 -key_size=48 \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false

echo after run...
df -T | grep mnt
