MKIMG = ../mkimage_imx8

CC ?= gcc
REV ?= A0
OEI ?= NO
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
AHAB_IMG ?= mx93$(LC_REVISION)-ahab-container.img
MCU_IMG = m33_image.bin
M7_IMG = m7_image.bin

ifeq ($(SOC),iMX95)
SPL_LOAD_ADDR ?= 0x4aa00000
SPL_LOAD_ADDR_M33_VIEW ?= 0x20480000
ATF_LOAD_ADDR ?= 0x20498000
MCU_TCM_ADDR ?= 0x1FFC0000
MCU_TCM_ADDR_ACORE_VIEW ?= 0x201C0000
else ifeq ($(SOC),iMX91)
SPL_LOAD_ADDR ?= 0x204A0000
ATF_LOAD_ADDR ?= 0x204C0000
MCU_TCM_ADDR ?= 0x1FFE0000
MCU_TCM_ADDR_ACORE_VIEW ?= 0x201E0000
else # iMX93
SPL_LOAD_ADDR ?= 0x2049A000
SPL_LOAD_ADDR_M33_VIEW ?= 0x3049A000
ATF_LOAD_ADDR ?= 0x204E0000
MCU_TCM_ADDR ?= 0x1FFE0000
MCU_TCM_ADDR_ACORE_VIEW ?= 0x201E0000
endif

FCB_LOAD_ADDR ?= $(ATF_LOAD_ADDR)
TEE_LOAD_ADDR ?= 0x96000000
UBOOT_LOAD_ADDR ?= 0x80200000
MCU_XIP_ADDR ?= 0x28032000 # Point entry of m33 in flexspi0 nor flash
M33_IMAGE_XIP_OFFSET ?= 0x31000 # 1st container offset is 0x1000 when boot device is flexspi0 nor flash, actually the m33_image.bin is in 0x31000 + 0x1000 = 0x32000.

M7_TCM_ADDR ?= 0x0
M7_TCM_ADDR_ALIAS ?= 0x303C0000

ifeq ($(OEI),YES)
OEI_IMG ?= oei.bin
OEI_A55_LOAD_ADDR ?= 0x20498000
OEI_A55_ENTR_ADDR ?= $(OEI_A55_LOAD_ADDR)
OEI_M33_LOAD_ADDR ?= 0x1ffc0000
OEI_M33_ENTR_ADDR ?= 0x1ffc0001	# = real entry address (0x1ffc0000) + 1
OEI_OPT_A55 ?= -oei $(OEI_IMG) a55 $(OEI_A55_ENTR_ADDR) $(OEI_A55_LOAD_ADDR)
OEI_OPT_M33 ?= -oei $(OEI_IMG) m33 $(OEI_M33_ENTR_ADDR) $(OEI_M33_LOAD_ADDR)
LPDDR_FW_PREFIX  ?= lpddr5
LPDDR_FW_VERSION ?= _v202210
else
OEI_IMG ?=
OEI_A55_ENTR_ADDR ?=
OEI_A55_LOAD_ADDR ?=
OEI_M33_ENTR_ADDR ?=
OEI_M33_LOAD_ADDR ?=
OEI_OPT_A55 ?=
OEI_OPT_M33 ?=
LPDDR_FW_PREFIX  ?=
LPDDR_FW_VERSION ?=
endif

LPDDR_FW_PREFIX  ?= lpddr4
LPDDR_FW_VERSION ?= _v202201

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

lpddr_imem = $(LPDDR_FW_PREFIX)_imem$(LPDDR_FW_VERSION).bin
lpddr_dmem = $(LPDDR_FW_PREFIX)_dmem$(LPDDR_FW_VERSION).bin

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

