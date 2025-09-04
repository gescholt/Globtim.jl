#!/usr/bin/env julia
"""
Julia Environment Validator for HPC Deployment
Issue #27 - Pre-Execution Validation Hook System (Component 2/4)

Purpose: Validate Julia environment and package availability before experiment execution
Critical for preventing 90% of dependency failures on HPC nodes

Author: GlobTim Project
Date: September 4, 2025
"""

using Pkg
using InteractiveUtils

# Configuration for validation
const CRITICAL_PACKAGES = [
    "Globtim",
    "DynamicPolynomials", 
    "HomotopyContinuation",
    "ForwardDiff",
    "LinearAlgebra",
    "DataFrames",
    "StaticArrays",
    "TimerOutputs"
]

const OPTIONAL_PACKAGES = [
    "CSV",
    "JSON",
    "Statistics",
    "Plots",
    "StatsPlots"
]

const VALIDATION_MODES = ["quick", "full", "critical-only"]

struct ValidationResult
    success::Bool
    mode::String
    julia_version::VersionNumber
    project_path::String
    critical_packages::Dict{String, Any}
    optional_packages::Dict{String, Any}
    warnings::Vector{String}
    errors::Vector{String}
    execution_time::Float64
end

"""
    validate_package(pkg_name::String) -> Dict{String, Any}

Validate individual package availability and basic functionality.
Returns dict with status, version, load_time, and any errors.
"""
function validate_package(pkg_name::String)
    result = Dict{String, Any}(
        "name" => pkg_name,
        "available" => false,
        "version" => nothing,
        "load_time" => 0.0,
        "precompiled" => false,
        "errors" => String[]
    )
    
    try
        # Check if package is installed
        pkg_spec = nothing
        try
            pkg_spec = Pkg.dependencies()[Base.UUID(pkg_name)] 
        catch
            # Try alternative method for package lookup
            try
                Pkg.status(pkg_name)
                result["available"] = true
            catch e
                push!(result["errors"], "Package not found in environment: $(e)")
                return result
            end
        end
        
        # Time package loading
        load_start = time()
        try
            if pkg_name == "Globtim"
                # Special handling for main package
                eval(:(using Globtim))
                result["version"] = string(Pkg.project().version)
            else
                eval(Meta.parse("using $pkg_name"))
                # Try to get version if possible
                try
                    mod = eval(Symbol(pkg_name))
                    if hasfield(typeof(mod), :VERSION)
                        result["version"] = string(mod.VERSION)
                    end
                catch
                    # Version extraction failed, not critical
                end
            end
            result["load_time"] = time() - load_start
            result["available"] = true
            
            # Check if precompiled
            result["precompiled"] = Base.isprecompiled(Base.PkgId(pkg_name))
            
        catch e
            result["load_time"] = time() - load_start
            push!(result["errors"], "Failed to load: $(e)")
        end
        
    catch e
        push!(result["errors"], "Package validation error: $(e)")
    end
    
    return result
end

