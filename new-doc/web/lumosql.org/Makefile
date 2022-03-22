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

SOURCES := $(shell find . -type f -name '*.md')
TARGETS := $(patsubst /%.md,/%.html,$(SOURCES))

ifneq ($(shell which pandoc),)
	PANDOC := $(shell which pandoc)
else
	$(error Could not find Pandoc)
endif

#.PHONY: clean
#clean:
#	rm $(TARGETS)

# Generalized rule: how to build a .html file from each .md
# Note: you will need pandoc 2 or greater for this to work
%.html: %.md 
	$(PANDOC) --from markdown+pipe_tables --to html5+smart --template=template --toc --css=skylighting-solarized-theme.css --output "$@" "$<"

