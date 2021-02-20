/*

  Modifications copyright 2019 The LumoSQL Authors under the terms contained in the file LICENSES/MIT

  SPDX-License-Identifier: MIT
  SPDX-FileCopyrightText: 2019 The LumoSQL Authors
  SPDX-ArtifactOfProjectName: LumoSQL
  SPDX-FileType: Code
  SPDX-FileComment: Original by Howard Chu, 2011

  not-fork.d/lmdb/files/btree.c
*/

#ifndef __LUMO_BACKEND_btree_c
#define __LUMO_BACKEND_btree_c 1

#include "lumo_btreeInt.h"
#include "vdbeInt.h"
#define MDB_MAXKEYSIZE	2000
#define MDB_USE_HASH	1
#include <sys/types.h>
#include <dirent.h>
#include "lmdb.h"

#ifndef NAME_MAX
#define NAME_MAX 256
#endif

#if MDB_VERSION_FULL < MDB_VERINT(0,9,19)
#define MC_READ(mc) (mc)->mc_txn
#else
#define MC_READ(mc) (mc)
#endif

#if 0
#define LOG(fmt,...)   sqlite3DebugPrintf("%s:%d " fmt "\n", __func__, __LINE__, __VA_ARGS__)
#else
#define LOG(fmt,...)	((void)0)
#endif

/*
 * Globals are protected by the static "open" mutex (SQLITE_MUTEX_STATIC_OPEN).
 */

/* The head of the linked list of shared Btree objects */
struct BtShared *sqlite3SharedCacheList = NULL;

/* The environment handle used for temporary environments (NULL or open). */
MDB_env *g_tmp_env;

/* rowid is an 8 byte int */
#define ROWIDMAXSIZE	10

#ifndef SQLITE_DEFAULT_FILE_PERMISSIONS
#define SQLITE_DEFAULT_FILE_PERMISSIONS	0644
#endif

#ifndef SQLITE_DEFAULT_PROXYDIR_PERMISSIONS
#define SQLITE_DEFAULT_PROXYDIR_PERMISSIONS	0755
#endif

#define	BT_MAX_PATH	512

static int errmap(int err)
{
  switch(err) {
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
    return SQLITE_NOMEM;
  case ENOENT:
    return SQLITE_CANTOPEN;
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
    return SQLITE_CORRUPT;
  case MDB_INCOMPATIBLE:
    return SQLITE_SCHEMA;
  case MDB_BAD_RSLOT:
    return SQLITE_MISUSE;
  case MDB_BAD_TXN:
    return SQLITE_ABORT;
  case MDB_BAD_VALSIZE:
    return SQLITE_TOOBIG;
  default:
    return SQLITE_INTERNAL;
  }
}

/* sqlightning used direct access to a cursor's internals to see if it
 * had been initialised; it also sets it to uninitialised in some cases;
 * we use a separate element to track this, and if we believe the cursor
 * to be initialised, we also use mdb_cursor_count to check if that's
 * still the case */
static int cursor_initialised(BtCursor *pCur) {
  if (pCur->mc_init) {
    size_t cp;
    return (mdb_cursor_count(pCur->mc, &cp) != EINVAL);
  }
  return 0;
}

/* in future we may decide to store these flags somewhere in the cursor
 * structure, but for now we use this function */
static inline unsigned long int cursor_flags(MDB_cursor *mc) {
  unsigned int flags;
  mdb_dbi_flags(mdb_cursor_txn(mc), mdb_cursor_dbi(mc), &flags);
  return flags;
}

/* dbi flags */
static inline unsigned long int dbi_flags(MDB_txn *txn, MDB_dbi dbi) {
  unsigned int flags;
  mdb_dbi_flags(txn, dbi, &flags);
  return flags;
}

/* count number of entries in the btree where this cursor is open */
static i64 cursor_entries(MDB_cursor *mc) {
  MDB_stat envstat;
  mdb_stat(mdb_cursor_txn(mc), mdb_cursor_dbi(mc), &envstat);
  return (i64)envstat.ms_entries;
}

/* count number of entries in a dvi */
static size_t dbi_entries(MDB_txn *txn, MDB_dbi dbi) {
  MDB_stat envstat;
  mdb_stat(txn, dbi, &envstat);
  return envstat.ms_entries;
}

/*
** Start a statement subtransaction. The subtransaction can can be rolled
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
int sqlite3BtreeBeginStmt(Btree *p, int iStatement){
  MDB_txn *txn;
  BtShared *pBt = p->pBt;
  int rc;
  sqlite3BtreeEnter(p);
  assert( p->inTrans==TRANS_WRITE );
  assert( iStatement>0 );
  assert( iStatement>p->db->nSavepoint );
  assert( pBt->inTransaction==TRANS_WRITE );
  /* At the pager level, a statement transaction is a savepoint with
  ** an index greater than all savepoints created explicitly using
  ** SQL statements. It is illegal to open, release or rollback any
  ** such savepoints while the statement transaction savepoint is active.
  */
  rc = mdb_txn_begin(pBt->env, p->curr_txn, 0, &txn);
  if (rc == 0)
  	p->curr_txn = txn;
  sqlite3BtreeLeave(p);
  LOG("rc=%d",rc);
  return errmap(rc);
}

/*
** Attempt to start a new transaction. A write-transaction
** is started if the second argument is nonzero, otherwise a read-
** transaction.  If the second argument is 2 or more an exclusive
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
** SQLite allows a transaction to be started read-only and then upgraded to
** read-write; LMDB does not allow that; sqlightning worked around this by
** creating a new read-write transaction and copying various bits of LMDB
** internals from the old (read-only) transaction; this was perfect for a
** proof of concept but it causes SQL errors in some cases and it's not
** portable across LMDB versions; therefore for LumoSQL we assume that any
** transaction started on a writable database is read-write and let LMDB
** finer-grained locking take care of concurrency issues.
*/
int sqlite3BtreeBeginTrans(Btree *p, int wrflag){
  MDB_txn *txn;
  BtShared *pBt = p->pBt;
  int rc = SQLITE_OK;

  /* Write transactions are not possible on a read-only database */
  if ((p->eFlags & MDB_RDONLY)!=0 && wrflag) {
    rc = SQLITE_READONLY;
    goto done;
  }

  /* otherwise force wrflag to match how the database was opened, as
   * per above comment
   */
  wrflag = (p->eFlags & MDB_RDONLY) == 0;

  /* if we are already in a transaction, this is an upgrade to read-write,
   * which is a no-op */
  if ((p->inTrans == TRANS_WRITE) ||
	(p->inTrans == TRANS_READ && !wrflag))
	goto done;

  rc = mdb_txn_begin(pBt->env, NULL, wrflag ? 0 : MDB_RDONLY, &txn);
  if (rc == 0) {
	if (wrflag) {
	  p->inTrans = TRANS_WRITE;
	} else {
	  p->inTrans = TRANS_READ;
	}
	p->main_txn = txn;
	p->curr_txn = txn;
  }

done:
  LOG("rc=%d",rc);
  return errmap(rc);
}

#ifndef SQLITE_OMIT_INCRBLOB
/*
** Argument pCsr must be a cursor opened for writing on an 
** INTKEY table currently pointing at a valid table entry. 
** This function modifies the data stored as part of that entry.
**
** Only the data content may be modified, it is not possible to 
** change the length of the data stored. If this function is called with
** parameters that attempt to write past the end of the existing data,
** no modifications are made and SQLITE_CORRUPT is returned.
*/
int sqlite3BtreePutData(BtCursor *pCsr, u32 offset, u32 amt, void *z){
  char *free_me = NULL;
  MDB_cursor *mc = pCsr->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_GET_CURRENT);

  if (rc)
    return SQLITE_ABORT;

  /* Check some assumptions: 
  **   (e) the cursor points at a valid row of an intKey table.
  */
  assert((cursor_flags(mc) & MDB_INTEGERKEY) != 0);

  if (data.mv_size < offset+amt)
  	return SQLITE_CORRUPT_BKPT;

  if (offset == 0 && amt == data.mv_size) {
	/* overwrite the whole data */
	data.mv_data = z;
  } else {
	/* overwrite part of the data, we need to make a copy */
	// XXX is there a way to avoid this double copy? sqlightning accessed the
	// XXX LMDB internals but we can't do that - also, this essentially makes
	// XXX incrblobs a lot slower than just writing whole blobs at once
	free_me = sqlite3_malloc(data.mv_size);
	if (! free_me)
	  return SQLITE_NOMEM;
	if (offset > 0)
	  memcpy(free_me, data.mv_data, offset);
	memcpy(free_me+offset, z, amt);
	offset += amt;
	if (offset < data.mv_size)
	  memcpy(free_me+offset, (char *)data.mv_data+offset, data.mv_size-offset);
  }
  rc = mdb_cursor_put(mc, &key, &data, MDB_CURRENT);
  if (free_me) 
	sqlite3_free(free_me);
  if (rc)
	return errmap(rc);
  return SQLITE_OK;
}

