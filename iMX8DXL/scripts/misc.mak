flash_secofw flash_b0_secofw: $(MKIMG) ahabfw.bin
	./$(MKIMG) -soc DXL -rev A0 -c -seco ahabfw.bin -out flash.bin

flash_msg_block:
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -msg_blk test_block.bin field 0x00100000 $(V2X_DUMMY_OCRAM) -out flash.bin

flash_flexspi_msg_block: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin $(QSPI_HEADER)
	./$(MKIMG) -soc DXL -rev A0 -dcd skip -dev flexspi -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -msg_blk test_block.bin field 0x00100000 $(V2X_DUMMY_OCRAM) -out flash.bin
	./$(QSPI_PACKER) $(QSPI_HEADER)

flash_nand_fw: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 $(V2X_DUMMY_DDR) -out flash.bin

flash_mfg flash_b0_mfg: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin Image fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.gz.u-boot board.dtb Image0 Image1
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -data board.dtb a35 0x83000000 -data fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.gz.u-boot a35 0x83100000 -data Image0 a35 0x80280000 -data Image1 a35 0x80c80000 -dummy 0x87fc0000 -out flash_mfg.bin

flash_nand_mfg flash_nand_b0_mfg: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin Image fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.gz.u-boot board-nand.dtb Image0 Image1
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -data board-nand.dtb a35 0x83000000 -data fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.gz.u-boot a35 0x83100000 -data Image0 a35 0x80280000 -data Image1 a35 0x80c80000 -dummy 0x87fc0000 -out flash_mfg.bin
