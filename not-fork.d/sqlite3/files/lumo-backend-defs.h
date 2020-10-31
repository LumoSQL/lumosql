/* when building unmodified sqlite3 this file does nothing apart to make
 * sure the LUMO_BACKEND macros are undefined; the backend will replace
 * this file with its own */

#undef LUMO_BACKEND_NAME
#undef LUMO_BACKEND_VERSION
#undef LUMO_BACKEND_COMMIT_ID

