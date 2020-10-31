/* extra functions needed by the LumoSQL LMDB backend, at least as a
 * temporary workaround until things are rewritten so they don't need
 * access to LMDB's internals */

/* given a transaction, return its parent */
MDB_txn * lumo_mdb_txn_parent(MDB_txn *txn) {
    return txn->mt_parent;
}

/* given a cursor, check if we are positioned past end of a page */
int lumo_mdb_cursor_past_end(MDB_cursor * mc) {
    return mc->mc_ki[mc->mc_top] >= NUMKEYS(mc->mc_pg[mc->mc_top]);
}

