"""
Unified Configuration Module

Consolidates configuration management from:
- config.jl (31 LOC) - TOML function parameters
- ConfigValidation.jl (521 LOC) - JSON schema validation
- parameter_tracking_config.jl (972 LOC) - Parameter tracking structures

Total consolidation: 1,524 LOC → ~1,100 LOC (28% reduction)

This module provides:
- Configuration structure definitions
- Schema validation
- TOML/JSON parsing
- Semantic validation
- Experiment configuration management

Author: GlobTim Project
Date: February 2026
"""

using JSON3
using TOML

# Use canonical ValidationResult from data_structures.jl
# (Defined when this file is included in Globtim.jl)

# ============================================================================
# EXCEPTION TYPES
# ============================================================================

"""
    ConfigError <: Exception

Base exception type for configuration errors.
"""
abstract type ConfigError <: Exception end

struct ConfigValidationError <: ConfigError
    message::String
end

# Note: SchemaValidationError is defined in validation.jl (DataValidationError hierarchy)
# Config-level schema validation uses ConfigValidationError instead.

struct ConfigParseError <: ConfigError
    message::String
    filepath::Union{String, Nothing}
end

# ============================================================================
# BASIC CONFIGURATION STRUCTURES
# ============================================================================

"""
    FunctionParameters

Simple function parameters loaded from TOML.
Legacy structure for backward compatibility.
"""
struct FunctionParameters
    dim::Int
    center::Vector{Float64}
    num_samples::Int
    sample_range::Float64
    tolerance::Union{Float64, Nothing}
    delta::Union{Float64, Nothing}
    alpha::Union{Float64, Nothing}
end

function FunctionParameters(config::Dict)
    FunctionParameters(
        config["dim"],
        config["center"],
        config["num_samples"],
        config["sample_range"],
        get(config, "tolerance", nothing),
        get(config, "delta", nothing),
        get(config, "alpha", nothing)
    )
end

"""
    FunctionConfig

Configuration for a test function.
"""
struct FunctionConfig
    name::String
    dimension::Int
    parameters::Union{Dict{String, Any}, Nothing}
end

# ============================================================================
# EXPERIMENT CONFIGURATION STRUCTURES
# ============================================================================

"""
    TestInputParams

Parameters for test_input construction.
"""
struct TestInputParams
    center::Vector{Float64}
    GN::Union{Int, Nothing}
    sample_range::Union{Float64, Vector{Float64}}
    alpha::Union{Float64, Nothing}
    degree::Int
    tolerance::Union{Float64, Nothing}
    precision_params::Union{Dict{String, Any}, Nothing}
    noise_params::Union{Dict{String, Any}, Nothing}
end

"""
    ConstructorParams

Parameters for polynomial constructor.
"""
struct ConstructorParams
    precision::String
    basis::String
    normalized::Bool
    power_of_two_denom::Union{Bool, Nothing}
end

"""
    AnalysisParams

Parameters for critical point analysis.
"""
struct AnalysisParams
    enable_hessian::Bool
    tol_dist::Float64

    # Tracking flags (Issue #124: metadata-driven plotting)
    track_convergence::Bool
    track_gradient_norms::Bool
    track_distance_to_solutions::Bool
    track_performance_metrics::Bool
end

"""
    OutputSettings

Settings for experiment output.
"""
struct OutputSettings
    save_intermediate::Bool
    output_dir::String
    result_format::String
end

"""
    ExperimentConfig

Complete configuration for a standard experiment.
"""
struct ExperimentConfig
    function_config::FunctionConfig
    test_input_params::TestInputParams
    constructor_params::ConstructorParams
    analysis_params::AnalysisParams
    output_settings::Union{OutputSettings, Nothing}
end

# ============================================================================
# ODE EXPERIMENT CONFIGURATION STRUCTURES
# ============================================================================

"""
    ODESolverConfig

Configuration for ODE solver settings.
"""
struct ODESolverConfig
    method::String  # e.g., "Rosenbrock23", "Tsit5", "Vern9"
    abstol::Float64
    reltol::Float64
    time_span::Tuple{Float64, Float64}
    saveat::Union{Float64, Vector{Float64}, Nothing}
    maxiters::Union{Int, Nothing}
end

