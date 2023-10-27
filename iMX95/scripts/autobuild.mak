include ../scripts/autobuild_common.mak

ifeq ($(V),1)
AT :=
else
AT := @
endif

# Aliases
nightly : nightly_evk
nightly_mek: nightly_evk
nightly_evk: nightly_mx95evk

# MX95 EVK
nightly_mx95evk: BOARD = imx95evk
nightly_mx95evk: DTB = imx95-19x19-evk
nightly_mx95evk: CPU = imx95
nightly_mx95evk: DDR = lpddr5
nightly_mx95evk: DDR_FW_VER = v202306
nightly_mx95evk: core_files

core_files:
	$(AT)rm -rf boot
	$(AT)echo "Pulling nightly for EVK board from $(SERVER)/$(DIR)"
	$(AT)echo $(BUILD)-$(N)-iMX95-evk > nightly.txt
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(AHAB_IMG) -O $(AHAB_IMG)
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/bl31-$(CPU).bin -O bl31.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/u-boot-$(BOARD).bin-sd -O u-boot.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/u-boot-spl.bin-$(BOARD)-sd -O u-boot-spl.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_dmem_$(DDR_FW_VER).bin -O $(DDR)_dmem_$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_imem_$(DDR_FW_VER).bin -O $(DDR)_imem_$(DDR_FW_VER).bin
	$(AT)$(RWGET) $(SERVER)/$(DIR)/imx_dtbs -P boot -A "$(DTB)*.dtb"
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/Image-$(BOARD).bin -O Image
	$(AT)mv -f Image boot
