#!/bin/bash

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

ops=$(($1*1024))

mkdir results_cache 2>/dev/null

i=3
#20+ is hard limited and leads to segfault

#valgrind --tool=helgrind ./cache_bench --skewed=true --skew=500 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/csv.txt
./cache_bench --enableshardfix=false --skewed=true --zipf_const=0.0 --resident_ratio=1000 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/csv.txt

exit


for skew in 0 100 10000; do
for i in 0 1 2 4 8; do
    ./cache_bench --skewed=true --skew=$skew --resident_ratio=2 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/result"$skew"_$((2**$i)).txt
done
done

exit




i=3
for skew in 0 1 2 4 8 16 32 64 128 256 512; do
    ./cache_bench --skewed=true --skew=$skew --resident_ratio=1000 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/resultsskew$skew.txt
done

exit

for i in 0 1 2 3 4 5 6 7 8; do
    ./cache_bench --skewed=true --skew=0 --resident_ratio=1000 --value_bytes=1024 --cache_size=$((2*1024*1024*1024)) --threads=8 --lookup_percent=100 --insert_percent=0 --erase_percent=0 --lookup_insert_percent=0 --num_shard_bits=$i --ops_per_thread=$(($ops/8)) > results_cache/result$((2**$i)).txt
done

exit