/* 
** Set a flag on this cursor to cache the locations of pages from the 
** overflow list for the current row. This is used by cursors opened
** for incremental blob IO only.
*/
void sqlite3BtreeCacheOverflow(BtCursor *pCur){
  LOG("done",0);
}
#endif

#ifndef SQLITE_OMIT_WAL
/*
** Run a checkpoint on the Btree passed as the first argument.
**
** Return SQLITE_LOCKED if this or any other connection has an open 
** transaction on the shared-cache the argument Btree is connected to.
**
** Parameter eMode is one of SQLITE_CHECKPOINT_PASSIVE, FULL or RESTART.
*/
int sqlite3BtreeCheckpoint(Btree *p, int eMode, int *pnLog, int *pnCkpt){
  int rc = 0;
  if( p ){
    BtShared *pBt = p->pBt;
	rc = mdb_env_sync(pBt->env, 1);
  }
  LOG("rc=%d",rc);
  return errmap(rc);
}
#endif

/*
** Clear the current cursor position.
*/
void sqlite3BtreeClearCursor(BtCursor *pCur){
  MDB_val key, data;
  mdb_cursor_get(pCur->mc, &key, &data, MDB_FIRST);
  pCur->mc_init = 1;
  LOG("done",0);
}

static int BtreeCompare(const MDB_val *a, const MDB_val *b)
{
  UnpackedRecord *p = a[1].mv_data;
  return -sqlite3VdbeRecordCompare(b->mv_size, b->mv_data, p);
}

static int BtreeTableHandle(Btree *p, int iTable, MDB_dbi *dbi)
{
  char name[13], *nptr;
  int rc, setName = 1;

  if (iTable == 1) {
	MDB_dbi main_dbi;
	rc = mdb_dbi_open(p->curr_txn, NULL, 0, &main_dbi);
	if (rc) goto done;
	if (! dbi_entries(p->curr_txn, main_dbi)) {
	  setName = 0;
	  nptr = NULL;
	}
  }
  if (setName) {
	nptr = name;
	sprintf(name, "Tab.%08x", iTable);
  }
  rc = mdb_open(p->curr_txn, nptr, 0, dbi);
  if (!rc && (dbi_flags(p->curr_txn, *dbi) & MDB_DUPSORT)) {
	mdb_set_compare(p->curr_txn, *dbi, BtreeCompare);
  }
done:
  return errmap(rc);
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
int sqlite3BtreeClearTable(Btree *p, int iTable, int *pnChange){
  int ents = 0, rc;
  MDB_dbi dbi;
  assert(p->curr_txn != NULL);
  if (pnChange) {
    assert(dbi_flags(p->curr_txn, iTable) & MDB_INTEGERKEY);
	ents = dbi_entries(p->curr_txn, iTable);
  }
  rc = BtreeTableHandle(p, iTable, &dbi);
  if (rc)
    goto done;
  rc = mdb_drop(p->curr_txn, dbi, 0);
  if (rc == 0 && pnChange)
  	*pnChange += ents;
done:
  LOG("rc=%d",rc);
  return errmap(rc);
}

/*
** Close an open database and invalidate all cursors.
*/
int sqlite3BtreeClose(Btree *p){
  BtShared *pBt = p->pBt;
  BtCursor *pCur;
  sqlite3_mutex *mutexOpen;

  /* Close all cursors opened via this handle. */
  pCur = p->pCursor;
  while (pCur) {
    BtCursor *pTmp = pCur;
	pCur = pCur->pNext;
	sqlite3BtreeCloseCursor(pTmp);
  }

  /* Abort any active transaction */
  mdb_txn_abort(p->main_txn);

  if (p->isTemp) {
    MDB_env *env = pBt->env;
    char *path;
    const char *epath;
	int len, rc;
	sqlite3_free(pBt);
	rc = mdb_env_get_path(env, &epath);
	/* if the env is correct, the above call will return OK, but just
	 * in case it doesn't... */
	if (rc) {
	  path = NULL;
	} else {
	  /* a temporary database is created in its own temporary directory,
	   * and we need to store the full path to files inside that
	   */
	  len = strlen(epath);
	  path = sqlite3_malloc(len + NAME_MAX + 2);
	  if (path)
	    strcpy(path, epath);
	}
    mdb_env_close(env);
	if (path) {
	  /* delete all files inside this directory, then the directory itself;
	   * we don't expect anybody to create directories inside this, so we
	   * don't recurse
	   */
	  DIR * dp = opendir(path);
	  if (dp) {
		struct dirent * ent;
		path[len++] = '/';
		while ((ent = readdir(dp)) != NULL) {
			if (ent->d_name[0] == '.') {
				if (! ent->d_name[1]) continue;
				if (ent->d_name[1] == '.' && ! ent->d_name[2]) continue;
			}
			strncpy(&path[len], ent->d_name, NAME_MAX);
			path[len + NAME_MAX] = 0;
			unlink(path);
		}
		closedir(dp);
		path[--len] = 0;
	  }
	  rmdir(path);
	  sqlite3_free(path);
	}
  } else {
	mutexOpen = sqlite3MutexAlloc(SQLITE_MUTEX_STATIC_OPEN);
	sqlite3_mutex_enter(mutexOpen);
	if (--pBt->nRef == 0) {
	  BtShared **prev;
	  if (pBt->xFreeSchema && pBt->pSchema)
		pBt->xFreeSchema(pBt->pSchema);
	  sqlite3DbFree(0, pBt->pSchema);
	  mdb_env_close(pBt->env);
	  prev = &sqlite3SharedCacheList;
	  while (*prev != pBt) prev = &(*prev)->pNext;
	  *prev = pBt->pNext;
	  sqlite3_free(pBt);
	} else {
      Btree **prev;
	  prev = &pBt->trees;
	  while (*prev != p) prev = &(*prev)->pNext;
	  *prev = p->pNext;
	}
	sqlite3_mutex_leave(mutexOpen);
  }
  sqlite3_free(p);
  LOG("done",0);
  return SQLITE_OK;
}

/*
** Close a cursor.
*/
int sqlite3BtreeCloseCursor(BtCursor *pCur){
  Btree *pBtree = pCur->pBtree;
  if (pBtree) {
    BtCursor **prev = &pBtree->pCursor;
	while (*prev != pCur) prev = &((*prev)->pNext);
	*prev = pCur->pNext;
  }
  sqlite3_free(pCur->index.mv_data);
  sqlite3BtreeClearCursor(pCur);
  LOG("done",0);
  return SQLITE_OK;
}

/*
** Do both phases of a commit.
*/
int sqlite3BtreeCommit(Btree *p){
  int rc;

  rc = sqlite3BtreeCommitPhaseOne(p, NULL);
  if (rc == 0)
    rc = sqlite3BtreeCommitPhaseTwo(p, 0);
  LOG("rc=%d",rc);
  return rc;
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
** Otherwise, sync the database file for the btree pBt. zMaster points to
** the name of a master journal file that should be written into the
** individual journal file, or is NULL, indicating no master journal file 
** (single database transaction).
**
** When this is called, the master journal should already have been
** created, populated with this journal pointer and synced to disk.
**
** Once this is routine has returned, the only thing required to commit
** the write-transaction for this database file is to delete the journal.
*/
int sqlite3BtreeCommitPhaseOne(Btree *p, const char *zMaster){
  BtCursor *pc, *pn;
  int rc = 0;
  if (p->main_txn) {
    rc = mdb_txn_commit(p->main_txn);
    p->main_txn = NULL;
    p->curr_txn = NULL;
	p->inTrans = TRANS_NONE;
  }
  for (pn = p->pCursor, pc=pn; pc; pc=pn) {
    pn = pc->pNext;
    sqlite3BtreeCloseCursor(pc);
	sqlite3BtreeCursorZero(pc);
  }

  LOG("rc=%d",rc);
  return errmap(rc);
}

/*
** Commit the transaction currently in progress.
**
** This routine implements the second phase of a 2-phase commit.  The
** sqlite3BtreeCommitPhaseOne() routine does the first phase and should
** be invoked prior to calling this routine.  The sqlite3BtreeCommitPhaseOne()
** routine did all the work of writing information out to disk and flushing the
** contents so that they are written onto the disk platter.  All this
** routine has to do is delete or truncate or zero the header in the
** the rollback journal (which causes the transaction to commit) and
** drop locks.
**
** Normally, if an error occurs while the pager layer is attempting to 
** finalize the underlying journal file, this function returns an error and
** the upper layer will attempt a rollback. However, if the second argument
** is non-zero then this b-tree transaction is part of a multi-file 
** transaction. In this case, the transaction has already been committed 
** (by deleting a master journal file) and the caller will ignore this 
** functions return code. So, even if an error occurs in the pager layer,
** reset the b-tree objects internal state to indicate that the write
** transaction has been closed. This is quite safe, as the pager will have
** transitioned to the error state.
**
** This will release the write lock on the database file.  If there
** are no active cursors, it also releases the read lock.
*/
int sqlite3BtreeCommitPhaseTwo(Btree *p, int bCleanup){
  LOG("done",0);
  return SQLITE_OK;
}

#ifndef SQLITE_OMIT_BTREECOUNT
/*
** The first argument, pCur, is a cursor opened on some b-tree. Count the
** number of entries in the b-tree and write the result to *pnEntry.
**
** SQLITE_OK is returned if the operation is successfully executed. 
** Otherwise, if an error is encountered (i.e. an IO error or database
** corruption) an SQLite error code is returned.
*/
int sqlite3BtreeCount(BtCursor *pCur, i64 *pnEntry){
  *pnEntry = cursor_entries(pCur->mc);
  LOG("done",0);
  return SQLITE_OK;
}
#endif

/*
** Create a new BTree table.  Write into *piTable the page
** number for the root page of the new table.
**
** The type of table is determined by the flags parameter.  Only the
** following values of flags are currently in use.  Other values for
** flags might not work:
**
**     BTREE_INTKEY|BTREE_LEAFDATA     Used for SQL tables with rowid keys
**     BTREE_ZERODATA                  Used for SQL indices
*/
int sqlite3BtreeCreateTable(Btree *p, int *piTable, int flags){
  BtShared *pBt;
  MDB_dbi dbi;
  MDB_val key;
  char name[13];
  unsigned int mflags;
  int rc;
  u32 last;

  pBt = p->pBt;

  sqlite3BtreeGetMeta(p, BTREE_LARGEST_ROOT_PAGE, &last);
  last++;
  sprintf(name, "Tab.%08x", last);

  /* create first DB implicitly */
  if (last == 1) {
    rc = mdb_open(p->main_txn, name, MDB_CREATE|MDB_INTEGERKEY, &dbi);
	if (rc)
		goto done;
	last++;
    sprintf(name, "Tab.%08x", last);
  }
  mflags = MDB_CREATE;

  if (flags & BTREE_INTKEY) {
    mflags = MDB_INTEGERKEY;
  } else {
    mflags = MDB_DUPSORT;
  }
  if (p->inTrans == TRANS_WRITE)
    mflags |= MDB_CREATE;
  rc = mdb_open(p->main_txn, name, mflags, &dbi);
  if (!rc) {
    *piTable = last;
	if (mflags & MDB_DUPSORT) {
	  mdb_set_compare(p->main_txn, dbi, BtreeCompare);
	}
	sqlite3BtreeUpdateMeta(p, BTREE_LARGEST_ROOT_PAGE, last);
  }
done:
  LOG("rc=%d",rc);
  return errmap(rc);
}

/*
** Create a new cursor for the BTree whose root is on the page
** iTable. If a read-only cursor is requested, it is assumed that
** the caller already has at least a read-only transaction open
** on the database already. If a write-cursor is requested, then
** the caller is assumed to have an open write transaction.
**
** If wrFlag==0, then the cursor can only be used for reading.
** If wrFlag==1, then the cursor can be used for reading or for
** writing if other conditions for writing are also met.  These
** are the conditions that must be met in order for writing to
** be allowed:
**
** 1:  The cursor must have been opened with wrFlag==1
**
** 2:  The database must be writable (not on read-only media)
**
** 3:  There must be an active transaction.
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
  int iTable,                                 /* Root page of table to open */
  int wrFlag,                                 /* 1 to write. 0 read-only */
  struct KeyInfo *pKeyInfo,                   /* First arg to xCompare() */
  BtCursor *pCur                              /* Write new cursor here */
){
  MDB_dbi dbi;
  int rc;

  rc = BtreeTableHandle(p, iTable, &dbi);
  if (rc == 0) {
    rc = mdb_cursor_open(p->curr_txn, dbi, &pCur->mc);
    if (rc == 0) {
      pCur->pNext = p->pCursor;
      p->pCursor = pCur;
      pCur->pBtree = p;
      pCur->pKeyInfo = pKeyInfo;
    }
  }
  LOG("rc=%d, iTable=%d",rc, iTable);
  return rc;
}

/*
** Determine whether or not a cursor has moved from the position it
** was last placed at.  Cursors can move when the row they are pointing
** at is deleted out from under them.
**
** This routine returns an error code if something goes wrong.  The
** integer *pHasMoved is set to one if the cursor has moved and 0 if not.
*/
#if SQLITE_VERSION_NUMBER < 3009000
int sqlite3BtreeCursorHasMoved(BtCursor *pCur, int *pHasMoved){
  MDB_cursor *mc = pCur->mc;
  if (! cursor_initialised(pCur)) {
    *pHasMoved = 1;
  }else{
    *pHasMoved = 0;
  }
  LOG("rc=0, *pHasMoved=%d",*pHasMoved);
  return SQLITE_OK;
}
#else
int sqlite3BtreeCursorHasMoved(BtCursor *pCur){
  return ! cursor_initialised(pCur);
}
#endif

/*
** Return the size of a BtCursor object in bytes.
**
** This interfaces is needed so that users of cursors can preallocate
** sufficient storage to hold a cursor.  The BtCursor object is opaque
** to users so they cannot do the sizeof() themselves - they must call
** this routine.
*/
int sqlite3BtreeCursorSize(void){
  LOG("done",0);
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
  p->pKeyInfo = NULL;
  p->pBtree = NULL;
  p->cachedRowid = 0;
  p->index.mv_data = NULL;
  p->index.mv_size = 0;
  p->mc = NULL;
  p->mc_init = 0;
  LOG("done",0);
}

/*
** Read part of the data associated with cursor pCur.  Exactly
** "amt" bytes will be transfered into pBuf[].  The transfer
** begins at "offset".
**
** Return SQLITE_OK on success or an error code if anything goes
** wrong.  An error is returned if "offset+amt" is larger than
** the available payload.
*/
int sqlite3BtreeData(BtCursor *pCur, u32 offset, u32 amt, void *pBuf){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_GET_CURRENT);
  if (rc != 0) {
    rc = SQLITE_ERROR;
  } else if (offset+amt <= data.mv_size) {
    memcpy(pBuf, (char *)data.mv_data+offset, amt);
	rc = SQLITE_OK;
  } else {
	rc = SQLITE_CORRUPT_BKPT;
  }
  LOG("rc=%d",rc);
  return rc;
}

