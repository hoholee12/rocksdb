#!/bin/bash

if [[ $1 == "init" ]]; then
rm -rf /tmp/rocksdbtest-*
./db_bench -benchmarks=fillrandom -write_buffer_size=1000 -target_file_size_base=1000 -num=100000
else
uftrace ./db_bench -benchmarks=updaterandom -write_buffer_size=1000 -target_file_size_base=1000 -num=1000 -use_existing_db=false > test.txt
sed -i 's/.*|//g' test.txt
fi
