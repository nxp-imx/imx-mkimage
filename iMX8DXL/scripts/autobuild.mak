WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net
BUILD ?= Linux_IMX_Full
#DIR = internal-only/Linux_IMX_Rocko_MX8/$(N)/common_bsp
#DIR = internal-only/Linux_IMX_Core/$(N)/common_bsp
DIR = internal-only/$(BUILD)/$(N)/common_bsp
ARCHIVE_PATH ?= ~
ARCHIVE_NAME ?= $(shell cat nightly.txt).tar

nightly : nightly_mek

nightly_evk : nightly_mek

nightly_mek :
	@rm -rf boot
	@echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8DXL-evk > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlevk/mx8dxla0-ahab-container.img -O mx8dxla0-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlevk/mx8dxl-evk-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlevk/bl31-imx8dxl.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlevk/u-boot-imx8dxlevk.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlevk/u-boot-spl.bin-imx8dxlevk-sd -O u-boot-spl.bin
#	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlevk/u-boot-spl.bin-imx8dxlevk-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlevk/m4_image.bin -O m4_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8dxl-evk*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

archive :
	git ls-files --others --exclude-standard -z | xargs -0 tar rvf $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
	bzip2 $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
