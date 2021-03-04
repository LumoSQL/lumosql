/*

  Copyright 2021 The LumoSQL Authors under the terms contained in the file LICENSES/MIT

  SPDX-License-Identifier: MIT
  SPDX-FileCopyrightText: 2021 The LumoSQL Authors
  SPDX-ArtifactOfProjectName: LumoSQL
  SPDX-FileType: Code
  SPDX-FileComment: Original by Claudio Calvelli, 2021

  not-fork.d/lmdb/files/backup.c
*/

#ifndef __LUMO_BACKEND_backup_c
#define __LUMO_BACKEND_backup_c 1

/*
** Create an sqlite3_backup process to copy the contents of zSrcDb from
** connection handle pSrcDb to zDestDb in pDestDb. If successful, return
** a pointer to the new sqlite3_backup object.
**
** If an error occurs, NULL is returned and an error code and error message
** stored in database handle pDestDb.
*/
sqlite3_backup *sqlite3_backup_init(
  sqlite3* pDestDb,                     /* Database to write to */
  const char *zDestDb,                  /* Name of database within pDestDb */
  sqlite3* pSrcDb,                      /* Database connection to read from */
  const char *zSrcDb                    /* Name of database within pSrcDb */
){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3_backup_init\n"); fclose(fp); // XXX
  return NULL; // XXX sqlite3_backup_init
}

/*
** Return the total number of pages in the source database as of the most 
** recent call to sqlite3_backup_step().
*/
int sqlite3_backup_pagecount(sqlite3_backup *p){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3_backup_pagecount\n"); fclose(fp); // XXX
  return 0; // XXX sqlite3_backup_pagecount
}

/*
** Return the number of pages still to be backed up as of the most recent
** call to sqlite3_backup_step().
*/
int sqlite3_backup_remaining(sqlite3_backup *p){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3_backup_remaining\n"); fclose(fp); // XXX
  return 0; // XXX sqlite3_backup_remaining
}

/*
** Copy nPage pages from the source b-tree to the destination.
*/
int sqlite3_backup_step(sqlite3_backup *p, int nPage){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3_backup_step\n"); fclose(fp); // XXX
  return SQLITE_INTERNAL; // XXX sqlite3_backup_step
}

/*
** Release all resources associated with an sqlite3_backup* handle.
*/
int sqlite3_backup_finish(sqlite3_backup *p){
  FILE *fp = fopen("/tmp/lmdb.debug", "a"); fprintf(fp, "called: sqlite3_backup_finish\n"); fclose(fp); // XXX
  return SQLITE_INTERNAL; // XXX sqlite3_backup_finish
}

#endif
