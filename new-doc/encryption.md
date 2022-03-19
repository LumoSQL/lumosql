
# Encryption

1. LumoSQL open source encryption to replace [SQLCipher](https://www.zetetic.net/sqlcipher/)/[SEE](https://www.hwaci.com/sw/sqlite/see.html). The authors of SQLite produce the closed-source SQLite Encryption Extension (SEE). There are several open source solutions to replace SEE, the most popular of which is SQLCipher, which has an open source version with limited functionality. Closed source encryption is not acceptable for privacy or security in the 21st century. The first version of this will be exposing the page-level crypto in LMDBv1.0 via the new LumoSQL crypto API, with metadata handled by the new pragmas.

LumoSQL will also support LMDBv1.0 page-level encryption.
