<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2022 The LumoSQL Authors, see LICENSES/MIT -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2021 -->

# About Lumions

The privacy and security features of LumoSQL are based on the concept of a
portable binary blob that is encrypted and signed, and optionally has within it
different levels of access to the data, ie RBAC. We soon realised this should
be a single global standard for all data storage, and that there was no such
standard already. The security and privacy requirements of the 21st century
demand something like this, so we created it.

This is a collaboration involving the [LumoSQL team](https://lumosql.org/), the
[Department of Electronics and Informatics](http://www.etrovub.be/) of the
[Vrije Universiteit Brussel](https://www.vub.be/) and others.

# Lumion RFC Specification

This directory contains the Lumion specification. We are maintaining it using
IETF tools for RFC generation because we think it should become an RFC.  This
RFC draft is the only specification for Lumions, and is the reference for
LumoSQL and other software we write that handle Lumions in various ways.

The draft RFC [draft-shearer-desmet-calvelli-lumionsrfc-00.txt](draft-shearer-desmet-calvelli-lumionsrfc-00.txt) is 
taking shape.

We maintain the text in the markdown file
[draft-shearer-desmet-calvelli-lumionsrfc-00.md](draft-shearer-desmet-calvelli-lumionsrfc-00.md),
with IETF-specific markdown extensions as described in
[Dan York's RFC Markdown Examples](https://github.com/danyork/writing-internet-drafts-in-markdown/).

The IETF does not support markdown, their specification is entirely in XML.
The Lumions RFC uses a pre-processing tool called mmark to read IETF-specific
markdown and produce IETF-compatible XML. The IETF has a tool called xml2rfc
that will emit either a standard .txt file (similar to all RFCs for the last
half century) or a pdf.

# Toolchain

The Lumion RFC is maintained in Markdown, as specified for and processed by the
[mmark IETF Markdown tool](https://github.com/mmarkdown/mmark) tool, which
tracks the RFC file format specification v3, as per the
[draft RFC 7991](https://datatracker.ietf.org/doc/html/rfc7991).

The only mmark dependency is the python tool xml2rfc. Always use the [xml2rfc version number used by Pypi](https://pypi.org/project/xml2rfc/) even if you do not use "pip install", because that is what [mmark defines as "latest version"](https://github.com/mmarkdown/mmark/issues/172#issuecomment-1025528296).

The Pipy version of xml2rfc approximately tracks the [official IETF
repo](https://svn.ietf.org/svn/tools/xml2rfc/trunk xml2rfc) which is maintained
by the [comprehensive IETF project](https://xml2rfc.tools.ietf.org/). This
project is formalising a 50 year-old file format with great care.

To create the Lumoion RFC from the markdown:

* "pip install xml2rfc", or use some other installation method that yields a version >= Pypi. Older operating systems will not give a good version via "pip", so either learn about pip or change OS version.
* Install the Go language (often called "golang" in package repositories)
* git clone https://github.com/mmarkdown/mmark ; cd mmark
* go get && go build
* ./mmark -version     <-- test the binary
* cd rfc ; make        <-- this should rebuild the .txt files for the sample RFCs

Test the toolchain for the Lumion RFC:

* copy the file draft-shearer-desmet-calvelli-lumionsrfc-00.md to mmark/rfc
* make 

If this generates draft-shearer-desmet-calvelli-lumionsrfc-00.txt then your
toolchain is working. Change paths etc to your taste.

You may wish to try "make pdf". xml2rfc will reliably tell you what additional
dependencies it needs, if any.

# Inspiration for the Lumoions RFC Content Headings

In terms of the content of the *text* version of the RFC (not the details of the markdown), 
the [Syslog Specification in RFC 5424](https://datatracker.ietf.org/doc/html/rfc5424) is perhaps reasonably
close to the sections the Lumions RFC needs.

