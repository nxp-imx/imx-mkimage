MKIMG = ../mkimage_imx8

CC ?= gcc
REV ?= B0
OEI ?= NO
MSEL ?= 0
CFLAGS ?= -O2 -Wall -std=c99
INCLUDE = ./lib

#define the F(Q)SPI header file
ifneq ($(wildcard ./scripts/fspi_header_200),)
	QSPI_HEADER ?= ./scripts/fspi_header_200
else
	QSPI_HEADER = ../scripts/fspi_header
endif

QSPI_PACKER = ../scripts/fspi_packer.sh
QSPI_FCB_GEN = ../scripts/fspi_fcb_gen.sh
PAD_IMAGE = ../scripts/pad_image.sh
SPLIT_KERNEL = ../scripts/split_kernel.sh

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

LC_REVISION = $(shell echo $(REV) | tr ABC abc)

ifeq ($(LC_REVISION),a0)
LC_REVISION := a1
endif

ifeq ($(LC_REVISION),a1)
ELE_REVISION := a0
else
ELE_REVISION := $(LC_REVISION)
endif

AHAB_IMG = mx95$(ELE_REVISION)-ahab-container.img
SPL_LOAD_ADDR ?= 0x4aa00000		# For singleboot, non-SCMI SPL, use NPU SRAM
SPL_LOAD_ADDR_M33_VIEW ?= 0x20480000 	# For lpboot, SCMI SPL
ATF_LOAD_ADDR ?= 0x8A200000
UBOOT_LOAD_ADDR ?= 0x90200000
MCU_TCM_ADDR ?= 0x1FFC0000		# 256KB TCM
MCU_TCM_ADDR_ACORE_VIEW ?= 0x201C0000
LPDDR_TYPE ?= lpddr5
LPDDR_FUNC ?= train
LPDDR_FW_VERSION ?= _v202409
SPL_A55_IMG ?= u-boot-spl.bin	# SPL without ddrfw
AP_IMG ?= ap.bin
KERNEL_DTB ?= imx95-19x19-evk.dtb   # Used by kernel authentication
KERNEL_DTB_ADDR ?= 0x93000000
KERNEL_ADDR ?= 0x90400000
V2X ?= $(OEI)
# This Capsule_GUID is reserved by NXP
CAPSULE_GUID ?= 2c4db6b3-0b15-4a36-beae-1ea135464f5b

FCB_LOAD_ADDR ?= 0x204D7000 #top 4K for fcb
V2X_DDR = 0x8b000000
MCU_IMG ?= m33_image.bin
M7_IMG ?= m7_image.bin
TEE ?= tee.bin
TEE_LOAD_ADDR ?= 0x8C000000
MCU_XIP_ADDR ?= 0x28032000 # Point entry of m33 in flexspi0 nor flash
M33_IMAGE_XIP_OFFSET ?= 0x31000 # 1st container offset is 0x1000 when boot device is flexspi0 nor
				# flash, actually the m33_image.bin is in 0x31000 + 0x1000 = 0x32000.
M7_TCM_ADDR ?= 0x0
M7_TCM_ADDR_ALIAS ?= 0x303C0000
M7_DDR_ADDR ?= 0x80000000
M7_XIP_ADDR ?= 0x28132000 # Point entry of m7 in flexspi0 nor flash
M7_XIP_ADDR_ALIAS ?= 0x38132000 # Point entry of m7 in flexspi0 nor flash
M7_IMAGE_XIP_OFFSET ?= 0x131000 # 1st container offset is 0x1000 when boot device is flexspi0 nor
				# flash, actually the m7_image.bin is in 0x131000 + 0x1000 = 0x132000.

ifeq ($(LC_REVISION),b0)
CTNR_VERSION ?= 2 # For i.MX95 B0
DDR_DUMMY = -ddr_dummy
else
CTNR_VERSION ?= 0
DDR_DUMMY =
endif

