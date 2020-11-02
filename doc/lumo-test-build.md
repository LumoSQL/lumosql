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
   * [Running tests <a name="user-content-running-tests"></a>](#running-tests-)
   * [Adding new backends <a name="user-content-adding-backends"></a>](#adding-new-backends-)

LumoSQL Build System
====================

The LumoSQL project includes code to combine any version of SQLite with any
version of third party storeage backends, and to run tests on the combined
code. This requires small modifications to SQLite itself, and some new code
to interface each backend.

To do this, the project uses the "not-forking" mechanism described in
[Not-Forking Upstream Source Code Tracker](./lumo-not-forking.md), together
with appropriate configuration, to obtain the sources, and a set of shell
scripts to build and run test programs.

To ensure repeatability of tests, each test will include the following information:
* the version of the "not-forking" configuration used
* the version of sqlite3 used
* the name of the storage backend used: this is omitted if the test used an
unchanged version of sqlite3 with its own backend
* the version of the storage backend used, also omitted for tests using
an unchanged version of sqlite3

Three shell scripts, which can be found in the `tools` subdirectory, handle
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
sh tool/get-lumo-sources SRC_DIR CFG_VERSION SQLITE3_VERSION
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

`SQLITE3_VERSION` is the version of sqlite3 to download, for example `3.33.0`.

To download sqlite3 sources with an alternative backend, add two more
arguments to specify the backend's name and version:

```
sh tool/get-lumo-sources SRC_DIR CFG_VERSION SQLITE3_VERSION BACKEND_NAME BACKEND_VERSION
```

At present the only backend provided is the `lmdb` backend derived from the
sqlightning sources but modified to work with more versions of lmdb and sqlite3;
however to add new backends see [Adding new backends](#adding-backends) below.

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
sh tool/build-lumo-backend BUILD_DIR SRC_DIR
```

`SRC_DIR` is the directory created by `get-lumo-sources` and `BUILD_DIR` is a
new directory (it must not already exist, and the program will create it).

After a successful run, the file `sqlite3` inside `BUILD_DIR` will contain a
script to run the modified sqlite3 shell with the correct libraries (which will
also come from `BUILD_DIR`)

# Running tests <a name="running-tests"></a>

The `run-lumo-tests` script takes the path to the build directory created by
`build-lumo-backend` and runs a set of tests on it:

```
sh tool/run-lumo-tests [OPTIONS] BUILD_DIR
```

By default, if no OPTIONS are specified, the program writes a 1-line summary
of each test on standard output, with three columns containing the running
time in seconds, the test number and the test name respectively, for example:

```
   1.094   4 100 SELECTs on a string comparison
```

Shows that test number 4, "100 SELECTs on a string comparison", took just over
1 second to run.

One or more of the following OPTIONS request additional output:

* `-t FILENAME`: output the 1-line summary to `FILENAME` as well as on standard
output: this would be equivalent to adding `| tee FILENAME` at the end of the
command
* `-h FILENAME`: output a description of the tests and their results in HTML
format to `FILENAME`
* `-d DATABASE:TABLE`: adds 1 record to a database for each test ran: `DATABASE`
points to an existing sqlite3 database, and `TABLE` is the name of an existing
table inside that database; note that a "standard" sqlite3 must be installed on
the system and available via the default PATH for this to work: the version being
tested may be incomplete and/or incompatible with the standard, and therefore
can not be used for this

When storing results in a database, the table must be created with a statement
similar to:

```
CREATE TABLE results (
when_ran int,
duration float,
test_number int,
test_name varchar(255),
backend_name varchar(32),
backend_version varchar(32),
sqlite3_version varchar(32)
);
```

The column names are unimportant as long as there are 7 columns in the correct
order: the program just inserts 7 values; when testing unchanged sqlite3 sources,
the `backend_name` and `backend_version` columns will be left empty.

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

