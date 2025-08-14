MKIMG = ../mkimage_imx8

CC ?= gcc
REV ?= A0
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

ifneq ($(wildcard /usr/bin/rename.ul),)
    RENAME = rename.ul
else
    RENAME = rename
endif

LC_REVISION = $(shell echo $(REV) | tr ABC abc)

AHAB_IMG ?= mx943$(LC_REVISION)-ahab-container.img
SPL_LOAD_ADDR_M33_VIEW ?= 0x20480000 	# For lpboot, SCMI SPL
ATF_LOAD_ADDR ?= 0x8A200000
UBOOT_LOAD_ADDR ?= 0x90200000
MCU_TCM_ADDR ?= 0x1FFC0000		# 256KB TCM
MCU_TCM_ADDR_ACORE_VIEW ?= 0x201C0000
LPDDR_TYPE ?= lpddr5
LPDDR_FUNC ?= train
LPDDR_FW_VERSION ?= _v202409
SPL_A55_IMG ?= u-boot-spl.bin
AP_IMG ?= ap.bin
V2X ?= $(OEI)
KERNEL_DTB ?= imx943-evk.dtb  #Used by kernel authentication
KERNEL_DTB_ADDR ?= 0x93000000
KERNEL_ADDR ?= 0x90400000
KERNEL_INITRD_ADDR ?= 0x93800000

RECOVERY_DTB ?= imx943-evk-crrm.dtb
RECOVERY_IMG ?= Image_crrm.gz
RECOVERY_FS ?= initramfs.cpio.zst.u-boot

FCB_LOAD_ADDR ?= 0x204D7000 #top 4K for fcb
V2X_DDR = 0x8b000000

M70_TCM_ADDR ?= 0x0
M70_TCM_ADDR_ALIAS ?= 0x303C0000
M70_DDR_ADDR ?= 0x80000000

M71_TCM_ADDR ?= 0x0
M71_TCM_ADDR_ALIAS ?= 0x302C0000

M33S_TCM_ADDR ?= 0x1FFC0000
M33S_TCM_ADDR_ALIAS ?= 0x309C0000
M33S_DDR_ADDR ?= 0x86000000

MCU_IMG = m33_image.bin
M70_IMG = m70_image.bin
M71_IMG = m71_image.bin
M33S_IMG = m33s_image.bin
TEE ?= tee.bin
TEE_LOAD_ADDR ?= 0x8C000000
OEI_M33_LOAD_ADDR ?= 0x1ffc0000
OEI_M33_ENTR_ADDR ?= 0x1ffc0001	# = real entry address (0x1ffc0000) + 1

OEI_OPT_M33 ?=
OEI_IMG_M33 ?=

ifeq ($(LPDDR_TYPE),lpddr4)
FW_PRE=lpddr4x
else
FW_PRE=$(LPDDR_TYPE)
endif

lpddr_imem = $(FW_PRE)_imem$(LPDDR_FW_VERSION).bin
lpddr_dmem = $(FW_PRE)_dmem$(LPDDR_FW_VERSION).bin
lpddr_imem_qb = $(FW_PRE)_imem_qb$(LPDDR_FW_VERSION).bin
lpddr_dmem_qb = $(FW_PRE)_dmem_qb$(LPDDR_FW_VERSION).bin

ifeq ($(OEI),YES)
OEI_M33_DDR_IMG ?= oei-m33-ddr.bin

M33_OEI_DDRFW = m33-oei-ddrfw.bin
OEI_QBDATA_FILE = qb_data.bin

ifneq (,$(wildcard $(OEI_QBDATA_FILE)))
OEI_DDR_QB_DATA = $(OEI_QBDATA_FILE)
else
OEI_DDR_QB_DATA =
endif

ifneq (,$(wildcard $(OEI_M33_DDR_IMG)))
OEI_OPT_M33 += -ddr_dummy -oei $(M33_OEI_DDRFW) m33 $(OEI_M33_ENTR_ADDR) $(OEI_M33_LOAD_ADDR)
OEI_OPT_M33 += -hold 65536 $(OEI_DDR_QB_DATA)
OEI_IMG_M33 += $(M33_OEI_DDRFW) $(OEI_DDR_QB_DATA)
endif

ifeq (,$(OEI_IMG_M33))
$(warning "Note: There are no Cortex-M33 oei images")
endif

ifeq ($(V2X),YES)
	V2X_DUMMY = -dummy ${V2X_DDR}
endif

else
ifeq ($(V2X),YES)
$(error "V2X without OEI is not allowed as V2X FW resides in DDR")
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

u-boot-atf-container.img: bl31.bin u-boot-hash.bin
	if [ -f $(TEE) ]; then \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc IMX9 -sw_version $(ROLLBACK_INDEX_IN_CONTAINER) \
				   -cntr_version 2 -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) \
				   -out u-boot-atf-container.img; \
		else \
			./$(MKIMG) -soc IMX9 -cntr_version 2 -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) -out u-boot-atf-container.img; \
		fi; \
	else \
		./$(MKIMG) -soc IMX9 -cntr_version 2 -c \
			   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
			   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
			   -out u-boot-atf-container.img; \
	fi