"""
    DomainConfig

Configuration for parameter domain specification with multiple strategies.

Strategies:
- "centered_at_true": Domain centered at true parameter values with ± range
- "explicit_bounds": Explicit lower/upper bounds per parameter
- "random_offset": True parameters + random direction with specified offset
"""
struct DomainConfig
    strategy::String  # "centered_at_true", "explicit_bounds", "random_offset"

    # For "centered_at_true" strategy
    range::Union{Float64, Vector{Float64}, Nothing}  # Scalar or per-parameter

    # For "explicit_bounds" strategy
    bounds::Union{Vector{Tuple{Float64, Float64}}, Nothing}  # [(low, high), ...]

    # For "random_offset" strategy
    offset_length::Union{Float64, Nothing}
    random_seed::Union{Int, Nothing}
end

"""
    ModelConfig

Configuration for ODE model specification.
"""
struct ModelConfig
    name::String  # Model identifier (for logging/tracking)
    dimension::Int  # Number of parameters

    # For synthetic data generation
    true_parameters::Union{Vector{Float64}, Nothing}
    initial_conditions::Union{Vector{Float64}, Nothing}

    # Optional: fixed parameters (not being optimized)
    fixed_parameters::Union{Dict{String, Float64}, Nothing}
end

"""
    ComputationConfig

Extended computation configuration supporting multiple degrees and precision modes.
"""
struct ComputationConfig
    samples_per_dim::Int  # GN
    degrees::Vector{Int}  # List of degrees to test (e.g., [4, 5, 6, ..., 12])

    # Precision mode: single or comparison
    precision_mode::Union{String, Vector{String}}  # "float64", "adaptive", or ["float64", "adaptive"]

    # Tracker options per precision mode
    tracker_options::Union{Dict{String, Any}, Nothing}

    # Time limits
    max_time_per_degree::Union{Float64, Nothing}  # seconds
end

"""
    ODEExperimentConfig

Extended configuration for ODE-based experiments.
"""
struct ODEExperimentConfig
    model_config::ModelConfig
    domain_config::DomainConfig
    computation_config::ComputationConfig
    solver_config::ODESolverConfig
    constructor_params::ConstructorParams
    analysis_params::AnalysisParams
    output_settings::Union{OutputSettings, Nothing}
end

# ============================================================================
# VALIDATION CONSTANTS
# ============================================================================

const VALID_PRECISION_TYPES = [
    "Float64Precision",
    "AdaptivePrecision",
    "RationalPrecision",
    "BigFloatPrecision",
    "BigIntPrecision"
]
const VALID_BASIS_TYPES = ["chebyshev", "legendre"]
const VALID_RESULT_FORMATS = ["json", "hdf5"]
const VALID_DOMAIN_STRATEGIES = ["centered_at_true", "explicit_bounds", "random_offset"]
const VALID_ODE_SOLVERS = [
    "Rosenbrock23", "Rodas4", "Rodas5", "Rodas5P",  # Rosenbrock methods
    "Tsit5", "Vern7", "Vern8", "Vern9",             # Runge-Kutta methods
    "TRBDF2", "KenCarp4", "KenCarp5"                # SDIRK methods
]
const VALID_PRECISION_MODES = ["float64", "adaptive", "Float64Precision", "AdaptivePrecision"]

# ============================================================================
# TOML LOADING (from original config.jl)
# ============================================================================

"""
    get_config_path() -> String

Get path to the TOML configuration file.
"""
function get_config_path()
    joinpath(dirname(@__DIR__), "data", "config.toml")
end

"""
    load_function_params(func_name::String) -> FunctionParameters

Load function parameters from TOML configuration.
"""
function load_function_params(func_name::String)
    config_path = get_config_path()
    params = TOML.parsefile(config_path)
    FunctionParameters(params[func_name])
end

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

"""
    validate_precision_type(precision::String) -> Bool

Validate that precision type is supported.
"""
function validate_precision_type(precision::String)
    precision in VALID_PRECISION_TYPES
end

"""
    validate_basis_type(basis::String) -> Bool

Validate that basis type is supported.
"""
function validate_basis_type(basis::String)
    basis in VALID_BASIS_TYPES
end

