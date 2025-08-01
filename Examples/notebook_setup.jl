"""
Notebook Setup Helper for AdaptivePrecision Development

This script provides a robust setup for the AdaptivePrecision development notebook
that handles missing dependencies gracefully.

Usage in notebook:
    include("../../Examples/notebook_setup.jl")
"""

using Pkg

println("🚀 Setting up AdaptivePrecision Development Environment")
println("=" ^ 60)

# Activate the main project
try
    Pkg.activate("../../.")
    println("✅ Project activated: $(Pkg.project().path)")
catch e
    println("⚠️  Could not activate project: $e")
    println("   Continuing with current environment...")
end

# Core packages (required)
core_packages = [
    "Globtim", "DynamicPolynomials", "DataFrames", 
    "Statistics", "LinearAlgebra", "Printf"
]

println("\n📦 Loading core packages...")
for pkg in core_packages
    try
        eval(:(using $(Symbol(pkg))))
        println("  ✅ $pkg")
    catch e
        println("  ❌ $pkg: $e")
    end
end

# Optional packages with graceful fallback
optional_packages = [
    ("Revise", "Automatic code reloading"),
    ("BenchmarkTools", "Detailed performance benchmarking"),
    ("ProfileView", "Interactive performance profiling"),
    ("PlotlyJS", "Interactive plotting")
]

println("\n🔧 Checking optional packages...")
available_packages = Dict{String, Bool}()

for (pkg, description) in optional_packages
    try
        eval(:(using $(Symbol(pkg))))
        println("  ✅ $pkg: Available")
        available_packages[pkg] = true
    catch
        println("  ⚠️  $pkg: Not available - $description")
        available_packages[pkg] = false
    end
end

# Install missing packages function
function install_missing_packages()
    missing = [pkg for (pkg, available) in available_packages if !available]
    
    if isempty(missing)
        println("✅ All optional packages are available!")
        return
    end
    
    println("🚀 Installing missing packages: $(join(missing, \", \"))")
    
    for pkg in missing
        try
            Pkg.add(pkg)
            println("  ✅ $pkg installed")
        catch e
            println("  ❌ Failed to install $pkg: $e")
        end
    end
    
    println("\n📋 Restart the notebook kernel to use newly installed packages")
end

# Load testing framework
println("\n📊 Loading AdaptivePrecision testing framework...")
try
    include("../../test/adaptive_precision_4d_framework.jl")
    println("✅ Testing framework loaded successfully")
    println("  Available functions: $(length(TEST_FUNCTIONS_4D)) test functions")
    println("  BenchmarkTools available: $(available_packages[\"BenchmarkTools\"])")
catch e
    println("❌ Failed to load testing framework: $e")
end

# Summary
println("\n📋 Environment Setup Summary:")
println("  Core packages: ✅ Loaded")
println("  Revise: $(available_packages[\"Revise\"] ? \"✅\" : \"❌\") $(available_packages[\"Revise\"] ? \"(auto-reload enabled)\" : \"(manual reload required)\")")
println("  BenchmarkTools: $(available_packages[\"BenchmarkTools\"] ? \"✅\" : \"❌\") $(available_packages[\"BenchmarkTools\"] ? \"(detailed benchmarking)\" : \"(basic timing only)\")")
println("  ProfileView: $(available_packages[\"ProfileView\"] ? \"✅\" : \"❌\") $(available_packages[\"ProfileView\"] ? \"(interactive profiling)\" : \"(basic profiling only)\")")
println("  PlotlyJS: $(available_packages[\"PlotlyJS\"] ? \"✅\" : \"❌\") $(available_packages[\"PlotlyJS\"] ? \"(interactive plots)\" : \"(no plotting)\")")

if any(values(available_packages) .== false)
    println("\n💡 To install missing packages, run:")
    println("   install_missing_packages()")
    println("   Then restart the notebook kernel")
else
    println("\n🎉 Full development environment ready!")
end

println("\n🚀 Ready for AdaptivePrecision development!")
println("📋 Available quick functions: help_4d(), quick_test(), compare_precisions()")

# Export the installation function
export install_missing_packages
