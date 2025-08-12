# analyze_dependencies.jl
using Pkg
using TOML
using Dates

println("=== Analyzing Package Dependencies for Globtim HPC ===")

# Get all dependencies including indirect ones
function get_all_deps()
    deps = Pkg.dependencies()

    # Categorize packages
    stdlib_pkgs = String[]
    regular_pkgs = String[]
    binary_pkgs = String[]

    # Get list of standard library packages
    stdlib_names = ["LinearAlgebra", "Statistics", "Random", "Dates", "TOML", "UUIDs",
                   "SHA", "DelimitedFiles", "SparseArrays", "Distributed", "SharedArrays"]

    for (uuid, dep) in deps
        if dep.name in stdlib_names
            push!(stdlib_pkgs, dep.name)
        elseif contains(string(dep.name), "_jll")
            push!(binary_pkgs, dep.name)
        else
            push!(regular_pkgs, dep.name)
        end
    end

    return (stdlib=stdlib_pkgs, regular=regular_pkgs, binary=binary_pkgs)
end

pkgs = get_all_deps()

println("\n📚 Standard Library Packages (", length(pkgs.stdlib), "):")
for p in sort(pkgs.stdlib)
    println("  - ", p)
end

println("\n📦 Regular Packages (", length(pkgs.regular), "):")
for p in sort(pkgs.regular)
    println("  - ", p)
end

println("\n⚙️ Binary Dependencies (", length(pkgs.binary), "):")
for p in sort(pkgs.binary)
    println("  - ", p)
end

println("\n📊 Total packages: ", length(pkgs.stdlib) + length(pkgs.regular) + length(pkgs.binary))

# Check for excluded plotting packages
excluded_packages = ["Makie", "Colors", "CairoMakie", "GLMakie", "PlotlyJS", "Plots"]
found_excluded = String[]

for pkg_name in excluded_packages
    if pkg_name in pkgs.regular || pkg_name in pkgs.stdlib
        push!(found_excluded, pkg_name)
    end
end

if isempty(found_excluded)
    println("\n✅ No plotting packages found - HPC configuration correct!")
else
    println("\n⚠️  Found excluded packages that should not be in HPC build:")
    for pkg in found_excluded
        println("  - ", pkg)
    end
end

# Check for key computational packages
key_packages = ["ForwardDiff", "HomotopyContinuation", "DynamicPolynomials", "Optim", 
                "BenchmarkTools", "LinearSolve", "SpecialFunctions", "Distributions"]
missing_key = String[]

for pkg_name in key_packages
    if !(pkg_name in pkgs.regular || pkg_name in pkgs.stdlib)
        push!(missing_key, pkg_name)
    end
end

if isempty(missing_key)
    println("\n✅ All key computational packages found!")
else
    println("\n❌ Missing key packages:")
    for pkg in missing_key
        println("  - ", pkg)
    end
end

# Save to file for reference
open("dependency_analysis.txt", "w") do io
    println(io, "Globtim HPC Dependency Analysis - $(Dates.now())")
    println(io, "=" ^ 60)
    println(io, "\nPackage Summary:")
    println(io, "- Standard Library: ", length(pkgs.stdlib))
    println(io, "- Regular Packages: ", length(pkgs.regular))
    println(io, "- Binary Dependencies: ", length(pkgs.binary))
    println(io, "- Total: ", length(pkgs.stdlib) + length(pkgs.regular) + length(pkgs.binary))
    
    println(io, "\nStandard Library Packages:")
    for p in sort(pkgs.stdlib)
        println(io, "  ", p)
    end
    
    println(io, "\nRegular Packages:")
    for p in sort(pkgs.regular)
        println(io, "  ", p)
    end
    
    println(io, "\nBinary Dependencies:")
    for p in sort(pkgs.binary)
        println(io, "  ", p)
    end
    
    if !isempty(found_excluded)
        println(io, "\n⚠️ EXCLUDED PACKAGES FOUND:")
        for pkg in found_excluded
            println(io, "  ", pkg)
        end
    end
    
    if !isempty(missing_key)
        println(io, "\n❌ MISSING KEY PACKAGES:")
        for pkg in missing_key
            println(io, "  ", pkg)
        end
    end
end

println("\n📄 Analysis saved to dependency_analysis.txt")
println("\n=== Dependency Analysis Complete ===")
