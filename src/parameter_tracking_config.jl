# Parameter Tracking Configuration Module
# Provides JSON/TOML schema validation and configuration parsing for the parameter tracking infrastructure
#
# Extended for ODE experiment campaigns (Phase 1):
# - ODESolverConfig: Solver settings for ODE integration
# - DomainConfig: Flexible domain specification strategies
# - Support for multiple degrees and precision modes
# - TOML parsing alongside JSON

using JSON3
using TOML

# Exception types for configuration validation
struct ConfigValidationError <: Exception
    message::String
end

struct SchemaValidationError <: Exception
    message::String
    field::String
    value::Any
end

# Configuration structure types
struct FunctionConfig
    name::String
    dimension::Int
    parameters::Union{Dict{String, Any}, Nothing}
end

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

struct ConstructorParams
    precision::String
    basis::String
    normalized::Bool
    power_of_two_denom::Union{Bool, Nothing}
end

struct SparsificationParams
    enabled::Bool
    threshold::Union{Float64, Nothing}
    method::Union{String, Nothing}
end

struct AnalysisParams
    enable_hessian::Bool
    tol_dist::Float64
    sparsification::Union{SparsificationParams, Nothing}

    # Tracking flags (Issue #124: metadata-driven plotting)
    # These activate data collection during experiment execution
    track_convergence::Bool
    track_gradient_norms::Bool
    track_distance_to_solutions::Bool
    track_performance_metrics::Bool
end

struct OutputSettings
    save_intermediate::Bool
    output_dir::String
    result_format::String
    # Note: save_plots removed - visualization is a post-processing concern (Issue #124)
end

# ============================================================================
# Phase 1 Extensions: ODE Experiment Configuration
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
Model itself is provided as input; this contains auxiliary model information.
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

struct ExperimentConfig
    function_config::FunctionConfig
    test_input_params::TestInputParams
    constructor_params::ConstructorParams
    analysis_params::AnalysisParams
    output_settings::Union{OutputSettings, Nothing}
end

"""
    ODEExperimentConfig

Extended configuration for ODE-based experiments.
Supersedes ExperimentConfig for ODE workflows.
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

# Validation constants
const VALID_PRECISION_TYPES = [
    "Float64Precision",
    "AdaptivePrecision",
    "RationalPrecision",
    "BigFloatPrecision",
    "BigIntPrecision"
]
const VALID_BASIS_TYPES = ["chebyshev", "legendre"]
const VALID_RESULT_FORMATS = ["json", "hdf5"]
const VALID_SPARSIFICATION_METHODS = ["l2_norm", "absolute", "relative"]

# Phase 1 Extensions: ODE-specific validation constants
const VALID_DOMAIN_STRATEGIES = ["centered_at_true", "explicit_bounds", "random_offset"]
const VALID_ODE_SOLVERS = [
    "Rosenbrock23", "Rodas4", "Rodas5", "Rodas5P",  # Rosenbrock methods
    "Tsit5", "Vern7", "Vern8", "Vern9",             # Runge-Kutta methods
    "TRBDF2", "KenCarp4", "KenCarp5"                # SDIRK methods
]
const VALID_PRECISION_MODES = ["float64", "adaptive", "Float64Precision", "AdaptivePrecision"]

"""
    validate_precision_type(precision::String) -> Bool

Validate that precision type is one of the supported GlobTim precision types.
"""
function validate_precision_type(precision::String)
    return precision ∈ VALID_PRECISION_TYPES
end

"""
    validate_basis_type(basis::String) -> Bool

Validate that basis type is one of the supported polynomial basis types.
"""
function validate_basis_type(basis::String)
    return basis ∈ VALID_BASIS_TYPES
end

"""
    validate_function_config(config) -> FunctionConfig

Validate function configuration section and return structured object.
"""
function validate_function_config(config)
    # Check required fields
    if !haskey(config, :name)
        throw(
            SchemaValidationError(
                "Missing required field 'name'",
                "function_config.name",
                nothing
            )
        )
    end

    if !haskey(config, :dimension)
        throw(
            SchemaValidationError(
                "Missing required field 'dimension'",
                "function_config.dimension",
                nothing
            )
        )
    end

    # Validate field types
    if !isa(config.name, String)
        throw(
            SchemaValidationError(
                "Field 'name' must be a string",
                "function_config.name",
                config.name
            )
        )
    end

    if !isa(config.dimension, Int) || config.dimension < 1
        throw(
            SchemaValidationError(
                "Field 'dimension' must be a positive integer",
                "function_config.dimension",
                config.dimension
            )
        )
    end

    parameters = haskey(config, :parameters) ? config.parameters : nothing

    return FunctionConfig(config.name, config.dimension, parameters)
end

"""
    validate_test_input_params(config) -> TestInputParams

