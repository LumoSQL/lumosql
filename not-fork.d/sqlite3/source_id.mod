# update sqlite3.h to show backend name and version

method = sed
--
# mksqlite3h.tcl will insert the backend name and version number, but
# it needs to be told where to find them
Makefile.in : mksqlite3h.tcl\s+\$\(TOP\) = mksqlite3h.tcl $(TOP) $(LUMO_SOURCES)

# modify mksqlite3h.tcl to get the extra argument and add a variable for the backend info
tool/mksqlite3h.tcl : '\nset\s+TOP\s+\[lindex \$argv 0\]' = \nset TOP [lindex $argv 0]\nset backendId [exec sh $TOP/.lumosql/backend-id [lindex $argv 1]]\n

# and to add the backend information
tool/mksqlite3h.tcl : 'regsub\s+--\s+--VERS--' = regsub -- --SOURCE-ID-- $line "--SOURCE-ID--$backendId" line\n    regsub -- --VERS--

