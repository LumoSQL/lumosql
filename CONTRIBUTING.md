# Contributing to the LumoSQL Project

If you wish to make any changes to [the LumoSQL project’s files][home], here are
some rules and hints to keep in mind while you work. The 
[Documentation Project](https://lumosql.org/src/lumodoc/) is separate,
and has its own contribution rules.

We try to keep the barriers to contribution low, which is assisted by
our decision to use [Fossil].

If you are familiar with Fossil, you will be able to start using 
the [LumoSQL Build, Test and Benchmarking][testbuild] system straight
away. However the rest of this document has useful non-technical information
about contributing too.


[home]: https://lumosql.org/src/lumosql
[testbuild]: https://lumosql.org/src/lumosql/doc/tip/doc/lumo-test-build.md


## <a id="ghm"></a> The GitHub Mirror Is One-way

The LumoSQL [Fossil] repository is the official home for
this project. The GitHub mirror is largely one-way, as you may guess
from the name. You’re welcome to file GitHub issues or send PRs via
GitHub, but we’ll push the change back up through Fossil repo, so 
the resulting change won’t have any direct connection to the social 
graph maintained by GitHub, Inc.

If you want an exact clone of the LumoSQL project repo, or if you wish to
contribute to the project’s development with full credit for your
contributions, it’s best done via Fossil, not via GitHub.

[Fossil]: https://fossil-scm.org/


## <a id="gs-fossil"></a> Getting Started with Fossil

The LumoSQL software project is hosted using the Fossil
[distributed version control system][dvcs], which provides most of the
features of GitHub without [the complexities of Git][fvg].

Those new to Fossil should at least read its [Quick Start Guide][fqsg],
followed by [the official Fossil docss][fdoc]. You can download
[precompiled binaries][fbin] or [install from source](bffs); either way, make 
sure you have Fossil 2.14 or higher.

If you have questions about Fossil, ask on [the Fossil forum][ffor].

[bffs]:   https://fossil-scm.org/home/doc/trunk/www/build.wiki
[fbin]:   https://fossil-scm.org/index.html/uv/download.html
[fvg]:    https://fossil-scm.org/home/doc/trunk/www/fossil-v-git.wiki
[dvcs]:   https://en.wikipedia.org/wiki/Distributed_revision_control
[fdoc]:   https://fossil-scm.org/home/doc/trunk/www/permutedindex.html
[ffor]:   https://fossil-scm.org/forum/
[fqsg]:   https://fossil-scm.org/home/doc/trunk/www/quickstart.wiki


## <a id="fossil-anon" name="anon"></a> Fossil Anonymous Access

The fossil clone command has the same syntax as git:

    $ fossil clone https://lumosql.org/src/lumosql
    $ cd lumosql

but if we create a particular directory structure then Fossil can be used for
its strengths, as we show in later sections of this document:

    $ mkdir -p ~/src/lumosql-trees
    $ cd ~/src/lumosql-trees
    $ fossil clone https://lumosql.org/src/lumosql
    $ cd lumosql

That results in a clone of the `lumosql.fossil` repository plus a check-out
of the current trunk in a `lumosql/` directory alongside it, both of them
underneath `lumosql-trees`. 

Once you have done this, you will just be working with the cloned repository.

You only need to do this once per machine. 

## <a id="login"></a> Fossil Developer Access

If you have a developer account on the `lumosql.org/src/lumosql` Fossil
instance, just add your username to the URL like this:

    $ fossil clone https://USERNAME@lumosql.org/src/lumosql 

If you’ve already cloned anonymously, simply tell Fossil about the new
sync URL instead:

    $ cd ~/src/lumosql/trunk
    $ fossil sync https://USERNAME@lumosql.org/src/lumosql

Either way, Fossil will ask you for the password for `USERNAME` on the
remote Fossil instance, and it will offer to remember it for you. If
you let it remember the password, operation from then on is almost the
same as working with an anonymous clone, except that on checkin,
your changes will be sync’d back to the repository on lumosql.org if
you’re online at the time, and you’ll get credit under your developer
account name for the checkin.

If you’re working offline, Fossil will still do the checkin locally, and
it will sync up with the central repository after you get back online.
It is best to work on a branch when unable to use Fossil’s autosync
feature, as you are less likely to have a sync conflict when attempting
to send a new branch to the central server than in attempting to merge
your changes to the tip of trunk into the current upstream trunk, which
may well have changed since you went offline.

You can purposely work offline by disabling autosync mode:

    $ fossil set autosync 0

Until you re-enable it (`autosync 1`) Fossil will stop trying to sync your
local changes back to the central repo.  We recommend disabling autosync mode
only when you are truly going to be offline and don’t want Fossil attempting to
sync when you know it will fail.


## <a id="gda"></a> Getting Developer Access

We are pretty open about giving developer access.

One way to get developer access is to provide one good, substantial [patch](#patches) 
to LumoSQL. If we’ve accepted one of your patches, we will listen when you ask for a 
developer account.

If you have other ways of contributing then you should also get in touch. Code patches 
are not the only kind of contribution, although they are the main one.

## <a id="tags" name="branches"></a> Working with Existing Tags and Branches

This is one of Fossil's great strengths. The level under the recommended 
project directory (`~/src/lumosql`) stores multiple separate
checkouts, one for each version the developer is actively working with at the moment,
so to add a few other checkouts, you could say:

    $ cd ~/src/lumosql
    $ mkdir -p release          # another branch
    $ mkdir -p v20191215        # a tag this time, not a branch
    $ mkdir -p 2020-12-05       # the software as of a particular date
      ...etc...
    $ cd release
    $ fossil open ~/src/lumosql.fossil release
    $ cd ../v201951215
    $ fossil open ~/src/lumosql.fossil v20191215
    $ cd ../2020-12-05
    $ fossil open ~/src/lumosql.fossil 2020-12-05
      ...etc...

This gives you multiple independent checkouts, which allows you to
quickly switch between versions with “`cd`” commands. The alternative
(favored by Git and some other version control systems) is to use a
single working directory and switch among versions by updating that
single working directory in place. The problem is that this
invalidates all of the build artifacts tied to changed files, so you
have a longer rebuild time than simply switching among check-out
directories. It’s better to have multiple working states and
just “`cd`” among them.

When you say `fossil update` in a check-out directory, you get the “tip”
state of that version’s branch. This means that if you created your
“`release`” check-out while version 2017.01.23 was current and you say
“`fossil update`” today, you’ll get the release version 2020.12.05 or
later. But, since the `v20191215` tag was made on trunk, saying
“`fossil update`” in that check-out directory will fast-forward you to the tip of
trunk; you won’t remain pinned to that old version. This is one of the
essential differences between tags and branches in Fossil, which are at
bottom otherwise nearly identical.

The LumoSQL project uses tags for [each released version][tags], and it
has [many working branches][brlist]. You can use any of those names in
“`fossil open`” and “`fossil update`” commands, and you can also use any
of [Fossil’s special check-in names][fscn].

[brlist]: https://lumosql.org/src/lumosql/brlist
[fscn]:   https://fossil-scm.org/home/doc/trunk/www/checkin_names.wiki
[fvg]:    https://fossil-scm.org/home/doc/trunk/www/fossil-v-git.wiki
[gitwt]:  https://git-scm.com/docs/git-worktree
[tags]:   https://lumosql.org/src/lumosql/taglist


## <a id="branching"></a> Creating Branches

Creating a branch in Fossil is very simple.

    $ fossil ci --branch new-branch-name

That is to say, you make your changes as you normally would; then when
you go to check them in, you give the `--branch` option to the
`ci/checkin` command to put the changes on a new branch, rather than add
them to the same branch the changes were made against.

While developers with login rights to the LumoSQL Fossil instance are
allowed to check in on the trunk at any time, we recommend using
branches whenever you’re working on something experimental, or where you
can’t make the necessary changes in a single understandable checkin.

One of this project’s core principles is that `trunk` should always
build without error, and it should always function correctly. We do
try to achieve this, but don't always succeed.

Alternatively, developers may use branches to isolate work
until it is ready to merge into the trunk. It is okay to check work in
on a branch that doesn’t work, or doesn’t even *build*, so long as the
goal is to get it to a point that it does build and work properly before
merging it into trunk.

This is a difference with Git: because Fossil normally syncs
your work back to the central repository, this means we get to see the
branches you are still working on. This is a *good thing*. Do not fear
committing broken or otherwise bad code to a branch. [You are not your
code.][daff] We are software developers, too: we understand that
software development is an iterative process, that not all ideas are
perfect.  These public branches let your collaborators see what
you’re up to; they may be able to lend advice, to help with the work, and
they won't be unsurprised when your change finally lands in trunk.

Fossil fosters close cooperation, whereas Git fosters wild tangents that
never come back home.

Jim McCarthy (author of [Dynamics of Software Development][dosd]) has a
presentation on YouTube that touches on this topic at a couple of
points:

*   [Don’t go dark](https://www.youtube.com/watch?v=9OJ9hplU8XA)
*   [Beware of a guy in a room](https://www.youtube.com/watch?v=oY6BCHqEbyc)

Fossil’s sync-by-default behavior fights these negative tendencies.

LumoSQL project developers are welcome to create branches at will. The
main rule is to follow the branch naming scheme: all lowercase with
hyphens separating words. See the [available branch list][brlist] for
examples to emulate.

If you have checkin rights on the repository, it is generally fine to check
things in on someone else’s feature branch, as long as you do so in a way that
cooperates with the purpose of that branch. The same is true of `trunk`: if you
are going to make a major change then ask first.  This is yet another use for
branches: to make a possibly-controversial change so that it can be discussed
before being merged into the trunk.

[daff]: http://www.hanselman.com/blog/YouAreNotYourCode.aspx
[dosd]: http://amzn.to/2iEVoBL


## <a id="special"></a> Special Branches

Most of the branches in the LumoSQL project are feature branches of the
sort described in the previous section: an isolated line of development
by one or more of the project’s developers to work towards some new
feature, with the goal of merging that feature into the `trunk` branch.

There are a few branches in the project that are special, which are
subject to different rules than other branches, such as "release". 
LumoSQL is too young yet to have worked the system of branches out 
exactly.

## <a id="forum"></a> Developer Discussion Forum

The “[Forum][pfor]” link at the top of the Fossil web interface is for
discussing LumoSQL development and LumoSQL generally.  You can sign up for the
forums without having a developer login, and you can even post anonymously. If
you have a login, you can [sign up for email alerts][alert] if you like.

Keep in mind that posts to the Fossil forum are treated much the same
way as ticket submissions and wiki articles. They are permanently
archived with the project. The “edit” feature of Fossil forums just
creates a replacement record for a post, but the old post is still
available in the repository. Don’t post anything you wouldn’t want made
part of the permanent record of the project!

[pfor]: https://lumosql.org/src/lumosql/forum
[alert]: https://lumosql.org/src/lumosql/alerts


## <a id="patches"></a> Submitting Patches

If you do not have a developer login on the LumoSQL repository,
you can still send changes to the project.

The simplest way is to say this after developing your change against the
trunk of LumoSQL:

    $ fossil diff > my-changes.patch

Then either upload that file somewhere (e.g. Pastebin) and point to it
from a [forum post][pfor] . You will need to declare you are using the
LumoSQL licence. 

If your change is more than a small patch, `fossil diff` might not
incorporate all of the changes you have made. The old unified `diff`
format can’t encode branch names, file renamings, file deletions, tags,
checkin comments, and other Fossil-specific information. For such
changes, it is better to send a Fossil bundle:

    $ fossil set autosync 0                # disable autosync
    $ fossil checkin --branch my-changes
      ...followed by more checkins on that branch...
    $ fossil bundle export --branch my-changes my-changes.bundle

After that first `fossil checkin --branch ...` command, any subsequent
`fossil ci` commands will check your changes in on that branch without
needing a `--branch` option until you explicitly switch that checkout
directory to some other branch. This lets you build up a larger change
on a private branch until you’re ready to submit the whole thing as a
bundle.

Because you are working on a branch on your private copy of the
LumoSQL Fossil repository, you are free to make as many checkins as
you like on the new branch before giving the `bundle export` command.

Once you are done with the bundle, send it to the developers the same
way you should a patch file.

If you provide a quality patch, we are likely to offer you a developer
login on [the repository][repo] so you don’t have to continue with the
patch or bundle methods.

Please make your patches or experimental branch bundles against the tip
of the current trunk. PiDP-8/I often drifts enough during development
that a patch against a stable release may not apply to the trunk cleanly
otherwise.

[repo]:  https://lumosql.org/src/lumosql


## <a id="code-style"></a> LumoSQL Coding Rules

Style Guide Goes here...

