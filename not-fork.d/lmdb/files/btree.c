/*

  Copyright 2021 The LumoSQL Authors under the terms contained in the file LICENSES/MIT

  SPDX-License-Identifier: MIT
  SPDX-FileCopyrightText: 2021 The LumoSQL Authors
  SPDX-ArtifactOfProjectName: LumoSQL
  SPDX-FileType: Code
  SPDX-FileComment: Original by Claudio Calvelli, 2021

  not-fork.d/lmdb/files/btree.c
*/

// FIXME - we completely omit any shared cache code in this version

#ifndef __LUMO_BACKEND_btree_c
#define __LUMO_BACKEND_btree_c 1

/* see comments in removeTempDb() and sqlite3BtreeOpen() about using
** functions from dirent.h instead of a vfs call */
#include <dirent.h>
#include "lmdb.h"

/* maximum length of a filename we consider opening */
#define BTREE_MAX_PATH 1024

/* maximum key length which results in an index being a simple 1:1
** correspondence with an LMDB database; see comments in sqlite3BtreeInsert
** for more details */
#define LUMO_LMDB_MAX_KEY 479

struct BtreeSavepoint {
  struct BtreeSavepoint *prev;
  MDB_txn *txn;
  int nSavepoint;
};

struct Btree {
  sqlite3 *db;
  sqlite3_vfs *pVfs;
  MDB_env *env;
  struct BtreeSavepoint *svp;
  MDB_dbi dataDbi;
  void * pSchema;
  void (*xFreeSchema)(void *);
  int flags;
  int vfsFlags;
  int mdbFlags;
  int iDataVersion;
  u8 inTrans;
  u8 isTemp;
  u8 isMemdb;
  u8 inBackup;
  char path[];
};

struct BtCursor {
  Btree * pBtree;
  MDB_dbi dbi;
  MDB_cursor * cursor;
  struct KeyInfo *pKeyInfo;
  Pgno rootPage;
  unsigned int hints;
  u8 atEof;
};

static struct BtCursor fakeCursor = {
  .atEof = 1,
};

#undef LUMO_LOG_INSERTS
#ifdef LUMO_LMDB_DEBUG
// #define LUMO_LOG_INSERTS
static FILE * _log_fp = NULL;
#define LUMO_LOG_OPEN() if (! _log_fp) _log_fp = fopen("/tmp/lmdb.debug", "a")
#define LUMO_LOG(fmt, ...) do { \
  LUMO_LOG_OPEN(); \
  fprintf(_log_fp, fmt __VA_OPT__(,) __VA_ARGS__); \
  fflush(_log_fp); \
 } while(0)
static void LUMO_LOG_DATA(int n, const unsigned char * d) {
  int i;
  LUMO_LOG_OPEN();
  for (i = 0; i < n; i++) fprintf(_log_fp, " %02x", d[i]);
  fprintf(_log_fp, " [");
  for (i = 0; i < n; i++)
    fprintf(_log_fp, "%c", d[i] >= 32 && d[i] < 127 ? d[i] : 32);
  fprintf(_log_fp, "]");
  fflush(_log_fp);
}
static u64 get8(const MDB_val *);
static void LUMO_LOG_CURSOR(MDB_cursor * cursor, int isIndex) {
  MDB_val key, data;
  int rc = mdb_cursor_get(cursor, &key, &data, MDB_FIRST);
  LUMO_LOG_OPEN();
  while (rc == 0) {
    unsigned char * d = key.mv_data;
    int i;
    fprintf(_log_fp, "  => %zd:", (size_t)key.mv_size);
    for (i = 0; i < 8; i++) fprintf(_log_fp, "%02x", d[i]);
    if (! isIndex) fprintf(_log_fp, " == %lld", (long long)get8(&key));
    d = data.mv_data;
    for (i = 0; i < data.mv_size; i++) fprintf(_log_fp, " %02x", d[i]);
    fprintf(_log_fp, "   [");
    for (i = 0; i < data.mv_size; i++)
      fprintf(_log_fp, "%c", d[i] >= 32 && d[i] < 127 ? d[i] : 32);
    fprintf(_log_fp, "]\n");
    rc = mdb_cursor_get(cursor, &key, &data, MDB_NEXT);
  }
  fflush(_log_fp);
}
#define LUMO_TXN(i) (\
  (i) == SQLITE_TXN_NONE ? "NONE" : \
  ((i) == SQLITE_TXN_READ ? "READ" : \
  ((i) == SQLITE_TXN_WRITE ? "WRITE" : "?")) \
)
#else
#define LUMO_LOG(fmt, ...) do { } while(0)
#define LUMO_LOG_DATA(n, d) do { } while(0)
#define LUMO_LOG_CURSOR(cursor, isIndex) do { } while(0)
#define LUMO_TXN(i) ""
#endif

/* convert 64 bit integers to/from a string which sorts like a number;
** LMDB's integer keys don't appear to be particularly portable if one
** copies things across systems, and the only 64 bit option requires
** either a 64 bit processor or build options which we cannot guarantee
** will be present if we use a lmdb already installed on the system
**
** put8 must be passed a pre-allocated buffer of length at least 8
** and the pointer in d will be a small offset into that buffer
*/
#if 1
/* this version is a tiny fraction faster and uses less space in the
** database, so might as well use it */
#define USE_ROWID_COMPARE

static u64 get8(const MDB_val *d) {
  const unsigned char * ptr = d->mv_data;
  u64 res = 0;
  int i, len = d->mv_size;
  if (len > 8) len = 8;
  for (i = 0; i < d->mv_size; i++) {
    res <<= 8;
    res |= ptr[i];
  }
  return res;
}

static void put8(MDB_val *d, unsigned char *b, u64 v) {
  int size = 0;
  b += 8;
  LUMO_LOG("put8 %llu", (unsigned long long)v);
  /* we could replace this with a while(v) { ... } but this can be
  ** used as key and we don't necessarily want empty keys */
  do {
    *--b = v & 0xff;
    size++;
    v >>= 8;
    assert (size <= 8);
  } while (v);
  d->mv_size = size;
  d->mv_data = b;
}
#else
#undef USE_ROWID_COMPARE

static u64 get8(const MDB_val *d) {
  const unsigned char * ptr = d->mv_data;
  u64 res = 0;
  if (d->mv_size != 8) return res;
  res = (u64)sqlite3Get4byte(ptr);
  res <<= 32;
  return res | (u64)sqlite3Get4byte(ptr + 4);
}

static void put8(MDB_val *d, unsigned char *b, u64 v) {
  sqlite3Put4byte(b, (u32)(v >> 32));
  sqlite3Put4byte(b + 4, (u32)(v & 0xffffffffUL));
  d->mv_size = 8;
  d->mv_data = b;
}
#endif

static int error_map(int rc) {
  switch(rc) {
    case 0:
      return SQLITE_OK;
    case EACCES:
      return SQLITE_READONLY;
    case EIO:
    case MDB_PANIC:
      return SQLITE_IOERR;
    case EPERM:
      return SQLITE_PERM;
    case ENOMEM:
      return SQLITE_NOMEM_BKPT;
    case ENOENT:
      return SQLITE_CANTOPEN_BKPT;
    case ENOSPC:
    case MDB_MAP_FULL:
      return SQLITE_FULL;
    case MDB_NOTFOUND:
      return SQLITE_NOTFOUND;
    case MDB_VERSION_MISMATCH:
    case MDB_INVALID:
      return SQLITE_NOTADB;
    case MDB_PAGE_NOTFOUND:
    case MDB_CORRUPTED:
      return SQLITE_CORRUPT_BKPT;
    case MDB_INCOMPATIBLE:
      return SQLITE_SCHEMA;
    case MDB_BAD_RSLOT:
      return SQLITE_MISUSE_BKPT;
    case MDB_BAD_TXN:
      return SQLITE_ABORT;
    case MDB_BAD_VALSIZE:
      return SQLITE_TOOBIG;
  }
  return SQLITE_INTERNAL;
}

static int get_int(Btree *p, unsigned int idx) {
  MDB_val key, data;
  int rc;
  unsigned char bidx = idx;
  key.mv_data = &bidx;
  key.mv_size = 1;
  rc = mdb_get(p->svp->txn, p->dataDbi, &key, &data);
  if (rc) return 0;
  if (data.mv_size != 4) return 0;
  return sqlite3Get4byte(data.mv_data);
}

static int put_int(Btree *p, unsigned int idx, u32 iValue) {
  char buffer[4];
  unsigned char bidx = idx;
  MDB_val key, data;
  key.mv_data = &bidx;
  key.mv_size = 1;
  data.mv_data = buffer;
  data.mv_size = 4;
  sqlite3Put4byte(buffer, iValue);
  return mdb_put(p->svp->txn, p->dataDbi, &key, &data, 0);
}

