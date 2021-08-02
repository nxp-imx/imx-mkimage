#!/bin/bash

let dtba=0
if [ -f $1 ]; then
    let dtba=1
fi

if [ -f fsl-$1 ]; then
    let dtba=$((dtba + 2))
fi

if [ $3 ]&&[ -f $3 ]; then
    let dtba=4
fi

if [ $((dtba)) == 3 ]; then
    echo " Two u-boot DTB files exist: fsl-"$1 "and" $1
    echo " Please delete unused one!"
    echo " u-boot imx_v2020.04: "$1
    echo " u-boot imx_v2019.04: fsl-"$1
    exit -1
elif [ $((dtba)) == 0 ]; then
    echo " Can't find u-boot DTB file, please copy from u-boot"
    exit -2
elif [ $((dtba)) == 1 ]; then
    echo "Use u-boot DTB: "$1
    cp -f $1 $2
elif [ $((dtba)) == 2 ]; then
    echo "Use u-boot DTB: fsl-"$1
    cp -f fsl-$1 $2
elif [ $((dtba)) == 4 ]; then
    echo "Use u-boot DTB: "$3
    cp -f $3 $2
fi