u-boot-atf-container-spinand.img: bl31.bin u-boot-hash.bin
	if [ -f $(TEE) ]; then \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc IMX9 -sw_version $(ROLLBACK_INDEX_IN_CONTAINER) \
				   -cntr_version 2 -dev nand 4K -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) \
				   -out u-boot-atf-container-spinand.img; \
		else \
			./$(MKIMG) -soc IMX9 -dev nand 4K -cntr_version 2 -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) \
				   -out u-boot-atf-container-spinand.img; \
		fi; \
	else \
		./$(MKIMG) -soc IMX9 -dev nand 4K -cntr_version 2 -c \
			   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
			   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
			   -out u-boot-atf-container-spinand.img; \
	fi

crrm-container.img: bl31.bin u-boot-hash.bin Image.gz $(KERNEL_DTB)
	if [ -f $(TEE) ]; then \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc IMX9 -sw_version $(ROLLBACK_INDEX_IN_CONTAINER) \
				   -cntr_version 2 -u 1 -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) \
				   -ap Image.gz a55 $(KERNEL_ADDR) --data $(KERNEL_DTB) a55 $(KERNEL_DTB_ADDR) \
				   -recovery $(RECOVERY_IMG) a55 $(KERNEL_ADDR) \
				   -recovery $(RECOVERY_DTB) a55 $(KERNEL_DTB_ADDR) \
				   -recovery $(RECOVERY_FS) a55 $(KERNEL_INITRD_ADDR) \
				   -out crrm-container.img; \
		else \
			./$(MKIMG) -soc IMX9 -cntr_version 2 -u 1 -c \
				   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
				   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
				   -ap Image.gz a55 $(KERNEL_ADDR) --data $(KERNEL_DTB) a55 $(KERNEL_DTB_ADDR) \
				   -recovery $(RECOVERY_IMG) a55 $(KERNEL_ADDR) \
				   -recovery $(RECOVERY_DTB) a55 $(KERNEL_DTB_ADDR) \
				   -recovery $(RECOVERY_FS) a55 $(KERNEL_INITRD_ADDR) \
				   -ap $(TEE) a55 $(TEE_LOAD_ADDR) -out crrm-container.img; \
		fi; \
	else \
		./$(MKIMG) -soc IMX9 -cntr_version 2 -u 1 -c \
			   -ap bl31.bin a55 $(ATF_LOAD_ADDR) \
			   -ap u-boot-hash.bin a55 $(UBOOT_LOAD_ADDR) \
			   -ap Image.gz a55 $(KERNEL_ADDR) --data $(KERNEL_DTB) a55 $(KERNEL_DTB_ADDR) \
			   -recovery $(RECOVERY_IMG) a55 $(KERNEL_ADDR) \
			   -recovery $(RECOVERY_DTB) a55 $(KERNEL_DTB_ADDR) \
			   -recovery $(RECOVERY_FS) a55 $(KERNEL_INITRD_ADDR) \
			   -out crrm-container.img; \
	fi

fcb.bin: FORCE
	./$(QSPI_FCB_GEN) $(QSPI_HEADER)

.PHONY: clean nightly
clean:
	@rm -f $(MKIMG) u-boot-atf-container.img u-boot-spl-ddr-v2.bin m33-oei-ddrfw.bin a55-oei-ddrfw.bin u-boot-hash.bin flash.bin head.hash boot-spl-container.img
	@rm -rf extracted_imgs
	@echo "imx94 clean done"

flash_lpboot: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(V2X_DUMMY) -out flash.bin

flash_a55: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33) $(OEI_M33_DDR_IMG)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_a55_xspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) fcb.bin u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33) $(OEI_M33_DDR_IMG)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)
	$(call append_fcb)

flash_a55_xspi_crrm: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) fcb.bin crrm-container.img $(SPL_A55_IMG) $(OEI_IMG_M33) $(OEI_M33_DDR_IMG)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -u 1 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,crrm-container.img,1)
	$(call append_fcb)


## AHAB_IMG shall include both ELE and V2X containers ##
flash_a55_xspi_oem_fastboot: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(SPL_A55_IMG) $(OEI_IMG_M33) fcb.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -cntr_version 2 -cntr_flags 0x30010 -images_hash sha256 \
		   -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)
	$(call append_fcb)

flash_a55_no_ahabfw: $(MKIMG) $(MCU_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_a55_m70_ddr_no_ahabfw: $(MKIMG) $(MCU_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_DDR_ADDR) $(M70_DDR_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_a55_m70_ddr: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_DDR_ADDR) $(M70_DDR_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_a55_no_ahabfw_flexspi: $(MKIMG) $(MCU_IMG) $(SPL_A55_IMG) $(OEI_IMG_M33) fcb.bin u-boot-atf-container.img
	./$(MKIMG) -soc IMX9 -cntr_version 2 -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY)  -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)
	$(call append_fcb)

