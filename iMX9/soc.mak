MKIMG = ../mkimage_imx8

CC ?= gcc
REV ?= A0
CFLAGS ?= -O2 -Wall -std=c99 -static
INCLUDE = ./lib

#define the F(Q)SPI header file
QSPI_HEADER = ../scripts/fspi_header
QSPI_PACKER = ../scripts/fspi_packer.sh
QSPI_FCB_GEN = ../scripts/fspi_fcb_gen.sh
PAD_IMAGE = ../scripts/pad_image.sh

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

LC_REVISION = $(shell echo $(REV) | tr ABC abc)
AHAB_IMG = mx93$(LC_REVISION)-ahab-container.img
MCU_IMG = m33_image.bin

ifeq ($(SOC),iMX91)
SPL_LOAD_ADDR ?= 0x204A0000
ATF_LOAD_ADDR ?= 0x204C0000
else
SPL_LOAD_ADDR ?= 0x2049A000
ATF_LOAD_ADDR ?= 0x204E0000
endif
FCB_LOAD_ADDR ?= $(ATF_LOAD_ADDR)
TEE_LOAD_ADDR ?= 0x96000000
UBOOT_LOAD_ADDR ?= 0x80200000
MCU_TCM_ADDR ?= 0x1FFE0000
MCU_TCM_ADDR_ACORE_VIEW ?= 0x201E0000
MCU_XIP_ADDR ?= 0x28032000 # Point entry of m33 in flexspi0 nor flash
M33_IMAGE_XIP_OFFSET ?= 0x31000 # 1st container offset is 0x1000 when boot device is flexspi0 nor flash, actually the m33_image.bin is in 0x31000 + 0x1000 = 0x32000.

LPDDR_FW_VERSION = _v202201

define append_fcb
	@mv flash.bin flash.tmp
	@dd if=fcb.bin of=flash.bin bs=1k seek=1
	@dd if=flash.tmp of=flash.bin bs=1k seek=4
	@rm flash.tmp
	@echo "Append FCB to flash.bin"
endef

FORCE:

lpddr4_imem_1d = lpddr4_imem_1d$(LPDDR_FW_VERSION).bin
lpddr4_dmem_1d = lpddr4_dmem_1d$(LPDDR_FW_VERSION).bin
lpddr4_imem_2d = lpddr4_imem_2d$(LPDDR_FW_VERSION).bin
lpddr4_dmem_2d = lpddr4_dmem_2d$(LPDDR_FW_VERSION).bin
lpddr4_imem_qb = lpddr4_imem_qb$(LPDDR_FW_VERSION).bin
lpddr4_dmem_qb = lpddr4_dmem_qb$(LPDDR_FW_VERSION).bin
lpddr4_qb_data = lpddr4_qb_data.bin

u-boot-spl-ddr.bin: u-boot-spl.bin $(lpddr4_imem_1d) $(lpddr4_dmem_1d) $(lpddr4_imem_2d) $(lpddr4_dmem_2d)
	@objcopy -I binary -O binary --pad-to 0x8000 --gap-fill=0x0 $(lpddr4_imem_1d) lpddr4_pmu_train_1d_imem_pad.bin
	@objcopy -I binary -O binary --pad-to 0x4000 --gap-fill=0x0 $(lpddr4_dmem_1d) lpddr4_pmu_train_1d_dmem_pad.bin
	@objcopy -I binary -O binary --pad-to 0x8000 --gap-fill=0x0 $(lpddr4_imem_2d) lpddr4_pmu_train_2d_imem_pad.bin
	@cat lpddr4_pmu_train_1d_imem_pad.bin lpddr4_pmu_train_1d_dmem_pad.bin > lpddr4_pmu_train_1d_fw.bin
	@cat lpddr4_pmu_train_2d_imem_pad.bin $(lpddr4_dmem_2d) > lpddr4_pmu_train_2d_fw.bin
	@dd if=u-boot-spl.bin of=u-boot-spl-pad.bin bs=4 conv=sync
	@cat u-boot-spl-pad.bin lpddr4_pmu_train_1d_fw.bin lpddr4_pmu_train_2d_fw.bin > u-boot-spl-ddr.bin
	@rm -f u-boot-spl-pad.bin lpddr4_pmu_train_1d_fw.bin lpddr4_pmu_train_2d_fw.bin lpddr4_pmu_train_1d_imem_pad.bin lpddr4_pmu_train_1d_dmem_pad.bin lpddr4_pmu_train_2d_imem_pad.bin

