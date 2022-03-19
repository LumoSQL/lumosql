<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->



SQLite Virtual Machine Layer
----------------------------

In order to support multiple backends, LumoSQL needs to have a more general way
of matching capabilities to what is available, whether a superset or a subset of
what SQLite currently does. This needs to be done in such a way that it remains
easy to track upstream SQLite.

The SQLite architecture has the SQL virtual machine in the middle of everything:

`vdbeapi.c` has all the functions called by the parser
`vdbe.c` is the implementation of the virtual machine, and and it is
from here that calls are made into btree.c

All changes to SQLite storage code will be in vdbe.c , to insert an
API shim layer for arbitary backends. All BtreeXX function calls will
be replaced with backendXX calls.

`lumo-backend.c` will contain:

* a switch between different backends
* a virtual method table of function calls that can be stacked, for
layering some generic functionality on any backends that need it as
follows

`lumo-index-handler.c` is for backends that need help with index
and/or key handling. For example some cannot have arbitary length
keys, like LMDB. RocksDB and others do not suffer from this.
`lumo-transaction-handler.c` is for backends that do not have full
transaction support. RocksDB for example is not MVCC, and this will
add that layer. Similarly this is where we can implement functionality
to upgrade RO transactions to RW with a commit counter.
`lumo-crypto.c` provides encryption services transparently backends
depending on a decision made in lumo-backend.c, which will cover
everything except backend-specific metadata. Full disk encryption of
everything has to happen at a much lower layer, like SQLite's idea of
a VFS. The VFS concept will not translate entirely, because the very first
alternative backend is based on mmap, and which will need special handling. So we are for now expecting to implement a lumo-vfs-mmap.c and a lumo-vfs.c .
`lumo-vfs.c` provides VFS services to backends, and is invoked by
backends. `lumo-vfs.c` may call lumo-crypto for full file encryption
including backend metadata depending on the VFS being implemented.

Backend implementations will be in files such as `backend-lmdb.c`,
`backend-btree.c`, `backend-rocksdb.c` etc.

This new architecture means:

1. Features such as WALs or paging or network paging etc are specific to the backend, and invisible to any other LumoSQL or SQLite code.
2. Bug-for-bug compatibility with the orginal SQLite btree.c can be maintained (except in the case of encryption, which no open source users have access to anyway.)
3. New backends with novel features (and LMDB is novel enough, for a first example!) can be introduced without disturbing other code, and being able to be benchmarked and tested safely.




