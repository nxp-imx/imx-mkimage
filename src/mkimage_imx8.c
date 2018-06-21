/*
 * Copyright (C) 2016 Freescale Semiconductor, Inc.
 *
 * Copyright (C) 2017 NXP
 *
 * SPDX-License-Identifier:	GPL-2.0+
 * derived from u-boot's mkimage utility
 *
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#include <sys/stat.h>
#include <getopt.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <stdbool.h>
#include <inttypes.h>

#include "mkimage_common.h"
#include "build_info.h"

#ifndef O_BINARY
#define O_BINARY 0
#endif


#define IMG_STACK_SIZE			32 /* max of 32 images for commandline images */

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
		int 	id;
		char	*sname;			/* short (input) name to find table entry */
		char	*lname;			/* long (output) name to print for messages */
} table_entry_t;

/*
 * Supported commands for configuration file
 */
static table_entry_t imximage_cmds[] = {
		{CMD_BOOT_FROM,         "BOOT_FROM",            "boot command",   },
		{CMD_BOOT_OFFSET,       "BOOT_OFFSET",          "Boot offset",    },
		{CMD_WRITE_DATA,        "DATA",                 "Reg Write Data", },
		{CMD_WRITE_CLR_BIT,     "CLR_BIT",              "Reg clear bit",  },
		{CMD_WRITE_SET_BIT,     "SET_BIT",              "Reg set bit",  },
		{CMD_CHECK_BITS_SET,    "CHECK_BITS_SET",   "Reg Check all bits set", },
		{CMD_CHECK_BITS_CLR,    "CHECK_BITS_CLR",   "Reg Check all bits clr", },
		{CMD_CHECK_ANY_BIT_SET, "CHECK_ANY_BIT_SET",   "Reg Check any bit set", },
		{CMD_CHECK_ANY_BIT_CLR, "CHECK_ANY_BIT_CLR",   "Reg Check any bit clr", },
		{CMD_CSF,               "CSF",           "Command Sequence File", },
		{CMD_IMAGE_VERSION,     "IMAGE_VERSION",        "image version",  },
		{-1,                    "",                     "",               },
};

void check_file(struct stat* sbuf,char * filename)
{
	int tmp_fd  = open(filename, O_RDONLY | O_BINARY);
	if (tmp_fd < 0) {
			fprintf(stderr, "%s: Can't open: %s\n",
							filename, strerror(errno));
			exit(EXIT_FAILURE);
	}

	if (fstat(tmp_fd, sbuf) < 0) {
			fprintf(stderr, "%s: Can't stat: %s\n",
							filename, strerror(errno));
			exit(EXIT_FAILURE);
	}
	close(tmp_fd);
}

void
copy_file (int ifd, const char *datafile, int pad, int offset)
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

	if(sbuf.st_size == 0)
		goto close;

	ptr = mmap(0, sbuf.st_size, PROT_READ, MAP_SHARED, dfd, 0);
	if (ptr == MAP_FAILED) {
		fprintf (stderr, "Can't read %s: %s\n",
			datafile, strerror(errno));
		exit (EXIT_FAILURE);
	}

	size = sbuf.st_size;
	lseek(ifd, offset, SEEK_SET);
	if (write(ifd, ptr, size) != size) {
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
close:
	(void) close (dfd);
}


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

uint32_t get_cfg_value(char *token, char *name,  int linenr)
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


void set_dcd_param_v2(dcd_v2_t *dcd_v2, uint32_t dcd_len,
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
	/* Set bitmask: *address |= val_msk */
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
	/* Any bit clear: (*address & mask) != mask */
	case CMD_CHECK_ANY_BIT_CLR:
		d = d2;
		d->write_dcd_command.tag = DCD_CHECK_DATA_COMMAND_TAG;
		d->write_dcd_command.length = cpu_to_be16(4);
		d->write_dcd_command.param = DCD_CHECK_ANY_BIT_CLR_PARAM;
		break;
	/* Any bit set: (*address & mask) != 0 */
	case CMD_CHECK_ANY_BIT_SET:
		d = d2;
		d->write_dcd_command.tag = DCD_CHECK_DATA_COMMAND_TAG;
		d->write_dcd_command.length = cpu_to_be16(4);
		d->write_dcd_command.param = DCD_CHECK_ANY_BIT_SET_PARAM;
		break;
	default:
		break;
	}
	gd_last_cmd = d;
}

