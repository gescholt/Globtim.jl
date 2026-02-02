# DataFrameInterface.jl - Standardized DataFrame Interface for Issue #52
# Provides consistent column naming and access patterns for critical point data

module DataFrameInterface

using DataFrames
using CSV
using Statistics

export CriticalPointsSchema, ExperimentComparisonSchema, validate_schema, get_critical_value, standardize_columns!
export migrate_val_to_z!, detect_column_convention, create_schema_validator, detect_data_type
export quick_validate_any_schema, get_critical_values
export transform_to_experiment_summary, transform_to_critical_points

# Abstract base schema type
abstract type DataSchema end

# Schema definition for critical points DataFrames
struct CriticalPointsSchema <: DataSchema
    required_columns::Vector{String}
    value_columns::Vector{String}
    preferred_value_column::String

    function CriticalPointsSchema(;
        required_columns = ["z"],  # Only require z column for critical points
        value_columns = ["z", "val"],
        preferred_value_column = "z"
    )
        new(required_columns, value_columns, preferred_value_column)
    end
end

# Schema definition for experiment comparison DataFrames
struct ExperimentComparisonSchema <: DataSchema
    required_columns::Vector{String}
    performance_columns::Vector{String}
    preferred_performance_column::String

    function ExperimentComparisonSchema(;
        required_columns = ["experiment_id", "mean_l2_overall"],
        performance_columns = ["mean_l2_overall", "best_l2", "worst_l2"],
        preferred_performance_column = "mean_l2_overall"
    )
        new(required_columns, performance_columns, preferred_performance_column)
    end
end

# Default schema instances
const DEFAULT_CRITICAL_POINTS_SCHEMA = CriticalPointsSchema()
const DEFAULT_EXPERIMENT_SCHEMA = ExperimentComparisonSchema()

# Keep backward compatibility
const DEFAULT_SCHEMA = DEFAULT_CRITICAL_POINTS_SCHEMA

# Schema validation result
struct ValidationResult
    valid::Bool
    error::Union{String, Nothing}
    warning::Union{String, Nothing}
    detected_convention::String

    function ValidationResult(valid::Bool; error=nothing, warning=nothing, convention="unknown")
        new(valid, error, warning, convention)
    end
end

"""
    detect_data_type(df::DataFrame) -> String

Automatically detect the type of data in the DataFrame based on column patterns.

Returns one of: "critical_points", "experiment_comparison", "unknown"
"""
function detect_data_type(df::DataFrame)::String
    df_names = names(df)

    # Check for experiment comparison data (requires specific performance metrics)
    experiment_required = ["experiment_id", "mean_l2_overall"]
    if all(col in df_names for col in experiment_required)
        return "experiment_comparison"
    end

    # Check for critical points data (z or val columns indicate raw critical points)
    critical_point_indicators = ["z", "val"]
    if any(col in df_names for col in critical_point_indicators)
        return "critical_points"
    end

    return "unknown"
end

"""
    detect_column_convention(df::DataFrame) -> String

Detect the column naming convention used in the DataFrame.

Returns one of: "z", "val", "mixed", "unknown"
"""
function detect_column_convention(df::DataFrame)::String
    has_z = "z" in names(df)
    has_val = "val" in names(df)

    if has_z && has_val
        return "mixed"
    elseif has_z
        return "z"
    elseif has_val
        return "val"
    else
        return "unknown"
    end
end

