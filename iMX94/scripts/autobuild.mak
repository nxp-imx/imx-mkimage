include ../scripts/autobuild_common.mak

ifeq ($(V),1)
AT :=
else
AT := @
endif

# Aliases
nightly : nightly_evk
nightly_mek: nightly_evk
nightly_evk: nightly_evk19lp5
nightly_evk19lp5: nightly_mx943evk19lp5
nightly_evk19lp4: nightly_mx943evk19lp4
nightly_evk15: nightly_mx943evk15
nightly_mx943evk19lp5: nightly_mx943-19x19-lpddr5-evk
nightly_mx943evk19lp4: nightly_mx943-19x19-lpddr4-evk
nightly_mx943evk15: nightly_mx943-15x15-lpddr4-evk

# MX943 19x19 LPDDR5 EVK
nightly_mx943-19x19-lpddr5-evk: BOARD = $(CPU)-19x19-$(DDR)-evk
nightly_mx943-19x19-lpddr5-evk: DTB = imx943-19x19-evk
nightly_mx943-19x19-lpddr5-evk: CPU = imx943
nightly_mx943-19x19-lpddr5-evk: DDR = lpddr5
nightly_mx943-19x19-lpddr5-evk: DDR_FW_VER = $(LPDDR_FW_VERSION)
nightly_mx943-19x19-lpddr5-evk: M7_FILE = imx943evk_cm7_core0_TCM_power_mode_switch.bin
nightly_mx943-19x19-lpddr5-evk: M71_FILE = imx943evk_cm7_core1_TCM_power_mode_switch.bin
nightly_mx943-19x19-lpddr5-evk: M33S_FILE = imx943evk_cm33_core1_TCM_power_mode_switch.bin
nightly_mx943-19x19-lpddr5-evk: core_files

# MX943 19x19 LPDDR4X EVK
nightly_mx943-19x19-lpddr4-evk: BOARD = $(CPU)-19x19-lpddr4-evk
nightly_mx943-19x19-lpddr4-evk: DTB = imx943-19x19-evk
nightly_mx943-19x19-lpddr4-evk: CPU = imx943
nightly_mx943-19x19-lpddr4-evk: DDR = lpddr4x
nightly_mx943-19x19-lpddr4-evk: DDR_FW_VER = $(LPDDR_FW_VERSION)
nightly_mx943-19x19-lpddr4-evk: M7_FILE = imx943evk_cm7_core0_TCM_power_mode_switch.bin
nightly_mx943-19x19-lpddr4-evk: M71_FILE = imx943evk_cm7_core1_TCM_power_mode_switch.bin
nightly_mx943-19x19-lpddr4-evk: M33S_FILE = imx943evk_cm33_core1_TCM_power_mode_switch.bin
nightly_mx943-19x19-lpddr4-evk: core_files

# MX943 15x15 LPDDR4X EVK
nightly_mx943-15x15-lpddr4-evk: BOARD = $(CPU)-15x15-lpddr4-evk
nightly_mx943-15x15-lpddr4-evk: DTB = imx943-15x15-evk
nightly_mx943-15x15-lpddr4-evk: CPU = imx943
nightly_mx943-15x15-lpddr4-evk: DDR = lpddr4x
nightly_mx943-15x15-lpddr4-evk: DDR_FW_VER = $(LPDDR_FW_VERSION)
nightly_mx943-15x15-lpddr4-evk: M7_FILE = imx943evk_cm7_core0_TCM_power_mode_switch.bin
nightly_mx943-15x15-lpddr4-evk: M71_FILE = imx943evk_cm7_core1_TCM_power_mode_switch.bin
nightly_mx943-15x15-lpddr4-evk: M33S_FILE = iimx943evk_cm33_core1_TCM_power_mode_switch.bin
nightly_mx943-15x15-lpddr4-evk: core_files

core_files:
	$(AT)rm -rf boot
	$(AT)mkdir boot
	$(AT)echo "Pulling nightly for EVK board from $(SERVER)/$(DIR)"
	$(AT)echo $(BUILD)-$(N)-iMX943-evk > nightly.txt
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(AHAB_IMG) -O $(AHAB_IMG)
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/bl31-imx94.bin -O bl31.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/u-boot-$(BOARD).bin-sd -O u-boot.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/u-boot-spl.bin-$(BOARD)-sd -O u-boot-spl.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_dmem$(DDR_FW_VER).bin -O $(DDR)_dmem$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_dmem_qb$(DDR_FW_VER).bin -O $(DDR)_dmem_qb$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_imem$(DDR_FW_VER).bin -O $(DDR)_imem$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(DDR)_imem_qb$(DDR_FW_VER).bin -O $(DDR)_imem_qb$(DDR_FW_VER).bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/oei-m33-ddr.bin -O oei-m33-ddr.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/m33_image-mx94evk.bin -O m33_image.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(M7_FILE) -O m70_image.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(M71_FILE) -O m71_image.bin
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/imx-boot/imx-boot-tools/$(BOARD)/$(M33S_FILE) -O m33s_image.bin
	$(AT)$(RWGET) $(SERVER)/$(DIR)/imx_dtbs -P boot -A "$(DTB)*.dtb"
	$(AT)$(WGET) -q $(SERVER)/$(DIR)/Image-imx943evk.bin -O Image
	$(AT)mv -f Image boot
