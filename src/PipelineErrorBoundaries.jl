"""
PipelineErrorBoundaries Module - Issue #83 Implementation

Comprehensive defensive error detection framework for pipeline connection points
with concise, actionable error reporting and interface issue detection.

Key Features:
- Stage transition validation
- Interface issue detection (column naming, data format mismatches)
- File system operation boundaries
- Memory and resource boundary violations
- Pinpoint failure location within 10 seconds
- Actionable recovery suggestions

Author: GlobTim Project
Date: September 26, 2025
"""

module PipelineErrorBoundaries

using DataFrames, CSV, Dates, Statistics
using JSON3

# Import existing infrastructure
include("ValidationBoundaries.jl")
using .ValidationBoundaries

include("DefensiveCSV.jl")
using .DefensiveCSV

include("ErrorCategorization.jl")
using .ErrorCategorization

export PipelineBoundary, BoundaryResult, BoundaryError
export validate_stage_transition, detect_interface_issues, format_boundary_error
export HPC_JOB_BOUNDARY, DATA_PROCESSING_BOUNDARY, VISUALIZATION_BOUNDARY, FILE_OPERATION_BOUNDARY
export create_boundary_report, validate_pipeline_connection

# Custom exception hierarchy for pipeline boundaries
abstract type PipelineBoundaryError <: Exception end

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

# Result type for boundary validation
struct BoundaryResult
    success::Bool
    boundary_name::String
    validation_time::Float64
    errors::Vector{PipelineBoundaryError}
    warnings::Vector{String}
    recovery_actions::Vector{String}
    metadata::Dict{String, Any}

    function BoundaryResult(success::Bool, boundary_name::String,
                          validation_time::Float64,
                          errors::Vector{PipelineBoundaryError}=PipelineBoundaryError[],
                          warnings::Vector{String}=String[],
                          recovery_actions::Vector{String}=String[],
                          metadata::Dict{String, Any}=Dict{String, Any}())
        new(success, boundary_name, validation_time, errors, warnings, recovery_actions, metadata)
    end
end

# Pipeline boundary definitions
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

# Predefined boundary validators
const HPC_JOB_BOUNDARY = "hpc_job_submission_to_collection"
const DATA_PROCESSING_BOUNDARY = "data_collection_to_processing"
const VISUALIZATION_BOUNDARY = "processing_to_visualization"
const FILE_OPERATION_BOUNDARY = "file_operations_to_data_loading"

"""
    validate_stage_transition(from_stage::String, to_stage::String, data::Any; context::Dict=Dict()) -> BoundaryResult

Validate transition between pipeline stages with comprehensive error detection.

# Arguments
- `from_stage::String`: Source pipeline stage
- `to_stage::String`: Target pipeline stage
- `data::Any`: Data being transitioned
- `context::Dict`: Additional context for validation

# Returns
BoundaryResult with detailed validation results and recovery actions.

# Examples
```julia
# HPC job to result collection
result = validate_stage_transition("hpc_execution", "result_collection",
                                 hpc_output_data, context=Dict("job_id" => "exp_123"))

# Data processing transition
result = validate_stage_transition("data_collection", "analysis_pipeline",
                                 collected_data, context=Dict("experiment_id" => "4d_lotka"))
```
"""
function validate_stage_transition(from_stage::String, to_stage::String, data::Any;
                                 context::Dict{String, Any}=Dict{String, Any}())
    start_time = time()
    errors = PipelineBoundaryError[]
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

"""
HPC job submission to result collection boundary validation
"""
function validate_hpc_to_collection_boundary(data::Any, context::Dict{String, Any})
    errors = PipelineBoundaryError[]
    warnings = String[]
    recovery_actions = String[]

    # Check if data represents HPC job results
    if isa(data, DataFrame)
        # Validate HPC result data structure
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
        # Validate file-based HPC results
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
            # Propagate CSV interface warnings as boundary errors
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

"""
Data collection to processing pipeline boundary validation
"""
function validate_collection_to_processing_boundary(data::Any, context::Dict{String, Any})
    errors = PipelineBoundaryError[]
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

"""
Processing to visualization boundary validation
"""
function validate_processing_to_visualization_boundary(data::Any, context::Dict{String, Any})
    errors = PipelineBoundaryError[]
    warnings = String[]
    recovery_actions = String[]

    if isa(data, DataFrame)
        # Check for visualization-required aggregations
        viz_columns = [:mean_l2_overall, :best_l2, :worst_l2]
        available_viz_cols = intersect(viz_columns, Symbol.(names(data)))

        if isempty(available_viz_cols)
            # Check if raw data needs transformation
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

