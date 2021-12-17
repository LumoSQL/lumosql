%%%
title = "Lumions: Portable, Secure, Unique, Updatable Data Primitives"
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

date = 2021-12-17T00:00:00Z

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
  email = "me@rubdo.be"

%%%

.# Abstract

This memo defines Lumions, a new kind of secure, unique data encapsulation primitive designed
for reliable, fine-grained movements of data between Internet-of-Things devices and 
multiple clouds. Lumions are also compatible with decentralised, distributed key management.

{mainmatter}

# Introduction

A Lumion is a one-dimensional array of data which is at minimum encrypted,
signed, checksummed, versioned, binary and universally unique with
discriminated access control, stored in network byte order.

In addition a Lumion may optionally be encrypted with a public/private key
system such that it can be updated by anyone possessing the correct key and
conformant software. This is Role-based Access Control (RBAC.) There are many
useful properties possessed by a Lumion explained in this memo.

A Lumion has keys implemented as public/private key pairs, and there can be any
(or no) key management authorities. Lumion users can choose to implement any
key management authority they choose. 

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
length less than 2^64 bytes

Payload Metadata: A checksum or version number specific to the Payload Data

Metadata: all data to do with access control, checksums and version
numbers for the Lumion as a whole, the UUID and more.

Access Control: The RBAC system implemented for Lumions, where valid users
are anyone who has a valid key. A valid key can only be used to sign a Lumion
if it is used for the correct purpose. For example, a read-only key cannot
produce a valid signature for a Lumion after writing to it.

Key Management Authority: a scheme selected by users to manage their Lumion
keys. This could be any system at all, from a plain text file on a server on
the internet to a Kerberos server. In the case of an embedded database library,
the key management authority will typically be either individual app on the
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

Both payload and metadata can be versioned with 64-bit version numbers.

## Optional: Access Control

This is a simple version of Role-based Access Control, with a list of 
valid keys stored in the Lumion Metadata.

## Optional: Checksums

A signature is already a form of a checksum. But in addition to the overall
Lumion checksum, a checksum is also used as part of the Access Control system.

# Properties of Lumions

Non-repudiable: The original key authority might be unreliable and transient
(because the phone got swallowed by a diprodoton) but a cluster of rows can
definitely be identified as having the same original source.

Self-contained security: no external key authority or integrity authority is
needed. Discriminated access control is provided solely from the information
within the Lumion.

Integrity: Corruption can always be detected.

Recognisable: A Lumion will always be recognisable as a Lumion from its name-based UUID.

Identifiable: A Lumion will always be unique among Lumions due to the one-way hash part of its UUID.

Portable: Can be copied across architectures, networks, storage systems without
losing or gaining any information. 

Time-travelling: This is because Lumions have a version number, so they can be
viewed as snapshots in time. They can also be viewed as time sequence data, if
the Lumion Generator intended to produce that.

Standardised: A Lumion can be operated on by any software that complies with this RFC.

Secure: If there is no valid key available (because the original Lumion Generator did
not store the key correctly, or the key was lost, etc) then a Lumion cannot be decrypted.

Globally distributed namespace: Just by having a Lumion UUID, that means every
Lumion is part of an ad hoc global storage system.

# Description of Lumions

Any of the three types of data may be in plain text, although they usually will
not be because much of the value of a Lumion is in its encrypted properties. A plain
text Lumion is still signed, and still has a universally unique ID.

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

XXXX

# Lumion Data Format

A Lumion is laid out like this:

  +--------+-----------------+------------------------+---------+
  |  UUID  | Metadata Block  | Payload Metadata Block | Payload |
  +--------+-----------------+------------------------+---------+

These fields are always present in a Lumion.

The UUID is described in the section "Lumion UUID Format", and is always 256 bits wide.

The Metadata Block is laid out like this:

  +-----------+--------------+----------------------+----------------+
  | Signature | Feature List | Payload Metadata Off | Other Metadata |
  +-----------+--------------+----------------------+----------------+

The Lumion Signature is a digital signature from one of those allowed in this RFC. See the section 
"Lumion Ciphers, Signatures and Hashes".

The Lumion Feature list is a 32-bit bitmask with values as in the following table:
    XXXXXX

Payload Metadata Offset is a 64-bit integer.

Other Metadata covers RBAC and other Metadata features:
    * Next and Last pointers, in the case where the Lumion Version Count is non-zero. The pointers are Lumion UUIDs.
    * List of valid Lumion Access Keys
    * XXXXXX

The Payload Metadata Block is laid out like this:

  +----------------+-----------------------+------------------------+
  | Payload Length | Payload Version Count | Other Payload Metadata | 
  +----------------+-----------------------+------------------------+

Payload Length is a 64-bit integer.

Payload Version Count is a 64-bit integer.

Other Payload Metadata relates to RBAC, such as Last Edited By, which
is a keyid listed in the Metadata Block. XXXXX

# Lumion Data Formal Specification

A Lumion has the following ABNF [@RFC5234] definition:

(this is not valid Lumion ABNF, we're still at the high-level sketch stage. But
it is quite atmospheric, don't you think?)

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
[@RFC4122]. RFC4122 UUIDs cannot be used because of the constrained
environments many Lumion-using applications are deployed in.

XXXXXX

# List of Lumion Ciphers, Signatures and Hashes

XXXXXX

# Example Use Cases

## Data Tracking and Portability

XXXXXX

## Time Travelling Data for Snapshotting

This is about using the versioning information embedded within Lumions to come
up with time series data. It might in fact be more about ordinal data, because
wallclock time is not part of the Lumion definition in this RFC. 

Each Lumion can have a "next" and "last" pointer, as well as a version number.
The next and last are simply Lumion UUIDs.

## Non-Fungible Token (NFT) Applications

* Compatible with existing NFT registries
* First-ever updatable NFTs

XXXXXX

## Online Backups

If we can assemble time-ordered lists of Lumions, then this is also a
way of doing backups. Ad-hoc backups will be possible so long as the
smallest unit is a Lumion and only whole Lumions are transferred. The
UUID, versioning and ordinal information in a Lumion means that a
consistent backup can always be calculated assuming a reasonable
percentage of Lumions are present.

# Performance Considerations

XXXXXX

# Security Considerations

While a valid umion is entirely self-contained from a security point of view, it is 
important to remember that Lumions by design cannot support anonymity. Transparency
and traceability is vital to the Lumion concept, which is why it has a UUID. 

# Related Work

XXXXX

# IANA Considerations

This memo calls for IANA to register a new MIME content-type application/pidf+xml, per [MIME].

The registration template for this is below. 

##  Content-type registration for 'application/lumion'

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

<reference anchor='DSM-IV' target='http://www.psychiatryonline.com/resourceTOC.aspx?resourceID=1'>
  <front>
   <title>Diagnostic and Statistical Manual of Mental Disorders (DSM)</title>
   <author></author>
   <date></date>
  </front>
</reference>
