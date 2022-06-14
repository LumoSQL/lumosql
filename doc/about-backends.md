<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2019 -->


# LumoSQL Backend Storage Engines

Development of [LMDB](https://github.com/LMDB/lmdb) library by Howard Chu introduced a new way of data storage based on memory mapping, which offers new capailities and improved performance. Inspired by the 2013 prototype of [sqlightning](https://github.com/LMDB/sqlightning), LumoSQL dveloped tools to combine any version of SQLite with any version of LMDB. This was done to test the potential benefits of deploying LMDB as a substitute for currently very widely used SQLite b-tree. For comparison, BDB storage can also be used with SQLite version 3.18.2, see [discussion](https://lumosql.org/src/lumosql/doc/tip/doc/lumo-sqlite-bdb-backend.md).

At the moment LumoSQL supports:

- SQLite [b-tree](https://sqlite.org/src4/doc/trunk/www/bt.wiki)
- [LMDB](http://www.lmdb.tech/doc/)
- [BDB](https://docs.oracle.com/database/bdb181/html/gsg/C/BerkeleyDB-Core-C-GSG.pdf#%5B%7B%22num%22%3A44%2C%22gen%22%3A0%7D%2C%7B%22name%22%3A%22XYZ%22%7D%2C86.4%2C691.2%2Cnull%5D)


LumoSQL team is also considering the implementation of novel [C Btree](https://lumosql.org/src/lumosql/doc/tip/doc/lumo-malbrain-backend.md) (created by Karl Malbrain).

