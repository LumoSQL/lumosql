<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->

![](./images/lumo-legal-aspects-intro.png "XXXXXXXX")

Table of Contents
=================

   * [LumoSQL Licensing](#lumosql-licensing)
   * [Why MIT? Why Not MIT?](#why-mit-why-not-mit)
   * [In Detail: Patents, MIT and Apache 2.0](#in-detail-patents-mit-and-apache-20)
   * [In Detail: the SQLite Public Domain Licensing Problem](#in-detail-the-sqlite-public-domain-licensing-problem)
   * [History and Rationale](#history-and-rationale)
   * [Encryption Legal Issues](#encryption-legal-issues)
   * [LumoSQL Requirements and Decisions](#lumosql-requirements-and-decisions)

# LumoSQL Licensing

SQLite is released as [Public Domain](https://www.sqlite.org/copyright.html).
In order to both respect and improve on this, the [LumoSQL Project Aims](lumo-projet-aims.md) make this promise to SQLite users:

> LumoSQL will not come with legal terms less favourable than SQLite. LumoSQL
> will try to improve the legal standing and safety worldwide as compared to
> SQLite.

To achieve this LumoSQL has made these policy decisions:

* New LumoSQL code is licensed under the [MIT License](https://opensource.org/licenses/MIT), as used by many large corporations worldwide
* LumoSQL documentation is licensed under the [Creative Commons](https://creativecommons.org/licenses/by-sa/4.0/)
* Existing and future SQLite code is relicenced by the act of being distributed under the terms of the MIT license
* Open Source code from elsewhere, such as backend data stores, remain under the terms of the original license except where distribution under MIT effectively relicenses it
* Open Content documentation from elsewhere remains under the terms of the original license. No documentation is used in LumoSQL unless it can be freely mixed with any other documentation. 

The effect of these policy decisions are:

* LumoSQL users gain certainty as compared with SQLite users because they have a
license that is recognised in jurisdictions worldwide. 

* LumoSQL users do not lose any rights. For example, the MIT license permits use
with fully proprietary software, by anyone. Whatever users do today with
SQLite they can continue to do with LumoSQL. 

* While MIT does require users to include a copy of the license and the
copyright notice, the MIT license also permits the user to remove the
sentence requiring this from the license (thus re-licensing LumoSQL.) 

# Why MIT? Why Not MIT?

Github's [License Chooser for MIT](https://choosealicense.com/licenses/mit/) describes the MIT as:

> A short and simple permissive license with conditions only requiring
> preservation of copyright and license notices. Licensed works, modifications,
> and larger works may be distributed under different terms and without source
> code. 

The MIT license aims to get out of the way of software developers, and despite
some flaws it appears to do so reliably.

In addition, MIT is popular. As documented [on Wikipedia](https://en.wikipedia.org/wiki/MIT_License) MIT appears to be the most-used open source licenses. Popularity matters, because all licenses are in part a matter of community belief and momentum.  Microsoft releasedi
 [.NET Core](https://en.wikipedia.org/wiki/.NET_Core) and Facebook released
[React](https://en.wikipedia.org/wiki/React_(web_framework)) under the MIT, and
these companies are very cautious about the validity of the licenses they use.

In a forensic article analysing [the 171 words of the MIT license](https://writing.kemitchell.com/2016/09/21/MIT-License-Line-by-Line.html) as they apply in the US, lawyer Kyle E. Mitchell writes in his conclusion:

> The MIT License is a legal classic. The MIT License works. It is by no means
> a panacea for all software IP ills, in particular the software patent
> scourge, which it predates by decades. But MIT-style licenses have served
> admirably... We’ve seen that despite some crusty verbiage and lawyerly
> affectation, one hundred and seventy one little words can get a hell of a lot
> of legal work done, clearing a path for open-source software through a dense
> underbrush of intellectual property and contract.

Overall, in LumoSQL we have concluded that the MIT license is solid and it is
better than any other mainstream license for existing SQLite users. It is
certainly better than the SQLite Public Domain terms.

# In Detail: Patents, MIT and Apache 2.0

LumoSQL has a narrower range of possible licenses because of its nature as an
embedded library, where it is tightly combined with users' code. This means
that the terms and conditions for using LumoSQL have to be as open as possible
to accommodate all the different legal statuses of software that users combine
with LumoSQL. And the status that worries corporate lawyers the most is
"unknown". What if you aren't completely sure of the patent status of the
software, or the intentions of your company? And where there is uncertainty,
users are wise not to commit.

LumoSQL has tried hard to bring more certainty, not less, and this is tricky when it comes to patents.

Software patents are an issue in many jurisdictions. The MIT license includes a
grant of patents to its users, as [explained by the Open Source Initiative](https://opensource.com/article/18/3/patent-grant-mit-license),
including in the grant "... to deal in the software without restriction." While the
Apache 2.0 license specifically grants patent rights (as do the GPL and MPL), they are not more generous than the MIT license. There is some debate that varies by jurisdiction about exactly how clear the patent grant is, as documented in [the patent section on Wikipedia](https://en.wikipedia.org/wiki/MIT_License#Relation_to_patents).

The difficulty is that the Apache 2.0 (similar to the GPL and MPL) license also
includes a *patent retaliation* clause:

> If You institute patent litigation against any entity (including a
> cross-claim or counterclaim in a lawsuit) alleging that the Work or a
> Contribution incorporated within the Work constitutes direct or contributory
> patent infringement, then any patent licenses granted to You under this
> License for that Work shall terminate as of the date such litigation is
> filed.  

The intention is progressive and seemingly a Good Thing - after all, unless you
are a patent troll who wants more pointless patent litigation? However the
effect is that the Apache 2.0 license brings with it the requirement to check
for patent issues in any code it is connected to. It also is possible that the
company using LumoSQL actually does want the liberty to take software patent
action in court. So whether by the risk or the constraint, Apache 2.0 brings with it
significant change compared to SQLite's license terms in countries that recognise them. 

MIT has only a patent grant, not retaliation. That is why LumoSQL does not use the Apache 2.0 license.


# In Detail: the SQLite Public Domain Licensing Problem

There are numerous reasons other than licensing why SQLite is less open source
than it appears, and these are covered in the [LumoSQL Landscape](./lumo-landscape.md). As to licensing, SQLite is distributed as
Public Domain software, and this is mentioned by D Richard Hipp in his [2016 Changelog Podcast Interview](https://changelog.com/podcast/201). Although he is aware of the problems, Hipp has decided not to introduce changes.

The [Open Source Initiative](https://opensource.org/node/878) explains the Public Domain problem like this:

> “Public Domain” means software (or indeed anything else that could be
> copyrighted) that is not restricted by copyright. It may be this way because
> the copyright has expired, or because the person entitled to control the
> copyright has disclaimed that right. Disclaiming copyright is only possible
> in some countries, and copyright expiration happens at different times in
> different jurisdictions (and usually after such a long time as to be
> irrelevant for software). As a consequence, it’s impossible to make a
> globally applicable statement that a certain piece of software is in the
> public domain.

Germany and Australia are examples of countries in which Public Domain is not
normally recognised which means that legal certainty is not possible for users
in these countries who need it or want it. This is why the Open Source
Initiative does not recommend it and nor does it appear on the [SPDX License List](https://spdx.org/licenses/).

The SPDX License List is a tool used by many organisations to understand where they stand legally with the millions of lines of code they are using. David A Wheeler has produced a helpful [SPDX Tutorial](https://github.com/david-a-wheeler/spdx-tutorial) . All code and documentation developed by the LumoSQL project has a SPDX identifier.

# History and Rationale

SQLite Version 1 used the gdbm key-value store. This was under the GPL and
therefore so was SQLite. gdbm is limited, and is not a binary tree. When
Richard Hipp replaced it for SQLite version 2, he also dropped the GPL. SQLite
has been released as "Public Domain"


# Encryption Legal Issues

SQLite is not available with encryption. There are two common ways of adding encryption to SQLite, both of which have legal implications: 

1. Purchasing the [SQLite Encryption Extension](https://www.hwaci.com/sw/sqlite/see.html)(SEE) from Richard Hipp's company Hwaci. The SEE is proprietary software, and cannot be used with open source applications.
2. [SQLcipher](https://www.zetetic.net/sqlcipher/) which has a open core model. The BSD-licensed open source version requires users to publish copyright notices, and the more capable commercial editions are available on similar terms to SEE, and therefore cannot be used with open source applications. 

There are many other ways of adding encryption to SQLite, some of which are listed in the [Knowledgebase Relevant to LumoSQL](./lumo-relevant-knowledgebase.md).

The legal issues addressed in LumoSQL encryption include:

* Usability. Encryption should be available with LumoSQL in the core source code without having to consider any additional legal considerations.
* Unencumbered. No encryption code is used that may reasonably be subject to action by companies (eg copyright claims) or governments (eg export regulations). Crypto code will be reused from known-safe sources.
* Compliant with minimum requirements in various jurisdictions. With encryption being legally mandated or strongly recommended in many jurisdictions for particular use cases (banking, handling personal data, government data, etc) there are also minimum requirements. LumoSQL will not ship crypto code that fails minimum crypto requirements.
* Conspicuously *non-compliant* with maximum requirements in any jurisdiction. LumoSQL will not limit its encryption mechanisms or strength to comply with any legal restrictions, in common with other critical open source infrastructure. LumoSQL crypto tries to be as hard to break as possible regardless of the use case or jurisdiction.

