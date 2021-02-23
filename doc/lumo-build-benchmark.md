<!-- Copyright 2020 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Claudio Calvelli, December 2020 -->

# LumoSQL Build and Benchmark System

[LumoSQL](https://lumosql.org) implements a meta-build system for SQLite, using
the [Not-Forking tool](https://lumosql.org/src/not-forking) to handle many of
the complexities so we can build a matrix of combined codebases and versions
without having a mess of code specific to particular source trees.

But once a binary is built, how can we know if our changes to SQLite make a difference, and
what kind of difference? There was no standard way to compare software that
implements the SQLite APIs, so we designed one.

The LumoSQL Build and Benchmark System is relevant to all SQLite users wishing
to compare different configurations and versions of standard SQLite.  In
addition, the LumoSQL project includes code to combine any version of SQLite
with any version of third party storeage backends, and to run tests on the
combined code. This requires small modifications to SQLite itself, and some new
code to interface each backend.

# Questions The Build and Benchmark System Answers

A single command can now give universal, repeatable, definitive answers to the
following seemingly-simple questions:

* How can benchmarking runs be shared in a consistent manner between all users?
  ***(hint: use a standardised SQLite database)***
* Does SQLite get faster with each version? ***(hint: not always)***
* Which compile options make a given version of SQLite faster?
* How do different versions and compile options combine to change performance as
  data size gets larger?
* Does SQLITE\_DEBUG really make
[SQLite run approximately three times slower?](https://sqlite.org/compile.html)
* What happens when a given set of compile options, versions and data size are
  tested on faster and slower disks?
* Do I need to run hundreds of combinations to make decisions about SQLite versions/options/hardware?
  ***(hint: no, because you now can compare benchmarking results databases)***

Having addressed the above questions, the following seemingly more-difficult questions
now become very similar to the previous ones:

* What happens to performance when LMDB is swapped in as a storage backend for SQLite?
  ***(hint: there is a strange performance curve with increasing LMDB versions)***
* How does the Oracle-funded BDB backend compare with other backends, including the
  SQLite Btree? ***(hint: Oracle seems to have thought longer runtimes are better :-)***
* How do all of the above compare with each other with different build options,
  versions and datasizes? ***(hint: now can share benchmarking results, we can take
  advantage of thousands of CPU-hours from other people)***

The rest of this document introduces and defines the benchmarking tool that 
makes answering these questions possible. 

## Build and benchmark problem statement

Motivation: LumoSQL has established that there is currently no way of comparing
like-for-like SQLite-related databases. 

Test matrix: LumoSQL consists of multiple source trees from multiple sources,
assembled with the assistance of the not-forking tool. These trees represent a
matrix with a very large number of dimensions.  The dimensions include among
other things: the combination of these source trees; their build process; their
invocation parameters; their input data; and the running environment.

Example instances of these dimensions are:

* SQLite version 1 combined with LMDB version 2, to make combined source object A
* Combined source object A can be compiled with `-DSQLITE_DEBUG`, and also 
  `-D MDB_MAXKEYSIZE` (which only applies to LMDB). That will give two build
  objects to test, call them binary objects B and C.
* Each of binary objects B and C can be tested with large data files, and
  many small files. 
* Each of the above tests can be run in an environment with large amounts of
  memory, or with deliberate memory constraints.
* All of the above can then be repeated only with different versions of SQLite
  and LMDB
* ... and then we move on to the different versions of pure SQLite, and SQLite
  combined with Berkeley DB, etc.

***Problem statement:***

> The LumoSQL Build and Benchmark system solves the problem of defining the
dimensions of the test matrix in a formal machine-friendly manner, and 
presenting them to the user in a human-friendly manner.
> The user can then select some or all of these dimensions by human-readable
name, and then cause them to be actioned. Every selection by the user will have
multiple dependency actions.

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

Where the user has requested average results, the tests may be run several times.

# Build and benchmark options

## Build and Benchmark configuration

A special subdirectory `benchmark` in `not-fork.d/NAME` contain files to
control the build and benchmark process for backend `NAME` (`NAME` can be
`sqlite3` to control the process for all backends and/or for the unmodified
sqlite3). There must be at least one of the following files in each of those
directories:

* `versions` - contains a list of versions of `NAME` to build/benchmark by
default, one version per line; if `NAME` is a backend (as opposed to `sqlite3`)
the version line can have two special formats: `=VERSION` specified which
version of sqlite3 to use with this backend; and `SQLITE_VERSION+BACKEND_VERSION`
specifies the two versions explicitely for a particular build; a line containing
just a version number will use the default specified with `=VERSION`; the
file `not-fork.d/lmdb/benchmarking/versions` contains some examples.

* `standalone` - for backends which contain their own sqlite3 sources,
possibly modified, this file specifies to build/benchmark these rather
than build the backend and then link it to an "official" sqlite3.
Each line contains two version numbers, separated by space: the version
of the backend itself, and the version of sqlite3 that it includes these
are expected to include their own sqlite3, and they are built using that;
the file `not-fork.d/bdb/benchmarking/standalone` shows how to use this
for the BDB backend.

The remaining files in these directories specify build/benchmark options and
code to run to produce benchmarks; the code will be documented in another
section.

File names matching the pattern `*.option` specify options which are
relevant to building and/or benchmarking `NAME`. Each file corresponds
to a single option (the file name with the `.option` suffix removed must
be the same as the option name). Each file contains lines of the form
`key=value` (or `key` only) with the following keys defined at present:

* `build` - does the option affects the build process? (value `yes` or `no`,
default `no`)
* `default` - default value for the option, if not specified
* `equiv` - a list of values (separated by a comma) which are considered
equivalent; the first value is the one used to form internal target strings
* `syntax` - regular expression defining the valid syntax for the option;
default is to accept any string of alphanumeric characters; note that the
expression is anchored, i.e. it must match the whole string
* `numeric` - abbreviation for `syntax=0|-?[1-9]\d*`, accept only (integer) numeric
values (without leading zeros); this key has no value
* `positive` - abbreviation for `syntax=[1-9]\d*`, accept only (integer) positive
numeric values (without leading zeros); this key has no value
* `boolean` - abbreviation for `syntax=on|off|true|false`, `equiv=on,true`
and `equiv=off,false`; this key has no value
* `enum` - followed by a comma-separated list of values, abbreviation for
`syntax=value1|value2|...|valuen` i.e. accept only values from the list

For example, `not-fork.d/sqlite3/options/datasize.option` contains information
about the `datasize` benchmark option:

```
build = no
default = 1
positive
```

Options which affect the build must be known to the `lumo.build` script and/or
to the `lumo.mk` Makefile fragment to be effective; these files are installed
by the not-forking configuration and control the build process.

Options which affect the benchmark must be implemented by one or more of the
tests actually ran, for example by changing data sizes or using `PRAGMA`
statements; the `tool/build.tcl` tries to know as little as possible about
what is being done, to help using the framework for other systems.

Usually options which affect the benchmarking but not the build will be
present in `not-fork.d/sqlite3/options` only but will apply to all benchmarks,
no matter which backend they use. Options which affect the build could be
in any directory; currently there is no mechanism to address the case of the
same option is present in multiple directories, and it is undefined which
one will take precedence.

## Backends as of LumoSQL 0.4

At present the only backend provided is the `lmdb` backend derived from the
sqlightning sources but modified to work with more versions of lmdb and sqlite3;
however to add new backends see [Adding new backends](#adding-backends) below.

A third backend, based on Oracle's Berkeley DB is in progress; a special target
of `+bdb-VERSION` (without a sqlite3 version) indicates to build the code provided
directy by Oracle, without using the LumoSQL build mechanism.

## Specifying build/benchmark options to "make"

The Makefile has a mechanism to recognise build/benchmark options as command-line
option with the form `OPTION=value` where `OPTION` is the name of an option
translated to be in all capital letters; the name can also be prefixes with
the string `OPTION_` in case there is a name clash with other existing Makefile
options: for example, if `datasize` is defined as the above example, the following
two commands are equivalent and will set this option to the value 2:

```
make benchmark DATASIZE=2
make benchmark OPTION_DATASIZE=2
```

Options which affect the build may cause a rebuild of the objects; options which
only change the benchmark parameters can reuse an older build if available.

These options are in addition to the existing Makefile mechanism to generate
a list of targets, using the (previously documented) variables `USE_backend`,
`backend_VERSIONS`, etc:

* `SQLITE_VERSIONS=list` - build and benchmark the specified versions instead
of the default; the first version in the list will also be used to update
the benchmark result database (if a backend is built, the corresponding
unmodified version of sqlite is also added to this list, so the benchmark
can compare them)
* `USE_SQLITE=yes` - build and benchmark an unmodified sqlite3: this is the
default
* `USE_SQLITE=no` - do not build/benchmark an unmodified sqlite3; however the
version which will be used to store the benchmark results in a database will
always be built if necessary
* `USE_backend=yes` - include `backend` in the build/benchmark; this is the default
* `USE_backend=no` - do not include `backend` in the build/benchmark
* `SQLITE_FOR_backend=version` - version of sqlite3 to use when building a
backend if the backend version does not specify one
* `backend_VERSIONS=list` - replace the default list of versions to build; these
can be a single version, the backend version, or two versions separated by a "+",
the sqlite3 version and the backend version, respectively; the unmodified
sqlite3 will also be added to the benchmark, for comparison; if `list` is just
the word `all`, then all known versions are benchmarked
* `backend_STANDALONE=list` - if a backend includes its own version of sqlite3,
then build that instead of linking against an official one; the version can be
a single version, or two versions separated by `=`, which will be the backend
version and the version of sqlite3 it will build, respectively; the sqlite3
version is not used by the build process as it expects the backend to do what is
necessary, however if known it will be added to the benchmarks for comparison;
if `list` is just the word `all`, then all known versions are benchmarked
* `BENCHMARK_DB=filename` - where to store benchmark results, default is
`benchmarks.sqlite`
* `BENCHMARK_RUNS=number` - how many times to repeat each benchmark, default 1.

Alternatively, `TARGETS` can be specified to override all the makefile mechanism
and build/benchmark a specific combination of options only, as explained in
the next section.

Some options are provided to control the use of the not-forking tool:

* `NOTFORK_COMMAND=path` (default: look for `not-fork` in `$PATH`): the
name of the not-forking tool
* `NOTFORK_UPDATE=number` (default: 0): if nonzero, it will pass `--update`
the first time the not-forking tool is called with a particular repository;
this could be necessary if the defaults have been set to `--no-update`
and the cached copy of the repository is older than the version required.
* `NOTFORK_ONLINE=number` (default: 0): if nonzero, it will pass `--online`
to the not-forking tool; this could be necessary if the defaults have been
set to `--offline` and the operation cannot be completed with cached data.

## Encoding options in the target name

The target name is used internally by the benchmark system to determine if two
benchmarks are for similar things and can be compared; in general, two benchmarks
are comparable if they have the same build and benchmark options; to simplify
this decision, the options are encoded in the target name using the syntax:
`sqlite3version+[backendname-backendversion]+option-value[+option-value]...`
the options are always listed in lexycographic order, and default options are
omitted, so that if two string differ then the options differ.  This is an
internal representation, however it appears in the "target" field of the benchmark
database, and can be specified directly to make to repeat just a particular
benchmark without specifying all the options separately.

## Specifying build options to the build and benchmark tools

The various tools provided by previous versions of LumoSQL have been merged
into a single tool, `tool/build.tcl`, which guarantees identical parsing of
configuration and options in all stages of the process; the Makefile arranges
to call this tool as appropriate, but it can be called manually using the
syntax:

```
tclsh tool/build.tcl OPERATION NOTFORK_CONFIG ARGUMENTS
```

The `NOTFORK_CONFIG` is usually the not-fork.d directory provided with
LumoSQL; the `OPERATION` specifies what to do, and the `ARGUMENTS`
depend on the operation specified; the following `OPERATIONs` are
defined:

* `options` - creates a Makefile fragment to instruct `make` to accept
the command-line options described elsewhere in this document; this
is provided with LumoSQL in file `Makefile.options` but may need to be
regenerated if the configuration changes; `ARGUMENTS` contains just the
name of the file to write.

* `build` - builds all necessary binaries so that a benchmark can run;
the `ARGUMENTS` are of the form `-OPTION=VALUE` to set options specified
by an `*.options` file, or `OPTION=VALUE` for other options (such as
`USE_backend` and `TARGETS`); if the `VALUE` contains spaces or other
characters which may be special to the shell it will need to be quoted.

* `database` - creates a database to store benchmark results; this will
also be done automatically if required before running benchmarks;
`ARGUMENTS` contains just the database file name.

* `benchmark` - runs all benchmarks taking into account applicable options;
`ARGUMENTS`  is the same as for `build`.

* `what` - outputs a description of what it would be built and benchmarked
as well as the values of any options; `ARGUMENTS` is the same as for `build`
and `benchmark` and if present will modify the output as appropriate.

Note that apart from the slightly different syntax, build/benchmark options
are specified in the same way as standard `Makefile` arguments.

For example, to build two versions of plain sqlite3, two versions of sqlite3+LMDB
and one version of BDB with its own sqlite3:

```
tclsh tool/build.tcl build not-fork.d \
      SQLITE3_VERSION='3.14.15 3.33.0' \
      USE_LMDB=yes LMDB_VERSIONS='0.9.9 0.9.27' SQLITE_FOR_LMDB=3.8.0 \
      USE_BDB=yes BDB_STANDALONE='18.1.32'
```

To do the same build as above but specifying the target strings directly:

```
tclsh tool/build.tcl build not-fork.d \
      TARGETS='3.14.15 3.33.0 3.8.0+lmdb-0.9.9 3.8.0+lmdb-0.9.27 +bdb-18.1.32'
```

To add option `debug=on` to the build:

```
tclsh tool/build.tcl build not-fork.d \
      SQLITE3_VERSION='3.14.15 3.33.0' \
      USE_LMDB=yes LMDB_VERSIONS='0.9.9 0.9.27' SQLITE_FOR_LMDB=3.8.0 \
      USE_BDB=yes BDB_STANDALONE='18.1.32' \
      -DEBUG=on
```

or, with an explicit list of targets:

```
tclsh tool/build.tcl build not-fork.d \
      TARGETS='3.14.15++debug-on 3.33.0++debug-on \
      3.8.0+lmdb-0.9.9+debug-on 3.8.0+lmdb-0.9.27+debug-on \
      +bdb-18.1.32+debug-on'
```

To run the benchmarks rather just building the targets, replace `build` with
`benchmark`, for example:

```
tclsh tool/build.tcl benchmark not-fork.d \
      SQLITE3_VERSION='3.14.15 3.33.0' \
      USE_LMDB=yes LMDB_VERSIONS='0.9.9 0.9.27' SQLITE_FOR_LMDB=3.8.0 \
      USE_BDB=yes BDB_STANDALONE='18.1.32'
```

The first version of sqlite3 provided (in this case 3.14.15) will be used to
update the benchmark results database.

# What tests will run

Each test is composed of three lists of SQL statements, the "before" list
prepares the environment for the test, then the test itself runs and the
time it takes is logged, finally the "after" list can do any necessary
cleanup.  Two special files in `not-fork.d/sqlite3/benchmark` can provide
common "before" and "after" code which will be included in every test;
these files must have names `before-test` and `after-test` respectively.

Files matching the pattern `*.test` in directory `not-fork.d/sqlite3/benchmark`
contain the individual tests: the benchmark will read these files in lexycographic
order to decide which tests to run and in which order; for each test, the
contents of `before-test`, the test itself, and `after-test` are concatenated
and the result interpreted as TCL code; it is expected that this TCL code
sets the variable `name` to contain the name of the text, and also appends
SQL statements to three variables: `before_sql`, `sql` and `after_sql`:
these SQL statements will then be executed in the order listed, but only
the middle (`sql`) one is timed, so that setup and cleanup code does not
count towards the benchmarking.

This TCL code can access a number of variables from the `build.tcl` script,
in particular the array `options` contains the build and benchmark options;
test; each file is a fragment of TCL expected to set two variables: `name`
which is the name of the test, and `sql` which is the SQL to be executed;
the fragment can access the array `options` to determine the build and
benchmark options; examples are provided in the LumoSQL configuration to
specify the default set of tests, we show here an example from one of the tests:

```
set d25000 [expr $options(DATASIZE) * 25000]
set name "$d25000 INSERTs in a transaction"

append sql "BEGIN;\n"
append sql "CREATE TABLE t2(a INTEGER, b INTEGER, c VARCHAR(100));\n"
for {set i 1} {$i<=$d25000} {incr i} {
  set r [expr {int(rand()*500000)}]
  append sql "INSERT INTO t2 VALUES($i,$r,'[number_name $r]');\n"
}
append sql "COMMIT;\n"
```

This corresponds to the old "25000 INSERTs in a transaction" except that it now
multiplies the number of inserts by the `DATASIZE` option; so it first uses
`$options(DATASIZE)` to calculate the number of inserts, then sets the test
name accordinly and generates the SQL.

When running the benchmark, the program will measure just the time required to
run the appropriate version of sqlite3/backend on the sql generated by each
test.

At present, tests must be specified in the `sqlite3` directory and not a backend
one: this is so that we run the same tests for unmodified sqlite3 as we do for
the one modified by a backend, to guarantee a meaningful comparison.

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
* at least one of `benchmark/versions` and `benchmark/standalone`; the
former includes versions of the backend to build and link against a
"standard" sqlite, as well as specifying which versions of sqlite are
compatible with that; the latter specifies versions to build using an
included sqlite3; see the existing `versions` for LMDB and `standalone`
for BDB as examples

The build process requires the backend to provide the following two files
(in directory `.lumosql`), which means that `lumo-new-files.mod` or some
other file in the not-forking configuration must install them:

* `lumo.mk` is a Makefile fragment which will be inserted into the sqlite3
build process, for example to link against the backend
* `lumo.build` is a TCL script to build the backend; it has access to
various variables set by the build process; it needs to copy or move the
build result to `$lumo_dir/build`

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

`files/lumo.build` could be something like:

```
global backend_name
global backend_version
global build_options

puts "Configuring $backend_name $backend_version"
if {$build_options(DEBUG) eq "on"} {
    system ./configure --enable-debug
} else {
    system ./configure --disable-debug
}

puts "Building $backend_name $backend_version"
system make

# now move files of interest to lumo/build
global lumo_dir
set dest [file join $lumo_dir build]
if {! [file isdirectory $dest]} { file mkdir $dest }
file rename mybackend.h $dest
foreach fn [glob liblmybackend.*] {
    file rename $fn $dest
}
```