#ifdef USE_ROWID_COMPARE
/* compare two rowid values stored by get8() */
static int rowid_compare(const MDB_val *a, const MDB_val *b) {
  if (a->mv_size < b->mv_size) return -1;
  if (a->mv_size > b->mv_size) return 1;
  return memcmp(a->mv_data, b->mv_data, a->mv_size);
}
#endif

/* compare a key passed to a LMDB function with one stored in the
** database; this function is copied from sqlightning and will work
** as long as LMDB doesn't change the way it calls it so FIXME this
** will need to be reviewed to see if we can remove this dependency;
** we assume that sqlite3BtreeInsert and other functions which may
** result in key comparisons store the unpacked key in key[1] */
static int index_compare(const MDB_val *a, const MDB_val *b) {
  UnpackedRecord *p = a[1].mv_data;
  return -sqlite3VdbeRecordCompare(b->mv_size, b->mv_data, p);
}

/* open or create a database in the LMDB environment; tableFlags is 0 or a bitwise
 * OR of the following values */
typedef enum {
  get_table_index  = 1,  /* table is an index */
  get_table_create = 2,  /* create table if it does not exist */
  get_table_nocmp  = 4,  /* do not set a key compare function */
} get_table_t;
static int get_table(Btree *p, unsigned int iTable, get_table_t tableFlags, MDB_dbi *dbi) {
  char dbiName[32];
  int rc;
  unsigned int mdbFlags = 0;
  if (iTable < 1) return SQLITE_CORRUPT_BKPT;
  if (! p->svp) return SQLITE_INTERNAL;
  if (iTable == 1 || (tableFlags & get_table_create) != 0) mdbFlags |= MDB_CREATE;
  snprintf(dbiName, sizeof(dbiName), "t%08x", (unsigned int)iTable);
  LUMO_LOG("get_table: %d %x => <%s>\n", iTable, tableFlags, dbiName);
  rc = mdb_dbi_open(p->svp->txn, dbiName, mdbFlags, dbi);
  if (rc || (tableFlags & get_table_nocmp) != 0) return rc;
  if (tableFlags & get_table_index) {
    rc = mdb_set_compare(p->svp->txn, *dbi, index_compare);
  } else {
#ifdef USE_ROWID_COMPARE
    rc = mdb_set_compare(p->svp->txn, *dbi, rowid_compare);
#endif
  }
  return rc;
}

static int closeAllSavepoints(Btree *p, int nTo, int commit) {
  int rc = 0;
  if (! p->svp) return 0;
  while (p->svp->prev && p->svp->nSavepoint != nTo) {
    struct BtreeSavepoint * S = p->svp;
    p->svp = S->prev;
    LUMO_LOG("closeAllSavepoints(%d, %d) %p\n", S->nSavepoint, nTo, S->txn);
    if (commit) {
      int rc1 = mdb_txn_commit(S->txn);
      if (rc1 && ! rc) rc = rc1;
    } else {
      mdb_txn_abort(S->txn);
    }
    sqlite3_free(S);
  }
  return rc;
}

int sqlite3_enable_shared_cache(int enable) { }

static void removeTempDb(const char *zDir) {
  /* non-vfs routine to delete all files in a directory, then the
  ** directory itself; to get to the point of calling this we
  ** must have gone through the creation of a temporary database,
  ** which needs also be fixed o use vfs calls */
  DIR * dp = opendir(zDir);
  if (dp) {
    /* give us a buffer large enough for any files LMDB may create;
    ** we do not need to cope with arbitrary filenames here */
    int pLen = strlen(zDir);
    char buffer[pLen + 32];
    struct dirent * ent;
    strcpy(buffer, zDir);
    buffer[pLen++] = '/';
    while ((ent = readdir(dp)) != NULL) {
      if (ent->d_name[0] != '.' || ent->d_name[1] != '.' || ent->d_name[2]) {
	if (strlen(ent->d_name) < 30) {
	  strcpy(&buffer[pLen], ent->d_name);
	  unlink(buffer);
	}
      }
    }
    closedir(dp);
  }
  rmdir(zDir);
}

/*
** Open a database file.
** 
** zFilename is the name of the database file.  If zFilename is NULL
** then an ephemeral database is created.  The ephemeral database might
** be exclusively in memory, or it might use a disk-based memory cache.
** Either way, the ephemeral database will be automatically deleted 
** when sqlite3BtreeClose() is called.
**
** If zFilename is ":memory:" then an in-memory database is created
** that is automatically destroyed when it is closed.
**
** The "flags" parameter is a bitmask that might contain bits like
** BTREE_OMIT_JOURNAL and/or BTREE_MEMORY.
**
** If the database is already opened in the same database connection
** and we are in shared cache mode, then the open will fail with an
** SQLITE_CONSTRAINT error.  We cannot allow two or more BtShared
** objects in the same database connection since doing so will lead
** to problems with locking.
*/
int sqlite3BtreeOpen(
  sqlite3_vfs *pVfs,      /* VFS to use for this b-tree */
  const char *zFilename,  /* Name of the file containing the BTree database */
  sqlite3 *db,            /* Associated database handle */
  Btree **ppBtree,        /* Pointer to new Btree object written here */
  int flags,              /* Options */
  int vfsFlags            /* Flags passed through to sqlite3_vfs.xOpen() */
){
  char dirPathName[BTREE_MAX_PATH];
  Btree *p;
  int rc;
  int envClose = 0;
  int mdbFlags;

  /* True if opening an ephemeral, temporary database */
  const int isTempDb = zFilename==0 || zFilename[0]==0;

  /* Set the variable isMemdb to true for an in-memory database, or 
  ** false for a file-based database.
  */
#ifdef SQLITE_OMIT_MEMORYDB
  const int isMemdb = 0;
#else
  const int isMemdb = (zFilename && strcmp(zFilename, ":memory:")==0)
                       || (isTempDb && sqlite3TempInMemory(db))
                       || (vfsFlags & SQLITE_OPEN_MEMORY)!=0;
#endif

  LUMO_LOG("sqlite3BtreeOpen(%d, %d, %s)\n", isTempDb, isMemdb, zFilename ? zFilename : "?");
  mdbFlags = 0;
  if (vfsFlags & SQLITE_OPEN_READONLY) mdbFlags |= MDB_RDONLY;
  if (isMemdb || isTempDb) {
    /* FIXME there isn't a vfs function to create a temporary directory or
    ** some other "safe" temporary name; sqlightning used tempnam() which
    ** is not a good idea and we use mkdtemp but we can't use the vfs for
    ** that, so this will need to change at some point.
    **
    ** We spell the names backwards for the same reason as sqlite's own
    ** temporary file names do */
    strncpy(dirPathName, "/tmp/dbml.etilqs.", sizeof(dirPathName) - 7);
    dirPathName[sizeof(dirPathName) - 7] = 0;
    strcat(dirPathName, "XXXXXX");
    if (! mkdtemp(dirPathName)) {
      rc = EIO;
      goto error;
    }
    mdbFlags |= MDB_NOSYNC|MDB_NOLOCK;
  } else {
    sqlite3OsFullPathname(pVfs, zFilename, sizeof(dirPathName), dirPathName);
#if 0
    mdbFlags |= MDB_NOSUBDIR;
#else
    /* LMDB requires a temporary directory to already exist so let's make
    ** sure there is one */
    mkdir(dirPathName, 0777);
#endif
  }
  p = sqlite3MallocZero(sizeof(Btree) + strlen(dirPathName) + 1);
  if (!p) {
    rc = ENOMEM;
    goto error;
  }
  p->inTrans = SQLITE_TXN_NONE;
  p->inBackup = 0;
  p->db = db;
  p->flags = flags;
  p->vfsFlags = vfsFlags;
  p->mdbFlags = mdbFlags;
  strcpy(p->path, dirPathName);
  p->isTemp = isMemdb || isTempDb;
  p->isMemdb = isMemdb;
  p->pSchema = NULL;
  p->xFreeSchema = NULL;
  rc = mdb_env_create(&p->env);
  if (rc) goto error;
  envClose = 1;
  if (sizeof(size_t) < 8)
    mdb_env_set_mapsize(p->env, 1024 * 1024 * 1024);
  else
    mdb_env_set_mapsize(p->env, 1024ULL * 1044 * 1024 * 1024);
  mdb_env_set_maxreaders(p->env, 254);
  mdb_env_set_maxdbs(p->env, isTempDb ? 64 : 1024);
  rc = mdb_env_open(p->env, dirPathName, mdbFlags, SQLITE_DEFAULT_FILE_PERMISSIONS);
  // XXX any more initialisations
  *ppBtree = p;
  return SQLITE_OK;
error:
  if (envClose) mdb_env_close(p->env);
  if (isTempDb || isMemdb)
    removeTempDb(dirPathName);
  if (p) sqlite3_free(p);
  *ppBtree = 0;
  return error_map(rc);
}

