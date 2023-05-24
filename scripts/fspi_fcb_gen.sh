#!/bin/sh

cnt=0
for fcbfile in $*
do
    awk '{s="00000000"$1;l=length(s);if(!((NR-1)%4))printf "%08x ",(NR-1)*4;for(i=7;i>0;i-=2)printf " %s",substr(s,l-i,2);if(!(NR%4))printf "\n";}' $fcbfile > qspi-tmp
    xxd -r qspi-tmp qspi-header
    dd if=qspi-header of=qspi-header-crc bs=1 count=508
    crc_value=$(crc32 qspi-header-crc)
    echo $crc_value | xxd -r -ps >> qspi-header-crc
    dd if=qspi-header-crc of=fcb.bin bs=512 seek=$cnt
    cnt=$((cnt+1))
    rm -f qspi-tmp qspi-header qspi-header-crc
done

while [ $cnt -lt 4 ]
do
    dd if=/dev/zero of=fcb.bin bs=512 seek=$cnt count=1
    cnt=$((cnt+1))
done
echo "fcb.bin is generated"
