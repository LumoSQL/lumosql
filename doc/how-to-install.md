<!-- SPDX-License-Identifier: AGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors, 2019 Oracle -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, 2020 -->

<!-- toc -->

# Install LumoSQL

Installation consists of obtaining all relevant 3rd party dependencies (tcl, tclx, perl with modules TextGlob and Git, file, gnumake, gzip, gnutar, fossil or git, wget or curl), then downloading and installing the not-forking tool as an executable command, and downloading LumoSQL build tools that work currently as `make` commands. 

### Containers


The maintainers are test building LumoSQL on Debian, Fedora, Gentoo and Ubuntu.
Container images with the dependencies installed are available at
<https://quay.io/repository/keith_maxwell/lumosql-build> and the build steps are
in <https://github.com/maxwell-k/containers>.



### Installing Not-forking

This step requires perl with Text::Glob and a few other core modules, not-forking installation will inform you if the relevant modules are missing on your system, more information on installing it on different systems can be found below, as well as with the [not-forking documentation](https://lumosql.org/src/not-forking/doc/trunk/README.md).


```
wget -O- https://lumosql.org/src/not-forking/tarball/trunk/Not-forking-trunk.tar.gz | tar -zxf -
cd Not-forking-trunk
perl Makefile.PL
make
sudo make install      
```


### Build LumoSQL

Dependencies needed for this step include (tcl, tclx, file, gnumake, gzip, gnutar, fossil or git, wget or curl). Read below for more information on installing them on your distribution of choice.

```
fossil clone https://lumosql.org/src/lumosql
cd lumosql
make what
```
`fossil` command can be replaced with `git` or `wget`

`make what` will show which taregts will be built by typing `make`


Now you can build different target databases and benchmark them. For make options read the [quickstart](../README.md#using-the-build-and-benchmark-system) and the [build and benchmark system](./lumo-build-benchmark.md) sections.


## Installing on Popular Distributions

### Perl Modules

The default Perl installation on Debian/Ubuntu is perl-base, and on Fedora/Red
Hat is perl-core. These have nearly all the Perl modules required except for Text::Glob.

For example, on a Debian or Ubuntu system, as root type:

```
# apt install libtext-glob-perl
```

Or on a Fedora/Red Hat system, as root type:

```
# dnf install perl-text-glob
```

Or on a Gentoo system, as root type:

```
emerge --ask dev-perl/Text-Glob
```

On FreeBSD:

```
pkg install perl5 p5-Text-Glob
# for the complete list of recommended programs to access source repositories:
pkg install fossil perl5 git p5-Git-Wrapper curl p5-Text-Glob patch
```

On minimal operating systems such as often used with [Docker](https://docker.io) there is just
a basic Perl package present. You will need to add other modules including ExtUtils::MakeMaker,
Digest::SHA, Perl::Git, File::Path and Perl::FindBin .

Not-forking will inform you of any missing Perl modules.

## Download and Install Not-Forking

To download Not-forking, you can use `fossil clone` or `git clone`, or,  to download with wget:

```
wget -O- https://lumosql.org/src/not-forking/tarball/trunk/Not-forking-trunk.tar.gz | tar -zxf -
cd Not-forking-trunk
```

Once you have downloaded the Not-forking source, you can install it using:

```
perl Makefile.PL
make
sudo make install       # You need root for this step, via sudo or otherwise
```

If you are on a minimal operating system you may be missing some Perl modules
as decsribed above. The command ```perl Makefile.PL``` will fail with a helpful
message if you are missing modules needed to build Not-forking. Once you have
satisfied the Not-forking *build* dependencies, you can check that Not-forking
has everything it could possibly need by typing:

```
not-fork --check-recommend
```

and fixing anything reported as missing, or which is too old in cases where that matters.

At which point the `not-fork` command is installed in the system and its
required modules are available where your perl installation expects to
find them.



## Build Environment and Dependencies for LumoSQL build

#### Debian or Ubuntu-derived Operating Systems

Uncomment existing `deb-src` line in /etc/apt/sources.list, for example
for Ubuntu 20.04.2 a valid line is:
<b>
```
deb-src http://gb.archive.ubuntu.com/ubuntu focal main restricted
```
</b>

Then run
<b>
```
sudo apt update                              # this fetches the deb-src updates
sudo apt full-upgrade                        # this gets the latest OS updates
sudo apt install git build-essential tclx
sudo apt build-dep sqlite3
```
</b>

The *exact* commands above have been tested on a pristine install of Ubuntu
20.04.2 LTS, as installed from ISO or one of the operating systems shipped with
Windows Services for Linux.


#### Fedora-derived Operating Systems

On any reasonably recent Fedora-derived Linux distribution, including Red Hat:

```sh
<b>
sudo dnf install --assumeyes \
  git make gcc ncurses-devel readline-devel glibc-devel autoconf tcl-devel tclx-devel
```
</b>

#### Common to all Linux Operating Systems



* Recommended: [Fossil](https://fossil-scm.org/). As described above, you don't necessarily need Fossil. But Fossil is very easy to install: if you can't get version 2.13 or later from your distrbution then it is easy to build from source. 
  (*Note!* Ubuntu 20.04, Debian Buster and Gentoo do not include a sufficiently modern Fossil, while NetBSD
  and Ubuntu 20.10 do.) Since you now have a development environment anyway you can 
  [build Fossil trunk according to the official instructions](https://fossil-scm.org/home/doc/trunk/www/build.wiki) or this simpler version (tested on Ubuntu 20.04 LTS):
    * wget -O- https://fossil-scm.org/home/tarball/trunk/Fossil-trunk.tar.gz |  tar -zxf -
    * sudo apt install libssl-dev
    * cd Fossil-trunk ; ./configure ; make
    * sudo make install


* For completeness (although every modern Linux/Unix includes these), to build and benchmark any of the Oracle Berkeley DB targets, you need either "curl" or "wget", and also "file", "gzip" and GNU "tar". Just about any version of these will be sufficient, even on Windows.


* If you are running inside a fresh [Docker](https://docker.io) or similar container system, Fossil may be confused about the user id. One solution is to add a user (eg "adduser lumosql" and answer the questions) and then "export USER=lumosql".



On [Debian 10 "Buster" Stable Release](https://www.debian.org/releases/buster/), the not-forking makefile
("perl Makefile.PL") will warn that git needs to be version 2.22 or higher.
Buster has version 2.20, however this is not a critical error. If you don't
like error messages scrolling past during a build, then install a more recent
git [from Buster backports](https://backports.debian.org/Instructions/).


Now you have the dependencies installed, clone the LumoSQL repository using
`fossil clone https://lumosql.org/src/lumosql` , which will create a new subdirectory called `lumosql` and
a file called `lumosql.fossil` in the current directory.

Try:
<b>
```
cd lumosql
make what
```
</b>

To see what the default sources and options are. The `what` target does not make any changes although it may generate a file `Makefile.options` to help `make` parse the command line.



