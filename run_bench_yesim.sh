#!/bin/bash

function fragperlevel(){
	extentcount=0
	filecount=0
	for i in /home/jeongho/mnt/*; do
		level=$(cat $1 | grep -B1 "$i CREATE" | grep "current level: " | awk '{print $3}')
		if [[ $level == "" ]]; then
			continue
		fi
		filecount[level]=$((${filecount[level]}+1))
		extentcount[level]=$((${extentcount[level]}+$(filefrag $i | awk '{print $2}')))
	done
	for asdf in $(seq 0 10); do
		if [[ ${filecount[asdf]} != "" ]]; then
			echo "level $asdf fragmentation: $((${extentcount[asdf]}/${filecount[asdf]}))"
		fi
	done
}

echo updaterandom
echo dataset $1
dataset=$1

sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

smartctl -A /dev/sdb &> results/results_smartctl_begin_"$2"_"$(($dataset/9256395))"g.txt
iostat | grep sdb > results/results_iostat_begin_"$2"_"$(($dataset/9256395))"g.txt
if [[ -f /sys/kernel/debug/f2fs/status ]]; then
	sh -c "cat /sys/kernel/debug/f2fs/status" > results/results_fsstat_begin_"$2"_"$(($dataset/9256395))"g.txt
fi

#run
sudo time ./db_bench \
 -benchmarks="updaterandom,stats" \
 -num=$dataset \
 -histogram \
 -statistics \
 -threads=1 \
 -max_background_jobs=8 \
 -use_existing_db=true \
 -db=/home/jeongho/mnt \
 -use_direct_io_for_flush_and_compaction=false \
 -use_direct_reads=false \
 &> results/results_"$2"_"$(($dataset/9256395))"g.txt \
 
smartctl -A /dev/sdb &> results/results_smartctl_end_"$2"_"$(($dataset/9256395))"g.txt
iostat | grep sdb > results/results_iostat_end_"$2"_"$(($dataset/9256395))"g.txt
if [[ -f /sys/kernel/debug/f2fs/status ]]; then
	sh -c "cat /sys/kernel/debug/f2fs/status" > results/results_fsstat_end_"$2"_"$(($dataset/9256395))"g.txt
fi

filefrag /home/jeongho/mnt/* | awk '{print $(NF-2)}' > testfrag.txt
python countfrag.py testfrag.txt > results/results_"$2"_fragpercent_total_"$(($dataset/9256395))"g.txt
filefrag /home/jeongho/mnt/* | grep sst | awk '{print $(NF-2)}' > testfrag.txt
python countfrag.py testfrag.txt > results/results_"$2"_fragpercent_sst_"$(($dataset/9256395))"g.txt
filefrag /home/jeongho/mnt/* | grep buf | awk '{print $(NF-2)}' > testfrag.txt
python countfrag.py testfrag.txt > results/results_"$2"_fragpercent_buf_"$(($dataset/9256395))"g.txt
filefrag /home/jeongho/mnt/* | grep log | awk '{print $(NF-2)}' > testfrag.txt
python countfrag.py testfrag.txt > results/results_"$2"_fragpercent_log_"$(($dataset/9256395))"g.txt