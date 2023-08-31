include ../scripts/autobuild_common.mak

ifeq ($(V),1)
AT :=
else
AT := @
endif

# Aliases
nightly : nightly_evk
nightly_mek: nightly_evk
nightly_evk: nightly_a1evk
nightly_ddr3_evk: nightly_ddr3_a1evk

# LPDDR4 EVK - A1
nightly_a1evk: override REV = a1
nightly_a1evk: override BRD = lpddr4-evk
nightly_a1evk: override SBRD = evk
nightly_a1evk: core_files

# DDR3L EVK - A1
nightly_ddr3_a1evk: override REV = a1
nightly_ddr3_a1evk: override BRD = ddr3l-evk
nightly_ddr3_a1evk: override SBRD = ddr3-evk
nightly_ddr3_a1evk: core_files

# LPDDR4 EVK - B0
nightly_b0evk: override REV = b0
nightly_b0evk: override BRD = lpddr4-evk
nightly_b0evk: override SBRD = evk
nightly_b0evk: core_files ocram_files

# DDR3L EVK - B0
nightly_ddr3_b0evk: override REV = b0
nightly_ddr3_b0evk: override BRD = ddr3l-evk
nightly_ddr3_b0evk: override SBRD = ddr3-evk
nightly_ddr3_b0evk: core_files ocram_files

core_files:
	$(AT)rm -rf boot
	$(AT)echo "Pulling nightly for MEK board from $(SERVER)/$(DIR)"
	$(AT)echo $(BUILD)-$(N)-iMX8DXL-$(LC_REVISION)-evk > nightly.txt
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/$(SECO_FW_NAME) -O $(SECO_FW_NAME)
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/mx8dxl-$(SBRD)-scfw-tcm.bin -O scfw_tcm.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/bl31-imx8dxl.bin -O bl31.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/u-boot-imx8dxl$(LC_REVISION)-$(BRD).bin-sd -O u-boot.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/u-boot-imx8dxl$(LC_REVISION)-$(BRD).bin-fspi -O u-boot-fspi.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/m4_image.bin -O m4_image.bin
	$(AT)$(RWGET) $(SERVER)/$(DIR)/imx_dtbs -P boot -A "imx8dxl-evk*.dtb"
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/Image-imx8_all.bin -O Image
	$(AT)mv -f Image boot


ocram_files: 
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/bl31-imx8dxl.bin-optee -O bl31-optee.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/u-boot-spl.bin-imx8dxl$(LC_REVISION)-$(BRD)-sd -O u-boot-spl.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/u-boot-spl.bin-imx8dxl$(LC_REVISION)-$(BRD)-fspi -O u-boot-spl-fspi.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/imx8dxl$(LC_REVISION)-$(BRD)/tee.bin -O tee.bin

archive :
	git ls-files --others --exclude-standard -z | xargs -0 tar rvf $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
	bzip2 $(ARCHIVE_PATH)/$(ARCHIVE_NAME)
