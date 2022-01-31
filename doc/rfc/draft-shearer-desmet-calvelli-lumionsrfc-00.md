%%%
title = "Lumions: Portable, Private, Secure, Unique, Updatable Data Primitives"
abbrev = "lumionsrfc"
updates = []
ipr= "trust200902"
area = "Internet"
workgroup = ""
keyword = ["Data Format", "UUID", "Cryptography"]

[seriesInfo]
status = "informational"
name = "Internet-Draft"
value = "draft-shearer-desmet-calvelli-lumionsrfc-00"
stream = "IETF"

date = 2022-01-29T00:00:00Z

[[author]]
initials="D."
surname="Shearer"
fullname="Dan Shearer"
organization = "LumoSQL"
  [author.address]
  email = "dan@shearer.org"
  emails = ["dan@lumosql.org"] # for when you need to speficy more than 1 email address

[[author]]
initials="R."
surname="De Smet"
fullname="Ruben De Smet"
organization = "LumoSQL"
  [author.address]
  email = "me@rubdos.be"

[[author]]
initials="C."
surname="Calvelli"
fullname="Claudio Calvelli"
organization = "LumoSQL"
  [author.address]
  email = "webmaster@lumosql.org"


%%%

.# Abstract

This memo defines Lumions, a new kind of secure, unique data encapsulation
primitive designed for reliable, fine-grained storage and movements of arbitary
data between arbitary storage mechanisms and across arbitary networks. Lumions
are also compatible with decentralised, distributed key management. To
illustrate the main use case, Lumions would not be needed if JSON had
sophisticated privacy and encryption features, with a single unique JSON
namespace and a standard way of referring to other JSON objects.

{mainmatter}

# Introduction

A Lumion is a one-dimensional array of data signed with a public key
which MUST contain a checksum, a version number and a universally unique
identifier. A Lumion is binary data and MUST be stored in network byte order.

In addition a Lumion MAY be encrypted with one or more schemes defined in
this standard which together implement various forms of Role-based Access Control.
These schemes offer different levels of access depending on the token supplied. 
After being updated with a valid write access, a Lumion will have an updated
checksum. The updated signature will be valid in all situations where the 
previous version of the signature was valid.

A Lumion has keys implemented as public/private key pairs, and there can be any
(or no) key management authorities. The simplest case of a key management
authority is where a program on a device creates a Lumion, making that program
on that device the issuing authority. That program may subsequently be
uninstalled, or the private key data it created be deleted or lost, making it a
very transient key manaagement authority.

Distinct from any other key management scheme users may implement, there is one
specific key management authority scheme described in this RFC which stores
lists of Lumion keys in an application of a public blockchain. This gives
Lumions the optional ability to have a decentralised, globally distributed key authority.

Situations where Lumion properties are helpful include internet-connected
devices such as mobile phones; transparency requirements related to privacy;
and data portability requirements between clouds.

A new media type "application/lumion" is defined as a helpful hint for
high-level applications.

## Terminology

The keywords **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**,
**SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL**, when they appear in this document, are
 to be interpreted as described in [@RFC2119].

# Definitions

Lumion Generator: software that can produce a Lumion for any supplied raw
data. A Generator may be standalone or built into eg a database. A Lumion Generator
must also be able to read Lumions, and is a full implementation of this RFC.

Lumion Reader: is software that can access at least some data inside a Lumion,
provided it has a key to do so, where a key is required by a particular Lumion.
A Lumion Reader implements some of the verification and reading functionality in this RFC.

Lumion Recogniser: is very simple software, perhaps a function or a script,
that can detect the unique naming convention used by Lumions as defined in this
RFC, and extract the universally unique identifier used by a particular Lumion.
A Recogniser can extract Lumions from non-Lumion data, and search for a
particular Lumion. A Recogniser will not be able to reliably determine whether
any given Lumion is valid or not.

Payload Data: an arbitary binary string within a Lumion of arbitary
length less than 2^64 bytes.

Payload Metadata: A checksum or version number specific to the Payload Data.

Metadata: all data to do with access control, checksums and version
numbers for the Lumion as a whole, the UUID and more.

Access Control: The RBAC system implemented for Lumions, where valid users
are anyone who has a valid key. A valid key can only be used to sign a Lumion
if it is used for the correct purpose. For example, a read-only key cannot
produce a valid signature for a Lumion after writing to it.

Key Management Authority: a scheme selected by users to manage their Lumion
keys. This could be any system at all, from a plain text file on a server on
the internet to a Kerberos server. In the case of an embedded database library,
the key management authority will often be either an individual app on the
device (eg a banking app) or the device's platform-wide key management authority (eg the 
identity systems built into many versions of Android, and Apple phones.)

