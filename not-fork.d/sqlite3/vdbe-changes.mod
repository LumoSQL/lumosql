# update vdbe.c to add new information in stored rows; currently
# used to add rowsum

method = patch
--
--- sqlite3/src/vdbe.c-orig	2021-02-11 09:36:38.605044099 +0100
+++ sqlite3/src/vdbe.c	2021-02-20 11:53:38.937658846 +0100
@@ -21,6 +21,8 @@
 #include "sqliteInt.h"
 #include "vdbeInt.h"
 
+#include "lumo-vdbeInt.h"
+
 /*
 ** Invoke this macro on memory cells just prior to changing the
 ** value of the cell.  This macro verifies that shallow copies are
@@ -2609,6 +2611,9 @@
   u64 offset64;      /* 64-bit offset */
   u32 t;             /* A type code from the record header */
   Mem *pReg;         /* PseudoTable input register */
+#ifdef LUMO_EXTENSIONS
+  u32 iLumoExt;      /* remember if we've looked for a Lumo extension */
+#endif
 
   assert( pOp->p1>=0 && pOp->p1<p->nCursor );
   pC = p->apCsr[pOp->p1];
@@ -2631,6 +2636,9 @@
   assert( pC->eCurType!=CURTYPE_PSEUDO || pC->nullRow );
   assert( pC->eCurType!=CURTYPE_SORTER );
 
