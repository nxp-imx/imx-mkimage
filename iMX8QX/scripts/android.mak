u-boot-atf-container-android.img: bl31.bin u-boot-hash.bin
	if [ -f tee.bin ]; then \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc QX -sw_version $(ROLLBACK_INDEX_IN_CONTAINER) -rev B0 -c -ap bl31.bin a35 0x80040000 -ap u-boot-hash.bin a35 0x80060000 -ap tee.bin a35 0xFE000000 -out u-boot-atf-container-android.img; \
		else \
			./$(MKIMG) -soc QX -rev B0 -c -ap bl31.bin a35 0x80040000 -ap u-boot-hash.bin a35 0x80060000 -ap tee.bin a35 0xFE000000 -out u-boot-atf-container-android.img; \
		fi; \
	else \
	./$(MKIMG) -soc QX -rev B0 -c -ap bl31.bin a35 0x80040000 -ap u-boot-hash.bin a35 0x80060000 -out u-boot-atf-container-android.img; \
	fi

flash_b0_all_ddr: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf.bin m4_image.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-atf.bin a35 0x80000000 -m4 m4_image.bin 0 0x88000000 -out flash.bin

flash_all_spl_container_ddr: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf-container-android.img m4_image.bin u-boot-spl.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a35 0x80000000 -m4 m4_image.bin 0 0x88000000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container-android.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container-android.img of=flash.bin bs=1K seek=$$pad_cnt; \

flash_all_spl_container_ddr_car: $(MKIMG) mx8qx-ahab-container.img scfw_tcm.bin u-boot-atf-container-android.img m4_image.bin u-boot-spl.bin
	./$(MKIMG) -soc QX -rev B0 -append mx8qx-ahab-container.img -c -flags 0x01200000 -scfw scfw_tcm.bin -ap u-boot-spl.bin a35 0x80000000 -p3 -m4 m4_image.bin 0 0x88000000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container-android.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container-android.img of=flash.bin bs=1K seek=$$pad_cnt; \