FAST_HASH ?=
ifeq ($(FAST_HASH),YES)
MMC_FAST_HASH = -cntr_flags 0x20010
XSPI_FAST_HASH = -cntr_flags 0x30010
else
MMC_FAST_HASH = 
XSPI_FAST_HASH = 
endif

OEI_A55_LOAD_ADDR ?= 0x20498000
OEI_A55_ENTR_ADDR ?= $(OEI_A55_LOAD_ADDR)
OEI_M33_LOAD_ADDR ?= 0x1ffc0000
OEI_M33_ENTR_ADDR ?= 0x1ffc0001	# = real entry address (0x1ffc0000) + 1

OEI_OPT_A55 ?=
OEI_OPT_M33 ?=

OEI_IMG_A55 ?=
OEI_IMG_M33 ?=

lpddr_imem = $(LPDDR_TYPE)_imem$(LPDDR_FW_VERSION).bin
lpddr_dmem = $(LPDDR_TYPE)_dmem$(LPDDR_FW_VERSION).bin
lpddr_imem_qb = $(LPDDR_TYPE)_imem_qb$(LPDDR_FW_VERSION).bin
lpddr_dmem_qb = $(LPDDR_TYPE)_dmem_qb$(LPDDR_FW_VERSION).bin

ifeq ($(OEI),YES)
OEI_A55_DDR_IMG ?= oei-a55-ddr.bin
OEI_M33_DDR_IMG ?= oei-m33-ddr.bin
OEI_A55_TCM_IMG ?= oei-a55-tcm.bin
OEI_M33_TCM_IMG ?= oei-m33-tcm.bin

A55_OEI_DDRFW = a55-oei-ddrfw.bin
M33_OEI_DDRFW = m33-oei-ddrfw.bin
OEI_QBDATA_FILE = qb_data.bin

ifneq (,$(wildcard $(OEI_QBDATA_FILE)))
OEI_DDR_QB_DATA = $(OEI_QBDATA_FILE)
else
OEI_DDR_QB_DATA =
endif

ifneq (,$(wildcard $(OEI_A55_DDR_IMG)))
OEI_OPT_A55 += -oei $(A55_OEI_DDRFW) a55 $(OEI_A55_ENTR_ADDR) $(OEI_A55_LOAD_ADDR)
OEI_OPT_A55 += -hold 65536 $(OEI_DDR_QB_DATA)
OEI_IMG_A55 += $(A55_OEI_DDRFW) $(OEI_DDR_QB_DATA)
endif
ifneq (,$(wildcard $(OEI_M33_DDR_IMG)))
OEI_OPT_M33 += $(DDR_DUMMY) -oei $(M33_OEI_DDRFW) m33 $(OEI_M33_ENTR_ADDR) $(OEI_M33_LOAD_ADDR)
OEI_OPT_M33 += -hold 65536 $(OEI_DDR_QB_DATA)
OEI_IMG_M33 += $(M33_OEI_DDRFW) $(OEI_DDR_QB_DATA)
endif

ifneq ($(LC_REVISION),b0) # No need to include M7 TCM init OEI for B0
ifneq (,$(wildcard $(OEI_A55_TCM_IMG)))
OEI_OPT_A55 += -oei $(OEI_A55_TCM_IMG) a55 $(OEI_A55_ENTR_ADDR) $(OEI_A55_LOAD_ADDR)
OEI_IMG_A55 += $(OEI_A55_TCM_IMG)
endif
ifneq (,$(wildcard $(OEI_M33_TCM_IMG)))
OEI_OPT_M33 += -oei $(OEI_M33_TCM_IMG) m33 $(OEI_M33_ENTR_ADDR) $(OEI_M33_LOAD_ADDR)
OEI_IMG_M33 += $(OEI_M33_TCM_IMG)
endif
endif # No need to include M7 TCM init OEI for B0

ifeq (,$(OEI_IMG_M33))
$(warning "Note: There are no Cortex-M33 oei images")
endif

ifeq (,$(OEI_IMG_A55))
$(warning "Note: There are no Cortex-A55 oei images")
endif

ifeq ($(V2X),YES)
	V2X_DUMMY = -dummy ${V2X_DDR}
