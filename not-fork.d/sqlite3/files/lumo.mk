# extra stuff we may need to add when building LumoSQL

# note: the order is important, backend first, then sqlite3
ifneq ($(LUMO_BACKEND_NAME),)
include $(LUMO_BUILD)/lumo/build/.lumosql/lumo.mk
TCC += -I$(LUMO_BUILD)/lumo/build/.lumosql
endif

TCC += -I$(LUMO_SOURCES)/sqlite3/.lumosql

HAS_LUMO_EXTENSIONS := no

ifeq ($(OPTION_ROWSUM),on)
TCC += -DLUMO_ROWSUM=on
HAS_LUMO_EXTENSIONS := yes
endif

ifeq ($(HAS_LUMO_EXTENSIONS),yes)
TCC += -DLUMO_EXTENSIONS=1
endif

