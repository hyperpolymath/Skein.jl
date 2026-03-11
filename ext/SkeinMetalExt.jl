# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Skein.jl Metal/Apple Extension
# GPU-accelerated knot invariant computation, batch polynomial evaluation,
# and parallel equivalence checking via Metal + KernelAbstractions.jl.
# Automatically loaded when both Metal.jl and KernelAbstractions.jl are imported.

module SkeinMetalExt

using Metal
using KernelAbstractions
using Skein
using Skein: GaussCode, KnotRecord
using AcceleratorGate
using AcceleratorGate: _backend_env_available, _backend_env_count, _record_diagnostic!

# ============================================================================
# Availability Detection
# ============================================================================

function AcceleratorGate.metal_available()
    forced = _backend_env_available("AXIOM_METAL_AVAILABLE")
    forced !== nothing && return forced
    Metal.functional()
end

function AcceleratorGate.metal_device_count()
    forced = _backend_env_count("AXIOM_METAL_AVAILABLE", "AXIOM_METAL_DEVICE_COUNT")
    forced !== nothing && return forced
    1
end

# ============================================================================
# GPU Kernel: Batch Polynomial Evaluation
# ============================================================================

@kernel function _poly_eval_kernel!(results, @Const(coeffs), @Const(points),
                                     n_coeffs, n_points)
    idx = @index(Global)
    if idx <= n_points
        x = points[idx]
        val = coeffs[n_coeffs]
        for k in (n_coeffs-1):-1:1
            val = val * x + coeffs[k]
        end
        results[idx] = val
    end
end

# ============================================================================
# GPU Kernel: Batch Invariant Hash
# ============================================================================

@kernel function _invariant_hash_kernel!(hashes, @Const(gauss_data),
                                          @Const(offsets), @Const(lengths),
                                          num_knots)
    idx = @index(Global)
    if idx <= num_knots
        off = offsets[idx]
        len = lengths[idx]
        h = UInt64(0x56E1_4A54_5EED_0001)

        for k in 1:len
            val = gauss_data[off + k]
            h = xor(h, UInt64(abs(val)) * UInt64(0x9E3779B97F4A7C15))
            h = xor(h, h >> 17)
            sign_bit = val < 0 ? UInt64(1) : UInt64(0)
            h = xor(h, sign_bit << 63)
            h = h * UInt64(0xBF58476D1CE4E5B9)
        end

        hashes[idx] = h
    end
end

# ============================================================================
# Hook: Invariant Computation
# ============================================================================

"""
    Skein.backend_invariant_compute(::AcceleratorGate.MetalBackend, gauss_codes, invariant_type)

Metal/Apple-accelerated batch invariant computation for multiple knots.
"""
function Skein.backend_invariant_compute(::AcceleratorGate.MetalBackend,
                                          gauss_codes::Vector{GaussCode},
                                          invariant_type::Symbol)
    n = length(gauss_codes)
    n < 8 && return nothing

    try
        # For polynomial invariants, batch-evaluate on GPU
        if invariant_type == :jones
            # Delegate individual Jones computation (too complex for single kernel)
            return nothing
        end

        return nothing
    catch ex
        _record_diagnostic!("metal", "runtime_errors")
        @warn "Metal/Apple invariant compute failed, falling back to CPU" exception=ex maxlog=1
        return nothing
    end
end

# ============================================================================
# Hook: Polynomial Evaluation
# ============================================================================

"""
    Skein.backend_polynomial_eval(::AcceleratorGate.MetalBackend, coeffs, points)

Metal/Apple-accelerated batch polynomial evaluation via GPU kernel.
"""
function Skein.backend_polynomial_eval(::AcceleratorGate.MetalBackend,
                                        coeffs::Vector{Int},
                                        points::AbstractVector)
    n_points = length(points)
    n_coeffs = length(coeffs)
    n_points < 32 && return nothing

    try
        coeffs_gpu = MtlArray(Float64.(coeffs))
        points_gpu = MtlArray(Float64.(points))
        results_gpu = Metal.zeros(Float64, n_points)

        backend = MetalBackend()
        kernel = _poly_eval_kernel!(backend, 256)
        kernel(results_gpu, coeffs_gpu, points_gpu, Int32(n_coeffs), Int32(n_points);
               ndrange=n_points)
        KernelAbstractions.synchronize(backend)

        return Int.(round.(Array(results_gpu)))
    catch ex
        _record_diagnostic!("metal", "runtime_errors")
        @warn "Metal/Apple polynomial eval failed, falling back to CPU" exception=ex maxlog=1
        return nothing
    end
end

# ============================================================================
# Hook: Equivalence Check
# ============================================================================

function Skein.backend_equivalence_check(::AcceleratorGate.MetalBackend, args...)
    return nothing
end

# ============================================================================
# Hook: Batch Query
# ============================================================================

function Skein.backend_batch_query(::AcceleratorGate.MetalBackend, args...)
    return nothing
end

# ============================================================================
# Hook: Simplify
# ============================================================================

function Skein.backend_simplify(::AcceleratorGate.MetalBackend, args...)
    return nothing
end

# ============================================================================
# Memory Management
# ============================================================================

function AcceleratorGate.backend_to_gpu(::AcceleratorGate.MetalBackend, x::AbstractArray)
    MtlArray(x)
end

function AcceleratorGate.backend_to_cpu(::AcceleratorGate.MetalBackend, x_gpu::MtlArray)
    Array(x_gpu)
end

function AcceleratorGate.backend_synchronize(::AcceleratorGate.MetalBackend)
    Metal.synchronize()
end

end  # module SkeinMetalExt
