#!/bin/bash

foldername=$1

for i in $(ls $foldername | grep fragpercent_sst); do
	total=$(cat $foldername/$i | grep "total files" | awk '{print $3}')
	acc=0
	for x in $(cat $foldername/$i | grep "files fragmented in" | awk '{print $4*$6}'); do
		acc=$(($acc+$x))
	done
	echo $i fragmented by $(($acc*100/$total)) percent
done