"""
    validate_schema(df::DataFrame, schema::DataSchema = DEFAULT_SCHEMA) -> ValidationResult

Validate DataFrame against the specified schema.
"""
# Validation for critical points data
function validate_schema(df::DataFrame, schema::CriticalPointsSchema)::ValidationResult
    # Check required columns
    missing_required = setdiff(schema.required_columns, names(df))
    if !isempty(missing_required)
        error_msg = "Missing required columns: $(join(missing_required, ", ")). " *
                   "Available columns: $(join(names(df), ", "))"
        return ValidationResult(false, error=error_msg)
    end

    # Check for value columns
    has_value_cols = intersect(schema.value_columns, names(df))
    if isempty(has_value_cols)
        error_msg = "Missing critical value column. Expected one of: $(join(schema.value_columns, ", "))"
        return ValidationResult(false, error=error_msg)
    end

    # Detect convention and check for warnings
    convention = detect_column_convention(df)
    warning = nothing

    if convention == "mixed"
        warning = "DataFrame contains both 'z' and 'val' columns. This may cause ambiguity. " *
                 "Consider using standardize_columns!() to resolve conflicts."
    elseif convention == "val"
        warning = "DataFrame uses legacy 'val' column naming. Consider migrating to 'z' for consistency."
    end

    return ValidationResult(true, warning=warning, convention=convention)
end

# Validation for experiment comparison data
function validate_schema(df::DataFrame, schema::ExperimentComparisonSchema)::ValidationResult
    # Check required columns
    missing_required = setdiff(schema.required_columns, names(df))
    if !isempty(missing_required)
        error_msg = "Missing required columns: $(join(missing_required, ", ")). " *
                   "Available columns: $(join(names(df), ", "))"
        return ValidationResult(false, error=error_msg)
    end

    # Check for performance columns
    has_performance_cols = intersect(schema.performance_columns, names(df))
    if isempty(has_performance_cols)
        error_msg = "Missing performance column. Expected one of: $(join(schema.performance_columns, ", "))"
        return ValidationResult(false, error=error_msg)
    end

    # For experiment data, convention is always "experiment_comparison"
    return ValidationResult(true, warning=nothing, convention="experiment_comparison")
end

# Generic validation method with default schema
function validate_schema(df::DataFrame, schema::DataSchema = DEFAULT_SCHEMA)::ValidationResult
    # This should not be called directly, but serves as a fallback
    return ValidationResult(false, error="Unknown schema type")
end

"""
    get_critical_value(df::DataFrame, row_idx::Int, schema::CriticalPointsSchema = DEFAULT_SCHEMA) -> Float64

Get critical value from DataFrame using standardized column access.
"""
function get_critical_value(df::DataFrame, row_idx::Int, schema::CriticalPointsSchema = DEFAULT_SCHEMA)::Float64
    # Validate row index
    if row_idx < 1 || row_idx > nrow(df)
        throw(BoundsError(df, row_idx))
    end

    # Try preferred column first
    if schema.preferred_value_column in names(df)
        return df[row_idx, schema.preferred_value_column]
    end

    # Try other value columns
    for col in schema.value_columns
        if col in names(df) && col != schema.preferred_value_column
            return df[row_idx, col]
        end
    end

    throw(ArgumentError(
        "DataFrame missing critical value column. Expected one of: $(join(schema.value_columns, ", ")). " *
        "Available columns: $(join(names(df), ", "))"
    ))
end

"""
    get_critical_values(df::DataFrame, schema::Union{CriticalPointsSchema,Nothing} = nothing) -> Vector{Float64}

Get all critical values from DataFrame as a vector. Auto-detects data type if no schema provided.
"""
function get_critical_values(df::DataFrame, schema::Union{CriticalPointsSchema,Nothing} = nothing)::Vector{Float64}
    if nrow(df) == 0
        return Float64[]
    end

    # If no schema provided, auto-detect data type and use appropriate extraction
    if schema === nothing
        data_type = detect_data_type(df)

        if data_type == "critical_points"
            return get_critical_value_column(df, DEFAULT_CRITICAL_POINTS_SCHEMA)
        elseif data_type == "experiment_comparison"
            # For experiment comparison, use the performance metric
            exp_schema = DEFAULT_EXPERIMENT_SCHEMA
            if exp_schema.preferred_performance_column in names(df)
                return collect(skipmissing(df[!, exp_schema.preferred_performance_column]))
            else
                # Try other performance columns
                for col in exp_schema.performance_columns
                    if col in names(df)
                        return collect(skipmissing(df[!, col]))
                    end
                end
            end
        end

        # Fallback: return empty vector if no suitable column found
        return Float64[]
    end

    # Use provided schema for critical points data
    return get_critical_value_column(df, schema)
