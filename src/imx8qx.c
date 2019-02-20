/*
 * Copyright 2017 NXP
 *
 * SPDX-License-Identifier:     GPL-2.0+
 * derived from u-boot's mkimage utility
 *
 */

#include <inttypes.h>
#include "mkimage_common.h"

#define MAX_NUM_IMGS            6
#define IVT_HEADER_TAG          0xDE

typedef struct {
	uint64_t src;		/*8*/
	uint64_t dst;		/*8*/
	uint64_t entry;		/*8*/
	uint32_t size;		/*4*/
	uint32_t hab_flags;	/*4*/
	uint32_t flags1;	/*4*/
	uint32_t flags2;	/*4*/
} __attribute__((packed)) boot_img_t;; /*40*/

typedef struct {
	uint32_t num_images;	/*4*/
	uint32_t bd_size;	/*4*/
	uint32_t bd_flags;	/*4*/
	uint32_t reserved;	/*4*/
	boot_img_t img[MAX_NUM_IMGS];	/*240*/
}  __attribute__((packed)) boot_data_v3_t;		/*256*/

typedef struct {
	ivt_header_t header;	/*4*/
	uint32_t ver;	/*4*/
	uint64_t dcd_ptr;	/*8*/
	uint64_t boot_data_ptr;	/*8*/
	uint64_t self;		/*8*/
	uint64_t csf;		/*8*/
	uint64_t next;		/*8*/
}  __attribute__((packed)) flash_header_v3_t;		/*48*/

#define MAX_NUM_OF_CONTAINER    2

typedef struct {
	flash_header_v3_t fhdr[MAX_NUM_OF_CONTAINER];	/*96*/
	boot_data_v3_t boot_data[MAX_NUM_OF_CONTAINER]; /*512*/
	dcd_v2_t dcd_table; /*2880*/
}  __attribute__((packed)) imx_header_v3_t; /*3488*/


static void set_imx_hdr_v3(imx_header_v3_t *imxhdr, uint32_t dcd_len,
		uint32_t flash_offset, uint32_t hdr_base, uint32_t cont_id)
{
	flash_header_v3_t *fhdr_v3 = &imxhdr->fhdr[cont_id];

	/* Set magic number */
	fhdr_v3->header.tag = IVT_HEADER_TAG; /* 0xDE */
	fhdr_v3->header.length = cpu_to_be16(sizeof(flash_header_v3_t));
	fhdr_v3->header.version = IVT_VERSION; /* 0x43 */

	fhdr_v3->ver = IVT_VER; /* 0x01 */

	fhdr_v3->self = hdr_base + flash_offset + cont_id * sizeof(flash_header_v3_t);
	if (dcd_len > 0)
		fhdr_v3->dcd_ptr = hdr_base + flash_offset +
			offsetof(imx_header_v3_t, dcd_table);
	else
		fhdr_v3->dcd_ptr = 0;
	fhdr_v3->boot_data_ptr = hdr_base + flash_offset
			+ offsetof(imx_header_v3_t, boot_data) + cont_id * sizeof(boot_data_v3_t);

	fhdr_v3->csf = 0;

	if ((cont_id + 1) < MAX_NUM_OF_CONTAINER)
		fhdr_v3->next = (uintptr_t)&imxhdr->fhdr[cont_id + 1] - (uintptr_t)imxhdr;
	else
		fhdr_v3->next = 0;
}

