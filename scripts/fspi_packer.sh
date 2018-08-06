#!/bin/sh

mv flash.bin qspi-flash
awk '{s="00000000"$1;l=length(s);if(!((NR-1)%4))printf "%08x ",(NR-1)*4;for(i=7;i>0;i-=2)printf " %s",substr(s,l-i,2);if(!(NR%4))printf "\n";}' $1 > qspi-tmp
xxd -r qspi-tmp qspi-header
dd if=qspi-header of=qspi-header.off bs=1k seek=1
dd if=qspi-flash of=qspi-flash.off bs=1k seek=4
dd if=qspi-header.off of=qspi-flash.off conv=notrunc
mv qspi-flash.off flash.bin
rm qspi-tmp qspi-header* qspi-flash*
echo "F(Q)SPI IMAGE PACKED"

