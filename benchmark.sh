#!/bin/bash

if [[ $1 == "init" ]]; then
rm -rf /tmp/rocksdbtest-*
./db_bench -benchmarks=fillrandom -write_buffer_size=1000 -target_file_size_base=1000 -num=100000
else
uftrace ./db_bench -benchmarks=updaterandom -write_buffer_size=1000 -target_file_size_base=1000 -num=1000 -use_existing_db=true > test.txt

rm -rf thread*.c
x=-1
unset thread_list
for i in $(cat test.txt | sed -n 's/.*\[\(.*[0-9]\)\].*/\1/p'); do
	if [[ ! ${thread_list[*]} =~ $i ]]; then
		x=$(($x+1))
		thread_list[$x]=$i
	fi
done

for j in ${thread_list[@]}; do
	cat test.txt | grep "$j]" | sed 's/.*|//g' > thread$j.c
done
fi
