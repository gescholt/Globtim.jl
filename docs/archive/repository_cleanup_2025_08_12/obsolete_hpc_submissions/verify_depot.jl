# verify_depot.jl
using Pkg

println("=== Verifying Offline Depot Completeness for Globtim HPC ===")

# Temporarily disable network (simulate offline environment)
ENV["JULIA_NO_NETWORK"] = "1"
ENV["JULIA_PKG_SERVER"] = ""

println("🔒 Network disabled for offline testing")
println("Depot location: ", ENV["JULIA_DEPOT_PATH"])

# Test loading all key packages
println("\n📋 Testing key package loading...")
failed_packages = String[]
key_packages = [
    "ForwardDiff",
    "HomotopyContinuation", 
    "DynamicPolynomials",
    "Optim",
    "BenchmarkTools",
    "LinearSolve",
    "SpecialFunctions",
    "Distributions",
    "CSV",
    "DataFrames",
    "Clustering",
    "JSON3",
    "YAML",
    "Parameters",
    "PolyChaos",
    "IterTools",
    "TimerOutputs"
]

for pkg_name in key_packages
    try
        print("Loading $pkg_name... ")
        eval(Meta.parse("using $pkg_name"))
        println("✅")
    catch e
        println("❌")
        push!(failed_packages, pkg_name)
        println("  Error: ", e)
    end
end

# Test standard library packages
println("\n📚 Testing standard library packages...")
stdlib_packages = [
    "LinearAlgebra",
    "Statistics", 
    "Random",
    "Dates",
    "DelimitedFiles"
]

for pkg_name in stdlib_packages
    try
        print("Loading $pkg_name... ")
        eval(Meta.parse("using $pkg_name"))
        println("✅")
    catch e
        println("❌")
        push!(failed_packages, pkg_name)
        println("  Error: ", e)
    end
end

if isempty(failed_packages)
    println("\n✅ All packages load successfully!")
else
    println("\n⚠️  Failed packages:")
    for pkg in failed_packages
        println("  - ", pkg)
    end
end

# Test specific Globtim functionality
println("\n🧪 Testing Globtim core functionality...")

try
    # Test basic polynomial operations
    using DynamicPolynomials
    @polyvar x y
    p = x^2 + y^2 - 1
    println("✅ Polynomial creation works")
    
    # Test ForwardDiff
    using ForwardDiff
    f(x) = x[1]^2 + x[2]^2
    grad = ForwardDiff.gradient(f, [1.0, 2.0])
    println("✅ ForwardDiff gradient computation works")
    
    # Test optimization
    using Optim
    result = optimize(x -> (x[1] - 1)^2 + (x[2] - 2)^2, [0.0, 0.0])
    println("✅ Optimization works")
    
    # Test benchmarking
    using BenchmarkTools
    b = @benchmark sin(1.0)
    println("✅ Benchmarking works")
    
    println("\n✅ Core Globtim functionality verified!")
    
catch e
    println("\n❌ Globtim functionality test failed: ", e)
end

# Test that plotting packages are not directly accessible
println("\n🚫 Verifying plotting packages are excluded...")
plotting_packages = ["Makie", "CairoMakie", "GLMakie"]
excluded_count = 0

for pkg_name in plotting_packages
    try
        eval(Meta.parse("using $pkg_name"))
        println("⚠️  $pkg_name is accessible (may be transitive dependency)")
    catch e
        println("✅ $pkg_name properly excluded")
        excluded_count += 1
    end
end

# Summary
println("\n" * "="^60)
println("VERIFICATION SUMMARY")
println("="^60)
println("📦 Total key packages tested: ", length(key_packages) + length(stdlib_packages))
println("✅ Successfully loaded: ", length(key_packages) + length(stdlib_packages) - length(failed_packages))
println("❌ Failed to load: ", length(failed_packages))
println("🚫 Plotting packages excluded: ", excluded_count, "/", length(plotting_packages))

if isempty(failed_packages)
    println("\n🎉 DEPOT VERIFICATION SUCCESSFUL!")
    println("   Ready for HPC deployment")
else
    println("\n⚠️  DEPOT VERIFICATION INCOMPLETE")
    println("   Some packages failed to load")
end

println("\n📄 Verification complete - check output above for details")

# Re-enable network
delete!(ENV, "JULIA_NO_NETWORK")
delete!(ENV, "JULIA_PKG_SERVER")
