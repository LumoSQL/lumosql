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

# targets to build/benchmark by default; format is sqlite_version[+backend_name-version]
# the target naming scheme will be extended in future to add more dimensions,
# for example sqlite_version+[backend_name-version][+option-value]...
# to repeat a test target TT one could just run "make benchmark TARGETS=TT"
TARGETS ?= 3.7.17 3.30.1 3.33.0 3.7.17+lmdb-0.9.9 3.7.17+lmdb-0.9.16 3.7.17+lmdb-0.9.26

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