+#ifdef LUMO_EXTENSIONS
+  iLumoExt = 0;
+#endif
   if( pC->cacheStatus!=p->cacheCtr ){                /*OPTIMIZATION-IF-FALSE*/
     if( pC->nullRow ){
       if( pC->eCurType==CURTYPE_PSEUDO ){
@@ -2658,6 +2666,11 @@
       if( pC->payloadSize > (u32)db->aLimit[SQLITE_LIMIT_LENGTH] ){
         goto too_big;
       }
+#ifdef LUMO_EXTENSIONS
+      /* we will be looking for the extra "Lumo extension" blob */
+      iLumoExt = p2 + 1;
+      p2 = pC->nField - 1;
+#endif
     }
     pC->cacheStatus = p->cacheCtr;
     pC->iHdrOffset = getVarint32(pC->aRow, aOffset[0]);
@@ -2705,6 +2718,12 @@
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
@@ -2771,6 +2790,17 @@
     ** columns.  So the result will be either the default value or a NULL.
     */
     if( pC->nHdrParsed<=p2 ){
+#ifdef LUMO_EXTENSIONS
+      if (iLumoExt > 0){
+	/* we tried to get the Lumo column, and it wasn't there */
+#ifdef LUMO_ROWSUM
+	if (lumo_extension_need_rowsum) goto op_column_corrupt;
+#endif
+	p2 = iLumoExt-1;
+	iLumoExt = 0;
+	goto op_column_lumo_repeat;
+      }
+#endif
       if( pOp->p4type==P4_MEM ){
         sqlite3VdbeMemShallowCopy(pDest, pOp->p4.pMem, MEM_Static);
       }else{
@@ -2821,10 +2851,17 @@
   }else{
     pDest->enc = encoding;
     /* This branch happens only when content is on overflow pages */
+#ifdef LUMO_EXTENSIONS
+    if((((pOp->p5 & (OPFLAG_LENGTHARG|OPFLAG_TYPEOFARG))!=0
+          && ((t>=12 && (t&1)==0) || (pOp->p5 & OPFLAG_TYPEOFARG)!=0))
+     || (len = sqlite3VdbeSerialTypeLen(t))==0) && iLumoExt==0
+    ){
+#else
     if( ((pOp->p5 & (OPFLAG_LENGTHARG|OPFLAG_TYPEOFARG))!=0
           && ((t>=12 && (t&1)==0) || (pOp->p5 & OPFLAG_TYPEOFARG)!=0))
      || (len = sqlite3VdbeSerialTypeLen(t))==0
     ){
+#endif
       /* Content is irrelevant for
       **    1. the typeof() function,
       **    2. the length(X) function if X is a blob, and
@@ -2847,6 +2884,88 @@
     }
   }
 
+#ifdef LUMO_EXTENSIONS
+  if (iLumoExt > 0){
+    /* there was an extra hidden column, we need to check if it's
+    ** ours and process it if so; in any case we then need to repeat
+    ** the opcode to get the correct column; our column must be at
+    ** least 7 bytes to be useful so we check that t >= 12+7*2 or 26 */
+    if (t>=26 && (t%2)==0 && memcmp(pDest->z, lumo_extension_magic, 4)==0){
+      int ptr = 4;
+#ifdef LUMO_ROWSUM
+      int rowsum_found = 0;
+#endif
+      while (ptr < len) {
+	unsigned int xtype, xsubtype, xlen;
+	if (len - ptr < 3) goto op_column_corrupt;
+	xtype = (unsigned char)pDest->z[ptr++];
+	xsubtype = (unsigned char)pDest->z[ptr++];
+	xlen = (unsigned char)pDest->z[ptr++];
+	if (len - ptr < xlen) goto op_column_corrupt;
+#ifdef LUMO_ROWSUM
+	if (xtype == LUMO_ROWSUM_TYPE) {
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
+      if (lumo_extension_need_rowsum && !rowsum_found) goto op_column_corrupt;
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
@@ -2952,6 +3071,10 @@
   u32 len;               /* Length of a field */
   u8 *zHdr;              /* Where to write next byte of the header */
   u8 *zPayload;          /* Where to write next byte of the payload */
+#ifdef LUMO_EXTENSIONS
+  int iLumoExt;          /* are we adding LumoSQL extensions? */
+  Mem pLumoExt;          /* temp blob containing LumoSQL extensions */
+#endif
 
   /* Assuming the record contains N fields, the record format looks
   ** like this:
@@ -3002,7 +3125,20 @@
     }while( zAffinity[0] );
   }
 
+#ifdef LUMO_EXTENSIONS
+  /* see if we'll be adding any extensions */
+  iLumoExt = 0;
+#ifdef LUMO_ROWSUM
+  if (lumo_rowsum_algorithm < LUMO_ROWSUM_N_ALGORITHMS) iLumoExt = 1;
+#endif
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
@@ -3014,6 +3150,9 @@
       nField--;
     }
   }
+#ifdef LUMO_EXTENSIONS
+  }
+#endif
 #endif
 
   /* Loop through the elements that will make up the record to figure
@@ -3136,6 +3275,22 @@
     if( pRec==pData0 ) break;
     pRec--;
   }while(1);
+#ifdef LUMO_EXTENSIONS
+  if (iLumoExt > 0) {
+    pLumoExt.n = 4;
+#ifdef LUMO_ROWSUM
+    if (lumo_rowsum_algorithm < LUMO_ROWSUM_N_ALGORITHMS) {
+      /* add space for the rowsum */
+      pLumoExt.n += 3 + lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
+    }
+#endif
+    if (pLumoExt.n > 4) {
+      pLumoExt.uTemp = (pLumoExt.n*2) + 12;
+      nData += pLumoExt.n;
+      nHdr += sqlite3VarintLen(pLumoExt.uTemp);
+    }
+  }
+#endif
 
   /* EVIDENCE-OF: R-22564-11647 The header begins with a single varint
   ** which determines the total number of bytes in the header. The varint
@@ -3196,6 +3351,32 @@
     ** immediately follow the header. */
     zPayload += sqlite3VdbeSerialPut(zPayload, pRec, serial_type); /* content */
   }while( (++pRec)<=pLast );
+#ifdef LUMO_EXTENSIONS
+  if (iLumoExt > 0) {
+    /* we should be able to write directly to the record but for now this will do */
+    unsigned char zLumoExt[pLumoExt.n], *zLumoPtr = zLumoExt;
+    /* put the column type first, as it may be used in the rowsum calculations */
+    zHdr += putVarint32(zHdr, pLumoExt.uTemp);
+    memcpy(zLumoExt, lumo_extension_magic, 4);
+    zLumoPtr += 4;
+#ifdef LUMO_ROWSUM
+    if (lumo_rowsum_algorithm < LUMO_ROWSUM_N_ALGORITHMS) {
+      /* add one extra BLOB with the rowsum */
+      *zLumoPtr++ = LUMO_ROWSUM_TYPE;
+      *zLumoPtr++ = lumo_rowsum_algorithm;
+      *zLumoPtr++ = lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
+      if (lumo_rowsum_algorithms[lumo_rowsum_algorithm].length > 0){
+	  lumo_rowsum_algorithms[lumo_rowsum_algorithm].generate
+	    (zLumoPtr, pOut->z, zPayload - (u8*)pOut->z);
+      }
+      zLumoPtr += lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
+    }
+#endif
+    assert(pLumoExt.n == zLumoPtr-zLumoExt);
+    pLumoExt.z = zLumoExt;
+    zPayload += sqlite3VdbeSerialPut(zPayload, &pLumoExt, pLumoExt.uTemp);
+  }
+#endif
   assert( nHdr==(int)(zHdr - (u8*)pOut->z) );
   assert( nByte==(int)(zPayload - (u8*)pOut->z) );
 
@@ -3837,6 +4018,10 @@
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
@@ -3883,7 +4068,12 @@
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
