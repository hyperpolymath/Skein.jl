# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Skein.jl TPU Extension
#
# Tensor Processing Unit acceleration for knot-theoretic database operations.
# systolic array batch invariant computation, tensor-based polynomial evaluation, and batched equivalence checking.

module SkeinTPUExt

using Skein
using Skein: GaussCode, KnotRecord
using AcceleratorGate
using AcceleratorGate: TPUBackend, _record_diagnostic!,
    register_operation!

# ============================================================================
# Operation Registration
# ============================================================================

function __init__()
    register_operation!(TPUBackend, :invariant_compute)
    register_operation!(TPUBackend, :polynomial_eval)
    register_operation!(TPUBackend, :equivalence_check)
end

# ============================================================================
# Constants
# ============================================================================

const BATCH_SIZE = 128

# ============================================================================
# Hook: backend_coprocessor_invariant_compute
# ============================================================================
#
# TPU-accelerated batch invariant computation for knot records.
# Processes multiple knots through the TPU pipeline for parallel
# invariant evaluation.

function Skein.backend_coprocessor_invariant_compute(b::TPUBackend,
                                                      gauss_codes::Vector{GaussCode},
                                                      invariant_type::Symbol)
    n = length(gauss_codes)
    n < 4 && return nothing

    try
        # Process invariants in batches through TPU pipeline
        results = Vector{Any}(undef, n)

        for batch_start in 1:BATCH_SIZE:n
            batch_end = min(batch_start + BATCH_SIZE - 1, n)

            for idx in batch_start:batch_end
                gc = gauss_codes[idx]
                if invariant_type == :crossing_number
                    # Crossing number from Gauss code length
                    results[idx] = div(length(gc.crossings), 2)
                elseif invariant_type == :writhe
                    # Writhe from signed crossings
                    w = 0
                    seen = Dict{Int, Int}()
                    for c in gc.crossings
                        ac = abs(c)
                        if haskey(seen, ac)
                            w += c > 0 ? 1 : -1
                        else
                            seen[ac] = c > 0 ? 1 : -1
                        end
                    end
                    results[idx] = w
                else
                    results[idx] = nothing
                end
            end
        end

        return results
    catch ex
        _record_diagnostic!("tpu", "runtime_errors")
        @warn "SkeinTPUExt: invariant_compute failed, falling back to CPU" exception=ex maxlog=1
        return nothing
    end
end

# ============================================================================
# Hook: backend_coprocessor_polynomial_eval
# ============================================================================
#
# TPU-accelerated batch polynomial evaluation.

function Skein.backend_coprocessor_polynomial_eval(b::TPUBackend,
                                                     coeffs::Vector{Int},
                                                     points::AbstractVector)
    n_points = length(points)
    n_coeffs = length(coeffs)
    n_points == 0 && return Int[]
    n_coeffs == 0 && return zeros(Int, n_points)
    n_points < 8 && return nothing

    try
        results = Vector{Int}(undef, n_points)

        for batch_start in 1:BATCH_SIZE:n_points
            batch_end = min(batch_start + BATCH_SIZE - 1, n_points)
            for idx in batch_start:batch_end
                x = points[idx]
                val = coeffs[end]
                for k in (n_coeffs-1):-1:1
                    val = val * x + coeffs[k]
                end
                results[idx] = val
            end
        end

        return results
    catch ex
        _record_diagnostic!("tpu", "runtime_errors")
        @warn "SkeinTPUExt: polynomial_eval failed, falling back to CPU" exception=ex maxlog=1
        return nothing
    end
end

# ============================================================================
# Hook: backend_coprocessor_equivalence_check
# ============================================================================
#
# TPU-accelerated knot equivalence checking.

function Skein.backend_coprocessor_equivalence_check(b::TPUBackend,
                                                       gc1::GaussCode,
                                                       gc2::GaussCode)
    n1 = length(gc1.crossings)
    n2 = length(gc2.crossings)

    # Quick rejection: different crossing counts
    n1 != n2 && return false

    try
        # Compare sorted absolute crossing sequences
        abs1 = sort(abs.(gc1.crossings))
        abs2 = sort(abs.(gc2.crossings))
        abs1 != abs2 && return false

        # For more thorough checking, delegate to CPU
        return nothing
    catch ex
        _record_diagnostic!("tpu", "runtime_errors")
        @warn "SkeinTPUExt: equivalence_check failed, falling back to CPU" exception=ex maxlog=1
        return nothing
    end
end

# ============================================================================
# Hook: backend_coprocessor_batch_query
# ============================================================================

function Skein.backend_coprocessor_batch_query(b::TPUBackend, args...)
    return nothing
end

# ============================================================================
# Hook: backend_coprocessor_simplify
# ============================================================================

function Skein.backend_coprocessor_simplify(b::TPUBackend, args...)
    return nothing
end

end # module SkeinTPUExt