oei-ddr.bin: $(OEI_IMG) $(lpddr_imem) $(lpddr_dmem)
	@objcopy -I binary -O binary --pad-to 0x10000 --gap-fill=0x0 $(lpddr_imem) lpddr_pmu_train_imem_pad.bin
	@objcopy -I binary -O binary --pad-to 0x10000 --gap-fill=0x0 $(lpddr_dmem) lpddr_pmu_train_dmem_pad.bin
	@cat lpddr_pmu_train_imem_pad.bin lpddr_pmu_train_dmem_pad.bin > lpddr_pmu_train_fw.bin
	@dd if=$(OEI_IMG) of=oei-pad.bin bs=4 conv=sync
	@cat oei-pad.bin lpddr_pmu_train_fw.bin > oei-ddr.bin
	@rm -f oei-pad.bin lpddr_pmu_train_fw.bin lpddr_pmu_train_imem_pad.bin lpddr_pmu_train_dmem_pad.bin

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
			./$(MKIMG) -soc IMX9 -sw_version $(ROLLBACK_INDEX_IN_CONTAINER)  -c -ap bl31.bin a55 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) -ap tee.bin a55 $(TEE_LOAD_ADDR) -out u-boot-atf-container.img; \
		else \
			./$(MKIMG) -soc IMX9 -c -ap bl31.bin a55 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) -ap tee.bin a55 $(TEE_LOAD_ADDR) -out u-boot-atf-container.img; \
		fi; \
	else \
		./$(MKIMG) -soc IMX9 -c -ap bl31.bin a55 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) -out u-boot-atf-container.img; \
	fi

u-boot-atf-container-spinand.img: bl31.bin u-boot-hash.bin
	if [ -f tee.bin ]; then \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc IMX9 -sw_version $(ROLLBACK_INDEX_IN_CONTAINER)  -dev nand 4K -c -ap bl31.bin a55 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) -ap tee.bin a55 $(TEE_LOAD_ADDR) -out u-boot-atf-container-spinand.img; \
		else \
			./$(MKIMG) -soc IMX9 -dev nand 4K -c -ap bl31.bin a55 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) -ap tee.bin a55 $(TEE_LOAD_ADDR) -out u-boot-atf-container-spinand.img; \
		fi; \
	else \
		./$(MKIMG) -soc IMX9 -dev nand 4K -c -ap bl31.bin a55 $(ATF_LOAD_ADDR) -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) -out u-boot-atf-container-spinand.img; \
	fi

fcb.bin: FORCE
	./$(QSPI_FCB_GEN) $(QSPI_HEADER)

flash_fw.bin: FORCE
	@$(MAKE) --no-print-directory -f soc.mak flash_singleboot
	@mv -f flash.bin $@

.PHONY: clean nightly
clean:
	@rm -f $(MKIMG) u-boot-atf-container.img u-boot-spl-ddr.bin u-boot-spl-ddr-qb.bin u-boot-hash.bin
	@rm -rf extracted_imgs
	@echo "imx9 clean done"

flash_singleboot_no_ahabfw_a55_oei: $(MKIMG) u-boot-atf-container.img oei-ddr.bin u-boot-spl.bin
	./$(MKIMG) -soc IMX9 -c \
		   -oei oei-ddr.bin a55 $(OEI_A55_ENTR_ADDR) $(OEI_A55_LOAD_ADDR) \
		   -ap u-boot-spl.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_lpboot_a55_no_ahabfw: $(MKIMG) $(MCU_IMG) u-boot-atf-container.img u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -ap u-boot-spl.bin a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_lpboot_sm_no_ahabfw: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin

flash_lpboot_sm_m7_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M7_IMG)
	./$(MKIMG) -soc IMX9 -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) -out flash.bin

