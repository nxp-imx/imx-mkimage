#!/bin/bash

if [ -f $1 ]; then
	let size=$(wc -c $1 | awk '{print $1}')
	let padded_size=$(((size + 7) & ~7))

	if [ ${size} != ${padded_size} ]
	then
		echo $1 "is padded to" ${padded_size}
		objcopy -I binary -O binary --pad-to ${padded_size} $1
	fi
fi
