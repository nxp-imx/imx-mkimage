/*
 * Copyright 2018 NXP
 *
 * SPDX-License-Identifier:     GPL-2.0+
 * derived from u-boot's mkimage utility
 *
 */

#include "mkimage_common.h"

#include <inttypes.h>
#include <stdio.h>

#define OCRAM_START                     0x00100000
#define OCRAM_END                       0x00400000

#define IV_MAX_LEN			32
#define HASH_MAX_LEN			64
#define MAX_NUM_IMGS			6
#define MAX_NUM_SRK_RECORDS		4

#define IVT_HEADER_TAG_B0		0x87
#define IVT_VERSION_B0			0x00

#define IMG_FLAG_HASH_SHA256		0x000
#define IMG_FLAG_HASH_SHA384		0x100
#define IMG_FLAG_HASH_SHA512		0x200

#define IMG_FLAG_ENCRYPTED_MASK		0x400
#define IMG_FLAG_ENCRYPTED_SHIFT	0x0A

#define IMG_FLAG_BOOTFLAGS_MASK		0xFFFF0000
#define IMG_FLAG_BOOTFLAGS_SHIFT	0x10

#define IMG_ARRAY_ENTRY_SIZE		128
#define HEADER_IMG_ARRAY_OFFSET		0x10

#define HASH_TYPE_SHA_256		256
#define HASH_TYPE_SHA_384		384
#define HASH_TYPE_SHA_512		512

#define IMAGE_HASH_ALGO_DEFAULT		384
#define IMAGE_PADDING_DEFAULT		0x1000

#define DCD_ENTRY_ADDR_IN_SCFW		0x240

#define CONTAINER_ALIGNMENT		0x400
#define CONTAINER_FLAGS_DEFAULT		0x10
#define CONTAINER_FUSE_DEFAULT		0x0

#define SIGNATURE_BLOCK_HEADER_LENGTH	0x10

#define MAX_NUM_OF_CONTAINER		2

#define FILE_INITIAL_PADDING		0x0
#define FIRST_CONTAINER_HEADER_LENGTH	0x400

#define IMAGE_AP_DEFAULT_META		0x001355FC
#define IMAGE_M4_DEFAULT_META		0x0004A516

#define SECOND_CONTAINER_IMAGE_ARRAY_START_OFFEST	0x7000

uint32_t scfw_flags = 0;

typedef struct {
	uint8_t version;
	uint16_t length;
	uint8_t tag;
	uint16_t srk_table_offset;
	uint16_t cert_offset;
	uint16_t blob_offset;
	uint16_t signature_offset;
	uint32_t reserved;
} __attribute__((packed)) sig_blk_hdr_t;

typedef struct {
	uint32_t offset;
	uint32_t size;
	uint64_t dst;
	uint64_t entry;
	uint32_t hab_flags;
	uint32_t meta;
	uint8_t hash[HASH_MAX_LEN];
	uint8_t iv[IV_MAX_LEN];
} __attribute__((packed)) boot_img_t;

typedef struct {
	uint8_t version;
	uint16_t length;
	uint8_t tag;
	uint32_t flags;
	uint16_t sw_version;
	uint8_t fuse_version;
	uint8_t num_images;
	uint16_t sig_blk_offset;
	uint16_t reserved;
	boot_img_t img[MAX_NUM_IMGS];
	sig_blk_hdr_t sig_blk_hdr;
	uint32_t sigblk_size;
	uint32_t padding;
}  __attribute__((packed)) flash_header_v3_t;

typedef struct {
	flash_header_v3_t fhdr[MAX_NUM_OF_CONTAINER];
	dcd_v2_t dcd_table;
}  __attribute__((packed)) imx_header_v3_t;

static void set_imx_hdr_v3(imx_header_v3_t *imxhdr, uint32_t dcd_len,
		uint32_t flash_offset, uint32_t hdr_base, uint32_t cont_id)
{
	flash_header_v3_t *fhdr_v3 = &imxhdr->fhdr[cont_id];

	/* Set magic number */
	fhdr_v3->tag = IVT_HEADER_TAG_B0;
	fhdr_v3->version = IVT_VERSION_B0;
}

