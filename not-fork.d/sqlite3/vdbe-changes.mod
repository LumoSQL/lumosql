# automatically generated file for not-forking fragment_patch

method = fragment_patch
version >= 3.35

-----
src/pragma.c
start
/(?^:^((?:static\s+)?(?:void|int)\s+\S+)\b)/
@@ -13,6 +13,10 @@
 */
 #include "sqliteInt.h"
 
+#ifdef LUMO_EXTENSIONS
+#include "lumo-vdbeInt.h"
+#endif
+
 #if !defined(SQLITE_ENABLE_LOCKING_STYLE)
 #  if defined(__APPLE__)
 #    define SQLITE_ENABLE_LOCKING_STYLE 1
---
/(?^:^((?:static\s+)?(?:void|int)\s+\S+)\b)/ static\x20int\x20integrityCheckResultRow(Vdbe
/(?^:^\*\*\s+(Process\s+a\s+pragma\b))/
@@ -7,4 +7,74 @@
   return addr;
 }
 
+/* parse special Lumo pragmas */
+static int lumo_parse_pragma(
+	sqlite3 * db,           /* database connection */
+	const char * zDb,       /* database name */
+	const char * zLeft,     /* pragma ID */
+	const char * zRight,    /* value or NULL */
+	const char ** zResult   /* string result value or error message */
+){
+  *zResult = 0;
+#ifdef LUMO_ROWSUM
+  if (strcmp(zLeft, "lumo_rowsum_algorithm") == 0) {
+    // XXX in future, we'll store this with the database, but for now is global
+    if (zRight) {
+      /* set the algorithm */
+      int i;
+      /* if it's an alias, see what's the real algorithm */
+      for (i = 0; i < lumo_rowsum_n_alias; i++) {
+	if (strcmp(zRight, lumo_rowsum_alias[i].name) == 0) {
+	  lumo_rowsum_algorithm = lumo_rowsum_alias[i].same_as;
+	  /* if they disabled creation of rowsums, but the check is
+	  ** set to "always" the next update will fail, so set it
+	  ** to "yes" */
+	  if (lumo_rowsum_algorithm >= lumo_rowsum_n_algorithms &&
+	      lumo_extension_check_rowsum > 1)
+	    lumo_extension_check_rowsum = 1;
+	  return SQLITE_OK;
+	}
+      }
+      /* otherwise, see if it's an algorithm name */
+      for (i = 0; i < lumo_rowsum_n_algorithms; i++) {
+	if (strcmp(zRight, lumo_rowsum_algorithms[i].name) == 0) {
+	  lumo_rowsum_algorithm = i;
+	  return SQLITE_OK;
+	}
+      }
+      /* not found */
+      *zResult = "Invalid rowsum algorithm";
+      return SQLITE_ERROR;
+    } else {
+      /* get the name of the algorithm */
+      const char * zAlg;
+      if (lumo_rowsum_algorithm < lumo_rowsum_n_algorithms) {
+	*zResult = lumo_rowsum_algorithms[lumo_rowsum_algorithm].name;
+      } else {
+	*zResult = "none";
+      }
+      return SQLITE_OK;
+    }
+  }
+  if (strcmp(zLeft, "lumo_check_rowsum") == 0) {
+    // XXX in future, we'll store this with the database, but for now is global
+    if (zRight) {
+      if (strcmp(zRight, "always") == 0 || strcmp(zRight, "require") == 0)
+	lumo_extension_check_rowsum = 2;
+      else
+	lumo_extension_check_rowsum = sqlite3GetBoolean(zRight, 1);
+    } else {
+      *zResult = lumo_extension_check_rowsum>1 ? "always" :
+		 (lumo_extension_check_rowsum ? "yes" : "no");
+    }
+    return SQLITE_OK;
+  }
+#endif /* LUMO_ROWSUM */
+#ifdef LUMO_BACKEND_PRAGMA
+  return lumo_backend_pragma(db, zDb, zLeft, zRight, zResult);
+#else
+  return SQLITE_NOTFOUND;
+#endif
+}
+
 /*
---
/(?^:^((?:static\s+)?(?:void|int)\s+\S+)\b)/ void\x20sqlite3Pragma
/(?^:^\s*case\s+PragTyp_(.*?[^:])\s*:)/
@@ -16,6 +16,7 @@
   Db *pDb;                     /* The specific database being pragmaed */
   Vdbe *v = sqlite3GetVdbe(pParse);  /* Prepared statement */
   const PragmaName *pPragma;   /* The pragma */
