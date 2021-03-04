/*

  Copyright 2021 The LumoSQL Authors under the terms contained in the file LICENSES/MIT

  SPDX-License-Identifier: MIT
  SPDX-FileCopyrightText: 2021 The LumoSQL Authors
  SPDX-ArtifactOfProjectName: LumoSQL
  SPDX-FileType: Code
  SPDX-FileComment: Original by Claudio Calvelli, 2021

  not-fork.d/lmdb/files/pager.c
*/

#ifndef __LUMO_BACKEND_pager_c
#define __LUMO_BACKEND_pager_c 1

static sqlite3_file fakeFile = { 0, };

sqlite3_file *sqlite3_database_file_object(const char *zName){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3_database_file_object\n"); fclose(fp); // XXX
  return NULL; // XXX sqlite3_database_file_object
}

void sqlite3PagerCacheStat(Pager *pPager, int eStat, int reset, int *pnVal){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerCacheStat\n"); fclose(fp); // XXX
  // XXX sqlite3PagerCacheStat
}

void *sqlite3PagerGetData(DbPage *pPg){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerGetData\n"); fclose(fp); // XXX
  return NULL; // XXX sqlite3PagerCloseWal
}

int sqlite3PagerCloseWal(Pager *pPager, sqlite3 *db){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerCloseWal\n"); fclose(fp); // XXX
  return SQLITE_INTERNAL; // XXX sqlite3PagerCloseWal
}

u32 sqlite3PagerDataVersion(Pager *pPager){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerDataVersion\n"); fclose(fp); // XXX
  return 0; // XXX sqlite3PagerDataVersion
}

/*
** This function may only be called while a write-transaction is active in
** rollback. If the connection is in WAL mode, this call is a no-op. 
** Otherwise, if the connection does not already have an EXCLUSIVE lock on 
** the database file, an attempt is made to obtain one.
**
** If the EXCLUSIVE lock is already held or the attempt to obtain it is
** successful, or the connection is in WAL mode, SQLITE_OK is returned.
** Otherwise, either SQLITE_BUSY or an SQLITE_IOERR_XXX error code is 
** returned.
*/
/* with LMDB, this call is always a no-op */
int sqlite3PagerExclusiveLock(Pager *pPager){
  return SQLITE_OK;
}

sqlite3_file *sqlite3PagerFile(Pager *pPager){
  return &fakeFile;
}

const char *sqlite3PagerFilename(const Pager *pPager, int nullIfMemDb){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerFilename\n"); fclose(fp); // XXX
  return NULL; // XXX sqlite3PagerFilename
}

int sqlite3PagerFlush(Pager *pPager){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerFlush\n"); fclose(fp); // XXX
  return SQLITE_INTERNAL; // XXX sqlite3PagerFlush
}

int sqlite3PagerGet(Pager *pPager, Pgno pgno, DbPage **ppPage, int flags) {
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerGet\n"); fclose(fp); // XXX
  return SQLITE_INTERNAL; // XXX sqlite3PagerGet
}

int sqlite3PagerGetJournalMode(Pager *pPager){
  /* in reality, "none of the above" */
  // XXX return PAGER_JOURNALMODE_DELETE;
  return PAGER_JOURNALMODE_OFF;
}

i64 sqlite3PagerJournalSizeLimit(Pager *pPager, i64 iLimit){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerJournalSizeLimit\n"); fclose(fp); // XXX
  return 0; // XXX sqlite3PagerJournalSizeLimit
}

sqlite3_file *sqlite3PagerJrnlFile(Pager *pPager){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerJrnlFile\n"); fclose(fp); // XXX
  return NULL; // XXX sqlite3PagerJrnlFile
}

int sqlite3PagerLockingMode(Pager *pPager, int eMode){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerLockingMode\n"); fclose(fp); // XXX
  return 0; // XXX sqlite3PagerLockingMode
}

DbPage *sqlite3PagerLookup(Pager *pPager, Pgno pgno){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerLookup\n"); fclose(fp); // XXX
  return NULL; // XXX sqlite3PagerLookup
}

int sqlite3PagerMemUsed(Pager *pPager){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerMemUsed\n"); fclose(fp); // XXX
  return SQLITE_INTERNAL; // XXX sqlite3PagerMemUsed
}

int sqlite3PagerOkToChangeJournalMode(Pager *pPager){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerOkToChangeJournalMode\n"); fclose(fp); // XXX
  return 0; // XXX sqlite3PagerOkToChangeJournalMode
}

void sqlite3PagerPagecount(Pager *pPager, int *pnPage){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerPagecount\n"); fclose(fp); // XXX
  // XXX sqlite3PagerPagecount
}

int sqlite3PagerSetJournalMode(Pager *pPager, int eMode){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerSetJournalMode\n"); fclose(fp); // XXX
  return SQLITE_INTERNAL; // XXX sqlite3PagerSetJournalMode
}

void sqlite3PagerShrink(Pager *pPager){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerShrink\n"); fclose(fp); // XXX
  // XXX sqlite3PagerShrink;
}

void sqlite3PagerUnref(DbPage *pPg){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerUnref\n"); fclose(fp); // XXX
  // XXX sqlite3PagerUnref
}

void sqlite3PagerUnrefPageOne(DbPage *pPg){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerUnrefPageOne\n"); fclose(fp); // XXX
  // XXX sqlite3PagerUnrefPageOne
}

sqlite3_vfs *sqlite3PagerVfs(Pager *pPager){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerVfs\n"); fclose(fp); // XXX
  return NULL; // sqlite3PagerVfs
}

int sqlite3PagerWalCallback(Pager *pPager){
  return SQLITE_OK;
}

/* no WAL needed for LMDB */
int sqlite3PagerWalSupported(Pager *pPager){
  return 0;
}

int sqlite3PagerWrite(PgHdr *pPg){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3PagerWrite\n"); fclose(fp); // XXX
  return SQLITE_INTERNAL; // XXX sqlite3PagerWalCallback
}

#endif
