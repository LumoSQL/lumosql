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
RUN_ID                                                           TARGET                         DATE       TIME        DURATION
C0F2921BFD5AAC134CB4B31FE53F7950601DA1196221605C0E02F41E516AAC41 3.33.0                         2020-11-09 19:44:03      47.659
1172AD2F87424F2494A6E82DB22AE5C17E64452F93398B52200AED737CCCF51B 3.8.3.1                        2020-11-09 19:45:05      83.234
B8CBCD38F5BC3CAD3C1B72BF023753C137704A894046D926D71FF8B449A3C29C 3.18.2                         2020-11-09 19:46:43      50.252
B417153A7A9A8FC15A480A2F40EBE31C5A96406806D9584F93BCA14D78688805 3.8.3.1+lmdb-0.9.9             2020-11-09 19:47:48     102.819
A3E8FA72D737F1CCE5A7AA5431E4719D18ED25F9A4D7E95CB2BB8EC077AE07B6 3.8.3.1+lmdb-0.9.16            2020-11-09 19:49:45     104.092
6AEEEA5A5685EA80F1F4EDD15447F10E75285AD79A9D8A7F1F02317F17BEEEFF 3.8.3.1+lmdb-0.9.27            2020-11-09 19:51:44     120.463
5007318ED97028B5146A40A5BD9610789BE860FA7CA093150DC91B038F868047 +bdb-18.1.32                   2020-11-09 19:53:58     158.610
551874CA168577E445AB1BFE529707EE66E0C2240A3E4A1FDBEB36D72419FED6 3.33.0++datasize-2             2020-11-09 20:01:43     219.784
0EEB6EDE567986614716BB9B808705EB1908564E772FC1BFAB697202469B5EA3 3.8.3.1++datasize-2            2020-11-09 20:05:38     586.173
B39C44483D5624CA18FDA0AA6CADD761FE278395CDE70BC8CCE02FB0E00CB31C 3.18.2++datasize-2             2020-11-09 20:15:39     232.850
94E314C7DD515329494AA1B24B2E0FBE051880E6B384851D6A1445B9202F4A04 3.8.3.1+lmdb-0.9.9+datasize-2  2020-11-09 20:19:46     397.557
0EBFC2702D09B9982910DA5AE58BC68E0B0E36E420D07FD34C2C128562C44507 3.8.3.1+lmdb-0.9.16+datasize-2 2020-11-09 20:26:38     399.982
0E9D1D3A7F24ACCC473E9BA954A764935A6E9B9C7A227280C691B6EAE1DE3112 3.8.3.1+lmdb-0.9.27+datasize-2 2020-11-09 20:33:33     495.898
A7404A82A96542A8142B8B923CD88210E2B4F3C5608262D3C32AE97DDE3730A4 +bdb-18.1.32+datasize-2        2020-11-09 20:42:04     602.777
```

To display one or more results, add the run IDs to the command, for example:
```
tclsh tool/benchmark-filter.tcl 1172AD2F87424F2494A6E82DB22AE5C17E64452F93398B52200AED737CCCF51B
Benchmark: sqlite 3.8.3.1
   Target: 3.8.3.1
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e)
   Ran at: 2020-11-09 19:45:05
 Duration: 83.234

       TIME TEST NAME
      0.081    1 1000 INSERTs
      0.111    2 25000 INSERTs in a transaction
      0.250    3 100 SELECTs without an index
      0.800    4 100 SELECTs on a string comparison
      9.095    5 5000 SELECTs
      0.092    6 1000 UPDATEs without an index
     36.143    7 25000 UPDATEs with an index
     36.335    8 25000 text UPDATEs with an index
      0.048    9 INSERTs from a SELECT
      0.096   10 DELETE without an index
      0.060   11 DELETE with an index
      0.043   12 A big INSERT after a big DELETE
      0.045   13 A big DELETE followed by many small INSERTs
      0.035   14 DROP TABLE
```

or:
```
tclsh tool/benchmark-filter.tcl 1172AD2F87424F2494A6E82DB22AE5C17E64452F93398B52200AED737CCCF51B B417153A7A9A8FC15A480A2F40EBE31C5A96406806D9584F93BCA14D78688805 A3E8FA72D737F1CCE5A7AA5431E4719D18ED25F9A4D7E95CB2BB8EC077AE07B6 6AEEEA5A5685EA80F1F4EDD15447F10E75285AD79A9D8A7F1F02317F17BEEEFF
Column 1
Benchmark: sqlite 3.8.3.1
   Target: 3.8.3.1
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e)
   Ran at: 2020-11-09 19:45:05
 Duration: 83.234