"""
    validate_model_config_dict(model_config) -> Vector

Validate model_config section from JSON.
"""
function validate_model_config_dict(model_config)
    errors = []

    # Check required fields
    name_key = haskey(model_config, :name) ? :name : "name"
    dim_key = haskey(model_config, :dimension) ? :dimension : "dimension"
    param_key = haskey(model_config, :true_parameters) ? :true_parameters : "true_parameters"

    if !haskey(model_config, name_key) && !haskey(model_config, string(name_key))
        push!(errors, (
            field = "model_config.name",
            message = "Required field is missing",
            value = nothing
        ))
    else
        name = get(model_config, name_key, get(model_config, string(name_key), nothing))
        valid_names = ["lotka_volterra_2d", "lotka_volterra_4d", "fitzhugh_nagumo"]
        if !isnothing(name) && !(name in valid_names)
            push!(errors, (
                field = "model_config.name",
                message = "Must be one of: $(join(valid_names, ", "))",
                value = name
            ))
        end
    end

    if !haskey(model_config, dim_key) && !haskey(model_config, string(dim_key))
        push!(errors, (
            field = "model_config.dimension",
            message = "Required field is missing",
            value = nothing
        ))
    else
        dim = get(model_config, dim_key, get(model_config, string(dim_key), nothing))
        if !isnothing(dim)
            if !isa(dim, Integer)
                push!(errors, (
                    field = "model_config.dimension",
                    message = "Must be an integer",
                    value = dim
                ))
            elseif dim < 1 || dim > 10
                push!(errors, (
                    field = "model_config.dimension",
                    message = "Must be between 1 and 10",
                    value = dim
                ))
            end
        end
    end

    if !haskey(model_config, param_key) && !haskey(model_config, string(param_key))
        push!(errors, (
            field = "model_config.true_parameters",
            message = "Required field is missing",
            value = nothing
        ))
    else
        params = get(model_config, param_key, get(model_config, string(param_key), nothing))
        if !isnothing(params)
            if !isa(params, AbstractArray)
                push!(errors, (
                    field = "model_config.true_parameters",
                    message = "Must be an array",
                    value = params
                ))
            elseif isempty(params)
                push!(errors, (
                    field = "model_config.true_parameters",
                    message = "Must have at least one element",
                    value = params
                ))
            end
        end
    end

    return errors
end

"""
    validate_numerical_params_dict(num_params) -> Vector

Validate numerical_params section from JSON.
"""
function validate_numerical_params_dict(num_params)
    errors = []

    # Check GN
    gn_key = haskey(num_params, :GN) ? :GN : "GN"
    if !haskey(num_params, gn_key) && !haskey(num_params, string(gn_key))
        push!(errors, (
            field = "numerical_params.GN",
            message = "Required field is missing",
            value = nothing
        ))
    else
        GN = get(num_params, gn_key, get(num_params, string(gn_key), nothing))
        if !isnothing(GN)
            if !isa(GN, Integer)
                push!(errors, (
                    field = "numerical_params.GN",
                    message = "Must be an integer",
                    value = GN
                ))
            elseif GN < 4 || GN > 20
                push!(errors, (
                    field = "numerical_params.GN",
                    message = "Must be between 4 and 20",
                    value = GN
                ))
            end
        end
    end

    # Check degree_range
    deg_key = haskey(num_params, :degree_range) ? :degree_range : "degree_range"
    if !haskey(num_params, deg_key) && !haskey(num_params, string(deg_key))
        push!(errors, (
            field = "numerical_params.degree_range",
            message = "Required field is missing",
            value = nothing
        ))
    else
        deg_range = get(num_params, deg_key, get(num_params, string(deg_key), nothing))
        if !isnothing(deg_range)
            if !isa(deg_range, AbstractArray) || length(deg_range) != 2
                push!(errors, (
                    field = "numerical_params.degree_range",
                    message = "Must be an array of exactly 2 integers",
                    value = deg_range
                ))
            elseif any(d -> !isa(d, Integer) || d < 1, deg_range)
                push!(errors, (
                    field = "numerical_params.degree_range",
                    message = "All elements must be integers >= 1",
                    value = deg_range
                ))
            end
        end
    end

    return errors
end

"""
    validate_domain_config_dict(domain_config) -> Vector

Validate domain_config section from JSON.
"""
function validate_domain_config_dict(domain_config)
    errors = []

    # Check ranges
    ranges_key = haskey(domain_config, :ranges) ? :ranges : "ranges"
    if !haskey(domain_config, ranges_key) && !haskey(domain_config, string(ranges_key))
        push!(errors, (
            field = "domain_config.ranges",
            message = "Required field is missing",
            value = nothing
        ))
    else
        ranges = get(domain_config, ranges_key, get(domain_config, string(ranges_key), nothing))
        if !isnothing(ranges)
            if !isa(ranges, AbstractArray)
                push!(errors, (
                    field = "domain_config.ranges",
                    message = "Must be an array",
                    value = ranges
                ))
            elseif isempty(ranges)
                push!(errors, (
                    field = "domain_config.ranges",
                    message = "Must have at least one element",
                    value = ranges
                ))
            elseif any(r -> !isa(r, Number) || r <= 0, ranges)
                push!(errors, (
                    field = "domain_config.ranges",
                    message = "All elements must be positive numbers",
                    value = ranges
                ))
            end
        end
    end

    return errors