endif

else
ifeq ($(V2X),YES)
$(error "V2X without OEI is not allowed as V2X FW resides in DDR")
endif
ifneq ($(LC_REVISION),b0)
V2X_DUMMY_NPUSRAM = 0x4AA00000
V2X_DUMMY = -dummy ${V2X_DUMMY_NPUSRAM}
#A0/A1 needs M7 OEI even in OEI=NO case when trying to load M7 TCM image
OEI_M33_TCM_IMG ?= oei-m33-tcm.bin
OEI_OPT_M33 += -oei $(OEI_M33_TCM_IMG) m33 $(OEI_M33_ENTR_ADDR) $(OEI_M33_LOAD_ADDR)
OEI_IMG_M33 += $(OEI_M33_TCM_IMG)
endif

endif

###########################
# Append container macro
#
# $(1) - container to append, usually: u-boot-atf-container.img
# $(2) - the page at which the container must be append, usually: 1
###########################
define append_container
	@cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   psize=$$((0x400 * $(2))); \
                   pad_cnt=$$(((flashbin_size + psize - 1) / psize)); \
                   echo "append $(1) at $$((pad_cnt * $(2))) KB, psize=$$psize"; \
                   dd if=$(1) of=flash.bin bs=1K seek=$$((pad_cnt * $(2)));
endef

define append_fcb
	@mv flash.bin flash.tmp
	@dd if=fcb.bin of=flash.bin bs=1k seek=1
	@dd if=flash.tmp of=flash.bin bs=1k seek=4
	@rm flash.tmp
	@echo "Append FCB to flash.bin"
endef

FORCE:

fw-header.bin: $(lpddr_imem) $(lpddr_dmem)
	@imem_size=`wc -c $(lpddr_imem) | awk '{printf "%.8x", $$1}' | sed -e 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/'`; \
		echo $$imem_size | xxd -r -p >  fw-header.bin
	@dmem_size=`wc -c $(lpddr_dmem) | awk '{printf "%.8x", $$1}' | sed -e 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/'`; \
		echo $$dmem_size | xxd -r -p >> fw-header.bin

fw-header-qb.bin: $(lpddr_imem_qb) $(lpddr_dmem_qb)
	@imem_size=`wc -c $(lpddr_imem_qb) | awk '{printf "%.8x", $$1}' | sed -e 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/'`; \
		echo $$imem_size | xxd -r -p >  fw-header-qb.bin
	@dmem_size=`wc -c $(lpddr_dmem_qb) | awk '{printf "%.8x", $$1}' | sed -e 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/'`; \
		echo $$dmem_size | xxd -r -p >> fw-header-qb.bin

define append_ddrfw_v2
	@dd if=$(1) of=$(1)-pad bs=4 conv=sync
	@cat $(1)-pad fw-header.bin $(lpddr_imem) $(lpddr_dmem) $(3) > $(2).unaligned
	@dd if=$(2).unaligned of=$(2) bs=8 conv=sync
	@rm -f $(1)-pad $(2).unaligned fw-header.bin
endef

define append_ddrfw_v3
	@dd if=$(1) of=$(1)-pad bs=4 conv=sync
	@cat $(1)-pad fw-header.bin $(lpddr_imem) $(lpddr_dmem) fw-header-qb.bin $(lpddr_imem_qb) $(lpddr_dmem_qb) > $(2).unaligned
	@dd if=$(2).unaligned of=$(2) bs=8 conv=sync
	@rm -f $(1)-pad $(2).unaligned fw-header.bin fw-header-qb.bin
endef

a55-oei-ddrfw.bin: $(OEI_A55_DDR_IMG) $(lpddr_imem) $(lpddr_dmem) fw-header.bin $(lpddr_imem_qb) $(lpddr_dmem_qb) fw-header-qb.bin
	$(call append_ddrfw_v3,$(OEI_A55_DDR_IMG),a55-oei-ddrfw.bin)

