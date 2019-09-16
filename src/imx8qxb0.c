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

#define OCRAM_START						0x00100000
#define OCRAM_END						0x00400000

#define IV_MAX_LEN			32
#define HASH_MAX_LEN			64
#define MAX_NUM_IMGS			8
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

#define HASH_STR_SHA_256		"sha256"
#define HASH_STR_SHA_384		"sha384"
#define HASH_STR_SHA_512		"sha512"

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

#define MAX_NUM_OF_CONTAINER		3

#define BOOT_IMG_META_MU_RID_SHIFT	10
#define BOOT_IMG_META_PART_ID_SHIFT	20

#define IMAGE_TYPE_MASK	0xF

#define CORE_ID_SHIFT	0x4
#define CORE_ID_MASK	0xF

#define HASH_TYPE_SHIFT	0x8
#define HASH_TYPE_MASK	0x7

#define IMAGE_ENCRYPTED_SHIFT	0x11
#define IMAGE_ENCRYPTED_MASK	0x1

#define IMAGE_A35_DEFAULT_META(PART)		(((PART == 0 ) ? PARTITION_ID_AP : PART)  << BOOT_IMG_META_PART_ID_SHIFT |\
					 SC_R_MU_0A << BOOT_IMG_META_MU_RID_SHIFT | \
					 SC_R_A35_0)

#define IMAGE_A53_DEFAULT_META(PART)		(((PART == 0 ) ? PARTITION_ID_AP : PART) << BOOT_IMG_META_PART_ID_SHIFT |\
					 SC_R_MU_0A << BOOT_IMG_META_MU_RID_SHIFT | \
					 SC_R_A53_0)

#define IMAGE_A72_DEFAULT_META(PART)		(((PART == 0 ) ? PARTITION_ID_AP : PART) << BOOT_IMG_META_PART_ID_SHIFT |\
					 SC_R_MU_0A << BOOT_IMG_META_MU_RID_SHIFT | \
					 SC_R_A72_0)

#define IMAGE_M4_0_DEFAULT_META(PART)		(((PART == 0) ? PARTITION_ID_M4 : PART) << BOOT_IMG_META_PART_ID_SHIFT |\
					 SC_R_M4_0_MU_1A << BOOT_IMG_META_MU_RID_SHIFT | \
					 SC_R_M4_0_PID0)

#define IMAGE_M4_1_DEFAULT_META(PART)		(((PART == 0) ? PARTITION_ID_M4 : PART) << BOOT_IMG_META_PART_ID_SHIFT |\
					 SC_R_M4_1_MU_1A << BOOT_IMG_META_MU_RID_SHIFT | \
					 SC_R_M4_1_PID0)

#define CONTAINER_START(CNTR_NUM)	(CNTR_NUM * CONTAINER_ALIGNMENT)

#define CONTAINER_IMAGE_ARRAY_START_OFFSET	0x2000

uint32_t scfw_flags = 0;

typedef struct {
	char type;
	char core_id;
	char hash_type;
	bool encrypted;
	uint16_t boot_flags;
} img_flags_t;

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
} __attribute__((packed)) flash_header_v3_t;

typedef struct {
	flash_header_v3_t fhdr[MAX_NUM_OF_CONTAINER];
	dcd_v2_t dcd_table;
}  __attribute__((packed)) imx_header_v3_t;

uint32_t custom_partition = 0;

