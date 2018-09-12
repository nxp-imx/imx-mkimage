/*
 * Copyright (C) 2016 Freescale Semiconductor, Inc.
 *
 * SPDX-License-Identifier:	GPL-2.0+
 * derived from u-boot's mkimage utility
 *
 */

#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <sys/stat.h>
#include <getopt.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <zlib.h>

#ifndef O_BINARY
#define O_BINARY 0
#endif

#undef offsetof
#define offsetof(TYPE, MEMBER) ((size_t) &((TYPE *)0)->MEMBER)

typedef struct {
	uint32_t addr;
	uint32_t value;
} dcd_addr_data_t;

typedef struct {
	uint8_t tag;
	uint16_t length;
	uint8_t version;
} __attribute__((packed)) ivt_header_t;

typedef struct {
	uint8_t tag;
	uint16_t length;
	uint8_t param;
} __attribute__((packed)) write_dcd_command_t;

#define MAX_HW_CFG_SIZE_V2 1017
struct dcd_v2_cmd {
	write_dcd_command_t write_dcd_command; /*4*/
	dcd_addr_data_t addr_data[MAX_HW_CFG_SIZE_V2]; /*8136*/
} __attribute__((packed));

typedef struct {
	ivt_header_t header;
	struct dcd_v2_cmd dcd_cmd;
	uint32_t padding[1]; /* end up on an 8-byte boundary */
} dcd_v2_t;

typedef struct {
	uint32_t start;
	uint32_t size;
	uint32_t plugin;
	uint32_t padding[1];
} boot_data_t;

typedef struct {
	ivt_header_t header;
	uint32_t entry;
	uint32_t reserved1;
	uint32_t dcd_ptr;
	uint32_t boot_data_ptr;
	uint32_t self;
	uint32_t csf;
	uint32_t reserved2;
} flash_header_v2_t;

typedef struct {
	flash_header_v2_t fhdr;
	boot_data_t boot_data;
	uint32_t alignment[4];
} imx_header_v2_t;


#define IH_MAGIC	0x27051956	/* Image Magic Number		*/
#define IH_NMLEN		32	/* Image Name Length		*/

typedef struct uimage_header {
	uint32_t		ih_magic;	/* Image Header Magic Number	*/
	uint32_t		ih_hcrc;	/* Image Header CRC Checksum	*/
	uint32_t		ih_time;	/* Image Creation Timestamp	*/
	uint32_t		ih_size;	/* Image Data Size		*/
	uint32_t		ih_load;	/* Data	 Load  Address		*/
	uint32_t		ih_ep;		/* Entry Point Address		*/
	uint32_t		ih_dcrc;	/* Image Data CRC Checksum	*/
	uint8_t			ih_os;		/* Operating System		*/
	uint8_t			ih_arch;	/* CPU architecture		*/
	uint8_t			ih_type;	/* Image Type			*/
	uint8_t			ih_comp;	/* Compression Type		*/
	uint8_t			ih_name[IH_NMLEN];	/* Image Name		*/
} uimage_header_t;

struct fdt_header {
	uint32_t magic;			 /* magic word FDT_MAGIC */
	uint32_t totalsize;		 /* total size of DT block */
	uint32_t off_dt_struct;		 /* offset to structure */
	uint32_t off_dt_strings;		 /* offset to strings */
	uint32_t off_mem_rsvmap;		 /* offset to memory reserve map */
	uint32_t version;		 /* format version */
	uint32_t last_comp_version;	 /* last compatible version */

	/* version 2 fields below */
	uint32_t boot_cpuid_phys;	 /* Which physical CPU id we're
					    booting on */
	/* version 3 fields below */
	uint32_t size_dt_strings;	 /* size of the strings block */

	/* version 17 fields below */
	uint32_t size_dt_struct;		 /* size of the structure block */
};

/* Command tags and parameters */
#define HAB_DATA_WIDTH_BYTE 1 /* 8-bit value */
#define HAB_DATA_WIDTH_HALF 2 /* 16-bit value */
#define HAB_DATA_WIDTH_WORD 4 /* 32-bit value */
#define HAB_CMD_WRT_DAT_MSK 1 /* mask/value flag */
#define HAB_CMD_WRT_DAT_SET 2 /* set/clear flag */
#define HAB_CMD_CHK_DAT_SET 2 /* set/clear flag */
#define HAB_CMD_CHK_DAT_ANY 4 /* any/all flag */
#define HAB_CMD_WRT_DAT_FLAGS_WIDTH   5 /* flags field width */
#define HAB_CMD_WRT_DAT_FLAGS_SHIFT   3 /* flags field offset */
#define HAB_CMD_WRT_DAT_BYTES_WIDTH   3 /* bytes field width */
#define HAB_CMD_WRT_DAT_BYTES_SHIFT   0 /* bytes field offset */

#define IVT_HEADER_TAG			0xD1
#define IVT_VERSION			0x41
#define DCD_HEADER_TAG			0xD2
#define DCD_VERSION			0x41
#define DCD_WRITE_DATA_COMMAND_TAG	0xCC
#define DCD_WRITE_DATA_PARAM		(HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT) /* 0x4 */
#define DCD_WRITE_CLR_BIT_PARAM		((HAB_CMD_WRT_DAT_MSK << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0xC */
#define DCD_WRITE_SET_BIT_PARAM		((HAB_CMD_WRT_DAT_MSK << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_CMD_WRT_DAT_SET << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0x1C */
#define DCD_CHECK_DATA_COMMAND_TAG	0xCF
#define DCD_CHECK_BITS_CLR_PARAM	(HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT) /* 0x04 */
#define DCD_CHECK_BITS_SET_PARAM	((HAB_CMD_CHK_DAT_SET << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0x14 */
#define DCD_CHECK_ANY_BIT_CLR_PARAM	((HAB_CMD_CHK_DAT_ANY << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0x24 */
#define DCD_CHECK_ANY_BIT_SET_PARAM	((HAB_CMD_CHK_DAT_ANY << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_CMD_CHK_DAT_SET << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0x34 */

#define IVT_OFFSET_NAND     (0x400)
#define IVT_OFFSET_I2C      (0x400)
#define IVT_OFFSET_FLEXSPI  (0x1000)
#define IVT_OFFSET_SD		(0x400)
#define IVT_OFFSET_SATA		(0x400)
#define IMAGE_OFFSET_SD		(0x8000)
#define ROM_INITIAL_LOAD_SIZE (0x2000)

#define CSF_DATA_SIZE       (0x4000)
#define INITIAL_LOAD_ADDR_SCU_ROM 0x3100e000
#define INITIAL_LOAD_ADDR_AP_ROM 0x00110000
#define INITIAL_LOAD_ADDR_FLEXSPI 0x08000000
#define IMG_AUTO_ALIGN 0x10

#define PLUGIN_IMAGE_FLAG_MASK              (0x0001)    /* bit 0 is plugin image indicator */
#define HDMI_IMAGE_FLAG_MASK                (0x0002)    /* bit 1 is HDMI image indicator   */

#define HDMI_IVT_ID 0
#define PLUGIN_IVT_ID 1
#define IMAGE_IVT_ID 2

#define HDMI_FW_SIZE 0x17000 /* Use Last 0x1000 for IVT and CSF */
#define HDMI_FW_ADDR 0x32c10000

#define IH_OS_U_BOOT 17
#define IH_ARCH_ARM	2
#define IH_TYPE_FIRMWARE 5
#define IH_COMP_NONE 0

#define FDT_MAGIC	0xd00dfeed
#define CSF_SIZE 0x2000

#define ALIGN(x,a)		__ALIGN_MASK((x),(__typeof__(x))(a)-1, a)
#define __ALIGN_MASK(x,mask,mask2)	(((x)+(mask))/(mask2)*(mask2))

#define uswap_16(x) \
	((((x) & 0xff00) >> 8) | \
	 (((x) & 0x00ff) << 8))
#define uswap_32(x) \
	((((x) & 0xff000000) >> 24) | \
	 (((x) & 0x00ff0000) >>  8) | \
	 (((x) & 0x0000ff00) <<  8) | \
	 (((x) & 0x000000ff) << 24))
