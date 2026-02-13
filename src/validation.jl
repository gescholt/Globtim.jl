"""
Validation Module - Consolidated Validation Framework

Comprehensive validation framework consolidating:
- Data validation (DataFrame, CSV, column types)
- Pipeline stage transition validation
- Defense-in-depth integration
- Error categorization and reporting

This module replaces and consolidates:
- ValidationBoundaries.jl (439 LOC)
- PipelineErrorBoundaries.jl (701 LOC)
- PipelineDefenseIntegration.jl (454 LOC)

Total consolidation: 1,594 LOC → ~800 LOC (50% reduction)

Author: GlobTim Project
Date: February 2026
"""

using DataFrames
using CSV
using Statistics
using Dates
using JSON3

# Canonical result types are imported when this file is included in Globtim.jl
# They are: ValidationResult, CSVLoadResult, BoundaryResult, DefenseResult
# (defined in data_structures.jl which is included before this file)

# Import defensive CSV infrastructure (will be consolidated in Phase 4)
include("DefensiveCSV.jl")
using .DefensiveCSV

# Import error categorization (will be reviewed in Phase 4)
include("ErrorCategorization.jl")
using .ErrorCategorization

# ============================================================================
# UNIFIED ERROR TYPE HIERARCHY
# ============================================================================

"""
Base abstract type for all validation-related errors.
"""
abstract type ValidationError <: Exception end

# Data Validation Errors (from ValidationBoundaries.jl)
abstract type DataValidationError <: ValidationError end

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

# Pipeline Boundary Errors (from PipelineErrorBoundaries.jl)
abstract type PipelineBoundaryError <: ValidationError end

struct StageTransitionError <: PipelineBoundaryError
    from_stage::String
    to_stage::String
    failure_point::String
    recovery_action::String
    context::Dict{String, Any}
end

struct InterfaceCompatibilityError <: PipelineBoundaryError
    interface_type::String
    expected_format::String
    actual_format::String
    compatibility_issues::Vector{String}
    fix_suggestions::Vector{String}
end

struct ResourceBoundaryError <: PipelineBoundaryError
    resource_type::String
    limit_exceeded::String
    current_usage::String
    recommended_action::String
end

struct FileSystemBoundaryError <: PipelineBoundaryError
    operation_type::String
    file_path::String
    failure_reason::String
    recovery_steps::Vector{String}
end

# ============================================================================
# DEFENSE SEVERITY LEVELS
# ============================================================================

const DEFENSE_SUCCESS = "SUCCESS"
const DEFENSE_WARNING = "WARNING"
const DEFENSE_ERROR = "ERROR"
const DEFENSE_CRITICAL = "CRITICAL"

# ============================================================================
# PIPELINE BOUNDARY DEFINITIONS
# ============================================================================

struct PipelineBoundary
    name::String
    description::String
    validation_function::Function
    recovery_function::Function
    timeout_seconds::Int

    function PipelineBoundary(name::String, description::String,
                            validation_func::Function, recovery_func::Function,
                            timeout::Int=30)
        new(name, description, validation_func, recovery_func, timeout)
    end
end

# Predefined boundary constants
const HPC_JOB_BOUNDARY = "hpc_job_submission_to_collection"
const DATA_PROCESSING_BOUNDARY = "data_collection_to_processing"
const VISUALIZATION_BOUNDARY = "processing_to_visualization"
const FILE_OPERATION_BOUNDARY = "file_operations_to_data_loading"

# ============================================================================
# DATAFRAME VALIDATION FUNCTIONS
# ============================================================================

"""
    chain_validation(result::ValidationResult{T}, next_validator::Function)::ValidationResult{T} where T

Chain validation functions using the Railway Pattern for composable validation.
"""
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

"""
    validate_column_type(df::DataFrame, col::Symbol, expected_type::Type)::ValidationResult{DataFrame}

Validate that a DataFrame column has the expected type.
"""
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

    return ValidationResult(true, df, [], String[], 100.0)
end

"""
    safe_read_csv(filepath::String; required_columns::Vector{Symbol}=Symbol[],
                  expected_types::Dict{Symbol, DataType}=Dict{Symbol, DataType}())::ValidationResult{DataFrame}

Defensive CSV reading with type checking and validation.
"""
function safe_read_csv(filepath::String;
                      required_columns::Vector{Symbol}=Symbol[],
                      expected_types::Dict{Symbol, DataType}=Dict{Symbol, DataType}())::ValidationResult{DataFrame}

    !isfile(filepath) && return ValidationResult{DataFrame}(
        false, nothing, [DataLoadError(filepath, "File not found")], [], 0.0
    )

    try
        df = CSV.read(filepath, DataFrame;
            silencewarnings=true,
            types=Dict(),
            strict=false
        )

        errors = []
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

