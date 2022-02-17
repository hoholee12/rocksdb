#!/bin/bash

workloadhere=$1
counthere=$2
locationhere=$3

if [[ $workloadhere == "" ]]; then
	workloadhere="workloadc"
fi
if [[ $counthere == "" ]]; then
	counthere="1000000"
fi
if [[ $locationhere == "" ]]; then
	locationhere="/home/jeongho/mnt/ycsbtest"
fi

cd ../YCSB
./bin/ycsb load rocksdb -s -P workloads/$workloadhere -p recordcount=$counthere -p operationcount=$counthere -p rocksdb.dir=$locationhere
