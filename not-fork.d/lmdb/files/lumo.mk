# Extra Makefile stuff to link as a LumoSQL backend

TCC += -I$(LUMO_SOURCES)/$(LUMO_BACKEND)
TLIBS += -L$(LUMO_BUILD)/$(LUMO_BACKEND)
TLIBS += -llmdb