"""
    detect_filename_contamination(df::DataFrame, threshold_pct::Float64=10.0)::ValidationResult{DataFrame}

Detect filename contamination in DataFrame columns with specific patterns.
"""
function detect_filename_contamination(df::DataFrame, threshold_pct::Float64=10.0)::ValidationResult{DataFrame}
    contamination_errors = []
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

"""
    validate_parameter_ranges(df::DataFrame, param_columns::Vector{Symbol}=[:x1, :x2, :x3, :x4],
                             expected_range::Tuple{Float64, Float64}=(0.0, 10.0))::ValidationResult{DataFrame}

Validate parameter ranges for biological/scientific parameters.
"""
function validate_parameter_ranges(df::DataFrame,
                                 param_columns::Vector{Symbol}=[:x1, :x2, :x3, :x4],
                                 expected_range::Tuple{Float64, Float64}=(0.0, 10.0))::ValidationResult{DataFrame}

    range_errors = []
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

        # Check for values outside expected range
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

"""
    validate_experiment_output_strict(df::DataFrame)::ValidationResult{DataFrame}

Comprehensive data validation pipeline for experiment output.
"""
function validate_experiment_output_strict(df::DataFrame)::ValidationResult{DataFrame}
    # Define expected schema for experiment data
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

# ============================================================================
# HPC WORKFLOW INTEGRATION FUNCTIONS
# ============================================================================

"""
    save_experiment_results_safe(results::DataFrame, filepath::String;
                                validation_required::Bool=true)::ValidationResult{String}

Save experiment results with validation and verification.
"""
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

"""
    verify_written_data(filepath::String, original_data::DataFrame)::ValidationResult{DataFrame}

Verify that written data matches original data.
"""
function verify_written_data(filepath::String, original_data::DataFrame)::ValidationResult{DataFrame}
    try
        read_back = CSV.read(filepath, DataFrame)

        if size(read_back) != size(original_data)
            return ValidationResult{DataFrame}(false, nothing,
                                             [DataProductionError("file_verification",
                                                                 "Data dimensions changed during write",
                                                                 Dict("original" => size(original_data),
                                                                      "read_back" => size(read_back)))],
                                             [], 0.0)
        end

        return ValidationResult(true, read_back, [], String[], 100.0)

    catch e
        return ValidationResult{DataFrame}(false, nothing,
                                         [DataProductionError("file_verification",
                                                             "Could not verify written data: $e",
                                                             Dict("filepath" => filepath))],
                                         [], 0.0)
    end
end

"""
    load_and_validate_experiment_data(filepath::String;
                                     quality_threshold::Float64=70.0)::DataFrame

Load and validate experiment data with quality gates.
"""
function load_and_validate_experiment_data(filepath::String;
                                         quality_threshold::Float64=70.0)::DataFrame
    load_result = safe_read_csv(filepath;
        required_columns=[:x1, :x2, :x3, :x4, :z, :experiment_id],
        expected_types=Dict(:x1=>Float64, :x2=>Float64, :x3=>Float64, :x4=>Float64, :z=>Float64)
    )

    !load_result.success && throw(DataLoadError(filepath, "Failed to load: $(join([string(e) for e in load_result.errors], "; "))"))

    # Validate data quality
    validation = validate_experiment_output_strict(load_result.data)

    if validation.quality_score < quality_threshold
        throw(DataQualityError(validation.quality_score, quality_threshold,
                              "Data quality insufficient: $(validation.quality_score) < $quality_threshold"))
    end

    return load_result.data
end

# ============================================================================
# PIPELINE STAGE TRANSITION VALIDATION
# ============================================================================

"""
    validate_stage_transition(from_stage::String, to_stage::String, data::Any;
                             context::Dict{String, Any}=Dict{String, Any}()) -> BoundaryResult

Validate transition between pipeline stages with comprehensive error detection.
"""
function validate_stage_transition(from_stage::String, to_stage::String, data::Any;
                                 context::Dict{String, Any}=Dict{String, Any}())
    start_time = time()
    errors = []
    warnings = String[]
    recovery_actions = String[]

    boundary_name = "$(from_stage)_to_$(to_stage)"

    try
        # Stage-specific validation logic
        if from_stage == "hpc_execution" && to_stage == "result_collection"
            result = validate_hpc_to_collection_boundary(data, context)
            append!(errors, result.errors)
            append!(warnings, result.warnings)
            append!(recovery_actions, result.recovery_actions)

        elseif from_stage == "data_collection" && to_stage == "processing_pipeline"
            result = validate_collection_to_processing_boundary(data, context)
            append!(errors, result.errors)
            append!(warnings, result.warnings)
            append!(recovery_actions, result.recovery_actions)

        elseif from_stage == "processing_pipeline" && to_stage == "visualization"
            result = validate_processing_to_visualization_boundary(data, context)
            append!(errors, result.errors)
            append!(warnings, result.warnings)
            append!(recovery_actions, result.recovery_actions)

        elseif from_stage == "file_system" && to_stage == "data_loading"
            result = validate_filesystem_to_loading_boundary(data, context)
            append!(errors, result.errors)
            append!(warnings, result.warnings)
            append!(recovery_actions, result.recovery_actions)

        else
            # Generic stage transition validation
            result = validate_generic_stage_transition(from_stage, to_stage, data, context)
            append!(errors, result.errors)
            append!(warnings, result.warnings)
            append!(recovery_actions, result.recovery_actions)
        end

        validation_time = time() - start_time
        success = isempty(errors)

        metadata = Dict{String, Any}(
            "from_stage" => from_stage,
            "to_stage" => to_stage,
            "data_type" => string(typeof(data)),
            "validation_duration" => validation_time,
            "timestamp" => Dates.now()
        )

        return BoundaryResult(success, boundary_name, validation_time, errors, warnings, recovery_actions, metadata)

    catch e
        validation_time = time() - start_time
        push!(errors, StageTransitionError(from_stage, to_stage, "validation_exception",
                                         "Check stage transition logic",
                                         Dict("exception" => string(e))))

        return BoundaryResult(false, boundary_name, validation_time, errors, warnings, recovery_actions,
                            Dict("validation_failed" => true, "exception" => string(e)))
    end
