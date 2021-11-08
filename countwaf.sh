#!/bin/bash

foldername=$1

for i in $(ls $foldername | grep iostat); do
	if [[ $(echo $i | grep iostat_begin) ]]; then
		#echo $i
		name=$foldername/$i
	elif [[ $(echo $i | grep iostat_end) ]]; then
		#echo $i
		name2=$foldername/$i
		val=$(cat $name | awk '{print $6}')
		val2=$(cat $name2 | awk '{print $6}')
		echo $(echo $i | sed 's/_end//g')
		result=$(($(($val2-$val))/1000000))
		percent=$(($result*100/32))
		echo $result GB, $percent %
	fi
	#else skip
done



