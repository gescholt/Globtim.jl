# Parameter Tracking Configuration Module
# Provides JSON schema validation and configuration parsing for the parameter tracking infrastructure

using JSON3

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
end

struct OutputSettings
    save_intermediate::Bool
    save_plots::Bool
    output_dir::String
    result_format::String
end

struct ExperimentConfig
    function_config::FunctionConfig
    test_input_params::TestInputParams
    constructor_params::ConstructorParams
    analysis_params::AnalysisParams
    output_settings::Union{OutputSettings, Nothing}
end

# Validation constants
const VALID_PRECISION_TYPES = ["Float64Precision", "AdaptivePrecision", "RationalPrecision", "BigFloatPrecision", "BigIntPrecision"]
const VALID_BASIS_TYPES = ["chebyshev", "legendre"]
const VALID_RESULT_FORMATS = ["json", "hdf5"]
const VALID_SPARSIFICATION_METHODS = ["l2_norm", "absolute", "relative"]

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
        throw(SchemaValidationError("Missing required field 'name'", "function_config.name", nothing))
    end
    
    if !haskey(config, :dimension)
        throw(SchemaValidationError("Missing required field 'dimension'", "function_config.dimension", nothing))
    end
    
    # Validate field types
    if !isa(config.name, String)
        throw(SchemaValidationError("Field 'name' must be a string", "function_config.name", config.name))
    end
    
    if !isa(config.dimension, Int) || config.dimension < 1
        throw(SchemaValidationError("Field 'dimension' must be a positive integer", "function_config.dimension", config.dimension))
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
        throw(SchemaValidationError("Missing required field 'center'", "test_input_params.center", nothing))
    end
    
    if !haskey(config, :degree)
        throw(SchemaValidationError("Missing required field 'degree'", "test_input_params.degree", nothing))
    end
    
    # Validate center (must be array-like of numbers)
    if !isa(config.center, AbstractArray) || !all(x -> isa(x, Number), config.center)
        throw(SchemaValidationError("Field 'center' must be an array of numbers", "test_input_params.center", config.center))
    end
    
    center = Float64.(config.center)
    
    # Validate degree
    if !isa(config.degree, Int) || config.degree < 1
        throw(SchemaValidationError("Field 'degree' must be a positive integer", "test_input_params.degree", config.degree))
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
        throw(SchemaValidationError("Field 'sample_range' must be a number or array of numbers", "test_input_params.sample_range", sample_range))
    end
    
    return TestInputParams(center, GN, sample_range, alpha, config.degree, tolerance, precision_params, noise_params)
end

"""
    validate_constructor_params(config) -> ConstructorParams

Validate constructor parameters section and return structured object.
"""
function validate_constructor_params(config)
    # Check required fields
    if !haskey(config, :precision)
        throw(SchemaValidationError("Missing required field 'precision'", "constructor_params.precision", nothing))
    end
    
    if !haskey(config, :basis)
        throw(SchemaValidationError("Missing required field 'basis'", "constructor_params.basis", nothing))
    end
    
    # Validate precision type
    if !validate_precision_type(config.precision)
        throw(SchemaValidationError("Invalid precision type", "constructor_params.precision", config.precision))
    end
    
    # Validate basis type
    if !validate_basis_type(config.basis)
        throw(SchemaValidationError("Invalid basis type", "constructor_params.basis", config.basis))
    end
    
    # Extract optional fields with defaults
    normalized = haskey(config, :normalized) ? config.normalized : false
    power_of_two_denom = haskey(config, :power_of_two_denom) ? config.power_of_two_denom : nothing
    
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
            throw(SchemaValidationError("Invalid sparsification method", "analysis_params.sparsification.method", method))
        end
        
        sparsification = SparsificationParams(enabled, threshold, method)
    end
    
    return AnalysisParams(enable_hessian, tol_dist, sparsification)
end

"""
    validate_output_settings(config) -> OutputSettings

Validate output settings section and return structured object.
"""
function validate_output_settings(config)
    # Extract fields with defaults
    save_intermediate = haskey(config, :save_intermediate) ? config.save_intermediate : false
    save_plots = haskey(config, :save_plots) ? config.save_plots : false
    output_dir = haskey(config, :output_dir) ? config.output_dir : "./results"
    result_format = haskey(config, :result_format) ? config.result_format : "json"
    
    # Validate result format
    if result_format ∉ VALID_RESULT_FORMATS
        throw(SchemaValidationError("Invalid result format", "output_settings.result_format", result_format))
    end
    
    return OutputSettings(save_intermediate, save_plots, output_dir, result_format)
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
        required_sections = [:function_config, :test_input_params, :constructor_params, :analysis_params]
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
        output_settings = haskey(parsed, :output_settings) ? 
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

# Export main functions and types
export ExperimentConfig, FunctionConfig, TestInputParams, ConstructorParams, AnalysisParams, OutputSettings
export ConfigValidationError, SchemaValidationError
export parse_experiment_config, load_experiment_config
export validate_precision_type, validate_basis_type