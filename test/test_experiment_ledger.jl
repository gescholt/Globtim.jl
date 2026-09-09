# Tests for ExperimentLedger and the anisotropic-simplex degree
# spec. Both live here because the simplex spec landed alongside
# the ledger and shares the small-fixture style.

using Test
using Globtim
using Random
using JSON3

@testset "one_d_per_dim_simplex support" begin
    # Simplex with vertices d_j*e_j: every exponent satisfies sum nu_j/d_j <= 1.
    L = Globtim.SupportGen(3, (:one_d_per_dim_simplex, [4, 2, 2]))
    @test L.size == (14, 3)
    @test all(sum(L.data[i, :] .// [4, 2, 2]) <= 1 for i in 1:L.size[1])
    # Isotropic simplex degenerates to total degree
    Liso = Globtim.SupportGen(2, (:one_d_per_dim_simplex, [3, 3]))
    @test Liso.size[1] == binomial(2 + 3, 2)
    @test_throws ArgumentError Globtim.SupportGen(2, (:one_d_per_dim_simplex, [0, 3]))

    # Nontensor LS fit reproduces a polynomial lying exactly in the support.
    f(v) = 2.0 + v[1]^4 - 3.0 * v[1]^2 * v[2] + 0.5 * v[2] * v[3] - v[3]^2
    TR = Globtim.TestInput(f; dim = 3, center = zeros(3), GN = 2, sample_range = 1.0)
    rng = Random.MersenneTwister(7)
    S = cos.(pi .* rand(rng, 200, 3))
    pol = Globtim.Constructor(
        TR,
        (:one_d_per_dim_simplex, [4, 2, 2]);
        basis = :chebyshev,
        normalized = false,
        grid = S,
        grid_mode = :nontensor,
        sample_measure = :chebyshev,
    )
    @test pol.degree == (:one_d_per_dim_simplex, [4, 2, 2])
    @test length(pol.coeffs) == 14
    x = Globtim.DynamicPolynomials.@polyvar(y[1:3])[1]
    p = Globtim.main_nd(
        x,
        3,
        pol.degree,
        pol.coeffs;
        basis = pol.basis,
        precision = pol.precision,
        normalized = pol.normalized,
        power_of_two_denom = pol.power_of_two_denom,
    )
    V = 2.0 .* rand(rng, 100, 3) .- 1.0
    @test maximum(abs(f(V[i, :]) - p(x => V[i, :])) for i in 1:100) < 1e-9
end

@testset "emit_ledger_record" begin
    mktempdir() do dir
        # No repo above a temp dir: in-dir record only, absolute outdir stored.
        write(joinpath(dir, "results_summary.json"), "{\"ok\": true}")
        rid = Globtim.emit_ledger_record(;
            slug = "unit test/slug",
            outdir = dir,
            headline = Dict("recovery" => 1.0e-7, "bad" => Inf),
            issue_id = "ISSUE-123",
            job_id = nothing,
            append_to_ledger = false,
        )
        @test occursin("unit-test-slug", rid)
        rec = JSON3.read(read(joinpath(dir, "ledger_record.json"), String))
        @test rec["slug"] == "unit-test-slug"
        @test rec["status"] == "completed"
        @test rec["headline"]["bad"] === nothing
        @test rec["headline"]["recovery"] == 1.0e-7
        @test length(rec["artifacts"]) == 1
        @test rec["artifacts"][1]["path"] == "results_summary.json"
        @test length(rec["artifacts"][1]["sha256"]) == 64
        @test rec["manual"] == false
    end

    # Missing outdir and missing artifact fail loudly (no silent fallbacks).
    @test_throws ErrorException Globtim.emit_ledger_record(;
        slug = "x",
        outdir = joinpath(tempdir(), "does-not-exist-$(rand(UInt32))"),
    )
    mktempdir() do dir
        @test_throws ErrorException Globtim.emit_ledger_record(;
            slug = "x",
            outdir = dir,
            artifacts = ["absent.json"],
        )
    end
end
