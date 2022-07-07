<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2019 -->


<!-- toc -->

Knowledge Relevant to LumoSQL
=============================

LumoSQL has many antecedents and relevant codebases.  This document is intended
to be a terse list of published source code for reference of LumoSQL
developers. Although it is stored with the rest of the LumoSQL documentation
and referred to throughout, it is a standalone document.

Everything listed here is open source, except for software produced by
sqlite.org or the commercial arm hwaci.com. There are many closed-source
products that extend and reuse SQLite in various ways, none of which have been
considered by the LumoSQL project.

# List of SQLite Code-related Knowledge

SQLite code has been incorporated into many other projects, and besides there are many other relevant key-value stores and libraries.

| Project | Last modified | Description   |
| ------------- | ------------- | --------|
| [sqlightning](https://github.com/LMDB/sqlightning)  | 2013 | SQLite ported to the LMDB key-value store; all in C |
| [Original MDB Paper](https://www.openldap.org/pub/hyc/mdb-paper.pdf) | 2012 | Paper by Howard Chu describing the motivations, design and constraints of the LMDB key-value store |
| [SQLHeavy](https://github.com/btrask/sqlheavy)  | 2016 | sqlightning updated, and ported to LevelDB, LMDB, RocksDB and more, with a key-value store library abstraction; all in C |
| [SQLite 4](https://sqlite.org/src4/tree?ci=trunk) | 2014 | Abandoned new version of SQLite with improved backend support and other features |
| [Oracle BDB port of SQLite](https://bintray.com/version/files/homebrew/mirror/berkeley-db/18.1.32) | 2020 | The original ubiquitous Unix K-V store, disused in open source since Oracle's 2013 license change to AGPL; the API template for most of the k-v btree stores around. Now includes many additional features including full MVCC transactions, networking and replication. This link is a mirror of code from download.oracle.com, which requires a login. This is version 18.1.32, which was the last with a port of SQLite | 
| [Sleepycat/Oracle BDB-SQL](https://fossies.org/linux/misc/db-18.1.32.tar.gz) | current | Port of SQLite to the Sleepycat/Oracle transactional bdb K-V store. As of 5th March 2020 this mirror is identical to Oracle's login-protected tarball for db 18.1.32 | 
| [rqlite](https://github.com/rqlite/rqlite) | current | Distributed database with networking and Raft consensus on top of SQLite nodes |
| [Bedrock](https://github.com/Expensify/Bedrock) | current | WAN-replicated blockchain multimaster database built on SQLite. Has MySQL emulation |
| [Comdb](https://github.com/bloomberg/comdb2) | current | Clustered HA RDBMS built on SQLite and a forked old Sleepcat BDB, synchronous replication, stored procedures |
| [sql.js](https://github.com/kripken/sql.js/) | current | SQLite compiled to JavaScript WebAssembly through Emscripten |
| [ActorDB](https://github.com/biokoda/actordb) | current | SQLite with a data sharding/distribution system across clustered nodes. Each node stores data in LMDB, which is connected to SQLite at the SQLite WAL layer |
| [WAL-G](https://github.com/wal-g/wal-g) | current | Backup/replication tool that intercepts the WAL journal log for each of Postgres, Mysql, MonogoDB and Redis |
| [sqlite3odbc](https://github.com/gdev2018/sqlite3odbc) | current | ODBC driver for SQLite by [Christian Werner](http://www.ch-werner.de/sqliteodbc/) as used by many projects including LibreOffice |
| [Spatialite](https://www.gaia-gis.it/fossil/libspatialite/index)| current | Geospatial GIS extension to SQLite, similar to PostGIS |
| [Gigimushroom's Database Backend Engine](https://github.com/gigimushroom/DatabaseBackendEngine)|2019| A good example of an alternative BTree storage engine implemented using SQLite's Virtual Table Interface. This approach is not what LumoSQL has chosen for many reasons, but this code demonstrates virtual tables can work, and also that storage engines implemented at virtual tables can be ported to be LumoSQL backends.|

# List of MVCC-capable KV store-related Knowledge

There are hundreds of active K-V stores, but few of them do
[MVCC](https://en.wikipedia.org/wiki/Multiversion_concurrency_control). MVCC is
a requirement for any performant backend to SQLite, because although SQLite
does do transaction management at the SQL level, it assumes the KV store will
handle contention. SQLite translates SQL transactions into KV store
transactions. There are many interesting KV stores that target use cases that
do not need or want MVCC listed in *Section 8 Related Work* in 
[Microsoft's SIGMOD paper on the FASTER KV store](https://www.microsoft.com/en-us/research/uploads/prod/2018/03/faster-sigmod18.pdf) 
including Redis, RocksDB, Aerospike, etc.  We have done little source code
review of non-MVCC KV stores, and have not considered them for LumoSQL
backends.


| Project | Last modified | Description   |
| ------------- | ------------- | --------|
| SQLite's built-in KV store  | current | **Included as a reminder** that SQLite is *also* the world's most widely-used key-value store, and it does full MVCC. LumoSQL plans to expose this via an API for the first time |
| [LMDB](https://github.com/LMDB/) | current | Maintained by the OpenLDAP project, LMDB is a standalone KV store written in C, and is the only KV store that is implemented using mmap. LMDB is the first backend target for LumoSQL |
| [Oracle BDB KV Store](https://bintray.com/version/files/homebrew/mirror/berkeley-db/18.1.40) | 2020 | Version 18.1.40 (the link given here) and later of BDB do not include the SQLite port, but they are still the same MVCC KV store. LumoSQL may consider continuing to develop the SQLite port. |
| [libkvstore](https://github.com/btrask/libkvstore) | 2016 | The k-v store abstraction library used by SQLHeavy |
| [Comdb's BDB fork](https://github.com/bloomberg/comdb2) | current | The BDB fork has had row-level locking added to it and has other interesting features besides being the second SQLite-on-BDB port |
| [Karl Malbrain's DB](https://github.com/malbrain/database/wiki) | current | This C library appears to be a maintained and well-researched and documented KV store, but without widespread deployment it is unlikely to be competitive. Perhaps that is unfair, and LumoSQL hopes to find out. The code suggests some interesting approaches to lockless design |
| [Serial Safety Net Concurrency](www.cs.cmu.edu/~./pavlo/papers/p781-wu.pdf) | 2015 | Karl Malbrain implements the Serial Safety Net (SSN) concurrency control protocol discussed in this paper. This paper also gives an analysis of other concurrency control methods including timestamps.| 
| [Badger](https://github.com/dgraph-io/badger) | current | Written in Go. Implements MVCC using a separate WAL file for each of its memory tables. Untested and only reviewed briefly. |


# List of On-disk SQLite Format-related Knowledge

The on-disk file format is important to many SQLite use cases, and introspection tools are both important and rare. Other K-V stores also have third-party on-disk introspection tools. There are advantages to having investigative tools that do not use the original/canonical source code to read and write these databases. The SQLite file format is promoted as being a stable, backwards-compatible transport (recommend by the Library of Congress as an archive format) but it also has significant drawbacks as discussed elsewhere in the LumoSQL documentation.

| Project | Last modified | Description |
| ------- | ------------- | ----------- |
| [A standardized corpus for SQLite database forensics](https://www.sciencedirect.com/science/article/pii/S1742287618300471) | current | Sample SQLite databases and evaluations of 5 tools that do extraction and recovery from SQLite, including Undark and SQLite Deleted Records Parser |
| [FastoNoSQL](https://github.com/fastogt/fastonosql) | current | GUI inspector and management tool for on-disk databases including LMDB and LevelDB |
| [Undark](https://github.com/inflex/undark) | 2016 | SQLite deleted and corrupted data recovery tool |
| [SQLite Deleted Records Parser](https://github.com/mdegrazia/SQLite-Deleted-Records-Parser) | 2015 | Script to recover deleted entries in an SQLite database |
| [lua-mdb](https://github.com/catwell/cw-lua/tree/master/lua-mdb) | 2016 | Parse and investigate LMDB file format |

(The forensics and data recovery industry has many tools that diagnose SQLite
database files. Some are open source but many are not. A list of tools commonly
cited by forensics practicioners, none of which LumoSQL has downloaded or tried
is: Belkasoft Evidence Center, BlackBag BlackLight, Cellebrite UFED Physical
Analyser, DB Browser for SQLite, Magnet AXIOM and Oxygen Forensic Detective.)

# List of Relevant SQL Checksumming-related Knowledge

| Project | Last modified | Description |
| ------- | ------------- | ----------- |
| [eXtended Keccak Code Package](https://github.com/XKCP/XKCP)  | current | Code from https://keccak.team for very fast peer-reviewed hashing |
| [SQL code for Per-table Multi-database Solution](https://www.periscopedata.com/blog/hashing-tables-to-ensure-consistency-in-postgres-redshift-and-mysql) | 2014 | Periscope's SQL row hashing solution for Postgres, Redshift and MySQL |
| [SQL code for Public Key Row Tracking](https://www.percona.com/blog/2018/10/12/track-postgresql-row-changes-using-public-private-key-signing/) | 2018 | Percona's SQL row integrity solution for Postgresql using public key crypto |
| [Richard Hipp's SQLite Checksum VFS](https://sqlite.org/cksumvfs.html) | 2019 | This shows the potential benefits from maintaining checksums. There are many limitations, but its more than any other mainstream database ships by default |


# List of Relevant Benchmarking and Test Knowledge

Benchmarking is a big part of LumoSQL, to determine if changes are an
improvement. The trouble is that SQLite and other top databases are not really
benchmarked in realistic and consistent way, despite SQL server benchmarking
using tools like TPC being an obsessive industry in itself, and there being
myriad of testing tools released with SQLite, Postgresql, MariaDB etc. But in
practical terms there is no way of comparing the most-used databases with each
other, or even of being sure that the tests that do exist are in any way
realistic, or even of simply reproducing results that other people have found.
LumoSQL covers so many codebases and use cases that better SQL benchmarking is
a project requirement. Benchmarking and testing overlap, which is addressed in
the code and docs.

The well-described [testing of SQLite](https://sqlite.org/testing.html)
involves some open code, some closed code, and many ad hoc processes. Clearly
the SQLite team have an internal culture of testing that has benefited the
world. However that is very different to reproducible testing, which is in turn
very different to reproducible benchmarking, and that is even without
considering whether the benchmarking is a reasonable approximation of actual
use cases. As the development of LumoSQL has proceeded, it has become clear
that the TCL testing harness shipped with SQLite code contains specific
dependencies on the behaviour of the SQLite btree backend. While LumoSQL with
the original btree backend aims to always pass these tests, differences such as
locking behaviour, assumed key lengths, and even the number of database files a
backend uses all mean that the SQLite TCL test suite is not generally useful.

To highlight how poorly SQL benchmarking is done: there are virtually no test
harnesses that cover encrypted databases and/or encrypted database connections,
despite encryption being frequently required, and despite crypto implementation
decisions making a very big difference in performance. Encryption and security are
not the only ways a database impacts privacy, so privacy is a valid dimension for 
database testing - and a fundamental goal for LumoSQL. Testing all databases in 
the same way for privacy is challenging.

SQL testing is also very difficult. As the Regression Testing paper below says:
"A problem with testing SQL in DBMSs lies in the fact that the state of the
database must be considered when deducing testing outcomes". SQL statements
frequently change the state of the server during their execution, in different
ways on different servers. This can change the behaviour or at least the
performance of the next statement, and so on.



| Project | Last modified | Description | 
| ------- | ------------- | ----------- |
| [Dangers and complexity of sqlite3 benchmarking](https://www.cs.utexas.edu/~vijay/papers/apsys17-sqlite.pdf)| n/a | Helpful 2017 paper: "...changing just one parameter in SQLite can change the performance by 11.8X... up to 28X difference in performance" |
| [sqllogictest](https://www.sqlite.org/sqllogictest/doc/trunk/about.wiki)|2017 | [sqlite.org code](https://www.sqlite.org/sqllogictest/artifact/2c354f3d44da6356) to [compare the results](https://gerardnico.com/data/type/relation/sql/test) of many SQL statements between multiple SQL servers, either SQLite or an ODBC-supporting server |
| [TCL SQLite tests](https://github.com/sqlite/sqlite/tree/master/test)|current| These are a mixture of code covereage tests, unit tests and test coverage. Actively maintained. |
| [Yahoo Cloud Serving Benchmark](https://github.com/brianfrankcooper/YCSB/)| current | Benchmarking tool for K-V stores and cloud-accessible databases |
| [Example Android Storage Benchmark](https://github.com/greenrobot/android-database-performance) | 2018 | This code is an example of the very many Android benchmarking/testing tools. This needs further investigation |
| [Sysbench](https://github.com/akopytov/sysbench) | current | A multithreaded generic benchmarking tool, with one well-supported use case being networked SQL servers, and [MySQL in particular](https://www.percona.com/blog/2019/04/25/creating-custom-sysbench-scripts/) |
| [Regression Testing of SQL](https://www.diva-portal.org/smash/get/diva2:736996/FULLTEXT01.pdf)|n/a | 2014 paper "a framework for minimizing the required developer effort formanaging and running SQL regression tests" |
| [Enhancing the Performance of SQLite](https://pdfs.semanticscholar.org/c2da/33304627649b599f80a5428354e116ba6201.pdf)| n/a | 2013 paper that does profiling and develops performance testing metrics for SQLite |
| [SQLite Profiler and Tracer](https://github.com/microsoft/sqlite-tracer) | 2018 | Microsoft SQLite statement profiler and timer, helpful for comparing LumoSQL backends |
| [SQLCipher Performance Optimisation](https://discuss.zetetic.net/t/sqlcipher-performance-optimization/14) | n/a | 2014 comments on the additional performance metric problems that come with SQLite encryption |
| [Performance analysis ... on flash file systems](https://sci-hub.se/10.1007/s10617-014-9149-2) | 2013 | Discussion of SQLite and 2 others on Flash, examining the cost to flash of SQL operations |


# List of Just a Few SQLite Encryption Projects

Encryption is a major problem for SQLite users looking for open code. There are no official implementations in open source, although the APIs are documented (seemingly by an SCM mistake years ago (?), see sqlite3-dbx below) and most solutions use the SQLite extension interface. This means that there are many mutually-incompatible implementations, several of them seeming to be very popular. None appear to have received encryption certification (?) and none seem to publish test results to reassure users about compatibility with SQLite upstream or with the file format. Besides the closed source solution from sqlite.org, there are also at least three other closed source options not listed here. This choice between either closed source or fragmented solutions is a poor security approach from the point of view of maintenance as well as peer-reviewed security. This means that SQLite in 2020 does not have a good approach to privacy.


| Project | Last modified | Description | 
| ------- | ------------- | ----------- |
| [SQLite Encryption Extension](https://www.sqlite.org/see/doc/release/www/readme.wiki)(SEE)| current | Info about the proprietary, closed source official SQLite crypto solution, illustrating that there is little to be compatible with in the wider SQLite landscape. This is a standalone product. The API is published and used by some open source code. |
| [SQLCipher](https://github.com/sqlcipher/sqlcipher) | current | Adds at-rest encryption to SQLite [at the pager level](https://www.zetetic.net/sqlcipher/design/), using OpenSSL (the default) or optionally other providers. Uses an open core licensing model, and the less-capable open source version is BSD licensed with a requirement that users publish copyright notices. Uses the SEE API. |
| [Oracle BDB Encryption](https://docs.oracle.com/cd/E17276_01/html/bdb-sql/sql_encryption.html) | 2018 | Exposes the (old and insecure) BDB encryption facilities via the SEE API with one minor change. |
| [sqleet](https://github.com/resilar/sqleet) | current | Implements SHA256 encryption, also at the pager level. Public Domain (not Open Source, similar to SQLite) |
| [sqlite3-dbx](https://github.com/newsoft/sqlite3-dbx) | kinda-current | Accidentally-published but unretracted code on sqlite.org fully documents crypto APIs used by SEE |
| [SQLite3-Encryption](https://github.com/darkman66/SQLite3-Encryption) | current | No crypto libraries (DIY crypto!) and based on the similar-sounding SQLite3-with-Encryption project | 
| [wxSqlite3](https://github.com/utelle/wxsqlite3/) | current | wxWidgets C++ wrapper, that also implements SEE-equivalent crypto. Licensed under the LGPL |
| [LMDB v1.0pre with encryption](https://github.com/LMDB/lmdb/tree/mdb.master3) | current | The LMDB branch mdb.master3 is a prerelease of LMDBv1.0 with page-level encryption. This could be used in an architecturally similar way to the role of BDB encryption in the Oracle BDB+SQLite port |
| [Discussion of SQLCipher vs sqleet](https://github.com/resilar/sqleet/issues/12) | 2019 | Authors of sqleet and wxSQLite3 discuss SQLCipher, covering many weaknesses and some strengths |


... there are many more crypto projects for SQLite. 

# List of from-scratch MySQL SQL and MySQL Server implementations

If we want to make SQLite able to process MySQL queries there is a lot of existing code in this area to consider. There are at least 80 projects on github which implement some or all of the MySQL network-parse-optimise-execute SQL pathway, a few of them implement all of it. None so far reviewed used MySQL or MariaDB code to do so. Perhaps that is because the SQL processing code alone in these databases is many times bigger than the whole of SQLite, and it isn't even clear how to add them to this table if we wanted to. Only a few of these projects put a MySQL frontend on SQLite, but two well-maintained projects do, showing us two ways of implementing this.

| Project | Last modified | Description |
| ------- | ------------- | ----------- |
| [Bedrock](https://github.com/Expensify/Bedrock) | current | The MySQL compatibility seems to be popular and is actively supported but it is also small. It speaks the MySQL/MariaDB protocol accurately but doesn't seem to try very hard to match MySQL SQL language semantics and extensions, rather relying on the fact that SQLite substantially overlaps with MySQL. |
| [TiDB](https://github.com/pingcap/tidb/) | current | Distributed database with MySQL emulation as the primary dialect and referred to throughout the code, with frequent detailed bugfixes on deviations from MySQL SQL language behaviour. |
| [phpMyAdmin parser](https://github.com/phpmyadmin/sql-parser) | current | A very complete parser for MySQL code, demonstrating that completeness is not the unrealistic goal some claim it to be |
| [Go MySQL Server](https://github.com/src-d/go-mysql-server) | current | A MySQL server written in Go that executes queries but mostly leaves the backend for the user to implement. Intended to put a compliant MySQL server on top of arbitrary backend sources. |
| [ClickHouse MySQL Frontend](https://github.com/ClickHouse/ClickHouse/tree/146109fe27074229a38cd704d60f23ec7bd2ed67/base/mysqlxx) | current | Yandex' [Clickhouse](https://clickhouse.tech/) has a MySQL frontend.|
