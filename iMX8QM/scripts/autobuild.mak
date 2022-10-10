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

nightly :
	@rm -rf boot
	@echo "Pulling nightly for Validation board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8QM-val > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmlpddr4arm2/$(AHAB_IMG) -O $(AHAB_IMG)
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmlpddr4arm2/mx8qm-val-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmlpddr4arm2/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmlpddr4arm2/u-boot-imx8qmlpddr4arm2.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/u-boot-spl.bin-imx8qmmek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/u-boot-spl.bin-imx8qmmek-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmlpddr4arm2/m4_image.bin -O m4_image.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmlpddr4arm2/m4_1_image.bin -O m4_1_image.bin
	@$(RWGET) $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8qm-lpddr4*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

nightly_mek :
	@rm -rf boot
	@echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	@echo $(BUILD)-$(N)-iMX8QM-mek > nightly.txt
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/$(AHAB_IMG) -O $(AHAB_IMG)
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/mx8qm-mek-scfw-tcm.bin -O scfw_tcm.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/bl31-imx8qm.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/u-boot-imx8qmmek.bin-sd -O u-boot.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/u-boot-spl.bin-imx8qmmek-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/u-boot-spl.bin-imx8qmmek-fspi -O u-boot-spl-fspi.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/m4_image.bin -O m4_image.bin
	@$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8qmmek/m4_1_image.bin -O m4_1_image.bin
	@$(RWGET) $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8qm-mek*.dtb"
	@$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	@mv -f Image boot

archive :
	git ls-files --others --exclude-standard -z | xargs -0 tar rvf $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
	bzip2 $(ARCHIVE_PATH)/$(ARCHIVE_NAME)

