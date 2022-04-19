<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2019 -->

# LumoSQL

[LumoSQL](lumosql.org) is a modification (not a fork) of the
[SQLite](https://sqlite.org) embedded data storage library, the [most-deployed software](https://sqlite.org/mostdeployed.html).
LumoSQL adds performance, security and privacy features, partly by adding
multiple backend storage systems.  If you are an SQLite user familiar with C
development wanting an easier way to benchmark and measure SQLite, or if you
are wanting features only available in other key-value storage engines, then
you may find LumoSQL interesting.

In [Phase II of LumoSQL](./doc/LumoSQL-PhaseII-Announce.md) we are building on 
the existing optional per-row checksums to add per-row [Attribute-Based Encryption (ABE)](https://en.wikipedia.org/wiki/Attribute-based_encryption) and much more.

In the existing LumoSQL 0.4 there are currently three LumoSQL backends:

* the default SQLite Btree storage system
* [LMDB](https://github.com/LMDB/lmdb)
* [the Berkley Database](https://en.wikipedia.org/wiki/Berkeley_DB)

LumoSQL has a build and benchmarking tool for comparing vanilla SQLite versions
and configurations with each other, as well as comparing the performance of
different storage backends. LumoSQL is written in C, like SQLite. The
benchmarking and other tools are written in Tcl, like much of the tooling and
extensions for SQLite and Fossil. The build tool guarantees that options and
configurations are always selected in the same way, so that benchmark results are 
reliable.

LumoSQL is distributed under [very liberal licence terms](LICENCES/README.md).

LumoSQL is supported by the [NLNet Foundation](https://nlnet.nl).

Neither Windows nor Android are supported at present, despite being important
SQLite targets. We do plan to do so, and in addition contributors are most
welcome via the [LumoSQL Fossil site](/).

# Table of Contents

* [Design, Not-Forking and Participating](#design-not-forking-and-participating)
* [LumoSQL, and SQLite's Billions of Users](#lumosql-and-sqlites-billions-of-users)
* [Limitations of LumoSQL](#limitations-of-lumosql)
* [Build Environment and Dependencies](#build-environment-and-dependencies)
* [Using the Build and Benchmark System](#using-the-build-and-benchmark-system)
* [A Brief History of LumoSQL](#a-brief-history-of-lumosql)

<a name="design-not-forking-and-participating"></a>
## Design, Not-Forking and Participating

If you are reading this on Github, then you are looking at a mirror. LumoSQL is
is maintained using [the Fossil repository](/). If you 
want to participate in LumoSQL there is a forum, and if you have code contributions
you can ask for access to the respository.

LumoSQL has multiple upstreams, but does not fork any of them despite needing modifications.
The novel [Not-forking](https://lumosql.org/src/not-forking) tool semi-automatically 
tracks upstream changes and is a requirement for building LumoSQL. Between not-forking 
and the [LumoSQL Build and Benchmark System](doc/lumo-build-benchmark.md),
LumoSQL is as much about combining and configuring upstreams as it is about creating
original database software. By maintaining Not-forking outside LumoSQL, we hope
other projects will find it useful.

The LumoSQL and SQLite projects are cooperating, so any merge friction is
expected to become less over time, and key to that is the approach of not
forking.

<a name="lumosql-and-sqlites-billions-of-users"></a>
## LumoSQL, and SQLite's Billions of Users

LumoSQL exists to demonstrate changes to SQLite that might be useful, but which
SQLite probably cannot consider for many years because of SQLite's unique
position of being used by a majority of the world's population. 

SQLite is used by thousands of software projects, just three being
Google's Android, Mozilla's Firefox and Apple's iOS which between them have
billions of users. That is a main reason why SQLite is so careful and conservative
with all changes.

On the other hand, many of these same users need SQLite to have new features
which do not fit with the SQLite project's cautious approach, and LumoSQL is a
demonstration of some of these improvements. 

The LumoSQL documentation project reviews dozens of relevant codebases.  SQLite
has become ubiquitous over two decades, which means there is a great deal of
preparation needed when considering architectural changes.

<a name="limitations-of-lumosql"></a>
## Limitations of LumoSQL

As of LumoSQL 0.4, there are many obvious limitations, including:

* The tests used in benchmarking mostly come from an ancient version of SQLite's
  speedtest.tcl modified many times, to which DATASIZE
  and DEBUG have been added. Experts in SQLite and LMDB database testing 
  should review the files in not-fork.d/sqlite3/benchmark/\*test. There are 
  [9 tools named \*speed\*](https://sqlite.org/src/dir?ci=tip&name=tool) 
  in the SQLite source, and any/all of them should be added here.
* Neither LMDB nor BDB backends ship with latest SQLite builds. Now all the LumoSQL infrastructure
  exists, that is a smaller, more maintainable and repeatable task. But it is not done yet.
  There are some generic problems to be solved in the process, such as the optimal way to
  address keysize disparities between a KVP store provider and SQLite's internal large keysize.
* If we import more of the speed tests from SQLite identified above, then we will 
  have a problem with several LMDB and at least two BDB instances, where the SQLite
  tests will fail. In most cases this is about the LMDB port needing to be more 
  complete but in some it is about relevance, where some SQLite tests will not apply. In
  addition some backends will always need
  to have additional tests (for example, BDB has more extensive user management than 
  SQLite).

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