static int joinIndexKey(MDB_val *key, MDB_val *data, BtCursor *pCur, u_int32_t amt);

/*
** For the entry that cursor pCur is point to, return as
** many bytes of the key or data as are available on the local
** b-tree page.  Write the number of available bytes into *pAmt.
**
** These routines are used to get quick access to key and data
** in the common case where no overflow pages are used.
*/
#if SQLITE_VERSION_NUMBER < 3008002
const void *sqlite3BtreeKeyFetch(BtCursor *pCur, int *pAmt){
#else
const void *sqlite3BtreeKeyFetch(BtCursor *pCur, u32 *pAmt){
#endif
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_GET_CURRENT);
  LOG("done",0);
  if (rc)
    return NULL;
  else {
	*pAmt = key.mv_size;
	if (cursor_flags(mc) & MDB_INTEGERKEY)
	  return key.mv_data;
	else {
	  *pAmt += data.mv_size;
	  joinIndexKey(&key, &data, pCur, *pAmt);
	  return pCur->index.mv_data;
	}
  }
}
#if SQLITE_VERSION_NUMBER < 3008002
const void *sqlite3BtreeDataFetch(BtCursor *pCur, int *pAmt){
#else
const void *sqlite3BtreeDataFetch(BtCursor *pCur, u32 *pAmt){
#endif
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_GET_CURRENT);
  LOG("done",0);
  /* index tables are supposed to be all key, no data */
  if (rc || !(cursor_flags(mc) & MDB_INTEGERKEY)) {
    *pAmt = 0;
    return NULL;
  }
  *pAmt = data.mv_size;
  return data.mv_data;
}

/*
** Set *pSize to the number of bytes of data in the entry the
** cursor currently points to.
**
** The caller must guarantee that the cursor is pointing to a non-NULL
** valid entry.  In other words, the calling procedure must guarantee
** that the cursor has Cursor.eState==CURSOR_VALID.
**
** Failure is not possible.  This function always returns SQLITE_OK.
** It might just as well be a procedure (returning void) but we continue
** to return an integer result code for historical reasons.
*/
int sqlite3BtreeDataSize(BtCursor *pCur, u32 *pSize){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_GET_CURRENT);
  if (rc == 0)
    *pSize = data.mv_size;
  LOG("done",0);
  return SQLITE_OK;
}

