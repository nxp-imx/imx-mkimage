MKIMG = ../mkimage_imx8
DCD_CFG_SRC = imx8qx_dcd_1.2GHz.cfg
DCD_CFG = imx8qx_dcd.cfg.tmp

DCD_CFG_16BIT_SRC = imx8qx_dcd_16bit_1.2GHz.cfg
DCD_16BIT_CFG = imx8qx_16bit_dcd.cfg.tmp

CC ?= gcc
CFLAGS ?= -O2 -Wall -std=c99 -static
INCLUDE = ./lib

#set default DDR_training to be in DCDs

DDR_TRAIN ?= 1
WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net
DIR = build-output/Linux_IMX_MX8/$(N)/common_bsp

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

$(DCD_CFG): FORCE
	@echo "Converting iMX8 DCD file"
	$(CC) -E -Wp,-MD,.imx8qx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_CFG) $(DCD_CFG_SRC)
	$(CC) -E -Wp,-MD,.imx8qx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_16BIT_CFG) $(DCD_CFG_16BIT_SRC)
FORCE:

u-boot-atf.bin: u-boot.bin bl31.bin
	@cp bl31.bin u-boot-atf.bin
	./$(MKIMG) -commit > head.hash
	@cat u-boot.bin head.hash > u-boot-hash.bin
	@dd if=u-boot-hash.bin of=u-boot-atf.bin bs=1K seek=128

.PHONY: clean nightly
clean:
	@rm -f $(MKIMG) $(DCD_CFG) .imx8qx_dcd.cfg.cfgtmp.d

flash_scfw: $(MKIMG) scfw_tcm.bin
	./$(MKIMG) -soc QX -c -scfw scfw_tcm.bin -out flash.bin

flash_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_16bit_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_16BIT_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash: $(MKIMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_early: $(MKIMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -flags 0x00400000 -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_flexspi: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -dev flexspi -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_multi_cores: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m40_tcm.bin 0 0x34FE0000 -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_nand: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -dev nand -dcd $(DCD_CFG) -c -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_cm4_0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_all: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin u-boot-atf.bin scd.bin csf.bin csf_ap.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -scd scd.bin -csf csf.bin -c -ap u-boot-atf.bin a35 0x80000000 -csf csf_ap.bin -out flash.bin

flash_ca35_ddrstress: $(MKIMG) scfw_tcm.bin mx8qx_ddr_stress_test.bin
	./$(MKIMG) -soc QX -c -flags 0x00800000 -scfw scfw_tcm.bin -c -ap mx8qx_ddr_stress_test.bin a35 0x00112000 -out flash.bin

flash_ca35_ddrstress_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin mx8qx_ddr_stress_test.bin
	./$(MKIMG) -soc QX -c -flags 0x00800000 -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap mx8qx_ddr_stress_test.bin a35 0x00112000 -out flash.bin	
	
flash_cm4ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x88000000 -out flash.bin

flash_fastboot: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin m4_image.bin
	./$(MKIMG) -soc QX -dev emmc_fast -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

nightly :
	@rm -rf boot
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/bl31-imx8qxp.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/u-boot-imx8qxplpddr4arm2.bin-sd -O u-boot.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR) -P boot -A "Image-fsl-imx8qxp-*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot
	@$(RENAME) "Image-" "" boot/*.dtb
