# update various files to provide a Lumo extension; currently
# used to add rowsum

method = patch
--
--- sqlite3/src/pragma.c-orig	2021-02-22 15:29:35.146284010 +0100
+++ sqlite3/src/pragma.c	2021-02-23 12:46:09.574704069 +0100
@@ -13,6 +13,8 @@
 */
 #include "sqliteInt.h"
 
+#include "lumo-vdbeInt.h"
+
 #if !defined(SQLITE_ENABLE_LOCKING_STYLE)
 #  if defined(__APPLE__)
 #    define SQLITE_ENABLE_LOCKING_STYLE 1
@@ -362,6 +364,72 @@
   return addr;
 }
 
+#ifdef LUMO_EXTENSIONS
+/* parse special Lumo pragmas */
+static int lumo_parse_pragma(
+	sqlite3 * db,           /* database connection */
+	const char * zDb,       /* database name */
+	const char * zLeft,     /* pragma ID */
+	const char * zRight,    /* value or NULL */
+	const char ** zResult   /* string result value or error message */
+){
+  *zResult = 0;
+  if (strcmp(zLeft, "lumo_rowsum_algorithm") == 0) {
+    // XXX in future, we'll store this with the database, but for now is global
+    if (zRight) {
+      /* set the algorithm */
+      int i;
+      /* if it's an alias, see what's the real algorithm */
+      for (i = 0; i < LUMO_ROWSUM_N_ALIAS; i++) {
+	if (strcmp(zRight, lumo_rowsum_alias[i].name) == 0) {
+	  lumo_rowsum_algorithm = lumo_rowsum_alias[i].same_as;
+	  /* if they disabled creation of rowsums, but the check is
+	  ** set to "always" the next update will fail, so set it
+	  ** to "yes" */
+	  if (lumo_rowsum_algorithm >= LUMO_ROWSUM_N_ALGORITHMS &&
+	      lumo_extension_check_rowsum > 1)
+	    lumo_extension_check_rowsum = 1;
+	  return SQLITE_OK;
+	}
+      }
+      /* otherwise, see if it's an algorithm name */
+      for (i = 0; i < LUMO_ROWSUM_N_ALGORITHMS; i++) {
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
+      if (lumo_rowsum_algorithm < LUMO_ROWSUM_N_ALGORITHMS) {
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
+  return SQLITE_NOTFOUND;
+}
+#endif /* LUMO_EXTENSIONS */
+
 /*
 ** Process a pragma statement.  
 **
@@ -395,6 +463,9 @@
   Db *pDb;                     /* The specific database being pragmaed */
   Vdbe *v = sqlite3GetVdbe(pParse);  /* Prepared statement */
   const PragmaName *pPragma;   /* The pragma */
+#ifdef LUMO_EXTENSIONS
+  const char * zLumoResult = 0;
+#endif
 
   if( v==0 ) return;
   sqlite3VdbeRunOnlyOnce(v);
@@ -465,6 +536,25 @@
     goto pragma_out;
   }
 
+#ifdef LUMO_EXTENSIONS
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
+  }
+#endif
+
   /* Locate the pragma in the lookup table */
   pPragma = pragmaLocate(zLeft);
   if( pPragma==0 ) goto pragma_out;
--- sqlite3/src/vdbe.c-orig	2021-02-11 09:36:38.605044099 +0100
+++ sqlite3/src/vdbe.c	2021-02-22 19:32:22.029862245 +0100
@@ -21,6 +21,18 @@
 #include "sqliteInt.h"
 #include "vdbeInt.h"
 
+#include "lumo-vdbeInt.h"
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
+
 /*
 ** Invoke this macro on memory cells just prior to changing the
 ** value of the cell.  This macro verifies that shallow copies are
@@ -2609,6 +2621,9 @@
   u64 offset64;      /* 64-bit offset */
   u32 t;             /* A type code from the record header */
   Mem *pReg;         /* PseudoTable input register */
+#ifdef LUMO_EXTENSIONS
+  u32 iLumoExt;      /* remember if we've looked for a Lumo extension */
+#endif
 
   assert( pOp->p1>=0 && pOp->p1<p->nCursor );
   pC = p->apCsr[pOp->p1];
@@ -2631,6 +2646,9 @@
   assert( pC->eCurType!=CURTYPE_PSEUDO || pC->nullRow );
   assert( pC->eCurType!=CURTYPE_SORTER );
 
+#ifdef LUMO_EXTENSIONS
+  iLumoExt = 0;
+#endif
   if( pC->cacheStatus!=p->cacheCtr ){                /*OPTIMIZATION-IF-FALSE*/
     if( pC->nullRow ){
       if( pC->eCurType==CURTYPE_PSEUDO ){
@@ -2658,6 +2676,13 @@
       if( pC->payloadSize > (u32)db->aLimit[SQLITE_LIMIT_LENGTH] ){
         goto too_big;
       }
+#ifdef LUMO_EXTENSIONS
+      /* we will be looking for the extra "Lumo extension" blob */
+      if (pC->isTable) {
+	iLumoExt = p2 + 1;
+	p2 = pC->nField - 1;
+      }
+#endif
     }
     pC->cacheStatus = p->cacheCtr;
     pC->iHdrOffset = getVarint32(pC->aRow, aOffset[0]);
@@ -2705,6 +2730,12 @@
     }
   }
 
+#ifdef LUMO_EXTENSIONS
+  /* we may repeat the whole code twice: if the first time we extract the
+  ** hidden "Lumo" column, we process it then get back here to do whaat
+  ** we were asked to do in he first place */
+op_column_lumo_repeat:
+#endif
   /* Make sure at least the first p2+1 entries of the header have been
   ** parsed and valid information is in aOffset[] and pC->aType[].
   */
@@ -2771,6 +2802,17 @@
     ** columns.  So the result will be either the default value or a NULL.
     */
     if( pC->nHdrParsed<=p2 ){
+#ifdef LUMO_EXTENSIONS
+      if (iLumoExt > 0){
+	/* we tried to get the Lumo column, and it wasn't there */
+#ifdef LUMO_ROWSUM
+	if (lumo_extension_check_rowsum > 1) goto op_column_corrupt;
+#endif
+	p2 = iLumoExt-1;
+	iLumoExt = 0;
+	goto op_column_lumo_repeat;
+      }
+#endif
       if( pOp->p4type==P4_MEM ){
         sqlite3VdbeMemShallowCopy(pDest, pOp->p4.pMem, MEM_Static);
       }else{
@@ -2838,7 +2880,20 @@
       ** as that array is 256 bytes long (plenty for VdbeMemPrettyPrint())
       ** and it begins with a bunch of zeros.
       */
-      sqlite3VdbeSerialGet((u8*)sqlite3CtypeMap, t, pDest);
+#ifdef LUMO_EXTENSIONS
+      /* ... however the Lumo blob is still necessary */
+      if (iLumoExt > 0 && t>=28 && (t%2) == 0) {
+	rc = sqlite3VdbeMemFromBtree(pC->uc.pCursor, aOffset[p2], len, pDest);
+	if( rc!=SQLITE_OK ) goto abort_due_to_error;
+	sqlite3VdbeSerialGet((const u8*)pDest->z, t, pDest);
+	pDest->flags &= ~MEM_Ephem;
+      } else {
+#else
+	sqlite3VdbeSerialGet((u8*)sqlite3CtypeMap, t, pDest);
+#endif
+#ifdef LUMO_EXTENSIONS
+      }
+#endif
     }else{
       rc = sqlite3VdbeMemFromBtree(pC->uc.pCursor, aOffset[p2], len, pDest);
       if( rc!=SQLITE_OK ) goto abort_due_to_error;
@@ -2847,6 +2902,91 @@
     }
   }
 
+#ifdef LUMO_EXTENSIONS
+  if (iLumoExt > 0){
+    /* there was an extra hidden column, we need to check if it's
+    ** ours and process it if so; in any case we then need to repeat
+    ** the opcode to get the correct column; our column must be at
+    ** least 8 bytes to be useful so we check that t >= 12+8*2 or 28 */
+    if (t>=28 && (t%2)==0 && memcmp(pDest->z, LUMO_EXTENSION_MAGIC, 4)==0){
+      int ptr = 4;
+#ifdef LUMO_ROWSUM
+      int rowsum_found = 0;
+#endif
+      while (ptr < len) {
+	unsigned int xtype, xsubtype, xlen;
+	if (len - ptr < 1) goto op_column_corrupt;
+	ptr += getVarint32(&pDest->z[ptr], xtype);
+	if (xtype == LUMO_END_TYPE) break;
+	if (len - ptr < 2) goto op_column_corrupt;
+	ptr += getVarint32(&pDest->z[ptr], xsubtype);
+	if (len - ptr < 1) goto op_column_corrupt;
+	ptr += getVarint32(&pDest->z[ptr], xlen);
+	if (len - ptr < xlen) goto op_column_corrupt;
+#ifdef LUMO_ROWSUM
+	if (xtype == LUMO_ROWSUM_TYPE && lumo_extension_check_rowsum) {
+	  rowsum_found = 1;
+	  if (xsubtype < LUMO_ROWSUM_N_ALGORITHMS) {
+	    if (xlen == lumo_rowsum_algorithms[xsubtype].length){
+	      /* this looks like a rowsum, check the row against it */
+	      if (xlen != 0) {
+		unsigned char rowsum[xlen];
+		if( pC->szRow>=aOffset[p2] ){
+		  /* the whole row fits in the page, so that's the easy case */
+		  lumo_rowsum_algorithms[xsubtype].generate(rowsum, pC->aRow, aOffset[p2]);
+		} else {
+		  /* checksum the part of the row which does fit then do the rest */
+		  char ctx[lumo_rowsum_algorithms[xsubtype].mem];
+		  Mem cdata;
+		  int l;
+		  lumo_rowsum_algorithms[xsubtype].init(ctx);
+		  lumo_rowsum_algorithms[xsubtype].update(ctx, pC->aRow, pC->szRow);
+		  memset(&cdata, 0, sizeof(cdata));
+		  cdata.szMalloc = 0;
+		  cdata.flags = MEM_Null;
+		  l = aOffset[p2] - pC->szRow;
+		  if( sqlite3VdbeMemGrow(&cdata, l, 0) ) goto no_mem;
+		  rc = sqlite3VdbeMemFromBtree(pC->uc.pCursor, pC->szRow, l, &cdata);
+		  if( rc!=SQLITE_OK ) {
+		    sqlite3VdbeMemRelease(&cdata);
+		    goto abort_due_to_error;
+		  }
+		  lumo_rowsum_algorithms[xsubtype].update(ctx, cdata.z, l);
+		  sqlite3VdbeMemRelease(&cdata);
+		  lumo_rowsum_algorithms[xsubtype].final(ctx, rowsum);
+		}
+		/* we calculated a rowsum for this row, does it match the one
+		** stored in the database? */
+		if (memcmp(rowsum, &pDest->z[ptr], xlen) != 0)
+		  goto op_column_corrupt;
+	      }
+	    } else {
+	      /* we know this algorithm, and the length of the stored rowsum
+	      ** differs from the expected; this won't do */
+	      goto op_column_corrupt;
+	    }
+	  } else {
+	    /* we don't know this algorithm; we ignore this rowsum, but
+	    ** FIXME we may decide that it's an error if "need_rowsum"
+	    ** is set; or we may move the "rowsum_found = 1" inside the
+	    ** "true" branch of the if, in case there's more than one
+	    ** rowsum and then it'll be OK as long as we know at least
+	    ** one of the algorithms */
+	  }
+	}
+#endif
+	ptr += xlen;
+      }
+#ifdef LUMO_ROWSUM
+      if (lumo_extension_check_rowsum > 1 && !rowsum_found) goto op_column_corrupt;
+#endif
+    }
+    p2 = iLumoExt-1;
+    iLumoExt = 0;
+    goto op_column_lumo_repeat;
+  }
+#endif
+
 op_column_out:
   UPDATE_MAX_BLOBSIZE(pDest);
   REGISTER_TRACE(pOp->p3, pDest);
@@ -2952,6 +3092,9 @@
   u32 len;               /* Length of a field */
   u8 *zHdr;              /* Where to write next byte of the header */
   u8 *zPayload;          /* Where to write next byte of the payload */
+#ifdef LUMO_EXTENSIONS
+  int iLumoExt;          /* are we adding LumoSQL extensions? */
+#endif
 
   /* Assuming the record contains N fields, the record format looks
   ** like this:
@@ -3002,7 +3145,32 @@
     }while( zAffinity[0] );
   }
 
+#ifdef LUMO_EXTENSIONS
+  /* see if we'll be adding any extensions */
+  iLumoExt = 0;
+#ifdef LUMO_ROWSUM
+  if (lumo_rowsum_algorithm < LUMO_ROWSUM_N_ALGORITHMS) {
+    int xLen;
+    /* add space for the rowsum */
+    xLen = lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
+    iLumoExt += sqlite3VarintLen(LUMO_ROWSUM_TYPE);
+    iLumoExt += sqlite3VarintLen(lumo_rowsum_algorithm);
+    iLumoExt += sqlite3VarintLen(xLen);
+    iLumoExt += xLen;
+  }
+#endif
+  if (iLumoExt) {
+    /* add space for the initial "Lumo" and the end type */
+    iLumoExt += 4 + sqlite3VarintLen(LUMO_END_TYPE);
+  }
+#endif
+
 #ifdef SQLITE_ENABLE_NULL_TRIM
+#ifdef LUMO_EXTENSIONS
+  /* if there are any extensions we cannot trim NULLs so we wrap this
+  ** code in an extra "if" */
+  if (iLumoExt == 0) {
+#endif
   /* NULLs can be safely trimmed from the end of the record, as long as
   ** as the schema format is 2 or more and none of the omitted columns
   ** have a non-NULL default value.  Also, the record must be left with
@@ -3014,6 +3182,9 @@
       nField--;
     }
   }
+#ifdef LUMO_EXTENSIONS
+  }
+#endif
 #endif
 
   /* Loop through the elements that will make up the record to figure
@@ -3136,6 +3307,12 @@
     if( pRec==pData0 ) break;
     pRec--;
   }while(1);
+#ifdef LUMO_EXTENSIONS
+  if (iLumoExt > 0) {
+    nData += iLumoExt;
+    nHdr += sqlite3VarintLen(iLumoExt*2+12);
+  }
+#endif
 
   /* EVIDENCE-OF: R-22564-11647 The header begins with a single varint
   ** which determines the total number of bytes in the header. The varint
@@ -3196,6 +3373,29 @@
     ** immediately follow the header. */
     zPayload += sqlite3VdbeSerialPut(zPayload, pRec, serial_type); /* content */
   }while( (++pRec)<=pLast );
+#ifdef LUMO_EXTENSIONS
+  if (iLumoExt > 0) {
+    unsigned int uLen = zPayload - (u8*)pOut->z;
+    /* put the column type first, as it may be used in the rowsum calculations */
+    zHdr += putVarint32(zHdr, iLumoExt*2+12);
+    memcpy(zPayload, LUMO_EXTENSION_MAGIC, 4);
+    zPayload += 4;
+#ifdef LUMO_ROWSUM
+    if (lumo_rowsum_algorithm < LUMO_ROWSUM_N_ALGORITHMS) {
+      int iSumLen;
+      iSumLen = lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
+      zPayload += putVarint32(zPayload, LUMO_ROWSUM_TYPE);
+      zPayload += putVarint32(zPayload, lumo_rowsum_algorithm);
+      zPayload += putVarint32(zPayload, iSumLen);
+      if (iSumLen > 0){
+	lumo_rowsum_algorithms[lumo_rowsum_algorithm].generate(zPayload, pOut->z, uLen);
+	zPayload += iSumLen;
+      }
+    }
+#endif
+    zPayload += putVarint32(zPayload, LUMO_END_TYPE);
+  }
+#endif
   assert( nHdr==(int)(zHdr - (u8*)pOut->z) );
   assert( nByte==(int)(zPayload - (u8*)pOut->z) );
 
@@ -3837,6 +4037,10 @@
   }else if( pOp->p4type==P4_INT32 ){
     nField = pOp->p4.i;
   }
+#ifdef LUMO_EXTENSIONS
+  /* we make space for an extra column where we add our stuff */
+  nField++;
+#endif
   assert( pOp->p1>=0 );
   assert( nField>=0 );
   testcase( nField==0 );  /* Table with INTEGER PRIMARY KEY and nothing else */
@@ -3883,7 +4087,12 @@
   assert( pOrig );
   assert( pOrig->pBtx!=0 );  /* Only ephemeral cursors can be duplicated */
 
+#ifdef LUMO_EXTENSIONS
+  /* we make space for an extra column where we add our stuff */
+  pCx = allocateCursor(p, pOp->p1, pOrig->nField+1, -1, CURTYPE_BTREE);
+#else
   pCx = allocateCursor(p, pOp->p1, pOrig->nField, -1, CURTYPE_BTREE);
+#endif
   if( pCx==0 ) goto no_mem;
   pCx->nullRow = 1;
   pCx->isEphemeral = 1;
@@ -5834,6 +6043,53 @@
   assert( pC->isTable==0 );
   rc = ExpandBlob(pIn2);
   if( rc ) goto abort_due_to_error;
+#ifdef LUMO_EXTENSIONS
+  {
+    /* if we've inserted an extra value, it'll now be where sqlite
+    ** expects to see the rowid; also, OP_IdxDelete expects the index
+    ** key to be exactly columns, rowid, so it won't work if there
+    ** is an extra hidden column; we remove it again but will do
+    ** something with it in a future version */
+    unsigned char * zHdr = pIn2->z;
+    int hPtr, dPtr, hRowid, hLumo, nHdr, dRowid, dLumo, tRowid, tLumo, lRowid, lLumo;
+    int lHdr;
+    hRowid = -1;
+    hLumo = -1;
+    dRowid = 0;
+    dLumo = 0;
+    tRowid = 0;
+    tLumo = 0;
+    lRowid = 0;
+    lLumo = 0;
+    lHdr = hPtr = getVarint32(zHdr, nHdr);
+    dPtr = nHdr;
+    while (hPtr < nHdr) {
+      hRowid = hLumo;
+      dRowid = dLumo;
+      tRowid = tLumo;
+      lRowid = lLumo;
+      hLumo = hPtr;
+      dLumo = dPtr;
+      hPtr += getVarint32(&zHdr[hPtr], tLumo);
+      lLumo = sqlite3VdbeSerialTypeLen(tLumo);
+      dPtr += lLumo;
+    }
+    if (hRowid >= 0 && tLumo >= 28 && (tLumo & 1) == 0 &&
+        memcmp(&zHdr[dLumo], LUMO_EXTENSION_MAGIC, 4) == 0)
+    {
+      /* there is a Lumo blob at the end */
+      int lNew;
+      lNew = putVarint32(zHdr, hLumo);
+      if (lNew < lHdr) {
+	memmove(&zHdr[lNew], &zHdr[lHdr], hLumo - lHdr);
+	hLumo += lNew - lHdr;
+      }
+      if (dLumo > nHdr)
+	memmove(&zHdr[hLumo], &zHdr[nHdr], dLumo - nHdr);
+      pIn2->n = hLumo + dLumo - nHdr;
+    }
+  }
+#endif
   x.nKey = pIn2->n;
   x.pKey = pIn2->z;
   x.aMem = aMem + pOp->p3;
