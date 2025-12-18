#!/usr/bin/env julia

"""
Project.toml Circular Dependency Validator

Validates Project.toml for circular dependency prevention rules:
1. Extension-WeakDep Consistency: Extensions only reference weakdeps
2. No Dual Dependencies: No package in both [deps] and [weakdeps]
3. Extension Configuration: Proper extension setup

Usage:
    julia tools/validation/validate_project_toml.jl [path/to/Project.toml]
"""

using TOML
using UUIDs

struct ValidationError
    rule::String
    message::String
    severity::Symbol  # :error, :warning, :info
end

function validate_project_toml(project_path::String="Project.toml")
    if !isfile(project_path)
        return [ValidationError("file_existence", "Project.toml not found at: $project_path", :error)]
    end

    try
        project = TOML.parsefile(project_path)
        return validate_project_structure(project, project_path)
    catch e
        return [ValidationError("parsing", "Failed to parse Project.toml: $e", :error)]
    end
end

function validate_project_structure(project::Dict, project_path::String)
    errors = ValidationError[]

    # Extract sections
    deps = get(project, "deps", Dict())
    weakdeps = get(project, "weakdeps", Dict())
    extensions = get(project, "extensions", Dict())

    # Rule 1: Extension-WeakDep Consistency
    append!(errors, validate_extension_weakdep_consistency(extensions, weakdeps, deps))

    # Rule 2: No Dual Dependencies
    append!(errors, validate_no_dual_dependencies(deps, weakdeps))

    # Rule 3: Extension Configuration
    append!(errors, validate_extension_configuration(extensions, weakdeps))

    # Rule 4: Heavy Dependencies Check
    append!(errors, validate_heavy_dependencies(deps))

    return errors
end

function validate_extension_weakdep_consistency(extensions::Dict, weakdeps::Dict, deps::Dict)
    errors = ValidationError[]

    for (ext_name, ext_deps) in extensions
        # Handle both string and array formats
        deps_list = isa(ext_deps, String) ? [ext_deps] : ext_deps

        for dep in deps_list
            if haskey(deps, dep)
                push!(errors, ValidationError(
                    "extension_weakdep_consistency",
                    "Extension '$ext_name' references '$dep' which is in [deps]. Move '$dep' to [weakdeps].",
                    :error
                ))
            elseif !haskey(weakdeps, dep)
                push!(errors, ValidationError(
                    "extension_weakdep_consistency",
                    "Extension '$ext_name' references '$dep' which is not in [weakdeps]. Add '$dep' to [weakdeps].",
                    :error
                ))
            end
        end
    end

    return errors
end

function validate_no_dual_dependencies(deps::Dict, weakdeps::Dict)
    errors = ValidationError[]

    for pkg_name in keys(deps)
        if haskey(weakdeps, pkg_name)
            push!(errors, ValidationError(
                "no_dual_dependencies",
                "Package '$pkg_name' appears in both [deps] and [weakdeps]. Remove from one section.",
                :error
            ))
        end
    end

    return errors
end

function validate_extension_configuration(extensions::Dict, weakdeps::Dict)
    errors = ValidationError[]

    # Check if we have extensions but no weakdeps
    if !isempty(extensions) && isempty(weakdeps)
        push!(errors, ValidationError(
            "extension_configuration",
            "Extensions defined but no [weakdeps] section. Extensions require weakdeps.",
            :warning
        ))
    end

    # Check for orphaned weakdeps (weakdeps not used in extensions)
    used_weakdeps = Set{String}()
    for ext_deps in values(extensions)
        deps_list = isa(ext_deps, String) ? [ext_deps] : ext_deps
        union!(used_weakdeps, deps_list)
    end

    for pkg_name in keys(weakdeps)
        if !(pkg_name in used_weakdeps)
            push!(errors, ValidationError(
                "extension_configuration",
                "Weakdep '$pkg_name' not used in any extension. Consider creating extension or moving to [deps].",
                :info
            ))
        end
    end

    return errors
end

function validate_heavy_dependencies(deps::Dict)
    errors = ValidationError[]

    # Known heavy dependencies that should be in weakdeps/extensions
    heavy_packages = [
        "Makie", "CairoMakie", "GLMakie", "WGLMakie",
        "Plots", "PlotlyJS", "PyPlot", "GR",
        "Genie", "HTTP", "WebSockets",
        "DataStructures",  # Sometimes heavy
        "CSV"  # Can be heavy for I/O intensive packages
    ]

    for pkg_name in keys(deps)
        if pkg_name in heavy_packages
            push!(errors, ValidationError(
                "heavy_dependencies",
                "Heavy dependency '$pkg_name' in [deps]. Consider moving to [weakdeps] with extension.",
                :warning
            ))
        end
    end

    return errors
end

function print_validation_results(errors::Vector{ValidationError}, project_path::String)
    if isempty(errors)
        printstyled("✅ PASSED: Project.toml validation successful for $project_path\n", color=:green, bold=true)
        return true
    end

    # Group by severity
    error_count = sum(e.severity == :error for e in errors)
    warning_count = sum(e.severity == :warning for e in errors)
    info_count = sum(e.severity == :info for e in errors)

    println("📋 Project.toml Validation Results for $project_path")
    println("=" ^ 60)

    if error_count > 0
        printstyled("❌ ERRORS ($error_count):\n", color=:red, bold=true)
        for error in filter(e -> e.severity == :error, errors)
            printstyled("  • [$(error.rule)] $(error.message)\n", color=:red)
        end
        println()
    end

    if warning_count > 0
        printstyled("⚠️  WARNINGS ($warning_count):\n", color=:yellow, bold=true)
        for warning in filter(e -> e.severity == :warning, errors)
            printstyled("  • [$(warning.rule)] $(warning.message)\n", color=:yellow)
        end
        println()
    end

    if info_count > 0
        printstyled("ℹ️  INFO ($info_count):\n", color=:cyan, bold=true)
        for info in filter(e -> e.severity == :info, errors)
            printstyled("  • [$(info.rule)] $(info.message)\n", color=:cyan)
        end
        println()
    end

    # Summary
    if error_count > 0
        printstyled("💥 VALIDATION FAILED: $error_count error(s) must be fixed\n", color=:red, bold=true)
        return false
    else
        printstyled("✅ VALIDATION PASSED: Only warnings/info, no blocking errors\n", color=:green, bold=true)
        return true
    end
end

function main()
    project_path = length(ARGS) > 0 ? ARGS[1] : "Project.toml"

    println("🔍 Validating Project.toml for circular dependency prevention...")
    println("📁 Path: $project_path")
    println()

    errors = validate_project_toml(project_path)
    success = print_validation_results(errors, project_path)

    # Exit with error code if validation failed
    if !success
        exit(1)
    end
end

# Run validation if called as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end