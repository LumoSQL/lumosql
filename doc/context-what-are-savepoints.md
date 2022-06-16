<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->

# Observations on Savepoints in SQLite Internals

Dan Shearer
dan@shearer.org

Thanks to Uilbeheist.

## SAVEPOINT statement in SQLite vs the standard

The SAVEPOINT statement has been in the ISO SQL standard since 1992, and is in
most SQL implementations. SQLite users can take advantage of a unique SQLite
feature, where they can choose to avoid using all BEGIN/COMMIT\|END statements
in favour of named savepoints. The exception is BEGIN IMMEDIATE (==EXCLUSIVE in
WAL mode), because savepoints do not an equivalent to IMMEDIATE.

sqlite3 extends both SQL standard transactions and savepoints to be a superset
of both. An SQLite BEGIN/COMMIT transaction is a special un-named case of a
savepoint, and a named saveppoint outside a BEGIN/COMMIT has an implied BEGIN.
A savepoint cannot ever be followed by a BEGIN because there can only be one
open main transaction at once, and a BEGIN always marks the start of a main
transaction.

This above context helps understand the 
[SQLite SAVEPOINT documentation](https://sqlite.org/lang_savepoint.html) which
says:

> SAVEPOINTs are a method of creating transactions, similar to BEGIN and
> COMMIT, except that the SAVEPOINT and RELEASE commands are named and may be
> nested.

Other implementations of SQL stick to the less flexible definition used in
the SQL standard, with [MariaDB](https://mariadb.com/kb/en/savepoint/),  
[Postgresql](https://www.postgresql.org/docs/8.1/sql-savepoint.html), 
[Microsoft SQL Server](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/save-transaction-transact-sql?view=sql-server-ver15)
and [Oracle Server](https://docs.oracle.com/cd/B19306_01/server.102/b14200/statements_10001.htm)
seeming to be more or less identical. 

MariaDB can seem as if it behaves like SQLite, but that is only due to it being
silent rather than throwing an error when a savepoint is used outside
BEGIN/COMMIT. From the MariaDB documentation: "if SAVEPOINT is issued and no
transaction was started, no error is reported but no savepoint is created". In
fact MariaDB behaves like other implementations. 

## Savepoints in SQLite Code

Internal terminology: Where savepoints are not used within a standard
transaction, source code comments call it a "transaction savepoint". Similarly
an internal name for a standard BEGIN/COMMIT transaction is "anonymous
savepoint" while a "non-transaction savepoint" is the usual kind that follows a
BEGIN.

vdbe.c maintains the struct Savepoint declared in sqliteInt.h, while pager.c
maintains an array of struct PagerSavepoint. These parallel structures all come
down to the same objects on disk. 

### vdbe.c 

The opcode OP_Savepoint is the only relevant code in vdbe, which has some
savepoint logic and calls btree.c/sqlite3BtreeSavepoint(). vdbe deals with the
savepoints names and assigns each a sequence number. 

### btree.c

btree.c implments sqlite3BtreeSavepoint() which uses
sqlite3PagerOpenSavepoint() to do the work. There is not much savepoint logic
in btree.c however it is btree.c that implements transactions and
subtransactions. (Subtransactions map onto subjournals but btree.c doesn't know
anything about them.)

### pager.c

Savepoint logic is mostly implemented in pager.c, by manipulating the objects
in the Pager.aSavepoint[] array . pager.c has the complete implementation of
sub-journals, which are maintained to match savepoint nesting. pager.c does not
know about savepoint names, only the sequence numbers vdbe.c assigned. It is
pager code that does the actual rollback to the correct savepoint, no other
code is involved in this.

Note: Savepoint code in pager.c seems to be quite intertwined with journal
states, but very little difference between using WALs or not. pagerUseWal() and
the aWalData[] array seem hardly used suggesting that savepoint implications
for WAL mode are little different from the others.

