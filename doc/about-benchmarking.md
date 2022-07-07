<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->


<!-- toc -->

About Benchmarkings
==================

Having a reliable benchmarking system has always been one of the LumoSQL objectives. LumoSQL is a modification of SQLite and benchmarking is used to measure and compare the performance of different builds on different machines.

The results are stored in an SQLite database which is available to download at  <https://lumosql.org/dist/benchmarks-to-date>. It is being actively updated and accepting data from volunteers. 

> [Direct Download Link](https://lumosql.org/dist/benchmarks-to-date/all-lumosql-benchmark-data-combined.sqlite)

The source code for benchmarking tools can be found in the [lumosql repo](https://lumosql.org/src/lumosql/dir?name=tool). *benchmark-filter.tcl*  is a useful tool for viewing the data, see [documentation on how to use it](./lumo-benchmark-filter.md). 

Alternatively, plotted data is presented with an [interactive web UI](http://r.lumosql.org:3838/contrastexample.html).

Once LumoSQL is installed the user can perform benchmarks using `make benchmark [OPTIONS]`. Follow an [example of running a benchmark](../README.md#using-the-build-and-benchmark-system) and read the full documantation on [benchmark options](./lumo-build-benchmark.md).


# Discussion

The strange thing is that benchmarking between SQL databases is almost non-existent, as well as difficult.
We focus on the practical recommendations of the 2018
paper [Fair Benchmarking Considered Difficult:Common Pitfalls In Database Performance Testing](https://mytherin.github.io/papers/2018-dbtest.pdf). 
We store the results in an SQLite database, and we make the method and the 
[results](https://lumosql.org/dist/benchmarks-to-date/) available publicly.

The LumoSQL benchmarking problem is less difficult than comparing 
unrelated databases, which is perhaps why the [Transaction Processing Performance Council](https://tpc.org) has not published news since 2004.
There are testing tools released with SQLite, Postgresql, MariaDB etc, but 
there simply is no way to compare. Benchmarking and testing overlap.

The well-described [testing of SQLite](https://sqlite.org/testing.html)
involves some open code, some closed code, and many ad hoc processes. Clearly
the SQLite team have an internal culture of testing that has benefited the
world. However that is very different to testing that is reproducible by
anyone, which is in turn very different to reproducible reproducible by anyone,
and that is even without considering whether the benchmarking is a reasonable
approximation of actual use cases.

## All SQLite Performance Papers are Nonsense



In 2017 a helpful paper was published by [Purohith, Mohan and Chidambaram](https://www.cs.utexas.edu/~vijay/papers/apsys17-sqlite.pdf) on the
topic of "The Dangers and Complexities of SQLite Benchmarking". Since the first
potential problem is that this paper itself is in error, LumoSQL repeated
the literature research component in the paper. We agree with the authors in stating:

> When we investigated 16 papers from the 2015-2017
> whose evaluation included SQLite, we find that none report
> all the parameters required to meaningfully compare
> results: ten papers do not report any parameters [17–26],
> five do not report the sync mode [27–31], while only
> one paper reports all parameters except write-ahead log
> size [32]. Without reporting how SQLite was configured,
> it is meaningless to compare SQLite results.

LumoSQL found three additional papers published in 2017-2019, with similar flaws.
In brief:

> **All published papers on SQLite's performance are nonsense**

And this is for SQLite alone, something that has relatively few parameters
compared to the popular online SQL databases. The field of SQL databases in
general is even more poorly benchmarked.

Benchmarking between SQL databases hardly exists at all. 

# Limiting the Problem Space

LumoSQL has some advantages that reduce the problem space for benchmarking:

* The test harness is effectively the entire SQLite stack above the btree layer
(or lumo-backend.c). It is true that SQLite benchmarking is difficult because
there are so many pragmas and compile options, but most of these apply to all
backends. The *effect* of a given pragma or compile option may differ by
backend, but this will be a second-order effect and hopefully not as severe as
first-order effects.
* The backends we have today differ in a relatively small number of dimensions,
usually to do with their speciality. The SQLite Btree backend has options for
WAL files, journals and cache sizes; the LMDB backend uses the OS buffer cache
and so there are OS-level defaults to be aware of; the BDB backend has tuning
options relating to cache and locking. That relatively small number of
differences still potentially gives a large benchmarking matrix, so we have to
control for that (or regard computation as free, which is close to accurate at
the scale of the LumoSQL project.)
* No networking, clustering or client interoperability involved. This
eliminates many classes of complexity.

To further reduce the problem space we will not be testing across multiple
platforms. This can be addressed later.

# What Questions Will Benchmarking Answer?

Questions by LumoSQL/SQLite internals developers:

- I am considering a change to the main code path to integrate a new feature,
  will the performance of LumoSQL suffer?
- I have identified a potential optimisation, is the performance benefit worth
  the additional complexity?
- I have implemented a new backend, should we make it the default?

Questions by LumoSQL/SQLite application developers:

- Is LumoSQL any different from SQLite when configured to use the SQLite backend?
- I have these requirements for a system, which LumoSQL backend should I choose?

# Checklist from the "Considered Difficult" Paper

We have considered the checklist from the [Fair Benchmarking Considered Difficult:Common Pitfalls In Database Performance Testing paper](https://mytherin.github.io/papers/2018-dbtest.pdf) as a guidline for good benckmarking practice.


* Choosing your Benchmarks.
  - Benchmark covers whole evaluation space
  - Justify picking benchmark subset
  - Benchmark stresses functionality in the evaluation space
* Reproduciblity.
  - Hardware configuration
  - DBMS parameters and version
  - Source code or binary files
  - Data, schema & queries
* Optimization.
  - Compilation flags
  - System parameters
* Apples vs Apples
  - Similar functionality
  - Equivalent workload
* Comparable tuning
  - Different data
  - Various workloads
* Cold/warm/hot runs.
  - Differentiate between cold and hot runs
  - Cold runs: Flush OS and CPU caches
  - Hot runs: Ignore initial runs
* Preprocessing.
  - Ensure preprocessing is the same between systems
  - Be aware of automatic index creation
* Ensure correctness.
  - Verify results
  - Test different data sets
  - Corner cases work
* Collecting Results.
  - Do several runs to reduce interference
  - Check standard deviation for multiple runs
  - Report robust metrics (e.g., median and confidence inter-vals)


## Reproducibility and Tests 

We aim to record a complete set of parameters that define the outcome of the benchmark run. First, to define the environment in which the runs are performed we record:

- os-type
- os-version
- cpu-type
- cpu-comment
- disk-comment
- byte-order
- word-size

Secondly, the exact versions of software involved in the build process:

- backend
- backend-id
- backend-name
- backend-version
- backend-date
- sqlite-id
- sqlite-name
- sqlite-version
- sqlite-date
- notforking-id
- notforking-date

And lastly, the software specific parameters:

- option-debug
- option-lmdb_debug
- option-lmdb_fixed_rowid
- option-lmdb_transaction
- option-rowsum
- option-rowsum_algorithm
- option-sqlite3_journal

Each run performs 17 types of queries that reflect the average user experience (user-cpu-time,  system-cpu-time, and real-time is recorded for each test) :

- Creating database and tables
- 1000 INSERTs
- 100 UPDATEs without an index, upgrading a read-only transaction
- 25000 INSERTs in a transaction
- 100 SELECTs without an index
- 100 SELECTs on a string comparison
- Creating an index
- 5000 SELECTs with an index
- 1000 UPDATEs without an index
- 25000 UPDATEs with an index
- 25000 text UPDATEs with an index
- INSERTs from a SELECT
- DELETE without an index
- DELETE with an index
- A big INSERT after a big DELETE
- A big DELETE followed by many small INSERTs
- DROP TABLE

Runs are performed on different scales by multiplying the number of queries by some factor. That factor is recorded as:

- option-datasize



# Details of Benchmarking Code

## Metrics

Benchmarking will take place via SQL, with these items being measured at least:

* Elapsed time for a series of SQL statements

  The TCL script benchmark.tcl is a forked version of speedtest.tcl, which 
  writes results to an SQLite database as well a producing HTML output.
  The SQL statements are discussed further down in this section. Each of the 
  timed tests will also have VDBE ops and IOPS recorded as per the next 
  two sections.

* VDBE Operations per second 

  benchmark.tcl can collect VDBE ops, but only with some help from LumoSQL.

  A timer is started in sqlite3_prepare(), VDBE opcodes are counted in
  sqlite3VdbeExec(), and the timer is stopped in sqlite3_finalize(). This
  then allows us to calculate how long the sql3_stmt took to execute per
  instruction. The number of instructions will be the same for all backends.

* Disk Operations per second

  benchmark.tcl can do this by comparing per-pid IOPS using the algorithm
  here: https://github.com/true/aspersa-mirror/blob/master/iodump . 
  We look up the IOPS at the beginning and end of the test and store the 
  difference. 

  This is not portable to other operating systems, however, that will
  hopefully be a relatively small variable compared to the the 
  variable of one backend vs another. 

## SQL in benchmark.tcl 

To start with we are modifying speedtest.tcl as described. We are adding a BLOB
test with large generated blobs, but it is basically the same. In the future we
need to have more realistic SQL statements. And that varies by use case:

1. embedded style SQL statements, typically developing for heavily resource
   constrained deployments, who are likely to use SQL to simply store and
   retrieve values and be more interested in tradeoffs and settings that
   reduce latency. Tightly coupled with the SQLite library. Short transactions.
2. online style SQL statements, used for transaction processing. Concurrency
   matters. Same SQL might be used with another database. Some long transactions.
3. online style SQL statements, used for analytics processing. Much more 
   batch oriented. Same SQL might be used with another database. Some long transactions.

## SQL Logic Test

It isn't clear that the SQL logic test is suitable for benchmarking. We are 
working on this, but our hope is that it will be readily adaptable.

[wiki]: https://www.sqlite.org/sqllogictest/doc/trunk/about.wiki
[fossil repository]: https://www.sqlite.org/sqllogictest/dir?name=src&type=tre
[results]:
  https://www.sqlite.org/sqllogictest/wiki?name=Differences+Between+Engines

This works by ODBC - noting that SQLite has an ODBC driver.

## C speed tests with SQLite C API

We have only done basic testing to make sure the code runs.  Our objective in
running these tests will be to quantify performance. These tests use the C API.

`speedtest1.c` appears to be very actively maintained by <https://sqlite.org>,
the file has a number of different contributors and has frequent commits.

`mptest.c` and `threadtest3.c` look promising for testing async access. See the 
notes previously about the unsophisticated concurrency handling we have already
demonstrated in SQLite. 

# Computer architectures and operating systems

We are not going to get ambitious with platforms and variations. For the present,
benchmarking on 64 bit x86 Linux will be sufficient.

We will impose memory pressure in benchmarking runs by limiting the memory
available to the LumoSQL process. However we can do this effectively with the
cgroups API rather than having small VMs.

Other obvious variations for the future include Windows, and 32-bit hardware.
We are ignoring these for now.

## C speed tests with the SQLite/LumoSQL KV API

This is a lesser priority.

It is important to also benchmark at the LumoSQL KV API level, ie
lumo-backend.c .  This is so that we can observe if the performance of each
backend remains roughly the same (especially, *relatively* the same compared to
the others) whether accessed via the SQLite API or directly via the common KV
API. It is possible that the SQLite stack will have some unexpected interaction
with a particular backend - to pick a pathological corner case, a magic string.

# List of Relevant Benchmarking and Test Knowledge

References articles and papers discussing benchmarking can be found in the [Full Knowledgebase Relevant to LumoSQL](./context-relevant-knowledgebase.md#list-of-relevant-benchmarking-and-test-knowledge) section.


References to other benchmarking tools are linked in the [Relevant Codebases](./context-relevant-codebases.md/#list-of-relevant-benchmarking-and-test-knowledge) section.



Benchmarking LumoSQL
====================


# Nature of the Benchmarking

The SQL benchmarking is to seek answers about throughput:

* total time elapsed for tests
* bytes per second (in cases where we are reading or writing a known quantity of data)
* operations per second (with the ops measured either by *vdbe*c, or os_*c, or both.) 

LumoSQL benchmarking will mostly be using blackbox testing approaches
(high-level functionality) with some highly-targetted whitebox testing for
known tricky differences between backends (eg locking). 

Being a low-level library, functional benchmarking often gets close to
internals testing. That's ok, but we need to be aware of this. We don't want to
be doing internals testing. That is for make test.

At a later date we can add benchmarking at LumoSQL KV API level, ie
lumo-backend.c .  This is so that we can observe if the performance of each
backend remains roughly the same (especially, *relatively* the same compared to
the others) whether accessed via the SQLite API or directly via the common KV
API. It is possible that the SQLite stack will have some unexpected interaction
with a particular backend - to pick a pathological corner case, a magic string.



# Possible Benchmarking Dimensions

[TBD - notes only]

* Dataset can fit entirely in memory (or not)
* Caching (durability on/off)
* Updates vs Reads vs -Only
* Ops per second at disk
* VDBE ops per second
* Latency at C API
* Blobs

# SQL Dimensions

* Single filtering plus offset
* join with grouping and ordering
* multiple indexing

# Concurrency Dimensions

This is going to be very important, especially since concurrency is one of SQLite known weak points.
[The async SQLite tests](https://github.com/sqlite/sqlite/blob/master/test/async2.test) don't seem to be stressing concurrency really.
[mptest](https://github.com/sqlite/sqlite/tree/master/mptest) seems to be more along those lines but I haven't done sample runs of it (mptest hasn't changed in 7 years, and all the references to it seem to be in the context of Windows, if that means anything.)

# Workload Simulation

* Analytics-type workload patterns
* Human thread-following app simulation - nearly all read operations
* 50/50 read/write - classical ecommerce-type application
* Mixture of all of above on different threads to be really mean