/*
** Delete the entry that the cursor is pointing to.  The cursor
** is left pointing at a arbitrary location.
*/
#if SQLITE_VERSION_NUMBER < 3009000
int sqlite3BtreeDelete(BtCursor *pCur){
#else
/** mdb_cursor_del always act as if bPreserve is true, so we
 * ignore this argument
 */
int sqlite3BtreeDelete(BtCursor *pCur, int bPreserve){
#endif
  int rc;
  MDB_cursor *mc = pCur->mc;
  rc = mdb_cursor_del(mc, 0);
  if (rc == 0) pCur->mc_init = 0;
  LOG("rc=%d",rc);
  return errmap(rc);
}

/*
** Erase all information in a table and add the root of the table to
** the freelist.  Except, the root of the principle table (the one on
** page 1) is never added to the freelist.
**
** This routine will fail with SQLITE_LOCKED if there are any open
** cursors on the table.
*/
int sqlite3BtreeDropTable(Btree *p, int iTable, int *piMoved){
  int rc;
  MDB_dbi dbi;
  *piMoved = 0;
  rc = BtreeTableHandle(p, iTable, &dbi);
  if (rc == 0)
    rc = mdb_drop(p->curr_txn, dbi, 1);

  LOG("rc=%d",rc);
  return errmap(rc);
}

/*
** Return TRUE if the cursor is not pointing at an entry of the table.
**
** TRUE will be returned after a call to sqlite3BtreeNext() moves
** past the last entry in the table or sqlite3BtreePrev() moves past
** the first entry.  TRUE is also returned if the table is empty.
*/
int sqlite3BtreeEof(BtCursor *pCur){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int ret = mdb_cursor_get(mc, &key, &data, MDB_CURRENT) == 0;
  LOG("ret=%d",ret);
  return ret;
}

/* Move the cursor to the first entry in the table.  Return SQLITE_OK
** on success.  Set *pRes to 0 if the cursor actually points to something
** or set *pRes to 1 if the table is empty.
*/
int sqlite3BtreeFirst(BtCursor *pCur, int *pRes){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_FIRST);
  if (rc == MDB_NOTFOUND) {
    *pRes = 1;
    rc = SQLITE_OK;
	pCur->mc_init = 1;
  } else if (rc) {
    rc = errmap(rc);
  } else {
    *pRes = 0;
	pCur->mc_init = 1;
    rc = SQLITE_OK;
  }
  LOG("rc=%d, *pRes=%d", rc,*pRes);
  return rc;
}

/*
** Return the value of the 'auto-vacuum' property. If auto-vacuum is 
** enabled 1 is returned. Otherwise 0.
*/
int sqlite3BtreeGetAutoVacuum(Btree *p){
  LOG("done",0);
  return 0;
}

/*
** Return the cached rowid for the given cursor.  A negative or zero
** return value indicates that the rowid cache is invalid and should be
** ignored.  If the rowid cache has never before been set, then a
** zero is returned.
*/
sqlite3_int64 sqlite3BtreeGetCachedRowid(BtCursor *pCur){
  LOG("done",0);
  return pCur->cachedRowid;
}

/*
** Return the full pathname of the underlying database file.
**
** The pager filename is invariant as long as the pager is
** open so it is safe to access without the BtShared mutex.
*/
const char *sqlite3BtreeGetFilename(Btree *p){
  const char *epath;
  int rc = mdb_env_get_path(p->pBt->env, &epath);
  if (rc) epath = NULL;
  LOG("done rc=%d",rc);
  return epath;
}