void set_dcd_val_v2(dcd_v2_t *dcd_v2, char *name, int lineno,
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

void set_dcd_rst_v2(dcd_v2_t *dcd_v2, uint32_t dcd_len,
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
	printf("dcd size in bytes = %d\n", len);
}

void parse_cfg_cmd(dcd_v2_t *dcd_v2, int32_t cmd, char *token,
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
	case CMD_CHECK_ANY_BIT_SET:
	case CMD_CHECK_ANY_BIT_CLR:
		value = get_cfg_value(token, name, lineno);
		set_dcd_param_v2(dcd_v2, dcd_len, cmd);
		set_dcd_val_v2(dcd_v2, name, lineno, fld, value, dcd_len);
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

void parse_cfg_fld(dcd_v2_t *dcd_v2, int32_t *cmd,
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
		case CMD_CHECK_ANY_BIT_SET:
		case CMD_CHECK_ANY_BIT_CLR:
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

uint32_t parse_cfg_file(dcd_v2_t *dcd_v2, char *name)
{
	FILE *fd = NULL;
	char *line = NULL;
	char *token, *saveptr1, *saveptr2;
	int lineno = 0;
	int fld;
	size_t len;
	int dcd_len = 0;
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

	set_dcd_rst_v2(dcd_v2, dcd_len, name, lineno);
	fclose(fd);

	return dcd_len;
}

/*
 * Read commandline parameters and construct the header in order
 *
 * This will then construct the image according to the header and
 *
 * parameters passed in
 *
 */
int main(int argc, char **argv)
{
	int c;
	char *ofname = NULL;
	bool output = false;
	bool dcd_skip = false;
	bool emmc_fastboot = false;

	int container = -1;
	image_t param_stack[IMG_STACK_SIZE];/* stack of input images */
	int p_idx = 0;/* param index counter */

	uint32_t ivt_offset = IVT_OFFSET_SD;
	uint32_t sector_size = 0x200; /* default sector size */
	soc_type_t soc = NONE; /* Initially No SOC defined */
	rev_type_t rev = NO_REV; /* Initially No REV defined */

	static struct option long_options[] =
	{
		{"scfw", required_argument, NULL, 'f'},
		{"seco", required_argument, NULL, 'O'},
		{"m4", required_argument, NULL, 'm'},
		{"ap", required_argument, NULL, 'a'},
		{"dcd", required_argument, NULL, 'd'},
		{"out", required_argument, NULL, 'o'},
		{"flags", required_argument, NULL, 'l'},
		{"scd", required_argument, NULL, 'x'},
		{"csf", required_argument, NULL, 'z'},
		{"dev", required_argument, NULL, 'e'},
		{"soc", required_argument, NULL, 's'},
		{"rev", required_argument, NULL, 'r'},
		{"container", no_argument, NULL, 'c'},
		{"partition", required_argument, NULL, 'p'},
		{"commit", no_argument, NULL, 't'},
		{"append", no_argument, NULL, 'A'},
		{"data", required_argument, NULL, 'D'},
		{"fileoff", required_argument, NULL, 'P'},
		{"msg_blk", required_argument, NULL, 'M'},
		{NULL, 0, NULL, 0}
	};


	/* scan in parameters in order */
	while(1)
	{
		/* getopt_long stores the option index here. */
		int option_index = 0;

		c = getopt_long_only (argc, argv, ":f:m:a:d:o:l:x:z:e:p:c",
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
			case 'A':
				param_stack[p_idx].option = APPEND;
				param_stack[p_idx++].filename = argv[optind++];
				break;
			case 'p':
				fprintf(stdout, "PARTITION:\t%s\n", optarg);
				param_stack[p_idx].option = PARTITION;
				param_stack[p_idx++].entry = (uint32_t) strtoll(optarg, NULL, 0);
				break;
			case 's':
				if(!strncmp(optarg, "QX", 2))
					soc = QX;
				else if (!strncmp(optarg, "QM", 2))
					soc = QM;
				else{
					fprintf(stdout, "unrecognized SOC: %s \n",optarg);
					exit(EXIT_FAILURE);
				}
				fprintf(stdout, "SOC: %s \n",optarg);
				break;
			case 'r':
				if(soc == QX || soc == QM) {
					if(strcmp(optarg, "A0") == 0)
						rev = A0;
					else if(strcmp(optarg, "B0") == 0) {
						rev = B0;
						sector_size = 0x400;
					} else {
						fprintf(stdout, "unrecognized REVISION: %s \n",optarg);
						exit(EXIT_FAILURE);
					}
					fprintf(stdout, "REVISION: %s \n",optarg);
				}
				break;
			case 'f':
				fprintf(stdout, "SCFW:\t%s\n", optarg);
				param_stack[p_idx].option = SCFW;
				param_stack[p_idx++].filename = optarg;
				break;
			case 'O':
				fprintf(stdout, "SECO:\t%s\n", optarg);
				param_stack[p_idx].option = SECO;
				param_stack[p_idx++].filename = optarg;
				break;
			case 'd':
				fprintf(stdout, "DCD:\t%s\n", optarg);
				if (rev == B0) {
					if (!strncmp(optarg, "skip", 4)) {
						dcd_skip = true;
					} else {
						fprintf(stderr, "\n-dcd option requires argument skip\n\n");
						exit(EXIT_FAILURE);
					}
				} else {
					param_stack[p_idx].option = DCD;
					param_stack[p_idx].filename = optarg;
					p_idx++;
				}
				break;
			case 'D':
				if (rev == B0) {
					fprintf(stdout, "Data:\t%s\n", optarg);
					param_stack[p_idx].option = DATA;
					param_stack[p_idx].filename = optarg;
					if (optind < argc && *argv[optind] != '-')
						param_stack[p_idx].entry = (uint32_t) strtoll(argv[optind++], NULL, 0);
					else {
						fprintf(stderr, "\n-data option require TWO arguments: filename, load address in hex\n\n");
						exit(EXIT_FAILURE);
					}
					p_idx++;
				} else {
					fprintf(stderr, "\n-data option is only used with -rev B0.\n\n");
					exit(EXIT_FAILURE);
				}
				break;
			case 'm':
				fprintf(stdout, "CM4:\t%s", optarg);
				param_stack[p_idx].option = M4;
				param_stack[p_idx].filename = optarg;
				if ((optind < argc && *argv[optind] != '-') && (optind+1 < argc &&*argv[optind+1] != '-' )) {
					param_stack[p_idx].ext = strtol(argv[optind++], NULL, 0);
					param_stack[p_idx].entry = (uint32_t) strtoll(argv[optind++], NULL, 0);
					fprintf(stdout, "\tcore: %" PRIi64, param_stack[p_idx].ext);
					fprintf(stdout, " addr: 0x%08" PRIx64 "\n", param_stack[p_idx++].entry);
				} else {
					fprintf(stderr, "\n-m4 option require THREE arguments: filename, core: 0/1, start address in hex\n\n");
					exit(EXIT_FAILURE);
				}
				break;
			case 'a':
				fprintf(stdout, "AP:\t%s", optarg);
				param_stack[p_idx].option = AP;
				param_stack[p_idx].filename = optarg;
				if ((optind < argc && *argv[optind] != '-') && (optind+1 < argc &&*argv[optind+1] != '-' )) {
					if (!strncmp(argv[optind], "a53", 3))
						param_stack[p_idx].ext = CORE_CA53;
					else if (!strncmp(argv[optind], "a35", 3))
						param_stack[p_idx].ext = CORE_CA35;
					else if (!strncmp(argv[optind], "a72", 3))
						param_stack[p_idx].ext = CORE_CA72;
					else {
						fprintf(stderr, "ERROR: AP Core not found %s\n", argv[optind+2]);
						exit(EXIT_FAILURE);
					}
					fprintf(stdout, "\tcore: %s", argv[optind++]);

					param_stack[p_idx].entry = (uint32_t) strtoll(argv[optind++], NULL, 0);

					fprintf(stdout, " addr: 0x%08" PRIx64 "\n", param_stack[p_idx++].entry);
				} else {
					fprintf(stderr, "\n-ap option require THREE arguments: filename, a35/a53/a72, start address in hex\n\n");
					exit(EXIT_FAILURE);
				}
				break;
			case 'l':
				fprintf(stdout, "FLAG:\t%s\n", optarg);
				param_stack[p_idx].option = FLAG;
				param_stack[p_idx++].entry = (uint32_t) strtoll(optarg, NULL, 0);
				break;
			case 'o':
				fprintf(stdout, "Output:\t%s\n", optarg);
				ofname = optarg;
				output = true;
				break;
			case 'x':
				fprintf(stdout, "SCD:\t%s\n", optarg);
				param_stack[p_idx].option = SCD;
				param_stack[p_idx++].filename = optarg;
				break;
			case 'z':
				fprintf(stdout, "CSF:\t%s\n", optarg);
				param_stack[p_idx].option = CSF;
				param_stack[p_idx++].filename = optarg;
				break;
			case 'e':
				fprintf(stdout, "BOOT DEVICE:\t%s\n", optarg);
				if (!strcmp(optarg, "flexspi")) {
					ivt_offset = IVT_OFFSET_FLEXSPI;
				} else if (!strcmp(optarg, "sd")) {
					ivt_offset = IVT_OFFSET_SD;
				} else if (!strcmp(optarg, "nand")) {
					sector_size = 0x8000;/* sector size for NAND */
					if (rev == B0) {
						if (optind < argc && *argv[optind] != '-') {
							if (!strcmp(argv[optind], "4K")) {
								sector_size = 0x1000;
							} else if (!strcmp(argv[optind], "8K")) {
								sector_size = 0x2000;
							} else if (!strcmp(argv[optind], "16K")) {
								sector_size = 0x4000;
							} else
								fprintf(stdout, "\nwrong nand page size:\r\n 4K\r\n8K\r\n16K\n\n");
						} else {
							fprintf(stdout, "\n-dev nand requires the page size:\r\n 4K\r\n8K\r\n16K\n\n");
						}
					}
				} else if (!strcmp(optarg, "emmc_fast")) {
						ivt_offset = IVT_OFFSET_EMMC;
						emmc_fastboot = true;/* emmc boot */
				} else {
					fprintf(stdout, "\n-dev option, Valid boot devices are:\r\n sd\r\nflexspi\r\nnand\n\n");
					exit(EXIT_FAILURE);
				}
				break;
			case 'c':
					fprintf(stdout, "New Container: \t%d\n",++container);
					param_stack[p_idx++].option = NEW_CONTAINER;
					break;
			case ':':
				fprintf(stderr, "option %c missing arguments\n", optopt);
				exit(EXIT_FAILURE);
				break;
			case 't':
				fprintf(stdout, "%08x\n", MKIMAGE_COMMIT);
				exit(0);
				break;
			case 'P':
				fprintf(stdout, "FILEOFF:\t%s\n", optarg);
				param_stack[p_idx].option = FILEOFF;
				param_stack[p_idx++].dst = (uint64_t) strtoll(optarg, NULL, 0);
				break;
			case 'M':
				fprintf(stdout, "MSG BLOCK:\t%s", optarg);
				param_stack[p_idx].option = MSG_BLOCK;
				param_stack[p_idx].filename = optarg;
				if ((optind < argc && *argv[optind] != '-') && (optind+1 < argc &&*argv[optind+1] != '-' )) {
					if (!strncmp(argv[optind], "fuse", 4))
						param_stack[p_idx].ext = SC_R_OTP;
					else if (!strncmp(argv[optind], "debug", 5))
						param_stack[p_idx].ext = SC_R_DEBUG;
					else if (!strncmp(argv[optind], "field", 5))
						param_stack[p_idx].ext = SC_R_ROM_0;
					else {
						fprintf(stderr, "ERROR: MSG type not found %s\n", argv[optind+2]);
						exit(EXIT_FAILURE);
					}
					fprintf(stdout, "\ttype: %s", argv[optind++]);

					param_stack[p_idx].entry = (uint32_t) strtoll(argv[optind++], NULL, 0);

					fprintf(stdout, " addr: 0x%08" PRIx64 "\n", param_stack[p_idx++].entry);
				} else {
					fprintf(stderr, "\nmsg block option require THREE arguments: filename, debug/fuse/field, start address in hex\n\n");
					exit(EXIT_FAILURE);
				}
				break;
			case '?':
			default:
				/* invalid option */
				fprintf(stderr, "option '%c' is invalid: ignored\n",
					optopt);
				exit(EXIT_FAILURE);
		}
	}

	param_stack[p_idx].option = NO_IMG; /* null terminate the img stack */

	if(soc == NONE){
		fprintf(stderr, " No SOC defined");
		exit(EXIT_FAILURE);
	}

	if(container < 0)
	{ /* check to make sure there is at least 1 container defined */
		fprintf(stderr, " No Container defined");
		exit(EXIT_FAILURE);
	}

	if (!output) {
		fprintf(stderr, "mandatory args scfw and output file name missing! abort\n");
		exit(EXIT_FAILURE);
	}

	/* Now begin assembling the image acording to each SOC container */



	switch(soc)
	{
		case QX:
			if (rev == NO_REV) {
				fprintf(stdout, "No REVISION defined, using A0 by default\n");
				rev = A0;
			}
			fprintf(stdout, "ivt_offset:\t%d\n", ivt_offset);
			fprintf(stdout, "rev:\t%d\n", rev);
			if (rev == B0)
				build_container_qx_qm_b0(soc, sector_size, ivt_offset, ofname, emmc_fastboot, (image_t *) param_stack, dcd_skip);
			else
				build_container_qx(sector_size, ivt_offset, ofname, emmc_fastboot, (image_t *) param_stack);

			break;
		case QM:
			if (rev == B0)
				build_container_qx_qm_b0(soc, sector_size, ivt_offset, ofname, emmc_fastboot, (image_t *) param_stack, dcd_skip);
			else
				build_container_qm(sector_size, ivt_offset, ofname, emmc_fastboot, (image_t *) param_stack);
			break;
		default:
			fprintf(stderr, " unrecognized SOC defined");
			exit(EXIT_FAILURE);
	}


	fprintf(stdout, "DONE.\n");
	fprintf(stdout, "Note: Please copy image to offset: IVT_OFFSET + IMAGE_OFFSET\n");

	return 0;
}

