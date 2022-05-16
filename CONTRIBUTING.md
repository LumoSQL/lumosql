<!-- Copyright 2022 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2022 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2019 -->

# Contributing to the LumoSQL Project

Welcome! We'd love to have your contributions to [the LumoSQL
project’s files][home]. You don't need to be a coder to contribute.
We need help from documenters, cryptographers, mathematicians,
software packagers and graphic designers as well as coders who are
familiar with C, Tcl and other languages. If you know about database
theory and SQL then we definitely want to hear from you :-)

Please do:

* Drop in to #lumosql on [Libera irc chat][libera] , or email [authors@lumosql.org](mailto://authors@lumosql.org).
* Tell us about any problems you have following the [LumoSQL Build, Test and Benchmarking][testbuild] documentation.
* Help us improve the [Lumion design and RFC][lumions].

Things to note:

* The LumoSQL GitHub mirror is one-way. Development happens with [Fossil], which has good documentation and a very [helpful forum][ffor].

# Accessibility

Accessibility means that we make it as easy as possible for
developers to fully participate in LumoSQL development. This starts
with the tools we choose. We use and recommend:

* [Fossil], whose features are available via the commandline as well
  as Javascript-free web pages. (The one exception is the Fossil chat
facility implemented entirely in Javascript, which while interesting
and useful is not something LumoSQL uses.)
* [irc chat][libera], for which there are many accessible clients
* [paste-c](http://paste.c-net.org/) , which is an accessible and
  efficient Pastebin
* [dudle](https://dud-poll.inf.tu-dresden.de/) open source polling and meeting scheduler
* [R](https://www.r-project.org/), a data analysis toolkit
* Unix-like operating systems and commandline toolchains, to nobody's
  surprise :-)

We know these tools do work for many people, including all those
involved with LumoSQL at present.`

# The LumoSQL Timezone is *Brussels local time*

Computers know how to handle [UTC calculations](https://www.utctime.net/utc-time-zone-converter), summer time
etc, but humans don't find it so easy. Who knows which state in which country
is going on or off summer time just now? 

This is the [current time in LumoSQL](https://www.timeanddate.com/time/zone/belgium/brussels): https://www.timeanddate.com/time/zone/belgium/brussels

Brussels is in Belgium. We chose Brussels because:

* A majority of current LumoSQL contributors live in or were born in countries that jump between CET and CEST at the same time as Belgium.
* [ETRO at Vrije Universiteit Brussel](http://www.etrovub.be/) is the only place LumoSQL has ever physically gathered.
* We had to choose something.


[home]: https://lumosql.org/src/lumosql
[testbuild]: doc/lumo-build-benchmark.md
[Fossil]: https://fossil-scm.org/
[ffor]:   https://fossil-scm.org/forum/
[lumions]: doc/rfc/README.md
[libera]: https://libera.chat/