end

"""
    validate_config_schema(config) -> Vector

Validate configuration against schema structure.
"""
function validate_config_schema(config)
    errors = []

    # Check required top-level fields
    required_fields = ["model_config", "numerical_params", "domain_config"]
    for field in required_fields
        if !haskey(config, field) && !haskey(config, Symbol(field))
            push!(errors, (
                field = field,
                message = "Required field is missing",
                value = nothing
            ))
        end
    end

    # Return early if required fields missing
    if !isempty(errors)
        return errors
    end

    # Validate model_config
    model_config = get(config, :model_config, get(config, "model_config", nothing))
    if !isnothing(model_config)
        append!(errors, validate_model_config_dict(model_config))
    end

    # Validate numerical_params
    num_params = get(config, :numerical_params, get(config, "numerical_params", nothing))
    if !isnothing(num_params)
        append!(errors, validate_numerical_params_dict(num_params))
    end

    # Validate domain_config
    domain_config = get(config, :domain_config, get(config, "domain_config", nothing))
    if !isnothing(domain_config)
        append!(errors, validate_domain_config_dict(domain_config))
    end

    return errors
end

"""
    validate_config_semantics(config) -> Vector

Perform semantic validation beyond schema constraints.
"""
function validate_config_semantics(config)
    errors = []

    # Check dimension matches parameter count
    if haskey(config, :model_config) || haskey(config, "model_config")
        model_config = get(config, :model_config, get(config, "model_config", nothing))
        if !isnothing(model_config)
            dim_key = haskey(model_config, :dimension) ? :dimension : "dimension"
            param_key = haskey(model_config, :true_parameters) ? :true_parameters : "true_parameters"

            dim = get(model_config, dim_key, nothing)
            params = get(model_config, param_key, nothing)

            if !isnothing(dim) && !isnothing(params)
                if length(params) != dim
                    push!(errors, (
                        field = "model_config.true_parameters",
                        message = "Length must match dimension ($dim), got $(length(params))",
                        value = params
                    ))
                end
            end
        end
    end

    # Check degree range is valid
    if haskey(config, :numerical_params) || haskey(config, "numerical_params")
        num_params = get(config, :numerical_params, get(config, "numerical_params", nothing))
        if !isnothing(num_params)
            deg_key = haskey(num_params, :degree_range) ? :degree_range : "degree_range"
            deg_range = get(num_params, deg_key, nothing)

            if !isnothing(deg_range) && length(deg_range) >= 2
                if deg_range[1] > deg_range[2]
                    push!(errors, (
                        field = "numerical_params.degree_range",
                        message = "Min degree ($(deg_range[1])) must be ≤ max degree ($(deg_range[2]))",
                        value = deg_range
                    ))
                end
            end
        end
    end

    # Warn about large grid sizes
    if (haskey(config, :numerical_params) || haskey(config, "numerical_params")) &&
       (haskey(config, :model_config) || haskey(config, "model_config"))

        num_params = get(config, :numerical_params, get(config, "numerical_params", nothing))
        model_config = get(config, :model_config, get(config, "model_config", nothing))

        if !isnothing(num_params) && !isnothing(model_config)
            gn_key = haskey(num_params, :GN) ? :GN : "GN"
            dim_key = haskey(model_config, :dimension) ? :dimension : "dimension"

            GN = get(num_params, gn_key, nothing)
            dim = get(model_config, dim_key, nothing)

            if !isnothing(GN) && !isnothing(dim)
                total_points = GN^dim
                if total_points > 100_000
                    @warn "Large grid size: GN^dim = $total_points points (GN=$GN, dim=$dim)"
                end
            end
        end
    end

    return errors
end

"""
    validate_config_dict(config::Dict) -> ValidationResult{Dict}

Validate an experiment configuration dictionary against the schema
and perform semantic validation.

Uses canonical ValidationResult from data_structures.jl.
"""
function validate_config_dict(config::Dict)
    errors = []

    # Convert to JSON3 object for consistent handling
    config_json = JSON3.read(JSON3.write(config))

    # Schema validation
    schema_errors = validate_config_schema(config_json)
    append!(errors, schema_errors)

    # Only proceed with semantic validation if schema is valid
    if isempty(schema_errors)
        semantic_errors = validate_config_semantics(config_json)
        append!(errors, semantic_errors)
    end

    success = isempty(errors)
    quality_score = success ? 100.0 : max(0.0, 100.0 - length(errors) * 10.0)

    return ValidationResult{Dict}(
        success,
        success ? config : nothing,
        errors,
        String[],
        quality_score
    )
