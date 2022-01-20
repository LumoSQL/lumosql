# LumoSQL "Happy New Year" Team Meeting

**Dan Shearer, dan@lumosql.org**

**19th January 2022**

It's 2022, and we're starting Phase II of LumoSQL, so we had an irc Meeting libera.chat#lumosql Friday January 14th 2022 1300 CET. These first notes in Phase II have a lot of explanation in them, for people wanting to know what the LumoSQL team is up to.

- [Introduction](#introduction)
- [LumoSQL Core](#lumosql-core)
- [Lumions](#lumions)
- [Documentation](#documentation)
- [Project Organisation](#project-organisation)

<a name="introduction"></a>
# Introduction

Present: Gabby (Guest84), Claudio (Labhraich), Ruben De Smet (rubdos), Björn Johansson (BKJ621), Dan (danshearer), Tom Godden

This meeting was to catch up with what everyone is thinking about for LumoSQL Phase II, agree on immediate tasks and improve organisation.

Next meeting: January 21st 1300 CET

Björn has agreed to be responsible for organising future meetings and doing minutes. Thanks Björn.

<a name="lumosql-core"></a>
# LumoSQL Core

This month is about making sure the proof of concept LumoSQL still works, and designing what the production LumoSQL will look like. This means coordinating with SQLite.org and with the theoretical work from VUB. The proof of concept add a checksum column, and automatically updates the checksum when the row changed, and automatically verifies the checksum when the row is read. This was all transparent to existing SQLite binaries using a database that has these hidden columns present. The current task is to extend the hidden columns concept adds arbitary columns to all user-generated tables in a database, for arbitary purposes supported by code inserted in the core of SQLite. This is how encryption will be supported As well as checksums, and the [Lumion concept](https://lumosql.org/src/lumosql/doc/trunk/doc/rfc/README.md) implemented. Hidden columns are similar to the [SQLite ROWID column](https://www.sqlite.org/rowidtable.html), except without the apology at the bottom of the page for all the problems required by backwards compatibility. Hidden columns are transparent to all LumoSQL backends.

ACTION Labhraich supported by Dan: Check LumoSQL with current SQLite and LMDB versions.

ACTION Labhraich: Redesign and rewrite hidden columns proof of concept. Start with more fixed API including maybe some pragmas and other mechanisms.

ACTION Labhraich and Dan: Take hidden column API to SQLite.org for discussion, once a draft has been committed to the LumoSQL Fossil.

ACTION Labraich: Implement a way to handle SQLite's giant potential index size within LMDB's limited index size.

ACTION Dan: Commit refactored and properly documented btree.h (finally!) to sqlite.org. Because LumoSQL is roaring back into the btree modication business.

<a name="lumions"></a>
# Lumions

The Lumions concept is only a few weeks old. It applies Role Based Encyrption/[Attribute Based Encryptioni](https://en.wikipedia.org/wiki/Attribute-based_encryption) models to LumoSQL on a per-row basis, using the hidden columns technique. Lumions also would seem to be a good data storage format for the [Glycos](https://gitlab.com/etrovub/smartnets/glycos/) project at VUB. This would mean there are two independent implementations of Lumions from the beginning, which is ideal. We are developing a draft RFC for Lumions. Ruben says he will be 80% research and specification, with 20% implementation and benchmarking of Lumions. Björn wants to assist with review of drafts.

ACTION rubdos: Lumions: Document literature review items and initial design thoughts, especially relating to models for LumoSQL; check this work in to the LumoSQL repo.

ACTION rubdos supported by Dan: Lumions: Consider using existing LumoSQL benchmarking suite to compare approaches in both LumoSQL and Glycos.

ACTION Labhraich: check in Latex version of IEEE paper to LumoSQL Fossil, directly or via Dan proxy.

<a name="documentation"></a>
# Documentation

This has been slow to get going but there are no more blockers. The toolset is not polished (needs a script and/or a Makefile) and there is a new task related to presentation of benchmark results.

ACTION Gabby: Evaluate publishing the benchmarking results on the website in some searchable and comparable form.

ACTION Dan: meet with Gabby to assist with specification and contents of documentation.

ACTION Gabby: Conclude if the existing Chinese pictures theme is a good idea or not.

ACTION Dan: Take advice from Gabby and create Pandoc makefile with suitable scripts.

ACTION Dan: design the backend for submitting LumoSQL benchmarking databases and amalgamating them for Gabby's front end. Discuss with team. (Not clear if a web service to accept benchmark databases submitted by the world is still classed as "documentation", but it will do for now.)

<a name="project-organisation"></a>
# Project Organisation

Björn and Dan seem to have solved most of the big blockers.

(✅ DONE) ACTION Dan: Implement [Leantime](https://leantime.io) for LumoSQL for those team members who are interested in it.

(✅ DONE) ACTION Björn: Review Leantime implementation and advise Dan about what has to change. Design workflow, especially for creative aspects.

ACTION Dan: Change irc channel to point at https://lumosql.org/src/lumosql/doc/tip/doc/LumoSQL-PhaseII-Announce.md

ACTION Dan: implement meeting bot https://hcoop-meetbot.readthedocs.io/en/stable/ for next meeting to assist Björn in producing minutes.

ACTION Björn: Work through LumoSQL contacts in Management Wiki with Dan. We have some technical skills that would be helpful to have, and some organisations are clearly working in this area already.

ACTION Björn: Work out if it is even feasible to have the in-person funded LumoSQL sprint we had planned! (Fix pandemic first?)
