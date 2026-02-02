module ValidationBoundaries
# Type-safe data validation patterns for Julia
# Based on best practices for defensive programming and error handling

using DataFrames
using CSV
using Statistics

# Custom exception hierarchy for data validation errors
abstract type DataValidationError <: Exception end

struct FilenameContaminationError <: DataValidationError
    column::String
    contaminated_rows::Vector{Int}
    contamination_percentage::Float64

    function FilenameContaminationError(column::String, contaminated_rows::Vector{Int}, total_rows::Int)
        pct = (length(contaminated_rows) / total_rows) * 100
        new(column, contaminated_rows, pct)
    end
end

struct ParameterRangeError <: DataValidationError
    parameter::String
    expected_range::Tuple{Float64, Float64}
    actual_range::Tuple{Float64, Float64}
    invalid_values::Vector{Float64}
end

struct SchemaValidationError <: DataValidationError
    column::String
    expected_type::Type
    actual_type::Type
    message::String
end

struct ContentValidationError <: DataValidationError
    column::String
    invalid_values::Vector{Any}
    validation_rule::String
end

struct DataLoadError <: DataValidationError
    filepath::String
    message::String
end

struct DataQualityError <: DataValidationError
    quality_score::Float64
    threshold::Float64
    message::String
end

struct DataProductionError <: DataValidationError
    stage::String
    message::String
    context::Dict{String, Any}
end

# Result type pattern for validation chains (Railway Pattern)
struct ValidationResult{T}
    success::Bool
    data::Union{T, Nothing}
    errors::Vector{DataValidationError}
    warnings::Vector{String}
    quality_score::Float64

    function ValidationResult{T}(success::Bool, data::Union{T, Nothing},
                               errors::Vector{DataValidationError}=DataValidationError[],
                               warnings::Vector{String}=String[],
                               quality_score::Float64=100.0) where T
        new{T}(success, data, errors, warnings, quality_score)
    end
end

# Convenience constructors
ValidationResult(success::Bool, data::T, errors::Vector{DataValidationError}=DataValidationError[],
                warnings::Vector{String}=String[], quality_score::Float64=100.0) where T =
    ValidationResult{T}(success, data, errors, warnings, quality_score)

ValidationResult{T}(success::Bool) where T = ValidationResult{T}(success, nothing)

# Validation chain combinators
function chain_validation(result::ValidationResult{T}, next_validator::Function)::ValidationResult{T} where T
    !result.success && return result

    try
        next_result = next_validator(result.data)
        return ValidationResult{T}(
            next_result.success,
            next_result.success ? next_result.data : result.data,
            vcat(result.errors, next_result.errors),
            vcat(result.warnings, next_result.warnings),
            min(result.quality_score, next_result.quality_score)
        )
    catch e
        error_obj = e isa DataValidationError ? e : ContentValidationError("validation_chain", [e], "Chain validation failed")
        return ValidationResult{T}(false, result.data, vcat(result.errors, [error_obj]), result.warnings, 0.0)
    end
end

# Type-safe column validation
function validate_column_type(df::DataFrame, col::Symbol, expected_type::Type)::ValidationResult{DataFrame}
    !hasproperty(df, col) && return ValidationResult{DataFrame}(
        false, nothing, [SchemaValidationError(string(col), expected_type, Missing, "Column missing")], [], 0.0
    )

    col_values = df[!, col]
    non_matching = findall(x -> !isa(x, expected_type) && !ismissing(x), col_values)

    if !isempty(non_matching)
        actual_types = unique([typeof(df[i, col]) for i in non_matching])
        return ValidationResult{DataFrame}(
            false, nothing,
            [SchemaValidationError(string(col), expected_type, first(actual_types),
                                 "Found $(length(non_matching)) values of incorrect type")],
            [], 50.0
        )
    end

    return ValidationResult(true, df, DataValidationError[], String[], 100.0)
end

# Defensive CSV reading with type checking
function safe_read_csv(filepath::String;
                      required_columns::Vector{Symbol}=Symbol[],
                      expected_types::Dict{Symbol, DataType}=Dict{Symbol, DataType}())::ValidationResult{DataFrame}

    !isfile(filepath) && return ValidationResult{DataFrame}(
        false, nothing, [DataLoadError(filepath, "File not found")], [], 0.0
    )

    try
        # Read CSV defensively
        df = CSV.read(filepath, DataFrame;
            silencewarnings=true,
            types=Dict(),          # Don't assume types initially
            strict=false           # Allow type mismatches for validation
        )

        errors = DataValidationError[]
        warnings = String[]
        quality_score = 100.0

        # Validate required columns exist
        missing_cols = setdiff(required_columns, Symbol.(names(df)))
        if !isempty(missing_cols)
            push!(errors, SchemaValidationError(
                join(string.(missing_cols), ", "),
                Any, Missing,
                "Missing required columns: $(join(missing_cols, ", "))"
            ))
            quality_score = 0.0
        end

        # Validate expected types
        for (col, expected_type) in expected_types
            if hasproperty(df, col)
                type_result = validate_column_type(df, col, expected_type)
                if !type_result.success
                    append!(errors, type_result.errors)
                    quality_score = min(quality_score, type_result.quality_score)
                end
            end
        end

        success = isempty(errors)
        return ValidationResult{DataFrame}(success, success ? df : nothing, errors, warnings, quality_score)

    catch e
        return ValidationResult{DataFrame}(
            false, nothing, [DataLoadError(filepath, "CSV read failed: $e")], [], 0.0
        )
    end