end

# Individual boundary validators
function validate_hpc_to_collection_boundary(data::Any, context::Dict{String, Any})
    errors = []
    warnings = String[]
    recovery_actions = String[]

    if isa(data, DataFrame)
        expected_hpc_columns = [:experiment_id, :z, :x1, :x2, :x3, :x4]
        missing_columns = setdiff(expected_hpc_columns, Symbol.(names(data)))

        if !isempty(missing_columns)
            push!(errors, InterfaceCompatibilityError(
                "hpc_result_schema",
                "Standard HPC experiment columns: $(join(expected_hpc_columns, ", "))",
                "Found columns: $(join(names(data), ", "))",
                ["Missing critical columns: $(join(missing_columns, ", "))"],
                ["Verify HPC script output format", "Check experiment data generation"]
            ))
            push!(recovery_actions, "IMMEDIATE: Verify HPC experiment script generates required columns")
        end

        # Check for interface issues (val vs z column naming)
        if "val" in names(data) && !("z" in names(data))
            push!(errors, InterfaceCompatibilityError(
                "column_naming_interface",
                "L2 norm column should be named 'z'",
                "Found column named 'val' instead",
                ["Column 'val' detected instead of expected 'z'"],
                ["Rename 'val' column to 'z' in HPC script", "Update data collection logic"]
            ))
            push!(recovery_actions, "CRITICAL: Fix column naming in HPC experiment script (val → z)")
        end

        # Check for suspicious data quality patterns
        if "z" in names(data)
            z_values = collect(skipmissing(data.z))
            if !isempty(z_values) && all(isa.(z_values, Number))
                if any(z -> z < 0, z_values)
                    push!(warnings, "Negative L2 norm values detected - indicates computation errors")
                    push!(recovery_actions, "INVESTIGATE: Check HPC computation logic for L2 norm calculation")
                end

                if any(z -> z > 100, z_values)
                    push!(warnings, "Very large L2 norm values (>100) - may indicate convergence failures")
                    push!(recovery_actions, "OPTIMIZE: Review convergence criteria in HPC experiments")
                end
            end
        end

    elseif isa(data, String) && isfile(data)
        result = defensive_csv_read(data, detect_interface_issues=true)
        if !result.success
            push!(errors, FileSystemBoundaryError(
                "hpc_result_file_loading",
                data,
                result.error,
                ["Verify file integrity", "Check file permissions", "Validate CSV format"]
            ))
            push!(recovery_actions, "IMMEDIATE: Fix HPC result file: $(result.error)")
        else
            for warning in result.warnings
                if contains(warning, "INTERFACE ISSUE")
                    push!(errors, InterfaceCompatibilityError(
                        "csv_interface_issue",
                        "Standard interface format",
                        "Detected interface problem",
                        [warning],
                        ["Fix column naming in HPC output", "Update data generation logic"]
                    ))
                    push!(recovery_actions, "FIX: $warning")
                end
            end
        end

    else
        push!(errors, StageTransitionError(
            "hpc_execution", "result_collection",
            "data_type_validation",
            "Provide DataFrame or file path for HPC results",
            Dict("received_type" => string(typeof(data)))
        ))
        push!(recovery_actions, "IMMEDIATE: Provide valid HPC result data (DataFrame or file path)")
    end

    return (errors=errors, warnings=warnings, recovery_actions=recovery_actions)
end

