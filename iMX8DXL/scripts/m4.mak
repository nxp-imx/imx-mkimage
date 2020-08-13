flash_m4: $(MKIMG) mx8dxla0-ahab-container.img scfw_tcm.bin m4_image.bin
	SPL_CMD="$(shell cat u-boot-spl.bin_cmd)"; \
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -append mx8dxla0-ahab-container.img -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 $$SPL_CMD $(V2X_DUMMY_OCRAM) -out flash.bin

flash_m4_ddr: $(MKIMG) mx8dxla0-ahab-container.img scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -append mx8dxla0-ahab-container.img -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x88000000 $(V2X_DUMMY_DDR) -out flash.bin

flash_m4_xip: $(MKIMG) mx8dxla0-ahab-container.img scfw_tcm.bin m4_image.bin $(QSPI_HEADER)
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -dev flexspi -append mx8dxla0-ahab-container.img -c -scfw scfw_tcm.bin -fileoff 0x80000 -p1 -m4 m4_image.bin 0 0x08081000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)
