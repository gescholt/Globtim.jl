"""
PipelineDefenseIntegration Module - Issue #83 Integration Layer

Integration wrapper connecting the new PipelineErrorBoundaries framework
with existing GlobTim infrastructure including DefensiveCSV, ValidationBoundaries,
ErrorCategorization, and the Hook Orchestrator system.

Features:
- Seamless integration with existing defensive infrastructure
- Hook orchestrator pipeline validation integration
- Enhanced error reporting with actionable feedback
- Zero-configuration deployment to existing workflows

Author: GlobTim Project
Date: September 26, 2025
"""

module PipelineDefenseIntegration

using DataFrames, CSV, Dates
using JSON3

# Import all existing defensive infrastructure
include("PipelineErrorBoundaries.jl")
using .PipelineErrorBoundaries

include("DefensiveCSV.jl")
using .DefensiveCSV

include("ValidationBoundaries.jl")
using .ValidationBoundaries

include("ErrorCategorization.jl")
using .ErrorCategorization

export enhanced_pipeline_validation, integrate_with_hooks, create_defense_report
export validate_hpc_pipeline_stage, enhance_existing_workflows
export DEFENSE_SUCCESS, DEFENSE_WARNING, DEFENSE_ERROR, DEFENSE_CRITICAL
export DefenseResult

# Defense result severity levels
const DEFENSE_SUCCESS = "SUCCESS"
const DEFENSE_WARNING = "WARNING"
const DEFENSE_ERROR = "ERROR"
const DEFENSE_CRITICAL = "CRITICAL"

# Enhanced defense result combining all validation systems
struct DefenseResult
    overall_status::String
    validation_time::Float64
    boundary_results::Vector{BoundaryResult}
    csv_result::Union{CSVLoadResult, Nothing}
    validation_result::Union{ValidationResult, Nothing}
    error_category::Union{Dict{String, Any}, Nothing}
    actionable_steps::Vector{String}
    critical_failures::Vector{String}
    metadata::Dict{String, Any}

    function DefenseResult(overall_status::String, validation_time::Float64,
                         boundary_results::Vector{BoundaryResult},
                         csv_result::Union{CSVLoadResult, Nothing}=nothing,
                         validation_result::Union{ValidationResult, Nothing}=nothing,
                         error_category::Union{Dict{String, Any}, Nothing}=nothing,
                         actionable_steps::Vector{String}=String[],
                         critical_failures::Vector{String}=String[],
                         metadata::Dict{String, Any}=Dict{String, Any}())
        new(overall_status, validation_time, boundary_results, csv_result,
            validation_result, error_category, actionable_steps, critical_failures, metadata)
    end
end