end

"""
    migrate_val_to_z!(df::DataFrame) -> Bool

Migrate DataFrame from 'val' to 'z' column naming convention.
Returns true if migration was performed, false if not needed.
"""
function migrate_val_to_z!(df::DataFrame)::Bool
    if "val" in names(df) && "z" ∉ names(df)
        # Perform migration
        df[!, "z"] = df[!, "val"]
        select!(df, Not(:val))
        return true
    end

    return false
end

"""
    standardize_columns!(df::DataFrame, schema::CriticalPointsSchema = DEFAULT_SCHEMA) -> Dict{String, Any}

Standardize DataFrame columns according to schema preferences.
Returns a report of changes made.
"""
function standardize_columns!(df::DataFrame, schema::CriticalPointsSchema = DEFAULT_SCHEMA)::Dict{String, Any}
    report = Dict{String, Any}(
        "migration_performed" => false,
        "columns_removed" => String[],
        "warnings" => String[],
        "final_convention" => "unknown"
    )

    convention = detect_column_convention(df)

    if convention == "mixed"
        # Handle mixed convention - prefer 'z' over 'val'
        if "z" in names(df) && "val" in names(df)
            # Check if values are identical
            if df[!, "z"] ≈ df[!, "val"]
                select!(df, Not(:val))
                push!(report["columns_removed"], "val")
                push!(report["warnings"], "Removed duplicate 'val' column (identical to 'z')")
            else
                push!(report["warnings"],
                      "Both 'z' and 'val' columns present with different values. Manual resolution required.")
            end
        end
    elseif convention == "val" && schema.preferred_value_column == "z"
        # Migrate val to z
        migrated = migrate_val_to_z!(df)
        report["migration_performed"] = migrated
        if migrated
            push!(report["warnings"], "Migrated 'val' column to 'z' for consistency")
        end
    end

    report["final_convention"] = detect_column_convention(df)
    return report
end

"""
    create_schema_validator(schema::CriticalPointsSchema = DEFAULT_SCHEMA) -> Function

Create a validator function for the given schema.
"""
function create_schema_validator(schema::CriticalPointsSchema = DEFAULT_SCHEMA)
    return function(df::DataFrame)
        return validate_schema(df, schema)
    end
end

"""
    filter_critical_points(df::DataFrame, schema::CriticalPointsSchema = DEFAULT_SCHEMA) -> DataFrame

Filter DataFrame to include only critical points (type == "critical").
"""
function filter_critical_points(df::DataFrame, schema::CriticalPointsSchema = DEFAULT_SCHEMA)::DataFrame
    # Validate schema first
    validation = validate_schema(df, schema)
    if !validation.valid
        throw(ArgumentError("Invalid DataFrame schema: $(validation.error)"))
    end

    if "type" in names(df)
        return filter(row -> row.type == "critical", df)
    else
        throw(ArgumentError("DataFrame missing 'type' column required for filtering critical points"))
    end
end

