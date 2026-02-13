# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
Extension module activated when KnotTheory.jl is loaded alongside Skein.jl.

Provides direct storage/retrieval of KnotTheory types (PlanarDiagram etc.)
and delegates invariant computation to KnotTheory's verified implementations.

Usage:
```julia
using KnotTheory, Skein

db = SkeinDB("knots.db")
pd = PlanarDiagram(...)  # KnotTheory type
store!(db, "trefoil", pd)
```
"""
module KnotTheoryExt

using Skein
using KnotTheory

# -- Bridge: convert between KnotTheory types and Skein's GaussCode --

# TODO: Implement these conversions based on KnotTheory.jl's actual
# exported types. The signatures below are placeholders — adapt to
# match whatever PlanarDiagram / GaussCode types KnotTheory exposes.

#=
function Skein.store!(db::SkeinDB, name::String, pd::KnotTheory.PlanarDiagram;
                      metadata::Dict{String, String} = Dict{String, String}())
    gc = KnotTheory.to_gauss_code(pd)
    skein_gc = GaussCode(gc)
    Skein.store!(db, name, skein_gc; metadata = metadata)
end

function to_planar_diagram(record::KnotRecord)
    KnotTheory.from_gauss_code(record.gauss_code.crossings)
end
=#

end # module KnotTheoryExt
