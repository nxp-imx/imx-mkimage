WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net
BUILD ?= Linux_IMX_Full
#DIR = internal-only/Linux_IMX_Rocko_MX8/$(N)/common_bsp
#DIR = internal-only/Linux_IMX_Core/$(N)/common_bsp
DIR = internal-only/$(BUILD)/$(N)/common_bsp
ARCHIVE_PATH ?= ~
ARCHIVE_NAME ?= $(shell cat nightly.txt).tar

nightly :
	ls
	@rm -rf boot
	@echo "Pulling nightly for Validation board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8QX-val > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0lpddr4arm2/$(AHAB_IMG) -O $(AHAB_IMG)
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0lpddr4arm2/mx8qx-val-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0lpddr4arm2/bl31-imx8qx.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0lpddr4arm2/u-boot-imx8qxplpddr4arm2.bin-sd -O u-boot.bin
#	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0lpddr4arm2/u-boot-spl.bin-imx8qxplpddr4arm2-sd -O u-boot-spl.bin
#	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0lpddr4arm2/u-boot-spl.bin-imx8qxplpddr4arm2-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0lpddr4arm2/m4_image.bin -O m4_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8qxp-lpddr4*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

nightly_c0 :
	ls
	@rm -rf boot
	@echo "Pulling nightly for Validation board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8QX-val > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxplpddr4arm2/$(AHAB_IMG) -O $(AHAB_IMG)
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxplpddr4arm2/mx8qx-val-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxplpddr4arm2/bl31-imx8qx.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxplpddr4arm2/u-boot-imx8qxplpddr4arm2.bin-sd -O u-boot.bin
#	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxplpddr4arm2/u-boot-spl.bin-imx8qxplpddr4arm2-sd -O u-boot-spl.bin
#	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxplpddr4arm2/u-boot-spl.bin-imx8qxplpddr4arm2-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxplpddr4arm2/m4_image.bin -O m4_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8qxp-lpddr4*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

nightly_mek :
	@rm -rf boot
	@echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8QX-mek > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpmek/mx8qxb0-ahab-container.img -O mx8qxb0-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpmek/mx8qx-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpmek/bl31-imx8qx.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpmek/u-boot-imx8qxpmek.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpmek/u-boot-spl.bin-imx8qxpmek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpmek/u-boot-spl.bin-imx8qxpmek-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpmek/m4_image.bin -O m4_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8qxp-mek*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

nightly_c0mek :
	@rm -rf boot
	@echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8QX-mek > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0mek/mx8qxc0-ahab-container.img -O mx8qxc0-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0mek/mx8qx-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0mek/bl31-imx8qx.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0mek/u-boot-imx8qxpc0mek.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0mek/u-boot-spl.bin-imx8qxpc0mek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0mek/u-boot-spl.bin-imx8qxpc0mek-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qxpc0mek/m4_image.bin -O m4_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8qxp-mek*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

nightly_dxmek :
	@rm -rf boot
	@echo "Pulling nightly for DX MEK board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8DX-mek > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxmek/mx8qxc0-ahab-container.img -O mx8qxc0-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxmek/mx8dx-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxmek/bl31-imx8qx.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxmek/u-boot-imx8dxmek.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxmek/u-boot-spl.bin-imx8dxmek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxmek/u-boot-spl.bin-imx8dxmek-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxmek/m4_image.bin -O m4_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8dx-mek*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

nightly_dxlphantommek :
	@rm -rf boot
	@echo "Pulling nightly for DXL phantom MEK board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8DX-mek > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlphantommek/mx8qxb0-ahab-container.img -O mx8qxb0-ahab-container.img
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlphantommek/mx8dxl-phantom-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlphantommek/bl31-imx8qx.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlphantommek/u-boot-imx8dxlphantommek.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlphantommek/u-boot-spl.bin-imx8dxlphantommek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlphantommek/u-boot-spl.bin-imx8dxlphantommek-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxlphantommek/m4_image.bin -O m4_image.bin
	@$(WGET) -qr -nd -l1 -np $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8dxl-phantom-mek*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

archive :
	git ls-files --others --exclude-standard -z | xargs -0 tar rvf $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
	bzip2 $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