Validate test input parameters section and return structured object.
"""
function validate_test_input_params(config)
    # Check required fields
    if !haskey(config, :center)
        throw(
            SchemaValidationError(
                "Missing required field 'center'",
                "test_input_params.center",
                nothing
            )
        )
    end

    if !haskey(config, :degree)
        throw(
            SchemaValidationError(
                "Missing required field 'degree'",
                "test_input_params.degree",
                nothing
            )
        )
    end

    # Validate center (must be array-like of numbers)
    if !isa(config.center, AbstractArray) || !all(x -> isa(x, Number), config.center)
        throw(
            SchemaValidationError(
                "Field 'center' must be an array of numbers",
                "test_input_params.center",
                config.center
            )
        )
    end

    center = Float64.(config.center)

    # Validate degree
    if !isa(config.degree, Int) || config.degree < 1
        throw(
            SchemaValidationError(
                "Field 'degree' must be a positive integer",
                "test_input_params.degree",
                config.degree
            )
        )
    end

    # Extract optional fields with defaults
    GN = haskey(config, :GN) ? config.GN : nothing
    sample_range = haskey(config, :sample_range) ? config.sample_range : 1.0
    alpha = haskey(config, :alpha) ? config.alpha : nothing
    tolerance = haskey(config, :tolerance) ? config.tolerance : nothing
    precision_params = haskey(config, :precision_params) ? config.precision_params : nothing
    noise_params = haskey(config, :noise_params) ? config.noise_params : nothing

    # Validate sample_range (can be number or array of numbers)
    if isa(sample_range, Number)
        sample_range = Float64(sample_range)
    elseif isa(sample_range, AbstractArray) && all(x -> isa(x, Number), sample_range)
        sample_range = Float64.(sample_range)
    else
        throw(
            SchemaValidationError(
                "Field 'sample_range' must be a number or array of numbers",
                "test_input_params.sample_range",
                sample_range
            )
        )
    end

    return TestInputParams(
        center,
        GN,
        sample_range,
        alpha,
        config.degree,
        tolerance,
        precision_params,
        noise_params
    )
end

"""
    validate_constructor_params(config) -> ConstructorParams

Validate constructor parameters section and return structured object.
"""
function validate_constructor_params(config)
    # Check required fields
    if !haskey(config, :precision)
        throw(
            SchemaValidationError(
                "Missing required field 'precision'",
                "constructor_params.precision",
                nothing
            )
        )
    end

    if !haskey(config, :basis)
        throw(
            SchemaValidationError(
                "Missing required field 'basis'",
                "constructor_params.basis",
                nothing
            )
        )
    end

    # Validate precision type
    if !validate_precision_type(config.precision)
        throw(
            SchemaValidationError(
                "Invalid precision type",
                "constructor_params.precision",
                config.precision
            )
        )
    end

    # Validate basis type
    if !validate_basis_type(config.basis)
        throw(
            SchemaValidationError(
                "Invalid basis type",
                "constructor_params.basis",
                config.basis
            )
        )
    end

    # Extract optional fields with defaults
    normalized = haskey(config, :normalized) ? config.normalized : false
    power_of_two_denom =
        haskey(config, :power_of_two_denom) ? config.power_of_two_denom : nothing

    return ConstructorParams(config.precision, config.basis, normalized, power_of_two_denom)
end

"""
    validate_analysis_params(config) -> AnalysisParams

