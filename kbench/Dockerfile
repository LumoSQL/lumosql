FROM fedora:latest

RUN dnf install -y \
        git make gcc ncurses-devel readline-devel glibc-devel autoconf tcl-devel tclx-devel openssl-devel fossil wget perl-ExtUtils-MakeMaker perl-Digest-SHA perl-FindBin perl-Text-Glob patch lsscsi

RUN wget -O- https://lumosql.org/src/not-forking/tarball/trunk/Not-forking-trunk.tar.gz | tar -zxf - && \
        cd Not-forking-trunk && \
        perl Makefile.PL && \
        make INSTALL_PREFIX=/usr && \
        make install INSTALL_PREFIX=/usr && \
        cd && rm -rf Not-forking-trunk

ENV USER=nobody

COPY work-loop.sh /usr/local/bin/work-loop.sh
