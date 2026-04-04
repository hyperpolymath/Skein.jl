# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 required for Julia ecosystem)
# Property-based invariant tests for Skein.jl

using Test
using Skein

@testset "Property-Based Tests" begin

    @testset "Invariant: gauss_hash is deterministic" begin
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        for _ in 1:50
            @test gauss_hash(trefoil) == gauss_hash(GaussCode([1, -2, 3, -1, 2, -3]))
        end
    end

    @testset "Invariant: gauss_hash output is always 64 hex characters" begin
        for n in [0, 2, 4, 6, 8]
            crossings = n == 0 ? Int[] : [(-1)^i * ((i ÷ 2) + 1) for i in 1:n]
            g = GaussCode(crossings)
            h = gauss_hash(g)
            @test length(h) == 64
            @test all(c -> c in "0123456789abcdef", h)
        end
    end

    @testset "Invariant: crossing_number is non-negative" begin
        for _ in 1:50
            n = rand(0:5) * 2  # must be even for valid Gauss code
            crossings = n == 0 ? Int[] : [(-1)^i * ((i ÷ 2) + 1) for i in 1:n]
            g = GaussCode(crossings)
            @test crossing_number(g) >= 0
        end
    end

    @testset "Invariant: simplify does not increase crossing number" begin
        known_knots = [
            GaussCode([1, -2, 3, -1, 2, -3]),      # trefoil (3)
            GaussCode([1, -2, 3, -4, 2, -1, 4, -3]), # figure-eight (4)
            GaussCode(Int[]),                          # unknot (0)
        ]
        for g in known_knots
            s = simplify(g)
            @test crossing_number(s) <= crossing_number(g)
        end
    end

    @testset "Invariant: normalise_gauss produces crossings starting at 1" begin
        for _ in 1:30
            # Scale trefoil labels by a random factor
            k = rand(2:20)
            g = GaussCode([k, -2k, 3k, -k, 2k, -3k])
            n = Skein.normalise_gauss(g)
            if !isempty(n.crossings)
                abs_vals = abs.(n.crossings)
                @test minimum(abs_vals) == 1
            end
        end
    end

end