Validate analysis parameters section and return structured object.
"""
function validate_analysis_params(config)
    # Extract fields with defaults
    enable_hessian = haskey(config, :enable_hessian) ? config.enable_hessian : true
    tol_dist = haskey(config, :tol_dist) ? config.tol_dist : 1e-6

    # Validate sparsification if present
    sparsification = nothing
    if haskey(config, :sparsification)
        spars_config = config.sparsification
        enabled = haskey(spars_config, :enabled) ? spars_config.enabled : false
        threshold = haskey(spars_config, :threshold) ? spars_config.threshold : nothing
        method = haskey(spars_config, :method) ? spars_config.method : nothing

        # Validate sparsification method if provided
        if method !== nothing && method ∉ VALID_SPARSIFICATION_METHODS
            throw(
                SchemaValidationError(
                    "Invalid sparsification method",
                    "analysis_params.sparsification.method",
                    method
                )
            )
        end

        sparsification = SparsificationParams(enabled, threshold, method)
    end

    # Extract tracking flags (Issue #124) with defaults
    track_convergence = haskey(config, :track_convergence) ? config.track_convergence : false
    track_gradient_norms = haskey(config, :track_gradient_norms) ? config.track_gradient_norms : false
    track_distance_to_solutions = haskey(config, :track_distance_to_solutions) ? config.track_distance_to_solutions : false
    track_performance_metrics = haskey(config, :track_performance_metrics) ? config.track_performance_metrics : false

    return AnalysisParams(enable_hessian, tol_dist, sparsification,
                         track_convergence, track_gradient_norms,
                         track_distance_to_solutions, track_performance_metrics)
end

"""
    validate_output_settings(config) -> OutputSettings

Validate output settings section and return structured object.
"""
function validate_output_settings(config)
    # Extract fields with defaults
    save_intermediate =
        haskey(config, :save_intermediate) ? config.save_intermediate : false
    output_dir = haskey(config, :output_dir) ? config.output_dir : "./results"
    result_format = haskey(config, :result_format) ? config.result_format : "json"

    # Issue #124: Warn if save_plots is present (deprecated)
    if haskey(config, :save_plots)
        @warn "save_plots parameter is deprecated (Issue #124). Visualization is a post-processing concern. Use tracking flags in analysis_params instead."
    end

    # Validate result format
    if result_format ∉ VALID_RESULT_FORMATS
        throw(
            SchemaValidationError(
                "Invalid result format",
                "output_settings.result_format",
                result_format
            )
        )
    end

    return OutputSettings(save_intermediate, output_dir, result_format)
end

# ============================================================================
# Phase 1 Extensions: ODE Config Validation Functions
# ============================================================================

"""
    validate_model_config(config) -> ModelConfig

Validate model configuration section and return structured object.
"""
function validate_model_config(config)
    # Required fields
    if !haskey(config, :name)
        throw(SchemaValidationError("Missing required field 'name'",
                                    "model_config.name", nothing))
    end

    if !haskey(config, :dimension)
        throw(SchemaValidationError("Missing required field 'dimension'",
                                    "model_config.dimension", nothing))
    end

    if !isa(config.dimension, Int) || config.dimension < 1
        throw(SchemaValidationError("Field 'dimension' must be a positive integer",
                                    "model_config.dimension", config.dimension))
    end

    # Optional fields
    true_parameters = haskey(config, :true_parameters) ?
                     Float64.(config.true_parameters) : nothing
    initial_conditions = haskey(config, :initial_conditions) ?
                        Float64.(config.initial_conditions) : nothing
    fixed_parameters = haskey(config, :fixed_parameters) ?
                      config.fixed_parameters : nothing

    # Validate dimensionality if provided
    if true_parameters !== nothing && length(true_parameters) != config.dimension
        throw(SchemaValidationError(
            "true_parameters length must match dimension",
            "model_config.true_parameters",
            true_parameters
        ))
    end

    return ModelConfig(config.name, config.dimension, true_parameters,
                      initial_conditions, fixed_parameters)
end

"""
    validate_domain_config(config) -> DomainConfig

