<!-- Copyright 2021 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, August 2020 -->

LumoSQL RBAC Permissions System
===============================

[Role-based Access
Control](https://en.wikipedia.org/wiki/Role-based_access_control) (RBAC) is the
way that online relational databases make sure that only authorised users can
access information. The SQL standard has the concept of "roles", rather like
job titles. As a simple example, someone with "engineering cadet" role will see
different things in the database to someone with the "sales manager" role. RBAC
gets complicated, because people in organisations will often be in several
different roles, and roles can have different levels of privilege. Privileges
are things like "read-only access" and "full read/write and edit" access, and
"allowed to create new roles".

A full RBAC implementation covering the many dozens of combinations of RBAC
possibilities is beyond the scope of the current LumoSQL Phase II.


Existing SQLite Permission Schemes
----------------------------------

SQLite has a [user authentication extension](https://www.sqlite.org/src/doc/trunk/ext/userauth/user-auth.txt)
which provides some basic access control, and seems to be quite rarely used. If
you have a valid username and a password, then the SQLite API will allow a
database connection. All users are equivalent, except that an admin user can
modify the contents of the new system table sqlite_user . All access is by
means of the C API. Anyone with the SQLite database file can open it and make
changes regardless of user authentication, because there is no encryption.
Various proprietary products such as
[SEE](https://www.sqlite.org/see/doc/release/www/index.wiki) or
[SQLCipher](https://www.zetetic.net/sqlcipher/) can encrypt the entire SQLite
database, which works to some extent with SQLite user authentication.

LumoSQL RBAC Goals and Constraints
----------------------------------

LumoSQL aims to provide:

* Compatibility with existing SQLite binaries, when using the SQLite native db
  format. If this means losing some more advanced features, that is acceptable
  although regrettable. There is a big difference between the statements "using
  the native SQLite db format", and "using the native SQLite BTree backend".  In
  the latter case there is no more consrtaint with BTree than with LMDB or
  anything else. In the former case, nothing can be stored in the binary image
  that standard SQLite is not expecting, and this is a constraint.

* Access control from SQL statements, with a similar user interface to the
  major online databases, as described in this document

* Fine-grained access control user interface per table, also with a similar
  user interface to the major online databases

* Ultra fine-grained per-row runtime access control

* Ultra fine-grained at-rest access control, unique in the world of relational databases

* Access control from SQLite pragmas, dot commands and commandline, however this will probably
  always be a subset of the user interface exposed via SQL

This point above of "Ultra fine-grained at-rest access control" means that,
even if someone has a LumoSQL database in their possession, they will only be
able to acces the specific rows in the specific tables to which they have a
valid username and password, or other such cryptographic key. This is really
unprecedented in relational databases.

The high-level design of the permissions system is taken from Postgres version 14:

* LumoSQL will implement a small but strict subset of Postgres permissions
* LumoSQL will extend the Postgres design only in that it can apply per-row
* These comments relate only to the design as exposed in SQL statements

LumoSQL RBAC will be built in to the main code. It cannot be an extension
because of the fine-grained nature of the design. RBAC builds on the existing
per-row checksum code in LumoSQL.

LumoSQL RBAC does not require support from the storage subsystem, ie whether
the native BTree or LMDB or some other key-value storage system, RBAC will
still work because we are storing rows as opaque encrypted blocks.

The above must necessarily be implemented in a different way to any existing
database,  even though the SQL user interface is similar to others and entirely
derived from Postgres. The unique functionality of at-rest security and RBAC
means that the data must be stored as opaque rows, and while there will always
be RBAC-specific metadata stored in LumoSQL tables, it is possible and expected
that a single row's encrypted data can be exported and sent elsewhere, and the
RBAC remains functional to anyone with the correct key.

An example of how implementation must be different is that LumoSQL cannot have
an equivalent to the Postgres BYPASSRLS role attribute to bypass Row Level
Security, because for most operations nobody can bypass LumoSQL per-row RBAC.
If you don't have the key, a row is a block of bits with a little metadata.

Another example is that, conversely, everyone who can read a LumoSQL database
has permissions to dump all rows or at least all tables, because being an
embedded library it is guaranteed we can access the file. However the encrypted
tables or rows will never be plain text without the key, even for a dump
operation.


Enabling and Disabling Row-level Permissions
--------------------------------------------

Per-row access control is enabled by changing the definition as per the
[Postgres ALTER TABLE command](https://www.postgresql.org/docs/14/sql-altertable.html). ALTER TABLE
ENABLE/DISABLE refer to whether or not it is possible to use per-row security
in this table, not whether or not the feature is actually used. This matters when, for example,
we want to quickly determine if any rows _might_ be protected in a database. If none of the tables 
have row level security enabled then there should not be any encrypted rows.

Example: ALTER TABLE foobar ENABLE ROW LEVEL SECURITY;

The way [SQLite implements the schema](https://www.sqlite.org/schematab.html)
is helpful for implemnting per-row security. It differs from other databases
due to the nature of many embedded use cases. See the heading 
["Why ALTER TABLE is such a problem for SQLite"](https://www.sqlite.org/lang_altertable.html),
which explains why SQLite stores the schema as the literal plain text CREATE
TABLE statements. This gives LumoSQL a lot more freedom to improve the
internals of row-based security without impacting on backwards compatibility
with other versions of LumoSQL.


Roles
-----

Adapted from [roles in Postgres 14](https://www.postgresql.org/docs/14/user-manag.html).

Roles take the place of users and groups. They can be called anything.

Roles have attributes. LumoSQL has only two attributes: LOGIN and
SUPERUSER (see https://www.postgresql.org/docs/13/role-attributes.html )
A superuser has complete access. A login user has default access,
and can have access added to or subtracted from the default access level.

Roles are managed with CREATE/DROP/ALTER ROLE statements, except
for defining access privileges in a detailed way.

Example: "CREATE ROLE admins SUPERUSER"


Privileges
----------

Adapted from [privileges in Postgres 14](https://www.postgresql.org/docs/14/ddl-priv.html).

LumoSQL privileges are hard-coded and cannot be extended.

Some privileges are assigned to roles and objects by default.

The complete list of LumoSQL privileges is:

* SELECT
* UPDATE,
* INSERT
* DELETE
* CREATE

The UPDATE and DELETE privileges imply SELECT. CREATE only applies to tables.
The keyword "ALL" is also allowed.  

Note: In LumoSQL, SUPERUSER privileges cover much more than ALL, and these
additional privileges superuser has cannot be assigned in any way.

Default privileges of ALL are assigned to all roles for 
schema objects other than DATABASE and TABLE (and therefore 
for rows within each table.) This may need to be changed in
future versions of the LumoSQL per-row RBAC.


Granting membership to a Role
-----------------------------

This is one of two very different uses of and meanings for the GRANT statement, and is
adapted from [GRANT in Postgres 14](https://www.postgresql.org/docs/14/sql-grant.html). 
This usage is specific to roles, which typically means users such as an identifiable human or program.

The GRANT command grants membership in a role to one or more other
roles. Membership in a role is significant because it conveys the
privileges granted to a role to each of its members.

Only SUPERUSER can grant membership in roles.

Example: GRANT admins TO svetlana;

This means role svetlana is now a member of the role admins.

REVOKE undoes GRANT.


Granting permissions to an Object
---------------------------------

This is the second use for the GRANT statement, specific to database objects.

There are three objects that can be assigned permissions:

* DATABASE
* TABLE
* TABLE.ROW

Nothing else in a schema can have its permissions assigned or changed. All
other objects are accessible with ALL privileges at all times, no matter who
the user is, or no identified user at all. This is the nature of an embedded system,
where we expect the user who can open a database will always have permissions to 

Examples: GRANT INSERT ON some_table TO nikita;
          GRANT ALL ON some_table TO nikita WHERE ROWID=54321;

REVOKE undoes GRANT. REVOKing table permissions does not revoke
row permissions, or vice versa.

Unresolved Questions
--------------------

* What does it mean when a binary encrypted row is dumped? From the [SQLite documentation](https://sqlite.org/cli.html):

: Use the ".dump" command to convert the entire contents of a database into a single UTF-8 text file. 

We cannot turn an encrypted row into UTF-8 text without the key, and we cannot control who uses the dump command.

For example a dump session might look like:

```

$ lumosql rbac-example-db.lumo
@lumosql> .dump
    :
INSERT INTO "my_table" VALUES(X'AB12340CDE.... 12234DEF');

```

* Related to the above, but to be very clear, an encrypted row is not another datatype, and the BLOB affinity cannot help here.
