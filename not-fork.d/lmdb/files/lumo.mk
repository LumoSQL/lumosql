# Extra Makefile stuff to link as a LumoSQL backend

TCC += -I$(LUMO_BUILD)/lumo/build
TLIBS += -L$(LUMO_BUILD)/lumo/build
TLIBS += -llmdb

