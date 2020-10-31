# Extra Makefile stuff to link as a LumoSQL backend

TCC += -I$(LUMO_SOURCES)/$(LUMO_BACKEND)/libraries/liblmdb
TLIBS += -L$(LUMO_BUILD)/$(LUMO_BACKEND)
TLIBS += -rpath $(LUMO_BUILD)/$(LUMO_BACKEND)
TLIBS += -llmdb

