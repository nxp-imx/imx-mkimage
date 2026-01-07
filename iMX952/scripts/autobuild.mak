include ../scripts/autobuild_common.mak

ifeq ($(V),1)
AT :=
else
AT := @
endif

# Aliases
nightly : nightly_evk
nightly_mek: nightly_evk
nightly_evk: nightly_evk19
nightly_evk19: nightly_mx952evk19
nightly_evk15: nightly_mx952evk15
nightly_mx952evk19: nightly_mx952-19x19-lpddr5-evk
nightly_mx952evk15: nightly_mx952-15x15-lpddr4x-evk

# MX952 19x19 LPDDR5 EVK
nightly_mx952-19x19-lpddr5-evk: BOARD = $(CPU)-19x19-$(DDR)-evk
nightly_mx952-19x19-lpddr5-evk: DTB = imx952evk
nightly_mx952-19x19-lpddr5-evk: CPU = imx952
nightly_mx952-19x19-lpddr5-evk: DDR = lpddr5
nightly_mx952-19x19-lpddr5-evk: DDR_FW_VER = $(LPDDR_FW_VERSION)
nightly_mx952-19x19-lpddr5-evk: M7_FILE = $(DTB)_m7_TCM_power_mode_switch.bin
nightly_mx952-19x19-lpddr5-evk: core_files

# MX952 15x15 LPDDR4X EVK
nightly_mx952-15x15-lpddr4x-evk: BOARD = $(CPU)-15x15-$(DDR)-evk
nightly_mx952-15x15-lpddr4x-evk: DTB = imx952evk
nightly_mx952-15x15-lpddr4x-evk: CPU = imx952
nightly_mx952-15x15-lpddr4x-evk: DDR = lpddr4x
nightly_mx952-15x15-lpddr4x-evk: DDR_FW_VER = $(LPDDR_FW_VERSION)
nightly_mx952-15x15-lpddr4x-evk: M7_FILE = $(DTB)_m7_TCM_power_mode_switch.bin
nightly_mx952-15x15-lpddr4x-evk: core_files

core_files:
	$(AT)rm -rf boot
	$(AT)mkdir boot
	$(AT)echo "Pulling nightly for EVK board from $(SERVER)/$(DIR)"
	$(AT)echo $(BUILD)-$(N)-iMX952-evk > nightly.txt
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(AHAB_IMG) -O $(AHAB_IMG)
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/bl31-$(CPU).bin -O bl31.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/u-boot-$(BOARD).bin-sd -O u-boot.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/u-boot-spl.bin-$(BOARD)-sd -O u-boot-spl.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_dmem$(DDR_FW_VER).bin -O $(DDR)_dmem$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_dmem_qb$(DDR_FW_VER).bin -O $(DDR)_dmem_qb$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_imem$(DDR_FW_VER).bin -O $(DDR)_imem$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_imem_qb$(DDR_FW_VER).bin -O $(DDR)_imem_qb$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/oei-m33-ddr.bin -O oei-m33-ddr.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/m33_image-mx952evk.bin -O m33_image.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx_mcore_demos/$(M7_FILE) -O m7_image.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/Image-imx952evk.bin -O Image
	$(AT)mv -f Image boot
