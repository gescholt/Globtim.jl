#!/usr/bin/env julia

"""
    validate_config.jl

Standalone tool for validating experiment configuration files.

Usage:
    julia tools/validate_config.jl <config_file.json>

Example:
    julia tools/validate_config.jl experiments/lv4d_study/config.json
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Globtim

function main()
    if length(ARGS) < 1
        println("Usage: julia validate_config.jl <config_file.json>")
        println()
        println("Example:")
        println("  julia validate_config.jl experiments/lv4d_study/config.json")
        exit(1)
    end

    config_path = ARGS[1]

    if !isfile(config_path)
        println("❌ Error: File not found: $config_path")
        exit(1)
    end

    println("Validating configuration: $config_path")
    println()

    result = Globtim.ConfigValidation.validate_config_file(config_path)

    Globtim.ConfigValidation.print_validation_errors(result)

    if !result.valid
        exit(1)
    end

    exit(0)
end

main()
