# extra stuff we may need to add when building LumoSQL

# note: the order is important, backend first, then sqlite3
ifneq ($(LUMO_BACKEND_NAME),)
include $(LUMO_BUILD)/lumo/build/.lumosql/lumo.mk
TCC += -I$(LUMO_BUILD)/lumo/build/.lumosql
endif

TCC += -I$(LUMO_SOURCES)/sqlite3/.lumosql

# rowsum option - first translate from Boolean to enum (none, sha3)
# so we are ready to add more algorithms later
ifeq ($(OPTION_ROWSUM),)
OPTION_ROWSUM := none
else ifeq ($(OPTION_ROWSUM),off)
OPTION_ROWSUM := none
else ifeq ($(OPTION_ROWSUM),on)
OPTION_ROWSUM := sha3
endif

ifneq ($(OPTION_ROWSUM),none)
TCC += -DLUMO_ROWSUM='$(OPTION_ROWSUM)'
TCC += -DLUMO_ROWSUM_ID='LUMO_ROWSUM_ID_$(OPTION_ROWSUM)'
endif