m33-oei-ddrfw.bin: $(OEI_M33_DDR_IMG) $(lpddr_imem) $(lpddr_dmem) fw-header.bin $(lpddr_imem_qb) $(lpddr_dmem_qb) fw-header-qb.bin
	@echo "DDR FW - $(lpddr_imem) $(lpddr_dmem) $(lpddr_imem_qb) $(lpddr_dmem_qb)"
	$(call append_ddrfw_v3,$(OEI_M33_DDR_IMG),m33-oei-ddrfw.bin)

u-boot-spl-ddr-v2.bin: u-boot-spl.bin $(lpddr_imem) $(lpddr_dmem) fw-header.bin
	$(call append_ddrfw_v2,u-boot-spl.bin,u-boot-spl-ddr-v2.bin)

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
	if [ -f $(TEE) ]; then \
		if [ $(shell echo $(TEE_COMPRESS_ENABLE)) ]; then \
			echo "Start compress $(TEE)"; \
			lz4 -9 -f --rm $(TEE) $(TEE).lz4; \
			cp $(TEE).lz4 $(TEE); \
		fi; \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -sw_version $(ROLLBACK_INDEX_IN_CONTAINER) -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) \
				   -out u-boot-atf-container.img; \
		else \
			./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) -out u-boot-atf-container.img; \
		fi; \
	else \
		./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c \
			   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
			   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
			   -out u-boot-atf-container.img; \
	fi

u-boot-atf-container-spinand.img: bl31.bin u-boot-hash.bin
	if [ -f $(TEE) ]; then \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -sw_version $(ROLLBACK_INDEX_IN_CONTAINER) \
				   -dev nand 4K -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) \
				   -out u-boot-atf-container-spinand.img; \
		else \
			./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -dev nand 4K -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) \
				   -out u-boot-atf-container-spinand.img; \
		fi; \
	else \
		./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -dev nand 4K -c \
			   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
			   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
			   -out u-boot-atf-container-spinand.img; \
	fi

fcb.bin: FORCE
	./$(QSPI_FCB_GEN) $(QSPI_HEADER)

flash_fw.bin: FORCE
	@$(MAKE) --no-print-directory -f soc.mak flash_singleboot
	@mv -f flash.bin $@

.PHONY: clean nightly
clean:
	@rm -f $(MKIMG) u-boot-atf-container.img u-boot-spl-ddr-v2.bin m33-oei-ddrfw.bin a55-oei-ddrfw.bin u-boot-hash.bin flash.bin head.hash boot-spl-container.img
	@rm -rf extracted_imgs
	@echo "imx95 clean done"

# Add for System ready
ifeq ($(TEE),tee.bin-stmm)
overlay: u-boot.bin
	./$(MKIMG) -soc IMX9 -split u-boot.bin
	dtc -@ -I dts -O dtb -o signature.dtbo signature.dts
	fdtoverlay -i gen-uboot.dtb -o gen-uboot.dtb signature.dtbo
	@cat gen-u-boot-nodtb.bin gen-uboot.dtb > gen-u-boot.bin
	@mv -f gen-u-boot.bin u-boot.bin

flash_lpboot_sm_all_stmm_capsule: overlay flash_lpboot_sm_all
	./mkeficapsule flash.bin --monotonic-count 1 \
		--guid $(CAPSULE_GUID) \
		--private-key CRT.key \
		--certificate CRT.crt \
		--index 1 --instance 0 \
		capsule1.bin
endif

flash_lpboot: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -append $(AHAB_IMG) -c $(OEI_OPT_M33) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(V2X_DUMMY) -out flash.bin

