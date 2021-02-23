<!-- Copyright 2021 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2021 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, February 2021 -->

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

* Fix a documentation problem by writing a [Pandoc](https://pandoc.org) filter that understands [Fossil markdown](https://fossil-scm.org/home/md_rules). This was considered but abandoned as [out of scope for Fossil](https://fossil-scm.org/home/timeline?r=auto-toc). Pandoc processing of Markdown -> Markdown would give other advantages than TOCs.
* Fix a documentation problem by writing a Pandoc filter that understands [Pikchr](https://pikchr.org), which would apply to all Pandoc inputs including Markdown documentation such as used by LumoSQL

# Packaging tasks

* Develop a Debian package for [Not-Forking](https://lumosql.org/src/not-forking) for inclusion in the Not-Forking source tree. There is already an ebuild
* Develop a Debian package for LumoSQL for distribution in the LumoSQL source tree
* Develop an ebuild for LumoSQL for distribution in the LumoSQL source tree
