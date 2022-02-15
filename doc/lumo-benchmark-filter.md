<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Claudio Calvelli, November 2020 -->


Table of Contents
=================

   * [Displaying/processing benchmark results](#displayingprocessing-benchmark-results)
   * [Full set of options](#full-set-of-options)

Displaying/processing benchmark results
=======================================

The LumoSQL project runs a number of benchmarks on different versions of SQLite
optionally combined with third party storage backends; the results of these
benchmarks are kept in a SQLite database, by default `benchmarks.sqlite`;
the `benchmark-filter` tool is a simple TCL script which displays the results
in different ways; it can optionally also update the database to add extra
information to the benchmarks (for example something to identify who ran the
benchmarks, or the system where they ran) and export the benchmarks to a text
file for sending to other people without sending the sqlite database itself.

After running some benchmarks, call the tool with:
```
tclsh tool/benchmark-filter.tcl OPTIONS
```

If sqlite3 is installed on the system, or it is available from the LumoSQL
build directory, the tool can run without any options; otherwise it needs
to be given a path to a working version of sqlite; for the examples here
we assume that sqlite3 is available and the tool can run without any options.

Without any options it will show a summary of the most recent 20 benchmarks
with one line per benchmark starting with a "run ID" which is a unique
identifier which can be used to refer to the benchmark.  For example:

```
tclsh tool/benchmark-filter.tcl
RUN_ID                                                            TARGET                         DATE        TIME         DURATION
6D5E57885E9AE39E44CFF21ECAF40C24A8C4734A2829E1BD045B998090E1777E  3.37.0                         2022-02-13  18:58:48        4.679
81AC418B168B405615E46E916E714C96E6E3CA973A4CD4E4121D3865A178547E  3.37.0+lmdb-0.9.28             2022-02-13  18:59:14        3.280
4D0479B0DDA565B181B3EF17CAFB9DB97AAB6030B89C6189A46417D18C079509  3.37.1                         2022-02-13  18:59:39        4.728
C8FB7CC1C6486BB13F88ACD14C6C99572CEBEACA237645D3892F82BA1C25023A  3.37.1+lmdb-0.9.28             2022-02-13  19:00:05        3.024
0D18BDC37964B1D01150C160168DF5AB8A7514B20CF4E12170D9935B6682FCE3  3.37.2                         2022-02-13  19:00:29        4.207
670890DBE1E7AC4D61502E29FFAA5F950F59CD43D836BE3F34C3987FECD3C5DE  3.37.2+lmdb-0.9.28             2022-02-13  19:00:55        3.235
59074F6911449A752D9B842B5463869FE4283189E00FE3412A6F61A41CA2C63C  3.37.0+lmdb-0.9.29             2022-02-13  19:01:20        3.332
380FAC937E5B3088B0C246B4E0BE8FBB518085D6AD02956B53B90F071EC75BB4  3.37.1+lmdb-0.9.29             2022-02-13  19:01:44        3.188
F94BAB67A863BBA40CDE5D0B6C341FB9894563C008E44D682895C6723B4CD6AB  3.37.2+lmdb-0.9.29             2022-02-13  19:02:09        3.201
2CE9245515AFCBF387E94276309CCA4E9B70C920648F3509A95F3468F0F190A6  3.18.2++datasize-2             2022-02-13  19:02:41        8.829
A7342AB2CFF20FDF0A50B7EE88ED3907BDCCA9FA565D507C15A6537440C42930  +bdb-18.1.32+datasize-2        2022-02-13  19:03:11       10.879
D04DBC3C4BCF95331F209D01A58CF336ACBE3A85C2728837F5C0FF23E19494FC  3.37.0++datasize-2             2022-02-13  19:03:44        9.460
5851F2F616898546DECF1FA40BC8DB4B30B804F54C8B843A642B238F5DE06B94  3.37.0+lmdb-0.9.28+datasize-2  2022-02-13  19:04:14       34.170
C30E8AA797DCE8AB613C59A4D595E2FC530A4443B20FFAA17F9139D7285B94A9  3.37.1++datasize-2             2022-02-13  19:05:10        9.140
5BA1D49295BE671078A8162735B999918283FD8D719289204019A6E3C1D28D40  3.37.1+lmdb-0.9.28+datasize-2  2022-02-13  19:05:40       32.710
5790AB5B8F27AFFFE663A1A69A183B46F0261E40A6BBC8CA3AD541521325C308  3.37.2++datasize-2             2022-02-13  19:06:35        9.315
4E9B32A4DEBA03F09F44961726EACD7DF98161ABE94BD0F5A26965AEE80EAFC0  3.37.2+lmdb-0.9.28+datasize-2  2022-02-13  19:07:05       32.959
8DDF79AA141A5E6FB86BE0669088C5BA4DBD7D11D0BC2CF28CFF197F94E61682  3.37.0+lmdb-0.9.29+datasize-2  2022-02-13  19:08:00       33.064
11FE5A7259AA58C536260D4CC69D2CCA8E58700367B13BA809914EF11259BA51  3.37.1+lmdb-0.9.29+datasize-2  2022-02-13  19:08:54       32.555
3831757C412F45E78E3CBD7620C70ECB8A59AAEDA37F35E15078A70987332456  3.37.2+lmdb-0.9.29+datasize-2  2022-02-13  19:09:48       32.042
FIlter returned more than 20 runs, list has been truncated
Use: -limit NUMBER to change the limit, or: -limit 0 to show all
```

To display one or more results, add the run IDs to the command, for example:

```
tclsh tool/benchmark-filter.tcl 0D18BDC37964B1D01150C160168DF5AB8A7514B20CF4E12170D9935B6682FCE3
    Benchmark: sqlite 3.37.2
       Target: 3.37.2
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1)
       Ran at: 2022-02-13 19:00:29
     Duration: 4.207
    Disk time: read: 0.522; write: 2.177

       TIME TEST NAME
      0.007    1 Creating database and tables
      2.789    2 1000 INSERTs
      0.013    3 100 UPDATEs without an index, upgrading a read-only transaction
      0.085    4 25000 INSERTs in a transaction
      0.117    5 100 SELECTs without an index
      0.436    6 100 SELECTs on a string comparison
      0.032    7 Creating an index
      0.066    8 5000 SELECTs with an index
      0.061    9 1000 UPDATEs without an index
      0.155   10 25000 UPDATEs with an index
      0.136   11 25000 text UPDATEs with an index
      0.082   12 INSERTs from a SELECT
      0.076   13 DELETE without an index
      0.060   14 DELETE with an index
      0.059   15 A big INSERT after a big DELETE
      0.022   16 A big DELETE followed by many small INSERTs
      0.013   17 DROP TABLE
------------
      4.207 (total benchmark run time)
```

or:

```
tclsh tool/benchmark-filter.tcl 0D18BDC37964B1D01150C160168DF5AB8A7514B20CF4E12170D9935B6682FCE3 670890DBE1E7AC4D61502E29FFAA5F950F59CD43D836BE3F34C3987FECD3C5DE F94BAB67A863BBA40CDE5D0B6C341FB9894563C008E44D682895C6723B4CD6AB
Column 1
    Benchmark: sqlite 3.37.2
       Target: 3.37.2
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1)
       Ran at: 2022-02-13 19:00:29
     Duration: 4.207
    Disk time: read: 0.522; write: 2.177

Column 2
    Benchmark: sqlite 3.37.2 with lmdb 0.9.28
       Target: 3.37.2+lmdb-0.9.28
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1lmdb 0.9.28)
       Ran at: 2022-02-13 19:00:55
     Duration: 3.235
    Disk time: read: 0.522; write: 2.176

Column 3
    Benchmark: sqlite 3.37.2 with lmdb 0.9.29
       Target: 3.37.2+lmdb-0.9.29
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1lmdb 0.9.29)
       Ran at: 2022-02-13 19:02:09
     Duration: 3.201
    Disk time: read: 0.523; write: 2.192

--------------- TIME --------------
          1           2           3 TEST NAME
      0.007       0.010       0.010    1 Creating database and tables
      2.789       1.484       1.429    2 1000 INSERTs
      0.013       0.020       0.016    3 100 UPDATEs without an index, upgrading a read-only transaction
      0.085       0.094       0.096    4 25000 INSERTs in a transaction
      0.117       0.240       0.238    5 100 SELECTs without an index
      0.436       0.533       0.527    6 100 SELECTs on a string comparison
      0.032       0.037       0.044    7 Creating an index
      0.066       0.062       0.061    8 5000 SELECTs with an index
      0.061       0.099       0.103    9 1000 UPDATEs without an index
      0.155       0.180       0.183   10 25000 UPDATEs with an index
      0.136       0.144       0.148   11 25000 text UPDATEs with an index
      0.082       0.080       0.092   12 INSERTs from a SELECT
      0.076       0.082       0.077   13 DELETE without an index
      0.060       0.070       0.074   14 DELETE with an index
      0.059       0.071       0.069   15 A big INSERT after a big DELETE
      0.022       0.021       0.023   16 A big DELETE followed by many small INSERTs
      0.013       0.007       0.010   17 DROP TABLE
------------------------------------
      4.207       3.235       3.201 (total benchmark run time)
```

This result can also be obtained by selecting runs by their properties, in this
case they all had the SQLite version (3.37.2) and datasize (1) in common, so:
```
tclsh tool/benchmark-filter.tcl -version 3.37.2 -datasize 1
Column 1
    Benchmark: sqlite 3.37.2
       Target: 3.37.2
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1)
       Ran at: 2022-02-13 19:00:29
     Duration: 4.207
    Disk time: read: 0.522; write: 2.177

... (same output as previous example)
```

Or to compare all LMDB results with datasize 2:

```
tclsh tool/benchmark-filter.tcl -backend lmdb -datasize 2
Column 1
    Benchmark: sqlite 3.37.0 with lmdb 0.9.28
       Target: 3.37.0+lmdb-0.9.28+datasize-2
              (3.37.0 2021-11-27 14:13:22 bd41822c7424d393a30e92ff6cb254d25c26769889c1499a18a0b9339f5dalt1lmdb 0.9.28)
       Ran at: 2022-02-13 19:04:14
     Duration: 34.170
    Disk time: read: 0.403; write: 1.938

Column 2
    Benchmark: sqlite 3.37.1 with lmdb 0.9.28
       Target: 3.37.1+lmdb-0.9.28+datasize-2
              (3.37.1 2021-12-30 15:30:28 378629bf2ea546f73eee84063c5358439a12f7300e433f18c9e1bddd948dalt1lmdb 0.9.28)
       Ran at: 2022-02-13 19:05:40
     Duration: 32.710
    Disk time: read: 0.405; write: 1.978

Column 3
    Benchmark: sqlite 3.37.2 with lmdb 0.9.28
       Target: 3.37.2+lmdb-0.9.28+datasize-2
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1lmdb 0.9.28)
       Ran at: 2022-02-13 19:07:05
     Duration: 32.959
    Disk time: read: 0.404; write: 1.948

Column 4
    Benchmark: sqlite 3.37.0 with lmdb 0.9.29
       Target: 3.37.0+lmdb-0.9.29+datasize-2
              (3.37.0 2021-11-27 14:13:22 bd41822c7424d393a30e92ff6cb254d25c26769889c1499a18a0b9339f5dalt1lmdb 0.9.29)
       Ran at: 2022-02-13 19:08:00
     Duration: 33.064
    Disk time: read: 0.404; write: 1.941

Column 5
    Benchmark: sqlite 3.37.1 with lmdb 0.9.29
       Target: 3.37.1+lmdb-0.9.29+datasize-2
              (3.37.1 2021-12-30 15:30:28 378629bf2ea546f73eee84063c5358439a12f7300e433f18c9e1bddd948dalt1lmdb 0.9.29)
       Ran at: 2022-02-13 19:08:54
     Duration: 32.555
    Disk time: read: 0.404; write: 1.939

Column 6
    Benchmark: sqlite 3.37.2 with lmdb 0.9.29
       Target: 3.37.2+lmdb-0.9.29+datasize-2
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1lmdb 0.9.29)
       Ran at: 2022-02-13 19:09:48
     Duration: 32.042
    Disk time: read: 0.404; write: 1.950

--------------------------------- TIME --------------------------------
          1           2           3           4           5           6 TEST NAME
      0.010       0.010       0.010       0.009       0.014       0.014    1 Creating database and tables
      2.973       3.113       2.621       2.599       2.842       2.511    2 2000 INSERTs
      0.053       0.060       0.057       0.053       0.037       0.056    3 200 UPDATEs without an index, upgrading a read-only transaction
      0.158       0.162       0.160       0.157       0.168       0.163    4 50000 INSERTs in a transaction
      0.828       0.881       0.874       0.812       0.900       0.862    5 200 SELECTs without an index
      2.056       2.019       2.059       2.039       1.989       2.035    6 200 SELECTs on a string comparison
      0.068       0.063       0.068       0.059       0.074       0.079    7 Creating an index
     26.623      24.999      25.713      25.925      25.114      24.914    8 10000 SELECTs with an index
      0.289       0.308       0.307       0.305       0.317       0.309    9 2000 UPDATEs without an index
      0.347       0.343       0.339       0.343       0.340       0.340   10 50000 UPDATEs with an index
      0.266       0.261       0.266       0.266       0.268       0.269   11 50000 text UPDATEs with an index
      0.132       0.137       0.116       0.146       0.119       0.142   12 INSERTs from a SELECT
      0.126       0.127       0.126       0.127       0.131       0.125   13 DELETE without an index
      0.091       0.083       0.082       0.085       0.094       0.080   14 DELETE with an index
      0.114       0.109       0.127       0.112       0.114       0.116   15 A big INSERT after a big DELETE
      0.026       0.024       0.023       0.017       0.025       0.020   16 A big DELETE followed by many small INSERTs
      0.010       0.011       0.012       0.011       0.010       0.007   17 DROP TABLE
------------------------------------------------------------------------
     34.170      32.710      32.959      33.064      32.555      32.042 (total benchmark run time)

```

When there are a lot of runs selected, this output can get unreadable as
it will be wider than any terminal.  This default (show one target per
column) can be changed by adding `-column benchmark` meaning "show one
benchmark per column" (here we omit most columns for illustration):

```
tclsh tool/benchmark-filter.tcl -backend lmdb -datasize 2 -column benchmark
Column 1: Creating database and tables
Column 2: 2000 INSERTs
Column 3: 200 UPDATEs without an index, upgrading a read-only transaction
Column 4: 50000 INSERTs in a transaction
Column 5: 200 SELECTs without an index
Column 6: 200 SELECTs on a string comparison
Column 7: Creating an index
Column 8: 10000 SELECTs with an index
Column 9: 2000 UPDATEs without an index
Column 10: 50000 UPDATEs with an index
Column 11: 50000 text UPDATEs with an index
Column 12: INSERTs from a SELECT
Column 13: DELETE without an index
Column 14: DELETE with an index
Column 15: A big INSERT after a big DELETE
Column 16: A big DELETE followed by many small INSERTs
Column 17: DROP TABLE
Column 18: Total run duration

    1     2     3     4     5     6     7      8     9    10    11    12    13    14    15    16    17     18 Target
0.010 2.973 0.053 0.158 0.828 2.056 0.068 26.623 0.289 0.347 0.266 0.132 0.126 0.091 0.114 0.026 0.010 34.170 3.37.0+lmdb-0.9.28+datasize-2
0.010 3.113 0.060 0.162 0.881 2.019 0.063 24.999 0.308 0.343 0.261 0.137 0.127 0.083 0.109 0.024 0.011 32.710 3.37.1+lmdb-0.9.28+datasize-2
0.010 2.621 0.057 0.160 0.874 2.059 0.068 25.713 0.307 0.339 0.266 0.116 0.126 0.082 0.127 0.023 0.012 32.959 3.37.2+lmdb-0.9.28+datasize-2
0.009 2.599 0.053 0.157 0.812 2.039 0.059 25.925 0.305 0.343 0.266 0.146 0.127 0.085 0.112 0.017 0.011 33.064 3.37.0+lmdb-0.9.29+datasize-2
0.014 2.842 0.037 0.168 0.900 1.989 0.074 25.114 0.317 0.340 0.268 0.119 0.131 0.094 0.114 0.025 0.010 32.555 3.37.1+lmdb-0.9.29+datasize-2
0.014 2.511 0.056 0.163 0.862 2.035 0.079 24.914 0.309 0.340 0.269 0.142 0.125 0.080 0.116 0.020 0.007 32.042 3.37.2+lmdb-0.9.29+datasize-2
```

While this output is still quite wide, it will fit most displays, and does
not grow with the number of runs selected; also, the `-benchmarks` option
can help by selecting only the columns of interest, for example:

```
tclsh tool/benchmark-filter.tcl -backend lmdb -datasize 2 -column benchmark -benchmarks 2,8,total
Column 2: 2000 INSERTs
Column 8: 10000 SELECTs with an index
Column 18: Total run duration

    2      8     18 Target
2.973 26.623 34.170 3.37.0+lmdb-0.9.28+datasize-2
3.113 24.999 32.710 3.37.1+lmdb-0.9.28+datasize-2
2.621 25.713 32.959 3.37.2+lmdb-0.9.28+datasize-2
2.599 25.925 33.064 3.37.0+lmdb-0.9.29+datasize-2
2.842 25.114 32.555 3.37.1+lmdb-0.9.29+datasize-2
2.511 24.914 32.042 3.37.2+lmdb-0.9.29+datasize-2
```

Note that only "like-for-like" can be compared, the tests with the "datasize 1" option
differ from the tests with "datasize 2" and the tool will not show these side by side.
However, the option `-ignore-numbers` instructs the tool to ignore numbers in
the test names, so that they can be compared:

```
tclsh tool/benchmark-filter.tcl 0D18BDC37964B1D01150C160168DF5AB8A7514B20CF4E12170D9935B6682FCE3 5790AB5B8F27AFFFE663A1A69A183B46F0261E40A6BBC8CA3AD541521325C308
Runs 5790AB5B8F27AFFFE663A1A69A183B46F0261E40A6BBC8CA3AD541521325C308 and 0D18BDC37964B1D01150C160168DF5AB8A7514B20CF4E12170D9935B6682FCE3 have different tests

tclsh tool/benchmark-filter.tcl -ignore-numbers 0D18BDC37964B1D01150C160168DF5AB8A7514B20CF4E12170D9935B6682FCE3 5790AB5B8F27AFFFE663A1A69A183B46F0261E40A6BBC8CA3AD541521325C308
Column 1
    Benchmark: sqlite 3.37.2
       Target: 3.37.2
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1)
       Ran at: 2022-02-13 19:00:29
     Duration: 4.207
    Disk time: read: 0.522; write: 2.177

Column 2
    Benchmark: sqlite 3.37.2
       Target: 3.37.2++datasize-2
              (3.37.2 2022-01-06 13:25:41 872ba256cbf61d9290b571c0e6d82a20c224ca3ad82971edc46b29818d5dalt1)
       Ran at: 2022-02-13 19:06:35
     Duration: 9.315
    Disk time: read: 0.405; write: 1.945

--------- TIME --------
          1           2 TEST NAME
      0.007       0.011    1 Creating database and tables
      2.789       5.574    2 # INSERTs
      0.013       0.032    3 # UPDATEs without an index, upgrading a read-only transaction
      0.085       0.147    4 # INSERTs in a transaction
      0.117       0.455    5 # SELECTs without an index
      0.436       1.730    6 # SELECTs on a string comparison
      0.032       0.050    7 Creating an index
      0.066       0.099    8 # SELECTs with an index
      0.061       0.149    9 # UPDATEs without an index
      0.155       0.305   10 # UPDATEs with an index
      0.136       0.235   11 # text UPDATEs with an index
      0.082       0.126   12 INSERTs from a SELECT
      0.076       0.139   13 DELETE without an index
      0.060       0.093   14 DELETE with an index
      0.059       0.120   15 A big INSERT after a big DELETE
      0.022       0.028   16 A big DELETE followed by many small INSERTs
      0.013       0.021   17 DROP TABLE
------------------------
      4.207       9.315 (total benchmark run time)
```

# Full set of options <a name="full-set-of-options"></a>

The tool accepts a large set of options:

## environment

* `-database` `PATH_TO_DATABASE`  - the database to read, default is the last database updated by `make benchmark`, normally `benchmarks.sqlite`
* `-sqlite` `PATH_TO_SQLITE`  - the sqlite3 executable; by default the tool tries to find it either in the LumoSQL build directory or installed on the system
* `-limit` `N`  - limit the output to the most recent `N` runs which match other criteria; the default is 20
* `-import` `FILE`  - instead of using runs in the database, read `FILE` (which must have been created using the `-export` option) into a temporary database, then process the data as normal; if it is desired to import the runs into a permanent database, see the `-copy` option below; multiple files can be specified, for example `-import FILE1 FILE2` or `-import downloads/data.*`

## selecting runs

If more than one selection option is provided, the tool will select runs which match all the criteria; however if the same option is repeated, it selects any which match: so for example `-version N` `-version X` `-backend B` selects all runs with backend `B` which also used saqlite version `N` or `X`.

* `RUN_ID`  - specifying a run ID (which appears as a long hexadecimal string) means that only that run will be processed; if this option is repeated, it select all the runs listed; the option can be
abbreviated to fewer digits, and the program will look up the full ID
* `-option` `NAME-VALUE` - select runs which used the named option and value in the target
* `-missing` `NAME` - select runs which do not have option `NAME` recorded in the database as a target option
* `-datasize` `N` - select runs which used the `datasize` option with value `N`; this is an abbreviation for `option` `datasize-N`; like the `datasize` option, `N` could also be two numbers separated by comma
* `-target` `T` - select runs which used the specified target (same syntax as each element of the `TARGETS` make option)
* `-version` `V` - select runs which used the specified version of sqlite3; this differ from `-target` as the `-version` option can select any backend, while `-target` selects on the full specification of version of sqlite3, backend, options
* `-backend` `B` - select runs which used the specified backend (any version)
* `-backend` `B-V` - select runs which used version `V` of backend `B`
* `-no-backend` - select runs which used an unmodified sqlite (any version, unless `-version` is also secified).
The `-backend` and `-no-backend` options can be combined, and they include anything which matches, so `-backend` `lmdb` `-no-backend` means "select anything with an unmodified sqlite OR the LMDB backend" (but not for example the BDB backend)
* `-failed` - select runs which have failed tests
* `-interrupted` - select runs in which some tests were interrupted by a signal
* `-completed` - select runs in which all tests completed successfully and the run itself recorded an end time
* `-crashed` - select runs which have a start time but not an end time: this usually means that the runs have crashed; however a currently running benchmark will also be selected becauase it does not have an end time yet
* `-empty` - selects runs with no tests; usually combined with `-delete` (see below) to clean up the database
* `-invalid` - select runs which are invalid for some reason, for example they have test data but not information about the run itself, or the sums don't add up; usually combined with `-delete` or `-add` (see below) to clean up the data
* `-cpu-comment` `PATTERN` - select runs whose "cpu comment" matches the
pattern, for example `-cpu-comment` `%amd%` would select all benchmarks
running on an AMD processor, assuming the cpu comment was set appropriately
(or left at the default, and the tool could detect the CPU type); if this
option is repeated, select runs which match any of the patterns
* `-disk-comment` `PATTERN` - select runs whose "disk comment" matches the
pattern, for example `-disk-comment` `%nvme%` would select runs which stored
the databases on an NVME SSD, assuming the disk comment was set appropriately
(or left at the default, and the benchmark could detect the device); if this
option is repeated, select runs which match any of the patterns

## output format

More than one output format option can appear in the command line, and they all apply,
unless specified otherwise

* `-average`  - instead of displaying run details, calculates an average of runs with the same properties and displays that instead (currently unimplemented)
* `-list`  - list the selected runs, one per line, with no information about the single tests; this is the default if there are no selection options
* `-fields` `FIELD[,FIELD]...` - change the fields printed by `-list`, default is
`RUN_ID,TARGET,DATE,TIME,DURATION`; see below for the possible values
* `-summary`  - display a summary of each test in each selected run; this only works if the selected runs have the same tests; cannot be combined with `-details`; this is the default if there are some selection options
* `-quick` - similar to summary, but omits the initial test description and just shows the columns of timings: the column headers show the sqlite/backend combination
* `-details`  - display full details for each test in each selected run including all the information in the database; cannot be combined with `-summary`
* `-column` `WHAT` - what to show in columns, where `WHAT` is one of:
`test`, `benchmark` or `target` (`test` and `benchmark` are considered
equivalent for this option); applies only to `-summary` and `-quick`
* `-tests` `LIST` (or equivalently `-benchmarks` `LIST`) - in the `-summary`
and `-quick` output formats, selects which tests are included, by default
without this option they are all shown; the LIST is a comma-separate list
of test/benchmark numbers, as shown in the normal output, or anything starting
with the letter "t" to include the total run duration; this option is
normally used to make the output narrower when using `-column` `test`
(or the equivalent `-column` `benchmark`)
* `-ignore-numbers` - replace all numbers in test names with "#"; this
allows the `-summary` and `-quick` output to compare tests which differ
only by numbers, for example because they have different data sizes.
* `-export` `FILE`  - write the selected runs to `FILE` in a text format, useful for example to send the run information by email
* `-copy` `DATABASE`  - copies all information about the selected runs to `DATABASE`;
if the database already exists, it must have the same schema and must not already
contain the selected runs (the database will be created if it does not exist)

If no output format options (other than `-average`) are specified, the default is `-list` if there are no specific run selection criteria, `-summary` if there are any criteria.

### list columns

The following entries are valid values for the `-field` option, selecting which
columns are displayed:

* `RUN_ID` or `ID`: the run identifier, a long hexadecimal string which identifies
the run uniquely
* `RUN_ID:abbrev` or `ID:abbrev`: same as `RUN_ID`, but abbreviated to `abbrev`
hexadecimal digits (minimum 8)
* `TARGET`: the encoded target, for example `3.36.0` or `3.36.0+lmdb-0.9.29`;
using this with the build tool allows to repeat the benchmark with exactly the
same options
* `TITLE`: a human-readable version of `TARGET`, for example "sqlite 3.36.0 with
lmdb 0.9.29"
* `SQLITE_NAME`: the output of `sqlite -version`
* `DATE` and `TIME`: a representation of the date or time the run started
* `END_DATE` and `END_TIME`: a representation of the date or time the run
completed, or `-` for runs which did not complete
* `DONE`: "YES" or "NO", depending on whether the run completed or not
* `OK`, `INTR` or `FAIL`: the count of tests which succeeded, were interrupted
or failed with some error, respectively
* `CPU_TYPE` or `ARCH`: the CPU architecture used to run the tests, for example
`x86_64`, `arm` or `s390x`
* `OS_TYPE` or `OS`: the operating system used to run the tests, for example
`Linux` or `NetBSD`
* `CPU_COMMENT` or `CPU`: a user-provided comment intended to describe the
system used for the benchmark; if not provided, it shows as "-"; note that
the benchmark system will try to detect the CPU if the user did not
provide a comment
* `DISK_COMMENT` or `DISK`: a user-provided comment intended to describe the
storage medium used for the databases during the benchmark, or "-" if not provided;
note that the benchmark system will try to detect the storage device
if the user did not provide a ciomment; this doesn't always succeed, so
the column can still show as "-"

## extra actions

* `-add` `NAME=VALUE` - adds some run information, for example to find older benchmark results which did not include the default value for `datasize` and to update them to have it, one could specify: "`-missing datasize -add option-datasize=1`"
* `-delete` - delete the selected runs from the database; it is recommended to run the tool with `-list` instead of `-delete` first, and/or make a copy of the database before running `-delete`

## checking test results

When running tests (as opposed to benchmarks) the build tool will store the results in a different database and the useful data could be different; one can get a summary of test results with:

```
tool/benchmark-filter.tcl -database tests.sqlite -list -fields TARGET,DONE,OK,INTR,FAIL
```

or have complete information about targets with failed tests:

```
tool/benchmark-filter.tcl -database tests.sqlite -details -failed
```