/*
** Return the pathname of the journal file for this database. The return
** value of this routine is the same regardless of whether the journal file
** has been created or not.
*/
const char *sqlite3BtreeGetJournalname(Btree *p){
  /* sqlite3 will delete this file if there is an error during commit;
   * this may be correct for the original btree.c but we need something
   * different here (actually we'll need a new commit function which can
   * cope properly with multiple backends i.e. a transaction involving
   * tables handled by different backends).
   * For now we return NULL and the commit will ignore the journal file -
   * XXX vdbeaux will need a new commit function which can abort the
   * XXX commit without accessing journal files directly and is aware
   * XXX of the possibility of multiple, independent backends being
   * XXX involved in the same transaction
   */
  LOG("done",0);
  return NULL;
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
*/
void sqlite3BtreeGetMeta(Btree *p, int idx, u32 *pMeta){
  MDB_val key, data;
  MDB_dbi dbi;
  u32 idx32 = idx;
  int rc;

  assert(idx >= 0 && idx < NUMMETA);

  if (!idx) {
    *pMeta = 0;
	goto done;
  }
  rc = mdb_open(p->curr_txn, NULL, 0, &dbi);
  key.mv_data = &idx32;
  key.mv_size = sizeof(idx32);
  rc = mdb_get(p->curr_txn, dbi, &key, &data);
  if (rc == 0)
    memcpy(pMeta, data.mv_data, sizeof(*pMeta));
  else
    *pMeta = 0;
done:
  LOG("idx=%d, *pMeta=%u",idx,*pMeta);
}

/*
** Return the currently defined page size
*/
int sqlite3BtreeGetPageSize(Btree *p){
  MDB_stat envstat;
  mdb_env_stat(p->pBt->env, &envstat);
  LOG("done",0);
  return envstat.ms_psize;
}

#if !defined(SQLITE_OMIT_PAGER_PRAGMAS) || !defined(SQLITE_OMIT_VACUUM)
/*
** Return the number of bytes of space at the end of every page that
** are intentually left unused.  This is the "reserved" space that is
** sometimes used by extensions.
*/
int sqlite3BtreeGetReserve(Btree *p){
  LOG("done",0);
  return 0;
}

/*
** Set the maximum page count for a database if mxPage is positive.
** No changes are made if mxPage is 0 or negative.
** Regardless of the value of mxPage, return the maximum page count.
*/
int sqlite3BtreeMaxPageCount(Btree *p, int mxPage){
  MDB_stat envstat;
  MDB_envinfo envinfo;
  LOG("done",0);
  mdb_env_stat(p->pBt->env, &envstat);
  if (mxPage > 0)
    mdb_env_set_mapsize(p->pBt->env, mxPage * envstat.ms_psize);
  mdb_env_info(p->pBt->env, &envinfo);
  return envinfo.me_mapsize / envstat.ms_psize;
}

/*
** Set the secureDelete flag if newFlag is 0 or 1.  If newFlag is -1,
** then make no changes.  Always return the value of the secureDelete
** setting after the change.
*/
int sqlite3BtreeSecureDelete(Btree *p, int newFlag){
  LOG("done",0);
  return 0;
}
#endif /* !defined(SQLITE_OMIT_PAGER_PRAGMAS) || !defined(SQLITE_OMIT_VACUUM) */

/*
** Change the 'auto-vacuum' property of the database. If the 'autoVacuum'
** parameter is non-zero, then auto-vacuum mode is enabled. If zero, it
** is disabled. The default value for the auto-vacuum property is 
** determined by the SQLITE_DEFAULT_AUTOVACUUM macro.
*/
int sqlite3BtreeSetAutoVacuum(Btree *p, int autoVacuum){
  LOG("done",0);
  return SQLITE_READONLY;
}

#ifndef SQLITE_OMIT_AUTOVACUUM
/*
** A write-transaction must be opened before calling this function.
** It performs a single unit of work towards an incremental vacuum.
**
** If the incremental vacuum is finished after this function has run,
** SQLITE_DONE is returned. If it is not finished, but no error occurred,
** SQLITE_OK is returned. Otherwise an SQLite error code. 
*/
int sqlite3BtreeIncrVacuum(Btree *p){
  LOG("done",0);
  return SQLITE_DONE;
}
#endif

/* Store the rowid in the index as data
 * instead of as part of the key, so rows
 * that have the same indexed value have only one
 * key in the index.
 * The original index key looks like:
 * hdrSize_column1Size_columnNSize_rowIdSize_column1Data_columnNData_rowid
 * The new index key looks like:
 * hdrSize_column1Size_columnNSize_column1Data_columnNData
 * With a data section that looks like:
 * rowIdSize_rowid
 */
static void splitIndexKey(MDB_val *key, MDB_val *data)
{
	u32 hdrSize, rowidType;
	unsigned char *aKey = (unsigned char *)key->mv_data;
	getVarint32(aKey, hdrSize);
	getVarint32(&aKey[hdrSize-1], rowidType);
	data->mv_size = sqlite3VdbeSerialTypeLen(rowidType) + 1;
	key->mv_size -= data->mv_size;
	memmove(&aKey[hdrSize-1], &aKey[hdrSize], key->mv_size-(hdrSize-1));
	putVarint32(&aKey[key->mv_size], rowidType);
	putVarint32(aKey, hdrSize-1);
	data->mv_data = &aKey[key->mv_size];
}

static int joinIndexKey(MDB_val *key, MDB_val *data, BtCursor *pCur, u_int32_t amount)
{
	u32 hdrSize;
	unsigned char *aKey = (unsigned char *)key->mv_data;
	unsigned char *aData = (unsigned char *)data->mv_data;
	unsigned char *newKey;

	if (pCur->index.mv_size < amount) {
	  sqlite3_free(pCur->index.mv_data);
	  pCur->index.mv_data = sqlite3_malloc(amount*2);
	  if (!pCur->index.mv_data)
	    return SQLITE_NOMEM;
	  pCur->index.mv_size = amount*2;
	}
	newKey = (unsigned char *)pCur->index.mv_data;
	getVarint32(aKey, hdrSize);
	memcpy(newKey, aKey, hdrSize);
	memcpy(&newKey[hdrSize+1], &aKey[hdrSize], key->mv_size - hdrSize);
	memcpy(&newKey[key->mv_size+1], &aData[1], data->mv_size - 1);
	newKey[hdrSize] = aData[0];
	putVarint32(newKey, hdrSize+1);
	return SQLITE_OK;
}

/* sqlightnint used mdb_hash_val() which is internal to LMDB; as a temporary
 * measure, we copy and rename the function here, noting that it had the
 * following copyright notice:
 *
 * hash_64 - 64 bit Fowler/Noll/Vo-0 FNV-1a hash code
 *
 * @(#) $Revision: 5.1 $
 * @(#) $Id: hash_64a.c,v 5.1 2009/06/30 09:01:38 chongo Exp $
 * @(#) $Source: /usr/local/src/cmd/fnv/RCS/hash_64a.c,v $
 *
 *	  http://www.isthe.com/chongo/tech/comp/fnv/index.html
 *
 ***
 *
 * Please do not copyright this code.  This code is in the public domain.
 *
 * LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
 * USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
 * OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 *
 * By:
 *	chongo <Landon Curt Noll> /\oo/\
 *	  http://www.isthe.com/chongo/
 *
 * Share and Enjoy!	:-)
 *
 * XXX we need a more general solution to use with any backend which
 * XXX has a limit on key lengths
 */
typedef unsigned long long      lumo_hash_t;
#define LUMO_HASH_INIT ((lumo_hash_t)0xcbf29ce484222325ULL)

static lumo_hash_t
lumo_hash_val(MDB_val *val, lumo_hash_t hval)
{
	unsigned char *s = (unsigned char *)val->mv_data;	/* unsigned string */
	unsigned char *end = s + val->mv_size;
	/*
	 * FNV-1a hash each octet of the string
	 */
	while (s < end) {
		/* xor the bottom with the current octet */
		hval ^= (lumo_hash_t)*s++;

		/* multiply by the 64 bit FNV magic prime mod 2^64 */
		hval += (hval << 1) + (hval << 4) + (hval << 5) +
			(hval << 7) + (hval << 8) + (hval << 40);
	}
	/* return our new hash value */
	return hval;
}

// XXX we'll need a more generic solution for backends which have a key length limit
static void squashIndexKey(UnpackedRecord *pun, int file_format, MDB_val *key)
{
	int i, changed = 0;
	u32 serial_type;
	Mem *pMem;
	MDB_val v;
	lumo_hash_t h;

	/* Look for any large strings or blobs */
	pMem = pun->aMem;
	for (i=0; i<pun->nField; i++) {
#if SQLITE_VERSION_NUMBER < 3010000
		serial_type = sqlite3VdbeSerialType(pMem, file_format);
#else
		u32 len;
		serial_type = sqlite3VdbeSerialType(pMem, file_format, &len);
#endif
		if (serial_type >= 12 && pMem->n >72) {
			v.mv_data = (char *)pMem->z + 64;
			v.mv_size = pMem->n - 64;
			h = lumo_hash_val(&v, LUMO_HASH_INIT);
			pMem->n = 72;
			memcpy(v.mv_data, &h, sizeof(h));
			changed = 1;
		}
		pMem++;
	}

	/* If we changed anything and the key was provided, rewrite the key */
	if (changed && key) {
		u8 *zNewRecord;
		int nHdr = 0;
		int nData = 0;
		int nByte;
		int nVarint;
		int len;

		/* Loop thru and find out how much space is needed */
		pMem = pun->aMem;
		for (i=0; i<pun->nField; i++) {
#if SQLITE_VERSION_NUMBER < 3010000
			serial_type = sqlite3VdbeSerialType(pMem, file_format);
#else
			u32 pLen;
			serial_type = sqlite3VdbeSerialType(pMem, file_format, &pLen);
#endif
			len = sqlite3VdbeSerialTypeLen(serial_type);
			nData += len;
			nHdr += sqlite3VarintLen(serial_type);
			pMem++;
		}
		nHdr += nVarint = sqlite3VarintLen(nHdr);
		if (nVarint < sqlite3VarintLen(nHdr))
			nHdr++;
		nByte = nHdr+nData;
		zNewRecord = key->mv_data;
		len = putVarint32(zNewRecord, nHdr);
		pMem = pun->aMem;
		for (i=0; i<pun->nField; i++) {
#if SQLITE_VERSION_NUMBER < 3010000
			serial_type = sqlite3VdbeSerialType(pMem, file_format);
#else
			u32 pLen;
			serial_type = sqlite3VdbeSerialType(pMem, file_format, &pLen);
#endif
			len += putVarint32(&zNewRecord[len], serial_type);
			pMem++;
		}
		pMem = pun->aMem;
		for (i=0; i<pun->nField; i++) {
#if SQLITE_VERSION_NUMBER < 3008003
			len += sqlite3VdbeSerialPut(&zNewRecord[len], (int)(nByte-len), pMem, file_format);
#else
#if SQLITE_VERSION_NUMBER < 3010000
			serial_type = sqlite3VdbeSerialType(pMem, file_format);
#else
			u32 pLen;
			serial_type = sqlite3VdbeSerialType(pMem, file_format, &pLen);
#endif
			len += sqlite3VdbeSerialPut(&zNewRecord[len], pMem, serial_type);
#endif
			pMem++;
		}
		key->mv_size = len;
	}
}

/*
** Insert a new record into the BTree.  The key is given by (pKey,nKey)
** and the data is given by (pData,nData).  The cursor is used only to
** define what table the record should be inserted into.  The cursor
** is left pointing at a random location.
**
** For an INTKEY table, only the nKey value of the key is used.  pKey is
** ignored.  For a ZERODATA table, the pData and nData are both ignored.
**
** If the seekResult parameter is non-zero, then a successful call to
** MovetoUnpacked() to seek cursor pCur to (pKey, nKey) has already
** been performed. seekResult is the search result returned (a negative
** number if pCur points at an entry that is smaller than (pKey, nKey), or
** a positive value if pCur points at an entry that is larger than
** (pKey, nKey)). 
**
** If the seekResult parameter is non-zero, then the caller guarantees that
** cursor pCur is pointing at the existing copy of a row that is to be
** overwritten.  If the seekResult parameter is 0, then cursor pCur may
** point to any entry or to no entry at all and so this function has to seek
** the cursor before the new key can be inserted.
*/
int sqlite3BtreeInsert(
  BtCursor *pCur,                /* Insert data into the table of this cursor */
  const void *pKey, i64 nKey,    /* The key of the new record */
  const void *pData, int nData,  /* The data of the new record */
  int nZero,                     /* Number of extra 0 bytes to append to data */
  int appendBias,                /* True if this is likely an append */
  int seekResult                 /* Result of prior MovetoUnpacked() call */
){
  MDB_cursor *mc = pCur->mc;
  UnpackedRecord *p;
  MDB_val key[2], data;
#if SQLITE_VERSION_NUMBER < 3018000
  char aSpace[150];
#endif
  char *pFree = 0;
  int rc, res, flag = 0;

  if ((cursor_flags(mc) & MDB_INTEGERKEY) || !pKey) {
    key[0].mv_data = &nKey;
    key[0].mv_size = sizeof(i64);
    data.mv_size = nData + nZero;
    if (nZero)
      flag |= MDB_RESERVE;
    else
      data.mv_data = (void *)pData;
  } else {
#if SQLITE_VERSION_NUMBER < 3018000
    p = sqlite3VdbeAllocUnpackedRecord(
      pCur->pKeyInfo, aSpace, sizeof(aSpace), &pFree);
#else
    p = sqlite3VdbeAllocUnpackedRecord(pCur);
    pFree = p;
#endif
    if (!p)
      return SQLITE_NOMEM;
    key[0].mv_size = nKey;
    key[0].mv_data = (void *)pKey;
    splitIndexKey(key, &data);
    sqlite3VdbeRecordUnpack(pCur->pKeyInfo, (int)nKey, pKey, p);
    key[1].mv_data = p;
    /* flag = MDB_NODUPDATA; */
    squashIndexKey(p, pCur->pBtree->db->pVdbe->minWriteFileFormat, key);
  }
  rc = mdb_cursor_put(mc, key, &data, flag);
  pCur->mc_init = 1;
  if (pFree)
    sqlite3DbFree(pCur->pKeyInfo->db, pFree);
  else if (rc == 0 && (flag & MDB_RESERVE) != 0) {
    memcpy(data.mv_data, pData, nData);
    memset((char *)data.mv_data+nData, 0, nZero);
  }
  LOG("rc=%d",rc);
  return errmap(rc);
}

#ifndef SQLITE_OMIT_INTEGRITY_CHECK
/*
** This routine does a complete check of the given BTree file.  aRoot[] is
** an array of pages numbers were each page number is the root page of
** a table.  nRoot is the number of entries in aRoot.
**
** A read-only or read-write transaction must be opened before calling
** this function.
**
** Write the number of error seen in *pnErr.  Except for some memory
** allocation errors,  an error message held in memory obtained from
** malloc is returned if *pnErr is non-zero.  If *pnErr==0 then NULL is
** returned.  If a memory allocation error occurs, NULL is returned.
*/
char *sqlite3BtreeIntegrityCheck(
  Btree *p,     /* The btree to be checked */
  int *aRoot,   /* An array of root pages numbers for individual trees */
  int nRoot,    /* Number of entries in aRoot[] */
  int mxErr,    /* Stop reporting errors after this many */
  int *pnErr    /* Write number of errors seen to this variable */
){
  LOG("done",0);
  *pnErr = 0;
  return NULL;
}
#endif

/*
** Return non-zero if a transaction is active.
*/
int sqlite3BtreeIsInTrans(Btree *p){
  int rc = (p && (p->inTrans==TRANS_WRITE));
  LOG("rc=%d",rc);
  return rc;
}

/*
** Return non-zero if a read (or write) transaction is active.
*/
int sqlite3BtreeIsInReadTrans(Btree *p){
  int rc = (p && p->inTrans!=TRANS_NONE);
  LOG("rc=%d",rc);
  return rc;
}

int sqlite3BtreeIsInBackup(Btree *p){
  LOG("rc=0",0);
  return 0;
}

/*
** Read part of the key associated with cursor pCur.  Exactly
** "amt" bytes will be transfered into pBuf[].  The transfer
** begins at "offset".
**
** The caller must ensure that pCur is pointing to a valid row
** in the table.
**
** Return SQLITE_OK on success or an error code if anything goes
** wrong.  An error is returned if "offset+amt" is larger than
** the available payload.
*/
int sqlite3BtreeKey(BtCursor *pCur, u32 offset, u32 amt, void *pBuf){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_GET_CURRENT);
  if (rc != 0) {
    rc = SQLITE_ERROR;
  } else if (offset+amt <= key.mv_size) {
    memcpy(pBuf, (char *)key.mv_data+offset, amt);
    rc = SQLITE_OK;
  } else {
    rc = SQLITE_CORRUPT_BKPT;
  }
  LOG("rc=%d",rc);
  return rc;
}