function validate_collection_to_processing_boundary(data::Any, context::Dict{String, Any})
    errors = []
    warnings = String[]
    recovery_actions = String[]

    if isa(data, DataFrame)
        # Memory boundary check
        data_size_mb = Base.summarysize(data) / (1024^2)
        if data_size_mb > 1000  # 1GB limit
            push!(errors, ResourceBoundaryError(
                "memory",
                "Data size exceeds 1GB limit",
                "$(round(data_size_mb, digits=1)) MB",
                "Consider data chunking or filtering"
            ))
            push!(recovery_actions, "OPTIMIZE: Implement data chunking for large datasets")
        end

        # Validate processing pipeline schema expectations
        processing_required_columns = [:experiment_id, :degree]
        missing_cols = setdiff(processing_required_columns, Symbol.(names(data)))

        if !isempty(missing_cols)
            push!(errors, InterfaceCompatibilityError(
                "processing_pipeline_schema",
                "Processing requires: $(join(processing_required_columns, ", "))",
                "Missing: $(join(missing_cols, ", "))",
                ["Required columns not found for processing pipeline"],
                ["Verify data collection includes all required metadata", "Update collection logic"]
            ))
            push!(recovery_actions, "CRITICAL: Ensure data collection includes processing metadata")
        end

    else
        push!(errors, StageTransitionError(
            "data_collection", "processing_pipeline",
            "data_format_validation",
            "Processing pipeline requires DataFrame input",
            Dict("received_type" => string(typeof(data)))
        ))
        push!(recovery_actions, "IMMEDIATE: Convert collected data to DataFrame format")
    end

    return (errors=errors, warnings=warnings, recovery_actions=recovery_actions)
end

function validate_processing_to_visualization_boundary(data::Any, context::Dict{String, Any})
    errors = []
    warnings = String[]
    recovery_actions = String[]

    if isa(data, DataFrame)
        viz_columns = [:mean_l2_overall, :best_l2, :worst_l2]
        available_viz_cols = intersect(viz_columns, Symbol.(names(data)))

        if isempty(available_viz_cols)
            if "z" in names(data) && "experiment_id" in names(data)
                push!(warnings, "Raw data detected - requires aggregation for visualization")
                push!(recovery_actions, "TRANSFORM: Aggregate raw critical point data for visualization")
            else
                push!(errors, InterfaceCompatibilityError(
                    "visualization_data_format",
                    "Visualization requires aggregated metrics: $(join(viz_columns, ", "))",
                    "Found columns: $(join(names(data), ", "))",
                    ["No visualization-ready aggregations found"],
                    ["Transform raw data to experiment summaries", "Include aggregation step"]
                ))
                push!(recovery_actions, "CRITICAL: Transform data for visualization compatibility")
            end
        end

    else
        push!(errors, StageTransitionError(
            "processing_pipeline", "visualization",
            "visualization_input_validation",
            "Visualization requires processed DataFrame",
            Dict("received_type" => string(typeof(data)))
        ))
        push!(recovery_actions, "IMMEDIATE: Ensure processing outputs DataFrame for visualization")
    end

    return (errors=errors, warnings=warnings, recovery_actions=recovery_actions)
end

function validate_filesystem_to_loading_boundary(data::Any, context::Dict{String, Any})
    errors = []
    warnings = String[]
    recovery_actions = String[]

    if isa(data, String)
        if !isfile(data)
            push!(errors, FileSystemBoundaryError(
                "file_access",
                data,
                "File not found or inaccessible",
                ["Verify file path", "Check file permissions", "Confirm file creation completed"]
            ))
            push!(recovery_actions, "IMMEDIATE: Verify file exists at path: $data")
        else
            file_size = stat(data).size
            if file_size == 0
                push!(errors, FileSystemBoundaryError(
                    "file_integrity",
                    data,
                    "File is empty",
                    ["Check file generation process", "Verify write operations completed"]
                ))
                push!(recovery_actions, "CRITICAL: Fix empty file generation")
            end

            if endswith(data, ".csv")
                result = defensive_csv_read(data, validate_columns=false)
                if !result.success
                    push!(errors, FileSystemBoundaryError(
                        "csv_format_validation",
                        data,
                        result.error,
                        ["Fix CSV format issues", "Validate data generation", "Check encoding"]
                    ))
                    push!(recovery_actions, "FIX: $(result.error)")
                end
            end
        end

    else
        push!(errors, StageTransitionError(
            "file_system", "data_loading",
            "file_path_validation",
            "Provide valid file path string",
            Dict("received_type" => string(typeof(data)))
        ))
        push!(recovery_actions, "IMMEDIATE: Provide valid file path for data loading")
    end

    return (errors=errors, warnings=warnings, recovery_actions=recovery_actions)
end

function validate_generic_stage_transition(from_stage::String, to_stage::String, data::Any, context::Dict{String, Any})
    errors = []
    warnings = String[]
    recovery_actions = String[]

    if data === nothing
        push!(errors, StageTransitionError(
            from_stage, to_stage,
            "null_data_validation",
            "Provide non-null data for stage transition",
            Dict("context" => context)
        ))
        push!(recovery_actions, "IMMEDIATE: Ensure previous stage outputs valid data")
    end

    push!(warnings, "Unknown stage transition - using generic validation")
    push!(recovery_actions, "ENHANCE: Implement specific validation for $(from_stage) → $(to_stage)")

    return (errors=errors, warnings=warnings, recovery_actions=recovery_actions)
