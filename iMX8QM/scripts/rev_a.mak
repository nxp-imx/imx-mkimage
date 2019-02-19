DCD_800_CFG_SRC = imx8qm_dcd_800MHz.cfg
DCD_1200_CFG_SRC = imx8qm_dcd_1.2GHz.cfg
DCD_CFG_SRC = imx8qm_dcd_1.6GHz.cfg

DCD_800_CFG = imx8qm_dcd_800.cfg.tmp
DCD_1200_CFG = imx8qm_dcd_1200.cfg.tmp
DCD_CFG = imx8qm_dcd.cfg.tmp

#set default DDR_training to be in DCDs
DDR_TRAIN ?= 1

$(DCD_CFG): FORCE
	@echo "Converting iMX8 DCD 1.6GHz file"
	$(CC) -E -Wp,-MD,.imx8qm_dcd.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_CFG) $(DCD_CFG_SRC)

$(DCD_800_CFG): FORCE
	@echo "Converting iMX8 DCD 800MHz file"
	$(CC) -E -Wp,-MD,.imx8qm_dcd_800.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_800_CFG) $(DCD_800_CFG_SRC)

$(DCD_1200_CFG): FORCE
	@echo "Converting iMX8 DCD 1200MHz file"
	$(CC) -E -Wp,-MD,.imx8qm_dcd_1200.cfg.cfgtmp.d  -nostdinc -Iinclude -I$(INCLUDE) -DDDR_TRAIN_IN_DCD=$(DDR_TRAIN) -x c -o $(DCD_1200_CFG) $(DCD_1200_CFG_SRC)

flash_a0_scfw: $(MKIMG) scfw_tcm.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -out flash.bin

flash_a0_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_a0_dcd_800: $(MKIMG) $(DCD_800_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_800_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_a0_dcd_1200: $(MKIMG) $(DCD_1200_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_1200_CFG) -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_a0_early: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -flags 0x00400000 -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_a0_flexspi: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dev flexspi -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_a0_ca72: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -c -ap u-boot-atf.bin a72 0x80000000 -out flash.bin

flash_a0_multi_cores_m4_1: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m41_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m41_tcm.bin 1 0x38FE0000 -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_a0_multi_cores: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin m41_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m40_tcm.bin 0 0x34FE0000 -m4 m41_tcm.bin 1 0x38FE0000 -c -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_a0_cm4_0: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_a0_cm4_1: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 1 0x38FE0000 -out flash.bin

flash_a0_m4s_tcm: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_tcm.bin m41_tcm.bin
	./$(MKIMG) -soc QM -c -scfw scfw_tcm.bin -p1 -m4 m40_tcm.bin 0 0x34FE0000 -m4 m41_tcm.bin 1 0x38FE0000 -out flash.bin

flash_a0_all: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin u-boot-atf.bin scd.bin csf.bin csf_ap.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34FE0000 -csf csf.bin -scd scd.bin -c -ap u-boot-atf.bin a53 0x80000000 -csf csf_ap.bin -out flash.bin

flash_a0_ca72_ddrstress: $(MKIMG) scfw_tcm.bin mx8qm_ddr_stress_test.bin
	./$(MKIMG) -soc QM -c -flags 0x00800000 -scfw scfw_tcm.bin -c -ap mx8qm_ddr_stress_test.bin a72 0x00112000 -out flash.bin

flash_a0_ca53_ddrstress: $(MKIMG) scfw_tcm.bin mx8qm_ddr_stress_test.bin
	./$(MKIMG) -soc QM -c -flags 0x00800000 -scfw scfw_tcm.bin -c -ap mx8qm_ddr_stress_test.bin a53 0x00112000 -out flash.bin

flash_a0_ca72_ddrstress_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin mx8qm_ddr_stress_test.bin
	./$(MKIMG) -soc QM -c -flags 0x00800000 -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap mx8qm_ddr_stress_test.bin a72 0x00112000 -out flash.bin

flash_a0_ca53_ddrstress_dcd: $(MKIMG) $(DCD_CFG) scfw_tcm.bin mx8qm_ddr_stress_test.bin
	./$(MKIMG) -soc QM -c -flags 0x00800000 -dcd $(DCD_CFG) -scfw scfw_tcm.bin -c -ap mx8qm_ddr_stress_test.bin a53 0x00112000 -out flash.bin

flash_a0_cm4_01_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m40_ddr.bin m41_ddr.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m40_ddr.bin 0 0x88000000 -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_a0_m4_tcm_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m4_image.bin m41_ddr.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_a0_cm4_1_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin m41_ddr.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -p1 -m4 m41_ddr.bin 1 0x88800000 -out flash.bin

flash_a0_fastboot: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc QM -dev emmc_fast -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -m4 m4_image.bin 0 0x34fe0000 -ap u-boot-atf.bin a53 0x80000000 -out flash.bin

flash_a0_aprom_ddr: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin aprom_ddr.bin csf_ap.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap aprom_ddr.bin a53 0x80000000 -c -ap u-boot-atf.bin a53 0x90000000 -csf csf_ap.bin -out flash.bin

flash_a0_aprom_ddr_unsigned: $(MKIMG) $(DCD_CFG) scfw_tcm.bin u-boot-atf.bin aprom_ddr.bin csf_ap.bin
	./$(MKIMG) -soc QM -c -dcd $(DCD_CFG) -scfw scfw_tcm.bin -ap aprom_ddr.bin a53 0x80000000 -c -ap u-boot-atf.bin a53 0x90000000 -out flash.bin