flash_lpboot_no_ahabfw: $(MKIMG) $(MCU_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -c $(OEI_OPT_M33) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin

flash_lpboot_flexspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(XSPI_FAST_HASH) -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_M33) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(V2X_DUMMY) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_flexspi_no_ahabfw: $(MKIMG) $(MCU_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(XSPI_FAST_HASH) -dev flexspi -c $(OEI_OPT_M33) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_lpboot_flexspi_xip: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(XSPI_FAST_HASH) -dev flexspi -append $(AHAB_IMG) -fileoff $(M33_IMAGE_XIP_OFFSET) \
		   -c $(OEI_OPT_M33) -m33 $(MCU_IMG) 0 $(MCU_XIP_ADDR) $(V2X_DUMMY) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_a55: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33) $(OEI_M33_DDR_IMG)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_a55_no_ahabfw: $(MKIMG) $(MCU_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_a55_flexspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(SPL_A55_IMG) $(OEI_IMG_M33) fcb.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(XSPI_FAST_HASH) -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -fcb fcb.bin $(FCB_LOAD_ADDR) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)
	$(call append_fcb)

flash_m7_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M7_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) -out flash.bin

flash_m7: $(MKIMG) $(MCU_IMG) $(M7_IMG) $(AHAB_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) $(V2X_DUMMY) -out flash.bin

flash_m7_flexspi_xip: $(MKIMG) $(MCU_IMG) $(M7_IMG) $(AHAB_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(XSPI_FAST_HASH) -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) -fcb fcb.bin $(FCB_LOAD_ADDR)\
		   -fileoff $(M7_IMAGE_XIP_OFFSET)\
		   -m7 $(M7_IMG) 0 $(M7_XIP_ADDR) $(M7_XIP_ADDR_ALIAS) $(V2X_DUMMY)\
		   -out flash.bin
	$(call append_fcb)

# The diff with "flash_m7_no_ahabfw" is M7_TCM_ADDR vs M7_DDR_ADDR in -m7 option
flash_m7_ddr_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M7_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_DDR_ADDR) $(M7_DDR_ADDR) -out flash.bin

# The diff with "flash_m7" is M7_TCM_ADDR vs M7_DDR_ADDR in -m7 option
flash_m7_ddr: $(MKIMG) $(MCU_IMG) $(M7_IMG) $(OEI_IMG_M33) $(AHAB_IMG)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) \
		   -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_DDR_ADDR) $(M7_DDR_ADDR) $(V2X_DUMMY) -out flash.bin

flash_all: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M7_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS)  \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_all_ddr: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M7_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_DDR_ADDR) $(M7_DDR_ADDR)  \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_all_ddr_flexspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M7_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(XSPI_FAST_HASH) -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_DDR_ADDR) $(M7_DDR_ADDR)  \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) \
		   -fcb fcb.bin $(FCB_LOAD_ADDR) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)
	$(call append_fcb)

flash_all_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M7_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS)  \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_all_ap: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M7_IMG) $(AP_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS)  \
		   -ap $(AP_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin

flash_ele: $(MKIMG) ahabfw.bin
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) $(MMC_FAST_HASH) -c -ele ahabfw.bin -out flash.bin

ifneq ($(LC_REVISION),b0)
prepare_kernel_chunks: Image
	./$(SPLIT_KERNEL) Image $(KERNEL_ADDR) 0x700000

flash_kernel: $(MKIMG) prepare_kernel_chunks $(KERNEL_DTB)
	KERNEL_CMD="$(shell cat Image_cmd)"; \
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c $$KERNEL_CMD --data $(KERNEL_DTB) a55 $(KERNEL_DTB_ADDR) -out flash.bin
else
flash_kernel: $(MKIMG) Image $(KERNEL_DTB)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c -ap Image a55 $(KERNEL_ADDR) --data $(KERNEL_DTB) a55 $(KERNEL_DTB_ADDR) -out flash.bin
endif

flash_bootaux_cntr: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) -out flash.bin

flash_bootaux_cntr_xip: $(MKIMG) $(MCU_IMG)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c -fileoff $(M33_IMAGE_XIP_OFFSET) -m33 $(MCU_IMG) 0 $(MCU_XIP_ADDR) -out flash.bin

parse_container: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -parse flash.bin

extract: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -extract flash.bin

