#!/bin/bash

sudo make rocksdbjavastaticrelease -j3
echo "i assume that youve already compiled ycsb."
cp java/target/rocksdbjni-6.24.0.jar ~/.m2/repository/org/rocksdb/rocksdbjni/6.2.2/rocksdbjni-6.2.2.jar
cp java/target/rocksdbjni-6.24.0.jar ../YCSB/rocksdb/target/dependency/rocksdbjni-6.2.2.jar
echo "just a little test."
../YCSB/bin/ycsb load rocksdb -s -P workloads/workloadc -p rocksdb.dir=/tmp/ycsb-rocksdb-data