Column 2
Benchmark: sqlite 3.8.3.1 with lmdb 0.9.9
   Target: 3.8.3.1+lmdb-0.9.9
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e lmdb 0.9.9 7449ca604ca732ad262cfd77da403968cdb9157f)
   Ran at: 2020-11-09 19:47:48
 Duration: 102.819

Column 3
Benchmark: sqlite 3.8.3.1 with lmdb 0.9.16
   Target: 3.8.3.1+lmdb-0.9.16
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e lmdb 0.9.16 5d67c6aed16366ddcfac77eb6a166928a257ab7b)
   Ran at: 2020-11-09 19:49:45
 Duration: 104.092

Column 4
Benchmark: sqlite 3.8.3.1 with lmdb 0.9.27
   Target: 3.8.3.1+lmdb-0.9.27
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e lmdb 0.9.27 3c9aa9df8497ad977e0f91347f0626f5d53c9ab7)
   Ran at: 2020-11-09 19:51:44
 Duration: 120.463

----------------------TIME---------------------
          1           2           3           4 TEST NAME
      0.081       0.060       0.041       0.061    1 1000 INSERTs
      0.111       3.738       3.739       3.846    2 25000 INSERTs in a transaction
      0.250       0.284       0.305       0.288    3 100 SELECTs without an index
      0.800       0.845       0.833       0.841    4 100 SELECTs on a string comparison
      9.095      11.872      12.190      12.032    5 5000 SELECTs
      0.092       0.117       0.117       0.120    6 1000 UPDATEs without an index
     36.143      45.519      45.961      61.285    7 25000 UPDATEs with an index
     36.335      40.099      40.634      41.722    8 25000 text UPDATEs with an index
      0.048       0.041       0.041       0.042    9 INSERTs from a SELECT
      0.096       0.036       0.036       0.037   10 DELETE without an index
      0.060       0.035       0.035       0.035   11 DELETE with an index
      0.043       0.037       0.038       0.039   12 A big INSERT after a big DELETE
      0.045       0.106       0.089       0.086   13 A big DELETE followed by many small INSERTs
      0.035       0.031       0.031       0.030   14 DROP TABLE
```

Note that only "like-for-like" can be compared, the tests with the "datasize 1" option
differ from the tests with "datasize 2" and the tool will not show these side by side.

This result can also be obtained by selecting runs by their properties, in this
case they all had the SQLite version (3.8.3.1) and datasize (1) in common, so:
```
tclsh tool/benchmark-filter.tcl -version 3.8.3.1 -datasize 1
Column 1
Benchmark: sqlite 3.8.3.1
   Target: 3.8.3.1
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e)
   Ran at: 2020-11-09 19:45:05
 Duration: 83.234
... (same output as previous example)
```

Or to compare all LMDB results with datasize 2:
```
tclsh tool/benchmark-filter.tcl -backend lmdb -datasize 2
Column 1
Benchmark: sqlite 3.8.3.1 with lmdb 0.9.9
   Target: 3.8.3.1+lmdb-0.9.9+datasize-2
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e lmdb 0.9.9 7449ca604ca732ad262cfd77da403968cdb9157f)
   Ran at: 2020-11-09 20:19:46
 Duration: 397.557

Column 2
Benchmark: sqlite 3.8.3.1 with lmdb 0.9.16
   Target: 3.8.3.1+lmdb-0.9.16+datasize-2
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e lmdb 0.9.16 5d67c6aed16366ddcfac77eb6a166928a257ab7b)
   Ran at: 2020-11-09 20:26:38
 Duration: 399.982

Column 3
Benchmark: sqlite 3.8.3.1 with lmdb 0.9.27
   Target: 3.8.3.1+lmdb-0.9.27+datasize-2
          (3.8.3.1 2014-02-11 14:52:19 ea3317a4803d71d88183b29f1d3086f46d68a00e lmdb 0.9.27 3c9aa9df8497ad977e0f91347f0626f5d53c9ab7)
   Ran at: 2020-11-09 20:33:33
 Duration: 495.898

