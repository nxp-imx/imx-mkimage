#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Must set the sector offset of secondary image"
    exit -1
fi

sector_num=`printf "0x%X" $1`

sed -e s/%sectornum%/${sector_num}/g scripts/sit_template > sit_gen
chmod +x sit_gen

./sit_gen
objcopy -I binary -O binary --pad-to 512 sit.bin

rm sit_gen
echo "Generated sit.bin"
