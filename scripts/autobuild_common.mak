# For pulling archives internally. Example usage:
# $ export SERVER=https://us-nxrm.sw.nxp.com
# $ make SOC=iMX8QM nightly_mek

WGET = /usr/bin/wget
N ?= latest
ROOTDIR ?= repository/IMX-raw_Linux_Internal_Daily_Build
BUILD ?= Linux_IMX_Core
DIR = $(ROOTDIR)/$(BUILD)/$(N)/common_bsp
ARCHIVE_PATH ?= ~
ARCHIVE_NAME ?= $(shell cat nightly.txt).tar
USE_COMMON_LOCATION ?= true

ifeq (,$(findstring nxrm,$(SERVER)))
ROOTDIR := internal-only
RWGET = /usr/bin/wget -qr -nd -l1 -np
else
ifneq ($(shell test -e ~/.netrc && echo -n yes),yes)
$(warning No ~/.netrc found!)
endif
ifeq ($(N),latest)
override N := $(shell $(WGET) -q --output-document - $(SERVER)/$(ROOTDIR)/$(BUILD)/latest)
endif

ifeq ($(USE_COMMON_LOCATION),true)
COMMON_BUILD_VERSION := $(shell $(WGET) -q --output-document - $(SERVER)/$(ROOTDIR)/$(BUILD)/$(N)/common_build_version.txt || echo -n 0)
ifneq ($(COMMON_BUILD_VERSION),0)
COMMON_LOCATION := $(shell $(WGET) -q --output-document - $(SERVER)/$(ROOTDIR)/$(BUILD)/$(N)/common_location.txt)
DIR = $(COMMON_LOCATION)/../common_bsp
else
COMMON_BUILD_VERSION := $(shell $(WGET) -q --output-document - $(SERVER)/$(ROOTDIR)/$(BUILD)/$(N)/boottools_build_version.txt || echo -n 0)
ifneq ($(COMMON_BUILD_VERSION),0)
COMMON_LOCATION := $(shell $(WGET) -q --output-document - $(SERVER)/$(ROOTDIR)/$(BUILD)/$(N)/boottools_location.txt)
DIR = $(COMMON_LOCATION)/../common_bsp
endif
endif
endif

RWGET = echo Skipping
endif