int sqlite3BtreeClose(Btree *p) {
  LUMO_LOG("sqlite3BtreeClose %s\n", p->path);
  // XXX invalidate all cursors
  mdb_env_close(p->env);
  if (p->isTemp && *p->path)
    removeTempDb(p->path);
  if (p->pSchema) {
    if (p->xFreeSchema) p->xFreeSchema(p->pSchema);
    sqlite3_free(p->pSchema);
  }
  sqlite3_free(p);
  return SQLITE_OK;
}

int sqlite3BtreeSetCacheSize(Btree *p, int mxPage) {
  return SQLITE_OK;
}

int sqlite3BtreeSetSpillSize(Btree *p, int mxPage) {
  LUMO_LOG("called: sqlite3BtreeSetSpillSize\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeSetSpillSize(Btree*,int);
}

int sqlite3BtreeSetMmapLimit(Btree *p, sqlite3_int64 szMap) {
  LUMO_LOG("called: sqlite3BtreeSetMmapLimit\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeSetMmapLimit(Btree*,sqlite3_int64);
}

int sqlite3BtreeSetPagerFlags(Btree *p, unsigned pgFlags) {
  LUMO_LOG("called: sqlite3BtreeSetPagerFlags\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeSetPagerFlags(Btree*,unsigned);
}

int sqlite3BtreeSetPageSize(Btree *p, int nPagesize, int nReserve, int eFix) {
  LUMO_LOG("called: sqlite3BtreeSetPageSize\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeSetPageSize(Btree *p, int nPagesize, int nReserve, int eFix);
}

int sqlite3BtreeGetPageSize(Btree *p) {
  LUMO_LOG("called: sqlite3BtreeGetPageSize\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeGetPageSize(Btree*);
}

Pgno sqlite3BtreeMaxPageCount(Btree *p, Pgno mxPage) {
  LUMO_LOG("called: sqlite3BtreeMaxPageCount\n");
  return 0; // XXX Pgno sqlite3BtreeMaxPageCount(Btree *p,Pgno);
}

/*
** Return the size of the database file in pages. If there is any kind of
** error, return ((unsigned int)-1).
*/
Pgno sqlite3BtreeLastPage(Btree *p){
  MDB_envinfo info;
  u32 pgnoRoot;
  int rc = mdb_env_info(p->env, &info);
  if (rc) {
    LUMO_LOG("sqlite3BtreeLastPage: fail %d\n", rc);
    return (unsigned int)-1;
  }
  LUMO_LOG("sqlite3BtreeLastPage(%u)\n", (unsigned int)info.me_last_pgno);
  /* vdbe assumes that a rootpage must be < last page, which isn't true
   * with lmdb, so.... */
  if (! p->svp) return info.me_last_pgno;
  sqlite3BtreeGetMeta(p, BTREE_LARGEST_ROOT_PAGE, &pgnoRoot);
  LUMO_LOG("sqlite3BtreeLastPage(%u, %u)\n", (unsigned int)info.me_last_pgno, pgnoRoot);
  return info.me_last_pgno < pgnoRoot ? pgnoRoot : info.me_last_pgno;
}

int sqlite3BtreeSecureDelete(Btree *p, int newFlag) {
  LUMO_LOG("called: sqlite3BtreeSecureDelete\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeSecureDelete(Btree*,int);
}

int sqlite3BtreeGetRequestedReserve(Btree *p) {
  LUMO_LOG("called: sqlite3BtreeGetRequestedReserve\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeGetRequestedReserve(Btree*);
}

int sqlite3BtreeSetAutoVacuum(Btree *p, int autoVacuum) {
  LUMO_LOG("called: sqlite3BtreeSetAutoVacuum\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeSetAutoVacuum(Btree *, int);
}

int sqlite3BtreeGetAutoVacuum(Btree *p) {
  LUMO_LOG("called: sqlite3BtreeGetAutoVacuum\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeGetAutoVacuum(Btree *);
}

/*
** Attempt to start a new transaction. A write-transaction
** is started if the second argument is nonzero, otherwise a read-
** transaction.  If the second argument is 2 or more and exclusive
** transaction is started, meaning that no other process is allowed
** to access the database.  A preexisting transaction may not be
** upgraded to exclusive by calling this routine a second time - the
** exclusivity flag only works for a new transaction.
**
** A write-transaction must be started before attempting any 
** changes to the database.  None of the following routines 
** will work unless a transaction is started first:
**
**      sqlite3BtreeCreateTable()
**      sqlite3BtreeCreateIndex()
**      sqlite3BtreeClearTable()
**      sqlite3BtreeDropTable()
**      sqlite3BtreeInsert()
**      sqlite3BtreeDelete()
**      sqlite3BtreeUpdateMeta()
**
** If an initial attempt to acquire the lock fails because of lock contention
** and the database was previously unlocked, then invoke the busy handler
** if there is one.  But if there was previously a read-lock, do not
** invoke the busy handler - just return SQLITE_BUSY.  SQLITE_BUSY is 
** returned when there is already a read-lock in order to avoid a deadlock.
**
** Suppose there are two processes A and B.  A has a read lock and B has
** a reserved lock.  B tries to promote to exclusive but is blocked because
** of A's read lock.  A tries to promote to reserved but is blocked by B.
** One or the other of the two processes must give way or there can be
** no progress.  By returning SQLITE_BUSY and not invoking the busy callback
** when A already has a read lock, we encourage A to give up and let B
** proceed.
*/
int sqlite3BtreeBeginTrans(Btree *p, int wrFlag, int *pSchemaVersion) {
  int rc;
  const int isReadonly = p->vfsFlags & SQLITE_OPEN_READONLY;
  LUMO_LOG("sqlite3BtreeBeginTrans(%d/%d, %d, %s) %s\n",
	   wrFlag, isReadonly, p->inTrans, LUMO_TXN(p->inTrans), p->path);
  if (p->inTrans == SQLITE_TXN_WRITE) goto get_version;
  if (wrFlag && isReadonly != 0)
    return SQLITE_READONLY;
  if (p->inTrans != SQLITE_TXN_NONE) {
    if (wrFlag) p->inTrans = SQLITE_TXN_WRITE;
    goto get_version;
  }
  if (p->svp) return SQLITE_INTERNAL;
  p->svp = sqlite3DbMallocZero(0, sizeof(struct BtreeSavepoint));
  if (! p->svp) return SQLITE_NOMEM;
  p->svp->prev = NULL;
  p->svp->nSavepoint = -1;
  /* we always begin a writable transaction as long as the database itself
  ** is writable (i.e. readonly is not specified in vfsFlags); this is so
  ** that we can upgrade to a writable transaction later if necessary
  ** as lmdb doesn't have a method to do that */
  rc = mdb_txn_begin(p->env, NULL, isReadonly ? MDB_RDONLY : 0, &p->svp->txn);
  if (rc) {
    LUMO_LOG("sqlite3BtreeBeginTrans (%d): begin fail %d\n", wrFlag, rc);
    sqlite3_free(p->svp);
    p->svp = NULL;
    return error_map(rc);
  }
  rc = mdb_dbi_open(p->svp->txn, "meta", isReadonly ? 0 : MDB_CREATE, &p->dataDbi);
  if (rc && !(isReadonly && rc == MDB_NOTFOUND)) {
    mdb_txn_abort(p->svp->txn);
    sqlite3_free(p->svp);
    p->svp = NULL;
    LUMO_LOG("sqlite3BtreeBeginTrans (%d): dbi open fail %d\n", wrFlag, rc);
    return error_map(rc);
  }
  p->inTrans = wrFlag ? SQLITE_TXN_WRITE : SQLITE_TXN_READ;
get_version:
  if (pSchemaVersion)
    *pSchemaVersion = get_int(p, BTREE_SCHEMA_VERSION);
  LUMO_LOG("sqlite3BtreeBeginTrans(%d, %d) OK %p\n", wrFlag, pSchemaVersion ? *pSchemaVersion : get_int(p, BTREE_SCHEMA_VERSION), p->svp->txn);
  return SQLITE_OK;
}

/*
** This routine does the first phase of a two-phase commit.  This routine
** causes a rollback journal to be created (if it does not already exist)
** and populated with enough information so that if a power loss occurs
** the database can be restored to its original state by playing back
** the journal.  Then the contents of the journal are flushed out to
** the disk.  After the journal is safely on oxide, the changes to the
** database are written into the database file and flushed to oxide.
** At the end of this call, the rollback journal still exists on the
** disk and we are still holding all locks, so the transaction has not
** committed.  See sqlite3BtreeCommitPhaseTwo() for the second phase of the
** commit process.
**
** This call is a no-op if no write-transaction is currently active on pBt.
**
** Otherwise, sync the database file for the btree pBt. zSuperJrnl points to
** the name of a super-journal file that should be written into the
** individual journal file, or is NULL, indicating no super-journal file 
** (single database transaction).
**
** When this is called, the super-journal should already have been
** created, populated with this journal pointer and synced to disk.
**
** Once this is routine has returned, the only thing required to commit
** the write-transaction for this database file is to delete the journal.
*/
int sqlite3BtreeCommitPhaseOne(Btree *p, const char *zSuperJrnl) {
  LUMO_LOG("sqlite3BtreeCommitPhaseOne(%d, %s) %s\n",
	   p->inTrans, LUMO_TXN(p->inTrans), p->path);
  if (p->inTrans != SQLITE_TXN_NONE) {
    int rc = closeAllSavepoints(p, -1, 1);
    if (rc) return error_map(rc);
    if (p->inTrans == SQLITE_TXN_WRITE) {
      rc = mdb_txn_commit(p->svp->txn);
      p->inTrans = SQLITE_TXN_NONE;
      if (rc) {
	LUMO_LOG("sqlite3BtreeCommitPhaseOne: fail %p %d\n", p->svp->txn, rc);
	return error_map(rc);
      }
      LUMO_LOG("sqlite3BtreeCommitPhaseOne: OK %p\n", p->svp->txn);
    } else {
      mdb_txn_abort(p->svp->txn);
      LUMO_LOG("sqlite3BtreeCommitPhaseOne: abort r/o transaction %p\n", p->svp->txn);
      p->inTrans = SQLITE_TXN_NONE;
    }
    sqlite3_free(p->svp);
    p->svp = NULL;
  }
  LUMO_LOG("sqlite3BtreeCommitPhaseOne OK\n");
  return SQLITE_OK;
}

int sqlite3BtreeCommitPhaseTwo(Btree *p, int bCleanup) {
  return SQLITE_OK;
}

int sqlite3BtreeCommit(Btree *p) {
  return sqlite3BtreeCommitPhaseOne(p, NULL);
}

/*
** Rollback the transaction in progress.
**
** If tripCode is not SQLITE_OK then cursors will be invalidated (tripped).
** Only write cursors are tripped if writeOnly is true but all cursors are
** tripped if writeOnly is false.  Any attempt to use
** a tripped cursor will result in an error.
**
** This will release the write lock on the database file.  If there
** are no active cursors, it also releases the read lock.
*/
int sqlite3BtreeRollback(Btree *p, int tripCode, int writeOnly) {
  if (p->inTrans != SQLITE_TXN_NONE) {
    if (tripCode != SQLITE_OK) {
      // XXX invalidate all / all write cursors
    }
    closeAllSavepoints(p, -1, 0);
    //XXX mdb_dbi_close(p->env, p->dataDbi);
    LUMO_LOG("sqlite3BtreeRollback abort %p\n", p->svp->txn);
    mdb_txn_abort(p->svp->txn);
    p->inTrans = SQLITE_TXN_NONE;
  }
  LUMO_LOG("sqlite3BtreeRollback done\n");
  return SQLITE_OK;
}

/*
** Start a statement subtransaction. The subtransaction can be rolled
** back independently of the main transaction. You must start a transaction 
** before starting a subtransaction. The subtransaction is ended automatically 
** if the main transaction commits or rolls back.
**
** Statement subtransactions are used around individual SQL statements
** that are contained within a BEGIN...COMMIT block.  If a constraint
** error occurs within the statement, the effect of that one statement
** can be rolled back without having to rollback the entire transaction.
**
** A statement sub-transaction is implemented as an anonymous savepoint. The
** value passed as the second parameter is the total number of savepoints,
** including the new anonymous savepoint, open on the B-Tree. i.e. if there
** are no active savepoints and no other statement-transactions open,
** iStatement is 1. This anonymous savepoint can be released or rolled back
** using the sqlite3BtreeSavepoint() function.
*/
int sqlite3BtreeBeginStmt(Btree *p, int iStatement) {
  int rc;
  struct BtreeSavepoint * S = sqlite3DbMallocZero(0, sizeof(struct BtreeSavepoint));
  if (! S) return SQLITE_NOMEM;
  rc = mdb_txn_begin(p->env, p->svp ? p->svp->txn : NULL, 0, &S->txn);
  if (rc) {
    sqlite3_free(S);
    LUMO_LOG("sqlite3BtreeBeginStmt(%d): %p fail %d\n", iStatement, p->svp ? p->svp->txn : NULL, rc);
    return error_map(rc);
  }
  LUMO_LOG("sqlite3BtreeBeginStmt(%d): %p OK %p\n", iStatement, p->svp ? p->svp->txn : NULL, S->txn);
  S->nSavepoint = iStatement;
  S->prev = p->svp;
  p->svp = S;
  return SQLITE_OK;
}

/*
** Create a new BTree table.  Write into *piTable the page
** number for the root page of the new table.
**
** The type of type is determined by the flags parameter.  Only the
** following values of flags are currently in use.  Other values for
** flags might not work:
**
**     BTREE_INTKEY|BTREE_LEAFDATA     Used for SQL tables with rowid keys
**     BTREE_ZERODATA                  Used for SQL indices
*/
int sqlite3BtreeCreateTable(Btree *p, Pgno *piTable, int flags) {
  MDB_dbi dbi;
  u32 pgnoRoot;
  int rc;
  sqlite3BtreeGetMeta(p, BTREE_LARGEST_ROOT_PAGE, &pgnoRoot);
  /* vdbe may decide the database is corrupted if the root page is 2 */
  if (pgnoRoot < 2)
    pgnoRoot = 3;
  else
    pgnoRoot++;
  *piTable = pgnoRoot;
  rc = get_table(p, pgnoRoot, get_table_create | ((flags & BTREE_INTKEY) ? 0 : get_table_index), &dbi);
  LUMO_LOG("sqlite3BtreeCreateTable(%u): %d\n", pgnoRoot, rc);
  if (rc) return error_map(rc);
  //XXX mdb_dbi_close(p->env, dbi);
  return sqlite3BtreeUpdateMeta(p, BTREE_LARGEST_ROOT_PAGE, pgnoRoot);
}

int sqlite3BtreeTxnState(Btree *p) {
  return p ? p->inTrans : SQLITE_TXN_NONE;
}

int sqlite3BtreeIsInBackup(Btree *p) {
  return p->inBackup;
}

/*
** This function returns a pointer to a blob of memory associated with
** a single shared-btree. The memory is used by client code for its own
** purposes (for example, to store a high-level schema associated with 
** the shared-btree). The btree layer manages reference counting issues.
**
** The first time this is called on a shared-btree, nBytes bytes of memory
** are allocated, zeroed, and returned to the caller. For each subsequent 
** call the nBytes parameter is ignored and a pointer to the same blob
** of memory returned. 
**
** If the nBytes parameter is 0 and the blob of memory has not yet been
** allocated, a null pointer is returned. If the blob has already been
** allocated, it is returned as normal.
**
** Just before the shared-btree is closed, the function passed as the 
** xFree argument when the memory allocation was made is invoked on the 
** blob of allocated memory. The xFree function should not call sqlite3_free()
** on the memory, the btree layer does that.
*/
void *sqlite3BtreeSchema(Btree *p, int nBytes, void(*xFree)(void *)){
  if (nBytes > 0 && !p->pSchema) {
    p->pSchema = sqlite3DbMallocZero(0, nBytes);
    p->xFreeSchema = xFree;
  }
  return p->pSchema;
}

int sqlite3BtreeSchemaLocked(Btree *p) {
  return SQLITE_OK;
}

int sqlite3BtreeLockTable(Btree *p, int iTab, u8 isWriteLock) {
  return SQLITE_OK;
}

/*
** The second argument to this function, op, is always SAVEPOINT_ROLLBACK
** or SAVEPOINT_RELEASE. This function either releases or rolls back the
** savepoint identified by parameter iSavepoint, depending on the value 
** of op.
**
** Normally, iSavepoint is greater than or equal to zero. However, if op is
** SAVEPOINT_ROLLBACK, then iSavepoint may also be -1. In this case the 
** contents of the entire transaction are rolled back. This is different
** from a normal transaction rollback, as no locks are released and the
** transaction remains open.
*/
int sqlite3BtreeSavepoint(Btree *p, int op, int iSavepoint) {
  LUMO_LOG("called: sqlite3BtreeSavepoint\n");
  int rc = closeAllSavepoints(p, iSavepoint, op == SAVEPOINT_RELEASE);
  if (rc) return error_map(rc);
  if (iSavepoint >= 0) return SQLITE_OK;
  assert(op == SAVEPOINT_ROLLBACK);
  // FIXME we abort this transaction but in reality we are supposed to keep
  // it open; we'll add a sub-transaction to deal with this case
  mdb_txn_abort(p->svp->txn);
  p->inTrans = SQLITE_TXN_NONE;
  return SQLITE_OK;
}

int sqlite3BtreeCheckpoint(Btree *p, int eMode, int *pnLog, int *pnCkpt) {
  LUMO_LOG("called: sqlite3BtreeCheckpoint\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeCheckpoint(Btree*, int, int *, int *);
}

/*
** Return the full pathname of the underlying database file.  Return
** an empty string if the database is in-memory or a TEMP database.
**
** The pager filename is invariant as long as the pager is
** open so it is safe to access without the BtShared mutex.
*/
const char *sqlite3BtreeGetFilename(Btree *p) {
  return p->isTemp ? "" : p->path;
}

/*
** Return the pathname of the journal file for this database. The return
** value of this routine is the same regardless of whether the journal file
** has been created or not.
**
** The pager journal filename is invariant as long as the pager is
** open so it is safe to access without the BtShared mutex.
*/
const char *sqlite3BtreeGetJournalname(Btree *p) {
  LUMO_LOG("called: sqlite3BtreeGetJournalname\n");
  return NULL;
}

int sqlite3BtreeCopyFile(Btree *pTo, Btree *pFrom) {
  LUMO_LOG("called: sqlite3BtreeCopyFile\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeCopyFile(Btree *, Btree *);
}

int sqlite3BtreeIncrVacuum(Btree *p) {
  LUMO_LOG("called: sqlite3BtreeIncrVacuum\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeIncrVacuum(Btree *);
}

/*
** Erase all information in a table and add the root of the table to
** the freelist.  Except, the root of the principle table (the one on
** page 1) is never added to the freelist.
**
** This routine will fail with SQLITE_LOCKED if there are any open
** cursors on the table.
**
** If AUTOVACUUM is enabled and the page at iTable is not the last
** root page in the database file, then the last root page 
** in the database file is moved into the slot formerly occupied by
** iTable and that last slot formerly occupied by the last root page
** is added to the freelist instead of iTable.  In this say, all
** root pages are kept at the beginning of the database file, which
** is necessary for AUTOVACUUM to work right.  *piMoved is set to the 
** page number that used to be the last root page in the file before
** the move.  If no page gets moved, *piMoved is set to 0.
** The last root page is recorded in meta[3] and the value of
** meta[3] is updated by this procedure.
*/
int sqlite3BtreeDropTable(Btree *p, int iTable, int *piMoved) {
  MDB_dbi dbi;
  int rc = get_table(p, iTable, get_table_nocmp, &dbi), entries = 0;
  LUMO_LOG("sqlite3BtreeDropTable: get_table=%d\n", rc);
  *piMoved = 0;
  if (rc) return error_map(rc);
  rc = mdb_drop(p->svp->txn, dbi, iTable > 1);
  if (rc) return error_map(rc);
  return SQLITE_OK;
}

/*
** Delete all information from a single table in the database.  iTable is
** the page number of the root of the table.  After this routine returns,
** the root page is empty, but still exists.
**
** This routine will fail with SQLITE_LOCKED if there are any open
** read cursors on the table.  Open write cursors are moved to the
** root of the table.
**
** If pnChange is not NULL, then table iTable must be an intkey table. The
** integer value pointed to by pnChange is incremented by the number of
** entries in the table.
*/
int sqlite3BtreeClearTable(Btree *p, int iTable, int *pnChange) {
  MDB_dbi dbi;
  int rc = get_table(p, iTable, get_table_nocmp, &dbi), entries = 0;
  LUMO_LOG("sqlite3BtreeClearTable: get_table=%d\n", rc);
  if (rc) return error_map(rc);
  if (pnChange) {
    MDB_stat stat;
    rc = mdb_stat(p->svp->txn, dbi, &stat);
    if (rc == 0) entries = stat.ms_entries;
  }
  rc = mdb_drop(p->svp->txn, dbi, 0);
  if (rc) return error_map(rc);
  if (pnChange) *pnChange += entries;
  return SQLITE_OK;
}

int sqlite3BtreeClearTableOfCursor(BtCursor *pCur) {
  LUMO_LOG("called: sqlite3BtreeClearTableOfCursor\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeClearTableOfCursor(BtCursor*);
}

int sqlite3BtreeTripAllCursors(Btree *p, int errCode, int writeOnly) {
  LUMO_LOG("called: sqlite3BtreeTripAllCursors\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeTripAllCursors(Btree*, int, int);
}

/*
** This function may only be called if the b-tree connection already
** has a read or write transaction open on the database.
**
** Read the meta-information out of a database file.  Meta[0]
** is the number of free pages currently in the database.  Meta[1]
** through meta[15] are available for use by higher layers.  Meta[0]
** is read-only, the others are read/write.
** 
** The schema layer numbers meta values differently.  At the schema
** layer (and the SetCookie and ReadCookie opcodes) the number of
** free pages is not visible.  So Cookie[0] is the same as Meta[1].
**
** This routine treats Meta[BTREE_DATA_VERSION] as a special case.  Instead
** of reading the value out of the header, it instead loads the "DataVersion"
** from the pager.  The BTREE_DATA_VERSION value is not actually stored in the
** database file.  It is a number computed by the pager.  But its access
** pattern is the same as header meta values, and so it is convenient to
** read it from this routine.
*/
void sqlite3BtreeGetMeta(Btree *p, int idx, u32 *pValue) {
  if (idx == BTREE_DATA_VERSION)
    *pValue = p->iDataVersion;
  else
    *pValue = get_int(p, idx);
  LUMO_LOG("sqlite3BtreeGetMeta(%d: %d)\n", idx, *pValue);
}

/*
** Write meta-information back into the database.  Meta[0] is
** read-only and may not be written.
*/
int sqlite3BtreeUpdateMeta(Btree *p, int idx, u32 iValue) {
  int rc = put_int(p, idx, iValue);
  if (rc) {
    LUMO_LOG("sqlite3BtreeUpdateMeta(%d): fail %d\n", idx, rc);
    return error_map(rc);
  }
  LUMO_LOG("sqlite3BtreeUpdateMeta(%d: %d)\n", idx, (int)iValue);
  return SQLITE_OK;
}

/*
** Create a new cursor for the BTree whose root is on the page
** iTable. If a read-only cursor is requested, it is assumed that
** the caller already has at least a read-only transaction open
** on the database already. If a write-cursor is requested, then
** the caller is assumed to have an open write transaction.
**
** If the BTREE_WRCSR bit of wrFlag is clear, then the cursor can only
** be used for reading.  If the BTREE_WRCSR bit is set, then the cursor
** can be used for reading or for writing if other conditions for writing
** are also met.  These are the conditions that must be met in order
** for writing to be allowed:
**
** 1:  The cursor must have been opened with wrFlag containing BTREE_WRCSR
**
** 2:  Other database connections that share the same pager cache
**     but which are not in the READ_UNCOMMITTED state may not have
**     cursors open with wrFlag==0 on the same table.  Otherwise
**     the changes made by this write cursor would be visible to
**     the read cursors in the other database connection.
**
** 3:  The database must be writable (not on read-only media)
**
** 4:  There must be an active transaction.
**
** The BTREE_FORDELETE bit of wrFlag may optionally be set if BTREE_WRCSR
** is set.  If FORDELETE is set, that is a hint to the implementation that
** this cursor will only be used to seek to and delete entries of an index
** as part of a larger DELETE statement.  The FORDELETE hint is not used by
** this implementation.  But in a hypothetical alternative storage engine 
** in which index entries are automatically deleted when corresponding table
** rows are deleted, the FORDELETE flag is a hint that all SEEK and DELETE
** operations on this cursor can be no-ops and all READ operations can 
** return a null row (2-bytes: 0x01 0x00).
**
** No checking is done to make sure that page iTable really is the
** root page of a b-tree.  If it is not, then the cursor acquired
** will not work correctly.
**
** It is assumed that the sqlite3BtreeCursorZero() has been called
** on pCur to initialize the memory space prior to invoking this routine.
*/
int sqlite3BtreeCursor(
  Btree *p,                                   /* The btree */
  Pgno iTable,                                /* Root page of table to open */
  int wrFlag,                                 /* 1 to write. 0 read-only */
  struct KeyInfo *pKeyInfo,                   /* First arg to xCompare() */
  BtCursor *pCur                              /* Write new cursor here */
){
  MDB_val key, data;
  int rc;
  pCur->pBtree = p;
  pCur->pKeyInfo = pKeyInfo;
  pCur->rootPage = iTable;
  pCur->cursor = NULL;
  rc = get_table(p, iTable, pKeyInfo ? get_table_index : 0, &pCur->dbi);
  if (rc) {
    LUMO_LOG("sqlite3BtreeCursor(%u): table fail %d\n", iTable, rc);
    return error_map(rc);
  }
  rc = mdb_cursor_open(p->svp->txn, pCur->dbi, &pCur->cursor);
  if (rc) {
    LUMO_LOG("sqlite3BtreeCursor (%u): open fail %d\n", iTable, rc);
    //XXX mdb_dbi_close(p->env, pCur->dbi);
    return error_map(rc);
  }
  pCur->atEof = 0;
  LUMO_LOG("sqlite3BtreeCursor(%u) %p %p\n", iTable, pCur, pCur->cursor);
  rc = mdb_cursor_get(pCur->cursor, &key, &data, MDB_FIRST);
  if (rc) pCur->atEof = 1;
  return SQLITE_OK;
}

BtCursor *sqlite3BtreeFakeValidCursor(void) {
  LUMO_LOG("sqlite3BtreeFakeValidCursor\n");
  return &fakeCursor;
}

/*
** Return the size of a BtCursor object in bytes.
**
** This interfaces is needed so that users of cursors can preallocate
** sufficient storage to hold a cursor.  The BtCursor object is opaque
** to users so they cannot do the sizeof() themselves - they must call
** this routine.
*/
int sqlite3BtreeCursorSize(void){
  return ROUND8(sizeof(BtCursor));
}

/*
** Initialize memory that will be converted into a BtCursor object.
**
** The simple approach here would be to memset() the entire object
** to zero.  But it turns out that the apPage[] and aiIdx[] arrays
** do not need to be zeroed and they are large, so we can save a lot
** of run-time by skipping the initialization of those elements.
*/
void sqlite3BtreeCursorZero(BtCursor *p){
  // memset(p, 0, offsetof(BtCursor, BTCURSOR_FIRST_UNINIT));
  memset(p, 0, sizeof(BtCursor));
}

/*
** Provide flag hints to the cursor.
*/
void sqlite3BtreeCursorHintFlags(BtCursor *pCur, unsigned x) {
  pCur->hints = x;
}

/*
** Close a cursor.  The read lock on the database file is released
** when the last cursor is closed.
*/
int sqlite3BtreeCloseCursor(BtCursor *pCur) {
  if (pCur->cursor) {
    LUMO_LOG("sqlite3BtreeCloseCursor %u %p %p\n", pCur->rootPage, pCur, pCur->cursor);
    mdb_cursor_close(pCur->cursor);
    // XXX we need to see if we are going to close this table or not
    //XXX mdb_dbi_close(pCur->pBtree->env, pCur->dbi);
    pCur->cursor = NULL;
  }
  return SQLITE_OK;
}

/* Move the cursor so that it points to an entry near the key 
** specified by pIdxKey or intKey.   Return a success code.
**
** For INTKEY tables, the intKey parameter is used.  pIdxKey 
** must be NULL.  For index tables, pIdxKey is used and intKey
** is ignored.
**
** If an exact match is not found, then the cursor is always
** left pointing at a leaf page which would hold the entry if it
** were present.  The cursor might point to an entry that comes
** before or after the key.
**
** An integer is written into *pRes which is the result of
** comparing the key with the entry to which the cursor is 
** pointing.  The meaning of the integer written into
** *pRes is as follows:
**
**     *pRes<0      The cursor is left pointing at an entry that
**                  is smaller than intKey/pIdxKey or if the table is empty
**                  and the cursor is therefore left point to nothing.
**
**     *pRes==0     The cursor is left pointing at an entry that
**                  exactly matches intKey/pIdxKey.
**
**     *pRes>0      The cursor is left pointing at an entry that
**                  is larger than intKey/pIdxKey.
**
** For index tables, the pIdxKey->eqSeen field is set to 1 if there
** exists an entry in the table that exactly matches pIdxKey.  
*/
int sqlite3BtreeMovetoUnpacked(
  BtCursor *pCur,          /* The cursor to be moved */
  UnpackedRecord *pIdxKey, /* Unpacked index key */
  i64 intKey,              /* The table key */
  int biasRight,           /* If true, bias the search to the high end */
  int *pRes                /* Write search results here */
){
  unsigned char b64[8];
  MDB_val key[2], data;
  u64 keyVal = intKey;
  int rc;
  pCur->atEof = 0;
  if (pIdxKey) {
    /* Move in an index or a WITHOUT ROWID table */
    key[0].mv_size = 1;
    key[0].mv_data = "";
    key[1].mv_data = pIdxKey;
  } else {
    /* move in a WITH ROWID table */
    put8(key, b64, keyVal);
  }
  data.mv_size = 0;
  data.mv_data = "";
  rc = mdb_cursor_get(pCur->cursor, key, &data, MDB_SET_RANGE);
  if (rc == 0) {
    /* see if the match is exact */
    if (pIdxKey) {
      *pRes = sqlite3VdbeRecordCompare(key[0].mv_size, key[0].mv_data, pIdxKey) != 0;
      LUMO_LOG("sqlite3BtreeMovetoUnpacked bias=%d => found (%d)\n", biasRight, *pRes);
    } else {
      *pRes = keyVal != get8(key);
      LUMO_LOG("sqlite3BtreeMovetoUnpacked idx=%lld bias=%d => found %lld (%d)\n", (long long)keyVal, biasRight, (long long)get8(key), *pRes);
    }
    return SQLITE_OK;
  }
  if (rc != MDB_NOTFOUND) {
    LUMO_LOG("sqlite3BtreeMovetoUnpacked idx=%d bias=%d => failed (MDB_SET_RANGE) %d\n", (int)intKey, biasRight, rc);
    return error_map(rc);
  }
  LUMO_LOG("sqlite3BtreeMovetoUnpacked idx=%d bias=%d => not found\n", (int)intKey, biasRight);
  /* we'll pretend the cursor is on the first item */
  mdb_cursor_get(pCur->cursor, key, &data, MDB_FIRST);
  *pRes = -1;
  LUMO_LOG("sqlite3BtreeMovetoUnpacked idx=%d bias=%d => empty, returning first\n", (int)intKey, biasRight);
  return SQLITE_OK;
}

int sqlite3BtreeCursorHasMoved(BtCursor *pCur) {
  MDB_val key, data;
  int rc;
  if (pCur == &fakeCursor) {
    LUMO_LOG("sqlite3BtreeCursorHasMoved (fake): 0\n");
    return 0;
  }
  rc = mdb_cursor_get(pCur->cursor, &key, &data, MDB_GET_CURRENT);
  LUMO_LOG("sqlite3BtreeCursorHasMoved %u: %d\n", pCur->rootPage, rc);
  if (rc) return 1;
  return 0;
}

int sqlite3BtreeCursorRestore(BtCursor *pCur, int *pDifferentRow) {
  LUMO_LOG("called: sqlite3BtreeCursorRestore\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeCursorRestore(BtCursor*, int*);
}
/*
** Delete the entry that the cursor is pointing to. 
**
** If the BTREE_SAVEPOSITION bit of the flags parameter is zero, then
** the cursor is left pointing at an arbitrary location after the delete.
** But if that bit is set, then the cursor is left in a state such that
** the next call to BtreeNext() or BtreePrev() moves it to the same row
** as it would have been on if the call to BtreeDelete() had been omitted.
**
** The BTREE_AUXDELETE bit of flags indicates that is one of several deletes
** associated with a single table entry and its indexes.  Only one of those
** deletes is considered the "primary" delete.  The primary delete occurs
** on a cursor that is not a BTREE_FORDELETE cursor.  All but one delete
** operation on non-FORDELETE cursors is tagged with the AUXDELETE flag.
** The BTREE_AUXDELETE bit is a hint that is not used by this implementation,
** but which might be used by alternative storage engines.
*/
int sqlite3BtreeDelete(BtCursor *pCur, u8 flags) {
  /* mdb_cursor_del will leave the cursor in such a state that a call to
  ** mdb_cursor_get with MDB_NEXT or MDB_PREV does the required thing,
  ** so no need to do anything special for BTREE_SAVEPOSITION */
  int rc = mdb_cursor_del(pCur->cursor, 0);
  LUMO_LOG("sqlite3BtreeDelete: %d\n", rc);
  if (rc) return error_map(rc);
  return SQLITE_OK;
}

/*
** Insert a new record into the BTree.  The content of the new record
** is described by the pX object.  The pCur cursor is used only to
** define what table the record should be inserted into, and is left
** pointing at a random location.
**
** For a table btree (used for rowid tables), only the pX.nKey value of
** the key is used. The pX.pKey value must be NULL.  The pX.nKey is the
** rowid or INTEGER PRIMARY KEY of the row.  The pX.nData,pData,nZero fields
** hold the content of the row.
**
** For an index btree (used for indexes and WITHOUT ROWID tables), the
** key is an arbitrary byte sequence stored in pX.pKey,nKey.  The 
** pX.pData,nData,nZero fields must be zero.
**
** If the seekResult parameter is non-zero, then a successful call to
** MovetoUnpacked() to seek cursor pCur to (pKey,nKey) has already
** been performed.  In other words, if seekResult!=0 then the cursor
** is currently pointing to a cell that will be adjacent to the cell
** to be inserted.  If seekResult<0 then pCur points to a cell that is
** smaller then (pKey,nKey).  If seekResult>0 then pCur points to a cell
** that is larger than (pKey,nKey).
**
** If seekResult==0, that means pCur is pointing at some unknown location.
** In that case, this routine must seek the cursor to the correct insertion
** point for (pKey,nKey) before doing the insertion.  For index btrees,
** if pX->nMem is non-zero, then pX->aMem contains pointers to the unpacked
** key values and pX->aMem can be used instead of pX->pKey to avoid having
** to decode the key.
*/
int sqlite3BtreeInsert(
  BtCursor *pCur,                /* Insert data into the table of this cursor */
  const BtreePayload *pX,        /* Content of the row to be inserted */
  int flags,                     /* True if this is likely an append */
  int seekResult                 /* Result of prior MovetoUnpacked() call */
){
  MDB_val key[2], data;
  UnpackedRecord *pUnpacked = NULL, aUnpacked;
  int rc;
  unsigned int mdbFlags = 0;
  const int lumoData = pCur->pBtree->flags & BTREE_LUMO_EXTENSIONS;
#ifdef LUMO_LOG_INSERTS
  LUMO_LOG("sqlite3BtreeInsert: data before\n");
  LUMO_LOG_CURSOR(pCur->cursor, pCur->pKeyInfo != NULL);
#endif
  if (pCur->pKeyInfo) {
    /* inserting into an index or a WITHOUT ROWID table
    ** we allow the caller to provide data as well as key and this
    ** will be considered a Lumo column; the caller can retrieve
    ** that but only if they know to ask for it */
    if (pX->nMem) {
      aUnpacked.pKeyInfo = pCur->pKeyInfo;
      aUnpacked.aMem = pX->aMem;
      aUnpacked.nField = pX->nMem;
      aUnpacked.default_rc = 0;
      aUnpacked.errCode = 0;
      aUnpacked.r1 = 0;
      aUnpacked.r2 = 0;
      aUnpacked.eqSeen = 0;
    } else {
      /* we don't have an unpacked version of the key, so we add it now
      ** as it helps with comparisons */
      pUnpacked = sqlite3VdbeAllocUnpackedRecord(pCur->pKeyInfo);
      if (! pUnpacked) return SQLITE_NOMEM_BKPT;
      sqlite3VdbeRecordUnpack(pCur->pKeyInfo, (int)pX->nKey, pX->pKey, pUnpacked);
      if (pUnpacked->nField==0 || pUnpacked->nField>pCur->pKeyInfo->nAllField) {
	rc = SQLITE_CORRUPT_BKPT;
	goto out;
      }
    }
    /* an LMDB key is limited in length to the value returned by
    ** mdb_env_get_maxkeysize (normally 511); we can change that while
    ** building LMDB, but we can't do that on a system-built LMDB so
    ** we'll just limit keys to 511 bytes; in fact we currently limit
    ** them to 479 bytes, the remaining 32 bytes will be used to add
    ** a mechanism to cope with longer keys; the mechanism is already
    ** designed but (FIXME) not implemented yet until this bit of code
    ** is fully tested; we initially thought to move the rest of the
    ** key to the data, but we'd need to keep that sorted and that would
    ** result in the data having length limits, so we'd just push the
    ** problem to longer keys; instead the mechanism will move the
    ** rest of the key to the data without requiring the data to be
    ** sorted and therefore without introducing any length limits;
    ** the code to read the payload is already expecting the possibility
    ** of key being split in two, so that won't need to be changed */
    LUMO_LOG("sqlite3BtreeInsert(%u) key(%zd)", pCur->rootPage, (size_t)pX->nKey);
    LUMO_LOG_DATA(pX->nKey, pX->pKey);
    if (lumoData) {
      LUMO_LOG(" -- data(%zd)", (size_t)pX->nData);
      LUMO_LOG_DATA(pX->nData, pX->pData);
    }
    LUMO_LOG("\n");
    if (pX->nKey > LUMO_LMDB_MAX_KEY) {
      return SQLITE_INTERNAL; // FIXME see above comment
    } else {
      key[0].mv_size = pX->nKey;
      key[0].mv_data = (void *)pX->pKey;
      key[1].mv_data = (void *)(pUnpacked ? pUnpacked : &aUnpacked);
      data.mv_size = sqlite3VarintLen(0);
      if (lumoData) data.mv_size += pX->nData;
    }
    mdbFlags = MDB_RESERVE;
  } else {
    /* inserting into a WITH ROWID table */
    unsigned char bKey[8];
    u64 keyVal = pX->nKey;
    put8(key, bKey, keyVal);
    LUMO_LOG("sqlite3BtreeInsert(%u) key=%lld:", pCur->rootPage, (long long)keyVal);
    LUMO_LOG_DATA(key[0].mv_size, key[0].mv_data);
    LUMO_LOG(", data(%d+%d):", (int)pX->nData, (int)pX->nZero);
    LUMO_LOG_DATA(pX->nData, pX->pData);
    LUMO_LOG("\n");
    data.mv_size = pX->nData + pX->nZero;
    if (pX->nZero) {
      mdbFlags = MDB_RESERVE;
    } else {
      data.mv_data = (void *)pX->pData;
    }
  }
  rc = mdb_cursor_put(pCur->cursor, key, &data, mdbFlags);
  if (rc) {
    LUMO_LOG("sqlite3BtreeInsert(%u): failed(%d)\n", pCur->rootPage, rc);
    goto out_map;
  }
  if (pCur->pKeyInfo) {
    /* copy index data if required */
    unsigned char * ptr = data.mv_data;
    if (pX->nKey > LUMO_LMDB_MAX_KEY) {
      // FIXME - add the appropriate code
    } else {
      ptr += putVarint32(ptr, 0);
      if (lumoData)
	memcpy(ptr, pX->pData, pX->nData);
    }
    LUMO_LOG("  ==> LMDB key(%zd)", (size_t)key[0].mv_size);
    LUMO_LOG_DATA(key[0].mv_size, key[0].mv_data);
    LUMO_LOG("  -- data(%zd)", (size_t)data.mv_size);
    LUMO_LOG_DATA(data.mv_size, data.mv_data);
    LUMO_LOG("\n");
  } else if (pX->nZero) {
    /* copy data and the required number of zeros */
    unsigned char * ptr = data.mv_data;
    memcpy(ptr, pX->pData, pX->nData);
    ptr += pX->nData;
    memset(ptr, 0, pX->nZero);
  }
  LUMO_LOG("sqlite3BtreeInsert(%u): OK\n", pCur->rootPage);
  rc = SQLITE_OK;
  goto out;
out_map:
  rc = error_map(rc);
out:
  if (pUnpacked)
    sqlite3DbFree(pCur->pKeyInfo->db, pUnpacked);
#ifdef LUMO_LOG_INSERTS
  LUMO_LOG("sqlite3BtreeInsert: data after\n");
  LUMO_LOG_CURSOR(pCur->cursor, pCur->pKeyInfo != NULL);
#endif
  return rc;
}

/* Move the cursor to the first entry in the table.  Return SQLITE_OK
** on success.  Set *pRes to 0 if the cursor actually points to something
** or set *pRes to 1 if the table is empty.
*/
int sqlite3BtreeFirst(BtCursor *pCur, int *pRes) {
  MDB_val key, data;
  int rc = mdb_cursor_get(pCur->cursor, &key, &data, MDB_FIRST);
  if (rc) {
    if (rc != MDB_NOTFOUND) {
      LUMO_LOG("sqlite3BtreeFirst (%u): fail %d\n", pCur->rootPage, rc);
      return error_map(rc);
    }
    pCur->atEof = *pRes = 1;
  } else {
    pCur->atEof = *pRes = 0;
  }
  LUMO_LOG("sqlite3BtreeFirst(%u): %d\n", pCur->rootPage, *pRes);
  return SQLITE_OK;
}

/* Move the cursor to the last entry in the table.  Return SQLITE_OK
** on success.  Set *pRes to 0 if the cursor actually points to something
** or set *pRes to 1 if the table is empty.
*/
int sqlite3BtreeLast(BtCursor *pCur, int *pRes) {
  MDB_val key, data;
  int rc = mdb_cursor_get(pCur->cursor, &key, &data, MDB_LAST);
  if (rc) {
    if (rc != MDB_NOTFOUND) {
      LUMO_LOG("sqlite3BtreeLast (%u): fail %d\n", pCur->rootPage, rc);
      return error_map(rc);
    }
    pCur->atEof = *pRes = 1;
  } else {
    pCur->atEof = *pRes = 0;
  }
  LUMO_LOG("sqlite3BtreeLast(%u): %d\n", pCur->rootPage, *pRes);
  return SQLITE_OK;
}

int sqlite3BtreeNext(BtCursor *pCur, int flags) {
  MDB_val key, data;
  int rc = mdb_cursor_get(pCur->cursor, &key, &data, MDB_NEXT);
  if (rc) {
    if (rc != MDB_NOTFOUND) {
      LUMO_LOG("sqlite3BtreeNext (%u): fail %d\n", pCur->rootPage, rc);
      return error_map(rc);
    }
    LUMO_LOG("sqlite3BtreeNext(%u): eof\n", pCur->rootPage);
    pCur->atEof = 1;
    return SQLITE_DONE;
  }
  LUMO_LOG("sqlite3BtreeNext(%u): OK\n", pCur->rootPage);
  return SQLITE_OK;
}

int sqlite3BtreeEof(BtCursor *pCur) {
  LUMO_LOG("sqlite3BtreeEof %u: %d\n", pCur->rootPage, (int)pCur->atEof);
  return pCur->atEof;
}

int sqlite3BtreePrevious(BtCursor *pCur, int flags) {
  LUMO_LOG("called: sqlite3BtreePrevious\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreePrevious(BtCursor*, int flags);
}

/*
** Return the value of the integer key or "rowid" for a table btree.
** This routine is only valid for a cursor that is pointing into a
** ordinary table btree.  If the cursor points to an index btree or
** is invalid, the result of this routine is undefined.
*/
i64 sqlite3BtreeIntegerKey(BtCursor *pCur) {
  MDB_val key, data;
  i64 res;
  int rc = mdb_cursor_get(pCur->cursor, &key, &data, MDB_GET_CURRENT);
  res = rc ? 0 : get8(&key);
  LUMO_LOG("sqlite3BtreeIntegerKey %u: %d %zd (%lld)\n", pCur->rootPage, rc, key.mv_size, (long long)res);
  return res;
}

void sqlite3BtreeCursorPin(BtCursor *pCur) {
  LUMO_LOG("called: sqlite3BtreeCursorPin\n");
  // XXX void sqlite3BtreeCursorPin(BtCursor*);
}

void sqlite3BtreeCursorUnpin(BtCursor *pCur) {
  LUMO_LOG("called: sqlite3BtreeCursorUnpin\n");
  // XXX void sqlite3BtreeCursorUnpin(BtCursor*);
}

int sqlite3BtreePayload(BtCursor *pCur, u32 offset, u32 amt, void *pBuf) {
  LUMO_LOG("called: sqlite3BtreePayload\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreePayload(BtCursor*, u32 offset, u32 amt, void*);
}

/*
** For the entry that cursor pCur is point to, return as
** many bytes of the key or data as are available on the local
** b-tree page.  Write the number of available bytes into *pAmt.
**
** The pointer returned is ephemeral.  The key/data may move
** or be destroyed on the next call to any Btree routine,
** including calls from other threads against the same cache.
** Hence, a mutex on the BtShared should be held prior to calling
** this routine.
**
** These routines is used to get quick access to key and data
** in the common case where no overflow pages are used.
*/
const void *sqlite3BtreePayloadFetch(BtCursor *pCur, u32 *pAmt){
  MDB_val key, data;
  int rc = mdb_cursor_get(pCur->cursor, &key, &data, MDB_GET_CURRENT);
  LUMO_LOG("sqlite3BtreePayloadFetch %u: %d\n", pCur->rootPage, rc);
  if (rc) {
    *pAmt = 0;
    return "";
  }
  if (! pCur->pKeyInfo) LUMO_LOG("ID(%lld) ", (long long)get8(&key));
  LUMO_LOG("payload(%zd)", pCur->pKeyInfo ? key.mv_size : data.mv_size);
  LUMO_LOG_DATA(pCur->pKeyInfo ? key.mv_size : data.mv_size, pCur->pKeyInfo ? key.mv_data : data.mv_data);
  LUMO_LOG("\n");
  if (pCur->pKeyInfo) {
    *pAmt = key.mv_size;
    return key.mv_data;
  } else {
    *pAmt = data.mv_size;
    return data.mv_data;
  }
}

/*
** Return the number of bytes of payload for the entry that pCur is
** currently pointing to.  For table btrees, this will be the amount
** of data.  For index btrees, this will be the size of the key.
**
** The caller must guarantee that the cursor is pointing to a non-NULL
** valid entry.  In other words, the calling procedure must guarantee
** that the cursor has Cursor.eState==CURSOR_VALID.
*/
u32 sqlite3BtreePayloadSize(BtCursor *pCur){
  MDB_val key, data;
  int rc = mdb_cursor_get(pCur->cursor, &key, &data, MDB_GET_CURRENT);
  if (rc) return 0;
  if (pCur->pKeyInfo) return key.mv_size;
  return data.mv_size;
}

sqlite3_int64 sqlite3BtreeMaxRecordSize(BtCursor *pCur){
  LUMO_LOG("called: sqlite3BtreeMaxRecordSize\n");
  return 0; // XXX sqlite3_int64 sqlite3BtreeMaxRecordSize(BtCursor*);
}

char *sqlite3BtreeIntegrityCheck(sqlite3 *db, Btree *p, Pgno *aRoot, int nRoot, int mxErr, int *pnErr) {
  LUMO_LOG("called: sqlite3BtreeIntegrityCheck\n");
  return NULL; // XXX char *sqlite3BtreeIntegrityCheck(sqlite3*,Btree *p,Pgno*aRoot,int nRoot,int,int*);
}

Pager *sqlite3BtreePager(Btree *p){
  return (Pager *)p;
}

i64 sqlite3BtreeRowCountEst(BtCursor *pCur){
  LUMO_LOG("called: sqlite3BtreeRowCountEst\n");
  return 0; // XXX i64 sqlite3BtreeRowCountEst(BtCursor*);
}

int sqlite3BtreePayloadChecked(BtCursor *pCur, u32 offset, u32 amt, void *pBuf){
  LUMO_LOG("called: sqlite3BtreePayloadChecked\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreePayloadChecked(BtCursor*, u32 offset, u32 amt, void*);
}

int sqlite3BtreePutData(BtCursor *pCsr, u32 offset, u32 amt, void *z){
  LUMO_LOG("called: sqlite3BtreePutData\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreePutData(BtCursor*, u32 offset, u32 amt, void*);
}

void sqlite3BtreeIncrblobCursor(BtCursor *pCur){
  LUMO_LOG("called: sqlite3BtreeIncrblobCursor\n");
  // XXX void sqlite3BtreeIncrblobCursor(BtCursor *);
}

void sqlite3BtreeClearCursor(BtCursor *pCur){
  LUMO_LOG("called: sqlite3BtreeClearCursor\n");
  // XXX void sqlite3BtreeClearCursor(BtCursor *);
}

int sqlite3BtreeSetVersion(Btree *p, int iVersion) {
  LUMO_LOG("called: sqlite3BtreeSetVersion\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeSetVersion(Btree *pBt, int iVersion);
}

/*
** Return true if the cursor has a hint specified.  This routine is
** only used from within assert() statements
*/
int sqlite3BtreeCursorHasHint(BtCursor *pCur, unsigned int mask) {
  return (pCur->hints & mask)!=0;
}

int sqlite3BtreeIsReadonly(Btree *p) {
  LUMO_LOG("called: sqlite3BtreeIsReadonly\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeIsReadonly(Btree *pBt);
}

int sqlite3HeaderSizeBtree(void) {
  LUMO_LOG("called: sqlite3HeaderSizeBtree\n");
  return SQLITE_INTERNAL; // XXX int sqlite3HeaderSizeBtree(void);
}

int sqlite3BtreeCursorIsValidNN(BtCursor *pCur) {
  LUMO_LOG("called: sqlite3BtreeCursorIsValidNN\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeCursorIsValidNN(BtCursor*);
}

int sqlite3BtreeCount(sqlite3 *db, BtCursor *pCur, i64 *pnEntry) {
  LUMO_LOG("called: sqlite3BtreeCount\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeCount(sqlite3*, BtCursor*, i64*);
}

int sqlite3BtreeSharable(Btree *p) {
  return 0;
}

int sqlite3BtreeConnectionCount(Btree *p) {
  LUMO_LOG("called: sqlite3BtreeConnectionCount\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeConnectionCount(Btree *p);
}

int sqlite3BtreeGetReserveNoMutex(Btree *p) {
  LUMO_LOG("called: sqlite3BtreeGetReserveNoMutex\n");
  return SQLITE_INTERNAL; // XXX int sqlite3BtreeGetReserveNoMutex(Btree *);
}

i64 sqlite3BtreeOffset(BtCursor *pCur) {
  LUMO_LOG("called: sqlite3BtreeOffset\n");
  return 0; // XXX i64 sqlite3BtreeOffset(BtCursor*);
}

/* empty enter/leave routines: not needed by LMDB */
void sqlite3BtreeEnter(Btree *p){ }
void sqlite3BtreeEnterCursor(BtCursor *pCur){ }
void sqlite3BtreeEnterAll(sqlite3 *db){ }
void sqlite3BtreeLeave(Btree *p){ }
void sqlite3BtreeLeaveCursor(BtCursor *pCur){ }
void sqlite3BtreeLeaveAll(sqlite3 *db){ }

/*
** Return true if this is an in-memory or temp-file backed pager.
*/
/* this is here because we have a "fake" pager which is actually a Btree */
int sqlite3PagerIsMemdb(Pager *pPager){
  Btree *p = (Btree*)pPager;
  return p->isMemdb;
}

#endif
