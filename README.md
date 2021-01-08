<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2019 -->

# LumoSQL

[LumoSQL](lumosql.org) is a modification (not a fork) of the [SQLite](https://sqlite.org)
embedded data storage C language library. LumoSQL has multiple backend storage
systems selectable by the user and proposes other integrity and security features.
There are currently three backends: the default SQLite Btree storage system,
[LMDB](https://github.com/LMDB/lmdb) and [the Berkley Database](https://en.wikipedia.org/wiki/Berkeley_DB).

LumoSQL has a build and benchmarking tool for comparing vanilla SQLite versions and configurations
with each other, as well as with different storage backends.

LumoSQL is distributed under [very liberal licence terms](LICENCES/README.md).

Full LumoSQL documentation is maintained by 
[the LumoSQL Documentation project](https://lumosql.org/src/lumodoc), which has separate
goals and tools to LumoSQL (and which is looking for contributions!)

LumoSQL is supported by the [NLNet Foundation](https://nlnet.nl).

# Table of Contents

* [Participating, Not-Forking and Project Interactions](#participating-not-forking-and-project-interactions)
* [LumoSQL, and SQLite's Billions](#lumosql-and-sqlites-billions-of-users)
* [Quickstart](#quickstart)
  * [Build environment](#build-environment)
  * [Install dependencies](#install-dependencies)
  * [Using the Makefile tool](#using-the-makefile-tool)
* [Speed tests / benchmarking](#speed-tests--benchmarking)
* [A Brief History](#a-brief-history)

<a name="participating-not-forking-and-project-interactions"></a>
## Participating, Not-Forking and Project Interactions

If you are reading this on Github, then you are looking at a mirror. LumoSQL is
is maintained using [the Fossil repository](https://lumosql.org/src/lumosql). If you 
want to participate in LumoSQL there is a forum, and if you have code contributions
you can ask for access to the respository.

LumoSQL has multiple upstreams, but does not fork any of them.
The [Not-forking](https://lumosql.org/src/not-forking) tool is a requirement for 
building LumoSQL.

The LumoSQL and SQLite projects are cooperating, so any merge friction is
expected to become less over time, and key to that the approach of not
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

LumoSQL uses the [Fossil source code manager](https://fossil-scm.org) for these reasons:
* Fossil has advantages over Github which suit a project of this size, since Fossil was 
  intended for use by projects with less than one million lines of code
* Fossil encourages inclusivity and collaboration rather than forking
* Fossil and SQLite are symbiotic projects and test cases for each other

LumoSQL is mirrored to Github and changes can be imported from Github, but
Fossil is the tool of choice for LumoSQL.

<a name="quickstart"></a>
## Quickstart

* Ensure you have the build environment described below
* Type "make" in the top level directory

The [LumoSQL Build and Benchmark System](doc/lumo-build-benchmark.md) is well documented 
when you need to go deeper.

<a name="build-environment"></a>
## Build environment

The build system requires [the not-forking tool](https://lumosql.org/src/not-forking/).
Once that is installed, some other tools are needed, usually provided by installing
development packages.

On Ubuntu 18.0.4 LTS, Debian Stable (buster), and on any reasonably recent
Debian or Ubuntu-derived distribution, you need only:

```sh
sudo apt install git build-essential tclx
sudo apt build-dep sqlite3
```

(`apt build-dep` requires `deb-src` lines uncommented in /etc/apt/sources.list).

On Fedora 30, and on any reasonably recent Fedora-derived distribution:

```sh
sudo dnf install --assumeyes \
  git make gcc ncurses-devel readline-devel glibc-devel autoconf tcl-devel tclx-devel
```

The following steps have been tested on Fedora 30 and Ubuntu 18.04 LTS (via the
`container` target in the [Makefile](/Makefile)).

<a name="install-dependencies"></a>
## Install Dependencies

* to build and benchmark just SQLite, you need to have [Fossil](https://fossil-scm.org/)
* to build and benchmark any of the LMDB targets, you need to have git
* to build and benchmark any of the Oracle Berkeley DB targets, you need either curl or wget, and GNU tar

Select the version(s) you want from this list:

* git version 2.22 or later
* fossil version 2.13 or later from your distrbution, or [2.13 or 2.12.1 from the Fossil download page](https://fossil-scm.org/home/uv/download.html). You may want to [build trunk yourself](https://fossil-scm.org/home/doc/trunk/www/build.wiki), since it is very quick and easy even compared to LumoSQL.
* curl, wget and GNU tar mostly just have to exist. Even on Windows almost any version will be sufficient.

The not-forking tool will also advise you with an error message if you ask for sources that
require a tool that is not installed on your operating system.

<a name="using-the-makefile-tool"></a>
## Using the Makefile tool

Start with a clone of this repository as the current directory.

To build either (a) specific versions of SQLite or (b) sqlightning using
different versions of LMDB, use commands like those below changing the version
numbers to suit. A list of tested version numbers is in the table
[below](#which-lmdb-version).

```sh
make TARGETS=3.7.17
make TARGETS=3.7.17+lmdb-0.9.9
make TARGETS="3.33.0 3.7.17 3.7.17+lmdb-0.9.9"
```
See the [lumo-test-build](./doc/lumo-test-build.md) document for a large
number of options controlling the process, without having to figure out
the exact syntax for the `TARGETS` option.

# Speed tests / benchmarking

To benchmark a single binary takes approximately 4 minutes to complete depending
on hardware. The results are stored in an SQLite database stored in the LumoSQL 
top-level directory by default.

The instructions in this section explain how to benchmark six different
versions:

| V. | SQLite  | Backend     | Repository |
| -- | ------- | ----------- | ---------- |
| A. | 3.8.3.1 | -           | SQLite     |
| B. | 3.18.2  | -           | SQLite     |
| C. | 3.33.0  | -           | SQLite     |
| D. | 3.8.3.1 | LMDB 0.9.9  | LumoSQL    |
| E. | 3.8.3.1 | LMDB 0.9.16 | LumoSQL    |
| F. | 3.8.3.1 | LMDB 0.9.27 | LumoSQL    |

To benchmark the six versions above use:

```sh
make benchmark
```

This will create a database `benchmarks.sqlite` (if it does not already exist) with
two tables containing the results, `run_data` contains data relative to a whole
set of runs (version numbers, time test started, etc) and `test_data` contains
individual test results within a run; it will also produce a summary on standard
output:
```
Creating database benchmarks.sqlite
Target: 3.7.17
 21.772    1 1000 INSERTs
  0.257    2 25000 INSERTs in a transaction
...

```

If you want to store benchmarking in a different database file, use `BENCHMARK_DB`:

```
make benchmark BENCHMARK_DB=~/my-lumosql-results.sqlite
```

To run the benchmark for just two targets, and repeat the run 5 times:
```sh
make benchmark TARGETS="3.7.17 3.7.17+lmdb-0.9.9" BENCHMARK_RUNS=2
```

A simple (draft) tool is provided to display test results from the database:

```sh
tclsh tool/benchmark-filter.tcl
```

This gives a 1-line summary of each run in the database, for example:
```
RUN_ID                                                           TARGET               DATE/TIME             DURATION
0905DCF04077ADF9FB96FB382B023123CEDE86FA510FB66F2F7E095743CB82E1 3.7.17               2020-11-05 20:10:23    148.431
DDEC21FF7EF9186E4B636A948F387A7BA62BF0E7B503BD59BC0B1869340CCA9E 3.30.1               2020-11-05 20:13:06     89.370
5A02EAC0981E8C0502FD3AA137E292BC8912AFD0C27C043A9BC944CC53FB1739 3.33.0               2020-11-05 20:14:50     78.099
1FDEED012CAC8CC78CB76A658195A8D5C5B6FC4C1504B11064871C28BFB3F368 3.7.17+lmdb-0.9.9    2020-11-05 20:16:23    169.795
92CD0F823663E082BC91E75DBE8462D99874B87208F0D9FCE5CE145275D56B5E 3.7.17+lmdb-0.9.16   2020-11-05 20:19:28    156.159
D404F589B8FF22E5571E41323497BC0EF11E138A7CA1526FE114F9A869B5CCB9 3.7.17+lmdb-0.9.26   2020-11-05 20:22:19    177.874
```

or given one or more run IDs (first column of the output):

```sh
tclsh tool/benchmark-filter.tcl RUN_ID [RUN_ID]...
```

For example:

```
$ tclsh tool/benchmark-filter.tcl D404F589B8FF22E5571E41323497BC0EF11E138A7CA1526FE114F9A869B5CCB9
Benchmark: sqlite 3.7.17 with lmdb 0.9.26
   Target: 3.7.17+lmdb-0.9.26
          (3.7.17 2013-05-20 00:56:22 118a3b35693b134d56ebd780123b7fd6f1497668 lmdb 0.9.26 20403b7b3818fdddb11288245061b31a36066472)
   Ran at: 2020-11-05 20:22:19
 Duration: 177.874

       TIME NUM NAME
      7.424   1 1000 INSERTs
      7.369   2 25000 INSERTs in a transaction
      0.372   3 100 SELECTs without an index
      1.102   4 100 SELECTs on a string comparison
     16.435   5 5000 SELECTs
      0.156   6 1000 UPDATEs without an index
     87.422   7 25000 UPDATEs with an index
     57.220   8 25000 text UPDATEs with an index
      0.057   9 INSERTs from a SELECT
      0.037  10 DELETE without an index
      0.040  11 DELETE with an index
      0.069  12 A big INSERT after a big DELETE
      0.139  13 A big DELETE followed by many small INSERTs
      0.030  14 DROP TABLE

```

The "Repository" column means:

<dl>
<dt>SQLite</dt>
<dd>

https://github.com/sqlite/sqlite

</dd>
<dt>LumoSQL</dt>
<dd>

https://lumosql.org/src/lumosql/
(this repository)

</dd>
</dl>

<a name="a-brief-history"></a>
## A Brief History

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





