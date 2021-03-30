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

# this will be replaced by a runtime option and a PRAGMA later
ifeq ($(OPTION_LMDB_TRANSACTION),noupgrade)
TCC += -DLUMO_LMDB_TRANSACTION=0
else
ifeq ($(OPTION_LMDB_TRANSACTION),optimistic)
TCC += -DLUMO_LMDB_TRANSACTION=1
else
TCC += -DLUMO_LMDB_TRANSACTION=2
endif
endif

TCC += -g

