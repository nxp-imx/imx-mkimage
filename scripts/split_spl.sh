#!/bin/bash

if [ ${V2X} != YES ]; then
	echo "-ap u-boot-spl.bin a35 0x00100000" > $1_cmd
	exit 0
fi

if [ ! -f $1 ]; then
	echo "SPL file" $1 "NOT found"
	exit 1;
fi
let size=$(wc -c $1 | awk '{print $1}')
let split_address=$2
let split_size=$((split_address - 0x100000))

if [ ${size} -gt ${split_size} ]; then
	let residual_size=$((size - split_size))

	rm -f $1_split_a $1_split_b

	dd if=$1 of=$1_split_a bs=1 count=${split_size} conv=fsync
	dd if=$1 of=$1_split_b bs=1 skip=${split_size} count=${residual_size} conv=fsync

	echo "-ap u-boot-spl.bin_split_a a35 0x00100000 -data u-boot-spl.bin_split_b a35" $2 >  $1_cmd
else
	echo "-ap u-boot-spl.bin a35 0x00100000" > $1_cmd
fi
