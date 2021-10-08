MKIMG = ../mkimage_imx8

CC ?= gcc
REV ?= A0
CFLAGS ?= -O2 -Wall -std=c99 -static
INCLUDE = ./lib

#define the F(Q)SPI header file
QSPI_HEADER = ../scripts/fspi_header
QSPI_PACKER = ../scripts/fspi_packer.sh
PAD_IMAGE = ../scripts/pad_image.sh

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

AHAB_IMG = mx93a0-ahab-container.img
MCU_IMG = m33_image.bin

SPL_LOAD_ADDR ?= 0x2049A000
ATF_LOAD_ADDR ?= 0x204E0000
TEE_LOAD_ADDR ?= 0x96000000
UBOOT_LOAD_ADDR ?= 0x80200000
MCU_SSRAM_ADDR ?= 0x1ffc2000
MCU_XIP_ADDR ?= 0x4032000 # Point entry of m33 in flexspi0 nor flash
M33_IMAGE_XIP_OFFSET ?= 0x31000 # 1st container offset is 0x1000 when boot device is flexspi0 nor flash, actually the m33_image.bin is in 0x31000 + 0x1000 = 0x32000.


FORCE:

u-boot-hash.bin: u-boot.bin
	./$(MKIMG) -commit > head.hash
	@cat u-boot.bin head.hash > u-boot-hash.bin

u-boot-atf.bin: u-boot-hash.bin bl31.bin
	@cp bl31.bin u-boot-atf.bin
	@dd if=u-boot-hash.bin of=u-boot-atf.bin bs=1K seek=128

u-boot-atf.itb: u-boot-hash.bin bl31.bin
	./$(PAD_IMAGE) bl31.bin
	./$(PAD_IMAGE) u-boot-hash.bin
	TEE_LOAD_ADDR=$(TEE_LOAD_ADDR) ./mkimage_fit_atf.sh > u-boot.its;
	./mkimage_uboot -E -p 0x3000 -f u-boot.its u-boot-atf.itb;
	@rm -f u-boot.its

u-boot-atf-container.img: bl31.bin u-boot-hash.bin
	if [ -f tee.bin ]; then \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc IMX9 -sw_version $(ROLLBACK_INDEX_IN_CONTAINER)  -c -ap bl31.bin a35 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a35 $(UBOOT_LOAD_ADDR) -ap tee.bin a35 $(TEE_LOAD_ADDR) -out u-boot-atf-container.img; \
		else \
			./$(MKIMG) -soc IMX9 -c -ap bl31.bin a35 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a35 $(UBOOT_LOAD_ADDR) -ap tee.bin a35 $(TEE_LOAD_ADDR) -out u-boot-atf-container.img; \
		fi; \
	else \
		./$(MKIMG) -soc IMX9 -c -ap bl31.bin a35 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a35 $(UBOOT_LOAD_ADDR) -out u-boot-atf-container.img; \
	fi

.PHONY: clean nightly
clean:
	@rm -f $(MKIMG) u-boot-atf-container.img
	@rm -rf extracted_imgs
	@echo "imx8ulp clean done"

flash_singleboot: $(MKIMG) $(AHAB_IMG) u-boot-spl.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c -ap u-boot-spl.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_flexspi: $(MKIMG) $(AHAB_IMG) u-boot-spl.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -c -ap u-boot-spl.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_singleboot_m33: $(MKIMG) $(AHAB_IMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl.bin
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c -m4 $(MCU_IMG) 0 $(MCU_SSRAM_ADDR) -ap u-boot-spl.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_m33_no_ahabfw: $(MKIMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl.bin
	./$(MKIMG) -soc IMX9 -c -m4 $(MCU_IMG) 0 $(MCU_SSRAM_ADDR) -ap u-boot-spl.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_m33_flexspi: $(MKIMG) $(AHAB_IMG) $(UPOWER_IMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl.bin
	./$(MKIMG) -soc IMX9  -dev flexspi -append $(AHAB_IMG) -c -m4 $(MCU_IMG) 0 $(MCU_SSRAM_ADDR) -ap u-boot-spl.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_sentinel: $(MKIMG) ahabfw.bin
	./$(MKIMG) -soc IMX9 -c -sentinel ahabfw.bin -out flash.bin

flash_kernel: $(MKIMG) Image imx93-11x11-evk.dtb
	./$(MKIMG) -soc IMX9 -c -ap Image a35 0x80400000 --data imx93-11x11-evk.dtb a35 0x83000000 -out flash.bin

parse_container: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -parse flash.bin

extract: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -extract flash.bin

