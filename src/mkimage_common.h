/*
 * Copyright (C) 2017 NXP
 *
 * SPDX-License-Identifier:     GPL-2.0+
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
#include <stdbool.h>

#ifndef O_BINARY
#define O_BINARY 0
#endif


typedef enum option_type {
    NO_IMG = 0,
    DCD,
    SCFW,
    SECO,
    M4,
    AP,
    OUTPUT,
    SCD,
    CSF,
    FLAG,
    DEVICE,
    NEW_CONTAINER,
    APPEND,
    DATA,
    PARTITION,
    FILEOFF,
    MSG_BLOCK
} option_type_t;


typedef struct {
      option_type_t option;
      char* filename;
      uint64_t src;
      uint64_t dst;
      uint64_t entry;/* image entry address or general purpose num */
      uint64_t ext;
} image_t;

typedef enum REVISION_TYPE {
    NO_REV = 0,
    A0,
    B0
} rev_type_t;

typedef enum SOC_TYPE {
    NONE = 0,
    QX,
    QM
} soc_type_t;

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

#define MAX_HW_CFG_SIZE_V2 359

struct dcd_v2_cmd {
        write_dcd_command_t write_dcd_command; /*4*/
        dcd_addr_data_t addr_data[MAX_HW_CFG_SIZE_V2]; /*2872*/
} __attribute__((packed));

typedef struct {
        ivt_header_t header;   /*4*/
        struct dcd_v2_cmd dcd_cmd; /*2876*/
} __attribute__((packed)) dcd_v2_t;                     /*2880*/

#define CORE_SC         1
#define CORE_CM4_0      2
#define CORE_CM4_1      3
#define CORE_CA53       4
#define CORE_CA35       4
#define CORE_CA72       5
#define CORE_SECO       6

#define SC_R_OTP                  357U
#define SC_R_DEBUG                354U
#define SC_R_ROM_0                236U

#define MSG_DEBUG_EN    SC_R_DEBUG
#define MSG_FUSE        SC_R_OTP
#define MSG_FIELD       SC_R_ROM_0

#define IMG_TYPE_CSF     0x01   /* CSF image type */
#define IMG_TYPE_SCD     0x02   /* SCD image type */
#define IMG_TYPE_EXEC    0x03   /* Executable image type */
#define IMG_TYPE_DATA    0x04   /* Data image type */
#define IMG_TYPE_DCD_DDR 0x05   /* DCD/DDR image type */
#define IMG_TYPE_SECO    0x06   /* SECO image type */
#define IMG_TYPE_PROV    0x07   /* Provisioning image type */
#define IMG_TYPE_DEK     0x08   /* DEK validation type */

#define IMG_TYPE_SHIFT   0
#define IMG_TYPE_MASK    0x1f
#define IMG_TYPE(x)      (((x) & IMG_TYPE_MASK) >> IMG_TYPE_SHIFT)

#define BOOT_IMG_FLAGS_CORE_MASK        0xF
#define BOOT_IMG_FLAGS_CORE_SHIFT       0x04
#define BOOT_IMG_FLAGS_CPU_RID_MASK     0x3FF0
#define BOOT_IMG_FLAGS_CPU_RID_SHIFT    4
#define BOOT_IMG_FLAGS_MU_RID_MASK      0xFFC000
#define BOOT_IMG_FLAGS_MU_RID_SHIFT     14
#define BOOT_IMG_FLAGS_PARTITION_ID_MASK        0x1F000000
#define BOOT_IMG_FLAGS_PARTITION_ID_SHIFT       24

#define SC_R_A35_0      508
#define SC_R_A53_0      1
#define SC_R_A72_0      6
#define SC_R_MU_0A      213
#define SC_R_M4_0_PID0  278
#define SC_R_M4_0_MU_1A 297
#define SC_R_M4_1_PID0  298
#define SC_R_M4_1_MU_1A 317
#define PARTITION_ID_M4 0
#define PARTITION_ID_AP 1

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