"""
    summary_statistics(df::DataFrame, schema::CriticalPointsSchema = DEFAULT_SCHEMA) -> Dict{String, Any}

Compute summary statistics for critical point DataFrame.
"""
function summary_statistics(df::DataFrame, schema::CriticalPointsSchema = DEFAULT_SCHEMA)::Dict{String, Any}
    # Validate schema
    validation = validate_schema(df, schema)
    if !validation.valid
        throw(ArgumentError("Invalid DataFrame schema: $(validation.error)"))
    end

    stats = Dict{String, Any}(
        "total_rows" => nrow(df),
        "columns" => names(df),
        "column_convention" => validation.detected_convention
    )

    # Statistics for critical values
    try
        values = get_critical_values(df, schema)
        stats["critical_values"] = Dict(
            "count" => length(values),
            "min" => minimum(values),
            "max" => maximum(values),
            "mean" => sum(values) / length(values),
            "std" => length(values) > 1 ? sqrt(sum((values .- sum(values)/length(values)).^2) / (length(values)-1)) : 0.0
        )
    catch e
        stats["critical_values_error"] = string(e)
    end

    # Type distribution if available
    if "type" in names(df)
        type_counts = Dict{String, Int}()
        for type_val in df[!, "type"]
            type_counts[type_val] = get(type_counts, type_val, 0) + 1
        end
        stats["type_distribution"] = type_counts
    end

    return stats
end

"""
    safe_column_access(df::DataFrame, column_name::String, default_value=missing)

Safely access DataFrame column with optional default value.
"""
function safe_column_access(df::DataFrame, column_name::String, default_value=missing)
    if column_name in names(df)
        return df[!, column_name]
    else
        if default_value === missing
            throw(ArgumentError("Column '$(column_name)' not found in DataFrame. Available: $(join(names(df), ", "))"))
        else
            return fill(default_value, nrow(df))
        end
    end
end

# Utility functions for common operations
"""
    quick_validate(df::DataFrame) -> Bool

Quick validation check for DataFrame compatibility.
"""
function quick_validate(df::DataFrame)::Bool
    validation = validate_schema(df)
    return validation.valid
end

"""
    repair_dataframe!(df::DataFrame, schema::CriticalPointsSchema = DEFAULT_SCHEMA) -> Dict{String, Any}

Attempt to repair common DataFrame issues automatically.
"""
function repair_dataframe!(df::DataFrame, schema::CriticalPointsSchema = DEFAULT_SCHEMA)::Dict{String, Any}
    repair_report = Dict{String, Any}(
        "initial_validation" => validate_schema(df, schema),
        "repairs_attempted" => String[],
        "repairs_successful" => String[],
        "final_validation" => nothing
    )

    # Attempt standardization
    push!(repair_report["repairs_attempted"], "column_standardization")
    std_report = standardize_columns!(df, schema)
    if std_report["migration_performed"] || !isempty(std_report["columns_removed"])
        push!(repair_report["repairs_successful"], "column_standardization")
    end

    # Final validation
    repair_report["final_validation"] = validate_schema(df, schema)
    repair_report["standardization_report"] = std_report

    return repair_report
end

"""
    quick_validate_any_schema(df::DataFrame) -> Bool

Smart validation that automatically detects data type and uses appropriate schema.
"""
function quick_validate_any_schema(df::DataFrame)::Bool
    data_type = detect_data_type(df)

    if data_type == "critical_points"
        return validate_schema(df, DEFAULT_CRITICAL_POINTS_SCHEMA).valid
    elseif data_type == "experiment_comparison"
        return validate_schema(df, DEFAULT_EXPERIMENT_SCHEMA).valid
    else
        # For unknown data types, return true and let other parts of the system handle it
        return true
    end
end


# Transformation functions for Semantic Data Pipeline