end

"""
    detect_interface_issues(data::Any; context::Dict{String, Any}=Dict{String, Any}()) -> BoundaryResult

Detect common interface issues across data formats and pipeline connections.
"""
function detect_interface_issues(data::Any; context::Dict{String, Any}=Dict{String, Any}())
    start_time = time()
    errors = []
    warnings = String[]
    recovery_actions = String[]

    if isa(data, DataFrame)
        column_names = names(data)

        # Critical interface issues
        if "val" in column_names && !("z" in column_names)
            push!(errors, InterfaceCompatibilityError(
                "critical_column_naming",
                "L2 norm column must be named 'z'",
                "Found 'val' column instead",
                ["Column 'val' breaks downstream computations expecting 'z'"],
                ["Rename 'val' → 'z' in data generation", "Update column mapping logic"]
            ))
            push!(recovery_actions, "CRITICAL: Fix val→z column naming immediately")
        end

        # Parameter naming inconsistencies
        param_issues = String[]
        if "exp_name" in column_names && !("experiment_id" in column_names)
            push!(param_issues, "exp_name should be experiment_id")
        end
        if "polynomial_degree" in column_names && !("degree" in column_names)
            push!(param_issues, "polynomial_degree should be degree")
        end

        if !isempty(param_issues)
            push!(warnings, "Parameter naming inconsistencies detected")
            push!(recovery_actions, "STANDARDIZE: Fix parameter naming: $(join(param_issues, ", "))")
        end

        # Data type interface issues
        if "degree" in column_names
            degrees = collect(skipmissing(data.degree))
            if !isempty(degrees) && !all(isa.(degrees, Number))
                push!(errors, InterfaceCompatibilityError(
                    "degree_data_type",
                    "Degree column must contain numeric values",
                    "Found non-numeric degree values",
                    ["String/categorical degree values break numeric processing"],
                    ["Convert degree column to numeric", "Fix data generation types"]
                ))
                push!(recovery_actions, "CRITICAL: Fix non-numeric degree values")
            end
        end

    elseif isa(data, String) && isfile(data)
        result = defensive_csv_read(data, detect_interface_issues=true)

        for warning in result.warnings
            if contains(warning, "INTERFACE ISSUE")
                push!(errors, InterfaceCompatibilityError(
                    "csv_interface_compatibility",
                    "Standard pipeline interface format",
                    "CSV file interface issue detected",
                    [warning],
                    ["Fix data generation format", "Update CSV export logic"]
                ))
                push!(recovery_actions, "FIX CSV: $warning")
            elseif contains(warning, "DATA ISSUE")
                push!(warnings, warning)
                push!(recovery_actions, "INVESTIGATE: $warning")
            end
        end
    end

    validation_time = time() - start_time
    success = isempty(errors)

    metadata = Dict{String, Any}(
        "detection_duration" => validation_time,
        "data_type" => string(typeof(data)),
        "timestamp" => Dates.now(),
        "context" => context
    )

    return BoundaryResult(success, "interface_issue_detection", validation_time,
                        errors, warnings, recovery_actions, metadata)
end

"""
    validate_pipeline_connection(connection_points::Vector{Pair{String, Any}};
                                context::Dict{String, Any}=Dict{String, Any}()) -> Vector{BoundaryResult}

Validate multiple pipeline connection points in sequence.
"""
function validate_pipeline_connection(connection_points::Vector{Pair{String, Any}};
                                    context::Dict{String, Any}=Dict{String, Any}())
    results = BoundaryResult[]

    for i in 1:(length(connection_points) - 1)
        from_stage, from_data = connection_points[i]
        to_stage, to_data = connection_points[i + 1]

        result = validate_stage_transition(from_stage, to_stage, from_data, context=context)
        push!(results, result)

        # If critical errors, stop validation chain
        if !result.success && any(e -> isa(e, StageTransitionError) || isa(e, InterfaceCompatibilityError), result.errors)
            break
        end
    end

    return results
end

# ============================================================================
# DEFENSE-IN-DEPTH INTEGRATION
# ============================================================================