flash_sm_no_ahabfw: $(MKIMG) $(MCU_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) $(V2X_DUMMY) -out flash.bin

flash_m70: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) -out flash.bin

flash_m70_xspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)

flash_m70_ddr: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_DDR_ADDR) $(M70_DDR_ADDR) -out flash.bin

flash_m70_ddr_xspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_DDR_ADDR) $(M70_DDR_ADDR) -out flash.bin
		   $(call append_fcb)

flash_m70_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) -out flash.bin

flash_m70_no_ahabfw_xspi: $(MKIMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)

flash_m70_ddr_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_DDR_ADDR) $(M70_DDR_ADDR) -out flash.bin

flash_m70_ddr_no_ahabfw_xspi: $(MKIMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_DDR_ADDR) $(M70_DDR_ADDR) -out flash.bin
		   $(call append_fcb)

## AHAB_IMG shall include both ELE and V2X containers ##
flash_m70_ddr_xspi_oem_fastboot: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M70_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -cntr_flags 0x30010 -images_hash sha256 -dev flexspi \
		   -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_DDR_ADDR) $(M70_DDR_ADDR) $(V2X_DUMMY) -out flash.bin
		   $(call append_fcb)

flash_m71: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M71_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin

flash_m71_xspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M71_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)

flash_m71_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M71_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin

flash_m71_no_ahabfw_xspi: $(MKIMG) $(MCU_IMG) $(M71_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)

flash_m70_m71: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M70_IMG) $(M71_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin

flash_m70_m71_xspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M70_IMG) $(M71_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)


flash_m70_m71_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M70_IMG) $(M71_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin

flash_m70_m71_no_ahabfw_xspi: $(MKIMG) $(MCU_IMG) $(M70_IMG) $(M71_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)

flash_m33s: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) -out flash.bin

flash_m33s_ddr: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_DDR_ADDR) $(M33S_DDR_ADDR) -out flash.bin

flash_m33s_xspi: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)

flash_m33s_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M33S_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) -out flash.bin

flash_m33s_no_ahabfw_xspi: $(MKIMG) $(MCU_IMG) $(M33S_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)

flash_m33s_m71_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M33S_IMG) $(M71_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 0 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin

flash_m33s_m71_no_ahabfw_xspi: $(MKIMG) $(MCU_IMG) $(M33S_IMG) $(M71_IMG) $(OEI_IMG_M33) fcb.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -dev flexspi -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m7 $(M33S_IMG) 0 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin
		   $(call append_fcb)

flash_m33s_m70: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(M70_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) -out flash.bin

flash_m33s_m70_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M33S_IMG) $(M70_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS) -out flash.bin

flash_m33s_m71: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(M71_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin

flash_m33s_m70_m71: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(M70_IMG) $(M71_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS)  \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin

flash_m33s_m70_m71_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M33S_IMG) $(M70_IMG) $(M71_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS)  \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) -out flash.bin

flash_all: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(M70_IMG) $(M71_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS)  \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_all_no_ahabfw: $(MKIMG) $(MCU_IMG) $(M33S_IMG) $(M70_IMG) $(M71_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS)  \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

flash_all_ap: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(M70_IMG) $(M71_IMG) $(AP_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS)  \
		   -m7 $(M71_IMG) 1 $(M71_TCM_ADDR) $(M71_TCM_ADDR_ALIAS) \
		   -ap $(AP_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin

flash_kernel: $(MKIMG) Image $(KERNEL_DTB)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -c -ap Image a55 $(KERNEL_ADDR) \
		   --data $(KERNEL_DTB) a55 $(KERNEL_DTB_ADDR) -out flash.bin

#no M71 for jailhouse, inmate linux uses LPUART12
flash_jailhouse: $(MKIMG) $(AHAB_IMG) $(MCU_IMG) $(M33S_IMG) $(M70_IMG) u-boot-atf-container.img $(SPL_A55_IMG) $(OEI_IMG_M33)
	./$(MKIMG) -soc IMX9 -cntr_version 2 -append $(AHAB_IMG) -c $(OEI_OPT_M33) -msel $(MSEL) \
		   -m33 $(MCU_IMG) 0 $(MCU_TCM_ADDR) \
		   -m33 $(M33S_IMG) 1 $(M33S_TCM_ADDR) $(M33S_TCM_ADDR_ALIAS) \
		   -m7 $(M70_IMG) 0 $(M70_TCM_ADDR) $(M70_TCM_ADDR_ALIAS)  \
		   -ap $(SPL_A55_IMG) a55 $(SPL_LOAD_ADDR_M33_VIEW) $(V2X_DUMMY) -out flash.bin
	$(call append_container,u-boot-atf-container.img,1)

parse_container: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -parse flash.bin

extract: $(MKIMG) flash.bin
	./$(MKIMG) -soc IMX9 -cntr_version 2 -extract flash.bin

ifneq ($(wildcard ../$(SOC_DIR)/scripts/autobuild.mak),)
$(info include autobuild.mak)
include ../$(SOC_DIR)/scripts/autobuild.mak
endif
