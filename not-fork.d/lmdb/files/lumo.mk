# Extra Makefile stuff to link as a LumoSQL backend

TCC += -I$(LUMO_BUILD)/lumo/build
TLIBS += -L$(LUMO_BUILD)/lumo/build
TLIBS += -llmdb

ifneq ($(OPTION_LMDB_DEBUG),off)
TCC += -DLUMO_LMDB_DEBUG
ifeq ($(OPTION_LMDB_DEBUG),insert)
TCC += -DLUMO_LMDB_LOG_INSERTS
endif
endif

ifneq ($(OPTION_LMDB_FIXED_ROWID),off)
TCC += -DLUMO_LMDB_FIXED_ROWID
endif

TCC += -DLUMO_BACKEND_PRAGMA

TCC += -g

