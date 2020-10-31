# Add some files needed for the LumoSQL build

method = replace
--
.lumosql/lumo.mk                    =  files/lumo.mk
.lumosql/lumo.build                 =  files/lumo.build
libraries/liblmdb/mdb_lumo_extras.c =  files/mdb_lumo_extras.c
libraries/liblmdb/mdb_lumo_extras.h =  files/mdb_lumo_extras.h

.lumosql/backend/lumo_backup.c      =  files/backup.c
.lumosql/backend/lumo_btmutex.c     =  files/btmutex.c
.lumosql/backend/lumo_btree.c       =  files/btree.c
.lumosql/backend/lumo_btreeInt.h    =  files/btreeInt.h
.lumosql/backend/lumo_pager.c       =  files/pager.c
.lumosql/backend/lumo_pager.h       =  files/pager.h
.lumosql/backend/lumo_wal.c         =  files/wal.c

