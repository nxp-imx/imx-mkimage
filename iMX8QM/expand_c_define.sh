#!/bin/sh

####################################################################
#
#    Copyright 2017 NXP
#
####################################################################

# usage:
# cat ../../imx-sc-firmware/firmware/platform/board/mx8qm_val/ddrc/ddrc_mem_map.h | ./expand_c_define.sh  > ddrc_mem_map.h
# cat ../../imx-sc-firmware/firmware/platform/board/mx8qm_val/ddrc/ddr_phy_mem_map.h | ./expand_c_define.sh  > ddr_phy_mem_map.h

# This script parses a register mapping file from imx-sc-firmware (C header
# file with register base addresse and register offset definitions).
#
# This script evaluates an arithmetic expression to get the register
# addresses for iMX8QM.
# Its creates new C #define for each instance of the DDR (#0, #1).
#
# This script parses a C header file like:
# '#define DDRC_MSTR(X)            REG32(DDRC_BASE_ADDR(X) + 0x00)'
# and converts it to (last arithmetic expression is evaluated)
# '#define DDRC_MSTR_0 0x5c000000'
# '#define DDRC_MSTR_1 0x5c100000'

# search for the register map BASE_ADDR definition
# Search for a line like:
# #define DDR_PHY_BASE_ADDR(X) 0x5c000000 + ((X * 0x100000) + 0x10000)
base_found=0
while IFS= read -r line
do
  echo "$line"
  base_addr_name=$(echo "$line" | sed -n -e "s/^#define *\([^ ]*_BASE_ADDR(X)\) *\(.*\)/\1/p")
  #base_addr_expr="$(echo $line | sed -n -e 's/^#define *\([^ ]*_BASE_ADDR(X)\) *\(.*\)/\2/p')"
  base_addr_expr=$(echo "$line" | sed -n -e 's/^#define *\([^ ]*_BASE_ADDR(X)\) *\(.*\)$/\2/p')
  #echo "$base_addr_expr"
  if [ "${base_addr_name}X" != "X" ]
  then
    base_found=1
    break
  fi
done

# find register definitions and evaluate register addresses
# For example the following line:
# #define DDRC_MSTR(X)            REG32(DDRC_BASE_ADDR(X) + 0x00)
# is expanded to:
# #define DDRC_MSTR_0 0x5c000000
# #define DDRC_MSTR_1 0x5c100000

while IFS= read -r line
do
  echo "$line"
  # substitute BASE_ADDR(X) with the macro value
  line=$(echo "$line" | sed -n -e "s/${base_addr_name}/${base_addr_expr}/p")
  # extract register name and arithmetic expression
  reg_name=$(echo "$line" | sed -n -e "s/^#define *\([^(]*\)(X)[[:space:]]*REG32(\(.*\))$/\1/p")
  reg_value=$(echo "$line" | sed -n -e "s/^#define *\([^(]*\)(X)[[:space:]]*REG32(\(.*\))$/\2/p")
  #echo "$reg_name" "$reg_value"
  if [ "${reg_name}X" != "X" ]
  then
    # enumerate X from 0 to the number of DDR
    for instance in 0 1
    do
      tmp=$(echo "$reg_value" | sed -n -e "s/(X/(${instance}/p")
      printf "#define %-23s 0x%x\n" "${reg_name}_${instance}" $(($tmp))
    done
  fi
done

exit 0
