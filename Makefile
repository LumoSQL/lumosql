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
# Documented at https://lumosql.org/src/lumosql/doc/tip/doc/lumo-test-build.md

# version of sqlite3 to use for the benchmark database; by default this
# version is also benchmarked but see next comment
SQLITE_VERSION ?= 3.33.0

# version of sqlite3 to use with the LMDB backend and LMDB versions to use by default
USE_LMDB ?= yes
SQLITE_FOR_LMDB ?= 3.8.3.1
LMDB_VERSIONS ?= 0.9.9 0.9.16 0.9.27
LMDB_TARGETS ?= $(addprefix $(SQLITE_FOR_LMDB)+lmdb-,$(LMDB_VERSIONS))

# version of sqlite3 to use with the BDB backend and BDB versions to use by default
USE_BDB ?= no
SQLITE_FOR_BDB ?= 3.18.2
BDB_VERSIONS ?= 18.1.32
#BDB_VERSIONS ?= 18.1.32 18.1.40
BDB_TARGETS ?= $(addprefix $(SQLITE_FOR_BDB)+bdb-,$(BDB_VERSIONS))

# make a list of modified and unmodified sqlite3 targets
SQLITE_TARGETS = $(SQLITE_VERSION)
BACKEND_TARGETS =

ifeq ($(USE_LMDB),yes)
ifeq ($(findstring $(SQLITE_FOR_LMDB),$(SQLITE_TARGETS)),)
SQLITE_TARGETS += $(SQLITE_FOR_LMDB)
BACKEND_TARGETS += $(LMDB_TARGETS)
endif
endif

ifeq ($(USE_BDB),yes)
ifeq ($(findstring $(SQLITE_FOR_BDB),$(SQLITE_TARGETS)),)
SQLITE_TARGETS += $(SQLITE_FOR_BDB)
BACKEND_TARGETS += $(BDB_TARGETS)
endif
endif

# targets to build/benchmark by default; format is sqlite_version[+backend_name-version]
# the target naming scheme will be extended in future to add more dimensions,
# for example sqlite_version+[backend_name-version][+option-value]...
# to repeat a test target TT one could just run "make benchmark TARGETS=TT"
TARGETS ?= $(SQLITE_TARGETS) $(BACKEND_TARGETS)

# build directory
BUILD_DIR ?= build

# results database
BENCHMARK_DB ?= benchmarks.sqlite

# number of sets to run for each version
BENCHMARK_RUNS ?= 1

# directory where we keep the modified sources to build
NOTFORK_DIR ?= $(shell pwd)/sources

# default target will build SQLITE_VERSION and all the other TARGETS
all: $(BUILD_DIR) $(addprefix $(BUILD_DIR)/,$(SQLITE_VERSION) $(TARGETS))

# show what targets would be built, useful to test combinations of command-line
# options
what:
	@echo SQLITE_VERSION=$(SQLITE_VERSION)
	@echo USE_LMDB=$(USE_LMDB)
	@echo SQLITE_FOR_LMDB=$(SQLITE_FOR_LMDB)
	@echo LMDB_VERSIONS=$(LMDB_VERSIONS)
	@echo USE_BDB=$(USE_BDB)
	@echo SQLITE_FOR_BDB=$(SQLITE_FOR_BDB)
	@echo BDB_VERSIONS=$(BDB_VERSIONS)
	@echo TARGETS=
	@for n in $(TARGETS); do echo "    $$n"; done

$(BUILD_DIR) :
	mkdir -p $(BUILD_DIR)
$(BUILD_DIR)/% :
	./tool/get-lumo-sources $(NOTFORK_DIR) test $*
	./tool/build-lumo-backend $@ $(NOTFORK_DIR)

# "benchmark" target will build the same as above then runs one or more
# runs for each target
benchmark : all $(BUILD_DIR)/$(SQLITE_VERSION)
	tclsh tool/benchmark.tcl $(BUILD_DIR) $(BENCHMARK_DB) $(SQLITE_VERSION) \
	$(BENCHMARK_RUNS) $(TARGETS)

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
# To build and run withint a container:
#   make container
#   podman run -v .:/usr/src:Z make
#   podman run -v .:/usr/src:Z make bld-LMDB_0.9.9
#   podman run -v .:/usr/src:Z --interactive --tty --entrypoint=/bin/bash make

.PRECIOUS: bld-LMDB_% bld-SQLite-% src-lmdb
.PHONY: clean bin container
