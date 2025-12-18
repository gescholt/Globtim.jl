"""
    ConfigValidation

Module for validating experiment configurations against JSON schema
and performing semantic validation checks.
"""
module ConfigValidation

using JSON3

export ValidationError, ValidationResult, validate_config_dict, validate_config_file, print_validation_errors, validate_setup_config

# Load schema at module initialization
const SCHEMA_PATH = joinpath(dirname(@__DIR__), "schemas", "experiment_config_schema.json")
const SCHEMA = let
    JSON3.read(read(SCHEMA_PATH, String))
end

"""
    ValidationError

Represents a validation error with field, message, and value.
"""
struct ValidationError
    field::String
    message::String
    value::Any
end

"""
    ValidationResult

Result of validation containing validity status and any errors.
"""
struct ValidationResult
    valid::Bool
    errors::Vector{ValidationError}
end

"""
    validate_config_dict(config::Dict) -> ValidationResult

Validate an experiment configuration dictionary against the schema
and perform semantic validation.
"""
function validate_config_dict(config::Dict)
    errors = ValidationError[]

    # Convert to JSON3 object for schema validation
    config_json = JSON3.read(JSON3.write(config))

    # Schema validation
    schema_errors = validate_schema(config_json)
    append!(errors, schema_errors)

    # Only proceed with semantic validation if schema is valid
    if isempty(schema_errors)
        semantic_errors = validate_semantics(config_json)
        append!(errors, semantic_errors)
    end

    return ValidationResult(isempty(errors), errors)
end

"""
    validate_config_file(config_path::String) -> ValidationResult

Validate an experiment configuration file.
"""
function validate_config_file(config_path::String)
    if !isfile(config_path)
        return ValidationResult(false, [
            ValidationError("file", "Configuration file not found: $config_path", config_path)
        ])
    end

    try
        config_json = JSON3.read(read(config_path, String))
        config_dict = Dict(pairs(config_json))
        return validate_config_dict(config_dict)
    catch e
        return ValidationResult(false, [
            ValidationError("file", "Failed to parse JSON: $(e.msg)", config_path)
        ])
    end
end

