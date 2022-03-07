# Top-level Makefile for the LumoSQL project
#
# Copyright 2019 The LumoSQL Authors under the terms contained in LICENSES/MIT
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2019 The LumoSQL Authors
# SPDX-ArtifactOfProjectName: LumoSQL
# SPDX-FileType: Code
# SPDX-FileComment: Original by Keith Maxwell, 2019 
# 
# /Makefile
#
# Documented at https://lumosql.org/src/lumosql/doc/tip/doc/lumo-build-benchmark.md

# default target will build SQLITE_VERSIONS and all the other TARGETS
all: build

# if there is a Makefile.local we use it to get defaults
-include Makefile.local

# if we start checking for more versions, this will need to go into a
# separate script!
ifeq ($(TCL),)
ifneq ($(shell which tclsh),)
TCL := tclsh
else
ifneq ($(shell which tclsh8.7),)
TCL := tclsh8.7
else
ifneq ($(shell which tclsh8.6),)
TCL := tclsh8.6
else
$(error Could not find tclsh)
endif
endif
endif
endif

# provide defaults for DISK_COMMENT and CPU_COMMENT if we know how to
CPU_COMMENT ?= $(shell $(TCL) tool/hardware-detect.tcl)
ifeq ($(DB_DIR),)
DISK_COMMENT ?= $(shell $(TCL) tool/hardware-detect.tcl '$(BUILD_DIR)')
else
DISK_COMMENT ?= $(shell $(TCL) tool/hardware-detect.tcl '$(DB_DIR)')
endif

# now include build options etc - this file will be generated from the
# not-fork.d directory
include Makefile.options

# build directory
BUILD_DIR ?= build

# database name
DATABASE_NAME ?= benchmarks.sqlite
TEST_DATABASE_NAME ?= tests.sqlite

build: Makefile.options
	$(TCL) tool/build.tcl build not-fork.d $(BUILD_DIR) $(BUILD_OPTIONS)

cleanup: Makefile.options
	$(TCL) tool/build.tcl cleanup not-fork.d $(BUILD_DIR) $(BUILD_OPTIONS)

benchmark: Makefile.options $(DATABASE_NAME)
	$(TCL) tool/build.tcl benchmark not-fork.d $(BUILD_DIR) $(DATABASE_NAME) $(BUILD_OPTIONS)

test: Makefile.options $(TEST_DATABASE_NAME)
	$(TCL) tool/build.tcl test not-fork.d $(BUILD_DIR) $(TEST_DATABASE_NAME) $(BUILD_OPTIONS)

database: $(DATABASE_NAME)
$(DATABASE_NAME):
	$(TCL) tool/build.tcl database not-fork.d $(BUILD_DIR) $(DATABASE_NAME)
$(TEST_DATABASE_NAME):
	$(TCL) tool/build.tcl database not-fork.d $(BUILD_DIR) $(TEST_DATABASE_NAME)

# show what targets would be built, useful to test combinations of command-line
# options
what:
	$(TCL) tool/build.tcl what not-fork.d $(BUILD_OPTIONS)

targets:
	$(TCL) tool/build.tcl targets not-fork.d $(BUILD_OPTIONS)

Makefile.options: not-fork.d/*/benchmark tool/build.tcl
	$(TCL) tool/build.tcl options not-fork.d $@

clean:
	rm -rf $(BUILD_DIR)

realclean: clean
	rm -f $(BENCHMARK_DB)

# discovered with apt-get build-dep
BUILD_DEPENDENCIES := $(BUILD_DEPENDENCIES) \
	build-essential \
	debhelper \
	autoconf \
	libtool \
	automake \
	chrpath \
	libreadline-dev \
	tcl8.6-dev \
# for cloning over https with git
BUILD_DEPENDENCIES := $(BUILD_DEPENDENCIES) git ca-certificates
# for /usr/bin/tclsh, tcl8.6-dev brings in tcl8.6 which only includes tclsh8.6
BUILD_DEPENDENCIES := $(BUILD_DEPENDENCIES) tcl

container:
	container1="$$(buildah from ubuntu:18.04)" && \
	buildah run "$$container1" -- /bin/sh -c "apt-get update \
		&& DEBIAN_FRONTEND=noninteractive apt-get install \
			--no-install-recommends --yes $(BUILD_DEPENDENCIES) \
		&& rm -rf /var/lib/apt/lists/*" && \
	buildah config \
		--entrypoint '[ "make", "-C", "/usr/src" ]' \
		--cmd bin \
		"$$container1" && \
	buildah commit --rm "$$container1" make
# To build and run within a container:
#   make container
#   podman run -v .:/usr/src:Z make
#   podman run -v .:/usr/src:Z make bld-LMDB_0.9.9
#   podman run -v .:/usr/src:Z --interactive --tty --entrypoint=/bin/bash make

.PHONY: clean bin container get_sources build benchmark all

# Lumo build system currently does not support parallel build at this level
.NOTPARALLEL:

