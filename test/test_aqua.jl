"""
Aqua.jl Quality Assurance Tests for Globtim

This file runs Aqua.jl quality assurance checks on the Globtim package.
Configuration is loaded from aqua_config.jl.

Aqua.jl checks for:
- Method ambiguities
- Undefined exports
- Unbound type parameters
- Persistent tasks
- Project TOML formatting
- Dependency compatibility
- Stale dependencies

See: https://github.com/JuliaTesting/Aqua.jl
"""

using Test
using Aqua
using Globtim

# Load Aqua configuration
include("aqua_config.jl")

@testset "Aqua.jl Quality Assurance" begin
    # Check if we should run Aqua tests
    if !should_run_aqua_tests()
        @info "Skipping Aqua tests (disabled via environment variable or Julia version)"
        @test_skip "Aqua tests disabled"
        return
    end

    # Print configuration info
    if get(ENV, "AQUA_VERBOSE", "false") == "true"
        print_aqua_config()
    end

    # Run configured Aqua tests
    @testset "Configured Aqua Tests" begin
        run_configured_aqua_tests(Globtim)
    end

    println("\n✅ Aqua.jl quality assurance checks completed!")
end
