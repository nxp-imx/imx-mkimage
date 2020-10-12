flash_b0_all_ddr: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf.bin m4_image.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -m4 m4_image.bin 0 0x88000000 $(V2X_DUMMY_DDR) -out flash.bin

flash_all_spl_container_ddr: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf-container.img m4_image.bin u-boot-spl.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a35 0x00100000 -m4 m4_image.bin 0 0x88000000 $(V2X_DUMMY_DDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \

flash_all_spl_container_ddr_car: $(MKIMG) $(SECO_FW_NAME) scfw_tcm.bin u-boot-atf-container.img m4_image.bin u-boot-spl.bin
	./$(MKIMG) -soc DXL -rev A0 -append $(SECO_FW_NAME) -c -flags 0x01200000 -scfw scfw_tcm.bin -ap u-boot-spl.bin a35 0x00100000 -p3 -m4 m4_image.bin 0 0x88000000 $(V2X_DUMMY_DDR) -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \
