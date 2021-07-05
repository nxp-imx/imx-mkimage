#!/bin/bash

if [ ! -f $1 ]; then
	echo "Kernel Image file" $1 "NOT found"
	exit 1;
fi

let size=$(wc -c $1 | awk '{print $1}')
let split_address=$2
let split_size=$3
let split_number=$(((size + split_size -1) / split_size))
command=""

for ((i = 0; i < ${split_number}; i++)); do
	rm -f $1_split_$i

	dd if=$1 of=$1_split_$i bs=${split_size} skip=$i count=1 conv=fsync

	addr=`printf "0x%X" ${split_address}`
	command="$command -ap $1_split_$i a35 $addr"

	split_address=$((split_address + split_size))
done

rm -f $1_cmd
echo $command > $1_cmd