MKIMG = ../mkimage_imx8
#DCD_CFG_SRC = imx8qm_dcd_800MHz.cfg
#DCD_CFG_SRC = imx8qm_dcd_1.2GHz.cfg
DCD_CFG_SRC = imx8qm_dcd_1.6GHz.cfg

DCD_CFG = imx8qm_dcd.cfg.tmp

CC ?= gcc
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
	$(CC) -E -Wp,-MD,.imx8qm_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_CFG) $(DCD_CFG_SRC)

FORCE:

u-boot-atf.bin: u-boot.bin bl31.bin
	@cp bl31.bin u-boot-atf.bin
	./$(MKIMG) -commit > head.hash
	@cat u-boot.bin head.hash > u-boot-hash.bin
	@dd if=u-boot-hash.bin of=u-boot-atf.bin bs=1K seek=128
	@if [ ! -d "hdmitxfw.bin" ]; then \
	cp u-boot-atf.bin u-boot-atf-b.bin; \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmitxfw.bin hdmitxfw-pad.bin; \
	cat u-boot-atf.bin hdmitxfw-pad.bin > u-boot-atf-hdmi.bin; \
	cp u-boot-atf-hdmi.bin u-boot-atf.bin; \
	fi

.PHONY: clean
clean:
	@rm -f $(DCD_CFG) .imx8_dcd.cfg.cfgtmp.d

flash_scfw: $(MKIMG) scfw_tcm.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -out flash.bin

flash_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_early: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -flags 0x00400000 -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_flexspi: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dev flexspi -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_ca72: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a72 0x80000000 -out flash.bin

flash_multi_cores: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin m41_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m40_tcm.bin 0 0x34FE0000 -m4 m41_tcm.bin 1 0x38FE0000 -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_cm4_0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_cm4_1: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 1 0x38FE0000 -out flash.bin

flash_m4s_tcm: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin m41_tcm.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -m4 m40_tcm.bin 0 0x34FE0000 -m4 m41_tcm.bin 1 0x38FE0000 -out flash.bin

flash_all: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin u-boot-atf.bin scd.bin csf.bin csf_ap.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -csf csf.bin -scd scd.bin -c -ap u-boot-atf.bin a53 0x80000000 -csf csf_ap.bin -out flash.bin

flash_ca72_ddrstress: $(MKIMG) scfw_tcm.bin mx8qm_ddr_stress_test.bin
	./$(MKIMG) -soc QM -c -flags 0x00800000 -scfw scfw_tcm.bin -c -ap mx8qm_ddr_stress_test.bin a72 0x00112000 -out flash.bin

flash_ca53_ddrstress: $(MKIMG) scfw_tcm.bin mx8qm_ddr_stress_test.bin
	./$(MKIMG) -soc QM -c -flags 0x00800000 -scfw scfw_tcm.bin -c -ap mx8qm_ddr_stress_test.bin a53 0x00112000 -out flash.bin

flash_ca72_ddrstress_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin mx8qm_ddr_stress_test.bin
	./$(MKIMG) -soc QM -c -flags 0x00800000 -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap mx8qm_ddr_stress_test.bin a72 0x00112000 -out flash.bin

flash_ca53_ddrstress_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin mx8qm_ddr_stress_test.bin
	./$(MKIMG) -soc QM -c -flags 0x00800000 -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap mx8qm_ddr_stress_test.bin a53 0x00112000 -out flash.bin

flash_cm4_01_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_ddr.bin m41_ddr.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m40_ddr.bin 0 0x88000000 -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_m4_tcm_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin m41_ddr.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_cm4_1_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m41_ddr.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_fastboot: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -dev emmc_fast -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34fe0000 -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_aprom_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin aprom_ddr.bin csf_ap.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap aprom_ddr.bin a53 0x80000000 -c -ap u-boot-atf.bin a53 0x90000000 -csf csf_ap.bin -out flash.bin

flash_aprom_ddr_unsigned: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin aprom_ddr.bin csf_ap.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap aprom_ddr.bin a53 0x80000000 -c -ap u-boot-atf.bin a53 0x90000000 -out flash.bin


nightly :
	@rm -rf boot
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-imx8qmlpddr4arm2.bin-sd -O u-boot.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR) -P boot -A "Image-fsl-imx8qm-*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot
	@$(RENAME) "Image-" "" boot/*.dtb