Validate domain configuration section and return structured object.
"""
function validate_domain_config(config)
    # Required field
    if !haskey(config, :strategy)
        throw(SchemaValidationError("Missing required field 'strategy'",
                                    "domain_config.strategy", nothing))
    end

    strategy = config.strategy
    if strategy ∉ VALID_DOMAIN_STRATEGIES
        throw(SchemaValidationError("Invalid domain strategy",
                                    "domain_config.strategy", strategy))
    end

    # Strategy-specific validation
    range = nothing
    bounds = nothing
    offset_length = nothing
    random_seed = nothing

    if strategy == "centered_at_true"
        if !haskey(config, :range)
            throw(SchemaValidationError(
                "Missing required field 'range' for centered_at_true strategy",
                "domain_config.range", nothing))
        end

        if isa(config.range, Number)
            range = Float64(config.range)
        elseif isa(config.range, AbstractArray)
            range = Float64.(config.range)
        else
            throw(SchemaValidationError(
                "Field 'range' must be a number or array",
                "domain_config.range", config.range))
        end

    elseif strategy == "explicit_bounds"
        if !haskey(config, :bounds)
            throw(SchemaValidationError(
                "Missing required field 'bounds' for explicit_bounds strategy",
                "domain_config.bounds", nothing))
        end

        # Convert bounds to vector of tuples
        bounds = [(Float64(low), Float64(high)) for (low, high) in config.bounds]

    elseif strategy == "random_offset"
        if !haskey(config, :offset_length)
            throw(SchemaValidationError(
                "Missing required field 'offset_length' for random_offset strategy",
                "domain_config.offset_length", nothing))
        end
        offset_length = Float64(config.offset_length)
        random_seed = haskey(config, :random_seed) ? Int(config.random_seed) : nothing
    end

    return DomainConfig(strategy, range, bounds, offset_length, random_seed)
end

"""
    validate_solver_config(config) -> ODESolverConfig

Validate ODE solver configuration section and return structured object.
"""
function validate_solver_config(config)
    # Required fields with defaults
    method = haskey(config, :method) ? config.method : "Rosenbrock23"
    abstol = haskey(config, :abstol) ? Float64(config.abstol) : 1e-10
    reltol = haskey(config, :reltol) ? Float64(config.reltol) : 1e-10

    # Validate solver method
    if method ∉ VALID_ODE_SOLVERS
        @warn "Solver method '$method' not in validated list. Proceeding anyway."
    end

    # Time span
    if !haskey(config, :time_span)
        throw(SchemaValidationError("Missing required field 'time_span'",
                                    "solver_config.time_span", nothing))
    end

    time_span = tuple(Float64.(config.time_span)...)
    if length(time_span) != 2 || time_span[1] >= time_span[2]
        throw(SchemaValidationError(
            "time_span must be [start, end] with start < end",
            "solver_config.time_span", config.time_span))
    end

    # Optional fields
    saveat = haskey(config, :saveat) ?
             (isa(config.saveat, AbstractArray) ?
              Float64.(config.saveat) : Float64(config.saveat)) : nothing
    maxiters = haskey(config, :maxiters) ? Int(config.maxiters) : nothing

    return ODESolverConfig(method, abstol, reltol, time_span, saveat, maxiters)
end

"""
    validate_computation_config(config) -> ComputationConfig

Validate computation configuration section and return structured object.
"""
function validate_computation_config(config)
    # Required: samples_per_dim
    if !haskey(config, :samples_per_dim)
        throw(SchemaValidationError("Missing required field 'samples_per_dim'",
                                    "computation_config.samples_per_dim", nothing))
    end
    samples_per_dim = Int(config.samples_per_dim)

    # Required: degrees
    if !haskey(config, :degrees)
        throw(SchemaValidationError("Missing required field 'degrees'",
                                    "computation_config.degrees", nothing))
    end

    # Parse degrees - can be array or range string "4:12"
    if isa(config.degrees, AbstractArray)
        degrees = Int.(config.degrees)
    elseif isa(config.degrees, String) && occursin(":", config.degrees)
        # Parse range string
        parts = split(config.degrees, ":")
        if length(parts) != 2
            throw(SchemaValidationError(
                "Degree range must be 'start:end' format",
                "computation_config.degrees", config.degrees))
        end
        start_deg = parse(Int, parts[1])
        end_deg = parse(Int, parts[2])
        degrees = collect(start_deg:end_deg)
    else
        throw(SchemaValidationError(
            "degrees must be an array or range string 'start:end'",
            "computation_config.degrees", config.degrees))
    end

    # Precision mode
    precision_mode = haskey(config, :precision_mode) ? config.precision_mode : "float64"

    # Normalize precision mode strings
    if isa(precision_mode, String)
        precision_mode = lowercase(precision_mode)
        if precision_mode ∉ ["float64", "adaptive", "float64precision", "adaptiveprecision"]
            throw(SchemaValidationError("Invalid precision_mode",
                                        "computation_config.precision_mode", precision_mode))
        end
    elseif isa(precision_mode, AbstractArray)
        precision_mode = lowercase.(String.(precision_mode))
        for pm in precision_mode
            if pm ∉ ["float64", "adaptive", "float64precision", "adaptiveprecision"]
                throw(SchemaValidationError("Invalid precision_mode in array",
                                            "computation_config.precision_mode", pm))
            end
        end
    end

    # Optional fields
    tracker_options = haskey(config, :tracker_options) ? config.tracker_options : nothing
    max_time_per_degree = haskey(config, :max_time_per_degree) ?
                         Float64(config.max_time_per_degree) : nothing

    return ComputationConfig(samples_per_dim, degrees, precision_mode,
                           tracker_options, max_time_per_degree)
end

"""
    parse_experiment_config(json_string::String) -> ExperimentConfig

