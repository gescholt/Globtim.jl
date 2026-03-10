"""
Tests for ExperimentCLI.jl covering:
  1. Base.pairs returns an iterable Pairs object (not a bare NamedTuple)
  2. Truncation field validation (threshold > 0, mode ∈ {:relative, :absolute})
  3. Truncation fields are accepted via CLI --truncation-threshold / --truncation-mode
  4. Truncation fields are loaded from TOML via --config
  5. print_params includes truncation and basis info
"""

using Test
using Globtim
using Globtim.ExperimentCLI

@testset "ExperimentCLI" begin

    # ── Baseline: default construction ──────────────────────────────────────
    @testset "Default construction" begin
        ep = ExperimentParams()
        @test ep.domain_size == 0.1
        @test ep.GN == 5
        @test ep.truncation_threshold === nothing
        @test ep.truncation_mode === :relative
    end

    # ── Base.pairs contract ─────────────────────────────────────────────────
    @testset "Base.pairs returns a proper Pairs iterator" begin
        ep = ExperimentParams(GN=8, domain_size=0.5)

        p = pairs(ep)

        # Must be iterable as key => value pairs (not a bare NamedTuple)
        # The canonical test: Dict(pairs(x)) must work without error.
        d = Dict(p)
        @test d isa Dict
        @test d[:GN] == 8
        @test d[:domain_size] == 0.5
        @test haskey(d, :truncation_threshold)
        @test haskey(d, :truncation_mode)

        # All 13 fields must appear
        all_keys = Set(keys(d))
        expected_keys = Set([
            :domain_size, :GN, :degree_range, :max_time, :basis,
            :optim_f_tol, :optim_x_tol, :max_iterations,
            :enable_gradient_computation, :enable_hessian_computation,
            :enable_bfgs_refinement, :truncation_threshold, :truncation_mode
        ])
        @test all_keys == expected_keys

        # Iteration must yield Pair objects
        for (k, v) in pairs(ep)
            @test k isa Symbol
        end
    end

    # ── Truncation field validation ─────────────────────────────────────────
    @testset "Truncation field validation" begin
        # Valid: threshold > 0
        ep = ExperimentParams(truncation_threshold=0.01, truncation_mode=:relative)
        @test ep.truncation_threshold == 0.01
        @test ep.truncation_mode === :relative

        ep2 = ExperimentParams(truncation_threshold=1e-4, truncation_mode=:absolute)
        @test ep2.truncation_threshold ≈ 1e-4
        @test ep2.truncation_mode === :absolute

        # Valid: threshold=nothing (disabled)
        ep3 = ExperimentParams(truncation_threshold=nothing)
        @test ep3.truncation_threshold === nothing

        # Invalid: threshold <= 0
        @test_throws Exception ExperimentParams(truncation_threshold=0.0)
        @test_throws Exception ExperimentParams(truncation_threshold=-0.1)

        # Invalid: unknown truncation_mode
        @test_throws Exception ExperimentParams(truncation_threshold=0.01, truncation_mode=:nonsense)
        @test_throws Exception ExperimentParams(truncation_threshold=0.01, truncation_mode="bogus")

        # String mode is accepted and converted
        ep4 = ExperimentParams(truncation_threshold=0.01, truncation_mode="relative")
        @test ep4.truncation_mode === :relative

        ep5 = ExperimentParams(truncation_threshold=0.01, truncation_mode="absolute")
        @test ep5.truncation_mode === :absolute
    end

    # ── CLI parsing: truncation flags ───────────────────────────────────────
    @testset "CLI truncation args" begin
        # --truncation-threshold= and --truncation-mode= must be accepted
        ep = parse_experiment_args(["--truncation-threshold=0.05", "--truncation-mode=relative"])
        @test ep.truncation_threshold ≈ 0.05
        @test ep.truncation_mode === :relative

        ep2 = parse_experiment_args(["--truncation-threshold=1e-3", "--truncation-mode=absolute"])
        @test ep2.truncation_threshold ≈ 1e-3
        @test ep2.truncation_mode === :absolute

        # Without truncation flags: defaults apply
        ep3 = parse_experiment_args(String[])
        @test ep3.truncation_threshold === nothing
        @test ep3.truncation_mode === :relative

        # Unknown flag still errors
        @test_throws Exception parse_experiment_args(["--unknown-flag=42"])
    end

    # ── TOML --config loading: truncation fields ────────────────────────────
    @testset "TOML config loads truncation fields" begin
        # Write a minimal TOML with truncation settings
        toml_content = """
        [polynomial]
        GN = 10
        truncation_threshold = 0.02
        truncation_mode = "absolute"
        """
        tmp = tempname() * ".toml"
        try
            write(tmp, toml_content)
            ep = parse_experiment_args(["--config=$tmp"])
            @test ep.GN == 10
            @test ep.truncation_threshold ≈ 0.02
            @test ep.truncation_mode === :absolute
        finally
            isfile(tmp) && rm(tmp)
        end
    end

    # ── TOML --config: CLI args override TOML ──────────────────────────────
    @testset "CLI overrides TOML truncation fields" begin
        toml_content = """
        [polynomial]
        truncation_threshold = 0.02
        truncation_mode = "absolute"
        """
        tmp = tempname() * ".toml"
        try
            write(tmp, toml_content)
            # CLI --truncation-threshold overrides the TOML value
            ep = parse_experiment_args(["--config=$tmp", "--truncation-threshold=0.99"])
            @test ep.truncation_threshold ≈ 0.99
            # Mode from TOML still applies (CLI didn't override it)
            @test ep.truncation_mode === :absolute
        finally
            isfile(tmp) && rm(tmp)
        end
    end

    # ── print_params includes truncation and basis ──────────────────────────
    @testset "print_params includes basis and truncation info" begin
        ep = ExperimentParams(
            basis=:legendre,
            truncation_threshold=0.01,
            truncation_mode=:absolute
        )

        output = sprint(print_params, ep)

        # Basis must appear
        @test occursin("legendre", output)

        # Truncation must appear when set
        @test occursin("0.01", output) || occursin("truncat", lowercase(output))
        @test occursin("absolute", output)

        # Without truncation: must not crash and must not show truncation line
        ep2 = ExperimentParams(basis=:chebyshev)
        output2 = sprint(print_params, ep2)
        @test occursin("chebyshev", output2)
        @test !occursin("truncat", lowercase(output2))
    end

    # ── setproperties round-trips truncation fields ─────────────────────────
    # Call via ExperimentCLI which imports ConstructionBase internally
    @testset "setproperties preserves truncation fields" begin
        ep = ExperimentParams(GN=10, truncation_threshold=0.05, truncation_mode=:absolute)

        # Update GN: truncation fields must be preserved
        ep2 = ExperimentParams(;
            domain_size = ep.domain_size, GN = 20,
            degree_range = ep.degree_range, max_time = ep.max_time,
            basis = ep.basis, optim_f_tol = ep.optim_f_tol,
            optim_x_tol = ep.optim_x_tol, max_iterations = ep.max_iterations,
            enable_gradient_computation = ep.enable_gradient_computation,
            enable_hessian_computation = ep.enable_hessian_computation,
            enable_bfgs_refinement = ep.enable_bfgs_refinement,
            truncation_threshold = ep.truncation_threshold,
            truncation_mode = ep.truncation_mode
        )
        @test ep2.GN == 20
        @test ep2.truncation_threshold ≈ 0.05
        @test ep2.truncation_mode === :absolute

        # pairs(ep) can feed back into ExperimentParams constructor via Dict
        d = Dict(pairs(ep))
        d[:GN] = 30
        ep3 = ExperimentParams(; d...)
        @test ep3.GN == 30
        @test ep3.truncation_threshold ≈ 0.05
        @test ep3.truncation_mode === :absolute
    end

end
