# automatically generated file for not-forking fragment_patch

method = fragment_patch
version >= 3.35

-----
src/pragma.c
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
+  int iLumoExt = 0;  /* are we looking for a LumoSQL extension? */
+#endif
 
   assert( pOp->p1>=0 && pOp->p1<p->nCursor );
   pC = p->apCsr[pOp->p1];
@@ -63,6 +66,12 @@
       if( pC->payloadSize > (u32)db->aLimit[SQLITE_LIMIT_LENGTH] ){
         goto too_big;
       }
+#ifdef LUMO_EXTENSIONS
+      /* see if there's a Lumo extension column at the end */
+      if (pC->isTable) {
+	iLumoExt = 1;
+      }
+#endif
     }
     pC->cacheStatus = p->cacheCtr;
     pC->iHdrOffset = getVarint32(pC->aRow, aOffset[0]);
@@ -164,6 +173,99 @@
         }
       }
 
+#ifdef LUMO_EXTENSIONS
+      if (iLumoExt){
+	/* see if the last column is a LumoSQL extension */
+	const unsigned char * zH = zHdr;
+	u64 lumoOffset = aOffset[i], nextOffset = aOffset[i];
+	int lumoType = pC->aType[i];
+#ifdef LUMO_ROWSUM
+	int rowsum_found = 0;
+#endif
+	while (zH < zEndHdr) {
+	  lumoOffset = nextOffset;
+	  zH += getVarint32(zH, lumoType);
+	  nextOffset += sqlite3VdbeSerialTypeLen(lumoType);
+	}
+	/* there was an extra hidden column, we need to check if it's
+	** ours and process it if so; in any case we then need to repeat
+	** the opcode to get the correct column; our column must be at
+	** least 8 bytes to be useful so we check that t >= 12+8*2 or 28 */
+	if (lumoType>=28 && (lumoType%2)==0){
+	  zH = zData + lumoOffset;
+	  if (memcmp(zH, LUMO_EXTENSION_MAGIC, 4)==0){
+	    const unsigned char * zEnd = zH + (lumoType/2);
+	    zH += 4;
+	    while (zH < zEnd) {
+	      unsigned int xtype, xsubtype, xlen;
+	      zH += getVarint32(zH, xtype);
+	      if (xtype == LUMO_END_TYPE) break;
+	      if (zH >= zEnd) goto op_column_corrupt;
+	      zH += getVarint32(zH, xsubtype);
+	      if (zH >= zEnd) goto op_column_corrupt;
+	      zH += getVarint32(zH, xlen);
+	      if (&zH[xlen] > zEnd) goto op_column_corrupt;
+#ifdef LUMO_ROWSUM
+	      if (xtype == LUMO_ROWSUM_TYPE && lumo_extension_check_rowsum) {
+		rowsum_found = 1;
+		if (xsubtype < lumo_rowsum_n_algorithms) {
+		  if (xlen == lumo_rowsum_algorithms[xsubtype].length){
+		    /* this looks like a rowsum, check the row against it */
+		    if (xlen != 0) {
+		      unsigned char rowsum[xlen];
+		      if( pC->szRow>=lumoOffset ){
+			/* the whole row fits in the page, so that's the easy case */
+			lumo_rowsum_algorithms[xsubtype].generate(rowsum, pC->aRow, lumoOffset);
+		      } else {
+			/* checksum the part of the row which does fit then do the rest */
+			char ctx[lumo_rowsum_algorithms[xsubtype].mem];
+			Mem cdata;
+			int left = lumoOffset - pC->szRow;
+			lumo_rowsum_algorithms[xsubtype].init(ctx);
+			lumo_rowsum_algorithms[xsubtype].update(ctx, pC->aRow, pC->szRow);
+			memset(&cdata, 0, sizeof(cdata));
+			cdata.szMalloc = 0;
+			cdata.flags = MEM_Null;
+			if( sqlite3VdbeMemGrow(&cdata, left, 0) ) goto no_mem;
+			rc = sqlite3VdbeMemFromBtree(pC->uc.pCursor, pC->szRow, left, &cdata);
+			if( rc!=SQLITE_OK ) {
+			  sqlite3VdbeMemRelease(&cdata);
+			  goto abort_due_to_error;
+			}
+			lumo_rowsum_algorithms[xsubtype].update(ctx, cdata.z, left);
+			sqlite3VdbeMemRelease(&cdata);
+			lumo_rowsum_algorithms[xsubtype].final(ctx, rowsum);
+		      }
+		      /* we calculated a rowsum for this row, does it match the one
+		      ** stored in the database? */
+		      if (memcmp(rowsum, zH, xlen) != 0)
+			goto op_column_corrupt;
+		    }
+		  } else {
+		    /* we know this algorithm, and the length of the stored rowsum
+		    ** differs from the expected; this won't do */
+		  goto op_column_corrupt;
+		  }
+		} else {
+		  /* we don't know this algorithm; we ignore this rowsum, but
+		  ** FIXME we may decide that it's an error if "need_rowsum"
+		  ** is set; or we may move the "rowsum_found = 1" inside the
+		  ** "true" branch of the if, in case there's more than one
+		  ** rowsum and then it'll be OK as long as we know at least
+		  ** one of the algorithms */
+		}
+	      }
+#endif
+	      zH += xlen;
+	    }
+	  }
+	}
+#ifdef LUMO_ROWSUM
+	if (lumo_extension_check_rowsum > 1 && !rowsum_found) goto op_column_corrupt;
+#endif
+      }
+#endif
+
       pC->nHdrParsed = i;
       pC->iHdrOffset = (u32)(zHdr - zData);
       if( pC->aRow==0 ) sqlite3VdbeMemRelease(&sMem);
---
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/ MakeRecord
/(?^:^\s*case\s+OP_(.*?[^:])\s*:)/
@@ -64,6 +64,7 @@
     }while( zAffinity[0] );
   }
 
+#ifndef LUMO_EXTENSIONS
 #ifdef SQLITE_ENABLE_NULL_TRIM
   /* NULLs can be safely trimmed from the end of the record, as long as
   ** as the schema format is 2 or more and none of the omitted columns
@@ -77,6 +78,7 @@
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
+  if (! (pOp->p5 & OPFLAG_PREFORMAT)) {
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
@@ -18,10 +22,23 @@
   x.pKey = pIn2->z;
   x.aMem = aMem + pOp->p3;
   x.nMem = (u16)pOp->p4.i;
+#if 0 /* this doesn't work yet */
+#ifdef LUMO_EXTENSIONS
+  rc = lumoExtensionAdd(db, 1, x.pKey, x.nKey, 0, &zLumoExt, &nData);
+  if (rc) goto abort_due_to_error;
+  if (zLumoExt) {
+    x.pKey = zLumoExt;
+    x.nKey = nData;
+  }
+#endif
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
