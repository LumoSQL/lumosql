<!-- Copyright 2021 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2021 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, February 2021 -->

<!-- toc -->

# Google Summer of Code Ideas

This list was made for the LumoSQL project's application for 
[Google Summer of Code](https://summerofcode.withgoogle.com/) in 2021. GSoC pays students to
contribute to free software projects during the Northern Hemiphere summer.  If
you are a student, you will be able to apply for GSoC starting March 29th 2021.

# Benchmarking tasks

We have design outlines and background documentation for the following.

* LumoSQL benchmarking creates an SQLite database. Write a tool to accept these databases via the web and consolitate them, using the facilities existing in [benchmark-filter.tcl](../tool/benchmark-filter.tcl)
* Write a tool to drive [benchmarking](./lumo-build-benchmark.md) runs for different [pragmas](https://sqlite.org/pragma.html#toc) to start to address the problem that [all SQLite performance papers are nonsense](https://lumosql.org/src/lumodoc/doc/trunk/doc/lumo-benchmarking.md#all-sqlite-performance-papers-are-nonsense).
* Write a tool that analyses a consolidated benchmarking database and displays summary results over the web

# Lumo Column tasks

* Consider the LumoSQL "Lumo Column" implementation (full documentation not yet available). Look at the code for implementing per-row checksums in an implicit column that exists the same way as [SQLite ROWID](https://www.sqlite.org/lang_createtable.html#rowid) exists. All four sha3 hash formats are supported, besides "none" and "null". Add two new hash formats by extending the table for BLAKE2 and BLAKE3.
* This is an advanced task: working with LumoSQL developers, design SQL row-level equivalents to Unix mtime, ctime and atime using Lumo Columns. A Lumo Column is a blob with a header; you will need to change the header used for rowsums. All of the work required for this will be within the file vdbe.c
* Implement row-level mtime, ctime and atime using Lumo Columns

# Backend storage tasks

* Document the LumoSQL-specific user interface changes needed for backends. This involves looking at the features of BDB and LMDB including the existing BDB pragmas, and designing something more generic. This needs to work across other backend stores too, so comparing BDB (which probably isn't going to be the amazing storage engine of the future!) and LMDB and native SQLite is likely to give reasonable results
* Design a way of moving the BDB sources into a patch system like LumoSQL not-forking directory does for LMDB, rather than whole-file replacements
* Implement a not-forking directory following the design developed above. This should mean that the BDB backend works with more recent versions of SQLite, and where it does not, that the changes will be more obvious and easier to make
* Considering existing Not-Forking work done already, and the section "List of MVCC-capable KV store-related Knowledge" in the [LumoSQL Knowledgebase](https://lumosql.org/src/lumodoc/doc/trunk/doc/lumo-relevant-knowledgebase.md), prototype a backend for the Malbrain's btree. What might the advantages and disadvantges be of this storage engine? This is leading-edge experimentation, because there are very few new Btree storage engines, and exactly none of them under SQLite

# Tooling tasks

* Add a feature to [Not-Forking](https://lumosql.org/src/not-forking) so that it somewhat aware of licenses. For example, at the moment the LumoSQL build process gives the option of building with LMDB ([MIT licensed](https://en.wikipedia.org/wiki/MIT_License)), native SQLite ([kind-of licensed under sort-of public domain](https://sqlite.org/copyright.html)) and Berkeley DB ([AGPL](https://www.gnu.org/licenses/agpl-3.0.en.html)). The LumoSQL code has a [LICENCES/](https://lumosql.org/src/lumosql/dir?ci=tip&name=LICENCES) directory pointed at by [SPDX](https://spdx.dev) headers on all LumoSQL files. But these other codebases do not, and the interactions are different. The Berkeley DB licence subsumes all others and any resulting binary is under the AGPL. The LumoSQL/LMDB MIT subsumes the SQlite license and any resulting binary is under the MIT. At least one additional proposed backend is under the 2-clause BSD license, which is compatible with MIT and SQLite and AGPL, etc. Not-Forking needs a mechanism of signalling that it is grafting on code with a particular license - it does not need to do legal calculations about which license wins, but it does need to make it obvious which licenses apply. There are various possible designs, and the LumoSQL team would be glad to work with you on this.
* Fix a documentation problem by writing a [Pandoc](https://pandoc.org) filter that understands [Fossil markdown](https://fossil-scm.org/home/md_rules). This was considered but abandoned as [out of scope for Fossil](https://fossil-scm.org/home/timeline?r=auto-toc). Pandoc processing of Markdown -> Markdown would give other advantages than TOCs.
* Fix a documentation problem by writing a Pandoc filter that understands [Pikchr](https://pikchr.org), which would apply to all Pandoc inputs including Markdown documentation such as used by LumoSQL
* Develop a basic buildfarm so that Fossil is regularly built and tested with (a) multiple architectures - one big endian and (b) multiple build-time options. This would use the [Fossil hook](https://www.fossil-scm.org/home/help?cmd=hook) command

# Packaging tasks

* Develop a Debian package for [Not-Forking](https://lumosql.org/src/not-forking) for inclusion in the Not-Forking source tree. There is already an ebuild
* Develop a Debian package for LumoSQL for distribution in the LumoSQL source tree
* Develop an ebuild for LumoSQL for distribution in the LumoSQL source tree