#define _uswap_64(x, sfx) \
	((((x) & 0xff00000000000000##sfx) >> 56) | \
	 (((x) & 0x00ff000000000000##sfx) >> 40) | \
	 (((x) & 0x0000ff0000000000##sfx) >> 24) | \
	 (((x) & 0x000000ff00000000##sfx) >>  8) | \
	 (((x) & 0x00000000ff000000##sfx) <<  8) | \
	 (((x) & 0x0000000000ff0000##sfx) << 24) | \
	 (((x) & 0x000000000000ff00##sfx) << 40) | \
	 (((x) & 0x00000000000000ff##sfx) << 56))

#if defined(__GNUC__)
# define uswap_64(x) _uswap_64(x, ull)
#else
#error
# define uswap_64(x) _uswap_64(x, )
#endif

#if __BYTE_ORDER == __LITTLE_ENDIAN
# define cpu_to_le16(x)		(x)
# define cpu_to_le32(x)		(x)
# define cpu_to_le64(x)		(x)
# define le16_to_cpu(x)		(x)
# define le32_to_cpu(x)		(x)
# define le64_to_cpu(x)		(x)
# define cpu_to_be16(x)		uswap_16(x)
# define cpu_to_be32(x)		uswap_32(x)
# define cpu_to_be64(x)		uswap_64(x)
# define be16_to_cpu(x)		uswap_16(x)
# define be32_to_cpu(x)		uswap_32(x)
# define be64_to_cpu(x)		uswap_64(x)
#else
#error
# define cpu_to_le16(x)		uswap_16(x)
# define cpu_to_le32(x)		uswap_32(x)
# define cpu_to_le64(x)		uswap_64(x)
# define le16_to_cpu(x)		uswap_16(x)
# define le32_to_cpu(x)		uswap_32(x)
# define le64_to_cpu(x)		uswap_64(x)
# define cpu_to_be16(x)		(x)
# define cpu_to_be32(x)		(x)
# define cpu_to_be64(x)		(x)
# define be16_to_cpu(x)		(x)
# define be32_to_cpu(x)		(x)
# define be64_to_cpu(x)		(x)
#endif

#define fdt32_to_cpu(x)		be32_to_cpu(x)

#define fdt_get_header(fdt, field) \
	(fdt32_to_cpu(((const struct fdt_header *)(fdt))->field))
#define fdt_magic(fdt)			(fdt_get_header(fdt, magic))
#define fdt_totalsize(fdt)		(fdt_get_header(fdt, totalsize))
#define fdt_off_dt_struct(fdt)		(fdt_get_header(fdt, off_dt_struct))
#define fdt_off_dt_strings(fdt)		(fdt_get_header(fdt, off_dt_strings))
#define fdt_off_mem_rsvmap(fdt)		(fdt_get_header(fdt, off_mem_rsvmap))
#define fdt_version(fdt)		(fdt_get_header(fdt, version))
#define fdt_last_comp_version(fdt)	(fdt_get_header(fdt, last_comp_version))
#define fdt_boot_cpuid_phys(fdt)	(fdt_get_header(fdt, boot_cpuid_phys))
#define fdt_size_dt_strings(fdt)	(fdt_get_header(fdt, size_dt_strings))
#define fdt_size_dt_struct(fdt)		(fdt_get_header(fdt, size_dt_struct))

#define UNDEFINED 0xFFFFFFFF

static void fill_zero(int ifd, int size, int offset)
{
	int fill_size;
	uint8_t zeros[4096];
	memset(zeros, 0, sizeof(zeros));

	lseek(ifd, offset, SEEK_SET);

	while (size) {

		if (size > 4096)
			fill_size = 4096;
		else
			fill_size = size;

		if (write(ifd, (char *)&zeros, fill_size) != fill_size) {
			fprintf(stderr, "Write error: %s\n",
				strerror(errno));
			exit(EXIT_FAILURE);
		}

		size -= fill_size;

	};
}

static void
copy_file (int ifd, const char *datafile, int pad, int offset, int datafile_offset)
{
	int dfd;
	struct stat sbuf;
	unsigned char *ptr;
	int tail;
	int zero = 0;
	uint8_t zeros[4096];
	int size;

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

	ptr = mmap(0, sbuf.st_size, PROT_READ, MAP_SHARED, dfd, 0);
	if (ptr == MAP_FAILED) {
		fprintf (stderr, "Can't read %s: %s\n",
			datafile, strerror(errno));
		exit (EXIT_FAILURE);
	}

	size = sbuf.st_size - datafile_offset;
	lseek(ifd, offset, SEEK_SET);
	if (write(ifd, ptr + datafile_offset, size) != size) {
		fprintf (stderr, "Write error %s\n",
			strerror(errno));
		exit (EXIT_FAILURE);
	}

	tail = size % 4;
	pad = pad - size;
	if ((pad == 1) && (tail != 0)) {

		if (write(ifd, (char *)&zero, 4-tail) != 4-tail) {
			fprintf (stderr, "Write error on %s\n",
				strerror(errno));
			exit (EXIT_FAILURE);
		}
	} else if (pad > 1) {
		while (pad > 0) {
			int todo = sizeof(zeros);

			if (todo > pad)
				todo = pad;
			if (write(ifd, (char *)&zeros, todo) != todo) {
				fprintf(stderr, "Write error: %s\n",
					strerror(errno));
				exit(EXIT_FAILURE);
			}
			pad -= todo;
		}
	}

	(void) munmap((void *)ptr, sbuf.st_size);
	(void) close (dfd);
}

enum imximage_fld_types {
	CFG_INVALID = -1,
	CFG_COMMAND,
	CFG_REG_SIZE,
	CFG_REG_ADDRESS,
	CFG_REG_VALUE
};

enum imximage_cmd {
	CMD_INVALID,
	CMD_IMAGE_VERSION,
	CMD_BOOT_FROM,
	CMD_BOOT_OFFSET,
	CMD_WRITE_DATA,
	CMD_WRITE_CLR_BIT,
	CMD_WRITE_SET_BIT,
	CMD_CHECK_BITS_SET,
	CMD_CHECK_BITS_CLR,
	CMD_CHECK_ANY_BIT_SET,
	CMD_CHECK_ANY_BIT_CLR,
	CMD_CSF,
	CMD_PLUGIN,
};

typedef struct table_entry {
	int	id;
	char	*sname;		/* short (input) name to find table entry */
	char	*lname;		/* long (output) name to print for messages */
} table_entry_t;

/*
 * Supported commands for configuration file
 */
static table_entry_t imximage_cmds[] = {
	{CMD_BOOT_FROM,         "BOOT_FROM",            "boot command",	  },
	{CMD_BOOT_OFFSET,       "BOOT_OFFSET",          "Boot offset",	  },
	{CMD_WRITE_DATA,        "DATA",                 "Reg Write Data", },
	{CMD_WRITE_CLR_BIT,     "CLR_BIT",              "Reg clear bit",  },
	{CMD_WRITE_SET_BIT,     "SET_BIT",              "Reg set bit",  },
	{CMD_CHECK_BITS_SET,    "CHECK_BITS_SET",   "Reg Check all bits set", },
	{CMD_CHECK_BITS_CLR,    "CHECK_BITS_CLR",   "Reg Check all bits clr", },
	{CMD_CHECK_ANY_BIT_SET, "CHECK_ANY_BIT_SET",   "Reg Check any bit set", },
	{CMD_CHECK_ANY_BIT_CLR, "CHECK_ANY_BIT_CLR",   "Reg Check any bit clr", },
	{CMD_CSF,               "CSF",           "Command Sequence File", },
	{CMD_IMAGE_VERSION,     "IMAGE_VERSION",        "image version",  },
	{-1,                    "",                     "",	          },
};

static uint32_t imximage_version;
static struct dcd_v2_cmd *gd_last_cmd;
static uint32_t imximage_ivt_offset = UNDEFINED;
static uint32_t imximage_csf_size = UNDEFINED;

int get_table_entry_id(const table_entry_t *table,
		const char *table_name, const char *name)
{
	const table_entry_t *t;

	for (t = table; t->id >= 0; ++t) {
		if (t->sname && strcasecmp(t->sname, name) == 0)
			return (t->id);
	}

	return -1;
}

static uint32_t get_cfg_value(char *token, char *name,  int linenr)
{
	char *endptr;
	uint32_t value;

	errno = 0;
	value = strtoul(token, &endptr, 16);
	if (errno || (token == endptr)) {
		fprintf(stderr, "Error: %s[%d] - Invalid hex data(%s)\n",
			name,  linenr, token);
		exit(EXIT_FAILURE);
	}
	return value;
}

static void set_dcd_param_v2(dcd_v2_t *dcd_v2, uint32_t dcd_len,
		int32_t cmd)
{
	struct dcd_v2_cmd *d = gd_last_cmd;
	struct dcd_v2_cmd *d2;
	int len;

	if (!d)
		d = &dcd_v2->dcd_cmd;
	d2 = d;
	len = be16_to_cpu(d->write_dcd_command.length);
	if (len > 4)
		d2 = (struct dcd_v2_cmd *)(((char *)d) + len);

	switch (cmd) {
	/* Write value: *address = val_msk */
	case CMD_WRITE_DATA:
		if ((d->write_dcd_command.tag == DCD_WRITE_DATA_COMMAND_TAG) &&
		    (d->write_dcd_command.param == DCD_WRITE_DATA_PARAM))
			break;
		d = d2;
		d->write_dcd_command.tag = DCD_WRITE_DATA_COMMAND_TAG;
		d->write_dcd_command.length = cpu_to_be16(4);
		d->write_dcd_command.param = DCD_WRITE_DATA_PARAM;
		break;
	/* Clear bitmask: *address &= ~val_msk */
	case CMD_WRITE_CLR_BIT:
		if ((d->write_dcd_command.tag == DCD_WRITE_DATA_COMMAND_TAG) &&
		    (d->write_dcd_command.param == DCD_WRITE_CLR_BIT_PARAM))
			break;
		d = d2;
		d->write_dcd_command.tag = DCD_WRITE_DATA_COMMAND_TAG;
		d->write_dcd_command.length = cpu_to_be16(4);
		d->write_dcd_command.param = DCD_WRITE_CLR_BIT_PARAM;
		break;
	/* Set  bitmask: *address |= val_msk */
	case CMD_WRITE_SET_BIT:
		if ((d->write_dcd_command.tag == DCD_WRITE_DATA_COMMAND_TAG) &&
		    (d->write_dcd_command.param == DCD_WRITE_SET_BIT_PARAM))
			break;
		d = d2;
		d->write_dcd_command.tag = DCD_WRITE_DATA_COMMAND_TAG;
		d->write_dcd_command.length = cpu_to_be16(4);
		d->write_dcd_command.param = DCD_WRITE_SET_BIT_PARAM;
		break;
	/*
	 * Check data command only supports one entry,
	 */
	/* All bits set: (*address & mask) == mask */
	case CMD_CHECK_BITS_SET:
		d = d2;
		d->write_dcd_command.tag = DCD_CHECK_DATA_COMMAND_TAG;
		d->write_dcd_command.length = cpu_to_be16(4);
		d->write_dcd_command.param = DCD_CHECK_BITS_SET_PARAM;
		break;
	/* All bits clear: (*address & mask) == 0 */
	case CMD_CHECK_BITS_CLR:
		d = d2;
		d->write_dcd_command.tag = DCD_CHECK_DATA_COMMAND_TAG;
		d->write_dcd_command.length = cpu_to_be16(4);
		d->write_dcd_command.param = DCD_CHECK_BITS_CLR_PARAM;
		break;
	default:
		break;
	}
	gd_last_cmd = d;
}

static void set_dcd_val_v2(dcd_v2_t *dcd_v2, char *name, int lineno,
					int fld, uint32_t value, uint32_t off)
{
	struct dcd_v2_cmd *d = gd_last_cmd;
	int len;

	len = be16_to_cpu(d->write_dcd_command.length);
	off = (len - 4) >> 3;

	switch (fld) {
	case CFG_REG_ADDRESS:
		d->addr_data[off].addr = cpu_to_be32(value);
		break;
	case CFG_REG_VALUE:
		d->addr_data[off].value = cpu_to_be32(value);
		off++;
		d->write_dcd_command.length = cpu_to_be16((off << 3) + 4);
		break;
	default:
		break;

	}
}

static uint32_t set_dcd_rst_v2(dcd_v2_t *dcd_v2, uint32_t dcd_len,
						char *name, int lineno)
{
	struct dcd_v2_cmd *d = gd_last_cmd;
	int len;

	if (!d)
		d = &dcd_v2->dcd_cmd;
	len = be16_to_cpu(d->write_dcd_command.length);
	if (len > 4)
		d = (struct dcd_v2_cmd *)(((char *)d) + len);

	len = (char *)d - (char *)&dcd_v2->header;

	dcd_v2->header.tag = DCD_HEADER_TAG;
	dcd_v2->header.length = cpu_to_be16(len);
	dcd_v2->header.version = DCD_VERSION;

	return len;
}

static void parse_cfg_cmd(dcd_v2_t *dcd_v2, int32_t cmd, char *token,
				char *name, int lineno, int fld, int dcd_len)
{
	int value;
	static int cmd_ver_first = ~0;

	switch (cmd) {
	case CMD_IMAGE_VERSION:
		imximage_version = get_cfg_value(token, name, lineno);
		if (cmd_ver_first == 0) {
			fprintf(stderr, "Error: %s[%d] - IMAGE_VERSION "
				"command need be the first before other "
				"valid command in the file\n", name, lineno);
			exit(EXIT_FAILURE);
		}
		cmd_ver_first = 1;
		break;
	case CMD_BOOT_OFFSET:
		imximage_ivt_offset = get_cfg_value(token, name, lineno);
		if (cmd_ver_first != 1)
			cmd_ver_first = 0;
		break;
	case CMD_WRITE_DATA:
	case CMD_WRITE_CLR_BIT:
	case CMD_WRITE_SET_BIT:
	case CMD_CHECK_BITS_SET:
	case CMD_CHECK_BITS_CLR:
		value = get_cfg_value(token, name, lineno);
		set_dcd_param_v2(dcd_v2, dcd_len, cmd);
		set_dcd_val_v2(dcd_v2, name, lineno, fld, value, dcd_len); /*nothing to do for v2, because we are in CFG_REG_SIZE fld */
		if (cmd_ver_first != 1)
			cmd_ver_first = 0;
		break;
	case CMD_CSF:
		if (imximage_version != 2) {
			fprintf(stderr,
				"Error: %s[%d] - CSF only supported for VERSION 2(%s)\n",
				name, lineno, token);
			exit(EXIT_FAILURE);
		}
		imximage_csf_size = get_cfg_value(token, name, lineno);
		if (cmd_ver_first != 1)
			cmd_ver_first = 0;
		break;
	}
}

static void parse_cfg_fld(dcd_v2_t *dcd_v2, int32_t *cmd,
		char *token, char *name, int lineno, int fld, int *dcd_len)
{
	int value;

	switch (fld) {
	case CFG_COMMAND:
		*cmd = get_table_entry_id(imximage_cmds,
			"imximage commands", token);
		if (*cmd < 0) {
			fprintf(stderr, "Error: %s[%d] - Invalid command"
			"(%s)\n", name, lineno, token);
			exit(EXIT_FAILURE);
		}
		break;
	case CFG_REG_SIZE:
		parse_cfg_cmd(dcd_v2, *cmd, token, name, lineno, fld, *dcd_len);
		break;
	case CFG_REG_ADDRESS:
	case CFG_REG_VALUE:
		switch(*cmd) {
		case CMD_WRITE_DATA:
		case CMD_WRITE_CLR_BIT:
		case CMD_WRITE_SET_BIT:
		case CMD_CHECK_BITS_SET:
		case CMD_CHECK_BITS_CLR:
			value = get_cfg_value(token, name, lineno);
			set_dcd_param_v2(dcd_v2, *dcd_len, *cmd);
			set_dcd_val_v2(dcd_v2, name, lineno, fld, value,
					*dcd_len);

			if (fld == CFG_REG_VALUE) {
				(*dcd_len)++;
				if (*dcd_len > MAX_HW_CFG_SIZE_V2) {
					fprintf(stderr, "Error: %s[%d] -"
						"DCD table exceeds maximum size(%d)\n",
						name, lineno, MAX_HW_CFG_SIZE_V2);
					exit(EXIT_FAILURE);
				}
			}
			break;
		default:
			break;
		}
		break;
	default:
		break;
	}

}

static uint32_t parse_cfg_file(dcd_v2_t *dcd_v2, char *name)
{
	FILE *fd = NULL;
	char *line = NULL;
	char *token, *saveptr1, *saveptr2;
	int lineno = 0;
	int fld;
	size_t len;
	int dcd_len = 0, dcd_size = 0;
	int32_t cmd;

	fd = fopen(name, "r");
	if (fd == 0) {
		fprintf(stderr, "Error: %s - Can't open DCD file\n", name);
		exit(EXIT_FAILURE);
	}

	/*
	 * Very simple parsing, line starting with # are comments
	 * and are dropped
	 */
	while ((getline(&line, &len, fd)) > 0) {
		lineno++;

		token = strtok_r(line, "\r\n", &saveptr1);
		if (token == NULL)
			continue;

		/* Check inside the single line */
		for (fld = CFG_COMMAND, cmd = CMD_INVALID,
				line = token; ; line = NULL, fld++) {
			token = strtok_r(line, " \t", &saveptr2);
			if (token == NULL)
				break;

			/* Drop all text starting with '#' as comments */
			if (token[0] == '#')
				break;

			parse_cfg_fld(dcd_v2, &cmd, token, name,
					lineno, fld, &dcd_len);
		}

	}

	dcd_size = set_dcd_rst_v2(dcd_v2, dcd_len, name, lineno);
	fclose(fd);

	return dcd_size;
}

void dump_header_v2(imx_header_v2_t *imx_header, int index)
{
	const char *ivt_name[3] = {"HDMI FW", "PLUGIN", "LOADER IMAGE"};

	fprintf(stderr, "========= IVT HEADER [%s] =========\n", ivt_name[index]);
	fprintf(stderr, "header.tag: \t\t0x%x\n", imx_header[index].fhdr.header.tag);
	fprintf(stderr, "header.length: \t\t0x%x\n", imx_header[index].fhdr.header.length);
	fprintf(stderr, "header.version: \t0x%x\n", imx_header[index].fhdr.header.version);
	fprintf(stderr, "entry: \t\t\t0x%x\n", imx_header[index].fhdr.entry);
	fprintf(stderr, "reserved1: \t\t0x%x\n", imx_header[index].fhdr.reserved1);
	fprintf(stderr, "dcd_ptr: \t\t0x%x\n", imx_header[index].fhdr.dcd_ptr);
	fprintf(stderr, "boot_data_ptr: \t\t0x%x\n", imx_header[index].fhdr.boot_data_ptr);
	fprintf(stderr, "self: \t\t\t0x%x\n", imx_header[index].fhdr.self);
	fprintf(stderr, "csf: \t\t\t0x%x\n", imx_header[index].fhdr.csf);
	fprintf(stderr, "reserved2: \t\t0x%x\n", imx_header[index].fhdr.reserved2);

	fprintf(stderr, "boot_data.start: \t0x%x\n", imx_header[index].boot_data.start);
	fprintf(stderr, "boot_data.size: \t0x%x\n", imx_header[index].boot_data.size);
	fprintf(stderr, "boot_data.plugin: \t0x%x\n", imx_header[index].boot_data.plugin);
}

void dump_uimage_header(uimage_header_t * uimage_hd_ptr)
{
	fprintf(stderr, "========= UIMAGE HEADER =========\n");
	fprintf(stderr, "ih_magic: \t\t0x%x\n", be32_to_cpu(uimage_hd_ptr->ih_magic));
	fprintf(stderr, "ih_hcrc: \t\t0x%x\n", be32_to_cpu(uimage_hd_ptr->ih_hcrc));
	fprintf(stderr, "ih_time: \t\t0x%x\n", be32_to_cpu(uimage_hd_ptr->ih_time));
	fprintf(stderr, "ih_size: \t\t0x%x\n", be32_to_cpu(uimage_hd_ptr->ih_size));
	fprintf(stderr, "ih_load: \t\t0x%x\n", be32_to_cpu(uimage_hd_ptr->ih_load));
	fprintf(stderr, "ih_ep: \t\t\t0x%x\n", be32_to_cpu(uimage_hd_ptr->ih_ep));
	fprintf(stderr, "ih_dcrc: \t\t0x%x\n", be32_to_cpu(uimage_hd_ptr->ih_dcrc));
	fprintf(stderr, "ih_os: \t\t\t0x%x\n", uimage_hd_ptr->ih_os);
	fprintf(stderr, "ih_arch: \t\t0x%x\n", uimage_hd_ptr->ih_arch);
	fprintf(stderr, "ih_type: \t\t0x%x\n", uimage_hd_ptr->ih_type);
	fprintf(stderr, "ih_comp: \t\t0x%x\n", uimage_hd_ptr->ih_comp);
	fprintf(stderr, "ih_name: \t\t%s\n", uimage_hd_ptr->ih_name);
}

void set_uimage_header(uimage_header_t * uimage_hd_ptr, int fd, uint32_t ep)
{
	uint32_t checksum;
	time_t time;
	struct stat sbuf;
	void *file_ptr;

	if (fstat(fd, &sbuf) < 0) {
		fprintf(stderr, "set_uimage_header error: %s\n",
			strerror(errno));
		exit(EXIT_FAILURE);
	}

	time = sbuf.st_mtime;

	file_ptr = mmap(0, sbuf.st_size, PROT_READ, MAP_SHARED, fd, 0);
	if (file_ptr == MAP_FAILED) {
		fprintf (stderr, "set_uimage_header, File can't read %s\n",
			strerror(errno));
		exit (EXIT_FAILURE);
	}

	checksum = crc32(0,
			(const unsigned char *)(file_ptr), sbuf.st_size); /* crc for image and ivt, not include CSF and uimage header */

	uimage_hd_ptr->ih_magic = cpu_to_be32(IH_MAGIC);
	uimage_hd_ptr->ih_time = cpu_to_be32(time);
	uimage_hd_ptr->ih_size = cpu_to_be32((sbuf.st_size + 0x2000 - sizeof(flash_header_v2_t))); /* The st_size already contain the flash_header */
	uimage_hd_ptr->ih_load = cpu_to_be32(ep);
	uimage_hd_ptr->ih_ep = cpu_to_be32(ep);
	uimage_hd_ptr->ih_dcrc = cpu_to_be32(checksum);
	uimage_hd_ptr->ih_os = IH_OS_U_BOOT;
	uimage_hd_ptr->ih_arch = IH_ARCH_ARM;
	uimage_hd_ptr->ih_type = IH_TYPE_FIRMWARE;
	uimage_hd_ptr->ih_comp = IH_COMP_NONE;

	strncpy((char *)uimage_hd_ptr->ih_name, "Second uimage loader", IH_NMLEN);

	checksum = crc32(0, (const unsigned char *)uimage_hd_ptr,
				sizeof(uimage_header_t));
	uimage_hd_ptr->ih_hcrc = cpu_to_be32(checksum);
}

void generate_sld_with_ivt(char * input_file, uint32_t ep, char *out_file)
{
#define IVT_ALIGN 0x1000

	struct stat sbuf;
	void *file_ptr;
	int ivt_fd, input_fd;
	int aligned_size;

	int i;
	char pad = 0;

	input_fd = open(input_file, O_RDONLY | O_BINARY);
	if (input_fd < 0) {
		fprintf(stderr, "%s: Can't open: %s\n",
                            input_file, strerror(errno));
		exit(EXIT_FAILURE);
	}

	if (fstat(input_fd, &sbuf) < 0) {
		fprintf(stderr, "generate_sld_with_ivt error: %s\n",
			strerror(errno));
		exit(EXIT_FAILURE);
	}

	file_ptr = mmap(0, sbuf.st_size, PROT_READ, MAP_SHARED, input_fd, 0);
	if (file_ptr == MAP_FAILED) {
		fprintf (stderr, "generate_sld_with_ivt, File can't read %s\n",
			strerror(errno));
		exit (EXIT_FAILURE);
	}

	ivt_fd = open (out_file, O_RDWR|O_CREAT|O_TRUNC|O_BINARY, 0666);
	if (ivt_fd < 0) {
		fprintf(stderr, "%s: Can't open: %s\n",
                                "sld-ivt.bin", strerror(errno));
		exit(EXIT_FAILURE);
	}

	if (write(ivt_fd, file_ptr, sbuf.st_size) != sbuf.st_size) {
		fprintf(stderr, "error writing sld-ivt image\n");
		exit(EXIT_FAILURE);
	}

	aligned_size = (sbuf.st_size + sizeof(uimage_header_t) + IVT_ALIGN - 1) & ~(IVT_ALIGN - 1);
	i = sbuf.st_size + sizeof(uimage_header_t);

	for (; i < aligned_size; i++) {
		if (write(ivt_fd, (char *) &pad, 1) != 1) {
			fprintf(stderr,
					"Pad error on sld-ivt image\n");
			exit(EXIT_FAILURE);
		}
	}

	flash_header_v2_t ivt_header = { { 0xd1, 0x2000, 0x40 },
		ep, 0, 0, 0,
		(ep + aligned_size - sizeof(uimage_header_t)),
		(ep + aligned_size - sizeof(uimage_header_t) + 0x20),
		0 };

	if (write(ivt_fd, &ivt_header, sizeof(flash_header_v2_t)) != sizeof(flash_header_v2_t)) {
		fprintf(stderr, "IVT writing error on sld-ivt image\n");
		exit(EXIT_FAILURE);
	}

	close(ivt_fd);
	close(input_fd);
}

/* Return this IVT offset in the final output file */
int generate_ivt_for_fit(int fd, int fit_offset, uint32_t ep, uint32_t *fit_load_addr)
{
	uimage_header_t image_header;

	uint32_t fit_size, load_addr;
	int align_len = 64 - 1; /* 64 is cacheline size */

	lseek(fd, fit_offset, SEEK_SET);

	if (read(fd, (char *)&image_header, sizeof(uimage_header_t)) != sizeof(uimage_header_t)) {
		fprintf (stderr, "generate_ivt_for_fit read failed: %s\n",
			strerror(errno));
		exit (EXIT_FAILURE);
	}

	if (be32_to_cpu(image_header.ih_magic) != FDT_MAGIC){
		fprintf (stderr, "generate_ivt_for_fit error: not a FIT file\n");
		exit (EXIT_FAILURE);
	}

	fit_size = fdt_totalsize(&image_header);
	fit_size = (fit_size + 3) & ~3;

#define ALIGN_SIZE		0x1000

	fit_size = ALIGN(fit_size, ALIGN_SIZE);

	lseek(fd, fit_offset + fit_size, SEEK_SET);

	/* ep is the u-boot entry. SPL loads the FIT before the u-boot address. 0x2000 is for CSF_SIZE */
	load_addr = (ep - (fit_size + CSF_SIZE) - 512 -
			align_len) & ~align_len;

	flash_header_v2_t ivt_header = { { 0xd1, 0x2000, 0x40 },
		load_addr, 0, 0, 0,
		(load_addr + fit_size),
		(load_addr + fit_size + 0x20),
		0 };

	if (write(fd, &ivt_header, sizeof(flash_header_v2_t)) != sizeof(flash_header_v2_t)) {
		fprintf(stderr, "IVT writing error on fit image\n");
		exit(EXIT_FAILURE);
	}

	*fit_load_addr = load_addr;

	return fit_offset + fit_size;

}

int main(int argc, char **argv)
{
	int c, file_off, plugin_fd = -1, hdmi_fd = -1, ap_fd = -1, csf_hdmi_fd = -1, csf_fd = -1, ofd = -1, csf_plugin_fd = -1, sld_fd = -1;
	unsigned int dcd_size = 0, plugin_start_addr = 0, ap_start_addr = 0, sld_start_addr = 0, sld_src_off = 0, sld_csf_off = 0, sld_load_addr = 0;
	char *ofname = NULL, *hdmi_img = NULL, *dcd_img = NULL, *plugin_img = NULL, *ap_img = NULL, *csf_img = NULL, *csf_plugin_img = NULL, *csf_hdmi_img = NULL, *sld_img = NULL;
	char *signed_hdmi = NULL;
	static imx_header_v2_t imx_header[3]; /* At most there are 3 IVT headers */
	uint32_t ivt_offset = IVT_OFFSET_SD;
	uint32_t rom_image_offset = IMAGE_OFFSET_SD;
	uint32_t sector_size = 0x200;
	struct stat sbuf;
	uint32_t plugin_off = 0, hdmi_off = 0, image_off = 0, csf_plugin_off = 0, csf_hdmi_off = 0, csf_off = 0;
	uint32_t header_hdmi_off = 0, header_hdmi_2_off = 0, header_plugin_off = 0, header_image_off = 0, dcd_off = 0;
	uint32_t sld_header_off = 0;
	int using_fit = 0;
	dcd_v2_t dcd_table;
	uimage_header_t uimage_hdr;

	static struct option long_options[] =
	{
		{"loader", required_argument, NULL, 'i'},
		{"dcd", required_argument, NULL, 'd'},
		{"fit", no_argument, NULL, 'f'},
		{"out", required_argument, NULL, 'o'},
		{"plugin", required_argument, NULL, 'p'},
		{"hdmi", required_argument, NULL, 'h'},
		{"signed_hdmi", required_argument, NULL, 's'},
		{"csf_plugin", required_argument, NULL, 'q'},
		{"csf_hdmi", required_argument, NULL, 'm'},
		{"dev", required_argument, NULL, 'e'},
		{"csf", required_argument, NULL, 'c'},
		{"second_loader", required_argument, NULL, 'u'},
		{NULL, 0, NULL, 0}
	};

	memset((char*)&imx_header, 0, sizeof(imx_header_v2_t) * 3);

	fprintf(stderr, "Platform:\ti.MX8M (mScale)\n");

	while(1)
    	{
		/* getopt_long stores the option index here. */
		int option_index = 0;

		c = getopt_long_only (argc, argv, ":i:f:d:o:p:h:q:m:e:b:",
			long_options, &option_index);

		/* Detect the end of the options. */
		if (c == -1)
		break;

		switch (c)
		{
			case 0:
				fprintf(stderr, "option %s", long_options[option_index].name);
				if (optarg)
					fprintf(stderr, " with arg %s", optarg);
				fprintf(stderr, "\n");
				break;
			case 'd':
				fprintf(stderr, "DCD:\t%s\n", optarg);
				dcd_img = optarg;
				break;
			case 'f':
				fprintf(stderr, "Using FIT image\n");
				using_fit = 1;
				break;
			case 'p':
				fprintf(stderr, "PLUGIN:\t%s", optarg);
				plugin_img = optarg;
				if (optind < argc && *argv[optind] != '-') {
					plugin_start_addr = (uint32_t) strtoll(argv[optind++], NULL, 0);
					fprintf(stderr, " start addr: 0x%08x\n", plugin_start_addr);
				} else {
					fprintf(stderr, "\n-plugin option require TWO arguments: filename, start address in hex\n\n");
					exit(1);
				}
				break;
			case 'i':
				fprintf(stderr, "LOADER IMAGE:\t%s", optarg);
				ap_img = optarg;
				if (optind < argc && *argv[optind] != '-') {
					ap_start_addr = (uint32_t) strtoll(argv[optind++], NULL, 0);

					fprintf(stderr, " start addr: 0x%08x\n", ap_start_addr);
				} else {
					fprintf(stderr, "\n-loader option require TWO arguments: filename, start address in hex\n\n");
					exit(1);
				}
				break;
			case 'h':
				fprintf(stderr, "HDMI FW:\t%s\n", optarg); /* Fixed address for HDMI Firmware */
				hdmi_img = optarg;
				break;
			case 's':
				fprintf(stderr, "SIGNED HDMI FW:\t%s\n", optarg); /* Fixed address for HDMI Firmware */
				signed_hdmi = optarg;
				break;
			case 'o':
				fprintf(stderr, "Output:\t\t%s\n", optarg);
				ofname = optarg;
				break;
			case 'c':
				fprintf(stderr, "CSF:\t%s\n", optarg);
				csf_img = optarg;
				break;
			case 'q':
				fprintf(stderr, "CSF_PLUGIN:\t%s\n", optarg);
				csf_plugin_img = optarg;
				break;
			case 'm':
				fprintf(stderr, "CSF_HDMI:\t%s\n", optarg);
				csf_hdmi_img = optarg;
				break;
			case 'e':
				fprintf(stderr, "BOOT DEVICE:\t%s\n", optarg);
				if (!strcmp(optarg, "flexspi")) {
					ivt_offset = IVT_OFFSET_FLEXSPI;
					rom_image_offset = 0;
				} else if (!strcmp(optarg, "sd")) {
					ivt_offset = IVT_OFFSET_SD;
					rom_image_offset = IMAGE_OFFSET_SD;
				} else if (!strcmp(optarg, "emmc_fastboot")) {
					ivt_offset = IVT_OFFSET_SD;
					rom_image_offset = 0;
				} else {
					fprintf(stderr, "\n-dev option, Valid boot devices are sd, emmc_fastboot or nand\n\n");
					exit(1);
				}
				break;
			case 'u':
				fprintf(stderr, "SECOND LOADER IMAGE:\t%s", optarg);
				sld_img = optarg;
				if ((optind < argc && *argv[optind] != '-') && (optind+1 < argc &&*argv[optind+1] != '-' )) {
					sld_start_addr = (uint32_t) strtoll(argv[optind++], NULL, 0);
					sld_src_off = (uint32_t) strtoll(argv[optind++], NULL, 0);

					fprintf(stderr, " start addr: 0x%08x", sld_start_addr);
					fprintf(stderr, " offset: 0x%08x\n", sld_src_off);
				} else {
					fprintf(stderr, "\n-second_loader option require TWO arguments: filename, start address in hex\n\n");
					exit(1);
				}
				break;
			case ':':
				fprintf(stderr, "option %c missing arguments\n", optopt);
				break;
			case '?':
			default:
				/* invalid option */
				fprintf(stderr, "option '%c' is invalid: ignored\n",
					optopt);
				exit(1);
		}
	}

	if((ap_img == NULL) || (ofname == NULL))
	{
		fprintf(stderr, "mandatory args image and output file name missing! abort\n");
		exit(1);
	}

	if((dcd_img != NULL) && (plugin_img != NULL))
	{
		fprintf(stderr, "Can't enable DCD and PLUGIN at same time! abort\n");
		exit(1);
	}

	file_off = 0;

	if (signed_hdmi) {
		header_hdmi_off = file_off + ivt_offset;

		hdmi_fd = open(signed_hdmi, O_RDONLY | O_BINARY);
		if (hdmi_fd < 0) {
			fprintf(stderr, "%s: Can't open: %s\n",
                                signed_hdmi, strerror(errno));
			exit(EXIT_FAILURE);
		}

		if (fstat(hdmi_fd, &sbuf) < 0) {
			fprintf(stderr, "%s: Can't stat: %s\n",
				signed_hdmi, strerror(errno));
			exit(EXIT_FAILURE);
		}
		close(hdmi_fd);

		/* Aligned to 104KB = 92KB FW image + 0x8000 (IVT and alignment) + 0x4000 (second IVT + CSF)*/
		file_off += ALIGN(sbuf.st_size, HDMI_FW_SIZE + 0x2000 + 0x1000);
	}

	/* Check the HDMI image and set its IVT first */
	if(!signed_hdmi && hdmi_img) {

		header_hdmi_off = file_off + ivt_offset;

		file_off += ALIGN(sizeof(imx_header_v2_t) + ivt_offset, 0x2000); /* Aligned to 8KB */


		hdmi_fd = open(hdmi_img, O_RDONLY | O_BINARY);
		if (hdmi_fd < 0) {
			fprintf(stderr, "%s: Can't open: %s\n",
                                hdmi_img, strerror(errno));
			exit(EXIT_FAILURE);
		}

		if (fstat(hdmi_fd, &sbuf) < 0) {
			fprintf(stderr, "%s: Can't stat: %s\n",
				hdmi_img, strerror(errno));
			exit(EXIT_FAILURE);
		}
		close(hdmi_fd);

		if (sbuf.st_size > HDMI_FW_SIZE) {
			fprintf(stderr, "%s: size is too large:%ld\n",
				hdmi_img, sbuf.st_size);
			exit(EXIT_FAILURE);
		}

		hdmi_off = file_off;

		file_off += ALIGN(sbuf.st_size, HDMI_FW_SIZE); /* Aligned to 96KB */

		imx_header[HDMI_IVT_ID].fhdr.header.tag = IVT_HEADER_TAG; /* 0xD1 */
		imx_header[HDMI_IVT_ID].fhdr.header.length = cpu_to_be16(sizeof(flash_header_v2_t));
		imx_header[HDMI_IVT_ID].fhdr.header.version = IVT_VERSION; /* 0x40 */

		/* There are some tricks for HDMI FW.
		*  1. ROM only copies the FW image after IVT head (8K offset), to the address pointed by boot data
		*      This means, we need set boot_data-> start to the HDMI imem. Set the boot_data->size
		*      to the HDMI FW (imem + dmem) + HDMI IVT.
		*  2. The imem address can't be put IVT head. and IVT head won't be copied by ROM. But the CSF needs to
		*      check the IVT.  So we have to set IVT load address to the address after HDMI FW. And attach another
		*      IVT head after HDMI FW.
		*      Finally, there will be two IVT attached to HDMI FW.  First one is for ROM initial loading. ROM won't copy it.
		*      Second one is as a part of FW image, and be loaded to the specified dmem address in IVT.
		*/

		imx_header[HDMI_IVT_ID].fhdr.entry = HDMI_FW_ADDR; /* 0?*/
		imx_header[HDMI_IVT_ID].fhdr.dcd_ptr = 0;
		imx_header[HDMI_IVT_ID].fhdr.self = HDMI_FW_ADDR + HDMI_FW_SIZE;
		imx_header[HDMI_IVT_ID].fhdr.boot_data_ptr = imx_header[0].fhdr.self + offsetof(imx_header_v2_t, boot_data);

		imx_header[HDMI_IVT_ID].boot_data.start = HDMI_FW_ADDR;
		imx_header[HDMI_IVT_ID].boot_data.size = HDMI_FW_SIZE + 0x1000; /* 96KB = HDMI FW + HDMI IVT & CSF (4KB)*/
		imx_header[HDMI_IVT_ID].boot_data.plugin = HDMI_IMAGE_FLAG_MASK;

		header_hdmi_2_off = file_off;

		if (csf_hdmi_img) {

			csf_hdmi_fd = open(csf_hdmi_img, O_RDONLY | O_BINARY);
			if (csf_hdmi_fd < 0) {
				fprintf(stderr, "%s: Can't open: %s\n",
	                                csf_hdmi_img, strerror(errno));
				exit(EXIT_FAILURE);
			}

			if (fstat(csf_hdmi_fd, &sbuf) < 0) {
				fprintf(stderr, "%s: Can't stat: %s\n",
					csf_hdmi_img, strerror(errno));
				exit(EXIT_FAILURE);
			}
			close(csf_hdmi_fd);
		}
		imx_header[HDMI_IVT_ID].fhdr.csf = imx_header[HDMI_IVT_ID].fhdr.self + ALIGN(sizeof(imx_header_v2_t), 64); /* The fhdr + boot_data is 48 bytes, we align to 64 */
		csf_hdmi_off = header_hdmi_2_off + (imx_header[HDMI_IVT_ID].fhdr.csf - imx_header[HDMI_IVT_ID].fhdr.self);

		/* no matter if the hdmi csf exists, we still add 4KB for IVT and CSF*/
		file_off += ALIGN(sizeof(imx_header_v2_t), 0x1000); /* Aligned to 4KB */
	}

	if(plugin_img) {
		header_plugin_off = file_off + ivt_offset;

		plugin_fd = open(plugin_img, O_RDONLY | O_BINARY);
		if (plugin_fd < 0) {
			fprintf(stderr, "%s: Can't open: %s\n",
	                                plugin_img, strerror(errno));
			exit(EXIT_FAILURE);
		}

		if (fstat(plugin_fd, &sbuf) < 0) {
			fprintf(stderr, "%s: Can't stat: %s\n",
					plugin_img, strerror(errno));
			exit(EXIT_FAILURE);
		}
		close(plugin_fd);

		imx_header[PLUGIN_IVT_ID].fhdr.header.tag = IVT_HEADER_TAG; /* 0xD1 */
		imx_header[PLUGIN_IVT_ID].fhdr.header.length = cpu_to_be16(sizeof(flash_header_v2_t));
		imx_header[PLUGIN_IVT_ID].fhdr.header.version = IVT_VERSION; /* 0x40 */
		imx_header[PLUGIN_IVT_ID].fhdr.entry = plugin_start_addr;
		imx_header[PLUGIN_IVT_ID].fhdr.dcd_ptr = 0;
		imx_header[PLUGIN_IVT_ID].fhdr.self = plugin_start_addr - sizeof(imx_header_v2_t);
		imx_header[PLUGIN_IVT_ID].fhdr.boot_data_ptr = imx_header[PLUGIN_IVT_ID].fhdr.self + offsetof(imx_header_v2_t, boot_data);

		imx_header[PLUGIN_IVT_ID].boot_data.start = imx_header[PLUGIN_IVT_ID].fhdr.self - ivt_offset;

		imx_header[PLUGIN_IVT_ID].boot_data.plugin = PLUGIN_IMAGE_FLAG_MASK;
		imx_header[PLUGIN_IVT_ID].boot_data.size = ALIGN(sbuf.st_size + sizeof(imx_header_v2_t) + ivt_offset, sector_size);

		plugin_off = file_off + sizeof(imx_header_v2_t) + ivt_offset;
		file_off += imx_header[PLUGIN_IVT_ID].boot_data.size;

		if(csf_plugin_img) {
			csf_plugin_fd = open(csf_plugin_img, O_RDONLY | O_BINARY);
			if (csf_plugin_fd < 0) {
				fprintf(stderr, "%s: Can't open: %s\n",
		                                csf_plugin_img, strerror(errno));
				exit(EXIT_FAILURE);
			}

			if (fstat(csf_plugin_fd, &sbuf) < 0) {
				fprintf(stderr, "%s: Can't stat: %s\n",
						csf_plugin_img, strerror(errno));
				exit(EXIT_FAILURE);
			}
			close(csf_plugin_fd);

			imx_header[PLUGIN_IVT_ID].fhdr.csf = imx_header[PLUGIN_IVT_ID].boot_data.start + imx_header[PLUGIN_IVT_ID].boot_data.size;
			imx_header[PLUGIN_IVT_ID].boot_data.size += ALIGN(sbuf.st_size, 64);

			csf_plugin_off = file_off;
			file_off += ALIGN(sbuf.st_size, 64); /* Align for the next IVT */
		}

		/* We attach the secondary IVT to the plugin image (CSF contained),  and set it to load with plugin image.
		  * Thus plugin can use (plugin_IVT.boot_data.start + plugin_IVT.boot_data.size - sizeof(imx_header_v2_t)) to get the secondary IVT pointer
		  */
		imx_header[PLUGIN_IVT_ID].boot_data.size += sizeof(imx_header_v2_t); /* Add the secondary IVT size, need to load it with plugin image */

		header_image_off = file_off;
	} else {
		header_image_off = file_off + ivt_offset;
	}

	/* First boot loader image */
	if (dcd_img) {
		dcd_size = parse_cfg_file(&dcd_table, dcd_img);
		fprintf(stderr, "dcd size = %d\n", dcd_size);

		if (ALIGN(dcd_size, 64) > (ROM_INITIAL_LOAD_SIZE - ivt_offset - sizeof(imx_header_v2_t))) {
			fprintf(stderr, "DCD table with size %u exceeds maximum size %lu\n", ALIGN(dcd_size, 64), (ROM_INITIAL_LOAD_SIZE - ivt_offset - sizeof(imx_header_v2_t)));
			exit(EXIT_FAILURE);
		}
	}

	ap_fd = open(ap_img, O_RDONLY | O_BINARY);
	if (ap_fd < 0) {
		fprintf(stderr, "%s: Can't open: %s\n",
                        	ap_img, strerror(errno));
		exit(EXIT_FAILURE);
	}
	if (fstat(ap_fd, &sbuf) < 0) {
		fprintf(stderr, "%s: Can't stat: %s\n",
			ap_img, strerror(errno));
		exit(EXIT_FAILURE);
	}
	close(ap_fd);

	imx_header[IMAGE_IVT_ID].fhdr.header.tag = IVT_HEADER_TAG; /* 0xD1 */
	imx_header[IMAGE_IVT_ID].fhdr.header.length = cpu_to_be16(sizeof(flash_header_v2_t));
	imx_header[IMAGE_IVT_ID].fhdr.header.version = IVT_VERSION; /* 0x41 */
	imx_header[IMAGE_IVT_ID].fhdr.entry = ap_start_addr;

	imx_header[IMAGE_IVT_ID].fhdr.self = ap_start_addr - sizeof(imx_header_v2_t) - ALIGN(dcd_size, 64);
	if (dcd_size) {
		imx_header[IMAGE_IVT_ID].fhdr.dcd_ptr = imx_header[IMAGE_IVT_ID].fhdr.self + sizeof(imx_header_v2_t);
		dcd_off = header_image_off + sizeof(imx_header_v2_t);
	} else {
		imx_header[IMAGE_IVT_ID].fhdr.dcd_ptr = 0;
	}

	imx_header[IMAGE_IVT_ID].fhdr.boot_data_ptr = imx_header[IMAGE_IVT_ID].fhdr.self + offsetof(imx_header_v2_t, boot_data);

	/* When using plugin, the ROM read data from image offset again in pu_irom_hwcnfg_setup, so the boot_data.start and size must align to the rom_image_offset position in boot device
       *   This means we have to contain the PLUGIN image things (IVT, plugin, plugin csf)
	*/
	if (plugin_img) {
		imx_header[IMAGE_IVT_ID].boot_data.start = imx_header[IMAGE_IVT_ID].fhdr.self - (imx_header[PLUGIN_IVT_ID].boot_data.size - sizeof(imx_header_v2_t));
		imx_header[IMAGE_IVT_ID].boot_data.size = ALIGN(sbuf.st_size + sizeof(imx_header_v2_t),sector_size) +
			(imx_header[PLUGIN_IVT_ID].boot_data.size - sizeof(imx_header_v2_t));

		image_off = header_image_off + sizeof(imx_header_v2_t);
		file_off +=  ALIGN(sbuf.st_size + sizeof(imx_header_v2_t), sector_size);
	} else {
		imx_header[IMAGE_IVT_ID].boot_data.start = imx_header[IMAGE_IVT_ID].fhdr.self - ivt_offset;
		imx_header[IMAGE_IVT_ID].boot_data.size = ALIGN(sbuf.st_size + sizeof(imx_header_v2_t) + ivt_offset + ALIGN(dcd_size, 64), sector_size);

		image_off = header_image_off + sizeof(imx_header_v2_t) + ALIGN(dcd_size, 64);
		file_off +=  imx_header[IMAGE_IVT_ID].boot_data.size;
	}

	imx_header[IMAGE_IVT_ID].boot_data.plugin = 0;

	if (csf_img) {
		csf_fd = open(csf_img, O_RDONLY | O_BINARY);
		if (csf_fd < 0) {
			fprintf(stderr, "%s: Can't open: %s\n",
                                csf_img, strerror(errno));
			exit(EXIT_FAILURE);
		}

		if (fstat(csf_fd, &sbuf) < 0) {
			fprintf(stderr, "%s: Can't stat: %s\n",
				csf_img, strerror(errno));
			exit(EXIT_FAILURE);
		}
		close(csf_fd);

		if (sbuf.st_size > CSF_DATA_SIZE) {
			fprintf(stderr, "%s: file size %ld is larger than CSF_DATA_SIZE %d\n",
				csf_img, sbuf.st_size, CSF_DATA_SIZE);
			exit(EXIT_FAILURE);
		}

		imx_header[IMAGE_IVT_ID].fhdr.csf = imx_header[IMAGE_IVT_ID].boot_data.start + imx_header[IMAGE_IVT_ID].boot_data.size;

		imx_header[IMAGE_IVT_ID].boot_data.size += sbuf.st_size;

		csf_off = file_off;
		file_off += sbuf.st_size;
	} else {
		imx_header[IMAGE_IVT_ID].fhdr.csf = imx_header[IMAGE_IVT_ID].boot_data.start + imx_header[IMAGE_IVT_ID].boot_data.size;

		imx_header[IMAGE_IVT_ID].boot_data.size += CSF_SIZE; /* 8K region dummy CSF */

		csf_off = file_off;
		file_off += CSF_SIZE;
	}

	/* Second boot loader image */
	if (sld_img) {
		if (!using_fit) {
			char sld_ivt_img[32];
			memset(&sld_ivt_img, 0, 32);

			strncpy((char *)&sld_ivt_img, sld_img, (32 - 5));
			strcat((char *)&sld_ivt_img, ".ivt");

			fprintf(stderr, "SECOND LOADER IVT File:\t%s\n", (char *)&sld_ivt_img);

			/* We add 8K region for IVT and CSF to this second boot loader image*/
			/* According to u-boot authentication, the image size before IVT should align to 0x1000, this image size includes the uimage header because
			 *  we also need to sign and authenticate the uimage header.
			 *  Because the 8K region is added, we has to modify the size field in uimage to add the alignment padding and 8K region. This size does NOT include
			 *  the size of uimage header.
			 */
			generate_sld_with_ivt(sld_img, sld_start_addr, (char *)&sld_ivt_img);
			sld_img = (char *)&sld_ivt_img; /* Change to the sld_ivt image */

			sld_header_off = sld_src_off - rom_image_offset;
			imx_header[IMAGE_IVT_ID].fhdr.reserved1 = sld_header_off - header_image_off; /* Record the second bootloader relative offset in image's IVT reserved1*/

			sld_fd = open(sld_img, O_RDONLY | O_BINARY);
			if (sld_fd < 0) {
				fprintf(stderr, "%s: Can't open: %s\n",
	                                sld_img, strerror(errno));
				exit(EXIT_FAILURE);
			}

			if (fstat(sld_fd, &sbuf) < 0) {
				fprintf(stderr, "%s: Can't stat: %s\n",
					sld_img, strerror(errno));
				exit(EXIT_FAILURE);
			}

			set_uimage_header(&uimage_hdr, sld_fd, sld_start_addr);

			close(sld_fd);

			file_off = sld_header_off;
			file_off += sbuf.st_size + sizeof(uimage_header_t);

			sld_csf_off = file_off;
			file_off += CSF_SIZE - sizeof(flash_header_v2_t);
		}else {
			sld_header_off = sld_src_off - rom_image_offset;
			imx_header[IMAGE_IVT_ID].fhdr.reserved1 = sld_header_off - header_image_off; /* Record the second bootloader relative offset in image's IVT reserved1*/
			sld_fd = open(sld_img, O_RDONLY | O_BINARY);
			if (sld_fd < 0) {
				fprintf(stderr, "%s: Can't open: %s\n",
	                                sld_img, strerror(errno));
				exit(EXIT_FAILURE);
			}

			if (fstat(sld_fd, &sbuf) < 0) {
				fprintf(stderr, "%s: Can't stat: %s\n",
					sld_img, strerror(errno));
				exit(EXIT_FAILURE);
			}

			close(sld_fd);

			file_off = sld_header_off;
			file_off += sbuf.st_size + sizeof(uimage_header_t);
		}
	}


	/* Open output file */
	ofd = open (ofname, O_RDWR|O_CREAT|O_TRUNC|O_BINARY, 0666);
	if (ofd < 0) {
		fprintf(stderr, "%s: Can't open: %s\n",
                                ofname, strerror(errno));
		exit(EXIT_FAILURE);
	}

	if(signed_hdmi) {
		header_hdmi_off -= ivt_offset;
		lseek(ofd, header_hdmi_off, SEEK_SET);

		/* The signed HDMI FW has 0x400 IVT offset, need remove it */
		copy_file(ofd, signed_hdmi, 0, header_hdmi_off, 0x400);
	}

	if(!signed_hdmi && hdmi_img) {
		header_hdmi_off -= ivt_offset;
		hdmi_off -= ivt_offset;
		header_hdmi_2_off -= ivt_offset;

		lseek(ofd, header_hdmi_off, SEEK_SET);

		/* Write image header */
		if (write(ofd, &imx_header[HDMI_IVT_ID], sizeof(imx_header_v2_t)) != sizeof(imx_header_v2_t)) {
			fprintf(stderr, "error writing image hdr\n");
			exit(1);
		};

		copy_file(ofd, hdmi_img, 0, hdmi_off, 0);

		lseek(ofd, header_hdmi_2_off, SEEK_SET);

		if (write(ofd, &imx_header[HDMI_IVT_ID], sizeof(imx_header_v2_t)) != sizeof(imx_header_v2_t)) {
			fprintf(stderr, "error writing image hdr\n");
			exit(1);
		}

		if (csf_hdmi_img) {
			csf_hdmi_off -= ivt_offset;
			copy_file(ofd, csf_hdmi_img, 0, csf_hdmi_off, 0);
		}
	}

	if(plugin_img) {
		header_plugin_off -= ivt_offset;
		plugin_off -= ivt_offset;

		lseek(ofd, header_plugin_off, SEEK_SET);

		/* Write image header */
		if (write(ofd, &imx_header[PLUGIN_IVT_ID], sizeof(imx_header_v2_t)) != sizeof(imx_header_v2_t)) {
			fprintf(stderr, "error writing image hdr\n");
			exit(1);
		}

		copy_file(ofd, plugin_img, 0, plugin_off, 0);

		if (csf_plugin_img) {
			csf_plugin_off -= ivt_offset;
			copy_file(ofd, csf_plugin_img, 0, csf_plugin_off, 0);
		}
	}

	/* Main Image */
	header_image_off -= ivt_offset;
	image_off -= ivt_offset;
	lseek(ofd, header_image_off, SEEK_SET);

	/* Write image header */
	if (write(ofd, &imx_header[IMAGE_IVT_ID], sizeof(imx_header_v2_t)) != sizeof(imx_header_v2_t)) {
		fprintf(stderr, "error writing image hdr\n");
		exit(1);
	}

	if (dcd_size) {
		dcd_off -= ivt_offset;
		lseek(ofd, dcd_off, SEEK_SET);

		if (write(ofd, &dcd_table, dcd_size) != dcd_size) {
			fprintf(stderr, "error writing dcd\n");
			exit(1);
		}
	}

	copy_file(ofd, ap_img, 0, image_off, 0);

	if (csf_img) {
		csf_off -= ivt_offset;
		copy_file(ofd, csf_img, 0, csf_off, 0);
	} else {
		csf_off -= ivt_offset;
		fill_zero(ofd, CSF_SIZE, csf_off);
	}

	if (sld_img) {
		sld_header_off -= ivt_offset;
		lseek(ofd, sld_header_off, SEEK_SET);

		/* Write image header */
		if (!using_fit) {
			/* Write image header */
			if (write(ofd, &uimage_hdr, sizeof(uimage_header_t)) != sizeof(uimage_header_t)) {
				fprintf(stderr, "error writing uimage hdr\n");
				exit(1);
			}

			copy_file(ofd, sld_img, 0, sld_header_off + sizeof(uimage_header_t), 0);
			fill_zero(ofd, CSF_SIZE - sizeof(flash_header_v2_t), sld_csf_off);
			sld_csf_off -= ivt_offset;
			sld_load_addr = sld_start_addr - (uint32_t)sizeof(uimage_header_t);
		} else {
			copy_file(ofd, sld_img, 0, sld_header_off, 0);
			sld_csf_off = generate_ivt_for_fit(ofd, sld_header_off, sld_start_addr, &sld_load_addr) + 0x20;
		}
	}

	/* Close output file */
	close(ofd);

	if (!signed_hdmi)
		dump_header_v2(imx_header, 0);
	dump_header_v2(imx_header, 1);
	dump_header_v2(imx_header, 2);

	if (!using_fit)
		dump_uimage_header(&uimage_hdr);

	fprintf(stderr, "========= OFFSET dump =========");
	if (signed_hdmi) {
		fprintf(stderr, "\nSIGNED HDMI FW:\n");
		fprintf(stderr, " header_hdmi_off \t0x%x\n",
			header_hdmi_off);
	} else {
		fprintf(stderr, "\nHDMI FW:\n");
		fprintf(stderr, " header_hdmi_off \t0x%x\n hdmi_off \t\t0x%x\n header_hdmi_2_off \t0x%x\n csf_hdmi_off \t\t0x%x\n",
			header_hdmi_off, hdmi_off, header_hdmi_2_off, csf_hdmi_off);
	}

	fprintf(stderr, "\nPLUGIN:\n");
	fprintf(stderr, " header_plugin_off \t0x%x\n plugin_off \t\t0x%x\n csf_plugin_off \t0x%x\n",
		header_plugin_off, plugin_off, csf_plugin_off);

	fprintf(stderr, "\nLoader IMAGE:\n");
	fprintf(stderr, " header_image_off \t0x%x\n dcd_off \t\t0x%x\n image_off \t\t0x%x\n csf_off \t\t0x%x\n",
		header_image_off, dcd_off, image_off, csf_off);
	fprintf(stderr, " spl hab block: \t0x%x 0x%x 0x%x\n",
		imx_header[IMAGE_IVT_ID].fhdr.self, header_image_off, csf_off - header_image_off);

	fprintf(stderr, "\nSecond Loader IMAGE:\n");
	fprintf(stderr, " sld_header_off \t0x%x\n",
		sld_header_off);
	fprintf(stderr, " sld_csf_off \t\t0x%x\n",
		sld_csf_off);
	fprintf(stderr, " sld hab block: \t0x%x 0x%x 0x%x\n",
		sld_load_addr, sld_header_off, sld_csf_off - sld_header_off);

	return 0;
}