end

# Filename contamination detection with specific patterns
function detect_filename_contamination(df::DataFrame, threshold_pct::Float64=10.0)::ValidationResult{DataFrame}
    contamination_errors = DataValidationError[]
    warnings = String[]
    quality_score = 100.0

    filename_patterns = [
        r"\.csv$"i, r"\.jl$"i, r"\.txt$"i, r"\.dat$"i, r"\.h5$"i, r"\.json$"i,
        r"\.xlsx?$"i, r"\.pdf$"i, r"\.png$"i, r"\.jpg$"i,
        r"^[a-zA-Z_][a-zA-Z0-9_]*\.(csv|txt|dat|jl|json)$"i,
        r"comparison_data\.csv$"i,
        r"_\d{8}_\d{6}\.csv$"i  # timestamp pattern
    ]

    for col in names(df)
        filename_rows = Int[]
        col_values = df[!, col]

        for (i, val) in enumerate(col_values)
            val_str = string(val)

            # Check against filename patterns
            for pattern in filename_patterns
                if occursin(pattern, val_str)
                    push!(filename_rows, i)
                    break
                end
            end
        end

        contamination_pct = (length(filename_rows) / nrow(df)) * 100

        if contamination_pct > threshold_pct
            push!(contamination_errors, FilenameContaminationError(col, filename_rows, nrow(df)))
            quality_score = min(quality_score, 100.0 - contamination_pct)
        elseif contamination_pct > 1.0
            push!(warnings, "Column '$col' has $(round(contamination_pct, digits=1))% potential filename contamination")
            quality_score = min(quality_score, 90.0)
        end
    end

    success = isempty(contamination_errors)
    return ValidationResult{DataFrame}(success, success ? df : nothing, contamination_errors, warnings, quality_score)
end

# Parameter range validation for biological parameters
function validate_parameter_ranges(df::DataFrame,
                                 param_columns::Vector{Symbol}=[:x1, :x2, :x3, :x4],
                                 expected_range::Tuple{Float64, Float64}=(0.0, 10.0))::ValidationResult{DataFrame}

    range_errors = DataValidationError[]
    warnings = String[]
    quality_score = 100.0

    for param in param_columns
        !hasproperty(df, param) && continue

        values = collect(skipmissing(df[!, param]))
        isempty(values) && continue

        # Check if values are numeric
        non_numeric = findall(x -> !isa(x, Real), values)
        if !isempty(non_numeric)
            push!(range_errors, ContentValidationError(
                string(param),
                values[non_numeric],
                "All parameter values must be numeric"
            ))
            quality_score = 0.0
            continue
        end

        numeric_values = Float64.(values)
        actual_min, actual_max = extrema(numeric_values)
        actual_range = (actual_min, actual_max)

        # Check for values outside expected biological range
        invalid_indices = findall(x -> x < expected_range[1] || x > expected_range[2], numeric_values)
        if !isempty(invalid_indices)
            push!(range_errors, ParameterRangeError(
                string(param),
                expected_range,
                actual_range,
                numeric_values[invalid_indices]
            ))
            quality_score = min(quality_score, 50.0)
        end

        # Check for suspiciously narrow ranges
        range_span = actual_max - actual_min
        if range_span < 0.1 && actual_min > 0
            push!(warnings, "Parameter '$param' has very narrow range: $(round(range_span, digits=4))")
            quality_score = min(quality_score, 75.0)
        end
    end

    success = isempty(range_errors)
    return ValidationResult{DataFrame}(success, success ? df : nothing, range_errors, warnings, quality_score)
end

# Comprehensive data validation pipeline
function validate_experiment_output_strict(df::DataFrame)::ValidationResult{DataFrame}
    # Define expected schema for experiment data
    required_columns = [:x1, :x2, :x3, :x4, :z, :experiment_id]
    expected_types = Dict(
        :x1 => Float64, :x2 => Float64, :x3 => Float64, :x4 => Float64,
        :z => Float64, :experiment_id => AbstractString
    )

    # Validation pipeline using railway pattern
    result = ValidationResult(true, df)

    # Chain validations
    for (col, expected_type) in expected_types
        result = chain_validation(result, data -> validate_column_type(data, col, expected_type))
        !result.success && break
    end

    # Continue with content validations if schema is valid
    if result.success
        result = chain_validation(result, detect_filename_contamination)
        result = chain_validation(result, validate_parameter_ranges)
    end

    return result
end

