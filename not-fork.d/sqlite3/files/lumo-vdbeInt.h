#ifdef LUMO_EXTENSIONS

#ifndef _LUMO_VDBEINT_
#define _LUMO_VDBEINT_ 1

#define LUMO_END_TYPE 0

#ifdef LUMO_ROWSUM
typedef struct lumo_rowsum_spec {
    const char * name;
    int length;
    void (*generate)(unsigned char *, const void *, unsigned int);
    size_t mem;
    void (*init)(void *);
    void (*update)(void *, const void *, unsigned int);
    void (*final)(void *, unsigned char *);
} lumo_rowsum_spec;

extern const lumo_rowsum_spec lumo_rowsum_algorithms[];
extern const int lumo_rowsum_n_algorithms;

typedef struct lumo_rowsum_alias_spec {
    const char * name;
    unsigned int same_as;
} lumo_rowsum_alias_spec;

extern const lumo_rowsum_alias_spec lumo_rowsum_alias[];
extern const int lumo_rowsum_n_alias;

/* default value when creating a new table */
extern unsigned int lumo_rowsum_algorithm;

/* how we check the rowsum: 0, we don't check it at all; 1, we check it
** if present, but don't require it; 2, we require it to be there and
** check it */
extern int lumo_extension_check_rowsum;
#endif /* LUMO_ROWSUM */

/* how much space will be needed to add Lumo extensions to some data,
 * or 0 if there are no extensions to add */
int lumoExtensionLength(int, const unsigned char *, unsigned int, unsigned int);

/* the actual lumo extension data, the result buffer must have at
 * least the space indicated by lumoExtensionLength */
void lumoExtension(int, const unsigned char *, unsigned int, unsigned int,
		   const unsigned char *, unsigned int, unsigned char *);

/* take a packed record and add the Lumo extension data; it allocates a
** new buffer which needs to be freed by the caller; if the first argument
** is NULL, it is allocated with sqlite3MallocZero, if not NULL with
** sqlite3DbMallocZero */
int lumoExtensionAdd(sqlite3 *, int, const unsigned char *, sqlite3_int64,
		     sqlite3_int64, unsigned char **, sqlite3_int64 *);

/* see if a Lumo column is present */
int lumoExtensionPresent(int, u32, u32, u64, u32, const unsigned char *,
			 u32, u64, u64 *, u64 *);

/* handle data in a Lumo column, if it is really a Lumo column; return 0
** if not handled (not a Lumo column), 1 if OK, -1 if error */
int lumoExtensionHandle(int, const unsigned char *, u64, u64, VdbeCursor *);

/* function to call when no metadata was found: this could be an error if
** we were expecting to find it; return 0 if error, 1 if OK */
int lumoExtensionMissing(sqlite3 *);

#endif /* _LUMO_VDBEINT_ */
#endif /* LUMO_EXTENSIONS */