end

"""
    validate_config_file(config_path::String) -> ValidationResult{Dict}

Validate an experiment configuration file.
"""
function validate_config_file(config_path::String)
    if !isfile(config_path)
        return ValidationResult{Dict}(false, nothing, [
            (field = "file", message = "Configuration file not found: $config_path", value = config_path)
        ], [], 0.0)
    end

    try
        config_json = JSON3.read(read(config_path, String))
        config_dict = Dict(pairs(config_json))
        return validate_config_dict(config_dict)
    catch e
        return ValidationResult{Dict}(false, nothing, [
            (field = "file", message = "Failed to parse JSON: $e", value = config_path)
        ], [], 0.0)
    end
end

"""
    validate_setup_config(config_dict::Dict) -> ValidationResult{Dict}

Validate a setup_experiments.jl style configuration.
This is a lighter validation for configs generated by setup scripts.
"""
function validate_setup_config(config_dict::Dict)
    errors = []

    # Validate GN range
    if haskey(config_dict, "GN")
        GN = config_dict["GN"]
        if !isa(GN, Integer)
            push!(errors, (field = "GN", message = "Must be an integer", value = GN))
        elseif GN < 4 || GN > 20
            push!(errors, (field = "GN", message = "Must be between 4 and 20", value = GN))
        end
    end

    # Validate degree range
    if haskey(config_dict, "degree_min") && haskey(config_dict, "degree_max")
        deg_min = config_dict["degree_min"]
        deg_max = config_dict["degree_max"]

        if !isa(deg_min, Integer) || !isa(deg_max, Integer)
            push!(errors, (
                field = "degree_range",
                message = "degree_min and degree_max must be integers",
                value = (deg_min, deg_max)
            ))
        elseif deg_min > deg_max
            push!(errors, (
                field = "degree_range",
                message = "degree_min ($deg_min) must be ≤ degree_max ($deg_max)",
                value = (deg_min, deg_max)
            ))
        end
    end

    # Validate domain_range (must be positive)
    if haskey(config_dict, "domain_range")
        dr = config_dict["domain_range"]
        if !isa(dr, Number) || dr <= 0
            push!(errors, (
                field = "domain_range",
                message = "Must be a positive number",
                value = dr
            ))
        end
    end

    # Validate p_true if model dimension can be inferred
    if haskey(config_dict, "p_true") && haskey(config_dict, "model_func")
        p_true = config_dict["p_true"]
        model_func = config_dict["model_func"]

        # Extract dimension from model name (e.g., "define_daisy_ex3_model_4D" -> 4)
        dim_match = match(r"(\d+)D", model_func)
        if !isnothing(dim_match)
            expected_dim = parse(Int, dim_match.captures[1])
            if length(p_true) != expected_dim
                push!(errors, (
                    field = "p_true",
                    message = "Length must match model dimension ($expected_dim), got $(length(p_true))",
                    value = p_true
                ))
            end
        end
    end

    success = isempty(errors)
    quality_score = success ? 100.0 : max(0.0, 100.0 - length(errors) * 10.0)

    return ValidationResult{Dict}(success, success ? config_dict : nothing, errors, String[], quality_score)
end

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

"""
    print_validation_errors(result::ValidationResult)

Print validation errors in a readable format.
"""
function print_validation_errors(result::ValidationResult)
    if result.success
        println("✅ Configuration is valid")
        return
    end

    println("❌ Configuration validation failed:")
    println()

    for err in result.errors
        println("  Field: $(err.field)")
        println("  Error: $(err.message)")
        if !isnothing(err.value)
            println("  Value: $(err.value)")
        end
        println()
    end
end

# ============================================================================
# EXPORTS
# ============================================================================

# Configuration structures
export FunctionParameters, FunctionConfig
export TestInputParams, ConstructorParams, AnalysisParams, OutputSettings
export ExperimentConfig
export ODESolverConfig, DomainConfig, ModelConfig, ComputationConfig, ODEExperimentConfig

# Exception types
export ConfigError, ConfigValidationError, ConfigParseError

# Validation constants
export VALID_PRECISION_TYPES, VALID_BASIS_TYPES, VALID_RESULT_FORMATS
export VALID_DOMAIN_STRATEGIES, VALID_ODE_SOLVERS, VALID_PRECISION_MODES

# TOML loading functions
export get_config_path, load_function_params

# Validation functions
export validate_precision_type, validate_basis_type
export validate_config_dict, validate_config_file, validate_setup_config
export print_validation_errors
