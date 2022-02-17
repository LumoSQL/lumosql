# On FreeBSD there's a <edit/readline/readline.h> which is really from libedit;
# shell.c expects to find <editline/readline.h> with libedit, which FreeBSD doesn't have
# so, a small conditional patch

# only apply this on FreeBSD
osname = freebsd

# and might as well check that one file exists and the other doesn't
hasfile /usr/include/edit/readline/readline.h !/usr/include/editline/readline.h

# use a short sed expression to do it
method = sed

--
src/shell.c : \n#\s*include\s+<editline/readline.h> = \n#include <edit/readline/readline.h>
src/shell.c.in : \n#\s*include\s+<editline/readline.h> = \n#include <edit/readline/readline.h>

