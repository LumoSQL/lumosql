# extra stuff we may need to add when building LumoSQL

# note: the order is important, backend first, then sqlite3
ifneq ($(LUMO_BACKEND),)
include $(LUMO_SOURCES)/$(LUMO_BACKEND)/.lumosql/lumo.mk
TCC += -I$(LUMO_SOURCES)/$(LUMO_BACKEND)/.lumosql
endif

TCC += -I$(LUMO_SOURCES)/sqlite3/.lumosql

