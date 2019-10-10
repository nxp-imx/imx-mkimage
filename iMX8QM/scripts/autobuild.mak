WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net
BUILD ?= Linux_IMX_Regression
#DIR = internal-only/Linux_IMX_Rocko_MX8/$(N)/common_bsp
#DIR = internal-only/Linux_IMX_Core/$(N)/common_bsp
DIR = internal-only/$(BUILD)/$(N)/common_bsp
ARCHIVE_PATH ?= ~
ARCHIVE_NAME ?= $(shell cat nightly.txt).tar

nightly :
	@rm -rf boot
	@echo "Pulling nightly for Validation board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8QM-val > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/$(AHAB_IMG) -O $(AHAB_IMG)
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-val-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-imx8qmlpddr4arm2.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-spl.bin-imx8qmmek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-spl.bin-imx8qmmek-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/m4_image.bin -O m4_image.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/m4_1_image.bin -O m4_1_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR) -P boot -A "fsl-imx8qm-*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

nightly_mek :
	@rm -rf boot
	@echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8QM-mek > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/$(AHAB_IMG) -O $(AHAB_IMG)
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-imx8qmmek.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-spl.bin-imx8qmmek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-spl.bin-imx8qmmek-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/m4_image.bin -O m4_image.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/m4_1_image.bin -O m4_1_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR) -P boot -A "fsl-imx8qm-*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

archive :
	git ls-files --others --exclude-standard -z | xargs -0 tar rvf $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
	bzip2 $(ARCHIVE_PATH)/$(ARCHIVE_NAME)