#define IVT_VER                         0x01
#define IVT_VERSION                     0x43
#define DCD_HEADER_TAG                  0xD2
#define DCD_VERSION                     0x43
#define DCD_WRITE_DATA_COMMAND_TAG      0xCC
#define DCD_WRITE_DATA_PARAM            (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT) /* 0x4 */
#define DCD_WRITE_CLR_BIT_PARAM         ((HAB_CMD_WRT_DAT_MSK << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0xC */
#define DCD_WRITE_SET_BIT_PARAM         ((HAB_CMD_WRT_DAT_MSK << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_CMD_WRT_DAT_SET << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0x1C */
#define DCD_CHECK_DATA_COMMAND_TAG      0xCF
#define DCD_CHECK_BITS_CLR_PARAM        (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT) /* 0x04 */
#define DCD_CHECK_BITS_SET_PARAM        ((HAB_CMD_CHK_DAT_SET << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0x14 */
#define DCD_CHECK_ANY_BIT_CLR_PARAM     ((HAB_CMD_CHK_DAT_ANY << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0x24 */
#define DCD_CHECK_ANY_BIT_SET_PARAM     ((HAB_CMD_CHK_DAT_ANY << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_CMD_CHK_DAT_SET << HAB_CMD_WRT_DAT_FLAGS_SHIFT) | (HAB_DATA_WIDTH_WORD << HAB_CMD_WRT_DAT_BYTES_SHIFT)) /* 0x34 */

#define IVT_OFFSET_NAND         (0x400)
#define IVT_OFFSET_I2C          (0x400)
#define IVT_OFFSET_FLEXSPI      (0x1000)
#define IVT_OFFSET_SD           (0x400)
#define IVT_OFFSET_SATA         (0x400)
#define IVT_OFFSET_EMMC         (0x400)

#define CSF_DATA_SIZE       (0x4000)
#define INITIAL_LOAD_ADDR_SCU_ROM 0x2000e000
#define INITIAL_LOAD_ADDR_AP_ROM 0x00110000
#define INITIAL_LOAD_ADDR_FLEXSPI 0x08000000
#define IMG_AUTO_ALIGN 0x10

#define ALIGN(x,a)              __ALIGN_MASK((x),(__typeof__(x))(a)-1)
#define __ALIGN_MASK(x,mask)    (((x)+(mask))&~(mask))

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
# define cpu_to_le16(x)         (x)
# define cpu_to_le32(x)         (x)
# define cpu_to_le64(x)         (x)
# define le16_to_cpu(x)         (x)
# define le32_to_cpu(x)         (x)
# define le64_to_cpu(x)         (x)
# define cpu_to_be16(x)         uswap_16(x)
# define cpu_to_be32(x)         uswap_32(x)
# define cpu_to_be64(x)         uswap_64(x)
# define be16_to_cpu(x)         uswap_16(x)
# define be32_to_cpu(x)         uswap_32(x)
# define be64_to_cpu(x)         uswap_64(x)
#else
#error
# define cpu_to_le16(x)         uswap_16(x)
# define cpu_to_le32(x)         uswap_32(x)
# define cpu_to_le64(x)         uswap_64(x)
# define le16_to_cpu(x)         uswap_16(x)
# define le32_to_cpu(x)         uswap_32(x)
# define le64_to_cpu(x)         uswap_64(x)
# define cpu_to_be16(x)         (x)
# define cpu_to_be32(x)         (x)
# define cpu_to_be64(x)         (x)
# define be16_to_cpu(x)         (x)
# define be32_to_cpu(x)         (x)
# define be64_to_cpu(x)         (x)
#endif

#define UNDEFINED 0xFFFFFFFF

#if 0
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
        int     id;
        char    *sname;         /* short (input) name to find table entry */
        char    *lname;         /* long (output) name to print for messages */
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
#endif

void check_file(struct stat* sbuf,char * filename);
void copy_file (int ifd, const char *datafile, int pad, int offset);
uint32_t get_cfg_value(char *token, char *name,  int linenr);
void set_dcd_param_v2(dcd_v2_t *dcd_v2, uint32_t dcd_len,
                int32_t cmd);
void set_dcd_val_v2(dcd_v2_t *dcd_v2, char *name, int lineno,
                                        int fld, uint32_t value, uint32_t off);
void set_dcd_rst_v2(dcd_v2_t *dcd_v2, uint32_t dcd_len,
                                                char *name, int lineno);
void parse_cfg_cmd(dcd_v2_t *dcd_v2, int32_t cmd, char *token,
                                char *name, int lineno, int fld, int dcd_len);
void parse_cfg_fld(dcd_v2_t *dcd_v2, int32_t *cmd,
                char *token, char *name, int lineno, int fld, int *dcd_len);
uint32_t parse_cfg_file(dcd_v2_t *dcd_v2, char *name);

int build_container_qm(uint32_t sector_size, uint32_t ivt_offset, char * out_file,
                bool emmc_fastboot, image_t* image_stack);

int build_container_qx(uint32_t sector_size, uint32_t ivt_offset, char * out_file,
                bool emmc_fastboot, image_t* image_stack);

int build_container_qx_qm_b0(soc_type_t soc, uint32_t sector_size, uint32_t ivt_offset, char * out_file,
                bool emmc_fastboot, image_t* image_stack, bool dcd_skip);