static void copy_file_aligned (int ifd, const char *datafile, int offset, int align)
{
	int dfd;
	struct stat sbuf;
	unsigned char *ptr;
	uint8_t zeros[0x4000];
	int size;
	int ret;

	if (align > 0x4000) {
		fprintf (stderr, "Wrong alignment requested %d\n",
			align);
		exit (EXIT_FAILURE);
	}

	memset(zeros, 0, sizeof(zeros));

	if ((dfd = open(datafile, O_RDONLY|O_BINARY)) < 0) {
		fprintf (stderr, "Can't open %s: %s\n",
			datafile, strerror(errno));
		exit (EXIT_FAILURE);
	}

	if (fstat(dfd, &sbuf) < 0) {
		fprintf (stderr, "Can't stat %s: %s\n",
			datafile, strerror(errno));
		exit (EXIT_FAILURE);
	}

	if(sbuf.st_size == 0)
		goto close;

	ptr = mmap(0, sbuf.st_size, PROT_READ, MAP_SHARED, dfd, 0);
	if (ptr == MAP_FAILED) {
		fprintf (stderr, "Can't read %s: %s\n",
			datafile, strerror(errno));
		exit (EXIT_FAILURE);
	}

	size = sbuf.st_size;
	ret = lseek(ifd, offset, SEEK_SET);
	if (ret < 0) {
		fprintf(stderr, "%s: lseek error %s\n",
			__func__, strerror(errno));
		exit(EXIT_FAILURE);
	}

	if (write(ifd, ptr, size) != size) {
		fprintf (stderr, "Write error %s\n",
			strerror(errno));
		exit (EXIT_FAILURE);
	}

	align = ALIGN(size, align) - size;

	if (write(ifd, (char *)&zeros, align) != align) {
		fprintf(stderr, "Write error: %s\n",
			strerror(errno));
		exit(EXIT_FAILURE);
	}

	(void) munmap((void *)ptr, sbuf.st_size);
close:
	(void) close (dfd);

}

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

	if (img->size == 0)
		sprintf(sha_command, "sha%dsum /dev/null", hash_type);
	else
		sprintf(sha_command, "dd if=/dev/zero of=tmp_pad bs=%d count=1;\
				dd if=\'%s\' of=tmp_pad conv=notrunc;\
				sha%dsum tmp_pad; rm -f tmp_pad",
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
		fprintf(stdout, "CST: CONTAINER %d offset: 0x%x\n", i, file_offset + size);
		fprintf(stdout, "CST: CONTAINER %d: Signature Block: offset is at 0x%x\n", i,
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

uint32_t get_hash_algo(char *images_hash)
{
	uint32_t hash_algo = IMAGE_HASH_ALGO_DEFAULT;

	if (NULL != images_hash) {
	    if (0 == strcmp(images_hash, HASH_STR_SHA_256)) {
			hash_algo = HASH_TYPE_SHA_256;
		}
		else if (0 == strcmp(images_hash, HASH_STR_SHA_384)) {
			hash_algo = HASH_TYPE_SHA_384;
		}
		else if (0 == strcmp(images_hash, HASH_STR_SHA_512)) {
			hash_algo = HASH_TYPE_SHA_512;
		}
		else {
			fprintf(stderr,
					"\nERROR: %s is an invalid hash argument\n"
					"    Expected values: %s, %s, %s\n\n",
					images_hash, HASH_STR_SHA_256, HASH_STR_SHA_384, HASH_STR_SHA_512);
			exit(EXIT_FAILURE);
		}
	}

	fprintf(stdout, "Hash of the images = sha%d\n", hash_algo);
	return hash_algo;
}

void set_image_array_entry(flash_header_v3_t *container, soc_type_t soc,
		const image_t *image_stack, uint32_t offset,
		uint32_t size, char *tmp_filename, bool dcd_skip, char *images_hash)
{
	uint64_t entry = image_stack->entry;
	uint64_t core = image_stack->ext;
	uint32_t meta;
	char *tmp_name = "";
	option_type_t type = image_stack->option;
	boot_img_t *img = &container->img[container->num_images];

	if (container->num_images >= MAX_NUM_IMGS) {
		fprintf(stderr, "Error: Container allows 8 images at most\n");
		exit(EXIT_FAILURE);
	}

	img->offset = offset;  /* Is re-adjusted later */
	img->size = size;

	if (type != DUMMY_V2X) { /* skip hash generation here if dummy image */
		set_image_hash(img, tmp_filename, get_hash_algo(images_hash));
	}

	switch(type) {
	case SECO:
		if (container->num_images > 0) {
			fprintf(stderr, "Error: SECO container only allows 1 image\n");
			exit(EXIT_FAILURE);
		}

		img->hab_flags |= IMG_TYPE_SECO;
		img->hab_flags |= CORE_SECO << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "SECO";
		img->dst = 0x20C00000;
		img->entry = 0x20000000;

		break;
	case AP:
		if ((soc == QX || soc == DXL) && core == CORE_CA35)
			meta = IMAGE_A35_DEFAULT_META(custom_partition);
		else if (soc == QM && core == CORE_CA53)
			meta = IMAGE_A53_DEFAULT_META(custom_partition);
		else if (soc == QM && core == CORE_CA72)
			meta = IMAGE_A72_DEFAULT_META(custom_partition);
		else {
			fprintf(stderr, "Error: invalid AP core id: %" PRIi64 "\n", core);
			exit(EXIT_FAILURE);
		}
		img->hab_flags |= IMG_TYPE_EXEC;
		img->hab_flags |= CORE_CA53 << BOOT_IMG_FLAGS_CORE_SHIFT; /* On B0, only core id = 4 is valid */
		tmp_name = "AP";
		img->dst = entry;
		img->entry = entry;
		img->meta = meta;
		custom_partition = 0;
		break;
	case M4:
		if (core == 0) {
			core = CORE_CM4_0;
			meta = IMAGE_M4_0_DEFAULT_META(custom_partition);
		} else if (core == 1) {
			core = CORE_CM4_1;
			meta = IMAGE_M4_1_DEFAULT_META(custom_partition);
		} else {
			fprintf(stderr, "Error: invalid m4 core id: %" PRIi64 "\n", core);
			exit(EXIT_FAILURE);
		}
		img->hab_flags |= IMG_TYPE_EXEC;
		img->hab_flags |= core << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "M4";
		if ((entry & 0x7) != 0)
		{
			fprintf(stderr, "\n\nWarning: M4 Destination address is not 8 byte aligned\n\n");
		}
		img->dst = entry;
		img->entry = entry;
		img->meta = meta;
		custom_partition = 0;
		break;
	case DATA:
		img->hab_flags |= IMG_TYPE_DATA;
		img->hab_flags |= CORE_CA35 << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "DATA";
		img->dst = entry;
		break;
	case MSG_BLOCK:
		img->hab_flags |= IMG_TYPE_DATA;
		img->hab_flags |= CORE_CA35 << BOOT_IMG_FLAGS_CORE_SHIFT;
		img->meta = core << BOOT_IMG_META_MU_RID_SHIFT;
		tmp_name = "MSG_BLOCK";
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
	case DUMMY_V2X:
		img->hab_flags |= IMG_TYPE_V2X_DUMMY;
		img->hab_flags |= CORE_SC << BOOT_IMG_FLAGS_CORE_SHIFT;
		tmp_name = "V2X Dummy";
		set_image_hash(img, "/dev/null", IMAGE_HASH_ALGO_DEFAULT);
		img->dst = entry;
		img->entry = entry;
		img->size = 0; /* dummy image has no size */
		break;
	default:
		fprintf(stderr, "unrecognized image type (%d)\n", type);
		exit(EXIT_FAILURE);
	}

	fprintf(stdout, "%s file_offset = 0x%x size = 0x%x\n", tmp_name, offset, size);

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

int get_container_image_start_pos(image_t *image_stack, uint32_t align, soc_type_t soc, uint32_t *scu_cont_hdr_off)
{
	image_t *img_sp = image_stack;
    /*8K total container header*/
	int file_off = CONTAINER_IMAGE_ARRAY_START_OFFSET,  ofd = -1;
	flash_header_v3_t header;


	while (img_sp->option != NO_IMG) {
		if (img_sp->option == APPEND) {
			ofd = open(img_sp->filename, O_RDONLY);
			if (ofd < 0) {
				printf("Failure open first container file %s\n", img_sp->filename);
				break;
			}

			if (soc == DXL) {
				/* Skip SECO container, jump to V2X container */
				if(lseek(ofd, CONTAINER_ALIGNMENT, SEEK_SET) < 0) {
					printf("Failure Skip SECO header \n");
					exit(EXIT_FAILURE);
				}
			}

			if(read(ofd, &header, sizeof(header)) != sizeof(header)) {
				printf("Failure Read header \n");
				exit(EXIT_FAILURE);
			}

			close(ofd);

			if (header.tag != IVT_HEADER_TAG_B0) {
				printf("header tag missmatched %x\n", header.tag);
			} else if (header.num_images == 0) {
				printf("image num is 0 \n");
			} else {
				file_off = header.img[header.num_images - 1].offset + header.img[header.num_images - 1].size;
				if (soc == DXL) {
					file_off += CONTAINER_ALIGNMENT;
					*scu_cont_hdr_off = CONTAINER_ALIGNMENT + ALIGN(header.length, CONTAINER_ALIGNMENT);
				}
				else {
					*scu_cont_hdr_off = CONTAINER_ALIGNMENT;
				}
				file_off = ALIGN(file_off, align);
			}
		}

		img_sp++;
	}

	return file_off;
}


int build_container_qx_qm_b0(soc_type_t soc, uint32_t sector_size, uint32_t ivt_offset, char *out_file,
				bool emmc_fastboot, image_t *image_stack, bool dcd_skip, uint8_t fuse_version,
				uint16_t sw_version, char *images_hash)
{
	int file_off, ofd = -1;
	unsigned int dcd_len = 0;

	static imx_header_v3_t imx_header;
	image_t *img_sp = image_stack;
	struct stat sbuf;
	char *tmp_filename = NULL;
	uint32_t size = 0;
	uint32_t file_padding = 0;
	int ret;

	int container = -1;
	int cont_img_count = 0; /* indexes to arrange the container */

	memset((char *)&imx_header, 0, sizeof(imx_header_v3_t));

	if (image_stack == NULL) {
		fprintf(stderr, "Empty image stack ");
		exit(EXIT_FAILURE);
	}

	if (soc == QX)
		fprintf(stdout, "Platform:\ti.MX8QXP B0\n");
	else if (soc == QM)
		fprintf(stdout, "Platform:\ti.MX8QM B0\n");
	else if (soc == DXL)
		fprintf(stdout, "Platform:\ti.MX8DXL A0\n");

	set_imx_hdr_v3(&imx_header, dcd_len, ivt_offset, INITIAL_LOAD_ADDR_SCU_ROM, 0);
	set_imx_hdr_v3(&imx_header, 0, ivt_offset, INITIAL_LOAD_ADDR_AP_ROM, 1);

	printf("ivt_offset:\t%d\n", ivt_offset);

	file_off = get_container_image_start_pos(image_stack, sector_size, soc, &file_padding);
	printf("container image offset (aligned):%x\n", file_off);

	/* step through image stack and generate the header */
	img_sp = image_stack;

	while (img_sp->option != NO_IMG) { /* stop once we reach null terminator */
		switch (img_sp->option) {
		case AP:
		case M4:
		case SCFW:
		case DATA:
		case MSG_BLOCK:
			if (container < 0) {
				fprintf(stderr, "No container found\n");
				exit(EXIT_FAILURE);
			}
			check_file(&sbuf, img_sp->filename);
			tmp_filename = img_sp->filename;
			set_image_array_entry(&imx_header.fhdr[container],
						soc,
						img_sp,
						file_off,
						ALIGN(sbuf.st_size, sector_size),
						tmp_filename,
						dcd_skip,
						images_hash);
			img_sp->src = file_off;

			file_off += ALIGN(sbuf.st_size, sector_size);
			cont_img_count++;
			break;

		case DUMMY_V2X:
			if (container < 0) {
				fprintf(stderr, "No container found\n");
				exit(EXIT_FAILURE);
			}
			tmp_filename = "dummy";
			set_image_array_entry(&imx_header.fhdr[container],
						soc,
						img_sp,
						file_off,
						0,
						tmp_filename,
						dcd_skip,
						images_hash);
			img_sp->src = file_off;

			cont_img_count++;
			break;

		case SECO:
			if (container < 0) {
				fprintf(stderr, "No container found\n");
				exit(EXIT_FAILURE);
			}
			check_file(&sbuf, img_sp->filename);
			tmp_filename = img_sp->filename;
			set_image_array_entry(&imx_header.fhdr[container],
						soc,
						img_sp,
						file_off,
						sbuf.st_size,
						tmp_filename,
						dcd_skip,
						"sha384");
			img_sp->src = file_off;

			file_off += sbuf.st_size;
			cont_img_count++;
			break;

		case NEW_CONTAINER:
			container++;
			set_container(&imx_header.fhdr[container], sw_version,
					CONTAINER_ALIGNMENT,
					CONTAINER_FLAGS_DEFAULT,
					fuse_version);
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
		case FILEOFF:
			if (file_off > img_sp->dst)
			{
				fprintf(stderr, "FILEOFF address less than current file offset!!!\n");
				exit(EXIT_FAILURE);
			}
			if (img_sp->dst != ALIGN(img_sp->dst, sector_size))
			{
				fprintf(stderr, "FILEOFF address is not aligned to sector size!!!\n");
				exit(EXIT_FAILURE);
			}
			file_off = img_sp->dst;
			break;
		case PARTITION: /* keep custom partition until next executable image */
			custom_partition = img_sp->entry; /* use a global var for default behaviour */
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
	ret = lseek(ofd, file_padding, SEEK_SET);
	if (ret < 0) {
		fprintf(stderr, "%s: lseek error %s\n",
			__func__, strerror(errno));
		exit(EXIT_FAILURE);
	}

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
				img_sp->option == SCFW || img_sp->option == SECO || img_sp->option == MSG_BLOCK) {
			copy_file_aligned(ofd, img_sp->filename, img_sp->src, sector_size);
		}
		img_sp++;
	}

	/* Close output file */
	close(ofd);
	return 0;
}

img_flags_t parse_image_flags(uint32_t flags, char *flag_list)
{
	img_flags_t img_flags;

	strcpy(flag_list, "(");

	/* first extract the image type */
	strcat(flag_list, "IMG TYPE: ");
	img_flags.type = flags & IMAGE_TYPE_MASK;

	switch (img_flags.type) {

	case 0x3:
		strcat(flag_list, "Executable");
		break;
	case 0x4:
		strcat(flag_list, "Data");
		break;
	case 0x5:
		strcat(flag_list, "DDR Init");
		break;
	case 0x6:
		strcat(flag_list, "SECO");
		break;
	case 0x7:
		strcat(flag_list, "Provisioning");
		break;
	case 0x8:
		strcat(flag_list, "DEK validation");
		break;
	case 0xB:
		strcat(flag_list, "Primary V2X FW image");
		break;
	case 0xC:
		strcat(flag_list, "Secondary V2X FW image");
		break;
	case 0xD:
		strcat(flag_list, "V2X ROM Patch image");
		break;
	case 0xE:
		strcat(flag_list, "V2X Dummy image");
		break;
	default:
		strcat(flag_list, "Invalid img type");
		break;
	}
	strcat(flag_list, " | ");

	/* next get the core id */
	strcat(flag_list, "CORE ID: ");
	img_flags.core_id = (flags >> CORE_ID_SHIFT) & CORE_ID_MASK;

	switch (img_flags.core_id) {

	case CORE_SC:
		strcat(flag_list, "CORE_SC");
		break;
	case CORE_CM4_0:
		strcat(flag_list, "CORE_CM4_0");
		break;
	case CORE_CM4_1:
		strcat(flag_list, "CORE_CM4_1");
		break;
	case CORE_CA53:
		strcat(flag_list, "CORE_CA53");
		break;
	case CORE_CA72:
		strcat(flag_list, "CORE_CA72");
		break;
	case CORE_SECO:
		strcat(flag_list, "CORE_SECO");
		break;
	case CORE_V2X_P:
		strcat(flag_list, "CORE_V2X_P");
		break;
	case CORE_V2X_S:
		strcat(flag_list, "CORE_V2X_S");
		break;
	default:
		strcat(flag_list, "Invalid core id");
		break;

	}
	strcat(flag_list, " | ");

	/* next get the hash type */
	strcat(flag_list, "HASH TYPE: ");
	img_flags.hash_type = (flags >> HASH_TYPE_SHIFT) & HASH_TYPE_MASK;

	switch (img_flags.hash_type) {

	case 0x0:
		strcat(flag_list, "SHA256");
		break;
	case 0x1:
		strcat(flag_list, "SHA384");
		break;
	case 0x2:
		strcat(flag_list, "SHA512");
		break;
	default:
		break;
	}
	strcat(flag_list, " | ");

	/* lastly, read the encrypted bit */
	strcat(flag_list, "ENCRYPTED: ");
	img_flags.encrypted = (flags >> IMAGE_ENCRYPTED_SHIFT) & IMAGE_ENCRYPTED_MASK;

	if (img_flags.encrypted)
		strcat(flag_list, "YES");
	else
		strcat(flag_list, "NO");

	/* terminate flag string */
	strcat(flag_list, ")");

	return img_flags;
}

void print_image_array_fields(flash_header_v3_t *container_hdrs)
{
	boot_img_t img; /* image array entry */
	img_flags_t img_flags; /* image hab flags */
	int hash_length = 0;
	int num_images = 0;
	char img_name[32]; /* scfw, bootloader, etc. */
	char hash_name[8]; /* sha256, sha384, or sha512 */
	char flag_string[128]; /* text representation of image hab flags */

	/* get the number of image array entries from the container heaer */
	num_images = container_hdrs->num_images;

	for (int i = 0; i < num_images; i++) {
		/* get the next image array entry */
		img = container_hdrs->img[i];

		/* get the image flags */
		img_flags = parse_image_flags(img.hab_flags, flag_string);

		/* determine the type of image */
		switch (img_flags.type) {

		case 0x3:
			if (img_flags.core_id == CORE_SC)
				strcpy(img_name, "SCFW");
			else if ((img_flags.core_id == CORE_CA53) || (img_flags.core_id == CORE_CA72))
				strcpy(img_name, "Bootloader");
			else if (img_flags.core_id == CORE_CM4_0)
				strcpy(img_name, "M4_0");
			else if (img_flags.core_id == CORE_CM4_1)
				strcpy(img_name, "M4_1");
			break;
		case 0x4:
			strcpy(img_name, "Data");
			break;
		case 0x5:
			strcpy(img_name, "DDR Init");
			break;
		case 0x6:
			strcpy(img_name, "SECO FW");
			break;
		case 0x7:
			strcpy(img_name, "Provisioning");
			break;
		case 0x8:
			strcpy(img_name, "DEK Validation");
			break;
		case 0xB:
			strcpy(img_name, "Primary V2X FW image");
			break;
		case 0xC:
			strcpy(img_name, "Secondary V2X FW image");
			break;
		case 0xD:
			strcpy(img_name, "V2X ROM Patch image");
			break;
		case 0xE:
			strcpy(img_name, "V2X Dummy image");
			break;
		default:
			strcpy(img_name, "Unknown image");
			break;
		}

		/* get the image hash type */
		switch (img_flags.hash_type) {

		case 0x0:
			hash_length = 256 / 8;
			strcpy(hash_name, "SHA256");
			break;
		case 0x1:
			hash_length = 384 / 8;
			strcpy(hash_name, "SHA384");
			break;
		case 0x2:
			hash_length = 512 / 8;
			strcpy(hash_name, "SHA512");
			break;
		default:
			strcpy(hash_name, "Unknown");
			break;
		}

		/* print the image array fields */
		fprintf(stdout, "%sIMAGE %d (%s)%s\n", "\x1B[33m", i+1, img_name, "\x1B[37m");
		fprintf(stdout, "Offset: %#X\n", img.offset);
		fprintf(stdout, "Size: %#X (%d)\n", img.size, img.size);
		fprintf(stdout, "Load Addr: %#lX\n", img.dst);
		fprintf(stdout, "Entry Addr: %#lX\n", img.entry);
		fprintf(stdout, "Flags: %#X %s\n", img.hab_flags, flag_string);

		/* only print metadata and hash if the image isn't DDR init */
		if (img_flags.type != 0x5) {
			fprintf(stdout, "Metadata: %#X\n", img.meta);

			/* print the image hash */
			fprintf(stdout, "Hash: ");
			for (int i = 0; i < hash_length; i++)
				fprintf(stdout, "%02x", img.hash[i]);

			fprintf(stdout, " (%s)\n", hash_name);

		}
		fprintf(stdout, "\n");
	}
}

void print_container_hdr_fields(flash_header_v3_t *container_hdrs, int num_cntrs)
{

	for (int i = 0; i < num_cntrs; i++) {
		fprintf(stdout, "\n");
		fprintf(stdout, "*********************************\n");
		fprintf(stdout, "*				*\n");
		fprintf(stdout, "*          CONTAINER %d          *\n", i+1);
		fprintf(stdout, "*				*\n");
		fprintf(stdout, "*********************************\n\n");
		fprintf(stdout, "%16s", "Length: ");
		fprintf(stdout, "%#X (%d)\n", container_hdrs->length, container_hdrs->length);
		fprintf(stdout, "%16s", "Tag: ");
		fprintf(stdout, "%#X\n", container_hdrs->tag);
		fprintf(stdout, "%16s", "Version: ");
		fprintf(stdout, "%#X\n", container_hdrs->version);
		fprintf(stdout, "%16s", "Flags: ");
		fprintf(stdout, "%#X\n", container_hdrs->flags);
		fprintf(stdout, "%16s", "Num images: ");
		fprintf(stdout, "%d\n", container_hdrs->num_images);
		fprintf(stdout, "%16s", "Fuse version: ");
		fprintf(stdout, "%#X\n", container_hdrs->fuse_version);
		fprintf(stdout, "%16s", "SW version: ");
		fprintf(stdout, "%#X\n", container_hdrs->sw_version);
		fprintf(stdout, "%16s", "Sig blk offset: ");
		fprintf(stdout, "%#X\n\n", container_hdrs->sig_blk_offset);

		print_image_array_fields(container_hdrs);

		container_hdrs++;
	}

}

int extract_container_images(flash_header_v3_t *container_hdr, char *ifname, int num_cntrs, int ifd, soc_type_t soc)
{
	uint32_t img_offset = 0; /* image offset from container header */
	uint32_t img_size = 0; /* image size */
	uint32_t file_off = 0; /* current offset within container binary */
	const uint32_t pad = 0;
	int ofd = 0;
	int ret = 0;
	uint32_t seco_off = 0, seco_size = 0;
	char dd_cmd[512]; /* dd cmd to extract each image from container binary */
	struct stat buf;
	FILE *f_ptr = NULL; /* file pointer to the dd process */
	char *mem_ptr; /* pointer to input container in memory */

	fprintf(stdout, "Extracting container images...\n");

	/* create output directory if it does not exist */
	if (stat("extracted_imgs", &buf) == -1)
		mkdir("extracted_imgs", S_IRWXU|S_IRWXG|S_IRWXO);

	/* open container binary and map to memory */
	fstat(ifd, &buf);
	mem_ptr = mmap(NULL, buf.st_size, PROT_READ, MAP_SHARED, ifd, 0);

	for (int i = 0; i < num_cntrs; i++) {
		for (int j = 0; j < container_hdr->num_images; j++) {

			/* (re)initialize command buffer */
			memset(dd_cmd, 0, sizeof(dd_cmd));

			/* first get the image offset and size from the container header */
			img_offset = container_hdr->img[j].offset;
			img_size = container_hdr->img[j].size;

			if (!img_size) { /* check for images with zero size (DDR Init) */
				continue;

			} else if ((i == 0) && (soc != DXL)) { /* first container is always SECO FW */


				/* open output file */
				ofd = open("extracted_imgs/ahab-container.img", O_CREAT|O_WRONLY, S_IRWXU|S_IRWXG|S_IRWXO);

				/* first copy container header to output image */
				ret = write(ofd, (void *)mem_ptr, 1024);
				if (ret < 0)
					fprintf(stderr, "Error writing to output file\n");


				/* next, pad the output with zeros until the start of the image */
				for (int i = 0; i < (img_offset-CONTAINER_ALIGNMENT)/4; i++)
					ret = write(ofd, (void *)&pad, 4);

				/* now write the fw image to the output file */
				ret = write(ofd, (void *)(mem_ptr+img_offset), img_size);
				if (ret < 0)
					fprintf(stderr, "Error writing to output file\n");


				/* close output file and unmap input file */
				close(ofd);

				fprintf(stdout, "Container %d Image %d -> extracted_imgs/ahab-container.img\n", i+1, j+1);

			} else if ((i < 2 ) && (soc == DXL)) { /* Second Container is Always V2X for DXL */

				if (i == 0)
				{
					/* open output file */
					ofd = open("extracted_imgs/ahab-container.img", O_CREAT|O_WRONLY, S_IRWXU|S_IRWXG|S_IRWXO);

					/* first copy container header to output image */
					ret = write(ofd, (void *)mem_ptr, 0x400);
					if (ret < 0)
						fprintf(stderr, "Error writing to output file1\n");

					/* For DXL go to next container to copy header */
					seco_off = img_offset;
					seco_size = img_size;
					continue;
				}
				else if (i == 1 && j == 0)
				{ /* copy v2x container header and seco fw */
					ret = write(ofd,(void *) mem_ptr + file_off, container_hdr->length);
					if (ret < 0)
						fprintf(stderr, "Error writing to output file2\n");


					/* next, pad the output with zeros until the start of SECO image */
					for (int i = 0; i < (seco_off - (file_off + container_hdr->length))/4; i++)
						ret = write(ofd, (void *)&pad, 4);

					/* now write the SECO fw image to the output file */
					ret = write(ofd, (void *)(mem_ptr+seco_off), seco_size);
					if (ret < 0)
						fprintf(stderr, "Error writing to output file3: %x\n",ret);
				}

				/* now write the next image to the output file */
				ret = write(ofd, (void *)(mem_ptr + file_off + img_offset), img_size);
				if (ret < 0)
					fprintf(stderr, "Error writing to output file4: %x\n",ret);

				/* Iterate through V2X container for other images */
				if(j < (container_hdr->num_images - 1))
					continue;

				/* close output file and unmap input file */
				close(ofd);


				fprintf(stdout, "Container %d Image %d -> extracted_imgs/v2x-container.img\n", i+1, j+1);

			} else {
				sprintf(dd_cmd, "dd if=%s of=extracted_imgs/container%d_img%d.bin ibs=1 skip=%d count=%d conv=notrunc > /dev/null 2>&1", \
						ifname, i+1, j+1, file_off+img_offset, img_size);
				fprintf(stdout, "Container %d Image %d -> extracted_imgs/container%d_img%d.bin\n", i+1, j+1, i+1, j+1);
			}

			/* run dd command to extract current image from container */
			f_ptr = popen(dd_cmd, "r");
			if (f_ptr == NULL) {
				fprintf(stderr, "Failed to extract image\n");
				exit(EXIT_FAILURE);
			}

			/* close the pipe */
			pclose(f_ptr);
		}

		file_off += ALIGN(container_hdr->length, CONTAINER_ALIGNMENT);
		container_hdr++;
	}

	munmap((void *)mem_ptr, buf.st_size);
	fprintf(stdout, "Done\n\n");
	return 0;
}

int parse_container_hdrs_qx_qm_b0(char *ifname, bool extract, soc_type_t soc)
{
	int ifd; /* container file descriptor */
	int max_containers = (soc == DXL) ? 3 : 2;
	int cntr_num = 0; /* number of containers in binary */
	int file_off = 0; /* offset within container binary */
	int img_array_entries = 0; /* number of images in container */
	ssize_t rd_err;
	flash_header_v3_t container_headers[MAX_NUM_OF_CONTAINER];

	/* initialize region of memory where flash header will be stored */
	memset((void *)container_headers, 0, sizeof(container_headers));

	/* open container binary */
	ifd = open(ifname, O_RDONLY|O_BINARY);

	while (cntr_num < max_containers) {

		/* read in next container header up to the image array */
		rd_err = read(ifd, (void *)&container_headers[cntr_num], 16);
		if (rd_err == -1) {
			fprintf(stderr, "Error reading from input binary\n");
			exit(EXIT_FAILURE);
		}

		/* check that the current container has a valid tag */
		if (container_headers[cntr_num].tag != IVT_HEADER_TAG_B0)
			break;

		if (container_headers[cntr_num].num_images > MAX_NUM_IMGS) {
			fprintf(stderr, "This container includes %d images, beyond max 8 images\n",
				container_headers[cntr_num].num_images);
			exit(EXIT_FAILURE);
		}

		/* compute the size of the image array */
		img_array_entries = container_headers[cntr_num].num_images * sizeof(boot_img_t);

		/* read in the full image array */
		rd_err = read(ifd, (void *)&container_headers[cntr_num].img, img_array_entries);
		if (rd_err == -1) {
			fprintf(stderr, "Error reading from input binary\n");
			exit(EXIT_FAILURE);
		}

		/* read in signature block header */
		lseek(ifd, file_off + container_headers[cntr_num].sig_blk_offset, SEEK_SET);
		rd_err = read(ifd, (void *)&container_headers[cntr_num].sig_blk_hdr, sizeof(sig_blk_hdr_t));
		if (rd_err == -1) {
			fprintf(stderr, "Error reading from input binary\n");
			exit(EXIT_FAILURE);
		}

		/* seek to next container in binary */
		file_off += ALIGN(container_headers[cntr_num].length, CONTAINER_ALIGNMENT);
		lseek(ifd, file_off, SEEK_SET);

		/* increment current container count */
		cntr_num++;
	}


	print_container_hdr_fields(container_headers, cntr_num);

	if (extract)
		extract_container_images(container_headers, ifname, cntr_num, ifd, soc);

	close(ifd);

	return 0;

}
