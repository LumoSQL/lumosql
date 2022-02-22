#ifdef LUMO_EXTENSIONS

#ifndef _LUMO_VDBEADD_
#define _LUMO_VDBEADD_ 1

/* help making sure we only look at our data */
#define LUMO_EXTENSION_MAGIC "Lumo"
#define LUMO_EXTENSION_MAGIC_LEN strlen(LUMO_EXTENSION_MAGIC)

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

const lumo_rowsum_spec lumo_rowsum_algorithms[] = {
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
const int lumo_rowsum_n_algorithms =
  (sizeof(lumo_rowsum_algorithms) / sizeof(lumo_rowsum_algorithms[0]));

#undef LUMO_ROWSUM_ELEMENT_sha3
#undef LUMO_ROWSUM_ELEMENT_blake3
#undef LUMO_ROWSUM_ELEMENT

const lumo_rowsum_alias_spec lumo_rowsum_alias[] = {
  { "sha3",   LUMO_ROWSUM_ID_sha3 },
  { "blake3", LUMO_ROWSUM_ID_blake3 },
  { "none",   LUMO_ROWSUM_ID_none },
};
const int lumo_rowsum_n_alias = (sizeof(lumo_rowsum_alias) / sizeof(lumo_rowsum_alias[0]));
#endif /* LUMO_ROWSUM */

/* how much space will be needed to add Lumo extensions to some data,
 * or 0 if there are no extensions to add */
int lumoExtensionLength(
  int isIndex,
  const unsigned char *zData,
  unsigned int nData,
  unsigned int nZero
) {
  int iLumoExt = 0;
#ifdef LUMO_ROWSUM
  if (lumo_rowsum_algorithm < lumo_rowsum_n_algorithms) {
    int xLen;
    /* add space for the rowsum */
    xLen = lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
    iLumoExt += sqlite3VarintLen(LUMO_ROWSUM_TYPE);
    iLumoExt += sqlite3VarintLen(lumo_rowsum_algorithm);
    iLumoExt += sqlite3VarintLen(xLen);
    iLumoExt += xLen;
  }
#endif
  if (iLumoExt > 0) {
    /* add space for magic string and end type */
    iLumoExt += LUMO_EXTENSION_MAGIC_LEN + sqlite3VarintLen(LUMO_END_TYPE);
  }
  return iLumoExt;
}

/* the actual lumo extension data, the result buffer must have at
 * least the space indicated by lumoExtensionLength */
void lumoExtension(
  int isIndex,
  const unsigned char * zData,
  unsigned int nData,
  unsigned int nZero,
  const unsigned char * zSum,
  unsigned int nSum,
  unsigned char * zDest
){
  memcpy(zDest, LUMO_EXTENSION_MAGIC, LUMO_EXTENSION_MAGIC_LEN);
  zDest += LUMO_EXTENSION_MAGIC_LEN;
#ifdef LUMO_ROWSUM
  if (lumo_rowsum_algorithm < lumo_rowsum_n_algorithms) {
    int iSumLen;
    iSumLen = lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
    zDest += putVarint32(zDest, LUMO_ROWSUM_TYPE);
    zDest += putVarint32(zDest, lumo_rowsum_algorithm);
    zDest += putVarint32(zDest, iSumLen);
    if (iSumLen > 0){
      char context[lumo_rowsum_algorithms[lumo_rowsum_algorithm].mem];
      lumo_rowsum_algorithms[lumo_rowsum_algorithm].init(context);
      if (nSum > 0)
	lumo_rowsum_algorithms[lumo_rowsum_algorithm].update(context, zSum, nSum);
      if (nZero > 0) {
	char buffer[nZero < 1024 ? nZero : 1024];
	unsigned int nAddZero = nZero;
	memset(buffer, 0, sizeof(buffer));
	while (nAddZero >= 1024) {
	  lumo_rowsum_algorithms[lumo_rowsum_algorithm].update(context, buffer, 1024);
	  nAddZero -= 1024;
	}
	if (nAddZero > 0)
	  lumo_rowsum_algorithms[lumo_rowsum_algorithm].update(context, buffer, nAddZero);
      }
      lumo_rowsum_algorithms[lumo_rowsum_algorithm].final(context, zDest);
      zDest += iSumLen;
    }
  }
#endif
  zDest += putVarint32(zDest, LUMO_END_TYPE);
}

/* take a packed record and add the Lumo extension data; it allocates a
 * new buffer which needs to be freed by the caller; if the first argument
 * is NULL, it is allocated with sqlite3MallocZero, if not NULL with
 * sqlite3DbMallocZero */
int lumoExtensionAdd(
  sqlite3 *db,
  int isIndex,
  const unsigned char *zOld,
  sqlite3_int64 nOld,
  sqlite3_int64 nZero,
  unsigned char **zNew,
  sqlite3_int64 *nNew
){
  int iLumoExt = lumoExtensionLength(isIndex, zOld, nOld, nZero);
  if (iLumoExt>0) {
    /* add Lumo extension */
    const unsigned char * zRptr;
    unsigned char * zWptr;
    int oldHdr, oldLen, newHdr, newLen, serial_type;
    unsigned int nData, nSum;
    /* we need to add a column header for the extra blob */
    serial_type = iLumoExt*2+12;
    zRptr = zOld;
    oldLen = getVarint32(zRptr, oldHdr);
    newHdr = oldHdr + sqlite3VarintLen(serial_type);
    newLen = sqlite3VarintLen(newHdr);
    if (newLen > oldLen) {
      newHdr += newLen - oldLen;
      if (newLen < sqlite3VarintLen(newHdr)) newHdr++;
    }
    /* calculate new data payload size, and also what portion of the
    ** data we may use in rowsums */
    nSum = nOld + nZero + newHdr - oldHdr;
    nData = nSum + iLumoExt;
    /* allocate some memory to write a new record */
    if (db)
      zWptr = sqlite3DbMallocZero(db, nData);
    else
      zWptr = sqlite3MallocZero(nData);
    if (! zWptr) {
      return SQLITE_NOMEM_BKPT;
    }
    *zNew = zWptr;
    *nNew = nData;
    /* now write the new header */
    zWptr += putVarint32(zWptr, newHdr);
    zRptr += oldLen;
    memcpy(zWptr, zRptr, oldHdr - oldLen);
    zRptr += oldHdr - oldLen;
    zWptr += oldHdr - oldLen;
    zWptr += putVarint32(zWptr, serial_type);
    /* copy the old data */
    if (nOld > oldHdr) {
      memcpy(zWptr, zRptr, nOld - oldHdr);
      zWptr += nOld - oldHdr;
    }
    if (nZero > 0) {
      memset(zWptr, 0, nZero);
      zWptr += nZero;
    }
    /* and add any new data */
    lumoExtension(isIndex, zOld, nOld, nZero, *zNew, nSum, zWptr);
  } else {
    *zNew = NULL;
  }
  return SQLITE_OK;
}

#endif
#endif
