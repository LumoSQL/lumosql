---
title: LumoSQL Project Repositories
---

**Non-technical Introduction**

This is the home of [LumoSQL](https://lumosql.org/src/lumosql/), which is a
modification of [SQLite](https://sqlite.org), the world's [most-used
software](https://www.sqlite.org/famous.html). LumoSQL adds privacy, security
and performance options to SQLite, but stays carefully within the SQLite
project's software guidelines and does not seek to replace SQLite. Several of
LumoSQL's features can be enabled in a standard SQLite database without
disturbing traditional SQLite in any way.

All LumoSQL code is licensed under the [MIT open source
license](https://license.lumosql.org), perhaps the [most-used license](https://en.wikipedia.org/wiki/MIT_License).

LumoSQL is compliant with the mandatory privacy and security requirements of legislation based on 
[Article 7](https://fra.europa.eu/en/eu-charter/article/7-respect-private-and-family-life) and
[Article 8](https://fra.europa.eu/en/eu-charter/article/8-protection-personal-data) of the 
[EU Charter of Fundamental Rights](https://fra.europa.eu/en/eu-charter). Many countries outside Europe have similar legislation. SQLite cannot offer this, and yet is used at enormous scale for handling personal data within the EU and these other countries.

When LumoSQL becomes a readily-available option just like SQLite, this will
have implications for almost all mobile phone users, motor vehicles, web
browsers and many other kinds of embedded software. This software will then have 
a database which:

* Is not stored in plain text. LumoSQL's [at-rest encryption](https://en.wikipedia.org/wiki/Data_at_rest#Encryption) means that personal data is more secure.
* Checks for corruption. LumoSQL notices if the data it reads is not identical to the data it wrote. That might sound obvious, but no mainstream database does this yet!
* May be faster, depending on what your application is doing.
* Gives the user the option to keep data encrypted even if it is transferred to the cloud. Only when the user hands over a password can the data be decrypted, and even then the user might decide to only give the password for a portion of the data.

In the latter half of 2022 we hope there will be a usable general release, accompanied by documentation for end users.

**Technical Introduction**

LumoSQL provides new features for SQLite:

* Security. LumoSQL's design provides page-level encryption. There are commercially-licensed code patches that will add this to SQLite, but open source solutions are very limited. Security cannot be assured without open source, so this is an essential feature we have added to SQLite.
* Corruption detection and prevention. LumoSQL offers per-row checksums invisible to the application by default, but optionally visible and available to be operated on. This feature behaves like the existing SQLite ROWID column, implemented via additional hidden columns. No other mainstream database has this feature.
* Fine-grained Security. Using the hidden columns feature, LumoSQL is able to provide per-row encryption, meaning that some rows might be visible to a particular user while other rows are not.
* An encrypted equivalent to JSON called Lumions, usable in any application. [Lumions are an early draft standard](https://lumosql.org/src/lumosql/doc/tip/doc/rfc/README.md) and offer Attribute Based Encryption, versioning, strong GUID, checksumming and more. This RFC is ambitious but sufficiently limited in scope that it seems possible it could become a universal tool for privacy-compliant cloud-portable data.
* Alternative key-value stores. Every database has a key-value store underneath it, but only LumoSQL has the ability to swap key-value stores with full functionality. The native SQLite Btree can be replaced with LMDB, and with a sufficiently general API that other key-value stores are equally possible. We are very interested in 21st-century K-V stores such as Adaptive Radix Trees and Fractal Trees.

The techniques used to implement LumoSQL contain some important advances:

* LumoSQL [does not fork SQLite](https://lumosql.org/src/not-forking). SQLite is conservative about breaking compatibility due to its immense userbase, but LumoSQL applies new features to the current codebase or any previous version. This means that the SQLite project can experiment with alternate futures for its architecture and design, while LumoSQL does not have to carry the burden of forking such a successful and intricate codebase.
* LumoSQL provides a user-selectable matrix of code versions. As of today, some 600 combinations of SQLite versions and LMDB versions can be builts, tested and benchmarked. This matrix will grow as more key-value store backends are implemented via the LumoSQL backend API.
* Measurement-based. LumoSQL has an [extensive benchmarking toolset](https://lumosql.org/src/lumosql/doc/tip/doc/lumo-build-benchmark.md) which allows anyone to run their own benchmarks, store the results in a standard SQLite file, and then aggregate them. We have some early [graphical results](http://r.lumosql.org:3838/contrastexample.html) for the first ten thousand benchmark runs. We measure across platforms, versions, time and data size among other variables, and we are doing [careful statistical modelling](https://lumosql.org/src/lumosql/dir?ci=tip&name=analysis/contrasts).
* Recording prior art. For both the encryption and database design parts of LumoSQL we have gathered and annotated references in BibLaTeX format. Some of these are exported as part of the Lumions RFC.

LumoSQL is supported by [NLnet](https://nlnet.nl).


