# Replace a few sqlite3 files

method = replace
--
.lumosql/lumo.mk                       =  files/lumo.mk
.lumosql/lumo.build                    =  files/lumo.build
.lumosql/lumo-backend-defs.h           =  files/lumo-backend-defs.h
src/lumo-sha3.c                        =  files/lumo-sha3.c
src/lumo-vdbeInt.h                     =  files/lumo-vdbeInt.h
src/blake3.h                           =  files/blake3/blake3.h
src/blake3_impl.h                      =  files/blake3/blake3_impl.h
src/lumo-blake3.c                      =  files/blake3/blake3.c
src/lumo-blake3_dispatch.c             =  files/blake3/blake3_dispatch.c
src/lumo-blake3_portable.c             =  files/blake3/blake3_portable.c

