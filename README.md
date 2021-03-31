<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2019 -->

# LumoSQL

[LumoSQL](lumosql.org) is a modification (not a fork) of the
[SQLite](https://sqlite.org) embedded data storage library. LumoSQL offers
multiple backend storage systems selectable by the user and proposes other
integrity and security features. If you are an SQLite user familiar with C
development wanting an easier way to benchmark and measure SQLite, or if you
are wanting features only available in other key-value storage engines, then
you may find LumoSQL interesting.

In LumoSQL 0.4 there are currently three LumoSQL backends:

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

Full LumoSQL documentation is maintained by 
[the LumoSQL Documentation project](https://lumosql.org/src/lumodoc), which has separate
goals and tools to LumoSQL (and which is looking for contributors!)

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

<a name="build-environment-and-dependencies"></a>
## Build Environment and Dependencies

LumoSQL uses the [Fossil source code manager](https://fossil-scm.org) because:

* Fossil is designed for projects of up to a million or so lines of code, unlike git (and therefore Github)
* Fossil workflow and tools encourage inclusivity and collaboration rather than forking
* Fossil and SQLite are symbiotic projects and test cases for each other, and therefore LumoSQL may be too 

LumoSQL is mirrored to Github and changes can be imported from Github, but
Fossil is the tool of choice for LumoSQL.

#### Debian or Ubuntu-derived Operating Systems

Uncomment existing `deb-src` line in /etc/apt/sources.list, for example
for Ubuntu 20.04.2 a valid line is:
<b>
```
deb-src http://gb.archive.ubuntu.com/ubuntu focal main restricted
```
</b>

These *exact* commands have been tested on a pristine install of Ubuntu 20.04.2
LTS, installed from ISO or as one of the operating systems shipped with
Windows Services for Linux.

Then run
<b>
```
sudo apt update                              # this fetches the deb-src updates
sudo apt full-upgrade                        # this gets the latest OS updates
sudo apt install git build-essential tclx
sudo apt build-dep sqlite3
```
</b>


#### Fedora-derived Operating Systems

On any reasonably recent Fedora-derived Linux distribution, including Red Hat:

<b>
```sh
sudo dnf install --assumeyes \
  git make gcc ncurses-devel readline-devel glibc-devel autoconf tcl-devel tclx-devel
```
</b>

#### Common to all Linux Operating Systems

Once you have done the setup specific to your operating system in the previous
steps, the following should work on reaonably recent Debian and Fedora-related
operating systems, and Gentoo. 

Other required tools can be installed from your operating system's standard packages.
Here are the tool dependencies:

* [the not-forking tool](https://lumosql.org/src/not-forking/), 
which is a script that needs to be downloaded and installed manually (we will be packaging
it as soon as we can.) The instructions for not-forking are on its website.
* [Fossil](https://fossil-scm.org/). Fossil version 2.13 or later from your distrbution, or [2.13 or 2.12.1 from the Fossil download page](https://fossil-scm.org/home/uv/download.html). *Note!* Ubuntu 20.04 and Debian Buster do not include a sufficiently modern Fossil. Since you now have a development environment you may find it easiest to [build trunk yourself](https://fossil-scm.org/home/doc/trunk/www/build.wiki). These instructions have been tested on Ubuntu 20.04:
    * wget -O- https://fossil-scm.org/home/tarball/trunk/Fossil-trunk.tar.gz |  tar -zxf -
    * sudo apt install libssl-dev
    * cd Fossil-trunk ; ./configure ; make
    * sudo make install
* For completeness (although every modern Linux/Unix includes these), to build and benchmark any of the Oracle Berkeley DB targets, you need either "curl" or "wget", and also "file", "gzip" and GNU "tar". Just about any version of these will be sufficient, even on Windows.

One of the many helpful features of the not-forking tool is that it will advise
you with an error message if you ask for sources that require a tool or a
version that is not installed. So if you didn't quite get everything in the above list 
it won't be difficult notice.

On [Debian 10 "Buster" Stable Release](https://www.debian.org/releases/buster/), the not-forking makefile
("perl Makefile.PL") will warn that git needs to be version 2.22 or higher.
Buster has version 2.20, however this is not a critical error. If you don't
like error messages scrolling past during a build, then install a more recent
git [from Buster backports](https://backports.debian.org/Instructions/).

<a name="using-the-build-and-benchmark-system"></a>
## Using the Build and Benchmark System

This is a very brief quickstart, for full detail see the
[Build and Benchmark System documentation](doc/lumo-build-benchmark.md). 

Now you have the dependencies installed, clone the LumoSQL repository using
`fossil clone https://lumosql.org/src/lumosql` , which will create a new subdirectory called `lumosql` and
a file called `lumosql.fossil` in the current directory.

Try:
<b>
```
cd lumosql
make what
```
</b>

To see what the default sources and options are. The `what` target does not make any changes.

Benchmarking a single binary should take no longer than 4 minutes to complete depending
on hardware. The results are stored in an SQLite database stored in the LumoSQL 
top-level directory by default, that is, the directory you just created using `fossil clone`.

Start by building and benchmarking the official SQLite release version 3.34.0, which is the current
release at the time of writing this README.

<b>
`make benchmark USE_LMDB=no USE_BDB=no SQLITE_VERSIONS='3.34.0'`
</b>

All source files fetched are cached in ~/.cache/LumoSQL in a way that maximises reuse regardless of 
their origin (Fossil, git, wget etc) and which minimises errors. The LumoSQL build system is driving the
`not-fork` tool, which maintains the cache. Not-fork will download just the differences of a remote 
version if most of the code is already in cache.

The output from this make command will be something like this:

<b>
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
</b>

A database with the default name of `benchmarks.sqlite` has been created with
two tables containing the results. This is one single test run, and the test
run data is kept in the table `test_data`. The table `run_data` contains data
relative to a set of runs (version numbers, time test started, etc). This is cumulative,
so another invocation of `make benchmark` will append to `benchmarks.sqlite`.

Every run is assigned a SHA3 hash, which helps in making results persistent over time and 
across the internet.

The tool `benchmark-filter.tcl` does some basic processing of these results:

<b>
```
tool/benchmark-filter.tcl
RUN_ID                                                            TARGET  DATE        TIME         DURATION
DF28B0624434217B09E54A422E077307B60A913F7DDA1E7BA46DDE1F142DB2F1  3.34.0  2021-01-08  19:55:04       75.515
```
</b>

The option DATASIZE=**parameter** is a multiplication factor on the size of the chunks that is used for 
benchmarking. This is useful because it can affect the time it takes to run the tests by a very different
multiplication factor:

<b>
```
make benchmark USE_LMDB=no USE_BDB=no DATASIZE=2 SQLITE_VERSIONS='3.34.0 3.33.0'
```
</b>

followed by:

<b>
```
tool/benchmark-filter.tcl 
RUN_ID                                                            TARGET              DATE        TIME         DURATION
DF28B0624434217B09E54A422E077307B60A913F7DDA1E7BA46DDE1F142DB2F1  3.34.0              2021-01-08  19:55:04       75.515
FCD1E838F9FC61EAA39F4721EA252F5F10DE9FE57ABA22115D3E2793F5EB1095  3.34.0++datasize-2  2021-01-08  21:54:18      321.976
FA227B630BE52C537DCE1E4929D9335551F7AEE80A30EE2D449212CD2F94C727  3.33.0++datasize-2  2021-01-08  21:59:57      331.486
```
</b>

Simplistically, these results suggest that SQLite version 3.34.0 is faster than
3.33.0 on larger data sizes, but that 3.34.0 is much faster with smaller data
sizes. After adding more versions and running the benchmarking tool again, we would
soon discover that SQLite 3.25.0 seems faster than 3.33.0, and other interesting things. 
Simplistic interpretations can be misleading :-)

This is a Quickstart, so for full detail you will need the 
[Build/Benchmark documentation](doc/lumo-build-benchmark.md). However as a teaser, and since LMDB
was the original inspiration for LumoSQL (see the 
[History section below]((#a-brief-history-of-lumosql) for more on that) here are some more things that
can be done with the LMDB target:

<b>
```
$ make what LMDB_VERSIONS=all
tclsh tool/build.tcl what not-fork.d  LMDB_VERSIONS='all'
BENCHMARK_DB=benchmarks.sqlite
BENCHMARK_RUNS=1
SQLITE_VERSIONS=3.34.0
USE_SQLITE=yes
USE_BDB=yes
SQLITE_FOR_BDB=
BDB_VERSIONS=
BDB_STANDALONE=18.1.32=3.18.2
USE_LMDB=yes
SQLITE_FOR_LMDB=3.8.3.1
LMDB_VERSIONS=all
LMDB_STANDALONE=
OPTION_DATASIZE=1
OPTION_DEBUG=off
BUILDS=
    3.34.0
    3.18.2
    +bdb-18.1.32
    3.8.3.1
    3.8.3.1+lmdb-0.9.8
    3.8.3.1+lmdb-0.9.9
    3.8.3.1+lmdb-0.9.10
    3.8.3.1+lmdb-0.9.11
    3.8.3.1+lmdb-0.9.12
    3.8.3.1+lmdb-0.9.13
    3.8.3.1+lmdb-0.9.14
    3.8.3.1+lmdb-0.9.15
    3.8.3.1+lmdb-0.9.16
    3.8.3.1+lmdb-0.9.17
    3.8.3.1+lmdb-0.9.18
    3.8.3.1+lmdb-0.9.19
    3.8.3.1+lmdb-0.9.20
    3.8.3.1+lmdb-0.9.21
    3.8.3.1+lmdb-0.9.22
    3.8.3.1+lmdb-0.9.23
    3.8.3.1+lmdb-0.9.24
    3.8.3.1+lmdb-0.9.25
    3.8.3.1+lmdb-0.9.26
    3.8.3.1+lmdb-0.9.27
TARGETS=
    3.34.0
    3.18.2
    +bdb-18.1.32
    3.8.3.1
    3.8.3.1+lmdb-0.9.8
    3.8.3.1+lmdb-0.9.9
    3.8.3.1+lmdb-0.9.10
    3.8.3.1+lmdb-0.9.11
    3.8.3.1+lmdb-0.9.12
    3.8.3.1+lmdb-0.9.13
    3.8.3.1+lmdb-0.9.14
    3.8.3.1+lmdb-0.9.15
    3.8.3.1+lmdb-0.9.16
    3.8.3.1+lmdb-0.9.17
    3.8.3.1+lmdb-0.9.18
    3.8.3.1+lmdb-0.9.19
    3.8.3.1+lmdb-0.9.20
    3.8.3.1+lmdb-0.9.21
    3.8.3.1+lmdb-0.9.22
    3.8.3.1+lmdb-0.9.23
    3.8.3.1+lmdb-0.9.24
    3.8.3.1+lmdb-0.9.25
    3.8.3.1+lmdb-0.9.26
    3.8.3.1+lmdb-0.9.27
```
</b>

After executing this build with `make benchmark` rather than `make what`, here are summary results using a 
a new parameter to `benchmark-filter.tcl`:

<b>
```
$ tool/benchmark-filter.tcl -fields TARGET,DURATION
TARGET                  DURATION 
3.8.3.1+lmdb-0.9.9        89.523 
3.8.3.1+lmdb-0.9.10       88.351 
3.8.3.1+lmdb-0.9.11       86.815 
3.8.3.1+lmdb-0.9.12       99.207 
3.8.3.1+lmdb-0.9.13       87.490 
3.8.3.1+lmdb-0.9.14       88.241 
3.8.3.1+lmdb-0.9.15       88.415 
3.8.3.1+lmdb-0.9.16       86.958 
3.8.3.1+lmdb-0.9.17       90.032 
3.8.3.1+lmdb-0.9.18       89.872 
3.8.3.1+lmdb-0.9.19       92.257 
3.8.3.1+lmdb-0.9.21       93.398 
3.8.3.1+lmdb-0.9.22       93.473 
3.8.3.1+lmdb-0.9.23       93.908 
3.8.3.1+lmdb-0.9.24       95.054 
3.8.3.1+lmdb-0.9.25       89.829 
3.8.3.1+lmdb-0.9.26      101.211 
3.8.3.1+lmdb-0.9.27       90.744 
3.8.3.1                   73.464 
```
</b>

Again, simplistic interpretations are insufficient, but the data here suggests that LMDB has decreased
in performance over time, and no version of LMDB is faster than native SQLite 3.8.3.1 . However, further
benchmark runs indicates that is not the final story, as LMDB run on slower hard disks improve in relative 
speed rapidly. And we need to try the latest version of SQLite with all the versions of LMDB available 
in order to get an up-to-date picture. 

The results for the Berkely DB backend are also most interesting.

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





