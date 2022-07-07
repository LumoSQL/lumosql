<!-- Copyright 2021 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, August 2020 -->

<!-- toc -->

LumoSQL Minimal At-Rest Discretionary Access Control System
===========================================================


Role
Authority
Privilege
Subjects
Objects

How it compares
===============

* RBAC is not centrally administered by default ...
* A minimal subset of DAC implemented ...
* Privileges default to all for every user, because an embedded ...


Nobody else does at-rest fine-grained control

Not policies. Not columns. Not nested roles. Limited privileges, subjects and objects.

Definitions
===========


A  role is a database entity that is used to group a combination of authorities 
and/or privileges together so they can be simultaneously granted or revoked. 
When roles are used, the assignment of authorities and privileges is greatly 
simplified. For example, instead of granting the same set of authorities and 
privileges to every individual in a particular job function, you can assign a set 
of authorities and privileges to a role that represents the job and then grant 
membership in that role to every user who performs that particular job. It is 
important to note that only users with SECADM authority are allowed to 
create roles (by executing the CREATE ROLE SQL statement)



# The LumoSQL Security Design and Implementation

SQLite is an embedded database, and traditionally there has been no need of
access security in the main SQLite use case. The application took care of any
security needs, with a little-used password system for database access provided
by the C API. However once connected, there is little distinction between a
superuser or other users, and no encryption. Various solutions exist that
modify the SQLite source code to give one kind of encryption or another, as
documented in the 
[LumoSQL Knowledgebase](./context-relevant-knowledgebase.md#list-of-relevant-sql-checksumming-related-knowledge).

The LumoSQL approach is completely different. LumoSQL recognises that the
security and privacy requirements of the 21st century are very different to the
primary use case of SQLite over more than two decades, and so implements a
fairly complete security system, recognisable to anyone who has used one of the
mainstream networked SQL databases.

On the other hand, SQLite's strength is its simplicity and the things that come
with that including speed, compact code and relative ease of security review.
An example of how security models can become so complex they are impossible to verify is provided by Microsoft SQL Server, whose 
[Chart of Database Access Permissions](https://raw.githubusercontent.com/Microsoft/sql-server-samples/master/samples/features/security/permissions-posters/Microsoft_SQL_Server_2017_and_Azure_SQL_Database_permissions_infographic.pdf) defies analysis. 
Similar charts can be drawn up for Oracle, DB2 et al, with undoubted artistic merit. These databases need to solve very different problems to LumoSQL, and they must do it in a way that is compatible with decades-old security design. LumoSQL does not have these constraints.

# Goals

LumoSQL aims to deliver:

* At-rest data encryption at the database, table and row level
* Per-row integrity controls (eg checksums) stored in each row
* Per-row encryption, self-contained within each row
* Per-row RBAC, self-contained within each row

LumoSQL will avoid:

* Large amounts of security metadata
* Mandating a key management system
* Introducing new encryption technologies
* A large or complex security model

# Design Principles

0. LumoSQL data will be secure when at rest. This is consistent with the embedded use case, when databases are often at rest and often copied without knowledge of the application.
1. Security will be defined by the LumoSQL data, and travel with the data at all times.
2. Anyone with a valid key can read the data according to the LumoSQL security specification, using any conformant software.
3. Users may implement any (or no) key authority system. This is consistent with the way SQLite is used.
4. LumoSQL will define a standard key management system for anyone wanting to use it.
5. The fundamental unit for LumoSQL security is the encrypted row. Although database and tables can also be encrypted.

## LumoSQL is a Hybrid Access Control System

All SQL database security models implement [Discretionary Access Control](https://en.wikipedia.org/wiki/Discretionary_access_control). The traditional embedded use case for SQLite is already well-suited to implementing [Mandatory Access Control](https://en.wikipedia.org/wiki/Mandatory_access_control) on end users, because the application has ultimate control. LumoSQL will not implement Mandatory Access Control.

Within Discretionary Access Control there are different models and tradeoffs.
LumoSQL implements features from some of the most common approaches.

``` pikchr indent toggle source-inline
Frame: [
B: box invis 
line invis "LumoSQL" bold color purple from 0.5cm s of B.w to 0.5cm s of B.e
C1: circle color black rad 2cm at 0.8cm n of B.c
line invis "Role-Based" "Access Control" "(RBAC)" from 1cm n of C1.w to 1cm n of C1.e
C2: circle color black rad 2cm at 1.5cm sw of B.c
line invis "Any or No" "Key Authority" from 0.2cm s of C2.w to 0.2cm s of C2.c
C3: circle color black rad 2cm at 1.5cm se of B.c
line invis "At-rest" "Encryption" from C2.e to C3.e
Title: line invis "Discretionary Access Control" "Systems" color green from 4.2cm above C2.w to 4.2cm above C2.e
]
Border: box color gray rad 1cm thin width Frame.width+1cm height Frame.height+1cm at Frame.center
```
# LumoSQL is a Minimal Access Control System

LumoSQL implements the smallest possible security model that will satisfy the
goals. Nevertheless there are some features that are not implemented by any
other mainstream database. LumoSQL security aims to be verifiable.

``` pikchr indent toggle source-inline
B:  dot invis at (0,0)
Title: box invis "LumoSQL Compared With Typical SQL Access Control" ljust color purple at B+(1cm,0.4cm)

circle invis color green rad 0.4cm "✔" big big big bold at B+(0.6cm,-0.3cm)
box invis "Object types: Yes, but only database, table and row" ljust fit

circle invis color green rad 0.4cm "✔" big big big bold at 0.5cm below last circle
box invis "At-rest encryption for all object types: Yes." ljust fit

circle invis color green rad 0.4cm "✔" big big big bold at 0.5cm below last circle
box invis "Simple defaults: Yes. For a new database, a user has all privileges by default, which can be selectively tightened" ljust fit

circle invis color green rad 0.4cm "✔" big big big bold at 0.5cm below last circle
box invis "RBAC: Yes. Read/Write access for each object, enforced by the object being encrypted" ljust fit

circle invis color green rad 0.4cm "✔" big big big bold at 0.5cm below last circle
box invis "Portability and compatibility: Yes. Encrypted LumoSQL rows can be imported into other databases and verified there, or even decrypted if they have the key" ljust fit

circle invis color green rad 0.4cm "✔" big big big bold at 0.5cm below last circle
box invis "Distributed and Decentralised Key Management: Yes. Users can choose to use the optional blockchain-based LumoSQL key management system" ljust fit

circle invis color red rad 0.4cm "✘" big big big bold at 0.5cm below last circle
box invis "Table Policies: No." ljust fit

circle invis color red rad 0.4cm "✘" big big big bold at 0.5cm below last circle
box invis "Column security and encryption: No." ljust fit

circle invis color red rad 0.4cm "✘" big big big bold at 0.5cm below last circle
box invis "Complex role definitions: No. A user is either a superuser or not, or in a group or not, and a group has read or write access, or not. That's it." ljust fit

circle invis color red rad 0.4cm "✘" big big big bold at 0.5cm below last circle
box invis "Inherit privileges: No." ljust fit

circle invis color red rad 0.4cm "✘" big big big bold at 0.5cm below last circle
box invis "Predefined key management: No. Users can implement any key management system they choose, in the usual SQLite philosophy" ljust fit

circle invis color red rad 0.4cm "✘" big big big bold at 0.5cm below last circle
box invis "Network security: No. LumoSQL is an embedded database and needs no network security code." ljust fit

circle invis color red rad 0.4cm "✘" big big big bold at 0.5cm below last circle
box invis "Transport security: No. Any plain-text transport may be used to move LumoSQL data that is encrypted at rest." ljust fit


```

# LumoSQL Encrypts Three Kinds of Objects

This diagram illustrates the way that any or all of the three layers of at-rest
encryption can be active at once, and their different scopes. 

``` pikchr indent toggle source-inline
      fill = bisque
      linerad = 15px
      leftmargin = 2cm

      define diamond { \
        box wid 150% invis
        line from last.w to last.n to last.e to last.s close rad 0 $1
      }

      oval "SUBMIT TICKET" width 150%
      down
      arrow 50%
NEW:  file "New bug ticket" "marked \"Open\"" fit
      arrow same
      box "Triage," "augment &" "correct" fit
      arrow same
DC:   box "Developer comments" fit
      arrow same
FR:   box "Filer responds" fit
      arrow 100%
REJ:  diamond("Reject?")
      right
      arrow 100% "Yes" above
      box "Mark ticket" "\"Rejected\" &" "\"Resolved\"" fit with .w at previous.e
      arrow right 50%
REJF: file "Rejected" "ticket" fit
      arrow right 50%
REOP: diamond("Reopen?")
      down
REJA: arrow 75% from REJ.s "  No; fix it" ljust
CHNG: box "Developer changes code" with .n at last arrow.s fit
      arrow 50%
FIXD: diamond("Fixed?")
      right
FNO:  arrow "No" above
RES:  box "Optional:" "Update ticket resolution:" "\"Partial Fix\", etc." fit
      down
      arrow 75% "  Yes" ljust from FIXD.s
      box "Mark ticket" "\"Fixed\" & \"Closed\"" fit
      arrow 50%
RESF: file "Resolved ticket" fit
      arrow same
END:  oval "END"

      line from 0.3<FR.ne,FR.se> right even with 0.25 right of DC.e then up even with DC.e then to DC.e ->

      line from NEW.w left 0.5 then down even with REJ.w then to REJ.w ->

      line from RES.e right 0.3 then up even with CHNG.e then to CHNG.e ->

      line from REOP.s "No" aligned above down 0.4
      line from previous.s down to (previous.s, RESF.e) then to RESF.e ->

      line from REOP.n "Yes" aligned below up 0.3
      line from previous.n up even with 0.6<FR.ne,FR.se> then to 0.6<FR.ne,FR.se> ->


```



# LumoSQL RBAC Permissions System

[Role-based Access Control](https://en.wikipedia.org/wiki/Role-based_access_control) (RBAC) is the
way that online relational databases make sure that only authorised users can
access information. The SQL standard has the concept of "roles", rather like
job titles. As a simple example, someone with "engineering cadet" role will see
different things in the database to someone with the "sales manager" role. RBAC
gets complicated, because people in organisations will often be in several
different roles, and roles can have different levels of privilege. Privileges
are things like "read-only access" and "full read/write and edit" access, and
"allowed to create new roles".

A full RBAC implementation covering the many dozens of combinations of RBAC
possibilities is far outside the LumoSQL goals described above.


## Existing SQLite Permission Schemes

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

# LumoSQL RBAC Goals and Constraints

LumoSQL RBAC aims to provide:

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

# Interfaces to LumoSQL Security System

The primary means of interacting with the security system is via the SQL commands.

For interacting with database objects (that is, whole database encryption) the
SQLite [Security Encryption Extension C API](https://www.sqlite.org/see/doc/trunk/www/readme.wiki) is used, with some
of the key/rekey details modified for LumoSQL's different range of ciphers.

## Enabling and Disabling Row-level Permissions

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


## Roles

Adapted from [roles in Postgres 14](https://www.postgresql.org/docs/14/user-manag.html).

Roles take the place of users and groups. They can be called anything.

Roles have attributes. LumoSQL has only two attributes: LOGIN and
SUPERUSER (see https://www.postgresql.org/docs/13/role-attributes.html )
A superuser has complete access. A login user has default access,
and can have access added to or subtracted from the default access level.

Roles are managed with CREATE/DROP/ALTER ROLE statements, except
for defining access privileges in a detailed way.

Example: "CREATE ROLE admins SUPERUSER"


## Privileges

Adapted from [privileges in Postgres 14](https://www.postgresql.org/docs/14/ddl-priv.html).

LumoSQL privileges are hard-coded and cannot be extended.

Some privileges are assigned to roles and objects by default.

The complete list of LumoSQL privileges is:

* SELECT
* UPDATE
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

## Granting membership to a Role

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


## Granting permissions to an Object

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




## Unresolved Questions

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