void set_image_hash(boot_img_t *img, char *filename, uint32_t hash_type)
{
	FILE *fp = NULL;
	char sha_command[512];
	char hash[2 * HASH_MAX_LEN + 1];

	printf("SHA: %d %s %d\n", img->size, filename, hash_type);

	sprintf(sha_command, "dd if=/dev/zero of=tmp_pad bs=%d count=1;\
			dd if=\'%s\' of=tmp_pad conv=notrunc; sha%dsum tmp_pad; rm -f tmp_pad",
			img->size, filename, hash_type);

	switch(hash_type) {
	case HASH_TYPE_SHA_256:
		img->hab_flags |= IMG_FLAG_HASH_SHA256;
		break;
	case HASH_TYPE_SHA_384:
		img->hab_flags |= IMG_FLAG_HASH_SHA384;
		break;
	case HASH_TYPE_SHA_512:
		img->hab_flags |= IMG_FLAG_HASH_SHA512;
		break;
	default:
		fprintf(stderr, "Wrong hash type selected (%d) !!!\n\n",
				hash_type);
		exit(EXIT_FAILURE);
		break;
	}
	memset(img->hash, 0, HASH_MAX_LEN);

	fp = popen(sha_command, "r");
	if (fp == NULL) {
		fprintf(stderr, "Failed to run command hash\n" );
		exit(EXIT_FAILURE);
	}

	if(fgets(hash, hash_type / 4 + 1, fp) == NULL) {
		fprintf(stderr, "Failed to hash file: %s\n", filename);
		exit(EXIT_FAILURE);
	}

	for(int i = 0; i < strlen(hash)/2; i++){
		sscanf(hash + 2*i, "%02hhx", &img->hash[i]);
	}

	pclose(fp);
}

#define append(p, s, l) do {memcpy(p, (uint8_t *)s, l); p += l; } while (0)

uint8_t *flatten_container_header(imx_header_v3_t *imx_header,
					uint8_t containers_count,
					uint32_t *size_out, uint32_t file_offset)
{
	uint8_t *flat = NULL;
	uint8_t *ptr = NULL;
	uint16_t size = 0;

	/* Compute size of all container headers */
	for (int i = 0; i < containers_count; i++) {

		flash_header_v3_t *container = &imx_header->fhdr[i];

		container->sig_blk_offset = HEADER_IMG_ARRAY_OFFSET +
			container->num_images * IMG_ARRAY_ENTRY_SIZE;

		container->length = HEADER_IMG_ARRAY_OFFSET +
			(IMG_ARRAY_ENTRY_SIZE * container->num_images) + sizeof(sig_blk_hdr_t);

		/* Print info needed by CST to sign the container header */
		fprintf(stderr, "CST: CONTAINER %d offset: 0x%x\n", i, file_offset + size);
		fprintf(stderr, "CST: CONTAINER %d: Signature Block: offset is at 0x%x\n", i,
						file_offset + size + container->length - SIGNATURE_BLOCK_HEADER_LENGTH);

		size += ALIGN(container->length, container->padding);
	}

	flat = calloc(size, sizeof(uint8_t));
	if (!flat) {
		fprintf(stderr, "Failed to allocate memory (%d)\n", size);
		exit(EXIT_FAILURE);
	}

	ptr = flat;
	*size_out = size;

	for (int i = 0; i < containers_count; i++) {

		flash_header_v3_t *container = &imx_header->fhdr[i];
		uint32_t container_start_offset = ptr - flat;

		/* Append container header */
		append(ptr, container, HEADER_IMG_ARRAY_OFFSET);

		/* Adjust images offset to start from container headers start */
		for (int j = 0; j < container->num_images; j++) {
			container->img[j].offset -= container_start_offset + file_offset;
		}
		/* Append each image array entry */
		for (int j = 0; j < container->num_images; j++) {
			append(ptr, &container->img[j], sizeof(boot_img_t));
		}

		append(ptr, &container->sig_blk_hdr, sizeof(sig_blk_hdr_t));

		/* Padding for container (if necessary) */
		ptr += ALIGN(container->length, container->padding) - container->length;
	}

	return flat;
}

uint64_t read_dcd_offset(char *filename)
{
	int dfd;
	struct stat sbuf;
	uint8_t *ptr;
	uint64_t offset = 0;

	dfd = open(filename, O_RDONLY|O_BINARY);
	if (dfd < 0) {
	        fprintf(stderr, "Can't open %s: %s\n", filename, strerror(errno));
	        exit(EXIT_FAILURE);
	}

	if (fstat(dfd, &sbuf) < 0) {
		fprintf(stderr, "Can't stat %s: %s\n", filename, strerror(errno));
	        exit(EXIT_FAILURE);
	}

	ptr = mmap(0, sbuf.st_size, PROT_READ, MAP_SHARED, dfd, 0);
	if (ptr == MAP_FAILED) {
	        fprintf(stderr, "Can't read %s: %s\n", filename, strerror(errno));
	        exit(EXIT_FAILURE);
	}

	offset = *(uint32_t *)(ptr + DCD_ENTRY_ADDR_IN_SCFW);

	(void) munmap((void *)ptr, sbuf.st_size);
	(void) close(dfd);

	return offset;
}

