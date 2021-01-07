# LumoSQL Build and Benchmark System

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

## Problem statement

The LumoSQL Build and Benchmark system solves the problem of defining the
dimensions of the test matrix in a formal machine-friendly manner, and 
presenting them to the user in a human-friendly manner.

The user can then select some or all of these dimensions by human-readable
name, and then cause them to be actioned. Every selected by the user will have
multiple dependency actions.

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

Options which affect the benchmark must be known to the benchmark code inside
`tool/build.tcl` and they affect the way the executable is called and/or the
data used for the tests.

Usually options which affect the benchmarking but not the build will be
present in `not-fork.d/sqlite3/options` only but will apply to all benchmarks,
no matter which backend they use. Options which affect the build could be
in any directory; currently there is no mechanism to address the case of the
same option is present in multiple directories, and it is undefined which
one will take precedence.

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

* `SQLITE_VERSION=list` - build and benchmark the specified versions instead
of the default
* `SQLITE_EXTRA=list` - same as `SQLITE_VERSION` but this list will be added
to the default rather than replacing it
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

* `what` - outputs a ddescription of what it would be built and benchmarked
as well as the values of any options; `ARGUMENTS` is the same as for `build`
and `benchmark` and if present will modify the output as appropriate.

Note that apart from the slightly different syntax, build/benchmark options
are specified in the same way as Makefile arguments.

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

The directory `not-fork.d/sqlite3/benchmark` can contain files matching the
pattern `*.test` to specify what will be run: the benchmark will read these
files in lexycographic order, and measure the time it takes to run each
test; each file is a fragment of TCL expected to set two variables: `name`
which is the name of the test, and `sql` which is the SQL to be executed;
the fragment can access the array `options` to determine the build and
benchmark options; examples are provided in the LumoSQL configuration to
specify the default set of tests, we show here an example, test number 2:

```
set d25000 [expr $options(DATASIZE) * 25000]
set name "$d25000 INSERTs in a transaction"

set sql "BEGIN;\n"
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