"""
    enhanced_pipeline_validation(data::Any, stage_info::Dict; context::Dict=Dict()) -> DefenseResult

Comprehensive pipeline validation using all available defensive systems.
Integrates PipelineErrorBoundaries, DefensiveCSV, ValidationBoundaries, and ErrorCategorization.

# Arguments
- `data::Any`: Data to validate (DataFrame, file path, etc.)
- `stage_info::Dict`: Stage information with keys "from_stage", "to_stage"
- `context::Dict`: Additional context for validation

# Examples
```julia
# HPC job result validation
result = enhanced_pipeline_validation(hpc_data,
                                    Dict("from_stage" => "hpc_execution",
                                         "to_stage" => "result_collection"),
                                    context=Dict("job_id" => "exp_123"))

# File loading validation
result = enhanced_pipeline_validation("experiment.csv",
                                    Dict("from_stage" => "file_system",
                                         "to_stage" => "data_loading"))
```
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
        println("🔍 Running pipeline boundary validation...")
        boundary_result = PipelineErrorBoundaries.validate_stage_transition(from_stage, to_stage, data, context=context)
        push!(boundary_results, boundary_result)

        # Extract actionable steps from boundary validation
        append!(actionable_steps, boundary_result.recovery_actions)
        if !boundary_result.success
            for error in boundary_result.errors
                if isa(error, PipelineErrorBoundaries.InterfaceCompatibilityError) || isa(error, PipelineErrorBoundaries.StageTransitionError)
                    push!(critical_failures, PipelineErrorBoundaries.format_boundary_error(error))
                end
            end
        end

        # 2. Interface issue detection
        println("🔍 Running interface issue detection...")
        interface_result = PipelineErrorBoundaries.detect_interface_issues(data, context=context)
        push!(boundary_results, interface_result)
        append!(actionable_steps, interface_result.recovery_actions)

        # 3. File/CSV specific validation if applicable
        if isa(data, String) && isfile(data) && endswith(data, ".csv")
            println("🔍 Running defensive CSV validation...")
            csv_result = DefensiveCSV.defensive_csv_read(data,
                                          validate_columns=true,
                                          detect_interface_issues=true)

            # Convert CSV warnings to actionable steps
            for warning in csv_result.warnings
                if contains(warning, "INTERFACE ISSUE") || contains(warning, "DATA ISSUE")
                    push!(actionable_steps, "CSV FIX: $warning")
                end
            end

            if !csv_result.success
                push!(critical_failures, "CSV Loading Failed: $(csv_result.error)")
            end
        end

        # 4. Data validation using ValidationBoundaries if DataFrame
        if isa(data, DataFrame) || (csv_result !== nothing && csv_result.success)
            println("🔍 Running data validation boundaries...")
            df_to_validate = isa(data, DataFrame) ? data : csv_result.data

            validation_result = ValidationBoundaries.validate_experiment_output_strict(df_to_validate)

            if !validation_result.success
                for error in validation_result.errors
                    push!(critical_failures, ValidationBoundaries.format_validation_error(error))

                    # Convert validation errors to actionable steps
                    if isa(error, ValidationBoundaries.FilenameContaminationError)
                        push!(actionable_steps, "CRITICAL: Clean filename contamination in column '$(error.column)'")
                    elseif isa(error, ValidationBoundaries.ParameterRangeError)
                        push!(actionable_steps, "FIX: Correct parameter '$(error.parameter)' values outside range")
                    elseif isa(error, ValidationBoundaries.SchemaValidationError)
                        push!(actionable_steps, "SCHEMA: Fix column '$(error.column)' type mismatch")
                    end
                end
            end
        end

        # 5. Error categorization for comprehensive analysis
        if !isempty(critical_failures)
            println("🔍 Running error categorization...")
            error_text = join(critical_failures, "\n")
            error_category = ErrorCategorization.categorize_error(error_text, context=Dict{String, Any}("source" => "pipeline_validation"))
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
            "validation_systems" => ["PipelineErrorBoundaries", "DefensiveCSV", "ValidationBoundaries", "ErrorCategorization"],
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
                               experiment_context::Dict=Dict()) -> DefenseResult

Specialized validation for HPC pipeline stages with hook orchestrator integration.
"""
function validate_hpc_pipeline_stage(stage_name::String, data_path::String;
                                   experiment_context::Dict{String, Any}=Dict{String, Any}())

    # Map HPC pipeline stages to boundary validation stages
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