# HPC workflow integration functions
function save_experiment_results_safe(results::DataFrame, filepath::String;
                                    validation_required::Bool=true)::ValidationResult{String}
    try
        if validation_required
            validation = validate_experiment_output_strict(results)
            if !validation.success
                error_msg = "CRITICAL: Data validation failed: $(join([string(e) for e in validation.errors], "; "))"
                throw(DataProductionError("data_generation", error_msg,
                                        Dict("quality_score" => validation.quality_score,
                                             "error_count" => length(validation.errors))))
            end
        end

        CSV.write(filepath, results)

        # Post-write verification
        verify_result = verify_written_data(filepath, results)
        !verify_result.success && return verify_result

        return ValidationResult{String}(true, filepath, [], [], 100.0)

    catch e
        if e isa DataValidationError
            return ValidationResult{String}(false, nothing, [e], [], 0.0)
        else
            return ValidationResult{String}(false, nothing,
                                          [DataProductionError("file_write", string(e), Dict("filepath" => filepath))],
                                          [], 0.0)
        end
    end
end

function verify_written_data(filepath::String, original_data::DataFrame)::ValidationResult{DataFrame}
    try
        # Re-read and compare
        read_back = CSV.read(filepath, DataFrame)

        # Basic consistency checks
        if size(read_back) != size(original_data)
            return ValidationResult{DataFrame}(false, nothing,
                                             [DataProductionError("file_verification",
                                                                 "Data dimensions changed during write",
                                                                 Dict("original" => size(original_data),
                                                                      "read_back" => size(read_back)))],
                                             [], 0.0)
        end

        return ValidationResult(true, read_back, DataValidationError[], String[], 100.0)

    catch e
        return ValidationResult{DataFrame}(false, nothing,
                                         [DataProductionError("file_verification",
                                                             "Could not verify written data: $e",
                                                             Dict("filepath" => filepath))],
                                         [], 0.0)
    end
end

# Data loading with quality gates
function load_and_validate_experiment_data(filepath::String;
                                         quality_threshold::Float64=70.0)::DataFrame
    # Safe CSV loading with validation
    load_result = safe_read_csv(filepath;
        required_columns=[:x1, :x2, :x3, :x4, :z, :experiment_id],
        expected_types=Dict(:x1=>Float64, :x2=>Float64, :x3=>Float64, :x4=>Float64, :z=>Float64)
    )

    !load_result.success && throw(DataLoadError(filepath, "Failed to load: $(join([string(e) for e in load_result.errors], "; "))"))

    # Quality validation using existing DataProductionValidator
    include(joinpath(@__DIR__, "DataProductionValidator.jl"))
    validation = DataProductionValidator.validate_experiment_output(filepath)

    if validation.quality_score < quality_threshold
        throw(DataQualityError(validation.quality_score, quality_threshold,
                              "Data quality insufficient: $(validation.quality_score) < $quality_threshold"))
    end

    return load_result.data
end

# Utility functions for error reporting
function format_validation_error(error::DataValidationError)::String
    if error isa FilenameContaminationError
        return "🚨 FILENAME CONTAMINATION: Column '$(error.column)' has $(round(error.contamination_percentage, digits=1))% filename values ($(length(error.contaminated_rows)) rows)"
    elseif error isa ParameterRangeError
        return "⚠️  PARAMETER RANGE: '$(error.parameter)' values $(error.invalid_values) outside expected range $(error.expected_range)"
    elseif error isa SchemaValidationError
        return "❌ SCHEMA ERROR: Column '$(error.column)' expected $(error.expected_type), got $(error.actual_type) - $(error.message)"
    elseif error isa ContentValidationError
        return "❌ CONTENT ERROR: Column '$(error.column)' failed validation '$(error.validation_rule)' - $(length(error.invalid_values)) invalid values"
    elseif error isa DataLoadError
        return "❌ LOAD ERROR: $(error.filepath) - $(error.message)"
    elseif error isa DataQualityError
        return "❌ QUALITY ERROR: Score $(error.quality_score) below threshold $(error.threshold) - $(error.message)"
    elseif error isa DataProductionError
        return "🚨 PRODUCTION ERROR [$(error.stage)]: $(error.message)"
    else
        return "❌ VALIDATION ERROR: $(string(error))"
    end
end

function create_validation_report(result::ValidationResult)::String
    report = String[]

    push!(report, "=== VALIDATION REPORT ===")
    push!(report, "Status: $(result.success ? "✅ VALID" : "❌ INVALID")")
    push!(report, "Quality Score: $(round(result.quality_score, digits=1))/100")

    if !isempty(result.errors)
        push!(report, "\nERRORS ($(length(result.errors))):")
        for error in result.errors
            push!(report, "  $(format_validation_error(error))")
        end
    end

    if !isempty(result.warnings)
        push!(report, "\nWARNINGS ($(length(result.warnings))):")
        for warning in result.warnings
            push!(report, "  ⚠️  $warning")
        end
    end

    return join(report, "\n")
end

# Export main functions
export ValidationResult, DataValidationError
export FilenameContaminationError, ParameterRangeError, SchemaValidationError, ContentValidationError
export DataLoadError, DataQualityError, DataProductionError
export safe_read_csv, detect_filename_contamination, validate_parameter_ranges
export validate_column_type, validate_experiment_output_strict, save_experiment_results_safe
export load_and_validate_experiment_data, create_validation_report
export chain_validation, format_validation_error

end # module ValidationBoundaries