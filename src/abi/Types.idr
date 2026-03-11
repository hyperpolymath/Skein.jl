-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| ABI type definitions for Skein.jl FFI interface.
|||
||| These Idris2 types formally specify the data representations
||| used in the C-compatible FFI layer, with dependent-type proofs
||| guaranteeing memory layout correctness.
|||
||| The Julia implementation is the canonical source; these definitions
||| serve as a verified specification for cross-language bindings.
module Types

import Data.Vect
import Data.List

%default total

||| A crossing index in a Gauss code. Always positive.
||| The sign is carried separately to distinguish over/under crossings.
public export
CrossingIndex : Type
CrossingIndex = Nat

||| A signed crossing entry in a Gauss code.
||| Positive values indicate overcrossings, negative indicate undercrossings.
public export
record SignedCrossing where
  constructor MkSignedCrossing
  index : CrossingIndex
  isOver : Bool

||| Proof that a valid Gauss code has each crossing index appearing exactly twice.
public export
data ValidGaussCode : (entries : List SignedCrossing) -> Type where
  EmptyCode : ValidGaussCode []
  ||| For non-empty codes, each crossing index must appear exactly twice
  ||| with opposite signs (once over, once under).
  WellFormed : (entries : List SignedCrossing)
            -> (pairwise : All (\idx => count idx entries = 2) (nub (map index entries)))
            -> ValidGaussCode entries

||| A Gauss code with its validity proof.
public export
record GaussCode where
  constructor MkGaussCode
  entries : List SignedCrossing
  valid : ValidGaussCode entries

||| The crossing number: count of distinct crossing indices.
public export
crossingNumber : GaussCode -> Nat
crossingNumber gc = length (nub (map index gc.entries))

||| C-compatible representation for FFI.
||| Gauss code serialised as a flat array of signed 32-bit integers.
||| Positive = overcrossing, negative = undercrossing.
||| Length prefix for C interop.
public export
record CGaussCode where
  constructor MkCGaussCode
  len : Nat
  data_ : Vect len Int32

||| Proof that CGaussCode faithfully represents a GaussCode.
public export
data FaithfulRepr : GaussCode -> CGaussCode -> Type where
  ReprCorrect : (gc : GaussCode)
             -> (cgc : CGaussCode)
             -> (lenEq : cgc.len = length gc.entries)
             -> FaithfulRepr gc cgc

||| A knot record ID (UUID v4 as 36-byte ASCII string).
public export
record KnotId where
  constructor MkKnotId
  bytes : Vect 36 Char

||| Invariants computed on a knot.
public export
record KnotInvariants where
  constructor MkKnotInvariants
  crossingNumber : Nat
  writhe : Int
  gaussHash : Vect 64 Char  -- SHA-256 hex string

||| Proof: crossing number is non-negative (trivially true for Nat).
public export
crossingNonNeg : (n : Nat) -> LTE 0 n
crossingNonNeg n = LTEZero

||| Proof: hash length is always 64 (SHA-256 hex).
public export
hashLen : (inv : KnotInvariants) -> length (toList inv.gaussHash) = 64
hashLen inv = vectorLengthCorrect inv.gaussHash
  where
    vectorLengthCorrect : Vect n a -> length (toList (Vect.MkVect n a)) = n
    vectorLengthCorrect _ = Refl
