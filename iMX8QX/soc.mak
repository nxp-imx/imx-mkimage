MKIMG = ../mkimage_imx8
DCD_CFG_SRC = imx8qx_dcd_1.2GHz.cfg
DCD_CFG = imx8qx_dcd.cfg.tmp

DCD_CFG_16BIT_SRC = imx8qx_dcd_16bit_1.2GHz.cfg
DCD_16BIT_CFG = imx8qx_16bit_dcd.cfg.tmp

DCD_CFG_DDR3_SRC = imx8qx_ddr3_dcd_1066MHz_ecc.cfg
DCD_DDR3_CFG = imx8qx_ddr3_dcd_1066MHz_ecc.cfg.tmp

DCD_CFG_DX_DDR3_SRC = imx8dx_ddr3_dcd_16bit_933MHz.cfg
DCD_DX_DDR3_CFG = imx8dx_ddr3_dcd_16bit_933MHz.cfg.tmp

CC ?= gcc
REVISION ?= A0
CFLAGS ?= -O2 -Wall -std=c99 -static
INCLUDE = ./lib

#set default DDR_training to be in DCDs

DDR3_DCD ?= 0
DX ?= 0
DDR_TRAIN ?= 1
WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net
DIR = internal-only/Linux_IMX_Rocko_MX8/$(N)/common_bsp

#define the F(Q)SPI header file
QSPI_HEADER = ../scripts/fspi_header
QSPI_PACKER = ../scripts/fspi_packer.sh

ifeq ($(DDR3_DCD), 1)
    ifeq ($(DX), 1)
	    DCD_CFG_SRC = imx8dx_ddr3_dcd_16bit_933MHz.cfg
    else
	    DCD_CFG_SRC = imx8qx_ddr3_dcd_1066MHz_ecc.cfg
    endif
endif

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

$(DCD_CFG): FORCE
	@echo "Converting iMX8 DCD file"
	$(CC) -E -Wp,-MD,.imx8qx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_CFG) $(DCD_CFG_SRC)
	$(CC) -E -Wp,-MD,.imx8qx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_16BIT_CFG) $(DCD_CFG_16BIT_SRC)
	$(CC) -E -Wp,-MD,.imx8qx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_DDR3_CFG) $(DCD_CFG_DDR3_SRC)
	$(CC) -E -Wp,-MD,.imx8dx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_DX_DDR3_CFG) $(DCD_CFG_DX_DDR3_SRC)
FORCE:

u-boot-atf.bin: u-boot.bin bl31.bin
	@cp bl31.bin u-boot-atf.bin
	./$(MKIMG) -commit > head.hash
	@cat u-boot.bin head.hash > u-boot-hash.bin
	@dd if=u-boot-hash.bin of=u-boot-atf.bin bs=1K seek=128

Image0: Image
	@dd if=Image of=Image0 bs=10M count=1
Image1: Image
	@dd if=Image of=Image1 bs=10M skip=1

.PHONY: clean nightly
clean:
	@rm -f $(MKIMG) $(DCD_CFG) .imx8qx_dcd.cfg.cfgtmp.d Image0 Image1

flash_cm4 flash_b0_cm4: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_cm4ddr flash_b0_cm4ddr: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x88000000 -out flash.bin

flash_uboot_cm4ddr flash_b0_uboot_cm4ddr: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -m4 m4_image.bin 0 0x88000000 -out flash.bin

flash_uboot_cm4 flash_b0_uboot_cm4: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_scfw_a0: $(MKIMG) scfw_tcm.bin
	./$(MKIMG) -soc QX -c -scfw scfw_tcm.bin -out flash.bin

