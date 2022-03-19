<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->


LumoSQL
=======

![](./images/lumo-logo-temp.svg "LumoSQL logo")




Welcome to the LumoSQL project, which builds on the excellent
[SQLite](https://sqlite.org/) project without forking it.  LumoSQL is an SQL database
which can be used in embedded applications identically to SQLite, but also
optionally with different storage backends and other additional behaviour.
LumoSQL emphasises benchmarking, code reuse and modern database implementation.

* [About LumoSQL](./1.1-front-page.md)

## Why Choose LumoSQL

Our goal is to build a reliable and secure database management system that is fully open-source and improves on the performance on SQLite. 

- 100% downstream and upstream compatibility with [SQLite](https://sqlite.org), with same command line interface.

- Modular [backends](./backends.md).

- Stability through [corruption detection](./lumo-corruption-detection-and-magic.md) and [rollback journaling](./WALs.md).

- Reliably tested and [benchmarked](./3.3-benchmarking.md). 

- [Top Features](./1.2-top-features.md)
	
- [Get LumoSQL](./1.4-install-LumoSQL.md)


Table of Contents
=================
* About the Project
	* [About LumoSQL](./1.1-front-page.md)
	* [Install LumoSQL](./1.4-install-LumoSQL.md)
	* [Contribute to LumoSQL](../CONTRIBUTING.md)
	* [Legal Aspects](./3.2-legal-aspects.md)
	* [Code of Conduct](../CODE-OF-CONDUCT.md)

* Implementation
	* [Goals](./1.2-top-features.md)
	* [Benchmarking](./3.3-benchmarking.md)
	* [Not-Forking Tool](./3.4-not-forking-tool.md)
	* [Test Build](./3.5-lumo-test-build.md)
	* [Backends](./backends.md)
	* [Encryption](./encryption.md)

* Research
	* [SQLite Development Landscape](./2.1-development-landscape.md)	
	* [Relevant Knowledgebase](./2.4-relevant-knowledgebase.md)
	* [Relevant Codebases](./3.7-relevant-codebases.md)
	* [Scaling DBMS](./online-database-servers.md)
	* [Write Ahead Logs](./WALs.md)
	* [Savepoints in SQLite](./what-are-savepoints.md)
	* [Conclusions Prior to Development](./3.6-development-notes.md)
	* [API Points](./api.md)
	* [Virtual Machine Layer](./virtual-machine.md)