void set_image_array_entry(flash_header_v3_t *container, option_type_t type, uint32_t offset,
		uint32_t size, uint64_t dst, uint64_t entry, char *tmp_filename, bool dcd_skip)
{
	boot_img_t *img = &container->img[container->num_images];
	img->offset = offset;  /* Is re-adjusted later */
	img->size = size;
	char *tmp_name = "";

	set_image_hash(img, tmp_filename, IMAGE_HASH_ALGO_DEFAULT);

	switch(type) {
	case SECO:
		img->hab_flags |= IMG_TYPE_SECO;
		img->hab_flags |= CORE_SC << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "SECO";
		break;
	case AP:
		img->hab_flags |= IMG_TYPE_EXEC;
		img->hab_flags |= CORE_CA35 << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "AP";
		img->dst = entry;
		img->entry = entry;
		img->meta = IMAGE_AP_DEFAULT_META;
		break;
	case M4:
		img->hab_flags |= IMG_TYPE_EXEC;
		img->hab_flags |= CORE_CM4_0 << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "M4";
		img->dst = entry;
		img->entry = entry;
		img->meta = IMAGE_M4_DEFAULT_META;
		break;
	case DATA:
		img->hab_flags = IMG_TYPE_DATA;
		img->hab_flags |= CORE_CA35 << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "DATA";
		img->dst = entry;
		break;
	case SCFW:
		img->hab_flags |= scfw_flags & 0xFFFF0000;
		img->hab_flags |= IMG_TYPE_EXEC;
		img->hab_flags |= CORE_SC << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "SCFW";
		img->dst = 0x1FFE0000;
		img->entry = 0x1FFE0000;

		/* Lets add the DCD now */
		if (!dcd_skip) {
			container->num_images++;
			img = &container->img[container->num_images];
			img->hab_flags |= IMG_TYPE_DCD_DDR;
			img->hab_flags |= CORE_SC << BOOT_IMG_FLAGS_CORE_SHIFT;
			set_image_hash(img, "/dev/null", IMAGE_HASH_ALGO_DEFAULT);
			img->offset = offset + img->size;
			img->entry = read_dcd_offset(tmp_filename);
			img->dst = img->entry - 1;
		}
		break;
	default:
		fprintf(stderr, "unrecognized image type (%d)\n", type);
		exit(EXIT_FAILURE);
	}

	fprintf(stdout, "%s size = %d\n", tmp_name, size);

	container->num_images++;
}

void set_container(flash_header_v3_t *container,  uint16_t sw_version,
			uint32_t alignment, uint32_t flags, uint16_t fuse_version)
{
	container->sig_blk_hdr.tag = 0x90;
	container->sig_blk_hdr.length = sizeof(sig_blk_hdr_t);
	container->sw_version = sw_version;
	container->padding = alignment;
	container->fuse_version = fuse_version;
	container->flags = flags;
	printf("flags: 0x%x\n", container->flags);
}

int get_container2_image_start_pos(image_t *image_stack)
{
	image_t *img_sp = image_stack;
	int file_off = SECOND_CONTAINER_IMAGE_ARRAY_START_OFFEST + FILE_INITIAL_PADDING,  ofd = -1;
	flash_header_v3_t header;

	while (img_sp->option != NO_IMG) {

                if (img_sp->option == APPEND) {
			ofd = open(img_sp->filename, O_RDONLY);
			if (ofd < 0) {
				printf("Failure open first container file %s\n", img_sp->filename);
				break;
			}

			if(read(ofd, &header, sizeof(header)) != sizeof(header))
				printf("Failure Read header \n");

			close(ofd);

			if (header.tag != IVT_HEADER_TAG_B0) {
				printf("header tag missmatched \n");
			} else {
				return header.img[0].size + 0x2000; /*8K total container header*/
			}
		}

		img_sp++;
        }

	return file_off;
}