/*
** Set *pSize to the size of the buffer needed to hold the value of
** the key for the current entry.  If the cursor is not pointing
** to a valid entry, *pSize is set to 0. 
**
** For a table with the INTKEY flag set, this routine returns the key
** itself, not the number of bytes in the key.
**
** The caller must position the cursor prior to invoking this routine.
** 
** This routine cannot fail.  It always returns SQLITE_OK.  
*/
int sqlite3BtreeKeySize(BtCursor *pCur, i64 *pSize){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_GET_CURRENT);
  if (rc != 0) {
    *pSize = 0;
  } else {
	if (cursor_flags(mc) & MDB_INTEGERKEY) {
	  memcpy(pSize, key.mv_data, sizeof(i64));
	} else {
	  // XXX sqlightning used NODEKSZ + NODEDSZ so we translate that to
	  // XXX key.mv_size + data.mv_size -- is that correct? Or just key.mv_size?
	  *pSize = key.mv_size + data.mv_size;
	}
  }
  LOG("done",0);
  return SQLITE_OK;
}

/* Move the cursor to the last entry in the table.  Return SQLITE_OK
** on success.  Set *pRes to 0 if the cursor actually points to something
** or set *pRes to 1 if the table is empty.
*/
int sqlite3BtreeLast(BtCursor *pCur, int *pRes){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  int rc = mdb_cursor_get(mc, &key, &data, MDB_LAST);
  if (rc == MDB_NOTFOUND) {
    *pRes = 1;
    rc = SQLITE_OK;
	pCur->mc_init = 1;
  } else if (rc) {
    rc = errmap(rc);
  } else {
    *pRes = 0;
    rc = SQLITE_OK;
	pCur->mc_init = 1;
  }
  LOG("rc=%d, *pRes=%d", rc,*pRes);
  return rc;
}

/*
** Return the size of the database file in pages. If there is any kind of
** error, return ((unsigned int)-1).
*/
u32 sqlite3BtreeLastPage(Btree *p){
  MDB_envinfo envinfo;
  int rc = mdb_env_info(p->pBt->env, &envinfo);
  LOG("done",rc);
  return rc ? errmap(rc) : envinfo.me_last_pgno;
}

#ifndef SQLITE_OMIT_SHARED_CACHE
/*
** Obtain a lock on the table whose root page is iTab.  The
** lock is a write lock if isWritelock is true or a read lock
** if it is false.
*/
int sqlite3BtreeLockTable(Btree *p, int iTab, u8 isWriteLock){
  LOG("rc=0",0);
  return SQLITE_OK;
}
#endif

/* Move the cursor so that it points to an entry near the key 
** specified by pIdxKey or intKey.   Return a success code.
**
** For INTKEY tables, the intKey parameter is used.  pUnKey
** must be NULL.  For index tables, pUnKey is used and intKey
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
**     *pRes==0     The cursor is left pointing at an entry that
**                  exactly matches intKey/pUnKey.
**
**     *pRes>0      The cursor is left pointing at an entry that
**                  is larger than intKey/pUnKey.
**
*/
// XXX This function accesses LMDB's internals and will need to be rewritten
int sqlite3BtreeMovetoUnpacked(
  BtCursor *pCur,          /* The cursor to be moved */
  UnpackedRecord *pUnKey,  /* Unpacked index key */
  i64 intKey,              /* The table key */
  int biasRight,           /* If true, bias the search to the high end */
  int *pRes                /* Write search results here */
){
  MDB_cursor *mc = pCur->mc;
  MDB_val key[2], data;
  int rc, res, ret;
  unsigned int flags = cursor_flags(mc);
  unsigned char buf[ROWIDMAXSIZE];

  res = -1;
  ret = MDB_NOTFOUND;

  if (!cursor_entries(mc)) {
	pCur->mc_init = 0;
	ret = 0;
	goto done;
  }

  if ((flags & MDB_INTEGERKEY) || !pUnKey) {
    key[0].mv_data = &intKey;
	key[0].mv_size = sizeof(i64);
	ret = mdb_cursor_get(mc, key, NULL, MDB_SET);
  } else {
	int file_format =
			pCur->pBtree->db->pVdbe->minWriteFileFormat;
    key[0].mv_size = 1;
	key[0].mv_data = NULL;
	key[1].mv_size = 0;
	key[1].mv_data = pUnKey;
	squashIndexKey(pUnKey, file_format, NULL);
    /* Put the rowID into the data, not the key */
	if (pUnKey->nField > pCur->pKeyInfo->nField) {
	  u8 serial_type;
	  Mem *rowid = &pUnKey->aMem[pUnKey->nField - 1];
#if SQLITE_VERSION_NUMBER < 3010000
	  serial_type = sqlite3VdbeSerialType(rowid, file_format);
#else
	  u32 pLen;
	  serial_type = sqlite3VdbeSerialType(rowid, file_format, &pLen);
#endif
	  data.mv_size =
			sqlite3VdbeSerialTypeLen(serial_type) + 1;
	  assert(data.mv_size < ROWIDMAXSIZE);
	  data.mv_data = &buf;
	  putVarint32(buf, serial_type);
#if SQLITE_VERSION_NUMBER < 3008003
	  sqlite3VdbeSerialPut(&buf[1], ROWIDMAXSIZE - 1,
			rowid, file_format);
#else
	  sqlite3VdbeSerialPut(&buf[1], rowid, serial_type);
#endif
	  ret = mdb_cursor_get(mc, key, &data, MDB_GET_BOTH_RANGE);
	}
	if (ret == MDB_NOTFOUND) {
	  ret = mdb_cursor_get(mc, key, NULL, MDB_SET_RANGE);
	}
  }
  if (ret) {
    if (lumo_mdb_cursor_past_end(mc))
	  res = -1;
	else
	  res = 1;
  } else {
    if (flags & MDB_INTEGERKEY) {
      res = 0;
	} else {
	  /* an index lookup, we need to check for exact match */
	  int len;
	  const char *pkey = sqlite3BtreeKeyFetch(pCur, &len);
	  if (pkey)
        res = sqlite3VdbeRecordCompare(len, pkey, pUnKey);
	}
  }
  if (ret == MDB_NOTFOUND)
    ret = 0;
done:
  *pRes = res;
  LOG("rc=%d, *pRes=%d", ret, res);
  return errmap(ret);
}

