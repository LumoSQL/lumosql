<!--- SPDX-License-Identifier: CC-BY-SA-4.0 --->
<!--- SPDX-FileCopyrightText: 2020 The LumoSQL Authors --->
<!--- SPDX-ArtifactOfProjectName: LumoSQL --->
<!--- SPDX-FileType: Documentation --->
<!--- SPDX-FileComment: Original by Dan Shearer, 2020 --->

<!-- toc -->

![](./images/lumo-ecosystem-intro.png "LumoSQL logo")



LumoSQL 2019 Prototype Conclusions And Lessons
==============================================

The original LumoSQL question was: “does the 2013 sqlightning work still stand
up, and does it represent a way forward?” 

The answers are many kinds of both Yes and No:

1.  **Yes**, with some porting and archeology, sqlightning does still
    work and is relevant. It did move the world forward, it just took a while.
2.  **No**, SQLite in 2020 is not vastly slower than sqlightning, as it
    was in 2013. SQLite has improved its btreee code. We have not yet
    run the concurrency testing which seems likely to show benefits for
    using LMDB.
3.  **Yes**, sqlightning does represent a way forward to a more robust,
    private and secure internet. This is no longer an argument about
    pure speed, although LumoSQL is not slower than SQLite as far as we
    know to date.
4.  **No**, nobody can be really definitive about SQLite this way or
    that, because of the dearth of benchmarking or testing and complete
    absence of published results. We have started to address this
    already. 
5.  **Yes**, LMDB underneath SQLite has some key benefits over SQLite
    including in concurrency support and file integrity.
6.  **No**, we are not going to carry forward any of the LMDB prototype code. 
    But it will forever live on fondly in our hearts.

Facts Established by 2019 LumoSQL Prototype
-------------------------------------------

Using both technical and non-technical means, the LumoSQL Prototype project
established in a matter of a few person-weeks that:

-   The SQLite project has built-in problems (some of them in this chapter)
    that LumoSQL can address in part, while remaining a compatible superset of SQLite
    at both API and on-disk level, and not forking SQLite.

-   The porting and archeology involved in getting sqlightning going as
    an LMDB backend to SQLite was quite a lot more work than taking existing working
    code for other K-V store backends, most of which are currently maintained and in use. 

-   All major SQL databases including SQLite suffer from historical
    architecture decisions, including the use of Write Ahead Logs to do
    concurrency, and lack of validation by default at the data store
    level. This is a particularly big failing for SQLite given its emphasis on 
    file format on IoT devices.

-   All major SQL databases other than SQLite are in the millions of
    lines of source code, compared to SQLite at 350k SLOC . The
    difference is not due to the embedded use case. Some are tens of millions.

-   There is a great lack of published, systematic test results for multiple databases. There is no
    online evidence of SQLite tests being run regularly, and there
    are no published results from running SQLite test code . The same is true
    for all the other major databases. Even with continuous integration tools,
    do any open source database developers include testing in their published
    CI results? We could not find any.

-   There is no published SQLite benchmarking. LumoSQL has done some,
    and published it. We plan to do a lot more.

-   Benchmarking databases in a way which both reflects the real world and is
    also repeatable and general is difficult, and while SQLite is easier than
    the other databases because of its simplicity, the paper [Dangers and
    complexity of sqlite3
    benchmarking](https://www.cs.utexas.edu/~vijay/papers/apsys17-sqlite.pdf)
    highlights the difficulty "...changing just one parameter in SQLite can change
    the performance by 11.8X... up to 28X difference in performance".  We have
    developed some benchmarking solutions we think will practically benefit
    thousands of projects used on the internet, and hopefully change their practice
    based on information they can verify for themselves.

Lessons Learned from sqlightning
--------------------------------

* LMDB, SQLite Btree.c, BDB and ComDB are all quite similar transactional
  KV stores compared to all others in open source, and all written in C. 
  We are sure that with a little wrapping and perhaps one bugfix, LMDB
  can fully express the SQLite KV store semantics and vice versa. The same
  is true for BDB.

* btree.c:sqlite3BtreeBeginTrans had some internal LMDB cursor
   structures. Rewrote using the LMDB API instead; more tests passed .

* The SQL spec allows a transaction to be opened without specifying whether it is RO
   or RW. The sqlightning code handled the upgrade case of RO->RW by copying the
   transaction to a new (larger) RW structure, copying its cursors and restarting.
   This results in an "internal error" when the original btree.c returns "database
   is locked"; we have now fixed this bug in the modified btree.c to match the behaviour
   of the original btree.c . 

* There are only limited tests available for SQLite (visible in public)
   that exercise concurrency, races and deadlocks. There is a lot of
   scope for these sorts of problems and we need to address them at many
   levels including testing specifically for this.

* SQLite does not have sophisticated concurrent transaction handling
   compared to Postgresql, Oracle and MariaDB etc, being much more ready
   to return 'LOCKED' rather than some concurrency algorithms. We will
   return to this problem in later versions of LumoSQL.
   
   




