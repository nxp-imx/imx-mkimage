#!/bin/sh
#
# script to generate FIT image source for i.MX8MQ boards with
# ARM Trusted Firmware and multiple device trees (given on the command line)
#

[ -z "$BL31" ] && BL31="bl31.bin"
# keep backward compatibility
[ -z "$TEE_LOAD_ADDR" ] && TEE_LOAD_ADDR="0xfe000000"

if [ ! -f $BL31 ]; then
	echo "ERROR: BL31 file $BL31 NOT found" >&2
	exit 0
else
	echo "bl31.bin size: " >&2
	ls -lct bl31.bin | awk '{print $5}' >&2
fi

BL32="tee.bin"

if [ ! -f $BL32 ]; then
	BL32=/dev/null
else
	echo "Building with TEE support, make sure your bl31 is compiled with spd. If you do not want tee, please delete tee.bin" >&2
	echo "tee.bin size: " >&2
	ls -lct tee.bin | awk '{print $5}' >&2
fi

BL33="u-boot-hash.bin"

if [ ! -f $BL33 ]; then
	echo "ERROR: $BL33 file NOT found" >&2
	exit 0
else
	echo "$BL33 size: " >&2
	ls -lct u-boot-hash.bin | awk '{print $5}' >&2
fi

cat << __HEADER_EOF
/dts-v1/;

/ {
	description = "Configuration to load ATF before U-Boot";

	images {
		uboot@1 {
			description = "U-Boot (64-bit)";
			data = /incbin/("$BL33");
			type = "standalone";
			arch = "arm64";
			compression = "none";
			load = <0x80020000>;
		};
		atf@1 {
			description = "ARM Trusted Firmware";
			data = /incbin/("$BL31");
			type = "firmware";
			arch = "arm64";
			compression = "none";
			load = <0x80000000>;
			entry = <0x80000000>;
		};
__HEADER_EOF

if [ -f $BL32 ]; then
cat << __HEADER_EOF
		tee@1 {
			description = "TEE firmware";
			data = /incbin/("$BL32");
			type = "firmware";
			arch = "arm64";
			compression = "none";
			load = <$TEE_LOAD_ADDR>;
			entry = <$TEE_LOAD_ADDR>;
		};
__HEADER_EOF
fi

cat << __CONF_HEADER_EOF
	};
	configurations {
		default = "config@1";

__CONF_HEADER_EOF

if [ -f $BL32 ]; then
cat << __CONF_SECTION1_EOF
		config@1 {
			description = "fsl-imx8qxp-mek";
			firmware = "uboot@1";
			loadables = "atf@1", "tee@1";
		};
__CONF_SECTION1_EOF
else
cat << __CONF_SECTION1_EOF
		config@1 {
			description = "fsl-imx8qxp-mek";
			firmware = "uboot@1";
			loadables = "atf@1";
		};
__CONF_SECTION1_EOF
fi

cat << __ITS_EOF
	};
};
__ITS_EOF
