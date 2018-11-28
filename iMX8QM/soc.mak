MKIMG = ../mkimage_imx8
DCD_800_CFG_SRC = imx8qm_dcd_800MHz.cfg
DCD_1200_CFG_SRC = imx8qm_dcd_1.2GHz.cfg
DCD_CFG_SRC = imx8qm_dcd_1.6GHz.cfg

DCD_800_CFG = imx8qm_dcd_800.cfg.tmp
DCD_1200_CFG = imx8qm_dcd_1200.cfg.tmp
DCD_CFG = imx8qm_dcd.cfg.tmp

CC ?= gcc
INCLUDE = ./lib

#set default DDR_training to be in DCDs

DDR_TRAIN ?= 1
WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net

#DIR = internal-only/Linux_IMX_Rocko_MX8/$(N)/common_bsp
#DIR = internal-only/Linux_IMX_Core/$(N)/common_bsp
DIR = internal-only/Linux_IMX_Regression/$(N)/common_bsp

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

#define the F(Q)SPI header file
QSPI_HEADER = ../scripts/fspi_header
QSPI_PACKER = ../scripts/fspi_packer.sh
PAD_IMAGE = ../scripts/pad_image.sh

$(DCD_CFG): FORCE
	@echo "Converting iMX8 DCD 1.6GHz file"
	$(CC) -E -Wp,-MD,.imx8qm_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_CFG) $(DCD_CFG_SRC)

$(DCD_800_CFG): FORCE
	@echo "Converting iMX8 DCD 800MHz file"
	$(CC) -E -Wp,-MD,.imx8qm_dcd_800.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_800_CFG) $(DCD_800_CFG_SRC)

$(DCD_1200_CFG): FORCE
	@echo "Converting iMX8 DCD 1200MHz file"
	$(CC) -E -Wp,-MD,.imx8qm_dcd_1200.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_1200_CFG) $(DCD_1200_CFG_SRC)

FORCE:

u-boot-hash.bin: u-boot.bin
	./$(MKIMG) -commit > head.hash
	@cat u-boot.bin head.hash > u-boot-hash.bin

u-boot-atf.bin: u-boot-hash.bin bl31.bin
	@cp bl31.bin u-boot-atf.bin
	@dd if=u-boot-hash.bin of=u-boot-atf.bin bs=1K seek=128
	@if [ -f "hdmitxfw.bin" ] && [ -f "hdmirxfw.bin" ]; then \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmitxfw.bin hdmitxfw-pad.bin; \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmirxfw.bin hdmirxfw-pad.bin; \
	cat u-boot-atf.bin hdmitxfw-pad.bin hdmirxfw-pad.bin > u-boot-atf-hdmi.bin; \
	cp u-boot-atf-hdmi.bin u-boot-atf.bin; \
	fi

u-boot-atf.itb: u-boot-hash.bin bl31.bin
	@if [ -f "hdmitxfw.bin" ] && [ -f "hdmirxfw.bin" ]; then \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmitxfw.bin hdmitxfw-pad.bin; \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmirxfw.bin hdmirxfw-pad.bin; \
	cat u-boot-hash.bin hdmitxfw-pad.bin hdmirxfw-pad.bin > u-boot-hash.bin.temp; \
	mv u-boot-hash.bin.temp u-boot-hash.bin; \
	fi
	./$(PAD_IMAGE) bl31.bin
	./$(PAD_IMAGE) u-boot-hash.bin
	./mkimage_fit_atf.sh > u-boot.its;
	./mkimage_uboot -E -p 0x3000 -f u-boot.its u-boot-atf.itb;
	@rm -f u-boot.its

u-boot-atf-container.img: bl31.bin u-boot-hash.bin
	@if [ -f "hdmitxfw.bin" ] && [ -f "hdmirxfw.bin" ]; then \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmitxfw.bin hdmitxfw-pad.bin; \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmirxfw.bin hdmirxfw-pad.bin; \
	cat u-boot-hash.bin hdmitxfw-pad.bin hdmirxfw-pad.bin > u-boot-hash.bin.temp; \
	mv u-boot-hash.bin.temp u-boot-hash.bin; \
	fi
	if [ -f "tee.bin" ]; then \
	./$(MKIMG) -soc QM -rev B0 -c -ap bl31.bin a53 0x80000000 -ap u-boot-hash.bin a53 0x80020000 -ap tee.bin a53 0xFE000000 -out u-boot-atf-container.img; \
	else \
	./$(MKIMG) -soc QM -rev B0 -c -ap bl31.bin a53 0x80000000 -ap u-boot-hash.bin a53 0x80020000 -out u-boot-atf-container.img; \
	fi

