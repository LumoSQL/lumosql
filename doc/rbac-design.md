LumoSQL RBAC Permissions System
===============================

Existing Schemes
----------------

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

LumoSQL RBAC Goals
------------------

LumoSQL aims to provide:

* Compatibility with existing SQLite binaries, when using the SQLite native db format
* Access control from SQL statements, similar to the major online databases
* Fine-grained access control per table, also similar to the major online databases
* Ultra fine-grained per-row access control, unique in the world of relational databases
* Ultra fine-grained at-rest access control

This last point means that, even if someone has a LumoSQL database in their
possession, they will only be able to acces the specific rows in the specific
tables to which they have a valid username and password. This is really
unprecedented in relational databases.

The high-level design of the permissions system is taken from Postgres version 13:

* LumoSQL will implement a small but strict subset of Postgres
* LumoSQL will extend the Postgres design only in that it can apply per-row

LumoSQL RBAC will be built-in to the main code. It cannot be an extension
because of the fine-grained nature of the design. RBAC builds on the existing
per-row checksum code in LumoSQL.

Roles
-----

Guiding description: https://www.postgresql.org/docs/13/user-manag.html

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

Guiding description: https://www.postgresql.org/docs/13/ddl-priv.html

Privileges are hard-coded and cannot be extended.

Some privileges are assigned to roles and objects by default.

The complete list of LumoSQL privileges is: SELECT, UPDATE,
INSERT, DELETE, CREATE.  The UPDATE and DELETE privileges imply
SELECT. CREATE only applies to tables. "ALL" is also allowed.
Note: SUPERUSER privileges cover much more than ALL, and these
additional privileges are not able to be assigned in any way.

Default privileges of ALL are assigned to all roles for 
schema objects other than DATABASE and TABLE (and therefore 
for rows within each table.) This may need to be changed in
the future.


Granting membership to a Role
-----------------------------

Guiding description: https://www.postgresql.org/docs/13/sql-grant.html

GRANT command grants membership in a role to one or more other
roles. Membership in a role is significant because it conveys the
privileges granted to a role to each of its members.

Only SUPERUSER can grant membership in roles.

Example: GRANT admins TO svetlana;
This means role svetlana is now a member of the role admins.

REVOKE undoes GRANT.

This is one of two very different uses for the GRANT statement.


Granting permissions to an Object
---------------------------------

This is the second use for the GRANT statement.

There are three objects that can be assigned permissions:
DATABASE, TABLE, TABLE.ROW . Nothing else in a schema can 
have its permissions assigned or changed. All other objects
are accessible with ALL privileges.

Examples: GRANT INSERT ON some_table TO nikita;
          GRANT ALL ON some_table TO nikita WHERE ROWID=54321;

where 54321 is a ROWID

REVOKE undoes GRANT. REVOKing table permissions does not revoke
row permissions, or vice versa.
