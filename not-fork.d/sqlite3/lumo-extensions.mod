# Add a symbol for "lumo extensions"

method = sed
--
src/btree.h : \z = \n#define BTREE_LUMO_EXTENSIONS 0x1000000\n

