# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Skein.jl Backend Abstraction
# Uses AcceleratorGate.jl for shared coprocessor dispatch infrastructure.

using AcceleratorGate
using AcceleratorGate: generate_self_healing_hooks

# ============================================================================
# Domain-Specific Operation Hooks -- Skein
# ============================================================================

# Julia fallback implementations
backend_invariant_compute(::JuliaBackend, args...) = nothing
backend_polynomial_eval(::JuliaBackend, args...) = nothing
backend_equivalence_check(::JuliaBackend, args...) = nothing
backend_batch_query(::JuliaBackend, args...) = nothing
backend_simplify(::JuliaBackend, args...) = nothing

# Coprocessor extension hooks (concrete extensions overload these)
function backend_coprocessor_invariant_compute end
function backend_coprocessor_polynomial_eval end
function backend_coprocessor_equivalence_check end
function backend_coprocessor_batch_query end
function backend_coprocessor_simplify end

# Self-healing fallback generation for coprocessor hooks
generate_self_healing_hooks(@__MODULE__, [
    (:backend_coprocessor_invariant_compute, :backend_invariant_compute),
    (:backend_coprocessor_polynomial_eval, :backend_polynomial_eval),
    (:backend_coprocessor_equivalence_check, :backend_equivalence_check),
    (:backend_coprocessor_batch_query, :backend_batch_query),
    (:backend_coprocessor_simplify, :backend_simplify),
])

# Dispatch: CoprocessorBackend -> coprocessor hook
backend_invariant_compute(b::CoprocessorBackend, args...) = backend_coprocessor_invariant_compute(b, args...)
backend_polynomial_eval(b::CoprocessorBackend, args...) = backend_coprocessor_polynomial_eval(b, args...)
backend_equivalence_check(b::CoprocessorBackend, args...) = backend_coprocessor_equivalence_check(b, args...)
backend_batch_query(b::CoprocessorBackend, args...) = backend_coprocessor_batch_query(b, args...)
backend_simplify(b::CoprocessorBackend, args...) = backend_coprocessor_simplify(b, args...)

# Dispatch: GPUBackend -> Julia fallback (extensions override)
backend_invariant_compute(b::GPUBackend, args...) = backend_invariant_compute(JuliaBackend(), args...)
backend_polynomial_eval(b::GPUBackend, args...) = backend_polynomial_eval(JuliaBackend(), args...)
backend_equivalence_check(b::GPUBackend, args...) = backend_equivalence_check(JuliaBackend(), args...)
backend_batch_query(b::GPUBackend, args...) = backend_batch_query(JuliaBackend(), args...)
backend_simplify(b::GPUBackend, args...) = backend_simplify(JuliaBackend(), args...)