"""
    validate_julia_environment(mode::String = "quick") -> ValidationResult

Main validation function. Modes:
- "quick": Critical packages only, basic checks
- "full": All packages, comprehensive testing
- "critical-only": Only validate Globtim and core dependencies
"""
function validate_julia_environment(mode::String = "quick")
    start_time = time()
    
    println("🔍 Julia Environment Validation Starting...")
    println("Mode: $mode")
    println("Julia Version: $(VERSION)")
    println("Project: $(Pkg.project().path)")
    println("=" ^ 60)
    
    critical_results = Dict{String, Any}()
    optional_results = Dict{String, Any}()
    warnings = String[]
    errors = String[]
    
    # Validate critical packages
    println("\n📦 Validating Critical Packages:")
    for pkg in CRITICAL_PACKAGES
        print("  Testing $pkg... ")
        result = validate_package(pkg)
        critical_results[pkg] = result
        
        if result["available"]
            load_time = round(result["load_time"], digits=2)
            version_str = result["version"] !== nothing ? "v$(result["version"])" : "unknown"
            precomp_str = result["precompiled"] ? "✓" : "⚠"
            println("✅ OK ($version_str, $(load_time)s, precomp:$precomp_str)")
        else
            println("❌ FAILED")
            for error in result["errors"]
                println("    Error: $error")
                push!(errors, "Critical package $pkg: $error")
            end
        end
    end
    
    # Validate optional packages (if not critical-only mode)
    if mode != "critical-only"
        println("\n📦 Validating Optional Packages:")
        for pkg in OPTIONAL_PACKAGES
            print("  Testing $pkg... ")
            result = validate_package(pkg)
            optional_results[pkg] = result
            
            if result["available"]
                load_time = round(result["load_time"], digits=2)
                version_str = result["version"] !== nothing ? "v$(result["version"])" : "unknown"
                println("✅ OK ($version_str, $(load_time)s)")
            else
                println("⚠️  NOT AVAILABLE")
                push!(warnings, "Optional package $pkg not available")
            end
        end
    end
    
    # Environment checks
    println("\n🔧 Environment Checks:")
    
    # Check Julia depot path
    depot_paths = DEPOT_PATH
    println("  Julia Depot Paths: $(length(depot_paths)) paths")
    for (i, path) in enumerate(depot_paths)
        exists = isdir(path)
        println("    $i. $path $(exists ? "✅" : "❌")")
        if !exists
            push!(warnings, "Depot path does not exist: $path")
        end
    end
    
    # Check project environment
    project_file = Pkg.project().path
    manifest_file = dirname(project_file) * "/Manifest.toml"
    
    println("  Project.toml: $(isfile(project_file) ? "✅" : "❌") $project_file")
    println("  Manifest.toml: $(isfile(manifest_file) ? "✅" : "❌") $manifest_file")
    
    if !isfile(project_file)
        push!(errors, "Project.toml not found: $project_file")
    end
    
    # Full mode additional checks
    if mode == "full"
        println("\n🧪 Extended Validation (Full Mode):")
        
        # Test basic mathematical operations
        print("  Basic Math Operations... ")
        try
            using LinearAlgebra
            A = rand(10, 10)
            b = rand(10)
            x = A \ b
            norm(A * x - b) < 1e-10 || error("Linear solve failed")
            println("✅")
        catch e
            println("❌")
            push!(errors, "Basic math test failed: $e")
        end
        
        # Test Globtim basic functionality (if available)
        if critical_results["Globtim"]["available"]
            print("  Globtim Basic Test... ")
            try
                # Test basic Globtim functionality
                using Globtim
                # Simple test - check if basic functions are accessible
                if isdefined(Globtim, :test_input) && isdefined(Globtim, :Constructor)
                    println("✅")
                else
                    println("⚠️")
                    push!(warnings, "Globtim basic functions not fully accessible")
                end
            catch e
                println("❌")
                push!(errors, "Globtim basic test failed: $e")
            end
        end
    end
    
    execution_time = time() - start_time
    
    # Summary
    println("\n" * "=" ^ 60)
    println("📊 Validation Summary:")
    
    critical_ok = all(r["available"] for r in values(critical_results))
    critical_count = sum(r["available"] for r in values(critical_results))
    total_critical = length(critical_results)
    
    println("  Critical Packages: $critical_count/$total_critical $(critical_ok ? "✅" : "❌")")
    
    if !isempty(optional_results)
        optional_count = sum(r["available"] for r in values(optional_results))
        total_optional = length(optional_results)
        println("  Optional Packages: $optional_count/$total_optional")
    end
    
    println("  Warnings: $(length(warnings))")
    println("  Errors: $(length(errors))")
    println("  Execution Time: $(round(execution_time, digits=2))s")
    
    success = critical_ok && isempty(errors)
    
    if success
        println("🎉 Environment Validation PASSED")
    else
        println("❌ Environment Validation FAILED")
        println("\nErrors:")
        for error in errors
            println("  • $error")
        end
    end
    
    if !isempty(warnings)
        println("\nWarnings:")
        for warning in warnings
            println("  • $warning")
        end
    end
    
    return ValidationResult(
        success,
        mode,
        VERSION,
        project_file,
        critical_results,
        optional_results,
        warnings,
        errors,
        execution_time
    )
end

"""
    save_validation_report(result::ValidationResult, output_dir::String)

Save detailed validation report to files.
"""
function save_validation_report(result::ValidationResult, output_dir::String)
    mkpath(output_dir)
    
    # JSON-like summary
    summary_file = joinpath(output_dir, "validation_summary.txt")
    open(summary_file, "w") do io
        println(io, "Julia Environment Validation Report")
        println(io, "Generated: $(now())")
        println(io, "Mode: $(result.mode)")
        println(io, "Success: $(result.success)")
        println(io, "Julia Version: $(result.julia_version)")
        println(io, "Project: $(result.project_path)")
        println(io, "Execution Time: $(result.execution_time)s")
        println(io, "")
        
        println(io, "Critical Packages:")
        for (name, info) in result.critical_packages
            status = info["available"] ? "✅ OK" : "❌ FAILED"
            version = info["version"] !== nothing ? "v$(info["version"])" : "unknown"
            println(io, "  $name: $status ($version)")
        end
        
        if !isempty(result.optional_packages)
            println(io, "")
            println(io, "Optional Packages:")
            for (name, info) in result.optional_packages
                status = info["available"] ? "✅ OK" : "⚠️  NOT AVAILABLE"
                println(io, "  $name: $status")
            end
        end
        
        if !isempty(result.errors)
            println(io, "")
            println(io, "Errors:")
            for error in result.errors
                println(io, "  • $error")
            end
        end
        
        if !isempty(result.warnings)
            println(io, "")
            println(io, "Warnings:")
            for warning in result.warnings
                println(io, "  • $warning")
            end
        end
    end
    
    println("📄 Validation report saved to: $summary_file")
end

# Main execution (if run directly)
if abspath(PROGRAM_FILE) == @__FILE__
    # Parse command line arguments
    mode = length(ARGS) > 0 ? ARGS[1] : "quick"
    output_dir = length(ARGS) > 1 ? ARGS[2] : "."
    
    if !(mode in VALIDATION_MODES)
        println("❌ Invalid mode: $mode")
        println("Valid modes: $(join(VALIDATION_MODES, ", "))")
        exit(1)
    end
    
    try
        result = validate_julia_environment(mode)
        
        if output_dir != "."
            save_validation_report(result, output_dir)
        end
        
        # Exit with appropriate code
        exit(result.success ? 0 : 1)
        
    catch e
        println("❌ Validation failed with exception: $e")
        exit(2)
    end
end