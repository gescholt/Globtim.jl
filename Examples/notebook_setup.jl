"""
Notebook Setup Helper for AdaptivePrecision Development

This script provides a robust setup for the AdaptivePrecision development notebook
that handles missing dependencies gracefully.

Usage in notebook:
    include("../notebook_setup.jl")  # or appropriate relative path
"""

using Pkg
using Printf

println("🚀 Setting up AdaptivePrecision Development Environment")
println("=" ^ 60)

# Function to safely load a package
function safe_load_package(pkg_name::String)
    try
        # Try to load the package
        pkg_symbol = Symbol(pkg_name)
        if Base.find_package(pkg_name) !== nothing
            Base.require(Main, pkg_symbol)
            return true
        else
            return false
        end
    catch
        return false
    end
end

# Activate the main project with better path resolution
project_paths = ["../../.", "../..", "."]
project_activated = false

for path in project_paths
    try
        if isfile(joinpath(path, "Project.toml"))
            Pkg.activate(path)
            @printf "✅ Project activated: %s\n" Pkg.project().path
            project_activated = true
            break
        end
    catch
        continue
    end
end

if !project_activated
    println("⚠️  Could not find/activate project - using current environment")
end

# Core packages (required)
core_packages = ["Globtim", "DynamicPolynomials", "DataFrames", "Statistics", "LinearAlgebra"]

println("\n📦 Loading core packages...")
loaded_packages = Dict{String, Bool}()

for pkg in core_packages
    success = safe_load_package(pkg)
    if success
        println("  ✅ $pkg")
        loaded_packages[pkg] = true
    else
        println("  ❌ $pkg: Failed to load")
        loaded_packages[pkg] = false
    end
end

# Optional packages with graceful fallback
optional_packages = [
    ("Revise", "Automatic code reloading"),
    ("BenchmarkTools", "Detailed performance benchmarking"),
    ("ProfileView", "Interactive performance profiling"),
    ("CairoMakie", "High-quality static plotting for notebooks")
]

println("\n🔧 Checking optional packages...")
available_packages = Dict{String, Bool}()

for (pkg, description) in optional_packages
    success = safe_load_package(pkg)
    if success
        println("  ✅ $pkg: Available")
        available_packages[pkg] = true
    else
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

    @printf "🚀 Installing missing packages: %s\n" join(missing, ", ")

    for pkg in missing
        try
            Pkg.add(pkg)
            @printf "  ✅ %s installed\n" pkg
        catch e
            @printf "  ❌ Failed to install %s: %s\n" pkg e
        end
    end

    println("\n📋 Restart the notebook kernel to use newly installed packages")
end

# Load testing framework with better path resolution
println("\n📊 Loading AdaptivePrecision testing framework...")
framework_loaded = false
framework_paths = ["../../test/adaptive_precision_4d_framework.jl",
                   "../test/adaptive_precision_4d_framework.jl",
                   "test/adaptive_precision_4d_framework.jl"]

for path in framework_paths
    try
        if isfile(path)
            include(path)
            println("✅ Testing framework loaded successfully")
            if @isdefined(TEST_FUNCTIONS_4D)
                @printf "  Available functions: %d test functions\n" length(TEST_FUNCTIONS_4D)
            end
            framework_loaded = true
            break
        end
    catch e
        continue
    end
end

if !framework_loaded
    println("⚠️  Testing framework not found - basic functionality only")
end

# Summary
println("\n📋 Environment Setup Summary:")
println("  Core packages: ✅ Loaded")

# Check each optional package safely
revise_status = get(available_packages, "Revise", false)
benchmark_status = get(available_packages, "BenchmarkTools", false)
profile_status = get(available_packages, "ProfileView", false)
makie_status = get(available_packages, "CairoMakie", false)

revise_msg = revise_status ? "(auto-reload enabled)" : "(manual reload required)"
benchmark_msg = benchmark_status ? "(detailed benchmarking)" : "(basic timing only)"
profile_msg = profile_status ? "(interactive profiling)" : "(basic profiling only)"
makie_msg = makie_status ? "(high-quality plotting)" : "(no plotting)"

@printf "  Revise: %s %s\n" (revise_status ? "✅" : "❌") revise_msg
@printf "  BenchmarkTools: %s %s\n" (benchmark_status ? "✅" : "❌") benchmark_msg
@printf "  ProfileView: %s %s\n" (profile_status ? "✅" : "❌") profile_msg
@printf "  CairoMakie: %s %s\n" (makie_status ? "✅" : "❌") makie_msg

if any(values(available_packages) .== false)
    println("\n💡 To install missing packages, run:")
    println("   install_missing_packages()")
    println("   Then restart the notebook kernel")
else
    println("\n🎉 Full development environment ready!")
end

println("\n🚀 Ready for AdaptivePrecision development!")
if framework_loaded
    println("📋 Testing framework loaded - full functionality available")
else
    println("📋 Basic functionality available - install testing framework for full features")
end

# Make install function available in Main scope
Main.install_missing_packages = install_missing_packages

println("\n✅ Setup complete!")