Lumion Registry: One particular key management authority defined in this RFC
for storing Lumion keys in a public blockchain.

# Feature Levels

## Mandatory Minimum Requirements

A Lumion will always:

* Have a standardised Lumion UUID
* Be signed

We would not expect plain text Lumions to be common, but they are valid. A
plain text Lumion with a signature is no different in principle to a signed
plain text MIME email. So long as the signature is valid we know that the data
has not been changed.

There is no requirement for a key management authority, even on a device,
because it is also valid (and may sometimes be useful) for a Lumion Generator
to discard all knowledge of keys once it has generated a Lumion. 

## Optional: Key Authority

There are multiple ways of implementing a Key Authority. They are all explained
in the section "Lumion Key Management".

## Optional: Versioning

Both payload and metadata can be versioned with 64-bit version numbers. These versions
are internal versions, incremented each time the Lumion is updated and re-signed.

## Optional: Access Control

This is a simple version of Role-based Access Control, with a list of 
valid keys stored in the Lumion Metadata.

## Optional: Checksums

A signature is already a form of a checksum. But in addition to this overall
Lumion checksum, a checksum is also used as part of the Access Control system.

# Properties of Lumions

Standardised: A Lumion can be operated on by any software that complies with this RFC.

Integrity: Corruption can always be detected, at multiple levels (overall, or
in the payload, or in the metadata).

Uniquely Recognisable Among All Data: A Lumion will always be recognisable as a
Lumion from its name-based UUID.

Uniquely Identifiable Among All Lumions: A Lumion will always be unique among
all Lumions due to the one-way hash part of its UUID.

Secure: If there is no valid key available (because the original Lumion Generator did
not store the key correctly, or the key was lost, etc) then a Lumion cannot be decrypted.

Portable: Can be copied across architectures, networks, storage systems without
losing or gaining any information.

Non-repudiable: The original key authority might be unreliable and transient
(ifor example, because the originating phone got swallowed by a diprodoton) but
any Lumions generated on that phone and intended to have a common local
authority will always be identifiable as having the same original source.

Self-contained security: no external key authority or integrity authority is
needed. Discriminated access control is provided solely from the information
within the Lumion.

Globally distributed namespace: Just by having a Lumion UUID, that means every
Lumion is part of an ad hoc global storage system.

Sequenced Internally: Since Lumions have an internal version number, anyone with 
copies of all version of a Lumion can view them as a time-sequenced stream. (It is 
possible for a Lumion to keep all previous versions of its payload within itself, 
although whether this is scaleable or feasible is highly application-dependent.)

Sequenced Externally: Lumions have fields of Left, Right, Below and Above,
sized to contain a Lumion UUID. The contents of these fields can be updated at
any time, meaning that Lumions can optionally and frequently will form part of
a logical structure such as a Merkle tree, thus creating a sequence that can be
navigated forward/back/up/down, depending on the structure. This sequence data
can also be interpreted as time sequence data, if the Lumion Generator intended
to produce that. Timestamps are not required to be assigned by the Lumion
Generator for time sequence data, because if a sequence of Lumions is ordered
then a Lumion Reader can interpret that according to any temporal origin and
offset it chooses.

Time Travelling: Sequences of either the internal or external versioning can be
interpreted as snapshotted point-in-time state information. Such information
can always be played back to reconstruct a view of the world at any point in
time. Even where there are no timestamps, the relative versions can still be
replayed in either direction.

# Description of Lumions

Any of the three types of data may be in plain text, although they usually will
not be plain text because much of the value of a Lumion is in its encrypted
properties. A plain text Lumion is still signed, and still has a universally
unique ID.

Data in a Lumion may be automatically generated by one of these kinds of processes:

* cryptographic checksums
* symmetric encryption
* public key encryption
* public key signing
* one-way hashes appended to a name-based uniqueness algorithm

For each of these there are multiple possible ciphers and implementation techniques.

Portability requires that data is stored in Network Byte Order.

# Lumions and Key Management

There are four different levels of scope that involve key management:

1. The system within a Lumion, ie implementing access control so that a validly-signed
   Lumoion remains validly signed even after it has been updated by someone with a
   valid write key, and only allows reads by someone with a valid read or read+write key.
   All of that is about how the Lumion is maintained as a data artefact. These valid keys
   could have been generated by anyone anywhere, and stored anywhere. The Lumion neither
   knows nor cares. But it still has to do some degree of key management because it has 
   list of keys and their access rights inside it.

