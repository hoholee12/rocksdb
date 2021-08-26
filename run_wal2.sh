#!/bin/bash

echo uniform workload
echo dataset $1

sudo rm -rf /home/jeongho/mnt/*
sudo rm -rf /home/jeongho/mnt2/*

movewal=""
if [[ "$2" == "true" ]]; then
	movewal="-wal_dir=/home/jeongho/mnt2"
fi

#generate
sudo time ./db_bench \
 -benchmarks="fillrandom" \
 -num=$1 \
 -threads=1 \
 -histogram \
 -statistics \
 -db=/home/jeongho/mnt \
 -key_size=48 \
 -use_direct_io_for_flush_and_compaction=true \
 -use_direct_reads=true \
 $movewal \

echo before run...
df -T | grep mnt

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
 -use_direct_io_for_flush_and_compaction=true \
 -use_direct_reads=true \
 $movewal \
 
echo after run...
df -T | grep mnt