Parse and validate a JSON configuration string for GlobTim experiments.
Returns a structured ExperimentConfig object.

# Arguments
- `json_string`: JSON string containing the experiment configuration

# Returns
- `ExperimentConfig`: Validated and structured configuration object

# Throws
- `ConfigValidationError`: If JSON parsing fails or structure is invalid
- `SchemaValidationError`: If specific field validation fails

# Example
```julia
config_json = \"\"\"
{
    "function_config": {
        "name": "camel_2d",
        "dimension": 2
    },
    "test_input_params": {
        "center": [0.0, 0.0],
        "degree": 3
    },
    "constructor_params": {
        "precision": "Float64Precision",
        "basis": "chebyshev"
    },
    "analysis_params": {
        "enable_hessian": true
    }
}
\"\"\"

config = parse_experiment_config(config_json)
```
"""
function parse_experiment_config(json_string::String)
    # Parse JSON
    try
        parsed = JSON3.read(json_string)

        # Validate required sections
        required_sections =
            [:function_config, :test_input_params, :constructor_params, :analysis_params]
        for section in required_sections
            if !haskey(parsed, section)
                throw(ConfigValidationError("Missing required section: $section"))
            end
        end

        # Validate each section
        function_config = validate_function_config(parsed.function_config)
        test_input_params = validate_test_input_params(parsed.test_input_params)
        constructor_params = validate_constructor_params(parsed.constructor_params)
        analysis_params = validate_analysis_params(parsed.analysis_params)

        # Optional output settings
        output_settings =
            haskey(parsed, :output_settings) ?
            validate_output_settings(parsed.output_settings) : nothing

        return ExperimentConfig(
            function_config,
            test_input_params,
            constructor_params,
            analysis_params,
            output_settings
        )

    catch e
        if isa(e, ArgumentError) && occursin("JSON", string(e))
            throw(ConfigValidationError("Invalid JSON format: $e"))
        elseif isa(e, SchemaValidationError) || isa(e, ConfigValidationError)
            rethrow(e)
        else
            throw(ConfigValidationError("Unexpected error during validation: $e"))
        end
    end
end

"""
    load_experiment_config(filepath::String) -> ExperimentConfig

Load and parse an experiment configuration from a JSON file.
"""
function load_experiment_config(filepath::String)
    if !isfile(filepath)
        throw(ConfigValidationError("Configuration file not found: $filepath"))
    end

    try
        json_string = read(filepath, String)
        return parse_experiment_config(json_string)
    catch e
        throw(ConfigValidationError("Failed to load configuration from $filepath: $e"))
    end
end

# ============================================================================
# Phase 1 Extensions: ODE Config Parsing and Loading
# ============================================================================

"""
    parse_ode_experiment_config(config_dict) -> ODEExperimentConfig

Parse and validate an ODE experiment configuration from a dictionary.
Supports both JSON3.Object and Dict inputs.

# Arguments
- `config_dict`: Parsed configuration dictionary (from JSON or TOML)

# Returns
- `ODEExperimentConfig`: Validated and structured configuration object