flash_lpboot_a55_no_ahabfw_m33_oei: $(MKIMG) $(MCU_IMG) u-boot-atf-container.img oei-ddr.bin u-boot-spl.bin
	./$(MKIMG) -soc IMX9 -c \
		   -oei oei-ddr.bin m33 $(OEI_M33_ENTR_ADDR) $(OEI_M33_LOAD_ADDR) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap u-boot-spl.bin a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot: $(MKIMG) $(AHAB_IMG) u-boot-spl-ddr.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c $(OEI_OPT_A55) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_spinand: $(MKIMG) $(AHAB_IMG) u-boot-spl-ddr.bin u-boot-atf-container-spinand.img flash_fw.bin
	./$(MKIMG) -soc IMX9 -dev nand 4K -append $(AHAB_IMG) -c -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x1000 - 1) / 0x1000)); page=4;\
                   echo "append u-boot-atf-container-spinand.img at $$((pad_cnt * page)) KB"; \
                   dd if=u-boot-atf-container-spinand.img of=flash.bin bs=1K seek=$$((pad_cnt * page))

flash_singleboot_spinand_fw: flash_fw.bin
	@mv -f flash_fw.bin flash.bin

flash_singleboot_no_ahabfw: $(MKIMG) u-boot-spl-ddr.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -c $(OEI_OPT_A55) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_qb: $(MKIMG) $(AHAB_IMG) u-boot-spl-ddr-qb.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c -ap u-boot-spl-ddr-qb.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_flexspi: $(MKIMG) $(AHAB_IMG) u-boot-spl-ddr.bin u-boot-atf-container.img fcb.bin
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_A55) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -fcb fcb.bin $(FCB_LOAD_ADDR) -out flash.bin
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;
	$(call append_fcb)

flash_singleboot_m33: $(MKIMG) $(AHAB_IMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c $(OEI_OPT_A55) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_m33_no_ahabfw: $(MKIMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -c $(OEI_OPT_A55) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_m33_flexspi: $(MKIMG) $(AHAB_IMG) $(UPOWER_IMG) u-boot-atf-container.img $(MCU_IMG) u-boot-spl-ddr.bin fcb.bin
	./$(MKIMG) -soc IMX9  -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_A55) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -fcb fcb.bin $(FCB_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \
	$(call append_fcb)

flash_singleboot_all: $(MKIMG) $(AHAB_IMG) u-boot-atf-container.img $(MCU_IMG) $(M7_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c $(OEI_OPT_A55) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_singleboot_all_no_ahabfw: $(MKIMG) u-boot-atf-container.img $(MCU_IMG) $(M7_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -c $(OEI_OPT_A55) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt;

flash_lpboot: $(MKIMG) $(AHAB_IMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin

flash_lpboot_flexspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_flexspi_a55: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_flexspi_xip: $(MKIMG) $(AHAB_IMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -fileoff $(M33_IMAGE_XIP_OFFSET) -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_XIP_ADDR) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_flexspi_no_ahabfw: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -dev flexspi -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_a55: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin

flash_lpboot_all: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M7_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin

flash_lpboot_all_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M7_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin

flash_lpboot_flexspi_a55: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_flexspi_a55_no_ahabfw: $(MKIMG) $(MCU_IMG) u-boot-spl-ddr.bin
	./$(MKIMG) -soc IMX9 -dev flexspi -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -ap u-boot-spl-ddr.bin a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_sentinel: $(MKIMG) ahabfw.bin
	./$(MKIMG) -soc IMX9 -c -sentinel ahabfw.bin -out flash.bin

flash_kernel: $(MKIMG) Image imx93-11x11-evk.dtb
	./$(MKIMG) -soc IMX9 -c -ap Image a55 0x80400000 --data imx93-11x11-evk.dtb a55 0x83000000 -out flash.bin

flash_bootaux_cntr: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -c -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -out flash.bin

flash_bootaux_cntr_xip: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -c -fileoff $(M33_IMAGE_XIP_OFFSET) -m33 $(MCU_IMG) 0 $(MCU_XIP_ADDR) -out flash.bin

parse_container: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -parse flash.bin

extract: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -extract flash.bin

ifneq ($(wildcard ../$(SOC_DIR)/scripts/autobuild.mak),)
$(info include autobuild.mak)
include ../$(SOC_DIR)/scripts/autobuild.mak
endif
