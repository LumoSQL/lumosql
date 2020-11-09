<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Claudio Calvelli, October 2020 -->


Table of Contents
=================

   * [LumoSQL Build System](#lumosql-build-system)
   * [Obtaining the sources <a name="user-content-obtaining-sources"></a>](#obtaining-the-sources-)
   * [Building the program <a name="user-content-building-program"></a>](#building-the-program-)
   * [Running tests/benchmarks <a name="user-content-running-testsbenchmarks"></a>](#running-testsbenchmarks-)
   * ["make" targets <a name="user-content-make-targets"></a>](#make-targets-)
   * [Adding new backends <a name="user-content-adding-backends"></a>](#adding-new-backends-)

LumoSQL Build System
====================

The LumoSQL project includes code to combine any version of SQLite with any
version of third party storeage backends, and to run tests on the combined
code. This requires small modifications to SQLite itself, and some new code
to interface each backend.

To do this, the project uses the [Not-forking tool](https://lumosql.org/src/not-forking) 
together with appropriate configuration, to obtain the sources, and a set of shell
and Tcl scripts to build and run test programs.

To ensure repeatability of tests, each test will include the following information:
* the version of the "not-forking" configuration used
* the version of sqlite3 used (in one special case building third-party backend code
which provides its own patched version of sqlite3, this will be empty and the
backend name and version will contain information about the third-party code)
* the name of the storage backend used: this is omitted if the test used an
unchanged version of sqlite3 with its own backend
* the version of the storage backend used, also omitted for tests using
an unchanged version of sqlite3
* any other options (currently only `datasize-N` to multiply the data size used
in some benchmarks by `N`)

Three scripts, which can be found in the `tools` subdirectory, handle
the three steps of running a test:
* obtain the sources
* build sqlite3, possibly modified with an alternative storage backend
* run tests

For benchmarking, the third step may run several times to calculate averages.

# Obtaining the sources <a name="obtaining-sources"></a>

The shell script `get-lumo-sources` uses not-forking to download and install
sources; it needs all the versioning information described above and leaves
the sources in a local directory, ready for building and testing. Because
the script uses not-forking, if the sources are already available locally
in the not-forking cache, all download steps can be skipped.

To download unmodified sqlite3 sources call the script with 3 arguments:

```
sh tool/get-lumo-sources SRC_DIR CFG_VERSION LUMO_TARGET
```

`SRC_DIR` specifies a directory where to install the sources:
this will contain a subdirectory `sqlite3` with the actual sources, and
some other files required by the not-forking system and by the LumoSQL
build system. If the directory does not exist, the program will create it;
if it already exists, it must either be empty, or contain sources installed
by a previous run of the program.

`CFG_VERSION` specifies the version of the not-forking configuration to
be used: this ensures that tests can be repeated identically even when
the build system itself is evolving; the special value `test` indicates
that the program will use configuration found in directory `not-fork.d`:
this is useful to run tests based on local, uncommitted modifications of
the configuration.

`LUMO_TARGET` describes the target to download, for example `3.33.0`
for the unmodified sqlite sources, version 3.33.0; or `3.7.17+lmdb-0.9.26`
for sqlite3 version 3.7.17 combined with lmdb backend version 0.9.26.
If a second `+` appears in the target, this is taken to specify more
build options: however this is at present parsed but ignored, for
example in future one could have `3.7.17+lmdb-0.9.26+debug-on` to add
the option `debug` with value `on` to the build; or the same option using
the normal SQLite backend: `3.7.17++debug-on` (note the double `+` to
make sure the option is not interpreted as a backend name).

At present the only backend provided is the `lmdb` backend derived from the
sqlightning sources but modified to work with more versions of lmdb and sqlite3;
however to add new backends see [Adding new backends](#adding-backends) below.

A third backend, based on Oracle's Berkeley DB is in progress; a special target
of `+bdb-VERSION` (without a sqlite3 version) indicates to build the code provided
directy by Oracle, without using the LumoSQL build mechanism.

The backend sources will be in subdirectory `BACKEND_NAME` or the `SRC_DIR`
directory, for example if `SRC_DIR` is `lumo-sources` and the backend is lmdb,
the following directories will be available after running the tool:
`lumo-sources/sqlite3` and `lumo-sources/lmdb`

The `get-lumo-sources` script can take one of the following options to control
downloading of sources:
* `--update` (or `-u`): always check upstream repositories and download any
available updates
* `--no-update` (or `-n`): only check upstream repositories if there is no
cached version in the local cache

If neither option is specified, the program will use the default from the
not-fork configuration. Specifying `--no-update` only works if the required
version is already available locally: if an older version is available, the
program will still omit the update from upstream and will be unable to run;
however for repeated tests on versions already available locally the
`--no-update` option will save time and network activity.

# Building the program <a name="building-program"></a>

After obtaining the sources, and before making any other changes to the sources
directory, call the `build-lumo-backend` script to build a modified sqlite3:

```
sh tool/build-lumo-backend BUILD_DIR/TARGET SRC_DIR
```

`SRC_DIR` is the directory created by `get-lumo-sources` and `BUILD_DIR/TARGET`
is a new directory (it must not already exist, and the program will create it);
note that the last component of this directory must be the same as the target
used with `get-lumo-sources`.

After a successful run, there will be a subdirectory `sqlite3` inside the
destination directory, and that will contain a working sqlite3 with the
backend specified by `TARGET`.

# Running tests/benchmarks <a name="running-testsbenchmarks"></a>

The `benchmark.tcl` script takes a number of command-line arguments to run
a series of tests/benchmarks:

```
tclsh tool/benchmark.tcl BUILD_DIR DATABASE SQLITE_TARGET N_RUNS TARGETS
```

where `BUILD_DIR` is a directory containing a set of built targets (for example
by running `build-lumo-backend` `BUILD_DIR/TARGET` `SRC_DIR` for a number of
different targets, or simply the `build` directory generated by the top-level
Makefile); `DATABASE` is a database where the script will store the test results
and `SQLITE_TARGET` is a subdirectory within `BUILD_DIR` which contains an
unmodified sqlite3: this will be used to write to `DATABASE`; `N_RUNS` is
the number of times each set of tests will run and `TARGETS` is one or more
subdirectories within `BUILD_DIR` to run tests on.

The program will output one line per test summarising the results, for example:

```
   1.094   4 100 SELECTs on a string comparison
```

Shows that test number 4, "100 SELECTs on a string comparison", took just over
1 second to run.

More detailed information will be stored in the database using two tables:
see inside the script for the most current table schema, but table `run_data`
contains information relative to each run (a set of tests on the same target),
such as the target itself, the time the run started, etc; table `test_data`
will contain more detailed information about each test in each run; the
column `run_id` in the two tables connects the information.

A simple (draft) tool to list the runs and provide details of a single run is:

```
tool/benchmark-summary PATH_TO_SQLITE PATH_TO_DATABASE [RUN_ID]
```

where `PATH_TO_SQLITE` can point to either a system-installed sqlite3 or
to the same one inside the build directory which was used to create the
database; `PATH_TO_DATABASE` points to the same `DATABASE` as was provided
to `benchmark.tcl`; if no `RUN_ID` is provided the program prints one line
per run, with the run ID in the first column followed by some other information;
to see the results for a particular run, add the corresponding ID to the command.

# "make" targets <a name="make-targets"></A>

The top-level `Makefile` contains targets to build the required versions of
SQLite and backends, and to run a number of benchmarks.  By default the
`Makefile` sets the (LumoSQL) targets as follows:

* 3.33.0 (latest version of sqlite3 at the time of writing)
* 3.8.3.1 (sqlite3 version used with the LMDB backend)
* 3.18.2 (sqlite3 version used with the BDB backend)
* 3.8.3.1+lmdb-0.9.9 (earliest LMDB version tested)
* 3.8.3.1+lmdb-0.9.16
* 3.8.3.1+lmdb-0.9.27 (latest version of LMDB at the time of writing)
* +bdb-18.1.32 (third-party Berkeley DB code, providing its own sqlite3)

to build all of the above targets, just type:
```
make
```

and to run the corresponding benchmarks, type:
```
make benchmark
```

A number of options can be added to the above `make` commands to change the
default behaviour.

The whole list of (LumoSQL) targets can be replaced with a different one by
adding `TARGETS=...`, for example to benchmark just one version of LMDB and
the corresponding unmodified sqlite3:
```
make benchmark TARGETS='3.8.3.1+lmdb-0.9.27 3.8.3.1'
```
or to just build these targets without running benchmarks:
```
make TARGETS='3.8.3.1+lmdb-0.9.27 3.8.3.1'
```

Leaving `TARGETS` at its default value, it is possible to control how the
Makefile constructs the default value by specifying one or more of the
following options (the value indicated is the current default):

* `SQLITE_VERSION=3.33.0` - the version of sqlite3 to use to update the
benchmarks database; this will also be built and benchmarked by default
* `USE_LMDB=yes` - whether to build/benchmark the LMDB targets
* `SQLITE_FOR_LMDB=3.8.3.1` - the version of sqlite3 to use with the
LMDB backend; this will also be built and benchmarked using the default
(`btree.c`) backend for comparison
* `LMDB_VERSIONS='0.9.9 0.9.16 0.9.27'` - the versions of LMDB to use
* `USE_BDB=yes` - whether to build/benchmark the BDB targets
* `SQLITE_FOR_BDB=3.18.2` - the version of sqlite3 to use with the
BDB backend; this will also be built and benchmarked using the default
(`btree.c`) backend for comparison
* `BDB_VERSIONS=''` - the versions of BDB to use as LumoSQL backends
* `BDB_STANDALONE=18.1.32` - the versions of BDB to use with their own
included sqlite3

A special Makefile target `what` lists the value of these variables and the
resulting TARGETS, for example:

```
make what USE_BDB=no LMDB_VERSIONS='0.9.26 0.9.27'
SQLITE_VERSION=3.33.0
USE_LMDB=yes
SQLITE_FOR_LMDB=3.8.3.1
LMDB_VERSIONS=0.9.26 0.9.27
USE_BDB=no
SQLITE_FOR_BDB=3.18.2
BDB_VERSIONS=
BDB_STANDALONE=18.1.32
TARGETS=
    3.33.0
    3.8.3.1
    3.8.3.1+lmdb-0.9.26
    3.8.3.1+lmdb-0.9.27
```

or to check the defaults:
```
SQLITE_VERSION=3.33.0
USE_LMDB=yes
SQLITE_FOR_LMDB=3.8.3.1
LMDB_VERSIONS=0.9.9 0.9.16 0.9.27
USE_BDB=yes
SQLITE_FOR_BDB=3.18.2
BDB_VERSIONS=
BDB_STANDALONE=18.1.32
TARGETS=
    3.33.0
    3.8.3.1
    3.18.2
    3.8.3.1+lmdb-0.9.9
    3.8.3.1+lmdb-0.9.16
    3.8.3.1+lmdb-0.9.27
    +bdb-18.1.32
```

More `make` options to control other aspects of the benchmarking than the list
of targets:

* `BENCHMARK_DB=benchmarks.sqlite` - SQLite database which will contain the results
* `BENCHMARK_RUNS=1` - number of times to repeat each benchmark run

# Adding new backends <a name="adding-backends"></a>

To add new backends, create a new directory inside `not-fork.d` (or inside the
appropriate not-forking configuration repository) with the same name as the
backend, and add information about how to obtain the sources etc. At a minimum
the directory will contain the following files:

* `upstream.conf`: information about where to find the sources
* `lumo-new-files.mod`: a list of new files to be installed to link the
backend with sqlite3: see an existing backend for a quick example, or
read the more comprehensive documentation below
* `files/FILENAME`: every file mentioned in `lumo-new-files.mod` needs
to be provided in the `files/` directory

The build process requires the backend to provide the following two files
(in directory `.lumosql`), which means that `lumo-new-files.mod` or some
other file in the not-forking configuration must install them:

* `lumo.mk` is a Makefile fragment which will be inserted into the sqlite3
build process, for example to link against the backend
* `lumo.build` is a shell script to build the backend

The LumoSQL build system modifies sqlite3 to replace some of its own files
with a stub, which used the C preprocessor's `#include` directive to read
the original file. It also sets the include search path so that it looks
first in a subdirectory `.lumosql/backend` of the backend's sources, and
if not found there in the original sqlite3 sources. To avoid file name
collision, all such files will be prefixed with `lumo_`

Therefore, to replace one of these sqlite3 files with a new one the backend
will need to have a line in `lumo-new-files.mod` to specify a new file with
the appropriate name in `.lumosql/backend`, and also add this file in the
`files` directory.

For example, to replace `btree.c` with a new one (probably something to call
the new backend using its own API rather than the original `btree.c` from
sqlite3), one would have the following:

File `lumo-new-files.mod`:
```
method = replace
--
# files required by the LumoSQL build system
.lumosql/lumo.mk                 =  files/lumo.mk
.lumosql/lumo.build              =  files/lumo.build

# files we replace
.lumosql/backend/lumo_btree.c    =  files/btree.c
```

Then file `files/btree.c` would contain the new version, and file `files/lumo.mk`
would provide information on how to link the backend with sqlite3, for example:

```
TCC += -I$(LUMO_SOURCES)/$(LUMO_BACKEND)/include
TLIBS += -L$(LUMO_BUILD)/$(LUMO_BACKEND)
TLIBS += -lmy_backend
```

would add the `include` subdirectory in the backend's sources to the search
path when building sqlite3 (probably because the replaced `btree.c` needs
to include something from there), and also add the `build` directory in the
backend's sources as library search path; finally it asks to link `libmy_backend.so`
or `libmy_backend.a` into the sqlite3 executable, probably finding it in
the build directory just added to the library search path.

Finally, `files/lumo.build` could be something like:

```
echo "Configuring $LUMO_BACKEND_NAME $LUMO_BACKEND_VERSION"
"$LUMO_SOURCES/$LUMO_BACKEND_NAME"/libraries/liblmdb/configure || exit 1

echo "Building $LUMO_BACKEND_NAME $LUMO_BACKEND_VERSION"
make || exit 1

exit 0
```

