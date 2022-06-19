#!/bin/bash

./sata_ext4.sh
./fillseq.sh 100
./run_bench_bigcomp.sh 100 fillseq readseq
#./run_bench_bigcomp.sh 100 fillseq readrandom
#./run_bench_bigcomp.sh 100 fillseq seekrandom
./sata_ext4.sh
./fillrandom.sh 100
./run_bench_bigcomp.sh 100 fillrandom readseq
#./run_bench_bigcomp.sh 100 fillrandom readrandom
#./run_bench_bigcomp.sh 100 fillrandom seekrandom