2. How a Lumion Generator creates the Lumion in the first places and the list of keys inside
   the Lumion. There will also be the other half of keys to be stored somewhere (presumably
   inside a LumoSQL database, in a Lumion.) That incldues symmetric keys, and signatures.
   So this too is key management. New users, the extent to which revocation is supported, etc.
   I expect this will be mostly internal to LumoSQL, driven by the SQL interface (?)

3. Key management via an Authority, any authority. A LumoSQL user is building
   an app, and might choose to make LDAP or Active Directory or Kerberos the
   Authority, or an Oracle database, etc.  LumoSQL doesn't know or care, only that
   the keys are in the right places at the right time.  Will this be done through
   the C API, or SQL only?

4. Key management via the Lumion Registry, which is the only (and totally optional) scheme
   that LumoSQL is configured to support. This is the scheme I described where Lumions are 
   stored in a blockchain, specifically Ethereum, as an implementation of a standard Ethereum
   smart contract. This is where we could have many billions of rows with their UUID registered
   and also the users with access rights registered there too. See the later section headed "Lumion Registry".

# Goals and Constraints

XXXX THIS SECTION DOES NOT EXIST YET XXXX

# Lumion Data Format

A Lumion is laid out like this:

+--------+-----------------+----------------------+---------+
|  UUID  | Metadata Block  | Payload Metad. Block | Payload |
+--------+-----------------+----------------------+---------+

These fields are always present in a Lumion.

The UUID is described in the section "Lumion UUID Format", and is always 256 bits wide.

The Metadata Block is laid out like this:

+-----------+----------+--------------------+--------------+
| Signature | Features | Payload Metad. Off | Other Metad. |
+-----------+----------+--------------------+--------------+

The Lumion Signature is a digital signature from one of those allowed in this RFC. See the section 
"Lumion Ciphers, Signatures and Hashes".

The Lumion Feature list is a 32-bit bitmask with values as in the following table:

    XXXXX MORE GOES HERE XXXXX

Payload Metadata Offset is a 64-bit integer.

Other Metadata contains all RBAC metadata, and some non-RBAC Metadata:

* Left, Right, Below and Above pointers. These pointers are Lumion
  UUIDs, meaning that trees, lists and other structures can be
  implemented with Lumions. At least one of these fields MUST be
  non-zero if the External Lumion Version Count is non-zero.
* List of valid Lumion Access Keys
* XXXXX MORE GOES HERE XXXXX

The Payload Metadata Block is laid out like this:

+----------------+---------------------+----------------------+
| Payload Length | Payload Vers. Count | Other Payload Metad. |
+----------------+---------------------+----------------------+

Payload Length is a 64-bit integer.

Payload Version Count is a 64-bit integer.

Other Payload Metadata relates to RBAC, such as Last Edited By, which
is a keyid listed in the Metadata Block. XXXXX

# Lumion Data Formal Specification

A Lumion has the following ABNF [@RFC5234] definition:

