-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Foreign function interface declarations for Skein.jl.
|||
||| Specifies the C-compatible function signatures that the Zig FFI
||| must implement. Each declaration carries type-level documentation
||| of preconditions, postconditions, and ownership semantics.
module Foreign

import Types
import Layout

%default total

||| Database handle (opaque pointer).
public export
SkeinDBHandle : Type
SkeinDBHandle = AnyPtr

||| Error codes returned by FFI functions.
public export
data SkeinError
  = SkeinOk           -- 0: success
  | SkeinErrOpen      -- 1: failed to open database
  | SkeinErrQuery     -- 2: query execution failed
  | SkeinErrNotFound  -- 3: knot not found
  | SkeinErrDuplicate -- 4: name already exists
  | SkeinErrReadOnly  -- 5: database is read-only
  | SkeinErrInvalid   -- 6: invalid input data

||| FFI function: Open or create a Skein database.
|||
||| @param path Null-terminated path string. Use ":memory:" for in-memory.
||| @param readonly 0 for read-write, 1 for read-only.
||| @return Database handle (caller owns), or NULL on failure.
|||
||| Postcondition: returned handle must be closed with skein_close.
export
skein_open : (path : String) -> (readonly : Int) -> IO SkeinDBHandle

||| FFI function: Close a database handle.
|||
||| @param db Valid database handle (ownership transferred to callee).
||| Postcondition: handle is invalidated; further use is undefined behaviour.
export
skein_close : (db : SkeinDBHandle) -> IO ()

||| FFI function: Store a knot.
|||
||| @param db Valid database handle (borrowed).
||| @param name Null-terminated name string (borrowed).
||| @param crossings Pointer to signed crossing array (borrowed).
||| @param length Number of entries in crossings array.
||| @return Error code.
|||
||| Precondition: crossings has exactly `length` int32 elements.
||| Precondition: each crossing index appears exactly twice with opposite signs.
export
skein_store : (db : SkeinDBHandle)
           -> (name : String)
           -> (crossings : AnyPtr)
           -> (length : Int)
           -> IO Int  -- SkeinError

||| FFI function: Fetch a knot by name.
|||
||| @param db Valid database handle (borrowed).
||| @param name Null-terminated name string (borrowed).
||| @param result Pointer to output struct (caller-allocated).
||| @return Error code.
|||
||| Postcondition: on success, result is populated with knot data.
||| The name string in result is allocated and must be freed by caller.
export
skein_fetch : (db : SkeinDBHandle)
           -> (name : String)
           -> (result : AnyPtr)
           -> IO Int  -- SkeinError

||| FFI function: Count knots in database.
|||
||| @param db Valid database handle (borrowed).
||| @return Number of knots, or -1 on error.
export
skein_count : (db : SkeinDBHandle) -> IO Int

||| FFI function: Check if a knot exists.
|||
||| @param db Valid database handle (borrowed).
||| @param name Null-terminated name string (borrowed).
||| @return 1 if exists, 0 if not, -1 on error.
export
skein_haskey : (db : SkeinDBHandle) -> (name : String) -> IO Int

||| FFI function: Delete a knot by name.
|||
||| @param db Valid database handle (borrowed).
||| @param name Null-terminated name string (borrowed).
||| @return Error code.
export
skein_delete : (db : SkeinDBHandle) -> (name : String) -> IO Int  -- SkeinError

||| FFI function: Compute crossing number from raw Gauss code.
|||
||| @param crossings Pointer to signed crossing array (borrowed).
||| @param length Number of entries.
||| @return Crossing number (non-negative), or -1 on error.
|||
||| Pure function: no side effects, no database required.
export
skein_crossing_number : (crossings : AnyPtr) -> (length : Int) -> IO Int

||| FFI function: Compute writhe from raw Gauss code.
|||
||| @param crossings Pointer to signed crossing array (borrowed).
||| @param length Number of entries.
||| @return Writhe value, or MIN_INT on error.
export
skein_writhe : (crossings : AnyPtr) -> (length : Int) -> IO Int
