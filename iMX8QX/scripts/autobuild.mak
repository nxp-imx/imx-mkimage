WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net
#DIR = internal-only/Linux_IMX_Rocko_MX8/$(N)/common_bsp
#DIR = internal-only/Linux_IMX_Core/$(N)/common_bsp
DIR = internal-only/Linux_IMX_Regression/$(N)/common_bsp

nightly :
	@rm -rf boot
	@echo "Pulling nightly for Validation board from $(SERVER)/$(DIR)"
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-ahab-container.img -O mx8qx-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-val-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/bl31-imx8qxp.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/u-boot-imx8qxplpddr4arm2.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/CM4.bin -O u-boot.bin -O CM4.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "Image-fsl-imx8qxp-*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot
	@$(RENAME) "Image-" "" boot/*.dtb

nightly_mek :
	@rm -rf boot
	@echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-ahab-container.img -O mx8qx-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/mx8qx-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/bl31-imx8qxp.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/u-boot-imx8qxpmek.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qx/CM4.bin -O u-boot.bin -O CM4.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "Image-fsl-imx8qxp-*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot
	@$(RENAME) "Image-" "" boot/*.dtb