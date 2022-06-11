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


# Automated Meeting Notes With lumosql-meetbot

We use [HcoopMeetbot](https://hcoop-meetbot.readthedocs.io) to make irc meetings simpler and easier.

Normal irc chat is ignored by the bot, but chat that tagged as part of meeting
goes in the notes. Any user on the #lumosql channel can participate in a
meeting, or call one.

Meetings notes automatically appear in the [Meetbot log directory](https://lumosql.org/meetings) as soon as 
the meeting is finished.

This Meetbot helps us remember the important information immediately, and the action items.

# How to Use the Meetbot

In the #lumosql chat room on the [libera chat network](https://libera.chat Libera), you should see a logged-in user
called "lumosql-meetbot". This is a bot, and its purpose is to hang around waiting until someone
says "#startmeeting" in the chat. From then on, it listens for more instructions preceded with "#".

You can read all the details in the help page above. These are the commands we need for LumoSQL meetings:

* **#startmeeting**            Anyone can start a meeting, and is then the chair until **#endmeeting** is issued.
* **#meetingname \<descriptive name\>**             Important! The chair should specify this, because it gets extracted as the comment in the [table of meetings](https://lumosql.org/meetings).
* **#here**                    List yourself as an attendee. Everyone should do this at the beginning because it looks neater in the notes.
* **#topic**                   Start a new topic, that is a section heading in the meeting notes.
  * **#info \<text\>**           Add a bullet item under the current topic heading.
  * **#link \<link\> \<text\>**    The supplied URL gets added under the current topic heading as a clickable HREF link.
  * **#action \<nick\> \<text\>**  Assign an action item to user \<nick\> eg *#action bk712 to make the coffee*. Always use the irc nickame instead of a human-like name such as "Björn", because otherwise the Meetbot won't assign the actions properly at the end.
  * **#accepted \<text\>**       Log an agreement we have made, eg *#accepted we are all going home now*.
  * **#motion \<text\>**         The chair can propose any motion for voting, eg *#motion Vanilla icecream is best*.
  * **#vote +1 / -1**          Anyone can vote +1 or -1. The meetbot will allow people to vote multiple times, to correct a mistaken vote.
  * **#help \<text\>           Add a request for people to volunteer for a task in the notes. If you are looking for Meetbot help, then see **#commands** below.
  * **#close**                 The chair closes the vote, and the meetbot summarises the results.
* **#endmeeting**              End the meeting. The formatted minutes and raw log magically appear in a few seconds.
* **#commands**          get a list of all the valid commands, and be reminded of the URL of the help page.

It's a great tool, thanks to [Kenneth J. Pronovici](https://github.com/pronovic) and others.

You can address the bot directly and chat with it, including by the shortcut "@ \<text\>". You'll find out about that in the online help.

> <font size="6"> &#9757;&#127998; </font> The meeting logs are just HTML files, so if something *really* incorrect gets into the notes by accident we can edit them manually. But this should be very rare.

>    Obviously, chat in #lumosql is covered by the [LumoSQL Code of Conduct](../CODE-OF-CONDUCT.md), which says "be a decent person".


