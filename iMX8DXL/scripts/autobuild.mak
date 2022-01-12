WGET = /usr/bin/wget
N ?= latest
SERVER ?= http://yb2.am.freescale.net
BUILD ?= Linux_IMX_Full
#DIR = internal-only/Linux_IMX_Rocko_MX8/$(N)/common_bsp
#DIR = internal-only/Linux_IMX_Core/$(N)/common_bsp
DIR = internal-only/$(BUILD)/$(N)/common_bsp
ARCHIVE_PATH ?= ~
ARCHIVE_NAME ?= $(shell cat nightly.txt).tar

ifeq ($(V),1)
AT :=
else
AT := @
endif

nightly : nightly_a1_evk
nightly_evk : nightly_a1_evk
nightly_mek : nightly_a1_evk

nightly_a1_evk:
	$(AT)rm -rf boot
	$(AT)echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	$(AT)echo $(BUILD)-$(N)-iMX8DXL-$(LC_REVISION)-evk > nightly.txt
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/$(SECO_FW_NAME) -O $(SECO_FW_NAME)
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/mx8dxl-evk-scfw-tcm.bin -O scfw_tcm.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/bl31-imx8dxl.bin -O bl31.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/u-boot-imx8dxl$(LC_REVISION)evk.bin-sd -O u-boot.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/u-boot-imx8dxl$(LC_REVISION)evk.bin-fspi -O u-boot-fspi.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/m4_image.bin -O m4_image.bin
	$(AT)$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8dxl-evk*.dtb"
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	$(AT)mv -f Image boot

nightly_b0_evk: nightly_a1_evk
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/bl31-imx8dxl.bin-optee -O bl31-optee.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/u-boot-spl.bin-imx8dxl$(LC_REVISION)evk-sd -O u-boot-spl.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/u-boot-spl.bin-imx8dxl$(LC_REVISION)evk-fspi -O u-boot-spl-fspi.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)evk/tee.bin -O tee.bin

nightly_ddr3_a1_evk:
	$(AT)rm -rf boot
	$(AT)echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	$(AT)echo $(BUILD)-$(N)-iMX8DXL-ddr3-$(LC_REVISION)-evk > nightly.txt
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/$(SECO_FW_NAME) -O $(SECO_FW_NAME)
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/mx8dxl-ddr3-scfw-tcm.bin -O scfw_tcm.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/bl31-imx8dxl.bin -O bl31.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/u-boot-imx8dxl$(LC_REVISION)ddr3evk.bin-sd -O u-boot.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/u-boot-imx8dxl$(LC_REVISION)ddr3evk.bin-nand -O u-boot-nand.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/m4_image.bin -O m4_image.bin
	$(AT)$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8dxl-ddr3*.dtb"
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	$(AT)mv -f Image boot

nightly_ddr3_b0_evk: nightly_ddr3_a1_evk
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/bl31-imx8dxl.bin-optee -O bl31-optee.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/u-boot-spl.bin-imx8dxl$(LC_REVISION)ddr3evk-sd -O u-boot-spl.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/u-boot-spl.bin-imx8dxl$(LC_REVISION)ddr3evk-nand -O u-boot-spl-nand.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)ddr3evk/tee.bin -O tee.bin

archive :
	git ls-files --others --exclude-standard -z | xargs -0 tar rvf $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
	bzip2 $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
