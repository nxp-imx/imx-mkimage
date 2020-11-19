flash_m4: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 $(V2X_DUMMY_OCRAM) -out flash.bin

flash_m4_ddr: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x88000000 $(V2X_DUMMY_DDR) -out flash.bin

flash_m4_xip: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin m4_image.bin $(QSPI_HEADER)
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -dev flexspi -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -fileoff 0x80000 -p1 -m4 m4_image.bin 0 0x08081000 $(V2X_DUMMY_OCRAM) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)
