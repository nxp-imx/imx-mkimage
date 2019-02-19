WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net

#DIR = internal-only/Linux_IMX_Rocko_MX8/$(N)/common_bsp
DIR = internal-only/Linux_IMX_Core/$(N)/common_bsp
#DIR = internal-only/Linux_IMX_Regression/$(N)/common_bsp

nightly :
	@rm -rf boot
	@echo "Pulling nightly for Validation board from $(SERVER)/$(DIR)"
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-val-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-imx8qmlpddr4arm2.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-ahab-container.img -O mx8qm-ahab-container.img
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR) -P boot -A "Image-*imx8qm*"
	@$(RENAME) "Image-" "" boot/*.dtb

nightly_mek :
	rm -rf boot
	echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-imx8qmmek.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/u-boot-spl.bin-imx8qmmek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qm/mx8qm-ahab-container.img -O mx8qm-ahab-container.img
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR) -P boot -A "Image-*imx8qm*"
	@$(RENAME) "Image-" "" boot/*.dtb