.PHONY: clean
clean:
	@rm -f $(DCD_CFG) .imx8_dcd.cfg.cfgtmp.d $(DCD_800_CFG) $(DCD_1200_CFG) .imx8qm_dcd_800.cfg.cfgtmp.d .imx8qm_dcd.cfg.cfgtmp.d .imx8qm_dcd_1200.cfg.cfgtmp.d head.hash u-boot-hash.bin u-boot-atf.itb u-boot-atf-container.img u-boot-atf-hdmi.bin hdmitxfw-pad.bin hdmirxfw-pad.bin

flash_scfw: $(MKIMG) scfw_tcm.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -out flash.bin

flash_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_dcd_800: $(MKIMG) $(DCD_800_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_800_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_dcd_1200: $(MKIMG) $(DCD_1200_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_1200_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_early: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -flags 0x00400000 -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_flexspi: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dev flexspi -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_ca72: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a72 0x80000000 -out flash.bin

flash_multi_cores_m4_1: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m41_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m41_tcm.bin 1 0x38FE0000 -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_multi_cores: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin m41_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m40_tcm.bin 0 0x34FE0000 -m4 m41_tcm.bin 1 0x38FE0000 -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_cm4_0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_cm4_1: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 1 0x38FE0000 -out flash.bin

flash_m4s_tcm: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin m41_tcm.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -p1 -m4 m40_tcm.bin 0 0x34FE0000 -m4 m41_tcm.bin 1 0x38FE0000 -out flash.bin

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
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m40_ddr.bin 0 0x88000000 -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_m4_tcm_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin m41_ddr.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_cm4_1_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m41_ddr.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_fastboot: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -dev emmc_fast -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34fe0000 -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_aprom_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin aprom_ddr.bin csf_ap.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap aprom_ddr.bin a53 0x80000000 -c -ap u-boot-atf.bin a53 0x90000000 -csf csf_ap.bin -out flash.bin

flash_aprom_ddr_unsigned: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin aprom_ddr.bin csf_ap.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap aprom_ddr.bin a53 0x80000000 -c -ap u-boot-atf.bin a53 0x90000000 -out flash.bin

flash_b0_scfw: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -out flash.bin

flash_b0: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_b0_flexspi: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -rev B0 -dev flexspi -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_cm40flexspi flash_b0_cm40flexspi: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin m4_image.bin $(QSPI_HEADER)
	./$(MKIMG) -soc QM -rev B0 -dev flexspi -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -fileoff 0x80000 -p1 -m4 m4_image.bin 0 0x08081000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_cm4sflexspi flash_b0_cm4sflexspi: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin m40_flash.bin m41_flash.bin $(QSPI_HEADER)
	./$(MKIMG) -soc QM -rev B0 -dev flexspi -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -fileoff 0x80000 -p1 -m4 m40_flash.bin 0 0x08081000 -fileoff 0x180000 -m4 m41_flash.bin 1 0x08181000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_flexspi_all : $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin m40_flash.bin m41_flash.bin $(QSPI_HEADER)
	./$(MKIMG) -soc QM -rev B0 -dev flexspi -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -fileoff 0x80000 -m4 m40_flash.bin 0 0x08081000 -fileoff 0x180000 -m4 m41_flash.bin 1 0x08181000 -ap u-boot-atf.bin a35 0x80000000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_b0_multi_cores_m4_1: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin m41_tcm.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -m4 m41_tcm.bin 1 0x38FE0000 -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_b0_multi_cores_m4_1_trusty: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin m41_tcm.bin tee.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -m4 m41_tcm.bin 1 0x38FE0000 -ap u-boot-atf.bin a53 0x80000000 -data tee.bin 0x84000000 -out flash.bin

flash_b0_spl_fit_m4_1_trusty: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.itb m41_tcm.bin tee.bin u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -m4 m41_tcm.bin 1 0x38FE0000 -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf.itb at $$pad_cnt KB"; \
                   dd if=u-boot-atf.itb of=flash.bin bs=1K seek=$$pad_cnt; \
		   rm -f u-boot-atf.itb;

flash_b0_spl_container_m4_1_trusty: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf-container.img m41_tcm.bin tee.bin u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -m4 m41_tcm.bin 1 0x38FE0000 -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \
                   rm -f u-boot-atf-container.img;

flash_b0_spl_fit: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.itb u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf.itb at $$pad_cnt KB"; \
                   dd if=u-boot-atf.itb of=flash.bin bs=1K seek=$$pad_cnt; \
		   rm -f u-boot-atf.itb;

flash_b0_spl_container: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-spl.bin u-boot-atf-container.img
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_b0_spl: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf.bin at $$pad_cnt KB"; \
                   dd if=u-boot-atf.bin of=flash.bin bs=1K seek=$$pad_cnt

flash_b0_spl_flexspi_fit: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.itb u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf.itb at $$pad_cnt KB"; \
                   dd if=u-boot-atf.itb of=flash.bin bs=1K seek=$$pad_cnt; \
                   rm -f u-boot-atf.itb;
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_b0_spl_flexspi_container: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-spl.bin u-boot-atf-container.img
	./$(MKIMG) -soc QM -rev B0 -dev flexspi -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_b0_spl_flexspi: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf.bin at $$pad_cnt KB"; \
                   dd if=u-boot-atf.bin of=flash.bin bs=1K seek=$$pad_cnt
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_b0_linux: $(MKIMG) Image fsl-imx8qm-lpddr4-arm2.dtb
	./$(MKIMG) -soc QM -rev B0 -c -ap Image a53 0x80280000 --data fsl-imx8qm-lpddr4-arm2.dtb 0x83000000 -out flash.bin

flash_b0_ca72_ddrstress: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin mx8qmb0_ddr_stress_test.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c  -flags 0x00800000 -scfw scfw_tcm.bin -ap mx8qmb0_ddr_stress_test.bin a72 0x00100000 -out flash.bin

flash_ddrstress flash_b0_ca53_ddrstress: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin mx8qmb0_ddr_stress_test.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c  -flags 0x00800000 -scfw scfw_tcm.bin -ap mx8qmb0_ddr_stress_test.bin a53 0x00100000 -out flash.bin

flash_b0_ca72: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a72 0x80000000 -out flash.bin

flash_b0_cm4_0: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_b0_cm4_1: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 1 0x38FE0000 -out flash.bin

flash_b0_m4s_tcm: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin m40_tcm.bin m41_tcm.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -p1 -m4 m40_tcm.bin 0 0x34FE0000 -m4 m41_tcm.bin 1 0x38FE0000 -out flash.bin

flash_b0_m40_uboot: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin m4_image.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x88000000 -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_linux_m4: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf.bin m4_0_image.bin m4_1_image.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -p3 -m4 m4_0_image.bin 0 0x34FE0000 -p4 -m4 m4_1_image.bin 1 0x38FE0000 -out flash.bin

nightly :
	@rm -rf boot
	@echo "Pulling nightly for Validation board from $(SERVER)/$(DIR)"
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-val-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-imx8qmlpddr4arm2.bin-sd -O u-boot.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR) -P boot -A "Image-*imx8qm*"
	@$(WGET) -q https://bitbucket.sw.nxp.com/projects/IMX/repos/linux-firmware-imx/raw/firmware/seco/mx8qm-ahab-container.img?at=refs%2Fheads%2Fmaster -O mx8qm-ahab-container.img
	@$(RENAME) "Image-" "" boot/*.dtb

nightly_mek :
	rm -rf boot
	echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-imx8qmmek.bin-sd -O u-boot.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR) -P boot -A "Image-*imx8qm*"
	@$(WGET) -q https://bitbucket.sw.nxp.com/projects/IMX/repos/linux-firmware-imx/raw/firmware/seco/mx8qm-ahab-container.img?at=refs%2Fheads%2Fmaster -O mx8qm-ahab-container.img
	@$(RENAME) "Image-" "" boot/*.dtb

