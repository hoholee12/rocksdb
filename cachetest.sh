#!/bin/bash

ops=$(($1*1024))

mkdir results_cache 2>/dev/null

i=8
#valgrind --tool=helgrind ./cache_bench --skewed=true --skew=500 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/csv.txt
./cache_bench --skewed=true --skew=500 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/csv.txt

exit

for i in 0 1 2 3 4 5 6 7 8; do
    ./cache_bench --skewed=true --skew=0 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/result$((2**$i)).txt
done

exit

i=8
for skew in 0 1 2 4 8 16 32 64 128 256 512; do
    ./cache_bench --skewed=true --skew=$skew --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/resultsskew$skew.txt
done

exit
