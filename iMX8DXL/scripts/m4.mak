flash_cm4: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -append mx8dxl-ahab-container.img -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x34FE0000 -dummy 0x87f00000 -out flash.bin

flash_cm4_ddr: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -append mx8dxl-ahab-container.img -c -scfw scfw_tcm.bin -p1 -m4 m4_image.bin 0 0x88000000 -dummy 0x87f00000 -out flash.bin

flash_cm4_xip: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin m4_image.bin $(QSPI_HEADER)
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -dev flexspi -append mx8dxl-ahab-container.img -c -scfw scfw_tcm.bin -fileoff 0x80000 -p1 -m4 m4_image.bin 0 0x08081000 -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)