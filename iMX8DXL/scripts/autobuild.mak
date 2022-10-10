WGET = /usr/bin/wget
N ?= latest
ROOTDIR ?= repository/IMX-raw_Linux_Internal_Daily_Build
BUILD ?= Linux_IMX_Full
#DIR = $(ROOTDIR)/Linux_IMX_Rocko_MX8/$(N)/common_bsp
#DIR = $(ROOTDIR)/Linux_IMX_Core/$(N)/common_bsp
DIR = $(ROOTDIR)/$(BUILD)/$(N)/common_bsp
ARCHIVE_PATH ?= ~
ARCHIVE_NAME ?= $(shell cat nightly.txt).tar

ifeq (,$(findstring nxrm,$(SERVER)))
ROOTDIR := internal-only
RWGET = /usr/bin/wget -qr -nd -l1 -np
else
ifneq ($(shell test -e ~/.netrc && echo -n yes),yes)
$(warning No ~/.netrc found!)
endif
ifeq ($(N),latest)
override N := $(shell $(WGET) -q --output-document - $(SERVER)/$(ROOTDIR)/$(BUILD)/latest)
endif
RWGET = echo Skipping
endif

ifeq ($(V),1)
AT :=
else
AT := @
endif

nightly : nightly_evk
nightly_mek : nightly_evk

nightly_evk:
	$(AT)rm -rf boot
	$(AT)echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	$(AT)echo $(BUILD)-$(N)-iMX8DXL-$(LC_REVISION)-evk > nightly.txt
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/$(SECO_FW_NAME) -O $(SECO_FW_NAME)
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/mx8dxl-evk-scfw-tcm.bin -O scfw_tcm.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/bl31-imx8dxl.bin -O bl31.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/u-boot-imx8dxl$(LC_REVISION)-lpddr4-evk.bin-sd -O u-boot.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/u-boot-imx8dxl$(LC_REVISION)-lpddr4-evk.bin-fspi -O u-boot-fspi.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/m4_image.bin -O m4_image.bin
	$(AT)$(RWGET) $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8dxl-evk*.dtb"
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	$(AT)mv -f Image boot

nightly_a1evk: override REV = a1
nightly_a1mek : nightly_a1evk
nightly_a1evk: nightly_evk

nightly_b0evk: override REV = b0
nightly_b0mek : nightly_b0evk
nightly_b0evk: nightly_evk
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/bl31-imx8dxl.bin-optee -O bl31-optee.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/u-boot-spl.bin-imx8dxl$(LC_REVISION)-lpddr4-evk-sd -O u-boot-spl.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/u-boot-spl.bin-imx8dxl$(LC_REVISION)-lpddr4-evk-fspi -O u-boot-spl-fspi.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-lpddr4-evk/tee.bin -O tee.bin

nightly_ddr3_evk:
	$(AT)rm -rf boot
	$(AT)echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	$(AT)echo $(BUILD)-$(N)-iMX8DXL-ddr3-$(LC_REVISION)-evk > nightly.txt
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/$(SECO_FW_NAME) -O $(SECO_FW_NAME)
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/mx8dxl-ddr3-evk-scfw-tcm.bin -O scfw_tcm.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/bl31-imx8dxl.bin -O bl31.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/u-boot-imx8dxl$(LC_REVISION)-ddr3l-evk.bin-sd -O u-boot.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/u-boot-imx8dxl$(LC_REVISION)-ddr3l-evk.bin-nand -O u-boot-nand.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/m4_image.bin -O m4_image.bin
	$(AT)$(RWGET) $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8dxl-ddr3*.dtb"
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	$(AT)mv -f Image boot

nightly_ddr3_a1evk: override REV = a1
nightly_ddr3_a1evk: nightly_ddr3_evk

nightly_ddr3_b0evk: override REV = b0
nightly_ddr3_b0evk: nightly_ddr3_evk
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/bl31-imx8dxl.bin-optee -O bl31-optee.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/u-boot-spl.bin-imx8dxl$(LC_REVISION)-ddr3l-evk-sd -O u-boot-spl.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/u-boot-spl.bin-imx8dxl$(LC_REVISION)-ddr3l-evk-nand -O u-boot-spl-nand.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-ddr3l-evk/tee.bin -O tee.bin

archive :
	git ls-files --others --exclude-standard -z | xargs -0 tar rvf $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
	bzip2 $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
