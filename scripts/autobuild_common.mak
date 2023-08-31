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
BOOTTOOLS_BUILD_VERSION := $(shell $(WGET) -q --output-document - $(SERVER)/$(ROOTDIR)/$(BUILD)/$(N)/boottools_build_version.txt || echo -n 0)
ifneq ($(BOOTTOOLS_BUILD_VERSION),0)
BOOTTOOLS_LOCATION := $(shell $(WGET) -q --output-document - $(SERVER)/$(ROOTDIR)/$(BUILD)/$(N)/boottools_location.txt)
DIR = $(ROOTDIR)/$(BOOTTOOLS_LOCATION)/../common_bsp
endif
endif

RWGET = echo Skipping
endif
