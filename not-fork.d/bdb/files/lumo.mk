# Extra Makefile stuff to link as a LumoSQL backend

TCC += -I$(LUMO_BUILD)/$(LUMO_BACKEND)/src -I$(LUMO_BUILD)/$(LUMO_BACKEND)/build_unix
TLIBS += -L$(LUMO_BUILD)/$(LUMO_BACKEND)/build_unix/.libs -rpath $(LUMO_BUILD)/$(LUMO_BACKEND)/build_unix/.libs
TLIBS += -ldb