"""
    enhanced_pipeline_validation(data::Any, stage_info::Dict{String, Any};
                                context::Dict{String, Any}=Dict{String, Any}()) -> DefenseResult

Comprehensive pipeline validation using all available defensive systems.
"""
function enhanced_pipeline_validation(data::Any, stage_info::Dict{String, Any};
                                    context::Dict{String, Any}=Dict{String, Any}())
    start_time = time()

    boundary_results = BoundaryResult[]
    csv_result = nothing
    validation_result = nothing
    error_category = nothing
    actionable_steps = String[]
    critical_failures = String[]

    try
        from_stage = get(stage_info, "from_stage", "unknown")
        to_stage = get(stage_info, "to_stage", "unknown")

        # 1. Pipeline boundary validation
        @debug "Running pipeline boundary validation..."
        boundary_result = validate_stage_transition(from_stage, to_stage, data, context=context)
        push!(boundary_results, boundary_result)

        append!(actionable_steps, boundary_result.recovery_actions)
        if !boundary_result.success
            for error in boundary_result.errors
                if isa(error, InterfaceCompatibilityError) || isa(error, StageTransitionError)
                    push!(critical_failures, format_boundary_error(error))
                end
            end
        end

        # 2. Interface issue detection
        @debug "Running interface issue detection..."
        interface_result = detect_interface_issues(data, context=context)
        push!(boundary_results, interface_result)
        append!(actionable_steps, interface_result.recovery_actions)

        # 3. CSV specific validation if applicable
        if isa(data, String) && isfile(data) && endswith(data, ".csv")
            @debug "Running defensive CSV validation..."
            csv_result = defensive_csv_read(data,
                                          validate_columns=true,
                                          detect_interface_issues=true)

            for warning in csv_result.warnings
                if contains(warning, "INTERFACE ISSUE") || contains(warning, "DATA ISSUE")
                    push!(actionable_steps, "CSV FIX: $warning")
                end
            end

            if !csv_result.success
                push!(critical_failures, "CSV Loading Failed: $(csv_result.error)")
            end
        end

        # 4. Data validation if DataFrame
        if isa(data, DataFrame) || (csv_result !== nothing && csv_result.success)
            @debug "Running data validation boundaries..."
            df_to_validate = isa(data, DataFrame) ? data : csv_result.data

            validation_result = validate_experiment_output_strict(df_to_validate)

            if !validation_result.success
                for error in validation_result.errors
                    push!(critical_failures, format_validation_error(error))

                    if isa(error, FilenameContaminationError)
                        push!(actionable_steps, "CRITICAL: Clean filename contamination in column '$(error.column)'")
                    elseif isa(error, ParameterRangeError)
                        push!(actionable_steps, "FIX: Correct parameter '$(error.parameter)' values outside range")
                    elseif isa(error, SchemaValidationError)
                        push!(actionable_steps, "SCHEMA: Fix column '$(error.column)' type mismatch")
                    end
                end
            end
        end

        # 5. Error categorization
        if !isempty(critical_failures)
            @debug "Running error categorization..."
            error_text = join(critical_failures, "\n")
            error_category = categorize_error(error_text, context=Dict{String, Any}("source" => "pipeline_validation"))
        end

        # Determine overall status
        overall_status = if !isempty(critical_failures)
            DEFENSE_CRITICAL
        elseif any(r -> !r.success, boundary_results) || (csv_result !== nothing && !csv_result.success) ||
               (validation_result !== nothing && !validation_result.success)
            DEFENSE_ERROR
        elseif any(r -> !isempty(r.warnings), boundary_results) ||
               (csv_result !== nothing && !isempty(csv_result.warnings))
            DEFENSE_WARNING
        else
            DEFENSE_SUCCESS
        end

        validation_time = time() - start_time

        metadata = Dict{String, Any}(
            "stages" => "$(from_stage) → $(to_stage)",
            "data_type" => string(typeof(data)),
            "validation_systems" => ["BoundaryValidation", "DefensiveCSV", "DataValidation", "ErrorCategorization"],
            "timestamp" => Dates.now(),
            "context" => context
        )

        return DefenseResult(overall_status, validation_time, boundary_results,
                           csv_result, validation_result, error_category,
                           unique(actionable_steps), critical_failures, metadata)

    catch e
        validation_time = time() - start_time
        push!(critical_failures, "Defense integration failed: $e")

        metadata = Dict{String, Any}(
            "integration_error" => string(e),
            "timestamp" => Dates.now()
        )

        return DefenseResult(DEFENSE_CRITICAL, validation_time, boundary_results,
                           nothing, nothing, nothing, actionable_steps, critical_failures, metadata)
    end
end

"""
    validate_hpc_pipeline_stage(stage_name::String, data_path::String;
                               experiment_context::Dict{String, Any}=Dict{String, Any}()) -> DefenseResult

Specialized validation for HPC pipeline stages.
"""
function validate_hpc_pipeline_stage(stage_name::String, data_path::String;
                                   experiment_context::Dict{String, Any}=Dict{String, Any}())

    stage_mapping = Dict(
        "validation" => ("pre_execution", "hpc_submission"),
        "preparation" => ("hpc_submission", "resource_allocation"),
        "execution" => ("resource_allocation", "hpc_computation"),
        "monitoring" => ("hpc_computation", "result_generation"),
        "completion" => ("result_generation", "result_collection"),
        "recovery" => ("error_state", "recovery_action")
    )

    from_stage, to_stage = get(stage_mapping, stage_name, ("unknown_from", "unknown_to"))

    stage_info = Dict{String, Any}(
        "from_stage" => from_stage,
        "to_stage" => to_stage,
        "hpc_stage" => stage_name
    )

    context = merge(experiment_context, Dict{String, Any}(
        "hpc_pipeline_stage" => stage_name,
        "orchestrator_integration" => true,
        "data_path" => data_path
    ))

    return enhanced_pipeline_validation(data_path, stage_info, context=context)
