MKIMG = ../mkimage_imx8

CC ?= gcc
INCLUDE = ./lib

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

#define the F(Q)SPI header file
QSPI_HEADER = ../scripts/fspi_header
QSPI_PACKER = ../scripts/fspi_packer.sh
PAD_IMAGE = ../scripts/pad_image.sh

AHAB_IMG = mx8qmb0-ahab-container.img

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
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc QM -sw_version $(ROLLBACK_INDEX_IN_CONTAINER) -rev B0 -c -ap bl31.bin a53 0x80000000 -ap u-boot-hash.bin a53 0x80020000 -ap tee.bin a53 0xFE000000 -out u-boot-atf-container.img; \
		else \
			./$(MKIMG) -soc QM -rev B0 -c -ap bl31.bin a53 0x80000000 -ap u-boot-hash.bin a53 0x80020000 -ap tee.bin a53 0xFE000000 -out u-boot-atf-container.img; \
		fi; \
	else \
	./$(MKIMG) -soc QM -rev B0 -c -ap bl31.bin a53 0x80000000 -ap u-boot-hash.bin a53 0x80020000 -out u-boot-atf-container.img; \
	fi

.PHONY: clean
clean:
	@rm -f $(DCD_CFG) .imx8_dcd.cfg.cfgtmp.d $(DCD_800_CFG) $(DCD_1200_CFG) .imx8qm_dcd_800.cfg.cfgtmp.d .imx8qm_dcd.cfg.cfgtmp.d .imx8qm_dcd_1200.cfg.cfgtmp.d head.hash u-boot-hash.bin u-boot-atf.itb u-boot-atf-container.img u-boot-atf-hdmi.bin hdmitxfw-pad.bin hdmirxfw-pad.bin
	@rm -rf extracted_imgs
	@echo "imx8qm clean done"

flash: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_flexspi: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -rev B0 -dev flexspi -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_spl: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-spl.bin u-boot-atf-container.img
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_spl_flexspi: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-spl.bin u-boot-atf-container.img
	./$(MKIMG) -soc QM -rev B0 -dcd skip  -dev flexspi -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_linux_m4: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-spl.bin m4_image.bin m4_1_image.bin u-boot-atf-container.img
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -p3 -m4 m4_image.bin 0 0x34FE0000 -p4 -m4 m4_1_image.bin 1 0x38FE0000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_linux_m4_ddr: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-spl.bin m4_image.bin m4_1_image.bin u-boot-atf-container.img
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x00100000 -p3 -m4 m4_image.bin 0 0x88000000 -p4 -m4 m4_1_image.bin 1 0x88800000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_linux_m4_xip: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-spl.bin u-boot-atf-container.img m4_image.bin m4_1_image.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -dev flexspi -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -fileoff 0x80000 -p3 -m4 m4_image.bin 0 0x08081000 -fileoff 0x180000 -p4 -m4 m4_1_image.bin 1 0x08181000 -fileoff 0x280000 -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_regression_linux_m4: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin m4_image.bin m4_1_image.bin
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -p3 -m4 m4_image.bin 0 0x34FE0000 -p4 -m4 m4_1_image.bin 1 0x38FE0000 -out flash.bin

flash_regression_linux_m4_ddr: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin m4_image.bin m4_1_image.bin
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -p3 -m4 m4_image.bin 0 0x88000000 -p4 -m4 m4_1_image.bin 1 0x88800000 -out flash.bin

flash_regression_linux_m4_xip: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin m4_image.bin m4_1_image.bin $(QSPI_HEADER)
	./$(MKIMG) -soc QM -rev B0 -dev flexspi -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -fileoff 0x80000 -p3 -m4 m4_image.bin 0 0x08081000 -fileoff 0x180000 -p4 -m4 m4_1_image.bin 1 0x08181000 -fileoff 0x280000 -ap u-boot-atf.bin a35 0x80000000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_regression_linux_m41: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin m4_1_image.bin
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -p4 -m4 m4_1_image.bin 1 0x38FE0000 -out flash.bin

flash_regression_linux_m41_ddr: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin m4_1_image.bin
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-atf.bin a53 0x80000000 -p4 -m4 m4_1_image.bin 1 0x88800000 -out flash.bin

flash_regression_linux_m41_xip: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin m4_1_image.bin $(QSPI_HEADER)
	./$(MKIMG) -soc QM -rev B0 -dev flexspi -append $(AHAB_IMG) -c -flags 0x00200000 -scfw scfw_tcm.bin -fileoff 0x180000 -p4 -m4 m4_1_image.bin 1 0x08181000 -fileoff 0x280000 -ap u-boot-atf.bin a35 0x80000000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_scfw: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -out flash.bin

flash_kernel: $(MKIMG) Image fsl-imx8qm-mek.dtb
	./$(MKIMG) -soc QM -rev B0 -c -ap Image a53 0x80280000 --data fsl-imx8qm-mek.dtb 0x83000000 -out flash.bin

flash_ca72: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a72 0x80000000 -out flash.bin

parse_container: $(MKIMG) flash.bin
	./$(MKIMG) -soc QM -rev B0 -parse flash.bin

extract: $(MKIMG) flash.bin
	./$(MKIMG) -soc QM -rev B0 -extract flash.bin

ifneq ($(wildcard scripts/misc.mak),)
$(info include misc.mak)
include scripts/misc.mak
endif

ifneq ($(wildcard scripts/m4.mak),)
$(info include m4.mak)
include scripts/m4.mak
endif

ifneq ($(wildcard scripts/android.mak),)
$(info include android.mak)
include scripts/android.mak
endif

ifneq ($(wildcard scripts/test.mak),)
$(info include test.mak)
include scripts/test.mak
endif

ifneq ($(wildcard scripts/autobuild.mak),)
$(info include autobuild.mak)
include scripts/autobuild.mak
endif

ifneq ($(wildcard scripts/rev_a.mak),)
$(info include rev_a.mak)
include scripts/rev_a.mak
endif

ifneq ($(wildcard scripts/alias.mak),)
$(info include alias.mak)
include scripts/alias.mak
endif
