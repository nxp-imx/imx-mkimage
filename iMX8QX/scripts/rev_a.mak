DCD_CFG_SRC = imx8qx_dcd_1.2GHz.cfg
DCD_CFG = imx8qx_dcd.cfg.tmp

DCD_CFG_16BIT_SRC = imx8qx_dcd_16bit_1.2GHz.cfg
DCD_16BIT_CFG = imx8qx_16bit_dcd.cfg.tmp

DCD_CFG_DDR3_SRC = imx8qx_ddr3_dcd_1066MHz_ecc.cfg
DCD_DDR3_CFG = imx8qx_ddr3_dcd_1066MHz_ecc.cfg.tmp

DCD_CFG_DX_DDR3_SRC = imx8dx_ddr3_dcd_16bit_933MHz.cfg
DCD_DX_DDR3_CFG = imx8dx_ddr3_dcd_16bit_933MHz.cfg.tmp

#set default DDR_training to be in DCDs
DDR_TRAIN ?= 1

DDR3_DCD ?= 0
DX ?= 0

ifeq ($(DDR3_DCD), 1)
    ifeq ($(DX), 1)
	    DCD_CFG_SRC = imx8dx_ddr3_dcd_16bit_933MHz.cfg
    else
	    DCD_CFG_SRC = imx8qx_ddr3_dcd_1066MHz_ecc.cfg
    endif
endif

$(DCD_CFG): FORCE
	@echo "Converting iMX8 DCD file"
	$(CC) -E -Wp,-MD,.imx8qx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_CFG) $(DCD_CFG_SRC)
	$(CC) -E -Wp,-MD,.imx8qx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_16BIT_CFG) $(DCD_CFG_16BIT_SRC)
	$(CC) -E -Wp,-MD,.imx8qx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_DDR3_CFG) $(DCD_CFG_DDR3_SRC)
	$(CC) -E -Wp,-MD,.imx8dx_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_DX_DDR3_CFG) $(DCD_CFG_DX_DDR3_SRC)

flash_a0_scfw: $(MKIMG) scfw_tcm.bin
	./$(MKIMG) -soc QX -c -scfw scfw_tcm.bin -out flash.bin

flash_a0_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0_16bit_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_16BIT_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0_ddr3_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_DDR3_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0_dx_ddr3_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_DX_DDR3_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0: $(MKIMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0_cm4: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_a0_early: $(MKIMG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -flags 0x00400000 -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0_flexspi: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -dev flexspi -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0_multi_cores: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m40_tcm.bin 0 0x34FE0000 -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0_nand: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -dev nand -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a35 0x80000000 -out flash.bin

flash_a0_all: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin u-boot-atf.bin scd.bin csf.bin csf_ap.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -scd scd.bin -csf csf.bin -c -ap u-boot-atf.bin a35 0x80000000 -csf csf_ap.bin -out flash.bin

flash_a0_ca35_ddrstress: $(MKIMG) scfw_tcm.bin mx8qx_ddr_stress_test.bin
	./$(MKIMG) -soc QX -c -flags 0x00800000 -scfw scfw_tcm.bin -c -ap mx8qx_ddr_stress_test.bin a35 0x00112000 -out flash.bin

flash_a0_ca35_ddrstress_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin mx8qx_ddr_stress_test.bin
	./$(MKIMG) -soc QX -c -flags 0x00800000 -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap mx8qx_ddr_stress_test.bin a35 0x00112000 -out flash.bin

flash_a0_cm4ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x88000000 -out flash.bin

flash_a0_fastboot: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QX -dev emmc_fast -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -out flash.bin