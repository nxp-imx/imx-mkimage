MKIMG = mkimage_imx8
OUTIMG = flash.bin
DCD_CFG_SRC = imx8mq_dcd.cfg
DCD_CFG = imx8mq_dcd.cfg.tmp

CC ?= gcc
CFLAGS ?= -O2 -Wall -std=c99 -static
INCLUDE = ./lib

WGET = /usr/bin/wget
N ?= latest
SERVER=http://yb2.am.freescale.net
DIR = build-output/Linux_IMX_4.9_morty_trunk_next_mx8/$(N)/common_bsp
FW_DIR = imx-boot/imx-boot-tools/imx8mq

$(MKIMG): mkimage_imx8.c
	@echo "Compiling mkimage_imx8"
	$(CC) $(CFLAGS) mkimage_imx8.c -o $(MKIMG) -lz

$(DCD_CFG): $(DCD_CFG_SRC)
	@echo "Converting iMX8M DCD file" 
	$(CC) -E -Wp,-MD,.imx8mq_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -x c -o $(DCD_CFG) $(DCD_CFG_SRC)

u-boot-spl-ddr.bin: u-boot-spl.bin lpddr4_pmu_train_1d_imem.bin lpddr4_pmu_train_1d_dmem.bin lpddr4_pmu_train_2d_imem.bin lpddr4_pmu_train_2d_dmem.bin
	@objcopy -I binary -O binary --pad-to 0x8000 --gap-fill=0x0 lpddr4_pmu_train_1d_imem.bin lpddr4_pmu_train_1d_imem_pad.bin
	@objcopy -I binary -O binary --pad-to 0x4000 --gap-fill=0x0 lpddr4_pmu_train_1d_dmem.bin lpddr4_pmu_train_1d_dmem_pad.bin
	@objcopy -I binary -O binary --pad-to 0x8000 --gap-fill=0x0 lpddr4_pmu_train_2d_imem.bin lpddr4_pmu_train_2d_imem_pad.bin
	@cat lpddr4_pmu_train_1d_imem_pad.bin lpddr4_pmu_train_1d_dmem_pad.bin > lpddr4_pmu_train_1d_fw.bin
	@cat lpddr4_pmu_train_2d_imem_pad.bin lpddr4_pmu_train_2d_dmem.bin > lpddr4_pmu_train_2d_fw.bin
	@cat u-boot-spl.bin lpddr4_pmu_train_1d_fw.bin lpddr4_pmu_train_2d_fw.bin > u-boot-spl-ddr.bin
	@rm -f lpddr4_pmu_train_1d_fw.bin lpddr4_pmu_train_2d_fw.bin lpddr4_pmu_train_1d_imem_pad.bin lpddr4_pmu_train_1d_dmem_pad.bin lpddr4_pmu_train_2d_imem_pad.bin

u-boot-atf.bin: u-boot.bin bl31.bin
	@cp bl31.bin u-boot-atf.bin
	@dd if=u-boot.bin of=u-boot-atf.bin bs=1K seek=128

u-boot-atf-tee.bin: u-boot.bin bl31.bin tee.bin
	@cp bl31.bin u-boot-atf-tee.bin
	@dd if=tee.bin of=u-boot-atf-tee.bin bs=1K seek=128
	@dd if=u-boot.bin of=u-boot-atf-tee.bin bs=1M seek=1

.PHONY: clean
clean:
	@rm -f $(MKIMG) $(DCD_CFG) .imx8mq_dcd.cfg.cfgtmp.d u-boot-atf.bin u-boot-atf-tee.bin u-boot-spl-ddr.bin u-boot.itb u-boot.its $(OUTIMG)

dtbs = fsl-imx8mq-evk.dtb
u-boot.itb: $(dtbs)
	./mkimage_fit_atf.sh $(dtbs) > u-boot.its
	./mkimage_uboot -E -p 0x3000 -f u-boot.its u-boot.itb
	@rm -f u-boot.its

flash_hdmi_spl_uboot: $(MKIMG) signed_hdmi_imx8m.bin u-boot-spl-ddr.bin u-boot.itb
	./mkimage_imx8 -fit -signed_hdmi signed_hdmi_imx8m.bin -loader u-boot-spl-ddr.bin 0x7E1000 -second_loader u-boot.itb 0x40200000 0x60000 -out $(OUTIMG)

flash_hdmi_spl_uboot_tee: $(MKIMG) signed_hdmi_imx8m.bin u-boot-spl-ddr.bin u-boot-atf-tee.bin
	./mkimage_imx8 -signed_hdmi signed_hdmi_imx8m.bin -loader u-boot-spl-ddr.bin 0x7E1000 -second_loader u-boot-atf-tee.bin 0x40200000 0x60000 -out $(OUTIMG)

flash_spl_uboot: $(MKIMG) u-boot-spl-ddr.bin u-boot.itb
	./mkimage_imx8 -fit -loader u-boot-spl-ddr.bin 0x7E1000 -second_loader u-boot.itb 0x40200000 0x60000 -out $(OUTIMG)

flash_spl_uboot_tee: $(MKIMG) u-boot-spl-ddr.bin u-boot-atf-tee.bin
	./mkimage_imx8 -loader u-boot-spl-ddr.bin 0x7E1000 -second_loader u-boot-atf-tee.bin 0x40200000 0x60000 -out $(OUTIMG)

print_fit_hab: u-boot-nodtb.bin bl31.bin $(dtbs)
	./print_fit_hab.sh 0x60000 $(dtbs)

nightly :
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/lpddr4_pmu_train_1d_dmem.bin -O lpddr4_pmu_train_1d_dmem.bin
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/lpddr4_pmu_train_1d_imem.bin -O lpddr4_pmu_train_1d_imem.bin
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/lpddr4_pmu_train_2d_dmem.bin -O lpddr4_pmu_train_2d_dmem.bin
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/lpddr4_pmu_train_2d_imem.bin -O lpddr4_pmu_train_2d_imem.bin
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/bl31-imx8mq.bin -O bl31.bin
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/u-boot-spl.bin-imx8mqevk-sd -O u-boot-spl.bin
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/u-boot-nodtb.bin -O u-boot-nodtb.bin
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/fsl-imx8mq-evk.dtb -O fsl-imx8mq-evk.dtb
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/signed_hdmi_imx8m.bin -O signed_hdmi_imx8m.bin
	@$(WGET) -q $(SERVER)/$(DIR)/$(FW_DIR)/mkimage_uboot -O mkimage_uboot

#flash_dcd_uboot: $(MKIMG) $(DCD_CFG) u-boot-atf.bin
#	./mkimage_imx8 -dcd $(DCD_CFG) -loader u-boot-atf.bin 0x40001000 -out $(OUTIMG)

#flash_plugin: $(MKIMG) plugin.bin u-boot-spl-for-plugin.bin
#	./mkimage_imx8 -plugin plugin.bin 0x912800 -loader u-boot-spl-for-plugin.bin 0x7F0000 -out $(OUTIMG)
