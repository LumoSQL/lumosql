<!-- SPDX-License-Identifier: AGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors, 2019 Oracle -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->

# Welcome to LumoSQL

![](./images/lumo-logo-temp.svg "LumoSQL logo")

LumoSQL is a project under active developement. Our goal is to build a reliable and secure database management system that is fully open-source and improves on the performance on classic SQLite. 

* 100% downstream and upstream compatibility with [SQLite](https://sqlite.org), with same command line interface.

* Modular [backends](./about-backends.md).

* Stability through [corruption detection](./design-corruption-detection-and-magic.md) and [rollback journaling](./context-wals.md).

* Reliably tested and [benchmarked](./about-benchmarking.md). 

NEWS! - [LumoSQL Phase II announcement](./project-announce-phase2.md)

## [Phase II](https://lumosql.org/src/lumosql/doc/trunk/doc/project-announce-phase2.md) (ongoing)

- [**Role-based / attribute-based access control**](./design-rbac.md)
- **Implementation of hidden colums and tables**
- **Row level encryption**
- [**Reseach and design of Lumions**](./rfc/README.md)
  - [Bibliography](../references/lumosql-abe.bib)(download .bib)

## Phase I (complete) 

LumoSQL started as a combination of two embedded data storage C language libraries: [SQLite](https://sqlite.org) and [LMDB](https://github.com/LMDB/lmdb). LumoSQL builds on Howard Chu's 2013 proof of concept [sqlightning](https://github.com/LMDB/sqlightning) combining the two codebases. Howard's LMDB library has become a ubiquitous replacement for [bdb](https://sleepycat.com/) on the basis of performance, reliability, and license so the 2013 claims of it greatly increasing the performance of SQLite seemed credible. D Richard Hipp's SQLite is used in thousands of software projects, and since three of them are Google's Android, Mozilla's Firefox and Apple's iOS, an improved version of SQLite will benefit billions of people.


* **Research**
 

  - [SQLite Development Landscape](./context-development-landscape.md)
  - [What other software implements useful features?](./context-relevant-codebases.md)
  - [What research has been done on SQLite topics?](./context-relevant-knowledgebase.md)
  - [What is the best way to maintain journals?](./context-wals.md)
  - [How database storage systems are scaled?](./context-online-database-servers.md)
  - [What are savepoints in SQLite?](./context-what-are-savepoints.md)
  - [Conclusions prior to development](./context-development-notes.md)


* **Design**

  - [Feaures that LumoSQL will implement](./about-goals.md) 
  - [Identifying the API points of SQLite that LumoSQL will intercept](./design-api.md)
  - [Changes to be made to SQLite virtual machine layer](./design-virtual-machine.md)


*  **Implemented Features**

	> * [**Build**](./lumo-build-benchmark.md)

	> LumoSQL build and testing system allows the user to choose any version of SQLite and any available backend version, as well as other options during build in order to build a database best suited for user's needs. The performance of LumoSQL database can be tested and benchmared using the same tool.

	> * [**Not-Forking tool**](./about-not-forking-tool.md)
	

	> In order to make LumoSQL modular and compatible with a range of upstream versions, we have developed a tool that attempts to automate source code tracking. By tracking changes it avoids project level forking and therefore is called a not-forking tool.

	> * [**LMDB and BDB backends**](./about-backends.md) 

	> LMDB provides a fast and reliable way to store key-value data and has been proven by [Howard Chu](https://github.com/LMDB/sqlightning) to outperform the native SQLite b-tree in some situations.
 
	> * [**Row level checksums**](./design-corruption-detection-and-magic.md)

	> Row level checksums lets us find out if the data has been corrupted and locate the precise row that has been affected, thus making it easier to fix corruption issues.

	> * [**Benchmarking tool**](./about-benchmarking.md)

	> In order to test the performace of LumoSQL and prove or disprove its effectiveness we want to make sure that our benchmarking results are accurate and reproducible.




LumoSQL is currently under development. [Contributions to code and documentation](../CONTRIBUTING.md) are welcome. 


LumoSQL was started in December 2019 by Dan Shearer, who did the original source tree archaeology, patching and test builds. Keith Maxwell joined shortly after and contributed version management to the Makefile and the benchmarking tools. 


LumoSQL is supported by the [NLnet Foundation](https://nlnet.nl/project/LumoSQL/).

Published under [MIT license](./about-legal-aspects.md).
