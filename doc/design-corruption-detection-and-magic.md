<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->

Table of Contents
=================

   * [Summary of SQL Database Corruption Detection](#summary-of-sql-database-corruption-detection)
   * [SQLite and Integrity Checking](#sqlite-and-integrity-checking)
   * [LumoSQL Checksums and the SQLite On-disk File Format](#lumosql-checksums-and-the-sqlite-on-disk-file-format)
   * [Design of the SQLite Checksum VFS Loadable Extension](#design-of-the-sqlite-checksum-vfs-loadable-extension)
   * [Goals for Corruption Detection](#goals-for-corruption-detection)
   * [Design for Corruption Detection](#design-for-corruption-detection)
      * [For Non-row Data](#for-non-row-data)
      * [For Row Data](#for-row-data)
   * [Implementation for Corruption Detection](#implementation-for-corruption-detection)


![](./images/lumo-corruption-detection-and-magic-intro.png "Not Yet Done")

# Summary of SQL Database Corruption Detection

One of the short-term goals stated in the [LumoSQL Project Aims](./lumo-project-aims.md) is:

> LumoSQL will improve SQLite quality and privacy compliance by introducing
> optional on-disk checksums for storage backends including to the original
> SQLite btree format. This will give real-time row-level corruption detection.

This design and implementation discussion focusses on row-level corruption 
detection, which also gives the user a very rapid way of detecting changes.
The change detection aspect of row-level corruption detection is not dealt
with here, except that it is possible the speed benefits for detecting changes
might in many cases outweigh the costs of maintaining the checksum row.

It seems quite extraordinary that in 2020 none of the major online databases -
not Posgresql, Oracle, MariaDB, SQLServer or others - have the built-in ability
to check during a SELECT operation that the row being read from disk is exactly
the row that was previously written. There are many reasons why data can get
modified, deleted or overwritten outwith the control of the database, and the
ideal way to respond to this is to notify the database when a corrupt row is
accessed.  All that is needed is for a hash of the row to be stored with the
row when it is written.

All the major online databases have the capacity for an external process to
check disk files for database corruption, as does SQLite. This is very
different from real-time integrity checking, and cannot be done in real time.

Knowing that a corruption problem is limited to a row or an itemised
list of rows reduces a general "database corruption problem" down to a bounded
reconstruction task. Users can have confidence in the remainder of a database
even if there is corruption found in some rows.

This problem has been recognised and solved inefficiently at the SQL level by
various projects. Two of these are [Periscope Data's Per-table Multi-database Solution](https://www.periscopedata.com/blog/hashing-tables-to-ensure-consistency-in-postgres-redshift-and-mysql)
and [Percona's Postgresql Public Key Row Tracking](https://www.percona.com/blog/2018/10/12/track-postgresql-row-changes-using-public-private-key-signing/).
By using SQL code rather than modifying the database internals there is a
performance hit. Both these companies specialise in performance optimisation
but choose not to apply it to this feature, suggesting they are not convinced
of high demand from users.

Interestingly, all the big online databases have row-level security, which has
many similarities to the problem of corruption detection. 

For those databases that offer encryption, this is effectively page-level or
column-based hashes and therefore there is corruption detection by implication.
However this is not row-based checksumming, and it is not on by default in any
of the most common databases.

It is possible to introduce a checksum on database pages more easily than for
every row, and transparently to database users. However, knowing a database
page is corrupt isn't much help to the user, because there could be many rows
in a single page.

More on checksumming for SQL databses can be found referenced in [SQLite Relevant Knowledgebase](./2.4-relevant-knowledebase/#list-of-relevant-sql-checksumming-related-knowledge)) 

# SQLite and Integrity Checking

The SQLite developers go to great lengths to avoid database corruption, within
their project goals. Nevertheless, corrupted SQLite databases are an everyday
occurance for which there are recovery procedures and commercial tools.

SQLite does have checksums already in some places:

* for the journal transaction log (superceded by the Write Ahead Log system)
* for each database page when using the closed-source SQLite Encryption Extension
* for each page in a WAL file
* for each page when using the Checksum VFS Extension, discussed below

SQLite also has [PRAGMA integrity_check](https://www.sqlite.org/pragma.html#pragma_integrity_check) and
[PRAGMA quick_check](https://www.sqlite.org/pragma.html#pragma_quick_check)
which do partial checking, and which do not require exclusive access to the
database. These checks have to scan the database file sequentially and verify
the logic of its structure, because there are no checksums available to make it
work more quickly.

None of these are even close to end user benefits of row-level corruption
detection, at the potential cost of speed.

SQLite does have a file change counter in its database header, in 
[offset 24 of the official file format](https://www.sqlite.org/fileformat.html), however this
is not itself subject to integrity checks nor does it contain information about the rest of the file,
so it is a hint rather than a guarantee.

SQLite applications often need row-level integrity checking even more than the online databases because:

* SQLite embedded and IoT use cases often involve frequent power loss, which is the most likely time for corruption to occur.
* an SQLite database is an ordinary filesystem disk file stored wherever the user decided, which can often be deleted or overwritten by any unprivileged process.
* it is easy to backup an SQLite database partway through a transaction, meaning that the restore will be corrupted
* SQLite does not have robust locking mechanisms available for access by multiple processes at once, since it relies on lockfiles and Posix advisory locking 
* SQLite provides the [VFS API Interface](https://www.sqlite.org/vfs.html) which users can easily misuse to ignore locking via the sql3_*v2 APIs
* the on-disk file format is seemingly often corrupted regardless of use case. Better evidence on this is needed but authors of SQLite data file recovery software (see listing in [SQLite Relevant Knowledgebase](./2.4-relevant-knowledebase/#list-of-relevant-sql-checksumming-related-knowledge)) indicates high demand for their services. Informal shows of hands at conferences indicates that SQLite users expect corruption.

sqlite.org has a much more detailed, but still incomplete, summary of [How to Corrupt an SQLite Database](https://www.sqlite.org/howtocorrupt.html).

# LumoSQL Checksums and the SQLite On-disk File Format 

The SQLite database format is widely used as a defacto standard. LumoSQL ships
with the lumo-backend-mdb-traditional which is the unmodified SQLite on-disk
format, the same code generating the same data. There is no corruption
detection included in the file format for this backend.  However corruption
detection is available for the traditional backend, and other backends that do
not have scope for checksums in their headers. For all of these backends,
LumoSQL offers a separate metadata file containing integrity information.

The new backend lumo-backend-mdb-updated adds row-level checksums in the header
but is otherwise identical to the traditional SQLite MDB format. 

There is an argument that any change at all is the same as having a completely
different format.  This is not a strong argument against adding checksums to
the traditional SQLite on-disk format because with encryption increasingly
becoming mandatory, the standard cannot apply. The sqlite.org closed-source SSE
solution is described as "All database content, including the metadata, is
encrypted so that to an outside observer the database appears to be white
noise." Other solutions are possible involving metadata that is not encrypted
(but definitely checksummed), but in any case, there is no on-disk standard for
SQLite databases with encryption.

# Design of the SQLite Checksum VFS Loadable Extension

In April 2020 the [SQLite Checksum VFS](https://sqlite.org/cksumvfs.html) was 
committed to the [ext/ source tree](https://sqlite.org/src/file/ext/misc/cksumvfs.c).
The design goals were:

> The checksum VFS extension is a VFS shim that adds an 8-byte checksum to the
> end of every page in an SQLite database. The checksum is added as each page
> is written and verified as each page is read. The checksum is intended to
> help detect database corruption caused by random bit-flips in the mass
> storage device. 

It is important to note that this VFS is among the very first, if not the first,
of mainstream databases to recognise that all read operations should be subject to
validation.

The VFS overloads the low-level Read() function like this:
```
/* Verify the checksum if
 **    (1) the size indicates that we are dealing with a complete
 **        database page
 **    (2) checksum verification is enabled
 **    (3) we are not in the middle of checkpoint
*/
```

This means that if a page-level corruption is detected during a read operation
then SQLITE_IOERR_DATA is returned. This implementation has some major problems, including:

* No information about the logical location of this error, eg what row(s) it
  affects. The application knows nothing about how rows map to pages.
* No facility for isolation or recovery of data
* Brittle implementation due to requirements of the file format. The
  "bytes of reserved space on each page"
  value at offset 20 the SQLite database header must be exactly 8.

Good points to learn from this VFS include:

* the various PRAGMAs implememnted for control and ad hoc verification
* the new data error
* the fact that the status of verification is made visible via a SELECT
* page level detection protects all parts of the database, not just rows

# Goals for Corruption Detection

* Similar control interface to the Checksum VFS
* Row-oriented detection
* Detection available from SQL, with recovery an option
* Special column, just like RowID
* Complete abort also an option
* Optionally include page level as well, however, not necessarily

# Design for Corruption Detection

Row-level checksum data will be stored as an extra column. Non-row data will
be stored according to the same mechanism needed for encryption and other 
LumoSQL features. Per-row checksums are a valid choice without checksums 
for the other data including indexes and metadata.

It isn't yet clear whether there is merit in adding table-level corruption
detection, given that page-level checksumming is possible for all the 
initally-expected btree-type backends for SQLite. This can be added at a 
later stage, and would be included in the category of non-row data.

## For Non-row Data

Non-row data means all metadata associated with a LumoSQL database, which may
be considerably more than is with a traditional SQLite database depending on
the encryption or other options that are selected. We already know from the
Checksum VFS implementation that there is very little scope for adding checksum
metadata to a traditional SQLite file. 

All LumoSQL backends can have corruption detection enabled, with the metadata
stored either directly in the backend database files, or in a separate file.
When a user switches on checksums for a database, metadata needs to be stored.

This depends on two new functions needed in any case for labelling LumoSQL
databases provided by backend-magic.c: lumosql_set_magic() and
lumosql_get_magic(). These functions add and read a unique metadata signature
to a LumoSQL database.

1. if possible magic is inserted into the existing header

2. if not a separate "metadata" b-tree is created which contains a key "magic"
and the appropriate value. get_magic() will look for the special metadata
b-tree and the "magic" key

## For Row Data

High-level design for row-level checksums is:

1. an internally maintained row hash updated with every change to a row
2. If a corruption is detected on read, LumoSQL should make maximum relevant
   fuss. At minimum, [error code 11 is SQLITE_CORRUPT](https://www.sqlite.org/rescode.html#corrupt) but there is also
   SQLITE_IOERR_DATA (not SQLITE_IOERR_DATA is missing from the official SQLite 
   list of error codes, but this seems to be an error.)
3. This hash is kept in a special column so that user-level logic can do not
   only corruption detection, but also change detection.

At a later stage a column checksum can be added giving change detection on a
table, or corruption detection for read-only tables.

In the case where there is a separate metadata file, a function pair in
lumo-backend-magic.c reads and writes a whole-of-file checksum for the
database. This can't be done for where metadata is stored in the main database
file because it is a recursive problem. This is like a fail-early case of 
all other corruption detection, perhaps to warn the application to run 
integrity checks.

# Implementation for Corruption Detection

There is already precedent for having a column with metadata for every row, as 
explained in [the Last Insert Rowid documentation](https://sqlite.org/c3ref/last_insert_rowid.html):

> Each entry in most SQLite tables (except for WITHOUT ROWID tables) has a unique
> 64-bit signed integer key called the "rowid". The rowid is always available as
> an undeclared column named ROWID, OID, or _ROWID_ as long as those names are
> not also used by explicitly declared columns.

The implementation for corruption detection is to perform similar operations to
maintain a similar implicit column. In every non-index btree, the 
btree.c/sqlite3BtreeInsert() is called before every write of a row. At this point
the full row data is known, and so (just before invalidateIncrblobCursors() is
called in that function) we can add a hash of that data to the ROWCSUM column.

For reading, the function sqlite3_step() sees every row read from a table, and 
can check that the hash matches the data about to be returned to the user.

The user can execute:
```
    SELECT ROWCSUM from table;
```

and treat the results like any other column return (which is how change detection can 
be managed, by storing the checksum results in another column.)

[WITHOUT ROWID](https://sqlite.org/withoutrowid.html) tables are intended for
corner cases requiring marginally greater speed. Without some specific addition
reason not thought of yet, it seems incorrect to add checksums to a WITHOUT
ROWID table because that will reduce the one advantage they provide.

main.c/sqlite3_table_column_metadata() will need to know about ROWCSUM (and
_ROWCSUM_), however this does not seem to be vital functionality, used only in
shell.c and as a feature for extensions to export. 

The control mechanism will be the same as for the Checksum VFS Extension, 
with the addition of the term "_row_" to make it clear this is on a per-row
rather than per-page basis:

```
PRAGMA checksum_row_verification;          -- query status
PRAGMA checksum_row_verification=OFF;      -- disable verification
PRAGMA checksum_row_verification=ON;       -- re-enable verification

```

