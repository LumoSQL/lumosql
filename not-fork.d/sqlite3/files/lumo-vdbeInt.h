#ifdef LUMO_ROWSUM

/* declarations needed for the rowsum code */

#include "lumo-sha3.c"

#define LUMO_EXTENSIONS 1

#define LUMO_ROWSUM_ID_sha3_512 0
#define LUMO_ROWSUM_ID_sha3_384 1
#define LUMO_ROWSUM_ID_sha3_256 2
#define LUMO_ROWSUM_ID_sha3_224 3
#define LUMO_ROWSUM_ID_sha3 LUMO_ROWSUM_ID_sha3_256

#define LUMO_ROWSUM_GENERATE_sha3(d, p, l, k) { \
    SHA3Context ctx; \
    SHA3Init(&ctx, k); \
    SHA3Update(&ctx, p, l); \
    memcpy(d, SHA3Final(&ctx), k / 8); \
  }

static void lumo_sha3_512(void * d, const void * p, unsigned int n)
	LUMO_ROWSUM_GENERATE_sha3(d, p, n, 512)
static void lumo_sha3_384(void * d, const void * p, unsigned int n)
	LUMO_ROWSUM_GENERATE_sha3(d, p, n, 384)
static void lumo_sha3_256(void * d, const void * p, unsigned int n)
	LUMO_ROWSUM_GENERATE_sha3(d, p, n, 256)
static void lumo_sha3_224(void * d, const void * p, unsigned int n)
	LUMO_ROWSUM_GENERATE_sha3(d, p, n, 224)

#undef LUMO_ROWSUM_GENERATE_sha3

#define LUMO_ROWSUM_TYPE 1
#define LUMO_ROWSUM_LENGTH 66 /* must be >= 2 + maximum sum length */

static struct {
    const char * name;
    int length;
    void (*generate)(void *, const void *, unsigned int);
} lumo_rowsum_algorithms[] = {
    [LUMO_ROWSUM_ID_sha3_512] = { "sha3_512",  64,  lumo_sha3_512 },
    [LUMO_ROWSUM_ID_sha3_384] = { "sha3_384",  48,  lumo_sha3_384 },
    [LUMO_ROWSUM_ID_sha3_256] = { "sha3_256",  32,  lumo_sha3_256 },
    [LUMO_ROWSUM_ID_sha3_224] = { "sha3_224",  28,  lumo_sha3_224 },
};
static int lumo_rowsum_n_algorithms =
    sizeof(lumo_rowsum_algorithms) / sizeof(lumo_rowsum_algorithms[0]);

static struct {
    const char * name;
    int same_as;
} lumo_rowsum_alias[] = {
    { "sha3",   LUMO_ROWSUM_ID_sha3_256 },
};
static int lumo_rowsum_n_alias =
    sizeof(lumo_rowsum_alias) / sizeof(lumo_rowsum_alias[0]);

/* default value when creating a new table */
static unsigned int lumo_rowsum_algorithm = LUMO_ROWSUM_ID;

/* help making sure we only look at our data */
static const char lumo_extension_magic[4] = "Lumo";
#endif

