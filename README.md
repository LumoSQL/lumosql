<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2019 -->

# LumoSQL

[LumoSQL](lumosql.org) is a modification (not a fork) of the [SQLite](https://sqlite.org)
embedded data storage library. LumoSQL offers multiple backend storage
systems selectable by the user and proposes other integrity and security features.
There are currently three LumoSQL backends:

* the default SQLite Btree storage system
* [LMDB](https://github.com/LMDB/lmdb)
* [the Berkley Database](https://en.wikipedia.org/wiki/Berkeley_DB)

LumoSQL has a build and benchmarking tool for comparing vanilla SQLite versions
and configurations with each other, as well as comparing the performance of
different storage backends. LumoSQL is written in C, like SQLite. The
benchmarking and other tools are written in Tcl, like much of the tooling and
extensions for SQLite and Fossil.

LumoSQL is distributed under [very liberal licence terms](LICENCES/README.md).

Full LumoSQL documentation is maintained by 
[the LumoSQL Documentation project](https://lumosql.org/src/lumodoc), which has separate
goals and tools to LumoSQL (and which is looking for contributors!)

LumoSQL is supported by the [NLNet Foundation](https://nlnet.nl).

Neither Windows nor Android are supported at present, despite being important
SQLite targets. We do plan to do so, and in addition contributors are most
welcome via the [LumoSQL Fossil site](https://lumosql.org/src/lumosql).

# Table of Contents

* [Participating, Not-Forking and Project Interactions](#participating-not-forking-and-project-interactions)
* [LumoSQL, and SQLite's Billions of Users](#lumosql-and-sqlites-billions-of-users)
* [Build Environment and Dependencies](#build-environment-and-dependencies)
* [Using the Build and Benchmark System](#using-the-build-and-benchmark-system)
* [A Brief History of LumoSQL](#a-brief-history-of-lumosql)

<a name="participating-not-forking-and-project-interactions"></a>
## Participating, Not-Forking and Project Interactions

If you are reading this on Github, then you are looking at a mirror. LumoSQL is
is maintained using [the Fossil repository](https://lumosql.org/src/lumosql). If you 
want to participate in LumoSQL there is a forum, and if you have code contributions
you can ask for access to the respository.

LumoSQL has multiple upstreams, but does not fork any of them.
The novel [Not-forking](https://lumosql.org/src/not-forking) tool is a requirement for 
building LumoSQL. Between not-forking and the [LumoSQL Build and Benchmark System](doc/lumo-build-benchmark.md),
LumoSQL is as much about combining and configuring upstreams as it is about creating
original database software.

The LumoSQL and SQLite projects are cooperating, so any merge friction is
expected to become less over time, and key to that is the approach of not
forking.

<a name="lumosql-and-sqlites-billions-of-users"></a>
## LumoSQL, and SQLite's Billions of Users

SQLite is used by thousands of software projects, just three being
Google's Android, Mozilla's Firefox and Apple's iOS which between them have
billions of users. SQLite is careful and conservative, since changes are likely 
to be noticed by a majority of earth's population. 

On the other hand, many of these same users need SQLite to have new features
which do not fit with the SQLite project's cautious approach, and LumoSQL is a
demonstration of some of these improvements. 

The LumoSQL documentation project reviews dozens of relevant codebases.  SQLite
has become ubiquitous over two decades, which means there is a great deal of
preparation needed when considering architectural changes.

LumoSQL uses the [Fossil source code manager](https://fossil-scm.org) because:
* Fossil is designed for projects of up to a million or so lines of code, unlike git (and therefore Github)
* Fossil workflow and tools encourage inclusivity and collaboration rather than forking
* Fossil and SQLite are symbiotic projects and test cases for each other, and therefore LumoSQL may be too 

LumoSQL is mirrored to Github and changes can be imported from Github, but
Fossil is the tool of choice for LumoSQL.

<a name="build-environment-and-dependencies"></a>
## Build Environment and Dependencies

The build system requires [the not-forking tool](https://lumosql.org/src/not-forking/).
Other tools can usually be installed from your operating system's standard packages.

On any reasonably recent Debian or Ubuntu-derived Linux distribution
these installation commands should work:

```sh
sudo apt install git build-essential tclx
sudo apt build-dep sqlite3
```

(`apt build-dep` requires `deb-src` lines uncommented in /etc/apt/sources.list).

On any reasonably recent Fedora-derived Linux distribution:

```sh
sudo dnf install --assumeyes \
  git make gcc ncurses-devel readline-devel glibc-devel autoconf tcl-devel tclx-devel
```

The following steps have been tested on reaonably recent Debian and
Fedora-related operating systems, and Gentoo. 

The not-forking tool will advise you with an error message if you ask for sources that
require a tool or a version that is not installed. Here are the tool dependencies:

* to build and benchmark just SQLite, you need to have [Fossil](https://fossil-scm.org/). Fossil version 2.13 or later from your distrbution, or [2.13 or 2.12.1 from the Fossil download page](https://fossil-scm.org/home/uv/download.html). You may want to [build trunk yourself](https://fossil-scm.org/home/doc/trunk/www/build.wiki), since it is very quick and easy even compared to LumoSQL.
* to build and benchmark any of the LMDB targets, you need to have git version 2.22 or later.
* to build and benchmark any of the Oracle Berkeley DB targets, you need either curl or wget, and GNU tar. Just about any version will be sufficient, even on Windows.

<a name="using-the-build-and-benchmark-system"></a>
## Using the Build and Benchmark System

This is a very brief quickstart, for full detail see the
[Build and Benchmark System documentation](doc/lumo-build-benchmark.md). 

Now you have the dependencies installed, clone the LumoSQL repository using
`fossil clone https://lumosql.org/src/lumosql` .

Try `make what` to see what the default sources and options are. The `what` target does not make any changes.

Benchmarking a single binary should take no longer than 4 minutes to complete depending
on hardware. The results are stored in an SQLite database stored in the LumoSQL 
top-level directory by default, that is, the directory you just created using `fossil clone`.

Start by building and benchmarking the official SQLite release version 3.34.0:

`make benchmark USE_LMDB=no USE_BDB=no SQLITE_VERSIONS='3.34.0'`

All source files fetched are cached in ~/.cache/LumoSQL in a way that maximises reuse regardless of 
their origin (Fossil, git, wget etc) and which minimises errors. The LumoSQL build system is driving the
`not-fork` tool, which maintains the cache. Not-fork will download just the differences of a remote 
version if most of the code is already in cache.

The output from this make command will be something like this:

`
tclsh tool/build.tcl database not-fork.d build benchmarks.sqlite
Creating database benchmarks.sqlite
tclsh tool/build.tcl benchmark not-fork.d build benchmarks.sqlite  SQLITE_VERSIONS='3.34.0' USE_BDB='no' USE_LMDB='no'
*** Running benchmark 3.34.0
    TITLE = sqlite 3.34.0
    SQLITE_ID = 384f5c26f48b92e8bfcb168381d4a8caf3ea59e7
    SQLITE_NAME = 3.34.0 2020-12-01 16:14:00 a26b6597e3ae272231b96f9982c3bcc17ddec2f2b6eb4df06a224b91089falt1
    DATASIZE = 1
    DEBUG = off
    RUN_ID = DF28B0624434217B09E54A422E077307B60A913F7DDA1E7BA46DDE1F142DB2F1
          OK    16.314   1 1000 INSERTs
          OK     0.135   2 25000 INSERTs in a transaction
          OK     0.208   3 100 SELECTs without an index
          OK     0.499   4 100 SELECTs on a string comparison
          OK     7.011   5 5000 SELECTs
          OK     0.095   6 1000 UPDATEs without an index
          OK    25.471   7 25000 UPDATEs with an index
          OK    25.250   8 25000 text UPDATEs with an index
          OK     0.087   9 INSERTs from a SELECT
          OK     0.142  10 DELETE without an index
          OK     0.076  11 DELETE with an index
          OK     0.072  12 A big INSERT after a big DELETE
          OK     0.091  13 A big DELETE followed by many small INSERTs
          OK     0.064  14 DROP TABLE
                75.515 (total time)
`

A database with the default name of `benchmarks.sqlite` has been created with
two tables containing the results. This is one single test run, and the test
run data is kept in the table `test_data`. The table `run_data` contains data
relative to a set of runs (version numbers, time test started, etc). This is cumulative,
so another invocation of `make benchmark ...` will add to `benchmarks.sqlite`.

<a name="a-brief-history-of-lumosql"></a>
## A Brief History of LumoSQL

There have been several implementations of new storage backends to SQLite, all of them hard forks
and nearly all dead forks. A backend needs certain characteristics:

* btree-based key-value store
* transactions, or fully ACID
* full concurrency support, or fully MVCC

There are not many candidate key-value stores. One of the most widely-used is
Howard Chu's LMDB. There was a lot of attention in 2013 when Howard released
his [proof of concept SQLite port](https://github.com/LMDB/sqlightning). LMDB
operates on a very different and more modern principle to all other widely-used
key/value stores, potentially bringing benefits to some users of SQLite. In
2013, the ported SQLite gave significant performance benefits.

The original 2013 code modified the SQLite `btree.c` from version SQLite
version 3.7.17 to use LMDB 0.9.9 . It took considerable work for LumoSQL to
excavate the ancient code and reproduce the results.

By January 2020 the LumoSQL project concluded:

- Howard's 2013 performance work is reproducible
- SQLite's key-value store improved in performance since 2013, getting close to
  parity with LMDB by some measures
- SQLite can be readily modified to have multiple storage backends and still
  pass 'make test'
- SQLite doesn't expect there to be multiple backends, and this has many effects
  including for example in error handling. An abstraction layer was needed.

Since then, many new possibilities have emerged for LumoSQL, and new collaborations.





