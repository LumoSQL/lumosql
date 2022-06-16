<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->


Table of Contents
=================

   * [SQLite API Interception Points](#sqlite-api-interception-points)
     


![](./images/lumo-implementation-intro.jpg "Metro Station Construction Futian Shenzhen China, CC license, https://www.flickr.com/photos/dcmaster/36740345496")



SQLite API Interception Points
------------------------------

LumoSQL identifies choke points at which APIs can be intercepted to provide modular choices for backends, front-end parcers, encryption and networking.


   The API interception points are:

  1. Setup APIs/commandline/Pragmas, where we pass in info about what
front/backends we want to use or initialise. Noting that SQLite is
zero-config and so supplying no information to LumoSQL must always be an option.
Nevertheless, if a user wants to select a particular backend, or have
encryption or networking etc there will be some setup. Sqlite.org provides a
large number of controls in pragmas and the commandline already.

  2. SQL processing front ends. Code exists (see [Relevant Codebases](./context-relevant-codebases.md)
that implements MySQL-like behaviour in parallel with supporting SQLite semantics.
There is a choice codebases to do that with, covering different approaches to the problem.

  3. Transaction interception and handling, which in the case of the LMDB
backend will be pass-through but in other backends may be for replicated
storage, or backup. This interception point would be in ```wal.c``` if all
backends used a writeahead log and used it in a similar way, but they do not.
Instead this is where the new ```backend.c``` API interception point will be
used - see further down in this document.  This is where, for example, we can
choose to add replication features to the standard SQLite btree storage
backend.

  4. Storage backends, being a choice of native SQLite btree or LMDB today, and
swiftly after that other K-V stores. This is the choke point where we expect to
introduce [libkv](./context-relevant-codebases.md#libkv), or a modification of libkv.

  5. Network layers, which will be at all of the above, depending whether they
are for client access to the parser, or replicating transactions, or being
plain remote storage etc.

In most if not all cases it needs to be possible to have multiple choices
active at once, including the obvious cases of multiple parsers and multiple
storage backends, for example. This is because one of the important new use
cases for LumoSQL is conversion between formats, dialects and protocols.

Having designed the API architecture we can then produce a single LumoSQL tree
with these choke point APIs in place and proof of two things:

1. ability to have stock-standard identical SQLite APIs and on-disk
btree format, and

2. an example of an alternative chunk of code at each choke point:
MySQL; T-pipe writing out the transaction log in a text file; LMDB .
Not necessarily with the full flexibility of having all code active at
once if that's too hard (ie able to take any input SQL and store in
any backend)

   and then, having demonstrated we have a major step forward for the entire world,

3. Identify what chunks of SQLite we really don't want to support any more.
   Like maybe the ramdisk pragma given that we can/should/might have an
in-memory storage backend, which initially might just be LMDB with overcommit
switched off. This is where testing and benchmarking really matters.