# Throws
- `ConfigValidationError`: If structure is invalid
- `SchemaValidationError`: If specific field validation fails
"""
function parse_ode_experiment_config(config_dict)
    try
        # Validate required sections
        required_sections = [:model_config, :domain_config, :computation_config, :solver_config]
        for section in required_sections
            if !haskey(config_dict, section)
                throw(ConfigValidationError("Missing required section: $section"))
            end
        end

        # Validate each section
        model_config = validate_model_config(config_dict.model_config)
        domain_config = validate_domain_config(config_dict.domain_config)
        computation_config = validate_computation_config(config_dict.computation_config)
        solver_config = validate_solver_config(config_dict.solver_config)

        # Constructor params - use defaults if not provided
        constructor_params = if haskey(config_dict, :constructor_params)
            validate_constructor_params(config_dict.constructor_params)
        else
            # Default constructor params
            ConstructorParams("Float64Precision", "chebyshev", false, nothing)
        end

        # Analysis params - use defaults if not provided
        analysis_params = if haskey(config_dict, :analysis_params)
            validate_analysis_params(config_dict.analysis_params)
        else
            # Default analysis params
            AnalysisParams(true, 1e-6, nothing, false, false, false, false)
        end

        # Optional output settings
        output_settings = if haskey(config_dict, :output_settings)
            validate_output_settings(config_dict.output_settings)
        else
            nothing
        end

        return ODEExperimentConfig(
            model_config,
            domain_config,
            computation_config,
            solver_config,
            constructor_params,
            analysis_params,
            output_settings
        )

    catch e
        if isa(e, SchemaValidationError) || isa(e, ConfigValidationError)
            rethrow(e)
        else
            throw(ConfigValidationError("Unexpected error during ODE config validation: $e"))
        end
    end
end

"""
    load_ode_experiment_config(filepath::String) -> ODEExperimentConfig

Load and parse an ODE experiment configuration from a JSON or TOML file.
File format is auto-detected from extension (.json, .toml).

# Example
```julia
# From JSON
config = load_ode_experiment_config("experiment.json")

# From TOML
config = load_ode_experiment_config("experiment.toml")
```
"""
function load_ode_experiment_config(filepath::String)
    if !isfile(filepath)
        throw(ConfigValidationError("Configuration file not found: $filepath"))
    end

    try
        # Detect file format
        if endswith(filepath, ".json")
            # Parse JSON
            json_string = read(filepath, String)
            parsed = JSON3.read(json_string)
            return parse_ode_experiment_config(parsed)

        elseif endswith(filepath, ".toml")
            # Parse TOML
            parsed_dict = TOML.parsefile(filepath)
            # Convert to NamedTuple-like structure for consistency
            parsed = convert_dict_to_namedtuple(parsed_dict)
            return parse_ode_experiment_config(parsed)

        else
            throw(ConfigValidationError(
                "Unsupported file format. Use .json or .toml extension."))
        end

    catch e
        if isa(e, ConfigValidationError) || isa(e, SchemaValidationError)
            rethrow(e)
        else
            throw(ConfigValidationError("Failed to load ODE config from $filepath: $e"))
        end
    end
end

"""
    convert_dict_to_namedtuple(d::Dict) -> NamedTuple

Recursively convert a dictionary to NamedTuple for consistent API.
Helper function for TOML parsing.
"""
function convert_dict_to_namedtuple(d::Dict)
    if isempty(d)
        return NamedTuple()
    end

    # Convert nested dicts recursively
    converted = Dict{Symbol, Any}()
    for (k, v) in d
        key = Symbol(k)
        if isa(v, Dict)
            converted[key] = convert_dict_to_namedtuple(v)
        elseif isa(v, Array) && !isempty(v) && isa(v[1], Dict)
            # Array of dicts
            converted[key] = [convert_dict_to_namedtuple(item) for item in v]
        else
            converted[key] = v
        end
    end

    return NamedTuple(converted)
end

# Export main functions and types
export ExperimentConfig,
    FunctionConfig, TestInputParams, ConstructorParams, AnalysisParams, OutputSettings
export ConfigValidationError, SchemaValidationError
export parse_experiment_config, load_experiment_config
export validate_precision_type, validate_basis_type

# Phase 1 Extensions: Export ODE experiment types and functions
export ODEExperimentConfig, ModelConfig, DomainConfig, ComputationConfig, ODESolverConfig
export parse_ode_experiment_config, load_ode_experiment_config
export validate_model_config, validate_domain_config, validate_computation_config, validate_solver_config
