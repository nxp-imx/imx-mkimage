flash_b0_ca72_ddrstress: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin mx8qmb0_ddr_stress_test.bin
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c  -flags 0x00800000 -scfw scfw_tcm.bin -ap mx8qmb0_ddr_stress_test.bin a72 0x00100000 -out flash.bin

flash_ddrstress flash_b0_ca53_ddrstress: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin mx8qmb0_ddr_stress_test.bin
	./$(MKIMG) -soc QM -rev B0 -append $(AHAB_IMG) -c  -flags 0x00800000 -scfw scfw_tcm.bin -ap mx8qmb0_ddr_stress_test.bin a53 0x00100000 -out flash.bin

flash_scfw_test flash_b0_scfw_test: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin scfw_tests.bin
	./$(MKIMG) -soc QM -rev B0 -dcd skip -append $(AHAB_IMG) -c -scfw scfw_tcm.bin --data scfw_tests.bin 0x100000 -out flash.bin