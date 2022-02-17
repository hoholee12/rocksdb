#!/bin/bash

epoch=$(date +%s)

echo ",mem,page,total" > results/results_"$2"_"$3"g_memcheck.csv

while true; do
	sleep 1
	exist=$(pgrep db_bench_l1 | head -1)
	if [[ $exist == "" ]]; then	exit; fi
	memsize=$(ps aux | awk '{print $2,$6}' | grep $exist | head -1 | awk '{print $2}')
	pagesize=$(free | grep Mem | awk '{print $6}')
	totalsize=$(($(free | grep Mem | awk '{print $2}')-$(free | grep Mem | awk '{print $4}')))
	# seconds / rocksdb usage / total memory usage
	echo "$(($(date +%s)-$epoch)),$memsize,$pagesize,$totalsize" >> results/results_"$2"_"$3"g_memcheck.csv
done