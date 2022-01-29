#!/bin/bash

mkdir results 2>/dev/null

freespace=8192

function freespaceme(){
echo freespace... "$freespace"
mkdir /home/jeongho/mnt/stuffing
dd if=/dev/zero of=/home/jeongho/mnt/stuffing/s0 bs=1M count=$freespace >/dev/null 2>&1
openssl enc -aes-256-ctr -pass pass:"$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" -nosalt < /dev/zero > /home/jeongho/mnt/stuffing/s1 2>/dev/null
rm -rf /home/jeongho/mnt/stuffing/s0
}

function init(){
	if [[ ! "$(echo $2 | grep bk1)" ]]; then
		if [[ ! -d /home/jeongho/mntbackup/fillbackup_"$1" ]]; then mkdir /home/jeongho/mntbackup/fillbackup_"$1"; else return; fi
	fi
	if [[ "$(echo $2 | grep bk1)" ]]; then
		if [[ ! -d /home/jeongho/mntbackup2/fillbackup_"$1" ]]; then mkdir /home/jeongho/mntbackup2/fillbackup_"$1"; else return; fi
	fi
	./sata_f2fs.sh
	mkdir /home/jeongho/mnt/stuffing
	dd if=/dev/zero of=/home/jeongho/mnt/stuffing/s0 bs=1M count=$freespace >/dev/null 2>&1
	#./fill.sh $((7255012*500)) "$1"
	./fill.sh $((7255012*32)) "l1"
	if [[ "$(echo $2 | grep bk1)" ]]; then
		mv /home/jeongho/mnt/fill/* /home/jeongho/mntbackup2/fillbackup_"$1"
	else
		mv /home/jeongho/mnt/fill/* /home/jeongho/mntbackup/fillbackup_"$1"
	fi
}

function blktraceme(){
	if [[ -d ../mntbackup2/blktraces_"$1"g ]]; then
		rm -rf ../mntbackup2/blktraces_"$1"g
	fi

	#delete trace after analysis for space
	mkdir ../mntbackup2/blktraces_"$1"g
	mv *blktrace* ../mntbackup2/blktraces_"$1"g/
	../blktrace_results/printme.sh ../mntbackup2/blktraces_"$1"g
}

# arg1: name, arg2: appending num, arg3: dataset, arg4: which level, arg5: devicename, arg6: space?, arg7: bk1(70)/bk2(100)
function testme(){
	fsname=f2fs
	if [[ "$(echo $1 | grep ext4)" ]]; then
		fsname=ext4
	fi
	if [[ "$(echo $1 | grep xfs)" ]]; then
		fsname=xfs
	fi
	if [[ "$(echo $7 | grep bk1)" ]]; then
		cp /home/jeongho/mntbackup2/fillbackup_"$4"/* /home/jeongho/mnt
	else
		cp /home/jeongho/mntbackup/fillbackup_"$4"/* /home/jeongho/mnt
	fi
	if [[ "$6" == "" ]]; then
		freespaceme
	fi
	
	# free memory before test
	sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"

	#../blktrace_results/traceme_"$name".sh "$1"_"$2"g &
	#blkcheck=$!
	echo begin check "$1"...
	smartctl -A /dev/"$5" &> results/results_"$1"_smartctl_begin_"$2"g.txt
	iostat | grep "$5" > results/results_"$1"_iostat_begin_"$2"g.txt
	# 100mb ftrace before
	#echo begin first trace
	#trace-cmd record -e "$fsname" ./run_bench.sh 725501 false "$4" > /dev/null
	#sleep 1
	#trace-cmd report > results/results_"$1"_ftracea_"$2"g.txt
	#rm trace.dat
	# main load
	#./run_bench.sh 725501 false "$4" > /dev/null
	echo run workload
	#./run_bench.sh "$3" false "$4" "$1" "$2"
	./run_bench.sh "$3" false "l1" "$1" "$2"
	# 100mb ftrace after
	#echo begin second trace
	#trace-cmd record -e "$fsname" ./run_bench.sh 725501 false "$4" > /dev/null
	#sleep 1
	#trace-cmd report > results/results_"$1"_ftraceb_"$2"g.txt
	#rm trace.dat
	smartctl -A /dev/"$5" &> results/results_"$1"_smartctl_end_"$2"g.txt
	iostat | grep "$5" > results/results_"$1"_iostat_end_"$2"g.txt
	#killall blktrace

	# check fragmentation
	filefrag /home/jeongho/mnt/* | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results/results_"$1"_fragpercent_total_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep sst | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results/results_"$1"_fragpercent_sst_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep buf | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results/results_"$1"_fragpercent_buf_"$2"g.txt
	filefrag /home/jeongho/mnt/* | grep log | awk '{print $(NF-2)}' > testfrag.txt
	python countfrag.py testfrag.txt > results/results_"$1"_fragpercent_log_"$2"g.txt
	#intact=$(($(filefrag /home/jeongho/mnt/* | grep "1 extent\|0 extent" | wc -l)*100))
	#total=$(filefrag /home/jeongho/mnt/* | wc -l)
	#fragpercentage=$((100-$(($intact/$total))))
	#echo $fragpercentage > results/results_"$1"_fragpercent_"$2"g.txt
}

#for each workloads
# $1 = num
# $2 = workload type

name="sata"
devicename="sdb"


	# with no ssr
	#echo testing nossr...
	#./"$name"_f2fs_nossr.sh
	#testme "nossr" "$x" "$dataset" "l0" "$devicename"

#init "l0"
init "l1" "bk1"
#init "x1" "bk1"

for x in 128; do
	dataset_size=$x
	dataset=$((7255012*$dataset_size))
	freespace=$(($x/32*4096))
	echo dataset_size is $dataset_size
	
	#remove leftover blktrace
	#rm -f *blktrace*

	##real test
	
	
	# all of rocksdb on hot
	#echo testing ssr_steroids... with space bk1
	#./"$name"_f2fs_steroids.sh
	#testme "ssr_steroids_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"
	
	# all of rocksdb on cold
	#echo testing ssr_reverse... with space bk2
	#./"$name"_f2fs_reverse.sh
	#testme "ssr_reverse_bk2" "$x" "$dataset" "l0" "$devicename" "space" "bk2"
	
	# l1 cold
	echo testing l1... with space bk1
	./"$name"_f2fs_ext.sh
	testme "l1_space_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"
	#testme "l1_space_bk1" "$x" "$dataset" "x1" "$devicename" "space" "bk1"
	
	# ext4 with space
	echo testing ext4... with space bk1
	./"$name"_ext4.sh
	testme "ext4_space_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"
	#testme "ext4_space_bk1" "$x" "$dataset" "x1" "$devicename" "space" "bk1"
	
	# with ssr with space
	echo testing ssr... with space bk1
	./"$name"_f2fs.sh
	testme "ssr_space_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"
	#testme "ssr_space_bk1" "$x" "$dataset" "x1" "$devicename" "space" "bk1"
	
	# l1 hot
	#echo testing l1 hot... with space bk1
	#./"$name"_f2fs_ext_reverse.sh
	#testme "l1_space_reverse_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"
	#testme "l1_space_bk1" "$x" "$dataset" "x1" "$devicename" "space" "bk1"
	
	
	# with no ssr
	#echo testing nossr... bk2
	#./"$name"_f2fs_nossr.sh
	#testme "nossr_bk2" "$x" "$dataset" "l0" "$devicename" "space" "bk2"
	
	# xfs with space
	#echo testing xfs... with space bk1
	#./"$name"_xfs.sh
	#testme "xfs_space_bk1" "$x" "$dataset" "l1" "$devicename" "space" "bk1"

	#trace after one run
	#blktraceme $x
	
done

#7255012 (1GB)
#43530074 (6GB)
#72550123 (10GB)
#116080197 (16GB)
#232160394 (32GB)
#464320788 (64GB)

