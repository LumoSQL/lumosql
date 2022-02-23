#ifdef LUMO_EXTENSIONS

#ifndef _LUMO_VDBEADD_
#define _LUMO_VDBEADD_ 1

#include "vdbeInt.h"

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
    int iSumLen;
    /* add space for the rowsum */
    iSumLen = lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
    iLumoExt += sqlite3VarintLen(LUMO_ROWSUM_TYPE);
    iLumoExt += sqlite3VarintLen(lumo_rowsum_algorithm);
    iLumoExt += sqlite3VarintLen(iSumLen);
    iLumoExt += iSumLen;
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
    const unsigned char *zRptr, *zRowid;
    unsigned char * zWptr;
    int oldHdr, oldLen, newHdr, newLen, serial_type;
    unsigned int nData, nSum, nRowid;
    /* we need to add a column header for the extra blob */
    zRptr = zOld;
    oldLen = getVarint32(zRptr, oldHdr);
    if (isIndex) {
      /* when vdbe reads a column from an index, it'll do one of the following:
      ** 1. read a column before the ROWID for a search
      ** 2. read the ROWID by looking at the very end of the payload
      ** 3. compare the index data with what it expects it to be, before deleting
      **    an entry; this requires the header to contain only information about
      **    the index columns followed by the ROWID
      ** in particular, it never reads the ROWID column in OP_Column, which
      ** is where it checks if the payload length is what it expects it to be,
      ** so we can get away with appending our columns to the payload without
      ** modifying the header, and to cope with (2) we also add a second copy
      ** of the ROWID after our columns; since we don't change the header or
      ** the initial part of the payload, (1) and (3) continue to work */
      int typeRowid = zOld[oldHdr - 1];
      if (typeRowid < 1 || typeRowid == 7 || typeRowid > 9) {
	return SQLITE_CORRUPT_BKPT;
      }
      nRowid = sqlite3VdbeSerialTypeLen(typeRowid);
      zRowid = zOld + nOld - nRowid;
      serial_type = 0;
      newHdr = oldHdr;
      newLen = oldLen;
    } else {
      /* when vdbe reads a column from a row, it may read any columns,
      ** including the last one, at which point it checks if the payload
      ** size is the same as the end of the last column; therefore we
      ** cannot just add our data, we also need to add a single "blob"
      ** to the header to account for the increased payload size;
      ** vdbe will never actually read it because it won't look for it */
      nRowid = 0;
      zRowid = NULL;
      serial_type = iLumoExt*2+12;
      newHdr = oldHdr + sqlite3VarintLen(serial_type);
      newLen = sqlite3VarintLen(newHdr);
      if (newLen > oldLen) {
	newHdr += newLen - oldLen;
	if (newLen < sqlite3VarintLen(newHdr)) newHdr++;
      }
    }
    /* calculate new data payload size, and also what portion of the
    ** data we may use in rowsums */
    nSum = nOld + nZero + newHdr - oldHdr;
    nData = nSum + iLumoExt + nRowid;
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
    if (! isIndex) zWptr += putVarint32(zWptr, serial_type);
    /* copy the old data */
    if (nOld > oldHdr) {
      memcpy(zWptr, zRptr, nOld - oldHdr);
      zRptr += nOld - oldHdr;
      zWptr += nOld - oldHdr;
    }
    if (nZero > 0) {
      memset(zWptr, 0, nZero);
      zWptr += nZero;
    }
    /* add any new data */
    lumoExtension(isIndex, zOld, nOld, 0, *zNew, nSum, zWptr);
    /* finally add the ROWID if present */
    if (nRowid > 0) {
      zWptr += iLumoExt;
      memcpy(zWptr, zRowid, nRowid);
    }
  } else {
    *zNew = NULL;
  }
  return SQLITE_OK;
}

