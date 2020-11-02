<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2019 -->

# LumoSQL

## About LumoSQL

[LumoSQL](lumosql.org) is a modification of the [SQLite](https://sqlite.org)
embedded data storage C language library to have multiple backend storage
systems, selectable by the user. In this early release there are just two
backends, the default SQLite storage system, and
[LMDB](https://github.com/LMDB/lmdb). LumoSQL achieves this by abstracting out
the storage layer in SQLite without forking SQLite, making it possible to add
new backends. New versions of SQLite do not typically require much manual
merging in LumoSQL, if any. The LumoSQL and SQLite projects are cooperating, so any merge
friction is expected to become less over time.

LumoSQL is distributed under [very liberal terms](LICENCES/README.md).

The full documentation for LumoSQL is at [the LumoSQL Documentation project](https://lumosql.org/src/lumodoc).

SQLite is used by thousands of software projects, just three of them being 
Google's Android, Mozilla's Firefox and Apple's iOS which between them have 
billions of users. SQLite is careful and conservative with changes that might
have unpredictable effects on software stacks likely used by a majority of 
earth's population. On the other hand, there are changes to SQLite which are
needed by many users, and LumoSQL is a demonstration of some of these improvements.

The LumoSQL documentation project covers the strategy, plans and research into
dozens of relevant codebases. SQLite has become ubiquitous over two decades, which means 
there is a great deal of preparation needed when considering architectural changes.
If you are looking for more information about technical terms in this README you'll 
likely find it in the LumoSQL documentation.

LumoSQL uses the [Fossil source code manager](https://fossil-scm.org/), with a 
[mirror project on Github](https://github.com/LumoSQL). This is partly because Fossil
has some advantages over Github which suit a project of this size, and partly because
Fossil and SQLite are symbiotic projects and test cases for each other. Fossil can 
mirror to and from Github, but Fossil is the tool of choice for LumoSQL.

## Quickstart

* Ensure you have the build environment described below
* Type "make" in the top level directory

The [LumoSQL Build System](doc/lumo-test-build.md) is well documented when you need to 
go deeper.

## About LumoSQL

LumoSQL was started in December 2019 by Dan Shearer, who did the original
source tree archaeology, patching and test builds. Keith Maxwell joined for a
time and contributed invaluable version management to the Makefile and the
benchmarking tools.  Claudio Calvelli contributes in many areas including the
[not-forking tool](https://lumosql.org/src/not-forking), which is central to
the relationship between LumoSQL and SQLite and is now a separate project.

Generally speaking, the goal of the LumoSQL Project is to create and maintain
an enhanced version of SQLite in cooperation with the SQLite project. There are
some very specific goals and committments covered in the LumoSQL documentation.

LumoSQL is also supported by the [NLNet Foundation](https://nlnet.nl).

## LumoSQL Started from an LMDB Port

There have been several implementations of new storage backends to SQLite, all of them hard forks
and most (but notably not all) of them dead forks. A backend needs certain characteristics if 
it is to fit without totally rewriting SQLite:

* btree-based key-value store
* transactions, or fully ACID
* full concurrency support, or fully MVCC

There are not many candidate key-value stores. One of the most widely-used
key/value stores is Howard Chu's LMDB. That is why there was a lot of attention
when in 2013 Howard released his [proof of concept SQLite
port](https://github.com/LMDB/sqlightning). LMDB operates on a very different
and more modern principle to all other widely-used key/value stores, potentially bringing
benefits to some users of SQLite. In 2013, the ported SQLite seemed to give 
significant performance benefits, which is not surprising since LMDB's focus 
is on performance and small size.

The original 2013 code modified the SQLite `btree.c` from version SQLite version 
3.7.17 to use LMDB 0.9.9 . It took considerable work to excavate the code and 
reproduce the results from years ago. 

By January 2020 the LumoSQL project had established that it was feasible to
create something much more than an updated version of the LMDB port. We
concluded:

- Howard's 2013 performance work is reproducible
- SQLite's key-value store improved in performance since 2013, getting close to
  parity with LMDB by some measures
- SQLite can be readily modified to have multiple storage backends and still
  pass all of its own tests
- SQLite doesn't expect there to be multiple backends, and this has many effects
  including for example in error handling. An abstraction layer was needed.

In addition there are several disclaimers made by the SQLite project including
not being intended for high concurrency. Since high concurrency is a design
feature of LMDB and a common use case for SQLite, we wanted to investigate
whether an LMDB-backed LumoSQL might be better for highly concurrent applications.

Since then, many new possibilities have emerged for LumoSQL.

## What's In This Version of LumoSQL

LumoSQL provides a Makefile and benchmarking subsystem which:

- Re-creates many combinations of SQLite and LMDB trees and versions, as
  specified by the user
- Creates a testing matrix of versions and results. These can be limited by the
  user because a full suite takes hours to run.
- Is suitable for extending to multiple other backends

## Build environment

The build system requires [the not-forking tool](https://lumosql.org/src/not-forking/);
once that is installed, some other tools are needed, usually provided by installing
development packages.

On Ubuntu 18.0.4 LTS, Debian Stable (buster), and on any reasonably recent
Debian or Ubuntu-derived distribution, you need only:

```sh
sudo apt install git build-essential tcl
sudo apt build-dep sqlite3
```

(`apt build-dep` requires `deb-src` lines uncommented in /etc/apt/sources.list).

On Fedora 30, and on any reasonably recent Fedora-derived distribution:

```sh
sudo dnf install --assumeyes \
  git make gcc ncurses-devel readline-devel glibc-devel autoconf tcl-devel
```

The following steps have been tested on Fedora 30 and Ubuntu 18.04 LTS (via the
`container` target in the [Makefile](/Makefile)).

## Using the Makefile tool

Start with a clone of this repository as the current directory.

To build either (a) specific versions of SQLite or (b) sqlightning using
different versions of LMDB, use commands like those below changing the version
numbers to suit. A list of tested version numbers is in the table
[below](#which-lmdb-version).

```sh
make bld-SQLite-3.7.17
make bld-LMDB_0.9.9
```

# Speed tests / benchmarking

To benchmark a single binary takes approximately 4 minutes to complete depending
on hardware.

The instructions in this section explain how to benchmark four different
versions:

| V.  | SQLite | LMDB   | Repository | Report filename    |
| --- | ------ | ------ | ---------- | ------------------ |
| A.  | 3.7.17 | -      | SQLite     | SQLite-3.7.17.html |
| B.  | 3.30.1 | -      | SQLite     | SQLite-3.30.1.html |
| C.  | 3.7.17 | 0.9.9  | LumoSQL    | LMDB_0.9.9.html    |
| D.  | 3.7.17 | 0.9.16 | LumoSQL    | LMDB_0.9.16.html   |

To benchmark the four versions above use:

```sh
make benchmark
```

The "Repository" column means:

<dl>
<dt>SQLite</dt>
<dd>

<https://github.com/sqlite/sqlite>

</dd>
<dt>LumoSQL</dt>
<dd>

<https://github.com/LumoSQL/LumoSQL> (this repository)

</dd>
</dl>