end

# ============================================================================
# UTILITY FUNCTIONS - ERROR FORMATTING AND REPORTING
# ============================================================================

"""
    format_validation_error(error::DataValidationError) -> String

Format data validation errors with helpful formatting.
"""
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

"""
    format_boundary_error(error::PipelineBoundaryError) -> String

Format pipeline boundary errors with clear failure location and actionable recovery steps.
"""
function format_boundary_error(error::PipelineBoundaryError)::String
    if isa(error, StageTransitionError)
        return "🚨 STAGE TRANSITION FAILURE: $(error.from_stage) → $(error.to_stage)\n" *
               "   💥 Failure Point: $(error.failure_point)\n" *
               "   🔧 Recovery Action: $(error.recovery_action)\n" *
               "   📋 Context: $(error.context)"

    elseif isa(error, InterfaceCompatibilityError)
        return "❌ INTERFACE COMPATIBILITY ERROR: $(error.interface_type)\n" *
               "   ✅ Expected: $(error.expected_format)\n" *
               "   ❌ Actual: $(error.actual_format)\n" *
               "   🔍 Issues: $(join(error.compatibility_issues, "; "))\n" *
               "   🔧 Fix: $(join(error.fix_suggestions, "; "))"

    elseif isa(error, ResourceBoundaryError)
        return "⚠️  RESOURCE BOUNDARY VIOLATION: $(error.resource_type)\n" *
               "   📊 Limit Exceeded: $(error.limit_exceeded)\n" *
               "   📈 Current Usage: $(error.current_usage)\n" *
               "   🔧 Recommended: $(error.recommended_action)"

    elseif isa(error, FileSystemBoundaryError)
        return "📁 FILE SYSTEM BOUNDARY ERROR: $(error.operation_type)\n" *
               "   📂 File: $(error.file_path)\n" *
               "   💥 Reason: $(error.failure_reason)\n" *
               "   🔧 Recovery: $(join(error.recovery_steps, "; "))"
    else
        return "❌ PIPELINE BOUNDARY ERROR: $(string(error))"
    end
end

"""
    create_validation_report(result::ValidationResult) -> String

Create comprehensive validation report from ValidationResult.
"""
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

"""
    create_boundary_report(result::BoundaryResult) -> String

Create comprehensive boundary validation report.
"""
function create_boundary_report(result::BoundaryResult)::String
    report = String[]

    push!(report, "═══ PIPELINE BOUNDARY VALIDATION REPORT ═══")
    push!(report, "🎯 Boundary: $(result.boundary_name)")
    push!(report, "⏱️  Validation Time: $(round(result.validation_time * 1000, digits=1))ms")
    push!(report, "📊 Status: $(result.success ? "✅ VALID" : "❌ BOUNDARY VIOLATION")")
    push!(report, "📅 Timestamp: $(get(result.metadata, "timestamp", "N/A"))")

    if !isempty(result.errors)
        push!(report, "\n🚨 CRITICAL BOUNDARY VIOLATIONS ($(length(result.errors))):")
        for (i, error) in enumerate(result.errors)
            push!(report, "$(i). $(format_boundary_error(error))")
        end
    end

    if !isempty(result.warnings)
        push!(report, "\n⚠️  BOUNDARY WARNINGS ($(length(result.warnings))):")
        for warning in result.warnings
            push!(report, "   • $warning")
        end
    end

    if !isempty(result.recovery_actions)
        push!(report, "\n🔧 IMMEDIATE RECOVERY ACTIONS:")
        for (i, action) in enumerate(result.recovery_actions)
            priority = contains(action, "CRITICAL") ? "🚨" : contains(action, "IMMEDIATE") ? "⚡" : "🔧"
            push!(report, "$(i). $priority $action")
        end
    end

    return join(report, "\n")
end

