# LumoSQL Database v0.3 Released

10th November 2020

The [LumoSQL](https://lumosql.org/src/lumosql) project provides answers to questions not many people 
are asking about SQLite. SQLite is easily both the most-used database *and* most-used K-V store
in the world, and so these questions are relevant:

* How much faster is SQLite improving, version on version, and with various switches selected?
* What would SQLite look like if it used a more modern journaling model instead of WAL files?
* Would it be nice for BDB, the ancient Berkeley Database, to magically appear as an SQLite storage backend?
* Does SQLite work faster if it has [LMDB](http://www.lmdb.tech/doc/) as a storage backend?
* How on earth do you benchmark SQLite anyway, and compare with itself and others?

[LumoSQL is SQLite gently modified](https://lumosql.org/src/lumosql/doc/tip/README.md) to have 
multiple different backends, with [benchmarking](https://lumosql.org/benchmarking) and more. 
There is also the separate [LumoDoc](https://lumosql.org/src/lumodoc/) 
project, which isn't just documentation for LumoSQL but also the results of our research and
testing, including a 
[list of relevant codebases](https://lumosql.org/src/lumodoc/doc/trunk/doc/lumo-relevant-knowledgebase.md). 

The last talk at the **SQLite and Tcl 
Conference** [later on today](https://sqlite.org/forum/forumpost/521ebc1239) will by Dan Shearer
speaking about LumoSQL. So we thought we should make the first public release... and here it is.

## History

Long-time SQLite watchers may recall some prototype code by Howard Chu in 2013
called "sqlightning", which was btree.c modified to call LMDB internals. That code is
what inspired LumoSQL. LumoSQL 0.3 has had significant code contributions from 
first Keith Maxwell and then Uilebheist in assisting the project founder, Dan Shearer. 
One of our main achievements is to demonstrate how much more code is needed, so patches 
are welcomed. Do please drop in on the [LumoSQL forum](https://lumosql.org/src/lumosql/forum) or otherwise
[consider contributing](https://lumosql.org/src/lumosql/doc/tip/CONTRIBUTING.md). Many 
others have helped significantly with LumoSQL 0.3, including [NLNet](https://nlnet.nl) with sponsorship,
besides a long list of essential cheerleaders, encouragers and practical supporters.

## The Big Honking End Goal

The end goal is to develop a stable backend storage API in SQLite. This depends on 
many things, including being minimally invasive and maximally pleasing to drh :-)
Even if it cannot be committed to SQLite for some good reason, we will be able to 
carry it in LumoSQL.

But before we can even think of a storage API we need to understand what
different backends might be and what they need. Even key-value stores with
quite similar APIs such as SQLite native, LMDB and BDB have different
understandings of MVCC, key sizes, locking and more. The proposed API would
need to abstract all of this. We've been studying the interactions between
src/vdbe*, btree* and pager* as some may have noticed on the SQLite forum. 
There are not very many MVCC K-V stores suitable for linking to an embedded C
library, but we want to collect all those that are.

## Nope, Not a Fork

LumoSQL has avoided forking SQLite by developing the
[not-forking](https://lumosql.org/src/not-forking) tool. This tool could 
be helpful for anyone trying to stay in synch with multiple upstreams. It
knows how to fetch sources, parse version numbers and make non-controversial merges
even in cases where a straight patch or fossil merge would fail. It can also replace
entire files, and more.

# LumoSQL Features as of version 0.3

```
$ make what
SQLITE_VERSIONS=3.34.0           # whatever the latest version is
USE_LMDB=yes
SQLITE_FOR_LMDB=3.8.3.1
LMDB_VERSIONS=0.9.9 0.9.16 0.9.27
USE_BDB=yes
SQLITE_FOR_BDB=3.18.2
BDB_VERSIONS=
BDB_STANDALONE=18.1.32
TARGETS=
    3.34.0
    3.8.3.1
    3.18.2
    3.8.3.1+lmdb-0.9.9
    3.8.3.1+lmdb-0.9.16
    3.8.3.1+lmdb-0.9.27
    +bdb-18.1.32                 # the +means it is not yet a clean LumoSQL not-fork config
```

This [builds](https://lumosql.org/src/lumosql/doc/tip/doc/lumo-test-build.md) the versions listed.
With [Not-forking](https://lumosql.org/src/not-forking) we can
walk up and down the version tree. 

```
make benchmark
```

Will perform some fairly simple operations on all targets, storing results in a
single SQLite 3.33.0 database.  This database is intended to persist, and to be
amalgamated with results from others. While some basic query and fsck-like
tools are provided, LumoSQL hopes that people with skills in statistics and
data presentation will work their magic with this interesting new dataset. The
design is meant to encourage addition of new parameters and dimensions to the
benchmarking.

```
make benchmark TARGETS=3.7.17+lmdb-0.9.26+datasize-10
```

Runs the same benchmarks, except that all of the operations have a zero added to them, so
25000 SELECTs becomes 250000. Other size factors can be chosen.

# Results So Far

* The not-forking approach works. Yes we are going to be able to "try before we buy" a storage API
* Benchmarking works. It's got a long way to go, but even this much is a powerful new way of
  comparing SQLite versions
* SQLite has improved considerably in performance in the last five years
* SQLite+LMDB performs better than SQLite as dataset sizes increase (testing is incomplete though)
* SQLite+MDB don't perform at all well... in fact, worse than a very much older vanilla SQLite.
  (Some would hesitate to use SQLite+MDB in production anyway given that MDB
  is under the AGPL licence, and SQLite is a library and thus anything using it would also be
  covered by the AGPL.)

There are some less-technical results too, like the fact that there are
many developers around the world who have modified SQLite in interesting ways
but there has been no effective way for their work to be compared or evaluated.
Oh and, we're using Fossil, definitively so.

# Where Next for LumoSQL?

* Walk up the SQLite version tree to tip. We're all waiting to see what SQLite 3.33.0+LMDBv1.0rc1 will be like.
* Complete our work moving LMDB to only use liblmdb as a fully-external library
* Do some concurrency benchmarking, possibly addressing a potential concurrency problem with LMDB 
  in the process. Concurrency is not SQLite's strong point, so this will be very interesting 
* Possibly increase the SQLite version supporting BDB. This is a very important use case because
  the BDB API is both classic and yet also not LMDB, meaning if we get it right then we get it
  right for other K-V stores
* Produce lots more benchmarking data with our existing tools. That means lots of CPU time, and we'd
  love to have volunteers to help populate this  
* First draft backend API taking into account issues relating to keys, transactions, internal
  SQLite close couplings, etc.
* Talk to the active SQLite forks ... if you're reading this, we'd love to hear from you :-)

And that is LumoSQL release 0.3. We look forward to seeing those who can make it to the SQLite and Tcl 
Conference later on today at https://sqlite.org/forum/forumpost/521ebc1239 , and to producing more
releases in quick succession.
