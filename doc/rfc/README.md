<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2021 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2021 -->

# Lumion Specification

This directory contains the Lumion specification. We are maintaining it using
IETF tools for RFC generation because we think that it should become an RFC.
This is the only specification for Lumions, and is the reference for LumoSQL
and other software we write that handle Lumions in various ways.

At present (December 2021) this RFC is only the barest sketch outline.

# Toolchain

The [mmark IETF Markdown tool](https://github.com/mmarkdown/mmark) is a big
help, and comes with example RFCs. 

The quickest way to start is to copy the file draft-shearer-desmet-calvelli-lumionsrfc-00.md
into the rfc directory in the mmark tree, and then type 'make'. That will produce a new .txt
version.

# Inspiration

The [Syslog Specification in RFC 5424](https://datatracker.ietf.org/doc/html/rfc5424) is one reasonably close
RFC for comparing and contrast.

