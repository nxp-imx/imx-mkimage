flash_m4: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -dcd skip -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 -out flash.bin

flash_m4_ddr: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x88000000 -out flash.bin

flash_m4_xip: $(MKIMG) $(AHAB_IMG) scfw_tcm.bin m4_image.bin $(QSPI_HEADER)
	./$(MKIMG) -soc QX -rev B0 -dcd skip -dev flexspi -append $(AHAB_IMG) -c -scfw scfw_tcm.bin -fileoff 0x80000 -p1 -m4 m4_image.bin 0 0x08081000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)