# update vdbe.c to add new information in stored rows; currently
# used to add rowsum

method = patch
--
--- sqlite3/src/vdbe.c-orig	2021-02-11 09:36:38.605044099 +0100
+++ sqlite3/src/vdbe.c	2021-02-16 17:57:02.093653696 +0100
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
+  u32 iLumoExt;      /* check if a Lumo extension may be present */
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
@@ -2658,6 +2666,10 @@
       if( pC->payloadSize > (u32)db->aLimit[SQLITE_LIMIT_LENGTH] ){
         goto too_big;
       }
+#ifdef LUMO_EXTENSIONS
+      iLumoExt = p2 + 1;
+      p2 = pC->nField - 1;
+#endif
     }
     pC->cacheStatus = p->cacheCtr;
     pC->iHdrOffset = getVarint32(pC->aRow, aOffset[0]);
@@ -2762,10 +2774,23 @@
       pC->nHdrParsed = i;
       pC->iHdrOffset = (u32)(zHdr - zData);
       if( pC->aRow==0 ) sqlite3VdbeMemRelease(&sMem);
+#ifdef LUMO_EXTENSIONS
+      /* t could now be our blob rather than the value it needs to be */
+      if (iLumoExt > 0) {
+	t = pC->aType[iLumoExt - 1];
+      }
+#endif
     }else{
       t = 0;
     }
 
+#ifdef LUMO_EXTENSIONS
+    /* if necessary, restore the value of p2 so the next check is correct */
+    if (iLumoExt > 0) {
+      p2 = iLumoExt - 1;
+    }
+#endif
+
     /* If after trying to extract new entries from the header, nHdrParsed is
     ** still not up to p2, that means that the record has fewer than p2
     ** columns.  So the result will be either the default value or a NULL.
@@ -2779,9 +2804,22 @@
       goto op_column_out;
     }
   }else{
+#ifdef LUMO_EXTENSIONS
+    /* if necessary, restore the value of p2 so the next check is correct */
+    if (iLumoExt > 0) {
+      p2 = iLumoExt - 1;
+    }
+#endif
     t = pC->aType[p2];
   }
 
+#ifdef LUMO_EXTENSIONS
+    /* check if we have a Lumo extension block */
+    if (iLumoExt > 0 && pC->nHdrParsed>pC->nField) {
+      // XXX
+    }
+#endif
+
   /* Extract the content for the p2+1-th column.  Control can only
   ** reach this point if aOffset[p2], aOffset[p2+1], and pC->aType[p2] are
   ** all valid.
@@ -2952,6 +2990,9 @@
   u32 len;               /* Length of a field */
   u8 *zHdr;              /* Where to write next byte of the header */
   u8 *zPayload;          /* Where to write next byte of the payload */
+#ifdef LUMO_EXTENSIONS
+  Mem pLumoExt;          /* temp blob containing LumoSQL extensions */
+#endif
 
   /* Assuming the record contains N fields, the record format looks
   ** like this:
@@ -3002,7 +3043,7 @@
     }while( zAffinity[0] );
   }
 
-#ifdef SQLITE_ENABLE_NULL_TRIM
+#if defined(SQLITE_ENABLE_NULL_TRIM) && ! defined(LUMO_ROWSUM)
   /* NULLs can be safely trimmed from the end of the record, as long as
   ** as the schema format is 2 or more and none of the omitted columns
   ** have a non-NULL default value.  Also, the record must be left with
@@ -3136,6 +3177,20 @@
     if( pRec==pData0 ) break;
     pRec--;
   }while(1);
+#ifdef LUMO_EXTENSIONS
+  pLumoExt.n = 4;
+#ifdef LUMO_ROWSUM
+  if (lumo_rowsum_algorithm < lumo_rowsum_n_algorithms) {
+    /* add space for the rowsum */
+    pLumoExt.n += 3 + lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
+  }
+#endif
+  if (pLumoExt.n > 4) {
+    pLumoExt.uTemp = (pLumoExt.n*2) + 12;
+    nData += pLumoExt.n;
+    nHdr += sqlite3VarintLen(pLumoExt.uTemp);
+  }
+#endif
 
   /* EVIDENCE-OF: R-22564-11647 The header begins with a single varint
   ** which determines the total number of bytes in the header. The varint
@@ -3196,6 +3251,28 @@
     ** immediately follow the header. */
     zPayload += sqlite3VdbeSerialPut(zPayload, pRec, serial_type); /* content */
   }while( (++pRec)<=pLast );
+#ifdef LUMO_EXTENSIONS
+  if (pLumoExt.n > 4) {
+    /* we should be able to write directly to the record but for now this will do */
+    unsigned char zLumoExt[pLumoExt.n], *zLumoPtr = zLumoExt;
+    memcpy(zLumoExt, lumo_extension_magic, 4);
+    zLumoPtr += 4;
+#ifdef LUMO_ROWSUM
+    if (lumo_rowsum_algorithm < lumo_rowsum_n_algorithms) {
+      /* add one extra BLOB with the rowsum */
+      *zLumoPtr++ = LUMO_ROWSUM_TYPE;
+      *zLumoPtr++ = lumo_rowsum_algorithm;
+      *zLumoPtr++ = lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
+      lumo_rowsum_algorithms[lumo_rowsum_algorithm].generate(zLumoPtr, pOut->z, zPayload - (u8*)pOut->z);
+      zLumoPtr += lumo_rowsum_algorithms[lumo_rowsum_algorithm].length;
+    }
+#endif
+    assert(pLumoExt.n == zLumoPtr-zLumoExt);
+    pLumoExt.z = zLumoExt;
+    zHdr += putVarint32(zHdr, pLumoExt.uTemp);
+    zPayload += sqlite3VdbeSerialPut(zPayload, &pLumoExt, pLumoExt.uTemp);
+  }
+#endif
   assert( nHdr==(int)(zHdr - (u8*)pOut->z) );
   assert( nByte==(int)(zPayload - (u8*)pOut->z) );
 
@@ -3837,6 +3914,10 @@
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
@@ -3883,7 +3964,12 @@
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
