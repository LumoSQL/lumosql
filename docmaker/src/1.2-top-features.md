<!--- SPDX-License-Identifier: CC-BY-SA-4.0 --->
<!--- SPDX-FileCopyrightText: 2020 The LumoSQL Authors --->
<!--- SPDX-ArtifactOfProjectName: LumoSQL --->
<!--- SPDX-FileType: Documentation --->
<!--- SPDX-FileComment: Original by Dan Shearer, 2020 --->


Table of Contents
=================

   * [Overall Objective of LumoSQL](#overall-objective-of-lumosql)
   * [The Advantages of LumoSQL](#the-advantages-of-lumosql)
   * [Development Goals](#developmenr-goals)


![](./images/lumo-project-aims-intro.jpg "Mongolian horseback archery, rights request pending from https://www.toursmongolia.com/")

Overall Objective of LumoSQL
============================

	To create Privacy-compliant Open Source Database Platform with Modern Design and Benchmarking,
	usable either embedded or online.

This is the guide for every aspect of the project, which will ensure that
LumoSQL offers features that money can't buy, and drawing together an
SQLite-related ecosystem.

LumoSQL is based on SQLite. It aims to incorporate all of the [features of SQLite](https://www.sqlite.org/features.html) and improve it many ways.


Development Goals
====

* SQLite upstream promise: LumoSQL does not fork SQLite, and offers 100%
  compatibility with SQLite by default, and will contribute to SQLite where possible.
  This especially includes the SQLite user interface mechanisms of pragmas, 
  library APIs, and commandline parameters.


* [Legal promise](./3.2-legal-aspects.md): LumoSQL does not come with legal terms less favourable than 
  SQLite. LumoSQL will aim to improve the legal standing and safety worldwide
  as compared to SQLite. 


* Developer contract: LumoSQL has [stable APIs](./api.md) ([Application Programming Interfaces](https://en.wikipedia.org/wiki/Application_programming_interface#Libraries_and_frameworks)) for features found in multiple unrelated SQLite downstream projects:
  backends, frontends, encryption, networking and more. 

* Devops contract: LumoSQL reduces risk by making it possible to omit
  compilation of unneeded features, and has stable ABIs ([Application Binary Interfaces](https://en.wikipedia.org/wiki/Application_binary_interface)) so as to not break dynamically-linked applications.

* Ecosystem creation: LumoSQL will offer consolidated contact, code curation, bug tracking,
  licensing, and community communications across all these features from
  other projects. Bringing together SQLite code contributions under one umbrella reduces 
  technical risk in many ways, from inconsistent use of threads to tracking updated versions.



LumoSQL Design
================

* LumoSQL has three canonical and initial backends: btree (the existing
SQLite btree, ported to a new backend system); the LMDB backend; and the BDB
backend. Control over these interfaces is through the
same user interface mechanisms as the rest of LumoSQL, and SQLite.


* LumoSQL improves SQLite quality and privacy compliance by introducing
optional on-disk checksums for storage backends including the original
SQLite btree format.  This allows real-time row-level [corruption detection](./lumo-corruption-detection-and-magic.md).

* LumoSQL improves SQLite quality and privacy compliance by introducing
[optional storage backends](./backends.md) that are more crash-resistant than SQLite btree (such as LMDB)
and more oriented towards complete recovery (such as BDB).

* LumoSQL improves SQLite integrity in persistent storage by introducing
optional row-level checksums.

* LumoSQL provides the benefits of Open Source by being an open project
and continuing to accept and review contributions in an open way, using
Fossil and having diverse [contributors](../CONTRIBUTING.md).


* LumoSQL improves SQLite design by intercepting [APIs](./api.md) at a very small
number of critical choke-points, and giving the user optional choices at
these choke points. The choices are for alternative storage backends,
front end parsers, encryption, networking and more, all without removing
the [zero-config](https://sqlite.org/zeroconf.html) and embedded advantages of SQLite

* LumoSQL provides a means of tracking upstream SQLite, by making
sure that anything other than the API chokepoints can be synched at each
release, or more often if need be.


* LumoSQL provides updated public [testing tools](), with results published
and instructions for reproducing the test results. This also means
excluding parts of the LumoSQL test suite that don't apply to new backends

* LumoSQL provides [benchmarking tools](./3.3-benchmarking.md), otherwise as per the testing
tools.


* LumoSQL ensures that new code remains optional by means of [modularity](./3.5-lumo-test-build.md) at
compiletime and also runtime. By illustration of modularity, at compiletime
nearly all 30 million lines of the Linux kernel can be excluded giving just 200k
lines. Runtime modularity is controlled through the same user interfaces 
as the rest of LumoSQL.

* LumoSQL ensures that new code may be active at once, eg.
multiple backends or frontends for conversion between/upgrading from one
format or protocol to another. This is important to provide continuity and
supported upgrade paths for users, for example, users who want to become
privacy-compliant without disrupting their end users.

* Over time, LumoSQL will carefully consider the potential benefits of dropping
some of the most ancient parts of SQLite when merging from upstream, provided
it does not conflict with any of the other goals in this document. Eliminating 
SQLite code can be done by a similar non-forking mechanism as used to keep in synch
with the SQLite upstream. Patches will be offered to sqlite.org