"""
    validate_schema(config) -> Vector{ValidationError}

Validate configuration against JSON schema using manual validation.
"""
function validate_schema(config)
    errors = ValidationError[]

    # Check required top-level fields
    required_fields = ["model_config", "numerical_params", "domain_config"]
    for field in required_fields
        if !haskey(config, field) && !haskey(config, Symbol(field))
            push!(errors, ValidationError(
                field,
                "Required field is missing",
                nothing
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
        append!(errors, validate_model_config(model_config))
    end

    # Validate numerical_params
    num_params = get(config, :numerical_params, get(config, "numerical_params", nothing))
    if !isnothing(num_params)
        append!(errors, validate_numerical_params(num_params))
    end

    # Validate domain_config
    domain_config = get(config, :domain_config, get(config, "domain_config", nothing))
    if !isnothing(domain_config)
        append!(errors, validate_domain_config(domain_config))
    end

    return errors
end

"""
    validate_model_config(model_config) -> Vector{ValidationError}

Validate model_config section.
"""
function validate_model_config(model_config)
    errors = ValidationError[]

    # Check required fields
    name_key = haskey(model_config, :name) ? :name : "name"
    dim_key = haskey(model_config, :dimension) ? :dimension : "dimension"
    param_key = haskey(model_config, :true_parameters) ? :true_parameters : "true_parameters"

    if !haskey(model_config, name_key) && !haskey(model_config, string(name_key))
        push!(errors, ValidationError(
            "model_config.name",
            "Required field is missing",
            nothing
        ))
    else
        name = get(model_config, name_key, get(model_config, string(name_key), nothing))
        valid_names = ["lotka_volterra_2d", "lotka_volterra_4d", "fitzhugh_nagumo"]
        if !isnothing(name) && !(name in valid_names)
            push!(errors, ValidationError(
                "model_config.name",
                "Must be one of: $(join(valid_names, ", "))",
                name
            ))
        end
    end

    if !haskey(model_config, dim_key) && !haskey(model_config, string(dim_key))
        push!(errors, ValidationError(
            "model_config.dimension",
            "Required field is missing",
            nothing
        ))
    else
        dim = get(model_config, dim_key, get(model_config, string(dim_key), nothing))
        if !isnothing(dim)
            if !isa(dim, Integer)
                push!(errors, ValidationError(
                    "model_config.dimension",
                    "Must be an integer",
                    dim
                ))
            elseif dim < 1 || dim > 10
                push!(errors, ValidationError(
                    "model_config.dimension",
                    "Must be between 1 and 10",
                    dim
                ))
            end
        end
    end

    if !haskey(model_config, param_key) && !haskey(model_config, string(param_key))
        push!(errors, ValidationError(
            "model_config.true_parameters",
            "Required field is missing",
            nothing
        ))
    else
        params = get(model_config, param_key, get(model_config, string(param_key), nothing))
        if !isnothing(params)
            if !isa(params, AbstractArray)
                push!(errors, ValidationError(
                    "model_config.true_parameters",
                    "Must be an array",
                    params
                ))
            elseif isempty(params)
                push!(errors, ValidationError(
                    "model_config.true_parameters",
                    "Must have at least one element",
                    params
                ))
            end
        end
    end

    return errors
end

"""
    validate_numerical_params(num_params) -> Vector{ValidationError}

Validate numerical_params section.
"""
function validate_numerical_params(num_params)
    errors = ValidationError[]

    # Check GN
    gn_key = haskey(num_params, :GN) ? :GN : "GN"
    if !haskey(num_params, gn_key) && !haskey(num_params, string(gn_key))
        push!(errors, ValidationError(
            "numerical_params.GN",
            "Required field is missing",
            nothing
        ))
    else
        GN = get(num_params, gn_key, get(num_params, string(gn_key), nothing))
        if !isnothing(GN)
            if !isa(GN, Integer)
                push!(errors, ValidationError(
                    "numerical_params.GN",
                    "Must be an integer",
                    GN
                ))
            elseif GN < 4 || GN > 20
                push!(errors, ValidationError(
                    "numerical_params.GN",
                    "Must be between 4 and 20",
                    GN
                ))
            end
        end
    end

    # Check degree_range
    deg_key = haskey(num_params, :degree_range) ? :degree_range : "degree_range"
    if !haskey(num_params, deg_key) && !haskey(num_params, string(deg_key))
        push!(errors, ValidationError(
            "numerical_params.degree_range",
            "Required field is missing",
            nothing
        ))
    else
        deg_range = get(num_params, deg_key, get(num_params, string(deg_key), nothing))
        if !isnothing(deg_range)
            if !isa(deg_range, AbstractArray) || length(deg_range) != 2
                push!(errors, ValidationError(
                    "numerical_params.degree_range",
                    "Must be an array of exactly 2 integers",
                    deg_range
                ))
            elseif any(d -> !isa(d, Integer) || d < 1, deg_range)
                push!(errors, ValidationError(
                    "numerical_params.degree_range",
                    "All elements must be integers >= 1",
                    deg_range
                ))
            end
        end
    end

    return errors
end

"""
    validate_domain_config(domain_config) -> Vector{ValidationError}

Validate domain_config section.
"""
function validate_domain_config(domain_config)
    errors = ValidationError[]

    # Check ranges
    ranges_key = haskey(domain_config, :ranges) ? :ranges : "ranges"
    if !haskey(domain_config, ranges_key) && !haskey(domain_config, string(ranges_key))
        push!(errors, ValidationError(
            "domain_config.ranges",
            "Required field is missing",
            nothing
        ))
    else
        ranges = get(domain_config, ranges_key, get(domain_config, string(ranges_key), nothing))
        if !isnothing(ranges)
            if !isa(ranges, AbstractArray)
                push!(errors, ValidationError(
                    "domain_config.ranges",
                    "Must be an array",
                    ranges
                ))
            elseif isempty(ranges)
                push!(errors, ValidationError(
                    "domain_config.ranges",
                    "Must have at least one element",
                    ranges
                ))
            elseif any(r -> !isa(r, Number) || r <= 0, ranges)
                push!(errors, ValidationError(
                    "domain_config.ranges",
                    "All elements must be positive numbers",
                    ranges
                ))
            end
        end
    end

    return errors
end

"""
    validate_semantics(config) -> Vector{ValidationError}

Perform semantic validation beyond schema constraints.
"""
function validate_semantics(config)
    errors = ValidationError[]

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
                    push!(errors, ValidationError(
                        "model_config.true_parameters",
                        "Length must match dimension ($dim), got $(length(params))",
                        params
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
                    push!(errors, ValidationError(
                        "numerical_params.degree_range",
                        "Min degree ($(deg_range[1])) must be ≤ max degree ($(deg_range[2]))",
                        deg_range
                    ))
                end
            end
        end
    end

    # Warn about large grid sizes (warning, not error)
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
    print_validation_errors(result::ValidationResult)

Print validation errors in a readable format.
"""
function print_validation_errors(result::ValidationResult)
    if result.valid
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

"""
    validate_setup_config(config_dict::Dict) -> ValidationResult

Validate a setup_experiments.jl style configuration.
This is a lighter validation for configs generated by setup scripts.

# Arguments
- `config_dict`: Configuration dictionary from setup script

# Returns
- `ValidationResult`: Validation result with any errors found

# Example
```julia
config = Dict(
    "experiment_id" => 1,
    "GN" => 16,
    "degree_min" => 4,
    "degree_max" => 12,
    "p_true" => [0.2, 0.3, 0.5, 0.6]
)

result = validate_setup_config(config)
if !result.valid
    print_validation_errors(result)
end
```
"""
function validate_setup_config(config_dict::Dict)
    errors = ValidationError[]

    # Validate GN range
    if haskey(config_dict, "GN")
        GN = config_dict["GN"]
        if !isa(GN, Integer)
            push!(errors, ValidationError("GN", "Must be an integer", GN))
        elseif GN < 4 || GN > 20
            push!(errors, ValidationError("GN", "Must be between 4 and 20", GN))
        end
    end

    # Validate degree range
    if haskey(config_dict, "degree_min") && haskey(config_dict, "degree_max")
        deg_min = config_dict["degree_min"]
        deg_max = config_dict["degree_max"]

        if !isa(deg_min, Integer) || !isa(deg_max, Integer)
            push!(errors, ValidationError(
                "degree_range",
                "degree_min and degree_max must be integers",
                (deg_min, deg_max)
            ))
        elseif deg_min > deg_max
            push!(errors, ValidationError(
                "degree_range",
                "degree_min ($deg_min) must be ≤ degree_max ($deg_max)",
                (deg_min, deg_max)
            ))
        end
    end

    # Validate domain_range (must be positive)
    if haskey(config_dict, "domain_range")
        dr = config_dict["domain_range"]
        if !isa(dr, Number) || dr <= 0
            push!(errors, ValidationError(
                "domain_range",
                "Must be a positive number",
                dr
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
                push!(errors, ValidationError(
                    "p_true",
                    "Length must match model dimension ($expected_dim), got $(length(p_true))",
                    p_true
                ))
            end
        end
    end

    return ValidationResult(isempty(errors), errors)
end

end  # module