/* see if a Lumo column is present */
int lumoExtensionPresent(
  int isIndex,
  u32 nParsed,
  u32 nOffset,
  u64 nCol,
  u32 nField,
  const unsigned char * zData,
  u32 nHeader,
  u64 nData,
  u64 * nStart,
  u64 * nLen
){
  /* first find the end of the normal data */
  int iLen;
  while (nParsed < nField && nOffset < nHeader && nCol < nData) {
    int iType;
    nOffset += getVarint32(&zData[nOffset], iType);
    nCol += sqlite3VdbeSerialTypeLen(iType);
    nParsed++;
  }
  if (nParsed < nField) return 0;
  if (isIndex) {
    int typeRowid, nRowid;
    /* for an index, our data is not in the header, it follow immediately
    ** the ROWID and extend up to the second copy of the ROWID */
    typeRowid = zData[nHeader - 1];
    if (typeRowid < 1 || typeRowid == 7 || typeRowid > 9) return 0;
    nRowid = sqlite3VdbeSerialTypeLen(typeRowid);
    iLen = nData - nRowid - nCol;
  } else {
    int iType;
    /* for a table, our data is an extra BLOB added after the last
    ** column, with an extra header element to describe it */
    if (nOffset >= nHeader) return 0;
    getVarint32(&zData[nOffset], iType);
    if (iType<14 || iType%2) return 0; /* not a BLOB */
    iLen = (iType - 12) / 2;
  }
  if (iLen <= LUMO_EXTENSION_MAGIC_LEN) return 0; /* not big enough */
  /* could be our column, subject to checking magic string which
   * we cannot do now because zData was only guaranteed to be big enough
   * to contain the header */
  *nLen = iLen;
  *nStart = nCol;
  return 1;
}

#ifdef LUMO_ROWSUM
static int check_rowsum(
  const unsigned char * zH,
  unsigned int xlen,
  unsigned int xsubtype,
  u64 nSum,
  VdbeCursor *pC,
  int *need_rowsum
) {
  if (xsubtype >= lumo_rowsum_n_algorithms) {
    /* we don't know this algorithm; we ignore this rowsum, but
    ** FIXME we may decide that it's an error if "need_rowsum"
    ** is set; in which case we omit the *need_rowsum = 0 below
    ** and just return 1 */
    *need_rowsum = 0;
    return 1;
  }
  /* we know this algorithm, so go and check */
  if (lumo_rowsum_algorithms[xsubtype].length != xlen) return 0;
  if (xlen != 0) {
    /* not the NULL algorithm */
    unsigned char rowsum[xlen], ctx[lumo_rowsum_algorithms[xsubtype].mem], buffer[4096];
    u64 nCheck = nSum, nPos = 0;
    lumo_rowsum_algorithms[xsubtype].init(ctx);
    while (nCheck > 0) {
      int todo;
      todo = nCheck < sizeof(buffer) ? (u32)nCheck : (u32)sizeof(buffer);
      if (sqlite3BtreePayload(pC->uc.pCursor, nPos, todo, buffer) != SQLITE_OK) return -1;
      lumo_rowsum_algorithms[xsubtype].update(ctx, buffer, todo);
      nCheck -= todo;
      nPos += todo;
    }
    lumo_rowsum_algorithms[xsubtype].final(ctx, rowsum);
    if (memcmp(rowsum, zH, xlen) != 0) return -1;
  }
  *need_rowsum = 0;
  return 1;
}
#endif

int lumoExtensionHandle(
  int isIndex,
  const unsigned char *zRow,
  u64 nSum,
  u64 nLen,
  VdbeCursor *pC
){
  /* now we can check if it is a Lumo column... */
  const unsigned char *zH = zRow, *zEnd = &zRow[nLen - 1];
#ifdef LUMO_ROWSUM
  int need_rowsum = lumo_extension_check_rowsum > 1;
#endif
  if (nLen <= LUMO_EXTENSION_MAGIC_LEN) return 0;
  if (memcmp(zH, LUMO_EXTENSION_MAGIC, LUMO_EXTENSION_MAGIC_LEN) != 0) return 0;
  if (*zEnd != LUMO_END_TYPE) return -1;
  zH += LUMO_EXTENSION_MAGIC_LEN;
  while (zH < zEnd) {
    unsigned int xtype, xsubtype, xlen;
    zH += getVarint32(zH, xtype);
    if (xtype == LUMO_END_TYPE) return -1; /* END_TYPE in the middle? */
    if (zH >= zEnd) return -1;
    zH += getVarint32(zH, xsubtype);
    if (zH >= zEnd) return -1;
    zH += getVarint32(zH, xlen);
    if (&zH[xlen] > zEnd) return -1;
#ifdef LUMO_ROWSUM
    if (xtype == LUMO_ROWSUM_TYPE && lumo_extension_check_rowsum) {
      if (! check_rowsum(zH, xlen, xsubtype, nSum, pC, &need_rowsum)) return -1;
    }
#endif
    zH += xlen;
  }
#ifdef LUMO_ROWSUM
  if (need_rowsum) return -1;
#endif
  return 1;
}

#endif
#endif

