<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2019 -->



Table of Contents
=================

   * [LumoSQL Backend Storage Engines](#lumosql-backend-storage-engines)
   

# LumoSQL Backend Storage Engines
LumoSQL supports the SQLite [b-tree](https://sqlite.org/src4/doc/trunk/www/bt.wiki) format as well as [LMDB](http://www.lmdb.tech/doc/) and [BDB](https://docs.oracle.com/database/bdb181/html/gsg/C/BerkeleyDB-Core-C-GSG.pdf#%5B%7B%22num%22%3A44%2C%22gen%22%3A0%7D%2C%7B%22name%22%3A%22XYZ%22%7D%2C86.4%2C691.2%2Cnull%5D).

The implementation of BDB for SQLite is discussed [here](https://lumosql.org/src/lumosql/doc/tip/doc/lumo-sqlite-bdb-backend.md)

See [adding new backends](https://lumosql.org/src/lumosql/doc/tip/doc/lumo-build-benchmark.md#adding-new-backends) section for how to add new backends during build.

[adding new backends](./3.5-lumo-test-build.md#adding-new-backends)

LumoSQL team is considering the implementation of novel [C Btree](https://lumosql.org/src/lumosql/doc/tip/doc/lumo-malbrain-backend.md) (created by Karl Malbrain) in the future.