int build_container_qx_b0(uint32_t sector_size, uint32_t ivt_offset, char *out_file,
				bool emmc_fastboot, image_t *image_stack, bool dcd_skip)
{
	int file_off, ofd = -1;
	unsigned int dcd_len = 0;

	static imx_header_v3_t imx_header;
	image_t *img_sp = image_stack;
	struct stat sbuf;
	char *tmp_filename = NULL;
	uint32_t size = 0;
	uint32_t file_padding = FIRST_CONTAINER_HEADER_LENGTH + FILE_INITIAL_PADDING;

	int container = -1;
	int cont_img_count = 0; /* indexes to arrange the container */

	memset((char *)&imx_header, 0, sizeof(imx_header_v3_t));

	if (image_stack == NULL) {
		fprintf(stderr, "Empty image stack ");
		exit(EXIT_FAILURE);
	}

	fprintf(stdout, "Platform:\ti.MX8QXP B0\n");

	set_imx_hdr_v3(&imx_header, dcd_len, ivt_offset, INITIAL_LOAD_ADDR_SCU_ROM, 0);
	set_imx_hdr_v3(&imx_header, 0, ivt_offset, INITIAL_LOAD_ADDR_AP_ROM, 1);

	printf("ivt_offset:\t%d\n", ivt_offset);

	file_off = get_container2_image_start_pos(image_stack);
	file_off = ALIGN(file_off, sector_size);

	printf("container2 image off 0x%x\n", file_off);

	/* step through image stack and generate the header */
	img_sp = image_stack;

	while (img_sp->option != NO_IMG) { /* stop once we reach null terminator */
		switch (img_sp->option) {
		case AP:
		case M4:
		case SECO:
		case SCFW:
		case DATA:
			check_file(&sbuf, img_sp->filename);
			tmp_filename = img_sp->filename;
			set_image_array_entry(&imx_header.fhdr[container],
						img_sp->option,
						file_off,
						ALIGN(sbuf.st_size, sector_size),
						img_sp->dst,
						img_sp->entry,
						tmp_filename,
						dcd_skip);
			img_sp->src = file_off;

			file_off += ALIGN(sbuf.st_size, sector_size);
			cont_img_count++;
			break;

		case NEW_CONTAINER:
			container++;
			set_container(&imx_header.fhdr[container], 0xCAFE,
					CONTAINER_ALIGNMENT,
					CONTAINER_FLAGS_DEFAULT,
					CONTAINER_FUSE_DEFAULT);
			cont_img_count = 0; /* reset img count when moving to new container */
                        scfw_flags = 0;
			break;

		case APPEND:
			/* nothing to do here, the container is appended in the output */
			break;
                case FLAG:
                        /* override the flags for scfw in current container */
                        scfw_flags = img_sp->entry & 0xFFFF0000;/* mask off bottom 16 bits */
                        break;
		default:
			fprintf(stderr, "unrecognized option in input stack (%d)\n", img_sp->option);
			exit(EXIT_FAILURE);
		}
		img_sp++;/* advance index */
	}

	/* Open output file */
	ofd = open(out_file, O_RDWR|O_CREAT|O_TRUNC|O_BINARY, 0666);
	if (ofd < 0) {
		fprintf(stderr, "%s: Can't open: %s\n",
				out_file, strerror(errno));
		exit(EXIT_FAILURE);
	}

	/* Append container (if specified) */
	img_sp = image_stack;
	do {
		if (img_sp->option == APPEND) {
			copy_file(ofd, img_sp->filename, 0, 0);
		}
		img_sp++;
	} while (img_sp->option != NO_IMG);

	/* Add padding or skip appended container */
	lseek(ofd, file_padding, SEEK_SET);

	/* Note: Image offset are not contained in the image */
	uint8_t *tmp = flatten_container_header(&imx_header, container + 1, &size, file_padding);
	/* Write image header */
	if (write(ofd, tmp, size) != size) {
		fprintf(stderr, "error writing image hdr\n");
		exit(1);
	}

	/* Clean-up memory used by the headers */
	free(tmp);

	if (emmc_fastboot)
		ivt_offset = 0;/*set ivt offset to 0 if emmc */

	/* step through the image stack again this time copying images to final bin */
	img_sp = image_stack;
	while (img_sp->option != NO_IMG) { /* stop once we reach null terminator */
		if (img_sp->option == M4 || img_sp->option == AP || img_sp->option == DATA || img_sp->option == SCD ||
				img_sp->option == SCFW || img_sp->option == SECO) {
			copy_file(ofd, img_sp->filename, 0, img_sp->src);
		}
		img_sp++;
	}

	/* Close output file */
	close(ofd);
	return 0;
}

