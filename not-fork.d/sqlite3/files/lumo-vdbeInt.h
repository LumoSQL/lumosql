#ifdef LUMO_EXTENSIONS

#ifndef _LUMO_VDBEINT_
#define _LUMO_VDBEINT_ 1

#define LUMO_END_TYPE 0

/* help making sure we only look at our data */
#define LUMO_EXTENSION_MAGIC "Lumo"

#ifdef LUMO_ROWSUM

/* declarations needed for the rowsum code */

#include "lumo-sha3.c"

#define BLAKE3_NO_SSE2 1
#define BLAKE3_NO_SSE41 1
#define BLAKE3_NO_AVX2 1
#define BLAKE3_NO_AVX512 1
#include "lumo-blake3.c"
#include "lumo-blake3_dispatch.c"
#include "lumo-blake3_portable.c"

#define LUMO_ROWSUM_TYPE 1

#define LUMO_ROWSUM_ID_none 65535

#define LUMO_ROWSUM_ID_null 0

#define LUMO_ROWSUM_ID_sha3_512 1
#define LUMO_ROWSUM_ID_sha3_384 2
#define LUMO_ROWSUM_ID_sha3_256 3
#define LUMO_ROWSUM_ID_sha3_224 4
#define LUMO_ROWSUM_ID_sha3 LUMO_ROWSUM_ID_sha3_256

#define LUMO_ROWSUM_ID_blake3_512 5
#define LUMO_ROWSUM_ID_blake3_384 6
#define LUMO_ROWSUM_ID_blake3_256 7
#define LUMO_ROWSUM_ID_blake3_224 8
#define LUMO_ROWSUM_ID_blake3 LUMO_ROWSUM_ID_blake3_256

#define LUMO_ROWSUM_DECLARATIONS_sha3(k) \
  static void lumo_init_sha3_##k(void * ctx) { \
    SHA3Init(ctx, k); \
  } \
  static void lumo_update_sha3_##k(void * ctx, const void * p, unsigned int n) { \
    SHA3Update(ctx, p, n); \
  } \
  static void lumo_final_sha3_##k(void * ctx, unsigned char * d) { \
    memcpy(d, SHA3Final(ctx), k / 8); \
  } \
  static void lumo_generate_sha3_##k(unsigned char * d, const void * p, unsigned int n) { \
    SHA3Context ctx; \
    SHA3Init(&ctx, k); \
    SHA3Update(&ctx, p, n); \
    memcpy(d, SHA3Final(&ctx), k / 8); \
  }

LUMO_ROWSUM_DECLARATIONS_sha3(512)
LUMO_ROWSUM_DECLARATIONS_sha3(384)
LUMO_ROWSUM_DECLARATIONS_sha3(256)
LUMO_ROWSUM_DECLARATIONS_sha3(224)

#undef LUMO_ROWSUM_DECLARATIONS_sha3

#define LUMO_ROWSUM_DECLARATIONS_blake3(k) \
  static void lumo_init_blake3_##k(void * ctx) { \
    blake3_hasher_init(ctx); \
  } \
  static void lumo_update_blake3_##k(void * ctx, const void * p, unsigned int n) { \
    blake3_hasher_update(ctx, p, n); \
  } \
  static void lumo_final_blake3_##k(void * ctx, unsigned char * d) { \
    blake3_hasher_finalize(ctx, d, k / 8); \
  } \
  static void lumo_generate_blake3_##k(unsigned char * d, const void * p, unsigned int n) { \
    blake3_hasher ctx; \
    blake3_hasher_init(&ctx); \
    blake3_hasher_update(&ctx, p, n); \
    blake3_hasher_finalize(&ctx, d, k / 8); \
  }

LUMO_ROWSUM_DECLARATIONS_blake3(512)
LUMO_ROWSUM_DECLARATIONS_blake3(384)
LUMO_ROWSUM_DECLARATIONS_blake3(256)
LUMO_ROWSUM_DECLARATIONS_blake3(224)

#undef LUMO_ROWSUM_DECLARATIONS_blake3

#define LUMO_ROWSUM_ELEMENT(a, k, s) \
    [LUMO_ROWSUM_ID_##a##_##k] = { \
	#a "_" #k, \
	k / 8, \
	lumo_generate_##a##_##k, \
	s, \
	lumo_init_##a##_##k, \
	lumo_update_##a##_##k, \
	lumo_final_##a##_##k, \
    },

#define LUMO_ROWSUM_ELEMENT_sha3(k) LUMO_ROWSUM_ELEMENT(sha3, k, sizeof(SHA3Context))
#define LUMO_ROWSUM_ELEMENT_blake3(k) LUMO_ROWSUM_ELEMENT(blake3, k, sizeof(blake3_hasher))

static struct {
    const char * name;
    int length;
    void (*generate)(unsigned char *, const void *, unsigned int);
    size_t mem;
    void (*init)(void *);
    void (*update)(void *, const void *, unsigned int);
    void (*final)(void *, unsigned char *);
} lumo_rowsum_algorithms[] = {
    [LUMO_ROWSUM_ID_null] = { "empty", 0, NULL, 0, NULL, NULL, NULL },
    LUMO_ROWSUM_ELEMENT_sha3(512)
    LUMO_ROWSUM_ELEMENT_sha3(384)
    LUMO_ROWSUM_ELEMENT_sha3(256)
    LUMO_ROWSUM_ELEMENT_sha3(224)
    LUMO_ROWSUM_ELEMENT_blake3(512)
    LUMO_ROWSUM_ELEMENT_blake3(384)
    LUMO_ROWSUM_ELEMENT_blake3(256)
    LUMO_ROWSUM_ELEMENT_blake3(224)
};
#define LUMO_ROWSUM_N_ALGORITHMS \
    (sizeof(lumo_rowsum_algorithms) / sizeof(lumo_rowsum_algorithms[0]))

#undef LUMO_ROWSUM_ELEMENT_sha3
#undef LUMO_ROWSUM_ELEMENT_blake3
#undef LUMO_ROWSUM_ELEMENT

static struct {
    const char * name;
    unsigned int same_as;
} lumo_rowsum_alias[] = {
    { "sha3",   LUMO_ROWSUM_ID_sha3_256 },
    { "none",   LUMO_ROWSUM_ID_none },
};
#define LUMO_ROWSUM_N_ALIAS \
    (sizeof(lumo_rowsum_alias) / sizeof(lumo_rowsum_alias[0]))

/* default value when creating a new table */
extern unsigned int lumo_rowsum_algorithm;

/* how we check the rowsum: 0, we don't check it at all; 1, we check it
** if present, but don't require it; 2, we require it to be there and
** check it */
extern int lumo_extension_check_rowsum;
#endif /* LUMO_ROWSUM */

#endif /* _LUMO_VDBEINT_ */
#endif /* LUMO_EXTENSIONS */