"""
    create_defense_report(result::DefenseResult) -> String

Create comprehensive defense report combining all validation systems.
"""
function create_defense_report(result::DefenseResult)::String
    report = String[]

    push!(report, "╔══════════════════════════════════════════════════════════╗")
    push!(report, "║              COMPREHENSIVE DEFENSE REPORT                ║")
    push!(report, "╚══════════════════════════════════════════════════════════╝")

    status_icon = if result.overall_status == DEFENSE_SUCCESS
        "✅"
    elseif result.overall_status == DEFENSE_WARNING
        "⚠️"
    elseif result.overall_status == DEFENSE_ERROR
        "❌"
    else  # DEFENSE_CRITICAL
        "🚨"
    end

    push!(report, "$status_icon Overall Status: $(result.overall_status)")
    push!(report, "⏱️  Total Validation Time: $(round(result.validation_time * 1000, digits=1))ms")
    push!(report, "🎯 Pipeline Stage: $(get(result.metadata, "stages", "unknown"))")
    push!(report, "📅 Timestamp: $(get(result.metadata, "timestamp", "N/A"))")

    if !isempty(result.critical_failures)
        push!(report, "\n🚨 CRITICAL PIPELINE FAILURES:")
        push!(report, "="^60)
        for (i, failure) in enumerate(result.critical_failures)
            push!(report, "$(i). $failure")
        end
    end

    if !isempty(result.actionable_steps)
        push!(report, "\n🔧 IMMEDIATE ACTIONABLE STEPS:")
        push!(report, "="^45)

        critical_actions = filter(s -> contains(s, "CRITICAL"), result.actionable_steps)
        immediate_actions = filter(s -> contains(s, "IMMEDIATE"), result.actionable_steps)
        other_actions = filter(s -> !contains(s, "CRITICAL") && !contains(s, "IMMEDIATE"), result.actionable_steps)

        for (i, action) in enumerate([critical_actions; immediate_actions; other_actions])
            priority = contains(action, "CRITICAL") ? "🚨" : contains(action, "IMMEDIATE") ? "⚡" : "🔧"
            push!(report, "$(i). $priority $action")
        end
    end

    if !isempty(result.boundary_results)
        push!(report, "\n📊 BOUNDARY VALIDATION DETAILS:")
        push!(report, "="^40)
        for (i, boundary_result) in enumerate(result.boundary_results)
            status = boundary_result.success ? "✅" : "❌"
            push!(report, "$(i). $status $(boundary_result.boundary_name) ($(round(boundary_result.validation_time * 1000, digits=1))ms)")

            if !boundary_result.success && !isempty(boundary_result.errors)
                push!(report, "   Errors: $(length(boundary_result.errors))")
            end
            if !isempty(boundary_result.warnings)
                push!(report, "   Warnings: $(length(boundary_result.warnings))")
            end
        end
    end

    if result.csv_result !== nothing
        push!(report, "\n📄 CSV VALIDATION RESULTS:")
        push!(report, "="^35)
        csv_status = result.csv_result.success ? "✅" : "❌"
        push!(report, "$csv_status File: $(result.csv_result.file)")
        push!(report, "⏱️  Load Time: $(round(result.csv_result.load_time * 1000, digits=1))ms")

        if result.csv_result.success && result.csv_result.data !== nothing
            push!(report, "📊 Data: $(nrow(result.csv_result.data)) rows × $(ncol(result.csv_result.data)) columns")
        end

        if !isempty(result.csv_result.warnings)
            push!(report, "⚠️  Warnings: $(length(result.csv_result.warnings))")
        end
    end

    if result.validation_result !== nothing
        push!(report, "\n🔬 DATA VALIDATION RESULTS:")
        push!(report, "="^35)
        val_status = result.validation_result.success ? "✅" : "❌"
        push!(report, "$val_status Validation Status")
        push!(report, "📈 Quality Score: $(round(result.validation_result.quality_score, digits=1))/100")

        if !isempty(result.validation_result.errors)
            push!(report, "❌ Validation Errors: $(length(result.validation_result.errors))")
        end
    end

    if result.error_category !== nothing
        push!(report, "\n🏷️  ERROR CATEGORIZATION:")
        push!(report, "="^30)

        category = get(result.error_category, "category", "Unknown")
        confidence = get(result.error_category, "confidence", 0.0)
        severity = get(result.error_category, "severity", "Unknown")

        push!(report, "📂 Category: $category")
        push!(report, "🎯 Confidence: $(round(confidence * 100, digits=1))%")
        push!(report, "⚡ Severity: $severity")
    end

    return join(report, "\n")
end

# ============================================================================
# EXPORTS
# ============================================================================

# Error types
export ValidationError, DataValidationError, PipelineBoundaryError
export FilenameContaminationError, ParameterRangeError, SchemaValidationError, ContentValidationError
export DataLoadError, DataQualityError, DataProductionError
export StageTransitionError, InterfaceCompatibilityError, ResourceBoundaryError, FileSystemBoundaryError

# Defense severity levels
export DEFENSE_SUCCESS, DEFENSE_WARNING, DEFENSE_ERROR, DEFENSE_CRITICAL

# Boundary definitions
export PipelineBoundary, HPC_JOB_BOUNDARY, DATA_PROCESSING_BOUNDARY, VISUALIZATION_BOUNDARY, FILE_OPERATION_BOUNDARY

# DataFrame validation functions
export chain_validation, validate_column_type, safe_read_csv
export detect_filename_contamination, validate_parameter_ranges, validate_experiment_output_strict
export save_experiment_results_safe, load_and_validate_experiment_data, verify_written_data

# Pipeline validation functions
export validate_stage_transition, detect_interface_issues, validate_pipeline_connection

# Defense integration functions
export enhanced_pipeline_validation, validate_hpc_pipeline_stage

# Utility functions
export format_validation_error, format_boundary_error
export create_validation_report, create_boundary_report, create_defense_report