int build_container_qx(uint32_t sector_size, uint32_t ivt_offset, char* out_file, bool emmc_fastboot, image_t* image_stack)
{
        int file_off,  ofd = -1;
        unsigned int dcd_len = 0;

        static imx_header_v3_t imx_header;
        image_t* img_sp = image_stack;
        struct stat sbuf;
        uint64_t tmp_to = 0; /* used for offset of memory to find images */
        uint32_t custom_partition = 0; /* 0 denotes default partition */

        int container = -1;
        int cont_img_count = 0; /* indexes to arrange the container */

	memset((char*)&imx_header, 0, sizeof(imx_header_v3_t));

        if(image_stack == NULL) {
          fprintf(stderr, "Empty image stack ");
          exit(EXIT_FAILURE);
        }

        fprintf(stdout, "Platform:\ti.MX8QXP\n");

        if(emmc_fastboot){/* start images after initial 8K */
          file_off = 0x2000 - ivt_offset;
        }
        else
        {
          file_off = ALIGN(sizeof(imx_header_v3_t) + ivt_offset, sector_size);
        }

        do{ /* process DCD if it is found */
          if (img_sp->option == DCD) {
            dcd_len = parse_cfg_file(&imx_header.dcd_table, img_sp->filename);
            fprintf(stdout, "dcd len = %d\n", dcd_len);
          }
          img_sp++;
        }
        while(img_sp->option!= NO_IMG);


        /* change load addr  and setup DCD to be attached to first container */
        if (ivt_offset == IVT_OFFSET_FLEXSPI) {
            set_imx_hdr_v3(&imx_header, dcd_len, ivt_offset, INITIAL_LOAD_ADDR_FLEXSPI, 0);
            set_imx_hdr_v3(&imx_header, 0, ivt_offset, INITIAL_LOAD_ADDR_FLEXSPI, 1);
        } else {
            set_imx_hdr_v3(&imx_header, dcd_len, ivt_offset, INITIAL_LOAD_ADDR_SCU_ROM, 0);
            set_imx_hdr_v3(&imx_header, 0, ivt_offset, INITIAL_LOAD_ADDR_AP_ROM, 1);
        }


        /* step through image stack and generate the header */
        img_sp = image_stack;
        while(img_sp->option != NO_IMG){ /* stop once we reach null terminator */
              switch(img_sp->option){
                case SCFW:
                        check_file(&sbuf, img_sp->filename);
                        fprintf(stdout, "scfw size = %" PRIi64 "\n", sbuf.st_size);
                        imx_header.boot_data[container].img[cont_img_count].src = file_off;
                        img_sp->src = file_off;
                        imx_header.boot_data[container].img[cont_img_count].dst =   0x1ffe0000; /* hard code scfw entry address */
                        imx_header.boot_data[container].img[cont_img_count].entry = 0x1ffe0000;
                        imx_header.boot_data[container].img[cont_img_count].size = sbuf.st_size;
                        imx_header.boot_data[container].img[cont_img_count].flags2 = 0;
                        imx_header.boot_data[container].img[cont_img_count].hab_flags = IMG_TYPE_EXEC;
                        imx_header.boot_data[container].img[cont_img_count].flags1 = (CORE_SC & BOOT_IMG_FLAGS_CORE_MASK);
                        imx_header.boot_data[container].num_images++;
                        imx_header.boot_data[container].bd_size = sizeof(boot_data_v3_t);

                        file_off += ALIGN(sbuf.st_size, sector_size);
                        tmp_to = ALIGN((imx_header.boot_data[container].img[cont_img_count].dst + sbuf.st_size), IMG_AUTO_ALIGN);
                        cont_img_count++;
                        break;
                case M4:
                        check_file(&sbuf, img_sp->filename);
                        imx_header.boot_data[container].img[cont_img_count].src = file_off;
                        img_sp->src = file_off;
                        imx_header.boot_data[container].img[cont_img_count].dst = img_sp->entry;
                        imx_header.boot_data[container].img[cont_img_count].entry = img_sp->entry;
                        imx_header.boot_data[container].img[cont_img_count].size = sbuf.st_size;
                        imx_header.boot_data[container].num_images++;


                        imx_header.boot_data[container].img[cont_img_count].flags2 = 0;
                        imx_header.boot_data[container].img[cont_img_count].hab_flags = IMG_TYPE_EXEC;
                        if (img_sp->ext == 0) {
                            imx_header.boot_data[container].img[cont_img_count].flags1 = (CORE_CM4_0 & BOOT_IMG_FLAGS_CORE_MASK);
                            imx_header.boot_data[container].img[cont_img_count].flags1 |= (SC_R_M4_0_PID0 << BOOT_IMG_FLAGS_CPU_RID_SHIFT);
                            imx_header.boot_data[container].img[cont_img_count].flags1 |= (SC_R_M4_0_MU_1A << BOOT_IMG_FLAGS_MU_RID_SHIFT);
                        }
                        else if (img_sp->ext == 1) {
                            imx_header.boot_data[container].img[cont_img_count].flags1 = (CORE_CM4_1 & BOOT_IMG_FLAGS_CORE_MASK);
                            imx_header.boot_data[container].img[cont_img_count].flags1 |= (SC_R_M4_1_PID0 << BOOT_IMG_FLAGS_CPU_RID_SHIFT);
                            imx_header.boot_data[container].img[cont_img_count].flags1 |= (SC_R_M4_1_MU_1A << BOOT_IMG_FLAGS_MU_RID_SHIFT);
                        }
                        else{
                            fprintf(stderr, "Error: invalid m4 core id: %" PRIi64 "\n", img_sp->ext);
                            exit(EXIT_FAILURE);
                        }
                        if(custom_partition != 0)
                        {
                            imx_header.boot_data[container].img[cont_img_count].flags1 |= (custom_partition << BOOT_IMG_FLAGS_PARTITION_ID_SHIFT);
                            custom_partition = 0;
                        }
                        else
                        {
                            imx_header.boot_data[container].img[cont_img_count].flags1 |= (PARTITION_ID_M4 << BOOT_IMG_FLAGS_PARTITION_ID_SHIFT);
                        }
                        file_off += ALIGN(sbuf.st_size, sector_size);
                        cont_img_count++;
                        break;
                case AP:
                        check_file(&sbuf, img_sp->filename);
                        imx_header.boot_data[container].img[cont_img_count].src = file_off;
                        img_sp->src = file_off;
                        imx_header.boot_data[container].img[cont_img_count].dst = img_sp->entry;
                        imx_header.boot_data[container].img[cont_img_count].size = sbuf.st_size;
                        imx_header.boot_data[container].img[cont_img_count].entry = img_sp->entry;
                        imx_header.boot_data[container].num_images++;
                        imx_header.boot_data[container].bd_size = sizeof(boot_data_v3_t);
                        imx_header.boot_data[container].bd_flags = 0;


                        imx_header.boot_data[container].img[cont_img_count].flags2 = 0;
                        imx_header.boot_data[container].img[cont_img_count].hab_flags = IMG_TYPE_EXEC;
                        imx_header.boot_data[container].img[cont_img_count].flags1 = (img_sp->ext & BOOT_IMG_FLAGS_CORE_MASK);
                        if (img_sp->ext != CORE_CA35) {
                          fprintf(stderr, "Error: invalid AP core id: %" PRIi64 "\n", img_sp->ext);
                          exit(EXIT_FAILURE);
                        }
                        imx_header.boot_data[container].img[cont_img_count].flags1 |= (SC_R_A35_0 << BOOT_IMG_FLAGS_CPU_RID_SHIFT);
                        imx_header.boot_data[container].img[cont_img_count].flags1 |= (SC_R_MU_0A << BOOT_IMG_FLAGS_MU_RID_SHIFT);

                        if(custom_partition != 0)
                        {
                            imx_header.boot_data[container].img[cont_img_count].flags1 |= (custom_partition << BOOT_IMG_FLAGS_PARTITION_ID_SHIFT);
                            custom_partition = 0;
                        }
                        else
                        {
                            imx_header.boot_data[container].img[cont_img_count].flags1 |= (PARTITION_ID_AP << BOOT_IMG_FLAGS_PARTITION_ID_SHIFT);
                        }

                        file_off += ALIGN(sbuf.st_size, sector_size);
                        cont_img_count++;
                        break;
                case SCD:
                        check_file(&sbuf, img_sp->filename);
                        imx_header.boot_data[container].img[cont_img_count].src = file_off;
                        img_sp->src = file_off;
                        imx_header.boot_data[container].img[cont_img_count].dst = tmp_to;
                        imx_header.boot_data[container].img[cont_img_count].size = sbuf.st_size;
                        imx_header.boot_data[container].img[cont_img_count].flags2 = 0;
                        imx_header.boot_data[container].img[cont_img_count].hab_flags = IMG_TYPE_SCD;
                        imx_header.boot_data[container].img[cont_img_count].flags1 = (CORE_SC & BOOT_IMG_FLAGS_CORE_MASK);
                        imx_header.boot_data[container].num_images++; /* scd img is count in num_images */

                        tmp_to = ALIGN((tmp_to + sbuf.st_size), IMG_AUTO_ALIGN);
                        file_off += ALIGN(sbuf.st_size, sector_size);
                        cont_img_count++;
                        break;
                case CSF:
                        check_file(&sbuf, img_sp->filename);
                        if (sbuf.st_size > CSF_DATA_SIZE) {
                             fprintf(stderr, "%s: file size %" PRIi64 " is larger than CSF_DATA_SIZE %d\n",
                                              img_sp->filename, sbuf.st_size, CSF_DATA_SIZE);
                             exit(EXIT_FAILURE);
                        }
                        imx_header.boot_data[container].img[cont_img_count].src = file_off;
                        img_sp->src = file_off;
                        imx_header.boot_data[container].img[cont_img_count].dst = tmp_to;
                        imx_header.boot_data[container].img[cont_img_count].size = CSF_DATA_SIZE;
                        imx_header.boot_data[container].img[cont_img_count].flags2 = 0;
                        imx_header.boot_data[container].img[cont_img_count].hab_flags = IMG_TYPE_CSF;
                        imx_header.boot_data[container].img[cont_img_count].flags1 = (CORE_SC & BOOT_IMG_FLAGS_CORE_MASK);
                        imx_header.fhdr[container].csf = imx_header.boot_data[container].img[cont_img_count].dst;
                        imx_header.boot_data[container].num_images++; /* csf img is count in num_images */

                        tmp_to = ALIGN((tmp_to + CSF_DATA_SIZE), IMG_AUTO_ALIGN);
                        file_off += ALIGN(CSF_DATA_SIZE, sector_size);
                        cont_img_count++;
                        break;
                case FLAG:
                        imx_header.boot_data[container].bd_flags = img_sp->entry;
                        break;
                case NEW_CONTAINER: /* move the counters forward to start on a new container */
                        container++;
                        cont_img_count=0; /* reset img count when moving to new container */
                        break;
                case PARTITION: /* keep custom partition until next executable image */
                        custom_partition = img_sp->entry;
                        break;
                case DCD:
                        break; /* skip DCD here because we already processed it */
                default:
                        fprintf(stderr, "unrecognized option in input stack");
                        exit(EXIT_FAILURE);
              }
              img_sp++;/* advance index */
        }

        /* reset counters to write output file */
        container = 0;
        cont_img_count = 0;
        /* Open output file */
        ofd = open (out_file, O_RDWR|O_CREAT|O_TRUNC|O_BINARY, 0666);
        if (ofd < 0) {
            fprintf(stderr, "%s: Can't open: %s\n",
                                out_file, strerror(errno));
            exit(EXIT_FAILURE);
        }

        /* Note: Image offset are not contained in the image */

        /* Write image header */
        if (write(ofd, &imx_header, sizeof(imx_header_v3_t)) != sizeof(imx_header_v3_t)) {
            fprintf(stderr, "error writing image hdr\n");
            exit(1);
        }

        if(emmc_fastboot)
          ivt_offset = 0;/*set ivt offset to 0 if emmc */

        /* step through the image stack again this time copying images to final bin */
        img_sp = image_stack;
        while(img_sp->option != NO_IMG){ /* stop once we reach null terminator */
          if (img_sp->option == DCD           ||
              img_sp->option == OUTPUT        ||
              img_sp->option == FLAG          ||
              img_sp->option == DEVICE        ||
              img_sp->option == NEW_CONTAINER ||
              img_sp->option == PARTITION) {
            img_sp++;
            continue;/* skip writing to the output file if not an image option */
          }
          if (img_sp->option == CSF){ /* only pad if its a CSF image */
              copy_file(ofd, img_sp->filename, CSF_DATA_SIZE, img_sp->src - ivt_offset);

          }
          else {
              copy_file(ofd, img_sp->filename, 0, img_sp->src - ivt_offset);
          }
          img_sp++;
        }

/* Close output file */
        close(ofd);
        return 0;
}

