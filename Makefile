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
VERSIONS ?= SQLite-3.7.17 SQLite-3.30.1 LMDB_0.9.9 LMDB_0.9.16

all: $(addprefix bld-,$(VERSIONS))

benchmark: $(addsuffix .html,$(VERSIONS))

clean:
	rm -rf bld-* *.html

NOTFORK_DIR = $(shell pwd)/sources

bld-SQLite-%:
	# Build sqlite using not-fork
	./tool/get-lumo-sources $(NOTFORK_DIR) test $*
	./tool/build-lumo-backend $@ $(NOTFORK_DIR)

bld-LMDB_%:
	# build sqlite3 + lmdb using not-fork
	./tool/get-lumo-sources $(NOTFORK_DIR) test 3.7.17 lmdb $*
	./tool/build-lumo-backend $@ $(NOTFORK_DIR)

%.html: bld-%
	-rm -f $@
	./tool/run-lumo-tests -h $@ $<

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
