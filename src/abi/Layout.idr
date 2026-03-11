-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Memory layout specifications for Skein.jl FFI types.
|||
||| Defines the C-compatible struct layouts that the Zig FFI
||| implementation must adhere to. Dependent types ensure
||| layout correctness at compile time.
module Layout

import Types

%default total

||| C struct layout for a Gauss code passed across FFI boundary.
|||
||| ```c
||| typedef struct {
|||     uint32_t length;       // number of entries
|||     int32_t  crossings[];  // flexible array member
||| } skein_gauss_code_t;
||| ```
public export
record GaussCodeLayout where
  constructor MkGaussCodeLayout
  headerSize : Nat   -- size of length field (4 bytes)
  elementSize : Nat  -- size of each crossing entry (4 bytes)

||| The canonical layout: 4-byte header + 4-byte elements.
public export
canonicalLayout : GaussCodeLayout
canonicalLayout = MkGaussCodeLayout 4 4

||| Total byte size of a serialised Gauss code.
public export
totalSize : GaussCodeLayout -> Nat -> Nat
totalSize layout n = layout.headerSize + n * layout.elementSize

||| C struct layout for a knot query result.
|||
||| ```c
||| typedef struct {
|||     char     id[36];       // UUID
|||     char    *name;         // null-terminated
|||     int32_t  crossing_num; // crossing number
|||     int32_t  writhe;       // writhe
|||     char     hash[64];     // SHA-256 hex
||| } skein_knot_record_t;
||| ```
public export
record KnotRecordLayout where
  constructor MkKnotRecordLayout
  idSize : Nat       -- 36 bytes (UUID)
  namePtr : Nat      -- 8 bytes (pointer)
  crossingSize : Nat -- 4 bytes
  writheSize : Nat   -- 4 bytes
  hashSize : Nat     -- 64 bytes

||| The canonical knot record layout.
public export
canonicalRecordLayout : KnotRecordLayout
canonicalRecordLayout = MkKnotRecordLayout 36 8 4 4 64

||| Proof: total record size is well-defined.
public export
recordSize : KnotRecordLayout -> Nat
recordSize l = l.idSize + l.namePtr + l.crossingSize + l.writheSize + l.hashSize