flash_lpboot_sm_a55: flash_a55
flash_lpboot_sm_a55_no_ahabfw: flash_a55_no_ahabfw
flash_lpboot_sm_a55_flexspi: flash_a55_flexspi
flash_lpboot_sm_m7_no_ahabfw: flash_m7_no_ahabfw
flash_lpboot_sm_m7: flash_m7
flash_lpboot_sm_m7_flexspi_xip: flash_m7_flexspi_xip
flash_lpboot_sm_m7_ddr_no_ahabfw: flash_m7_ddr_no_ahabfw
flash_lpboot_sm_m7_ddr: flash_m7_ddr
flash_lpboot_sm_all: flash_all
flash_lpboot_sm_all_no_ahabfw: flash_all_no_ahabfw
flash_lpboot_sm: flash_lpboot
flash_lpboot_sm_no_ahabfw: flash_lpboot_no_ahabfw
#MSEL=1 for mx95alt
flash_alt: flash_a55
flash_jailhouse: flash_a55
flash_netc: flash_lpboot_sm_all
flash_evk: flash_lpboot_sm_all

flash_singleboot: $(MKIMG) $(AHAB_IMG) $(SPL_A55_IMG) u-boot-atf-container.img $(OEI_IMG_A55)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -append $(AHAB_IMG) -c $(OEI_OPT_A55) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_singleboot_no_ahabfw: $(MKIMG) $(SPL_A55_IMG) u-boot-atf-container.img $(OEI_IMG_A55)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c $(OEI_OPT_A55) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_singleboot_spinand: $(MKIMG) $(AHAB_IMG) $(SPL_A55_IMG) u-boot-atf-container-spinand.img $(OEI_IMG_A55) flash_fw.bin
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -dev nand 4K -append $(AHAB_IMG) -c $(OEI_OPT_A55) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container-spinand.img,4)

flash_singleboot_spinand_fw: flash_fw.bin
	@mv -f flash_fw.bin flash.bin

flash_singleboot_flexspi: $(MKIMG) $(AHAB_IMG) $(OEI_IMG_A55) $(SPL_A55_IMG) u-boot-atf-container.img fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_A55) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) $(V2X_DUMMY) \
		   -fcb fcb.bin $(FCB_LOAD_ADDR) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)
	$(call append_fcb)

flash_singleboot_m33: $(MKIMG) $(AHAB_IMG) u-boot-atf-container.img $(MCU_IMG) $(SPL_A55_IMG) $(OEI_IMG_A55)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -append $(AHAB_IMG) -c $(OEI_OPT_A55) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_singleboot_m33_no_ahabfw: $(MKIMG) u-boot-atf-container.img $(MCU_IMG) $(SPL_A55_IMG) $(OEI_IMG_A55)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c $(OEI_OPT_A55) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_singleboot_m33_flexspi: $(MKIMG) $(AHAB_IMG) $(UPOWER_IMG) u-boot-atf-container.img $(MCU_IMG) $(SPL_A55_IMG) $(OEI_IMG_A55) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -dev flexspi -append $(AHAB_IMG) -c $(OEI_OPT_A55) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) $(V2X_DUMMY) \
		   -fcb fcb.bin $(FCB_LOAD_ADDR) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)
	$(call append_fcb)

flash_singleboot_all: $(MKIMG) $(AHAB_IMG) u-boot-atf-container.img $(MCU_IMG) $(M7_IMG) $(SPL_A55_IMG) $(OEI_IMG_A55)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -append $(AHAB_IMG) -c $(OEI_OPT_A55) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) \
		   -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_singleboot_all_no_ahabfw: $(MKIMG) u-boot-atf-container.img $(MCU_IMG) $(M7_IMG) $(SPL_A55_IMG) $(OEI_IMG_A55)
	./$(MKIMG) -soc IMX9 -cntr_version $(CTNR_VERSION) -c $(OEI_OPT_A55) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(MCU_TCM_ADDR_ACORE_VIEW) \
		   -m7 $(M7_IMG) 0 $(M7_TCM_ADDR) $(M7_TCM_ADDR_ALIAS) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

ifneq ($(wildcard ../$(SOC_DIR)/scripts/autobuild.mak),)
$(info include autobuild.mak)
include ../$(SOC_DIR)/scripts/autobuild.mak
endif