----------------TIME---------------
          1           2           3 TEST NAME
      0.054       0.053       0.053    1 2000 INSERTs
     28.599      28.873      28.673    2 50000 INSERTs in a transaction
      0.534       0.536       0.543    3 100 SELECTs without an index
      1.638       1.642       1.676    4 100 SELECTs on a string comparison
     23.471      23.250      23.743    5 5000 SELECTs
      0.371       0.372       0.377    6 2000 UPDATEs without an index
    182.030     183.032     273.891    7 50000 UPDATEs with an index
    160.538     161.908     166.624    8 50000 text UPDATEs with an index
      0.055       0.055       0.057    9 INSERTs from a SELECT
      0.042       0.041       0.059   10 DELETE without an index
      0.040       0.039       0.040   11 DELETE with an index
      0.046       0.063       0.047   12 A big INSERT after a big DELETE
      0.108       0.088       0.086   13 A big DELETE followed by many small INSERTs
      0.031       0.031       0.030   14 DROP TABLE
```

# Full set of options <a name="full-set-of-options"></a>

The tool accepts a large set of options:

## environment

* `-database` `PATH_TO_DATABASE`  - the database to read, default is `benchmarks.sqlite` (the database produced by the benchmark tool)
* `-sqlite` `PATH_TO_SQLITE`  - the sqlite3 executable; by default the tool tries to find it either in the LumoSQL build directory or installed on the system
* `-limit` `N`  - limit the output to the most recent `N` runs which match other criteria; the default is 20
* `-import` `FILE`  - instead of using runs in the database, read `FILE` (which must have been created using the `-export` option) into a temporary database, then process the data as normal; if it is desired to import the runs into a permanent database, see the `-copy` option below

## selecting runs

If more than one selection option is provided, the tool will select runs which match all the criteria; however if the same option is repeated, it selects any which match: so for example `-version N` `-version X` `-backend B` selects all runs with backend `B` which also used saqlite version `N` or `X`.

* `RUN_ID`  - specifying a run ID (which appears as a long hexadecimal string) means that only that run will be processed; if this option is repeated, it select all the runs listed
* `-option` `NAME-VALUE` - select runs which used the named option and value in the target
* `-missing` `NAME` - select runs which do not have option `NAME` recorded in the database as a target option
* `-datasize` `N` - select runs which used the `datasize` option with value `N`; this is an abbreviation for `option` `datasize-N`
* `-target` `T` - select runs which used the specified target (same syntax as each element of the `TARGETS` make option)
* `-version` `V` - select runs which used the specified version of sqlite3; this differ from `-target` as the `-version` option can select any backend, while `-target` selects on the full specification of version of sqlite3, backend, options
* `-backend` `B` - select runs which used the specified backend (any version)
* `-backend` `B-V` - select runs which used version `V` of backend `B`
* `-failed` - select runs which have failed tests
* `-interrupted` - select runs in which some tests were interrupted by a signal
* `-completed` - select runs in which all tests completed successfully and the run itself recorded an end time
* `-crashed` - select runs which have a start time but not an end time: this usually means that the runs have crashed; however a currently running benchmark will also be selected becauase it does not have an end time yet
* `-empty` - selects runs with no tests; usually combined with `-delete` (see below) to clean up the database
* `-invalid` - select runs which are invalid for some reason, for example they have test data but not information about the run itself, or the sums don't add up; usually combined with `-delete` or `-add` (see below) to clean up the data

## output format

More than one output format option can appear in the command line, and they all apply,
unless specified otherwise

* `-average`  - instead of displaying run details, calculates an average of runs with the same properties and displays that instead (currently unimplemented)
* `-list`  - list the selected runs, one per line, with no information about the single tests
* `-summary`  - display a summary of each test in each selected run; this only works if the selected runs have the same tests; cannot be combined with `-details`
* `-details`  - display full details for each test in each selected run including all the information in the database; cannot be combined with `-summary`
* `-export` `FILE`  - write the selected runs to `FILE` in a text format, useful for example to send the run information by email
* `-copy` `DATABASE`  - copies all information about the selected runs to `DATABASE` which must already exist, have the same schema as the benchmarks database, and must not already contain the same runs

If no output format options (other than `-average`) are specified, the default is `-list` if there are no specific run selection criteria, `-summary` if there are any criteria.

## extra actions

* `-add` `NAME=VALUE` - adds some run information, for example to find older benchmark results which did not include the default value for `datasize` and to update them to have it, one could specify: "`-missing datasize -add option-datasize=1`"
* `-delete` - delete the selected runs from the database; it is recommended to run the tool with `-list` instead of `-delete` first, and/or make a copy of the database before running `-delete`