+  const char * zLumoResult = 0;
 
   if( v==0 ) return;
   sqlite3VdbeRunOnlyOnce(v);
@@ -84,6 +85,23 @@
     pParse->nErr++;
     pParse->rc = rc;
     goto pragma_out;
+  }
+
+  /* see if this is a special Lumo pragma */
+  rc = lumo_parse_pragma(db, zDb, zLeft, zRight, &zLumoResult);
+  if( rc==SQLITE_OK ){
+    sqlite3VdbeSetNumCols(v, 1);
+    sqlite3VdbeSetColName(v, 0, COLNAME_NAME, zLumoResult, SQLITE_TRANSIENT);
+    if (zLumoResult)
+      returnSingleText(v, zLumoResult);
+    goto pragma_out;
+  }
+  if( rc!=SQLITE_NOTFOUND ){
+    if( zLumoResult )
+      sqlite3ErrorMsg(pParse, "%s", zLumoResult);
+    pParse->nErr++;
+    pParse->rc = rc;
+    goto pragma_out;
   }
 
   /* Locate the pragma in the lookup table */
---
-----
src/vdbe.c
start
/(?^:^((?:static\s+)?(?:void|int)\s+\S+)\b)/
@@ -21,6 +21,21 @@
 #include "sqliteInt.h"
 #include "vdbeInt.h"
 
+#ifdef LUMO_EXTENSIONS
+#include "lumo-vdbeInt.h"
+#include "lumo-vdbeAdd.c"
+
+#ifdef LUMO_ROWSUM
+/* default value when creating a new table */
+unsigned int lumo_rowsum_algorithm = LUMO_ROWSUM_ID_sha3;
+
+/* how we check the rowsum: 0, we don't check it at all; 1, we check it
+** if present, but don't require it; 2, we require it to be there and
+** check it */
+int lumo_extension_check_rowsum = 2;
+#endif
+#endif
+
 /*
 ** Invoke this macro on memory cells just prior to changing the
 ** value of the cell.  This macro verifies that shallow copies are
---
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/ Column
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/
@@ -13,6 +13,9 @@
   u64 offset64;      /* 64-bit offset */
   u32 t;             /* A type code from the record header */
   Mem *pReg;         /* PseudoTable input register */
+#ifdef LUMO_EXTENSIONS
+  int check_lumo;    /* will we be checking for Lumo data? */
+#endif
 
   assert( pOp->p1>=0 && pOp->p1<p->nCursor );
   pC = p->apCsr[pOp->p1];
@@ -36,6 +39,10 @@
   assert( pC->eCurType!=CURTYPE_PSEUDO || pC->nullRow );
   assert( pC->eCurType!=CURTYPE_SORTER );
 
+#ifdef LUMO_EXTENSIONS
+  check_lumo = 0;
+#endif
+
   if( pC->cacheStatus!=p->cacheCtr ){                /*OPTIMIZATION-IF-FALSE*/
     if( pC->nullRow ){
       if( pC->eCurType==CURTYPE_PSEUDO ){
@@ -68,6 +75,9 @@
     pC->iHdrOffset = getVarint32(pC->aRow, aOffset[0]);
     pC->nHdrParsed = 0;
 
+#ifdef LUMO_EXTENSIONS
+    check_lumo = 1;
+#endif
 
     if( pC->szRow<aOffset[0] ){      /*OPTIMIZATION-IF-FALSE*/
       /* pC->aRow does not have to hold the entire row, but it does at least
@@ -183,6 +193,27 @@
       }
       goto op_column_out;
     }
+#ifdef LUMO_EXTENSIONS
+    if (check_lumo) {
+      u64 nStart, nLen;
+      int ok = 0;
+      /* see if a Lumo column is present */
+      if (lumoExtensionPresent(!pC->isTable, (u32)pC->nHdrParsed, (u32)pC->iHdrOffset,
+			       (u64)aOffset[pC->nHdrParsed], (u32)pC->nField, zData,
+			       (u32)aOffset[0], (u64)pC->payloadSize, &nStart, &nLen)) {
+	/* a Lumo column is present at nStart for a length of nLen */
+	const unsigned char *zRow;
+	zRow = &zData[nStart]; // XXX make sure we have the data in memory and have zRow point at it
+	ok = lumoExtensionHandle(!pC->isTable, zRow, nStart, nLen, pC);
+	if (ok < 0) goto op_column_corrupt;
+      }
+      if (!ok) {
+	/* handle case of missing Lumo column, if important */
+	if (! lumoExtensionMissing(db)) goto op_column_corrupt;
+      }
+    }
+#endif
+
   }else{
     t = pC->aType[p2];
   }
---
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/ MakeRecord
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/
@@ -64,6 +64,9 @@
     }while( zAffinity[0] );
   }
 
