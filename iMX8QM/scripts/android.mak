u-boot-atf-container-android.img: bl31.bin u-boot-hash.bin
	@if [ -f "hdmitxfw.bin" ] && [ -f "hdmirxfw.bin" ]; then \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmitxfw.bin hdmitxfw-pad.bin; \
	objcopy -I binary -O binary --pad-to 0x20000 --gap-fill=0x0 hdmirxfw.bin hdmirxfw-pad.bin; \
	cat u-boot-hash.bin hdmitxfw-pad.bin hdmirxfw-pad.bin > u-boot-hash.bin.temp; \
	mv u-boot-hash.bin.temp u-boot-hash.bin; \
	fi
	if [ -f "tee.bin" ]; then \
		if [ $(shell echo $(ROLLBACK_INDEX_IN_CONTAINER)) ]; then \
			./$(MKIMG) -soc QM -sw_version $(ROLLBACK_INDEX_IN_CONTAINER) -rev B0 -c -ap bl31.bin a53 0x80040000 -ap u-boot-hash.bin a53 0x80060000 -ap tee.bin a53 0xFE000000 -out u-boot-atf-container-android.img; \
		else \
			./$(MKIMG) -soc QM -rev B0 -c -ap bl31.bin a53 0x80040000 -ap u-boot-hash.bin a53 0x80060000 -ap tee.bin a53 0xFE000000 -out u-boot-atf-container-android.img; \
		fi; \
	else \
	./$(MKIMG) -soc QM -rev B0 -c -ap bl31.bin a53 0x80040000 -ap u-boot-hash.bin a53 0x80060000 -out u-boot-atf-container-android.img; \
	fi

flash_b0_spl_container_m4_1_trusty: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf-container-android.img m4_1_image.bin tee.bin u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -flags 0x01200000 -scfw scfw_tcm.bin -p4 -m4 m4_1_image.bin 1 0x88800000 -ap u-boot-spl.bin a53 0x80000000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container-android.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container-android.img of=flash.bin bs=1K seek=$$pad_cnt; \

flash_b0_spl_container_m4_1: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf-container.img m4_1_image.bin u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -flags 0x01200000 -scfw scfw_tcm.bin -p4 -m4 m4_1_image.bin 1 0x88800000 -ap u-boot-spl.bin a53 0x00100000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container.img of=flash.bin bs=1K seek=$$pad_cnt; \

flash_b0_spl_container_trusty: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-atf-container-android.img tee.bin u-boot-spl.bin
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x80000000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container-android.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container-android.img of=flash.bin bs=1K seek=$$pad_cnt; \

flash_b0_spl_container_android: $(MKIMG) mx8qm-ahab-container.img scfw_tcm.bin u-boot-spl.bin u-boot-atf-container-android.img
	./$(MKIMG) -soc QM -rev B0 -append mx8qm-ahab-container.img -c -scfw scfw_tcm.bin -ap u-boot-spl.bin a53 0x80000000 -out flash.bin
	cp flash.bin boot-spl-container.img
	@flashbin_size=`wc -c flash.bin | awk '{print $$1}'`; \
                   pad_cnt=$$(((flashbin_size + 0x400 - 1) / 0x400)); \
                   echo "append u-boot-atf-container-android.img at $$pad_cnt KB"; \
                   dd if=u-boot-atf-container-android.img of=flash.bin bs=1K seek=$$pad_cnt;