"""
    transform_to_experiment_summary(df::DataFrame) -> DataFrame

Transform granular critical points data into aggregated experiment summary format.

Input format (critical points):
- x1, x2, x3, x4: Parameter coordinates
- z: Critical value
- experiment_id: Experiment identifier
- degree, domain_size, timestamp: Experiment metadata

Output format (experiment comparison):
- experiment_id: Experiment identifier
- mean_l2_overall: Mean of all critical values
- best_l2: Minimum critical value
- worst_l2: Maximum critical value
- num_critical_points: Count of critical points
- degree, domain_size, timestamp: Preserved metadata
"""
function transform_to_experiment_summary(df::DataFrame)::DataFrame
    # Validate input is critical points data
    if detect_data_type(df) != "critical_points"
        throw(ArgumentError("Input DataFrame is not critical points data. Expected columns with 'z' and 'experiment_id'."))
    end

    # Validate required columns
    required_cols = ["z", "experiment_id"]
    missing_cols = setdiff(required_cols, names(df))
    if !isempty(missing_cols)
        throw(ArgumentError("Missing required columns: $(join(missing_cols, ", "))"))
    end

    # Statistics functions are now available from top-level import

    # Group by experiment_id and compute aggregated metrics
    summary_df = combine(groupby(df, :experiment_id)) do group
        critical_values = collect(skipmissing(group.z))

        if isempty(critical_values)
            # Handle empty group case
            return DataFrame(
                mean_l2_overall = [missing],
                best_l2 = [missing],
                worst_l2 = [missing],
                num_critical_points = [0],
                degree = "degree" in names(group) ? [first(group.degree)] : [missing],
                domain_size = "domain_size" in names(group) ? [first(group.domain_size)] : [missing],
                timestamp = "timestamp" in names(group) ? [first(group.timestamp)] : [missing]
            )
        end

        # Compute aggregated statistics
        return DataFrame(
            mean_l2_overall = [mean(critical_values)],
            best_l2 = [minimum(critical_values)],
            worst_l2 = [maximum(critical_values)],
            num_critical_points = [length(critical_values)],
            degree = "degree" in names(group) ? [first(group.degree)] : [missing],
            domain_size = "domain_size" in names(group) ? [first(group.domain_size)] : [missing],
            timestamp = "timestamp" in names(group) ? [first(group.timestamp)] : [missing]
        )
    end

    return summary_df
end

"""
    transform_to_critical_points(df::DataFrame) -> DataFrame

Transform experiment summary data back to critical points format (placeholder/identity function).

Note: This transformation loses information and is mainly for interface consistency.
In practice, you cannot accurately reconstruct granular critical points from summary statistics.
"""
function transform_to_critical_points(df::DataFrame)::DataFrame
    # Validate input is experiment comparison data
    if detect_data_type(df) != "experiment_comparison"
        throw(ArgumentError("Input DataFrame is not experiment comparison data. Expected columns with 'mean_l2_overall' and 'experiment_id'."))
    end

    # This transformation is intentionally limited - you cannot reconstruct granular data from summary
    # Return a synthetic representation using the mean values

    synthetic_df = DataFrame()

    for row in eachrow(df)
        # Create synthetic critical points using mean value
        # This is a placeholder - real transformation would require original data
        synthetic_point = DataFrame(
            x1 = [missing],  # Parameter coordinates cannot be reconstructed
            x2 = [missing],
            x3 = [missing],
            x4 = [missing],
            z = [row.mean_l2_overall],  # Use mean as representative value
            experiment_id = [row.experiment_id],
            degree = hasproperty(row, :degree) ? [row.degree] : [missing],
            domain_size = hasproperty(row, :domain_size) ? [row.domain_size] : [missing],
            timestamp = hasproperty(row, :timestamp) ? [row.timestamp] : [missing],
            source_file = ["synthetic_from_summary.csv"]
        )

        synthetic_df = vcat(synthetic_df, synthetic_point)
    end

    return synthetic_df
end

# Helper function (moved to end to avoid export issues)
function get_critical_value_column(df::DataFrame, schema::CriticalPointsSchema)::Vector{Float64}
    # Try preferred column first
    if schema.preferred_value_column in names(df)
        return collect(skipmissing(df[!, schema.preferred_value_column]))
    else
        # Try other value columns
        for col in schema.value_columns
            if col in names(df)
                return collect(skipmissing(df[!, col]))
            end
        end
    end

    # Fallback: return empty vector
    return Float64[]
end

end # module DataFrameInterface