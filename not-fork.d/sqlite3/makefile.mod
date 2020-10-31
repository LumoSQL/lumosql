# add an include of lumosql-specific things in the top-level makefile; we get
# two files, one from the backend and one from sqlite3 (as modified by not-fork)

# we could make this a bit easier to read by extending the "sed" method
# in not-forking; this will be done at some point

method = sed
--
Makefile.in : '\n#\s*libtool\s' = \ninclude $(LUMO_SOURCES)/sqlite3/.lumosql/lumo.mk\n# libtool 