flash_dcd_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_16bit_dcd_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_16BIT_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_ddr3_dcd_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_DDR3_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_dx_ddr3_dcd_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_DX_DDR3_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0: $(MKIMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_early_a0: $(MKIMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -flags 0x00400000 -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_flexspi_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -dev flexspi -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_flexspi: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin $(QSPI_HEADER)
	./$(MKIMG) -soc QX -rev B0 -dev flexspi -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_multi_cores_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m40_tcm.bin 0 0x34FE0000 -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_nand_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -dev nand -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_nand: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -rev B0 -dev nand 16K -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_cm4_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash flash_b0: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_all flash_b0_all: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin CM4.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -m4 CM4.bin 0 0x34FE0000 -out flash.bin

flash_ddrstress flash_b0_ddrstress: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin mx8qx_ddr_stress_test.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c  -flags 0x00800000 -scfw scfw_tcm.bin -ap mx8qx_ddr_stress_test.bin a35 0x00100000 -out flash.bin

flash_test_build_nand_4K flash_b0_test_build_nand_4K: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot.bin CM4.bin
	./$(MKIMG) -soc QX -rev B0 -dev nand 4K -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 CM4.bin 0 0x34FE0000 -out flash.bin

flash_test_build_nand_8K flash_b0_test_build_nand_8K: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot.bin CM4.bin
	./$(MKIMG) -soc QX -rev B0 -dev nand 8K -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 CM4.bin 0 0x34FE0000 -out flash.bin

flash_test_build_nand_16K flash_b0_test_build_nand_16K: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot.bin CM4.bin
	./$(MKIMG) -soc QX -rev B0 -dev nand 16K -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 CM4.bin 0 0x34FE0000 -out flash.bin

flash_test_build flash_b0_test_build: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot.bin CM4.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 CM4.bin 0 0x34FE0000 -out flash.bin

flash_scfw flash_b0_scfw: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin
	./$(MKIMG) -soc QX -rev B0 -dcd skip -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -out flash.bin

flash_secofw flash_b0_secofw: $(MKIMG) ahabfw.bin
	./$(MKIMG) -soc QX -rev B0 -c -seco ahabfw.bin -out flash.bin

flash_msg_block:
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -msg_blk test_block.bin field 0x83000000 -out flash.bin

flash_linux flash_b0_linux: $(MKIMG) Image fsl-imx8qxp-lpddr4-arm2.dtb
	./$(MKIMG) -soc QX -rev B0 -c -ap Image a35 0x80280000 --data fsl-imx8qxp-lpddr4-arm2.dtb 0x83000000 -out flash.bin

flash_test_build_mfg flash_b0_test_build_mfg: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin dummy_ddr.bin u-boot.bin CM4.bin kernel.bin initramfs.bin board.dtb
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 CM4.bin 0 0x34FE0000 -data kernel.bin 0x80280000 -data initramfs.bin 0x83100000 -data board.dtb 0x83000000 -out flash.bin

flash_mfg flash_b0_mfg: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin Image fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.gz.u-boot board.dtb Image0 Image1
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -data board.dtb 0x83000000 -data fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.gz.u-boot 0x83100000 -data Image0 0x80280000 -data Image1 0x80c80000  -out flash_mfg.bin

flash_nand_mfg flash_nand_b0_mfg: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin Image fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.gz.u-boot board-nand.dtb Image0 Image1
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -data board-nand.dtb 0x83000000 -data fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.gz.u-boot 0x83100000 -data Image0 0x80280000 -data Image1 0x80c80000 -out flash_mfg.bin

flash_all_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin u-boot-atf.bin scd.bin csf.bin csf_ap.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -scd scd.bin -csf csf.bin -c -ap u-boot-atf.bin a35 0x80000000 -csf csf_ap.bin -out flash.bin

flash_ca35_ddrstress_a0: $(MKIMG) scfw_tcm.bin mx8qx_ddr_stress_test.bin
	./$(MKIMG) -soc QX -c -flags 0x00800000 -scfw scfw_tcm.bin -c -ap mx8qx_ddr_stress_test.bin a35 0x00112000 -out flash.bin

flash_ca35_ddrstress_dcd_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin mx8qx_ddr_stress_test.bin
	./$(MKIMG) -soc QX -c -flags 0x00800000 -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap mx8qx_ddr_stress_test.bin a35 0x00112000 -out flash.bin	
	
flash_cm4ddr_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x88000000 -out flash.bin

flash_fastboot_a0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -dev emmc_fast -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

nightly :
	@rm -rf boot
	@echo "Pulling nightly for Validation board from $(SERVER)/$(DIR)"
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-ahab-container.img -O mx8qx-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-val-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/bl31-imx8qxp.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/u-boot-imx8qxplpddr4arm2.bin-sd -O u-boot.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "Image-fsl-imx8qxp-*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot
	@$(RENAME) "Image-" "" boot/*.dtb

nightly_mek :
	@rm -rf boot
	@echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-ahab-container.img -O mx8qx-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/bl31-imx8qxp.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/u-boot-imx8qxpmek.bin-sd -O u-boot.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "Image-fsl-imx8qxp-*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot
	@$(RENAME) "Image-" "" boot/*.dtb

