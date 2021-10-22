<!-- Copyright 2021 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2021 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, February 2021 -->

Notes Regarding Karl Malbrain's C Btree Code
=============================================

# Context

There are 4 key-value stores written in C that are used
at scale, are widely-ported and which have the property of being
[MVCC](https://en.wikipedia.org/wiki/Multiversion_concurrency_control). As documented in
[the LumoDoc Knowledgebase](https://lumosql.org/src/lumodoc/file?name=doc/lumo-relevant-knowledgebase.md&ci=tip)
they are:

* SQLite's built-in btree, which as the K-V store underneath the software which is most-deployed by at least two orders of magnitude, must therefore be the most-deployed K-V store.
* Oracle BDB, once ubiquitous, effectively dead due to Oracle licensing changes. LumoSQL works with a relatively recent version of this out-of-date K-V store.
* [LMDB](http://www.lmdb.tech/doc/), which seems to have replaced BDB in most contexts, and which is modern, well-tested and uses mmap() instead of the older idea of Write Ahead Logs.
* [Comdb's BDB fork](https://github.com/bloomberg/comdb2) (counting it as the spiritual successor to BDB, but [Bloomberg](https://bloomberg.com) is in fact the only user. In another universe perhaps this could have become BDB-ng if LMDB didn't exist.

# A possible new contender to consider

[Karl Malbrain](mailto://malbrain@berkeley.edu) has written a C Btree which is
not used anywhere, but which appears to have some novel features and be
intended to be efficient.  Since public C Btrees are relatively rare, this is
worth at least considering as a LumoSQL backend.

Karl says that his [latest code in February 2021](https://github.com/malbrain/database/tree/master/alpha) 
is intended to go in his [Btree project](https://github.com/malbrain/Btree-source-code) when it is more stable.
His [database project]() has a wider scope than just the K-V store.

Features and experiments Karl mentions that may make this Btree interesting for making LumoSQL more scalable include:

* the multi-root-node subdirectory removes the locking load on the root node by creating a read-only copy of the latest updated root version. The root is updated out-of-band.
* threads2 version: Multi-Threaded with latching implemented by a latch manager with test & set latches in the first few btree pages.

Karl's code is under the 2-Clause BSD.