/*
** Advance the cursor to the next entry in the database.  If
** successful then set *pRes=0.  If the cursor
** was already pointing to the last entry in the database before
** this routine was called, then set *pRes=1.
*/
int sqlite3BtreeNext(BtCursor *pCur, int *pRes){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  /* sqlightning used the cursor's internals to see if the database was
   * completely empty and return pRes = 1 without making any other changes;
   * this presumably saves some time but we omit the test and let the
   * normal call notice this */
  /* if (!mc->mc_db || mc->mc_db->md_root == P_INVALID) */
    /* *pRes = 1; */
  /* else { */
    int rc = mdb_cursor_get(mc, &key, &data, MDB_NEXT);
	*pRes = (rc == MDB_NOTFOUND) ? 1 : 0;
	pCur->mc_init = 1;
  /* } */
  LOG("rc=0, *pRes=%d",*pRes);
  return SQLITE_OK;
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
** The "flags" parameter is a bitmask that might contain bits
** BTREE_OMIT_JOURNAL and/or BTREE_NO_READLOCK.  The BTREE_NO_READLOCK
** bit is also set if the SQLITE_NoReadlock flags is set in db->flags.
** These flags are passed through into sqlite3PagerOpen() and must
** be the same values as PAGER_OMIT_JOURNAL and PAGER_NO_READLOCK.
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
  Btree *p;
  BtShared *pBt;
  sqlite3_mutex *mutexOpen = NULL;
  int eflags, rc = SQLITE_OK;
  char dirPathBuf[BT_MAX_PATH], *dirPathName = dirPathBuf;

  if ((p = (Btree *)sqlite3_malloc(sizeof(Btree))) == NULL) {
    rc = SQLITE_NOMEM;
	goto done;
  }
  p->db = db;
  p->pCursor = NULL;
  p->main_txn = NULL;
  p->curr_txn = NULL;
  p->inTrans = TRANS_NONE;
  p->isTemp = 0;
  p->locked = 0;
  p->wantToLock = 0;
  p->eFlags = 0;
  /* Transient and in-memory are all the same, use /tmp */
  if ((vfsFlags & (SQLITE_OPEN_TRANSIENT_DB|SQLITE_OPEN_TEMP_DB))
	|| !zFilename || !zFilename[0] || !strcmp(zFilename, ":memory:")) {
	if (vfsFlags & SQLITE_OPEN_READONLY) {
	  /* a read-onlyu temporary database is not much use - it'll just
	   * remain empty... */
	  rc = SQLITE_INTERNAL;
	  goto done;
	}
	p->isTemp = 1;
	strcpy(dirPathBuf, "/tmp/mdb.XXXXXX");
	if (! mkdtemp(dirPathBuf)) {
	  rc = errmap(errno);
	  goto done;
	}
  } else {
	sqlite3OsFullPathname(pVfs, zFilename, sizeof(dirPathBuf), dirPathName);
    mutexOpen = sqlite3MutexAlloc(SQLITE_MUTEX_STATIC_OPEN);
	sqlite3_mutex_enter(mutexOpen);
	for (pBt = sqlite3SharedCacheList; pBt; pBt = pBt->pNext) {
		if (pBt->env) {
		  const char *epath;
		  int rc = mdb_env_get_path(pBt->env, &epath);
		  if (!rc && !strcmp(epath, dirPathName)) {
			  p->pBt = pBt;
			  pBt->nRef++;
			  break;
		  }
		}
	}
	if (pBt) {
	  p->pNext = pBt->trees;
	  pBt->trees = p;
	  pBt->nRef++;
	  sqlite3_mutex_leave(mutexOpen);
	  *ppBtree = p;
	  goto done;
	}
  }
	pBt = sqlite3_malloc(sizeof(BtShared));
	if (!pBt) {
	  if (!p->isTemp) {
	    sqlite3_mutex_leave(mutexOpen);
	  }
	  rc = SQLITE_NOMEM;
	  goto done;
	}
	rc = mdb_env_create(&pBt->env);
	if (rc) {
	  if (!p->isTemp) {
	    sqlite3_mutex_leave(mutexOpen);
	  }
	  rc = errmap(rc);
	  goto done;
	}
	if (p->isTemp) {
	  mdb_env_set_maxdbs(pBt->env, 64);
	} else {
	  mdb_env_set_maxdbs(pBt->env, 256);
	  mdb_env_set_maxreaders(pBt->env, 254);
	}
	mdb_env_set_mapsize(pBt->env, 256*1048576);
	eflags = 0;
	if (p->isTemp) {
	  eflags |= MDB_NOSYNC;
	} else {
	  if (vfsFlags & SQLITE_OPEN_DELETEONCLOSE) {
		/* we only support delete-on-close for temporary DBs.  I don't believe
		 * this flag is set in any other case, but just in case it happens */
		sqlite3_mutex_leave(mutexOpen);
		rc = SQLITE_INTERNAL;
		goto done;
	  }
	  eflags |= MDB_NOSUBDIR;
	}
	if (vfsFlags & SQLITE_OPEN_READONLY)
	  eflags |= MDB_RDONLY;
	rc = mdb_env_open(pBt->env, dirPathName, eflags, SQLITE_DEFAULT_FILE_PERMISSIONS);
	if (rc) {
	  if (!p->isTemp)
	    sqlite3_mutex_leave(mutexOpen);
	  rc = errmap(rc);
	  goto done;
	}
	p->eFlags = eflags;
	pBt->db = db;
	pBt->openFlags = flags;
	pBt->inTransaction = TRANS_NONE;
	pBt->nTransaction = 0;
	pBt->pSchema = NULL;
	pBt->xFreeSchema = NULL;
	pBt->nRef = 1;
	pBt->pWriter = NULL;
	if (p->isTemp) {
	} else {
	  pBt->pNext = sqlite3SharedCacheList;
	  sqlite3SharedCacheList = pBt;
	  sqlite3_mutex_leave(mutexOpen);
	}
	p->pNext = NULL;
	pBt->trees = p;
	p->pBt = pBt;
	*ppBtree = p;

done:
  LOG("rc=%d",rc);
  return rc;;
}

/*
** Return the pager associated with a BTree.  This routine is used for
** testing and debugging only.
*/
Pager *sqlite3BtreePager(Btree *p){
  LOG("done",0);
  return (Pager *)p;
}

/*
** Step the cursor back to the previous entry in the database.  If
** successful then set *pRes=0.  If the cursor
** was already pointing to the first entry in the database before
** this routine was called, then set *pRes=1.
*/
int sqlite3BtreePrevious(BtCursor *pCur, int *pRes){
  MDB_cursor *mc = pCur->mc;
  MDB_val key, data;
  /* sqlightning used the cursor's internals to see if the database was
   * completely empty and return pRes = 1 without making any other changes;
   * this presumably saves some time but we omit the test and let the
   * normal call notice this */
  /* if (mc->mc_db->md_root == P_INVALID) */
    /* *pRes = 1; */
  /* else { */
    int rc = mdb_cursor_get(mc, &key, &data, MDB_PREV);
	*pRes = (rc == MDB_NOTFOUND) ? 1 : 0;
	pCur->mc_init = 1;
  /* } */
  LOG("done",0);
  return SQLITE_OK;
}