u-boot-spl-ddr-qb.bin: u-boot-spl.bin $(lpddr4_imem_qb) $(lpddr4_dmem_qb) $(lpddr4_qb_data)
	@objcopy -I binary -O binary --pad-to 0x8000 --gap-fill=0x0 $(lpddr4_imem_qb) lpddr4_pmu_qb_imem_pad.bin
	@objcopy -I binary -O binary --pad-to 0x4000 --gap-fill=0x0 $(lpddr4_dmem_qb) lpddr4_pmu_qb_dmem_pad.bin
	@cat lpddr4_pmu_qb_imem_pad.bin lpddr4_pmu_qb_dmem_pad.bin > lpddr4_pmu_qb_fw.bin
	@dd if=u-boot-spl.bin of=u-boot-spl-pad.bin bs=4 conv=sync
	@cat u-boot-spl-pad.bin lpddr4_pmu_qb_fw.bin $(lpddr4_qb_data) > u-boot-spl-ddr-qb.bin
	@rm -f u-boot-spl-pad.bin lpddr4_pmu_qb_imem_pad.bin lpddr4_pmu_qb_dmem_pad.bin lpddr4_pmu_qb_fw.bin

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

fcb.bin: FORCE
	./$(QSPI_FCB_GEN) $(QSPI_HEADER)

.PHONY: clean nightly
clean:
	@rm -f $(MKIMG) u-boot-atf-container.img u-boot-spl-ddr.bin u-boot-spl-ddr-qb.bin u-boot-hash.bin
	@rm -rf extracted_imgs
	@echo "imx9 clean done"

flash_singleboot: $(MKIMG) $(AHAB_IMG) u-boot-spl-ddr.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c -ap u-boot-spl-ddr.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_qb: $(MKIMG) $(AHAB_IMG) u-boot-spl-ddr-qb.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c -ap u-boot-spl-ddr-qb.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_flexspi: $(MKIMG) $(AHAB_IMG) u-boot-spl-ddr.bin u-boot-atf-container.img fcb.bin
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -c -ap u-boot-spl-ddr.bin a35 $(SPL_LOAD_ADDR) -fcb fcb.bin $(FCB_LOAD_ADDR) -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;
	$(call append_fcb)

flash_singleboot_m33: $(MKIMG) $(AHAB_IMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c -m4 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -ap u-boot-spl-ddr.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_m33_no_ahabfw: $(MKIMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -c -m4 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -ap u-boot-spl-ddr.bin a35 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_m33_flexspi: $(MKIMG) $(AHAB_IMG) $(UPOWER_IMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl-ddr.bin fcb.bin
	./$(MKIMG) -soc IMX9  -dev flexspi -append $(AHAB_IMG) -c -m4 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -ap u-boot-spl-ddr.bin a35 $(SPL_LOAD_ADDR) -fcb fcb.bin $(FCB_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \
	$(call append_fcb)

flash_lpboot: $(MKIMG) $(AHAB_IMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c -m4 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin

flash_lpboot_flexspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -c -m4 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_flexspi_xip: $(MKIMG) $(AHAB_IMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -fileoff $(M33_IMAGE_XIP_OFFSET) -c -m4 $(MCU_IMG) 0 $(MCU_XIP_ADDR) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_no_ahabfw_flexspi: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -dev flexspi -c -m4 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_sentinel: $(MKIMG) ahabfw.bin
	./$(MKIMG) -soc IMX9 -c -sentinel ahabfw.bin -out flash.bin

flash_kernel: $(MKIMG) Image imx93-11x11-evk.dtb
	./$(MKIMG) -soc IMX9 -c -ap Image a35 0x80400000 --data imx93-11x11-evk.dtb a35 0x83000000 -out flash.bin

flash_bootaux_cntr: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -c -m4 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -out flash.bin

flash_bootaux_cntr_xip: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -c -fileoff $(M33_IMAGE_XIP_OFFSET) -m4 $(MCU_IMG) 0 $(MCU_XIP_ADDR) -out flash.bin

parse_container: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -parse flash.bin

extract: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -extract flash.bin

ifneq ($(wildcard ../$(SOC_DIR)/scripts/autobuild.mak),)
$(info include autobuild.mak)
include ../$(SOC_DIR)/scripts/autobuild.mak
endif
