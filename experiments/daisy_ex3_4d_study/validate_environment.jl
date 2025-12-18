#!/usr/bin/env julia
"""
Environment Validation Script for HPC Deployment
===============================================

This script validates the package environment before running experiments
to ensure compatibility between local and cluster environments.

Author: GlobTim Project
Date: September 15, 2025
"""

using Pkg

println("🔍 Validating package environment for Lotka-Volterra 4D experiments...")
println("="^70)

# Check Julia version
expected_version = v"1.11.6"
println("Julia Version Check:")
println("  Expected: $expected_version")
println("  Current:  $VERSION")

if VERSION.major != expected_version.major || VERSION.minor != expected_version.minor
    @warn "Julia version mismatch! Expected $(expected_version.major).$(expected_version.minor).x, got $VERSION"
    if VERSION < expected_version
        @error "Julia version too old. Please upgrade to at least $expected_version"
        exit(1)
    end
else
    println("  ✅ Julia version compatible")
end

# Activate project
function find_project_dir()
    current_dir = dirname(@__FILE__)
    while !isfile(joinpath(current_dir, "Project.toml"))
        current_dir = dirname(current_dir)
        if current_dir == "/"
            @error "Could not find Project.toml"
            exit(1)
        end
    end
    return current_dir
end

project_dir = find_project_dir()

println("\nProject Activation:")
println("  Project directory: $project_dir")
Pkg.activate(project_dir)
println("  ✅ Project activated")

# Check project status
println("\nProject Status:")
try
    Pkg.resolve()
    println("  ✅ Package dependencies resolved")
catch e
    @error "Failed to resolve dependencies: $e"
    exit(1)
end

# Test critical packages for Lotka-Volterra experiments
critical_packages = [
    (:Globtim, "Local package for global optimization"),
    (:DynamicPolynomials, "Polynomial system construction"),
    (:HomotopyContinuation, "Polynomial system solving"),
    (:CSV, "Data export"),
    (:JSON, "Configuration files"),
    (:StaticArrays, "Vector operations"),
    (:LinearAlgebra, "Matrix operations"),
    (:TimerOutputs, "Performance monitoring")
]

println("\nCritical Package Loading Test:")
all_packages_loaded = true

for (pkg_name, description) in critical_packages
    try
        @eval using $pkg_name
        println("  ✅ $pkg_name: $description")
    catch e
        println("  ❌ $pkg_name FAILED: $e")
        all_packages_loaded = false
    end
end

if !all_packages_loaded
    @error "Some critical packages failed to load. Cannot proceed with experiments."
    exit(1)
end

# Test ModelingToolkit and OrdinaryDiffEq (heavy packages)
println("\nHeavy Package Loading Test:")
heavy_packages = [
    (:ModelingToolkit, "ODE system definition"),
    (:OrdinaryDiffEq, "Differential equation solving")
]

for (pkg_name, description) in heavy_packages
    try
        println("  Loading $pkg_name... (this may take a moment)")
        @eval using $pkg_name
        println("  ✅ $pkg_name: $description")
    catch e
        println("  ❌ $pkg_name FAILED: $e")
        all_packages_loaded = false
    end
end

if !all_packages_loaded
    @error "Heavy packages failed to load. Cannot proceed with experiments."
    exit(1)
end

# Test Dynamic_objectives package
println("\nDynamic_objectives Package Test:")
try
    using Dynamic_objectives

    # Test the 4D model function
    model, params, states, outputs = define_daisy_ex3_model_4D()
    println("  ✅ Dynamic_objectives package loaded")
    println("  ✅ define_daisy_ex3_model_4D function working")
    println("    Parameters: $(length(params))")
    println("    States: $(length(states))")
    println("    Outputs: $(length(outputs))")

catch e
    println("  ❌ Dynamic_objectives package FAILED: $e")
    exit(1)
end

# Test Globtim core functions
println("\nGlobtim Core Functions Test:")
model, params, states, outputs = nothing, nothing, nothing, nothing
try
    # Get model from Dynamic_objectives
    model, params, states, outputs = define_daisy_ex3_model_4D()

    # Test error function creation
    P_TRUE = [0.2, 0.3, 0.5, 0.6]
    IC = [1.0, 2.0, 1.0, 1.0]
    TIME_INTERVAL = [0.0, 10.0]
    NUM_POINTS = 25

    error_func = make_error_distance(
        model,
        outputs,
        IC,
        P_TRUE,
        TIME_INTERVAL,
        NUM_POINTS,
        L2_norm
    )

    # Test function evaluation
    error_at_true = error_func(P_TRUE)
    println("  ✅ Error function creation successful")
    println(
        "  ✅ Function evaluation working (error at true: $(round(error_at_true, digits=8)))"
    )

    # Quick test_input test
    TR = test_input(
        error_func,
        dim = 4,
        center = P_TRUE,
        GN = 5,  # Small test
        sample_range = 0.05
    )
    println("  ✅ test_input function working (generated $(TR.GN) samples)")

catch e
    println("  ❌ Globtim core functions FAILED: $e")
    exit(1)
end

# Environment summary
println("\n" * "="^70)
println("🎉 ENVIRONMENT VALIDATION SUCCESSFUL! 🎉")
println("="^70)
println("Environment Summary:")
println("  Julia Version: $VERSION")
println("  Project: $project_dir")
println("  All critical packages: ✅ LOADED")
println("  All heavy packages: ✅ LOADED")
println("  Dynamic_objectives package: ✅ WORKING")
println("  Globtim core functions: ✅ WORKING")
println("  4D Lotka-Volterra model: ✅ READY")
println()
println("🚀 Ready to proceed with Lotka-Volterra 4D experiments!")
println("="^70)
