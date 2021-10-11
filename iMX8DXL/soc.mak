MKIMG = ../mkimage_imx8

CC ?= gcc
V2X ?= YES
REVISION ?= A1
CFLAGS ?= -O2 -Wall -std=c99 -static
INCLUDE = ./lib

LC_REVISION = $(shell echo $(REVISION) | tr ABC abc)
SECO_FW_NAME = mx8dxl$(LC_REVISION)-ahab-container.img

#define the F(Q)SPI header file
QSPI_HEADER = ../scripts/fspi_header
QSPI_PACKER = ../scripts/fspi_packer.sh
PAD_IMAGE = ../scripts/pad_image.sh
SPLIT_SPL = ../scripts/split_spl.sh

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

V2X_OCRAM = 0x110000
ifeq ($(V2X),YES)
    V2X_DUMMY_DDR = -dummy 0x87fc0000
    V2X_DUMMY_OCRAM = -dummy ${V2X_OCRAM}
endif

TEE_LOAD_ADDR ?= 0x96000000

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
			./$(MKIMG) -soc DXL -rev A0 -sw_version $(ROLLBACK_INDEX_IN_CONTAINER)  -c -ap bl31.bin a35 0x80000000 -ap u-boot-hash.bin a35 0x80020000 -ap tee.bin a35 $(TEE_LOAD_ADDR) -out u-boot-atf-container.img; \
		else \
			./$(MKIMG) -soc DXL -rev A0 -c -ap bl31.bin a35 0x80000000 -ap u-boot-hash.bin a35 0x80020000 -ap tee.bin a35 $(TEE_LOAD_ADDR) -out u-boot-atf-container.img; \
		fi; \
	else \
	./$(MKIMG) -soc DXL -rev A0 -c -ap bl31.bin a35 0x80000000 -ap u-boot-hash.bin a35 0x80020000 -out u-boot-atf-container.img; \
	fi

prepare_spl: u-boot-spl.bin
	V2X=${V2X} ./$(SPLIT_SPL) u-boot-spl.bin ${V2X_OCRAM}

Image0: Image
	@dd if=Image of=Image0 bs=10M count=1
Image1: Image
	@dd if=Image of=Image1 bs=10M skip=1

.PHONY: clean nightly
clean:
	@rm -f $(MKIMG) u-boot-atf-container.img Image0 Image1 u-boot-hash.bin u-boot-atf.bin head.hash u-boot-atf-container.img flash.bin
	@rm -rf extracted_imgs
	@echo "imx8dxl clean done"

flash: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 $(V2X_DUMMY_DDR) -out flash.bin

flash_nand: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc DXL -rev A0 -dev nand 16K -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 $(V2X_DUMMY_DDR) -out flash.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 $(V2X_DUMMY_DDR) -out flash_fw.bin

flash_flexspi: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin $(QSPI_HEADER)
	./$(MKIMG) -soc DXL -rev A0  -dev flexspi -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 $(V2X_DUMMY_OCRAM) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_spl: $(MKIMG) prepare_spl $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf-container.img
	SPL_CMD="$(shell cat u-boot-spl.bin_cmd)"; \
	./$(MKIMG) -soc DXL -rev A0  -dcd skip -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin $$SPL_CMD $(V2X_DUMMY_OCRAM) -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_spl_flexspi: $(MKIMG) prepare_spl $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf-container.img
	SPL_CMD="$(shell cat u-boot-spl.bin_cmd)"; \
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -dev flexspi -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin $$SPL_CMD $(V2X_DUMMY_OCRAM) -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_spl_nand: $(MKIMG) prepare_spl $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf-container.img
	SPL_CMD="$(shell cat u-boot-spl.bin_cmd)"; \
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -dev nand 16K -dcd skip -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin $$SPL_CMD $(V2X_DUMMY_OCRAM) -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x4000 - 1) / 0x4000)); page=16;\
                   echo "append u-boot-atf-container.img at $$((pad_cnt * page))  a $$pad_cnt b $$page KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$((pad_cnt * page))

flash_linux_m4: $(MKIMG) prepare_spl $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf-container.img m4_image.bin
	SPL_CMD="$(shell cat u-boot-spl.bin_cmd)"; \
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -append $(SECO_FW_NAME) -c -flags 0x00200000 -scfw scfw_tcm.bin $$SPL_CMD -p3 -m4 m4_image.bin 0 0x34FE0000 $(V2X_DUMMY_OCRAM) -out flash.bin

	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \

flash_linux_m4_ddr: $(MKIMG) prepare_spl $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf-container.img m4_image.bin
	SPL_CMD="$(shell cat u-boot-spl.bin_cmd)"; \
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -flags 0x00200000 -scfw scfw_tcm.bin $$SPL_CMD -p3 -m4 m4_image.bin 0 0x88000000 $(V2X_DUMMY_DDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \

flash_linux_m4_xip: $(MKIMG) prepare_spl $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf-container.img m4_image.bin
	SPL_CMD="$(shell cat u-boot-spl.bin_cmd)"; \
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -append $(SECO_FW_NAME) -c -flags 0x00200000 -scfw scfw_tcm.bin -fileoff 0x80000 -p3 -m4 m4_image.bin 0 0x08081000 -fileoff 0x180000 $$SPL_CMD $(V2X_DUMMY_OCRAM) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_regression_linux_m4: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -p3 -m4 m4_image.bin 0 0x34FE0000 $(V2X_DUMMY_DDR) -out flash.bin

flash_regression_linux_m4_ddr: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -flags 0x00200000 -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -p3 -m4 m4_image.bin 0 0x88000000 $(V2X_DUMMY_DDR) -out flash.bin

flash_regression_linux_m4_xip : $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin m4_image.bin $(QSPI_HEADER)
	./$(MKIMG) -soc DXL -rev A0 -dev flexspi -append $(SECO_FW_NAME) -c -flags 0x00200000 -scfw scfw_tcm.bin -fileoff 0x80000 -p3 -m4 m4_image.bin 0 0x08081000 -fileoff 0x180000 -ap u-boot-atf.bin a35 0x80000000 $(V2X_DUMMY_OCRAM) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_scfw: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin $(V2X_DUMMY_OCRAM) --out flash.bin

flash_patch: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin message_signed.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -msg_blk message_signed.bin patch 0x80000000 $(V2X_DUMMY_OCRAM) --out flash.bin

flash_kernel: $(MKIMG) Image imx8dxl-evk.dtb
	./$(MKIMG) -soc DXL -rev A0 -c -ap Image a35 0x80280000 --data imx8dxl-evk.dtb a35 0x83000000 -out flash.bin

parse_container: $(MKIMG) flash.bin
	./$(MKIMG) -soc DXL -rev A0 -parse flash.bin

extract: $(MKIMG) flash.bin
	./$(MKIMG) -soc DXL -rev A0 -extract flash.bin


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
