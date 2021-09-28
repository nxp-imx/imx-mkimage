flash_ddrstress flash_a0_ddrstress: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin mx8dxl_ddr_stress_test.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c  -flags 0x00800000 -scfw scfw_tcm.bin -ap mx8dxl_ddr_stress_test.bin a35 0x00100000 $(V2X_DUMMY_DDR) -out flash.bin

flash_test_build_nand_4K flash_a0_test_build_nand_4K: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -dev nand 4K -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 $(V2X_DUMMY_DDR) -out flash.bin

flash_test_build_nand_8K flash_a0_test_build_nand_8K: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -dev nand 8K -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 $(V2X_DUMMY_DDR) -out flash.bin

flash_test_build_nand_16K flash_a0_test_build_nand_16K: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -dev nand 16K -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 $(V2X_DUMMY_DDR) -out flash.bin

flash_test_build flash_a0_test_build: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 $(V2X_DUMMY_DDR) -out flash.bin

flash_test_build_mfg flash_a0_test_build_mfg: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin dummy_ddr.bin u-boot.bin CM4.bin kernel.bin initramfs.bin board.dtb
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 CM4.bin 0 0x34FE0000 -data kernel.bin a35 0x80280000 -data initramfs.bin a35 0x83100000 -data board.dtb a35 0x83000000 $(V2X_DUMMY_DDR) -out flash.bin

flash_scfw_test flash_a0_scfw_test: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin scfw_tests.bin
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin --data scfw_tests.bin a35 0x100000 $(V2X_DUMMY_OCRAM) -out flash.bin

