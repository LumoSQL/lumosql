# add some functions to mdb.c and lmdb.h to allow controlled access to some
# LMDB internals; this may be a temporary measure to get the sqlightning
# code working without including the whole mdb.c

# we could simplify this by making changes to the not-forking sed method

method = sed
--
mdb.c : \z = \n#include "mdb_lumo_extras.c"\n
lmdb.h : \z = \n#include "mdb_lumo_extras.h"\n