(this is NOT valid Lumion ABNF because we're still at the high-level sketch
stage. But it is quite atmospheric, don't you think? A bit like mood music.)

      SYSLOG-MSG      = HEADER SP STRUCTURED-DATA [SP MSG]

      HEADER          = PRI VERSION SP TIMESTAMP SP HOSTNAME
                        SP APP-NAME SP PROCID SP MSGID
      PRI             = "<" PRIVAL ">"
      PRIVAL          = 1*3DIGIT ; range 0 .. 191
      VERSION         = NONZERO-DIGIT 0*2DIGIT
      HOSTNAME        = NILVALUE / 1*255PRINTUSASCII

      APP-NAME        = NILVALUE / 1*48PRINTUSASCII
      PROCID          = NILVALUE / 1*128PRINTUSASCII
      MSGID           = NILVALUE / 1*32PRINTUSASCII

      TIMESTAMP       = NILVALUE / FULL-DATE "T" FULL-TIME
      FULL-DATE       = DATE-FULLYEAR "-" DATE-MONTH "-" DATE-MDAY
      DATE-FULLYEAR   = 4DIGIT
      DATE-MONTH      = 2DIGIT  ; 01-12
      DATE-MDAY       = 2DIGIT  ; 01-28, 01-29, 01-30, 01-31 based on
                                ; month/year
      FULL-TIME       = PARTIAL-TIME TIME-OFFSET
      PARTIAL-TIME    = TIME-HOUR ":" TIME-MINUTE ":" TIME-SECOND
                        [TIME-SECFRAC]
      TIME-HOUR       = 2DIGIT  ; 00-23
      TIME-MINUTE     = 2DIGIT  ; 00-59
      TIME-SECOND     = 2DIGIT  ; 00-59
      TIME-SECFRAC    = "." 1*6DIGIT
      TIME-OFFSET     = "Z" / TIME-NUMOFFSET
      TIME-NUMOFFSET  = ("+" / "-") TIME-HOUR ":" TIME-MINUTE


      STRUCTURED-DATA = NILVALUE / 1*SD-ELEMENT
      SD-ELEMENT      = "[" SD-ID *(SP SD-PARAM) "]"
      SD-PARAM        = PARAM-NAME "=" %d34 PARAM-VALUE %d34
      SD-ID           = SD-NAME
      PARAM-NAME      = SD-NAME
      PARAM-VALUE     = UTF-8-STRING ; characters '"', '\' and
                                     ; ']' MUST be escaped.
      SD-NAME         = 1*32PRINTUSASCII
                        ; except '=', SP, ']', %d34 (")

      MSG             = MSG-ANY / MSG-UTF8
      MSG-ANY         = *OCTET ; not starting with BOM
      MSG-UTF8        = BOM UTF-8-STRING
      BOM             = %xEF.BB.BF

      UTF-8-STRING    = *OCTET ; UTF-8 string as specified in RFC 3629

      OCTET           = %d00-255
      SP              = %d32
      PRINTUSASCII    = %d33-126
      NONZERO-DIGIT   = %d49-57
      DIGIT           = %d48 / NONZERO-DIGIT
      NILVALUE        = "-"

# Lumion UUID Format

This is a combination of a name-based namespace and a robust hash, similar to
type 5 UUIDs in [@RFC4122]. 

RFC4122 UUIDs MUST NOT be used because of the constrained environments many
Lumion-using applications are deployed in and which therefore do not have
knowledge of namespaces that look like DNS or which imply a network even
exists. In addition RFC4122 does not include any hash more recent than SHA-1,
which is now deprecated.

XXXXX MORE GOES HERE XXXXX

# List of Lumion Ciphers, Signatures and Hashes

* SHA-3/SHA-256
* BLAKE3
* Curve 25519
* XXXXX MORE CIPHERS HERE XXXXX


# Example Use Cases

## Data Tracking and Portability

XXXXX EXPLAIN HERE - THIS IS AN EASY AND OBVIOUS ONE XXXXX

## Time Travelling Data for Snapshotting

This is about using the versioning information embedded within Lumions (either
internal or external) to come up with time series data. It might in fact be
more about ordinal data, because wallclock time is not part of the Lumion
definition in this RFC. A 

Each Lumion MUST have pointers called Left, Right, Below, Above, as well as an
external or internal version number.

## Non-Fungible Token (NFT) Applications

* Compatible with existing NFT registries
* First-ever updatable NFTs

XXXXX MORE GOES HERE XXXXX

## Online Backups

A time-ordered lists of Lumions is also a form of backups. Ad-hoc
backups will be possible so long as the smallest unit is a Lumion and
only whole Lumions are transferred. The UUID, versioning and ordinal
information optionally contained in a Lumion means that a consistent
backup can always be calculated assuming a reasonable percentage of
Lumions are present.

# Performance Considerations

XXXXXX

# Security Considerations

While a valid Lumion is entirely self-contained from a security point of view,
it is important to remember that Lumions do NOT provide any guarantee of anonymity.
Lumions MAY be used for this purpose despite the presence of a UUID if
the Lumion Generator is implemented in a very particular way (for example,
the Lumion Generator only ever produces a single Lumion before being deleted permanently.)
Transparency and traceability is vital to the Lumion concept, which is why it
has a UUID. For normal usage the UUID prevents Lumions providing anonymity.

# Related Work

XXXXX

# IANA Considerations

This memo calls for IANA to register a new MIME content-type application/pidf+xml, per [MIME].

The registration template for this is below. 

##  Content-type registration for 'apoplication/lumion'

   To: ietf-types@iana.org
   Subject: Registration of MIME media type application/lumion

   MIME media type name:  application

   MIME subtype name:     lumion

   Required parameters:   (none)
   Optional parameters:   (none)

   Encoding considerations: (none)
           
   Security considerations:

      This content type carries a payload with metadata, where the only
      information that can be deduced relates to the Lumion envelope.
      Everything else is encrypted. A Lumion thus is self-contained from
      a security point of view.

   Interoperability considerations:
      This content type provides a common format for transporting
      data in a secure and privacy-compliant manner.

   Published specification:
      (none)

   Applications which use this media type:
      Databases

   Additional information:
      Magic number(s): XXXX
      File extension(s): .lumion (optional)

   Person & email address to contact for further information:
      Dan Shearer
      EMail: dan@shearer.org

   Intended usage:
      Globally, at scale

   Author/Change controller:
      (none)

{backmatter}

