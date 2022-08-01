#!/bin/bash

if [[ $1 == "" ]]; then
	echo gimme something to grep
	exit
fi


for i in $(ls | grep thread); do
	mystr=$(cat $i | grep -i "$1" | awk '{print $1,$2}' | head -n 1)
	if [[ $mystr != "" ]]; then
		echo "$i: $mystr"
	fi
done
