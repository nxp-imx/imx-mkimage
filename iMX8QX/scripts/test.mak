flash_ddrstress flash_b0_ddrstress: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin mx8qxb0_ddr_stress_test.bin
	./$(MKIMG) -soc QX -rev B0 -append $(AHAB_IMG) -c  -flags 0x00800000 -scfw scfw_tcm.bin -ap mx8qxb0_ddr_stress_test.bin a35 0x00100000 -out flash.bin

flash_test_build_nand_4K flash_b0_test_build_nand_4K: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -dev nand 4K -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_test_build_nand_8K flash_b0_test_build_nand_8K: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -dev nand 8K -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_test_build_nand_16K flash_b0_test_build_nand_16K: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -dev nand 16K -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_test_build flash_b0_test_build: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin u-boot.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_test_build_mfg flash_b0_test_build_mfg: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin dummy_ddr.bin u-boot.bin CM4.bin kernel.bin initramfs.bin board.dtb
	./$(MKIMG) -soc QX -rev B0 -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -ap u-boot.bin a35 0x80000000 -m4 CM4.bin 0 0x34FE0000 -data kernel.bin 0x80280000 -data initramfs.bin 0x83100000 -data board.dtb 0x83000000 -out flash.bin

flash_scfw_test flash_b0_scfw_test: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin scfw_tests.bin
	./$(MKIMG) -soc QX -rev B0 -dcd skip -append $(AHAB_IMG) -c -scfw scfw_tcm.bin --data scfw_tests.bin 0x100000 -out flash.bin