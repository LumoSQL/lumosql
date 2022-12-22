# Licensing

This directory contains the licence which applies to all material in the LumoSQL project.

# MIT Licence

The [MIT Licence](https://en.wikipedia.org/wiki/MIT_License) applies to all
files in this project. The MIT licence is the most-widely used Open Source
licence, including by some of the world's largest companies. The MIT licence
grants everyone the right to use the code for any purpose under copyright law.
Every LumoSQL file should have a copyright statement at the top and also a
[Software Package Data Exchange](https://spdx.dev) machine-readable header.
Even if a file does not have these statements at the top, the MIT licence still
applies to all files in the LumoSQL source tree including files that are not
clearly code, such as configuration or input data.

The [LumoSQL Documentation](https://web.lumosql.org) has source files in /doc
in the LumoSQL source tree and therefore also covered by the MIT licence.
Documentation-specific licences do exist and they do have certain advantages.
If the MIT licence ever becomes a problem for LumoSQL documentation we will
adopt one of these licenses.

Some user interface code for the R statistical analysis package is included
under /analysis. All of this code is licensed under MIT by the respective authors.

To even further avoid potential misunderstanding, we maintain the site
[license.lumosql.org](https://license.lumosql.org) with the full text of the MIT Licence.

# Exception for academic papers

We do include some academic papers in full in the source tree under
/references. Evidently, these papers are copyright their respective authors and
universities as listed.

# No other exceptions

Licenses can be a confusing topic, but LumoSQL really does have no exceptions.

The MIT license covers the *source* tree for LumoSQL. When you start LumoSQL
development, the LumoSQL build tool pulls in code from other projects such as
SQLite and LMDB and combines them to produce binaries in the build/ directory.
LumoSQL does not pull code from projects with licenses incompatible with the
MIT license. The binaries produced by LumoSQL can be used for any purpose.

An example of an interesting licensing case (although the technology is not at
all interesting) is the discontinued and deprecated Berkeley DB backend.
The BDB code is available under the AGPL license, which means that any code
(such as SQLite) combined with it is also under the terms of the AGPL, and so
are any binaries using BDB.  The AGPL requires that code be made available to
anyone provided with the binary... which LumoSQL and SQLite comply with, so
there is no conflict. But none of this is even a question with the LumoSQL
source tree as distributed.  When you type "make" you are then pulling and
building code which has other licenses, and we are careful about that too.