"""
File system to data loading boundary validation
"""
function validate_filesystem_to_loading_boundary(data::Any, context::Dict{String, Any})
    errors = PipelineBoundaryError[]
    warnings = String[]
    recovery_actions = String[]

    if isa(data, String)
        # File existence and accessibility
        if !isfile(data)
            push!(errors, FileSystemBoundaryError(
                "file_access",
                data,
                "File not found or inaccessible",
                ["Verify file path", "Check file permissions", "Confirm file creation completed"]
            ))
            push!(recovery_actions, "IMMEDIATE: Verify file exists at path: $data")
        else
            # File integrity checks
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

            # CSV format validation for data files
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

"""
Generic stage transition validation for unknown stage combinations
"""
function validate_generic_stage_transition(from_stage::String, to_stage::String, data::Any, context::Dict{String, Any})
    errors = PipelineBoundaryError[]
    warnings = String[]
    recovery_actions = String[]

    # Basic data validation
    if data === nothing
        push!(errors, StageTransitionError(
            from_stage, to_stage,
            "null_data_validation",
            "Provide non-null data for stage transition",
            Dict("context" => context)
        ))
        push!(recovery_actions, "IMMEDIATE: Ensure previous stage outputs valid data")
    end

    # Add generic warning for unknown transitions
    push!(warnings, "Unknown stage transition - using generic validation")
    push!(recovery_actions, "ENHANCE: Implement specific validation for $(from_stage) → $(to_stage)")

    return (errors=errors, warnings=warnings, recovery_actions=recovery_actions)
end

"""
    detect_interface_issues(data::Any; context::Dict=Dict()) -> BoundaryResult

Detect common interface issues across data formats and pipeline connections.

# Examples
```julia
# Detect column naming issues
result = detect_interface_issues(df, context=Dict("source" => "hpc_results"))

# Check file format compatibility
result = detect_interface_issues("experiment.csv", context=Dict("target_pipeline" => "analysis"))
```
"""
function detect_interface_issues(data::Any; context::Dict{String, Any}=Dict{String, Any}())
    start_time = time()
    errors = PipelineBoundaryError[]
    warnings = String[]
    recovery_actions = String[]

    if isa(data, DataFrame)
        # Column naming interface issues
        column_names = names(data)

        # Critical interface issues that break computation
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
        # File-based interface validation
        result = defensive_csv_read(data, detect_interface_issues=true)

        # Convert CSV warnings to boundary errors/warnings
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
    create_boundary_report(result::BoundaryResult) -> String

Create comprehensive boundary validation report with pinpointed failure locations.
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

    if !isempty(result.metadata)
        push!(report, "\n📋 BOUNDARY METADATA:")
        for (key, value) in result.metadata
            if key != "timestamp"  # Already shown above
                push!(report, "   • $(key): $value")
            end
        end
    end

    return join(report, "\n")
end

"""
    validate_pipeline_connection(connection_points::Vector{Pair{String, Any}};
                                context::Dict=Dict()) -> Vector{BoundaryResult}

Validate multiple pipeline connection points in sequence.

# Arguments
- `connection_points`: Vector of stage_name => data pairs
- `context`: Additional validation context

# Examples
```julia
connections = [
    "hpc_execution" => hpc_results,
    "data_processing" => processed_data,
    "visualization" => viz_ready_data
]

results = validate_pipeline_connection(connections,
                                     context=Dict("experiment_id" => "4d_study"))
```
"""
function validate_pipeline_connection(connection_points::Vector{Pair{String, Any}};
                                    context::Dict{String, Any}=Dict{String, Any}())
    results = BoundaryResult[]

    for i in 1:(length(connection_points) - 1)
        from_stage, from_data = connection_points[i]
        to_stage, to_data = connection_points[i + 1]

        # Validate transition from current stage to next
        result = validate_stage_transition(from_stage, to_stage, from_data, context=context)
        push!(results, result)

        # If critical errors, stop validation chain
        if !result.success && any(e -> isa(e, StageTransitionError) || isa(e, InterfaceCompatibilityError), result.errors)
            break
        end
    end

    return results
end

end # module PipelineErrorBoundaries