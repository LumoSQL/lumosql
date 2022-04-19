Announcing LumoSQL Database Phase II
====================================

| July 27, 2021 |
|Dan Shearer    |
|dan@lumosql.org|

LumoSQL is a derivative of SQLite, the most-used software in the world.
Our focus is on privacy, at-rest encryption, reproducibility and the
things needed to support these goals. The NLNet Foundation continues to
support LumoSQL, this time via the NGI Assure fund linked below.

In LumoSQL Phase II, the team is focussing on:

* [Lumions as a universal data transport](./rfc/README.md) as well as the
  fundamental unit of private and secure data storage in LumoSQL.

* Implementing a small [subset of the Postgresql 13 RBAC](./rbac-design.md)
  permissions model via
  the SQL statements CREATE ROLE/GRANT/REVOKE etc. An important addition to
  Postgres is to allow per-row permissions as well as per-table.

* An extension of Phase I's hidden column mechanism, now to include hidden
  tables. When using the native SQLite file format, hidden columns (similar to
  ROWID) and tables are intended to be invisible to unmodified SQLite binaries.
  These columns and tables implement row-based and table-based encryption and
  more.

* Further integration of the LMDB key-value store as an optional backend, from
  version 0.9.11 onwards, and also the LMDBv1.0 pre-release. This work aims to
  implement remaining SQLite and LMDB API features, and to prepare for the
  page-level database encryption that is coming with LMDBv1.0.

* Improved documentation, assembling the knowledge we gained in Phase I,
  discussing the infrastructure as we now understand it, and covering the new
  features for privacy and encryption. We do realise there is plenty of
  work to do on this front :-)

LumoSQL retains and builds on Phase I features including:

* The build, benchmark and test tools to measure unmodified SQLite and LumoSQL
  in various configurations

* The Not-Fork tool which allows multiple upstream codebases to be combined
  across multiple versions without forking

Further info from these URLs:

   [LumoSQL Database](https://lumosql.org/src/lumosql)

   [Not-Forking reproducibility tool](https://lumosql.org/src/not-forking)

   [NLNet NGI Assure fund](https://nlnet.nl/assure/)