+#ifndef LUMO_EXTENSIONS
+  /* we cannot trim NULLs otherwise OP_Column will find our extra
+  ** columns where it would have found a NULL... */
 #ifdef SQLITE_ENABLE_NULL_TRIM
   /* NULLs can be safely trimmed from the end of the record, as long as
   ** as the schema format is 2 or more and none of the omitted columns
@@ -77,6 +80,7 @@
     }
   }
 #endif
+#endif
 
   /* Loop through the elements that will make up the record to figure
   ** out how much space is required for the new record.  After this loop,
---
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/ Insert
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/
@@ -6,6 +6,9 @@
   const char *zDb;  /* database name - used by the update hook */
   Table *pTab;      /* Table structure - used by update and pre-update hooks */
   BtreePayload x;   /* Payload to be inserted */
+#ifdef LUMO_EXTENSIONS
+  unsigned char * zLumoExt = NULL; /* memory allocated to add the Lumo extensions */
+#endif
 
   pData = &aMem[pOp->p2];
   assert( pOp->p1>=0 && pOp->p1<p->nCursor );
@@ -62,10 +65,24 @@
     x.nZero = 0;
   }
   x.pKey = 0;
+#ifdef LUMO_EXTENSIONS
+  if (! (pOp->p5 & OPFLAG_PREFORMAT) && ! pC->isEphemeral) {
+    sqlite3_int64 nData;
+    rc = lumoExtensionAdd(db, 0, x.pData, x.nData, x.nZero, &zLumoExt, &nData);
+    if (rc) goto abort_due_to_error;
+    if (zLumoExt) {
+      x.pData = zLumoExt;
+      x.nData = nData;
+    }
+  }
+#endif
   rc = sqlite3BtreeInsert(pC->uc.pCursor, &x,
       (pOp->p5 & (OPFLAG_APPEND|OPFLAG_SAVEPOSITION|OPFLAG_PREFORMAT)), 
       seekResult
   );
+#ifdef LUMO_EXTENSIONS
+  if (zLumoExt) sqlite3DbFree(db, zLumoExt);
+#endif
   pC->deferredMoveto = 0;
   pC->cacheStatus = CACHE_STALE;
 
---
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/ IdxInsert
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/
@@ -1,6 +1,10 @@
 case OP_IdxInsert: {        /* in2 */
   VdbeCursor *pC;
   BtreePayload x;
+#ifdef LUMO_EXTENSIONS
+  unsigned char * zLumoExt = NULL; /* memory allocated to add the Lumo extensions */
+  sqlite3_int64 nData;
+#endif
 
   assert( pOp->p1>=0 && pOp->p1<p->nCursor );
   pC = p->apCsr[pOp->p1];
@@ -18,10 +22,21 @@
   x.pKey = pIn2->z;
   x.aMem = aMem + pOp->p3;
   x.nMem = (u16)pOp->p4.i;
+#ifdef LUMO_EXTENSIONS
+  rc = lumoExtensionAdd(db, 1, x.pKey, x.nKey, 0, &zLumoExt, &nData);
+  if (rc) goto abort_due_to_error;
+  if (zLumoExt) {
+    x.pKey = zLumoExt;
+    x.nKey = nData;
+  }
+#endif
   rc = sqlite3BtreeInsert(pC->uc.pCursor, &x,
        (pOp->p5 & (OPFLAG_APPEND|OPFLAG_SAVEPOSITION|OPFLAG_PREFORMAT)), 
       ((pOp->p5 & OPFLAG_USESEEKRESULT) ? pC->seekResult : 0)
       );
+#ifdef LUMO_EXTENSIONS
+  if (zLumoExt) sqlite3DbFree(db, zLumoExt);
+#endif
   assert( pC->deferredMoveto==0 );
   pC->cacheStatus = CACHE_STALE;
   if( rc) goto abort_due_to_error;
---
-----