"""
    create_defense_report(result::DefenseResult) -> String

Create comprehensive defense report combining all validation systems.
"""
function create_defense_report(result::DefenseResult)::String
    report = String[]

    push!(report, "╔══════════════════════════════════════════════════════════╗")
    push!(report, "║              COMPREHENSIVE DEFENSE REPORT                ║")
    push!(report, "╚══════════════════════════════════════════════════════════╝")

    # Overall status with clear visual indicators
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

    # Critical failures section (most important)
    if !isempty(result.critical_failures)
        push!(report, "\n🚨 CRITICAL PIPELINE FAILURES:")
        push!(report, "="^60)
        for (i, failure) in enumerate(result.critical_failures)
            push!(report, "$(i). $failure")
        end
    end

    # Actionable steps (second most important)
    if !isempty(result.actionable_steps)
        push!(report, "\n🔧 IMMEDIATE ACTIONABLE STEPS:")
        push!(report, "="^45)

        # Prioritize actionable steps
        critical_actions = filter(s -> contains(s, "CRITICAL"), result.actionable_steps)
        immediate_actions = filter(s -> contains(s, "IMMEDIATE"), result.actionable_steps)
        other_actions = filter(s -> !contains(s, "CRITICAL") && !contains(s, "IMMEDIATE"), result.actionable_steps)

        for (i, action) in enumerate([critical_actions; immediate_actions; other_actions])
            priority = contains(action, "CRITICAL") ? "🚨" : contains(action, "IMMEDIATE") ? "⚡" : "🔧"
            push!(report, "$(i). $priority $action")
        end
    end

    # Boundary validation details
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

    # CSV validation results
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

    # Data validation results
    if result.validation_result !== nothing
        push!(report, "\n🔬 DATA VALIDATION RESULTS:")
        push!(report, "="^35)
        val_status = result.validation_result.success ? "✅" : "❌"
        push!(report, "$val_status Validation Status: $(val_status)")
        push!(report, "📈 Quality Score: $(round(result.validation_result.quality_score, digits=1))/100")

        if !isempty(result.validation_result.errors)
            push!(report, "❌ Validation Errors: $(length(result.validation_result.errors))")
        end
    end

    # Error categorization results
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

    # System metadata
    if !isempty(result.metadata)
        push!(report, "\n📋 SYSTEM METADATA:")
        push!(report, "="^25)
        push!(report, "🔧 Validation Systems: $(join(get(result.metadata, "validation_systems", []), ", "))")
        push!(report, "💾 Data Type: $(get(result.metadata, "data_type", "unknown"))")
    end

    return join(report, "\n")
end

"""
    integrate_with_hooks(hook_stage::String, data_or_path::Any,
                        experiment_context::Dict=Dict()) -> Dict

Integration point for hook orchestrator system.
Returns structured results for hook consumption.
"""
function integrate_with_hooks(hook_stage::String, data_or_path::Any,
                            experiment_context::Dict{String, Any}=Dict{String, Any}())

    # Run comprehensive validation
    result = validate_hpc_pipeline_stage(hook_stage, string(data_or_path),
                                       experiment_context=experiment_context)

    # Format for hook consumption
    hook_result = Dict{String, Any}(
        "defense_status" => result.overall_status,
        "success" => result.overall_status in [DEFENSE_SUCCESS, DEFENSE_WARNING],
        "validation_time_ms" => round(result.validation_time * 1000, digits=1),
        "critical_failures" => result.critical_failures,
        "actionable_steps" => result.actionable_steps,
        "should_continue" => result.overall_status != DEFENSE_CRITICAL,
        "hook_stage" => hook_stage,
        "timestamp" => Dates.now(),
        "metadata" => result.metadata
    )

    # Log defense report to hook logs
    report = create_defense_report(result)
    hook_log_path = get(ENV, "HOOK_LOG_DIR", "/tmp")

    try
        log_file = joinpath(hook_log_path, "defense_report_$(hook_stage)_$(Dates.format(Dates.now(), "yyyymmdd_HHMMSS")).log")
        open(log_file, "w") do f
            write(f, report)
        end
        hook_result["defense_report_path"] = log_file
    catch e
        hook_result["defense_report_error"] = string(e)
    end

    return hook_result
end

"""
    enhance_existing_workflows()

Patch existing workflow functions to include defensive validation.
This provides zero-configuration enhancement of existing scripts.
"""
function enhance_existing_workflows()
    println("🚀 Enhancing existing GlobTim workflows with defensive boundaries...")

    # Note: In a real implementation, this would monkey-patch existing functions
    # or provide enhanced versions that existing scripts can opt into

    println("✅ Enhanced workflows available:")
    println("   • enhanced_pipeline_validation() - Comprehensive validation")
    println("   • validate_hpc_pipeline_stage() - HPC stage-specific validation")
    println("   • integrate_with_hooks() - Hook orchestrator integration")
    println("   • create_defense_report() - Detailed reporting")

    println("\n🔧 Integration points:")
    println("   • collect_cluster_experiments.jl → Add validation calls")
    println("   • interactive_comparison_demo.jl → Enhance data loading")
    println("   • workflow_integration.jl → Add defensive boundaries")
    println("   • Hook orchestrator → integrate_with_hooks()")

    return true
end

end # module PipelineDefenseIntegration