/*
** Rollback the transaction in progress.  All cursors will be
** invalidated by this operation.  Any attempt to use a cursor
** that was open at the beginning of this operation will result
** in an error.
*/
#if SQLITE_VERSION_NUMBER < 3009000
int sqlite3BtreeRollback(Btree *p, int tripCode){
#else
int sqlite3BtreeRollback(Btree *p, int tripCode, int writeOnly){
/* TODO - if writeOnly is true, we do not invalidate read-only cursors */
#endif
  LOG("done",0);
  return sqlite3BtreeSavepoint(p, SAVEPOINT_ROLLBACK, -1);
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
int sqlite3BtreeSavepoint(Btree *p, int op, int iSavepoint){
  MDB_txn *parent;
  int rc = SQLITE_OK;

  if (!p->curr_txn)
    goto done;

  parent = lumo_mdb_txn_parent(p->curr_txn);
  if (op == SAVEPOINT_ROLLBACK) {
    if (iSavepoint == -1) {
	  mdb_txn_abort(p->main_txn);
	} else {
      mdb_txn_abort(p->curr_txn);
	}
  } else {
    if (iSavepoint == -1)
	  rc = mdb_txn_commit(p->main_txn);
	else
	  rc = mdb_txn_commit(p->curr_txn);
  }
  if (iSavepoint == -1) {
    p->main_txn = NULL;
	p->curr_txn = NULL;
	p->inTrans = TRANS_NONE;
  } else {
    p->curr_txn = parent;
	if (!parent) {
	  p->main_txn = NULL;
	  p->inTrans = TRANS_NONE;
	}
  }
done:
  LOG("rc=%d",rc);
  return errmap(rc);
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
  if (p->pBt->pSchema == NULL && nBytes > 0) {
    p->pBt->pSchema = sqlite3MallocZero(nBytes);
	p->pBt->xFreeSchema = xFree;
  }
  LOG("done",0);
  return p->pBt->pSchema;
}

/*
** Return SQLITE_LOCKED_SHAREDCACHE if another user of the same shared 
** btree as the argument handle holds an exclusive lock on the 
** sqlite_master table. Otherwise SQLITE_OK.
*/
int sqlite3BtreeSchemaLocked(Btree *p){
  LOG("rc=0",0);
  return SQLITE_OK;
}

/*
** Change the limit on the number of pages allowed in the cache.
**
** The maximum number of cache pages is set to the absolute
** value of mxPage.  If mxPage is negative, the pager will
** operate asynchronously - it will not stop to do fsync()s
** to insure data is written to the disk surface before
** continuing.  Transactions still work if synchronous is off,
** and the database cannot be corrupted if this program
** crashes.  But if the operating system crashes or there is
** an abrupt power failure when synchronous is off, the database
** could be left in an inconsistent and unrecoverable state.
** Synchronous is on by default so database corruption is not
** normally a worry.
*/
int sqlite3BtreeSetCacheSize(Btree *p, int mxPage){
  LOG("done",0);
  return SQLITE_OK;
}

/*
** Change the limit on the amount of the database file that may be
** memory mapped.
*/
int sqlite3BtreeSetMmapLimit(Btree *p, sqlite3_int64 szMmap){
  return SQLITE_OK;
}

#if SQLITE_VERSION_NUMBER >= 3008000
/*
** Change the way data is synced to disk in order to increase or decrease
** how well the database resists damage due to OS crashes and power
** failures.  Level 1 is the same as asynchronous (no syncs() occur and
** there is a high probability of damage)  Level 2 is the default.  There
** is a very low but non-zero probability of damage.  Level 3 reduces the
** probability of damage to near zero but with a write performance reduction.
*/
#ifndef SQLITE_OMIT_PAGER_PRAGMAS
int sqlite3BtreeSetPagerFlags(
  Btree *p,              /* The btree to set the safety level on */
  unsigned pgFlags       /* Various PAGER_* flags */
){
  /* this is not relevant to LMDB */
  return SQLITE_OK;
}
#endif

#endif

/*
** Set the cached rowid value of every cursor in the same database file
** as pCur and having the same root page number as pCur.  The value is
** set to iRowid.
**
** Only positive rowid values are considered valid for this cache.
** The cache is initialized to zero, indicating an invalid cache.
** A btree will work fine with zero or negative rowids.  We just cannot
** cache zero or negative rowids, which means tables that use zero or
** negative rowids might run a little slower.  But in practice, zero
** or negative rowids are very uncommon so this should not be a problem.
*/
void sqlite3BtreeSetCachedRowid(BtCursor *pCur, sqlite3_int64 iRowid){
  BtShared *pBt;
  BtCursor *pc;
  MDB_cursor *mc;
  MDB_dbi dbi;
  Btree *p;
  pBt = pCur->pBtree->pBt;

  mc = pCur->mc;
  dbi = mdb_cursor_dbi(mc);
  for (p=pBt->trees; p; p=p->pNext) {
    for (pc=p->pCursor; pc; pc=pc->pNext) {
	  if (mdb_cursor_dbi(pc->mc) == dbi)
	    pc->cachedRowid = iRowid;
	}
  }
  LOG("done",0);
}

/*
** Change the default pages size and the number of reserved bytes per page.
** Or, if the page size has already been fixed, return SQLITE_READONLY 
** without changing anything.
**
** The page size must be a power of 2 between 512 and 65536.  If the page
** size supplied does not meet this constraint then the page size is not
** changed.
**
** Page sizes are constrained to be a power of two so that the region
** of the database file used for locking (beginning at PENDING_BYTE,
** the first byte past the 1GB boundary, 0x40000000) needs to occur
** at the beginning of a page.
**
** If parameter nReserve is less than zero, then the number of reserved
** bytes per page is left unchanged.
**
** If the iFix!=0 then the pageSizeFixed flag is set so that the page size
** and autovacuum mode can no longer be changed.
*/
int sqlite3BtreeSetPageSize(Btree *p, int pageSize, int nReserve, int iFix){
  LOG("done",0);
	return SQLITE_READONLY;
}

/*
** Change the way data is synced to disk in order to increase or decrease
** how well the database resists damage due to OS crashes and power
** failures.  Level 1 is the same as asynchronous (no syncs() occur and
** there is a high probability of damage)  Level 2 is the default.  There
** is a very low but non-zero probability of damage.  Level 3 reduces the
** probability of damage to near zero but with a write performance reduction.
*/
#ifndef SQLITE_OMIT_PAGER_PRAGMAS
int sqlite3BtreeSetSafetyLevel(
  Btree *p,              /* The btree to set the safety level on */
  int level,             /* PRAGMA synchronous.  1=OFF, 2=NORMAL, 3=FULL */
  int fullSync,          /* PRAGMA fullfsync. */
  int ckptFullSync       /* PRAGMA checkpoint_fullfync */
){
  int onoff;
  if (level < 2)
    onoff = 1;
  else
    onoff = 0;
  mdb_env_set_flags(p->pBt->env, MDB_NOSYNC, onoff);
  LOG("done",0);
  return SQLITE_OK;
}
#endif

/*
** Set both the "read version" (single byte at byte offset 18) and 
** "write version" (single byte at byte offset 19) fields in the database
** header to iVersion.
*/
int sqlite3BtreeSetVersion(Btree *pBtree, int iVersion){
  LOG("done",0);
  return SQLITE_OK;
}

void sqlite3BtreeCursorHints(BtCursor *pCsr, unsigned int mask) {
	/* could use BTREE_BULKLOAD */
}

/*
** Return TRUE if the given btree is set to safety level 1.  In other
** words, return TRUE if no sync() occurs on the disk files.
*/
int sqlite3BtreeSyncDisabled(Btree *p){
  unsigned int flags;
  LOG("done",0);
  mdb_env_get_flags(p->pBt->env, &flags);
  return (flags & MDB_NOSYNC) != 0;
}

/*
** This routine sets the state to CURSOR_FAULT and the error
** code to errCode for every cursor on BtShared that pBtree
** references.
**
** Every cursor is tripped, including cursors that belong
** to other database connections that happen to be sharing
** the cache with pBtree.
**
** This is a no-op here since cursors in other transactions
** are fully isolated from the write transaction.
*/
#if SQLITE_VERSION_NUMBER < 3009000
void sqlite3BtreeTripAllCursors(Btree *pBtree, int errCode){
  LOG("done",0);
  /* no-op */
}
#else
int sqlite3BtreeTripAllCursors(Btree *pBtree, int errCode, int writeOnly){
    /* TODO - if writeOnly is true, we do not invalidate read-only cursors */
    return SQLITE_OK;
}
#endif

/*
** Write meta-information back into the database.  Meta[0] is
** read-only and may not be written.
*/
int sqlite3BtreeUpdateMeta(Btree *p, int idx, u32 iMeta){
  MDB_val key, data;
  MDB_dbi dbi;
  u32 idx32 = idx;
  int rc;

  if (p->eFlags & MDB_RDONLY)
    return SQLITE_READONLY;

  assert(idx > 0 && idx < NUMMETA);

  rc = mdb_open(p->curr_txn, NULL, 0, &dbi);
  key.mv_data = &idx32;
  key.mv_size = sizeof(idx32);
  data.mv_data = &iMeta;
  data.mv_size = sizeof(iMeta);
  rc = mdb_put(p->curr_txn, dbi, &key, &data, 0);
  LOG("rc=%d, idx=%d, iMeta=%u",rc,idx,iMeta);
  return errmap(rc);
}

#ifndef SQLITE_OMIT_SHARED_CACHE
/*
** Enable or disable the shared pager and schema features.
**
** This routine has no effect on existing database connections.
** The shared cache setting effects only future calls to
** sqlite3_open(), sqlite3_open16(), or sqlite3_open_v2().
*/
int sqlite3_enable_shared_cache(int enable){
  sqlite3GlobalConfig.sharedCacheEnabled = enable;
  LOG("done",0);
  return SQLITE_OK;
}
#endif
#endif

/* new functions added in SQLite 3.8.5 */
#if SQLITE_VERSION_NUMBER >= 3008005
/*
** Return the number of bytes of space at the end of every page that
** are intentually left unused.  This is the "reserved" space that is
** sometimes used by extensions.
**
** If SQLITE_HAS_MUTEX is defined then the number returned is the
** greater of the current reserved space and the maximum requested
** reserve space.
*/
int sqlite3BtreeGetOptimalReserve(Btree *p){
  int n=0;
#ifdef SQLITE_HAS_CODEC
  if( n<p->pBt->optimalReserve ) n = p->pBt->optimalReserve;
#endif
  return n;
}

/*
** Return true if the given Btree is read-only.
*/
int sqlite3BtreeIsReadonly(Btree *p){
  return (p->eFlags & MDB_RDONLY)!=0;
}

// TODO sqlite3BtreeClearTableOfCursor
// TODO sqlite3BtreeCursorRestore
// TODO sqlite3BtreeIncrblobCursor
// TODO sqlite3HeaderSizeBtree

#endif

