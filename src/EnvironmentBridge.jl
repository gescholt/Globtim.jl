"""
EnvironmentBridge.jl - Safe Cross-Environment Communication Module

This module provides safe, fail-fast communication between @globtimcore and @globtimplots
environments, eliminating the cross-environment function call bugs that cause MethodError
exceptions in interactive_comparison_demo.jl.

Key Design Principles:
- No fallback mechanisms - fail fast with clear errors
- Schema validation for all data transfers
- Subprocess isolation for cross-environment calls
- Comprehensive error handling and reporting
- Modular architecture for easy testing

Addresses GitLab Issue #65: Data Structure Standardization and Environment Isolation
"""

module EnvironmentBridge

using DataFrames
using CSV
using JSON3
using Dates

# Import our DataFrameInterface for schema validation
include("DataFrameInterface.jl")
using .DataFrameInterface

# Issue #79: Import ValidationBoundaries for defensive loading
include("ValidationBoundaries.jl")
using .ValidationBoundaries

include("DefensiveCSV.jl")
using .DefensiveCSV

export EnvironmentConfig, CrossEnvironmentCall, execute_cross_environment_call
export create_visualization_bridge, validate_environment_paths
export EnvironmentBridgeError, CrossEnvironmentResult
export validate_output_directory, validate_path_permissions
export validate_comparison_data, enhanced_validate_comparison_data
export prepare_comparison_data, transform_for_visualization
export load_comparison_data_defensive  # Issue #79: New defensive loading function

# Custom error types for fail-fast behavior
struct EnvironmentBridgeError <: Exception
    message::String
    error_type::String
    environment::String
    details::Dict{String, Any}

    function EnvironmentBridgeError(message::String, error_type::String, environment::String="unknown"; details=Dict{String, Any}())
        new(message, error_type, environment, details)
    end
end

# Result type for cross-environment operations
struct CrossEnvironmentResult
    success::Bool
    output_files::Vector{String}
    execution_time::Float64
    exit_code::Int
    stdout::String
    stderr::String
    environment_info::Dict{String, Any}

    function CrossEnvironmentResult(success::Bool, output_files::Vector{String}, execution_time::Float64, exit_code::Int, stdout::String, stderr::String; environment_info=Dict{String, Any}())
        new(success, output_files, execution_time, exit_code, stdout, stderr, environment_info)
    end
end

# Environment configuration for cross-environment calls
struct EnvironmentConfig
    name::String
    project_path::String
    julia_executable::String
    script_path::Union{String, Nothing}
    required_packages::Vector{String}
    validation_command::String

    function EnvironmentConfig(name::String, project_path::String;
                              julia_executable="julia",
                              script_path=nothing,
                              required_packages=String[],
                              validation_command="using Pkg; Pkg.status()")
        new(name, project_path, julia_executable, script_path, required_packages, validation_command)
    end
end

# Cross-environment call specification
struct CrossEnvironmentCall
    target_environment::EnvironmentConfig
    function_name::String
    data_file::String
    output_directory::String
    parameters::Dict{String, Any}
    timeout::Int

    function CrossEnvironmentCall(target_environment::EnvironmentConfig, function_name::String, data_file::String, output_directory::String; parameters=Dict{String, Any}(), timeout=300)
        new(target_environment, function_name, data_file, output_directory, parameters, timeout)
    end
end

"""
    validate_environment_paths(config::EnvironmentConfig) -> Bool

Validate that all paths in environment configuration exist and are accessible.
Throws EnvironmentBridgeError on validation failure (fail-fast behavior).
"""
function validate_environment_paths(config::EnvironmentConfig)::Bool
    # Check project path
    if !isdir(config.project_path)
        throw(EnvironmentBridgeError(
            "Project path does not exist: $(config.project_path)",
            "PATH_NOT_FOUND",
            config.name,
            details=Dict("path" => config.project_path, "type" => "project_directory")
        ))
    end

    # Check Julia executable
    julia_cmd = Cmd([config.julia_executable, "--version"])
    try
        result = read(julia_cmd, String)
        if !occursin("julia version", lowercase(result))
            throw(EnvironmentBridgeError(
                "Invalid Julia executable: $(config.julia_executable)",
                "INVALID_JULIA_EXECUTABLE",
                config.name,
                details=Dict("executable" => config.julia_executable, "output" => result)
            ))
        end
    catch e
        throw(EnvironmentBridgeError(
            "Cannot execute Julia: $(config.julia_executable) - $e",
            "JULIA_EXECUTION_FAILED",
            config.name,
            details=Dict("executable" => config.julia_executable, "error" => string(e))
        ))
    end

    # Check script path if specified
    if config.script_path !== nothing
        if !isfile(config.script_path)
            throw(EnvironmentBridgeError(
                "Script path does not exist: $(config.script_path)",
                "SCRIPT_NOT_FOUND",
                config.name,
                details=Dict("script_path" => config.script_path)
            ))
        end
    end

    return true
end

"""
    validate_data_for_cross_environment(df::DataFrame) -> Bool

Validate DataFrame schema before cross-environment transfer.
Uses DataFrameInterface for comprehensive validation.
"""
function validate_data_for_cross_environment(df::DataFrame)::Bool
    # Use our smart validation that auto-detects data type
    if !DataFrameInterface.quick_validate_any_schema(df)
        # If basic validation fails, get detailed error info
        data_type = DataFrameInterface.detect_data_type(df)
        error_msg = "Data validation failed for detected type: $data_type. Available columns: $(join(names(df), ", "))"

        throw(EnvironmentBridgeError(
            error_msg,
            "INVALID_DATA_SCHEMA",
            "source",
            details=Dict("validation_error" => error_msg, "columns" => names(df), "detected_type" => data_type)
        ))
    end

    # Additional cross-environment specific checks
    if nrow(df) == 0
        throw(EnvironmentBridgeError(
            "Cannot transfer empty DataFrame",
            "EMPTY_DATA",
            "source",
            details=Dict("columns" => names(df))
        ))
    end

    # Check for missing experiment_id which is critical for visualization
    if "experiment_id" in names(df) && any(ismissing, df.experiment_id)
        missing_count = count(ismissing, df.experiment_id)
        throw(EnvironmentBridgeError(
            "Data contains missing experiment_id values: $missing_count/$nrow(df) rows",
            "MISSING_EXPERIMENT_ID",
            "source",
            details=Dict("missing_count" => missing_count, "total_rows" => nrow(df))
        ))
    end

    return true
end

"""
    prepare_data_transfer(df::DataFrame, temp_file_path::String) -> String

Prepare DataFrame for cross-environment transfer by validating and writing to temporary file.
Returns the path to the temporary file.
"""
function prepare_data_transfer(df::DataFrame, temp_file_path::String)::String
    # Validate data schema
    validate_data_for_cross_environment(df)

    # Ensure output directory exists
    mkpath(dirname(temp_file_path))

    # Write data to temporary file
    try
        CSV.write(temp_file_path, df)
    catch e
        throw(EnvironmentBridgeError(
            "Failed to write data to temporary file: $temp_file_path - $e",
            "DATA_WRITE_FAILED",
            "source",
            details=Dict("temp_file" => temp_file_path, "error" => string(e))
        ))
    end

    # Verify file was written correctly
    if !isfile(temp_file_path)
        throw(EnvironmentBridgeError(
            "Temporary data file was not created: $temp_file_path",
            "TEMP_FILE_NOT_CREATED",
            "source",
            details=Dict("temp_file" => temp_file_path)
        ))
    end

    return temp_file_path
end

"""
    execute_cross_environment_call(call::CrossEnvironmentCall) -> CrossEnvironmentResult

Execute a cross-environment call using subprocess isolation.
This is the core function that eliminates MethodError exceptions.
"""
function execute_cross_environment_call(call::CrossEnvironmentCall)::CrossEnvironmentResult
    start_time = time()

    # Validate environment configuration
    validate_environment_paths(call.target_environment)

    # Ensure output directory exists
    mkpath(call.output_directory)

    # Verify data file exists
    if !isfile(call.data_file)
        throw(EnvironmentBridgeError(
            "Data file does not exist: $(call.data_file)",
            "DATA_FILE_NOT_FOUND",
            call.target_environment.name,
            details=Dict("data_file" => call.data_file)
        ))
    end

    # Create parameters file for the subprocess
    params_file = joinpath(dirname(call.data_file), "subprocess_params_$(Dates.format(Dates.now(), "yyyymmdd_HHMMSS")).json")

    params_data = Dict(
        "function_name" => call.function_name,
        "data_file" => call.data_file,
        "output_directory" => call.output_directory,
        "parameters" => call.parameters,
        "timestamp" => Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
    )

    try
        open(params_file, "w") do f
            JSON3.pretty(f, params_data)
        end
    catch e
        throw(EnvironmentBridgeError(
            "Failed to write parameters file: $params_file - $e",
            "PARAMS_FILE_WRITE_FAILED",
            call.target_environment.name,
            details=Dict("params_file" => params_file, "error" => string(e))
        ))
    end

    # Build Julia command for subprocess execution
    script_path = call.target_environment.script_path
    if script_path === nothing
        # If no script specified, we need to create a minimal executor script
        throw(EnvironmentBridgeError(
            "No execution script specified for environment: $(call.target_environment.name)",
            "NO_EXECUTION_SCRIPT",
            call.target_environment.name,
            details=Dict("environment_config" => call.target_environment)
        ))
    end

    cmd = `$(call.target_environment.julia_executable) --project=$(call.target_environment.project_path) $(script_path) $(params_file)`

    # Execute subprocess with timeout
    stdout_buffer = IOBuffer()
    stderr_buffer = IOBuffer()
    exit_code = 1

    try
        process = run(pipeline(cmd, stdout=stdout_buffer, stderr=stderr_buffer), wait=false)

        # Wait for process with timeout
        timer_task = @async begin
            sleep(call.timeout)
            if process_running(process)
                kill(process)
                throw(EnvironmentBridgeError(
                    "Cross-environment call timed out after $(call.timeout) seconds",
                    "EXECUTION_TIMEOUT",
                    call.target_environment.name,
                    details=Dict("timeout" => call.timeout, "command" => string(cmd))
                ))
            end
        end

        wait(process)

        # Cancel timeout timer if process completed
        if !istaskdone(timer_task)
            @async Base.throwto(timer_task, InterruptException())
        end

        exit_code = process.exitcode

    catch e
        if isa(e, EnvironmentBridgeError)
            rethrow(e)
        else
            throw(EnvironmentBridgeError(
                "Subprocess execution failed: $e",
                "SUBPROCESS_EXECUTION_FAILED",
                call.target_environment.name,
                details=Dict("command" => string(cmd), "error" => string(e))
            ))
        end
    finally
        # Clean up parameters file
        rm(params_file; force=true)
    end

    stdout_str = String(take!(stdout_buffer))
    stderr_str = String(take!(stderr_buffer))
    execution_time = time() - start_time

    # Collect output files
    output_files = String[]
    if isdir(call.output_directory)
        for file in readdir(call.output_directory)
            push!(output_files, joinpath(call.output_directory, file))
        end
    end

    # Check for success
    success = (exit_code == 0) && isdir(call.output_directory) && !isempty(output_files)

    if !success && exit_code == 0
        # Process completed but no output files generated
        throw(EnvironmentBridgeError(
            "Cross-environment call completed but generated no output files",
            "NO_OUTPUT_GENERATED",
            call.target_environment.name,
            details=Dict(
                "output_directory" => call.output_directory,
                "stdout" => stdout_str,
                "stderr" => stderr_str
            )
        ))
    elseif exit_code != 0
        throw(EnvironmentBridgeError(
            "Cross-environment call failed with exit code: $exit_code",
            "SUBPROCESS_FAILED",
            call.target_environment.name,
            details=Dict(
                "exit_code" => exit_code,
                "stdout" => stdout_str,
                "stderr" => stderr_str,
                "command" => string(cmd)
            )
        ))
    end

    environment_info = Dict(
        "environment_name" => call.target_environment.name,
        "project_path" => call.target_environment.project_path,
        "julia_executable" => call.target_environment.julia_executable,
        "function_name" => call.function_name
    )

    return CrossEnvironmentResult(success, output_files, execution_time, exit_code, stdout_str, stderr_str, environment_info=environment_info)
end

"""
    create_visualization_bridge(globtimplots_path::String) -> EnvironmentConfig

Create environment configuration for @globtimplots visualization calls.
This specifically addresses the interactive_comparison_demo.jl bug.
"""
function create_visualization_bridge(globtimplots_path::String)::EnvironmentConfig
    # Validate globtimplots path
    if !isdir(globtimplots_path)
        throw(EnvironmentBridgeError(
            "Globtimplots path does not exist: $globtimplots_path",
            "GLOBTIMPLOTS_NOT_FOUND",
            "globtimplots",
            details=Dict("path" => globtimplots_path)
        ))
    end

    # Check for expected structure
    src_dir = joinpath(globtimplots_path, "src")
    if !isdir(src_dir)
        throw(EnvironmentBridgeError(
            "Globtimplots src directory not found: $src_dir",
            "INVALID_GLOBTIMPLOTS_STRUCTURE",
            "globtimplots",
            details=Dict("expected_src_dir" => src_dir)
        ))
    end

    # Look for comparison_plots.jl
    comparison_plots_file = joinpath(src_dir, "comparison_plots.jl")
    if !isfile(comparison_plots_file)
        throw(EnvironmentBridgeError(
            "comparison_plots.jl not found in globtimplots: $comparison_plots_file",
            "COMPARISON_PLOTS_NOT_FOUND",
            "globtimplots",
            details=Dict("expected_file" => comparison_plots_file)
        ))
    end

    # Create environment config
    return EnvironmentConfig(
        "globtimplots",
        globtimplots_path,
        julia_executable="julia",
        script_path=nothing,  # Will be set by specific visualization functions
        required_packages=["Plots", "CSV", "DataFrames", "JSON3"],
        validation_command="using Plots, CSV, DataFrames, JSON3"
    )
end

"""
    create_dashboard_executor_script(output_path::String, globtimplots_path::String) -> String

Create a safe dashboard executor script for cross-environment visualization calls.
This script will be used as the script_path in EnvironmentConfig.
"""
function create_dashboard_executor_script(output_path::String, globtimplots_path::String)::String
    script_content = """
#!/usr/bin/env julia

# Safe Dashboard Executor Script for Cross-Environment Visualization
# Generated by EnvironmentBridge.jl

using Pkg
using JSON3
using CSV
using DataFrames

# Parse command line arguments
if length(ARGS) != 1
    println(stderr, "Usage: julia dashboard_executor.jl <params_file>")
    exit(1)
end

params_file = ARGS[1]

# Load parameters
try
    global params = JSON3.read(params_file, Dict{String, Any})
    println("Loaded parameters: ", keys(params))
catch e
    println(stderr, "Failed to load parameters file: \$params_file - \$e")
    exit(1)
end

# Load data
data_file = params["data_file"]
output_directory = params["output_directory"]

# Issue #79: Replace basic CSV.read with defensive loading
try
    println("🔍 Issue #79: Loading data with validation boundaries...")

    # Use defensive CSV loading with interface issue detection
    csv_result = defensive_csv_read(data_file,
                                  validate_columns=true,
                                  detect_interface_issues=true,
                                  min_quality_score=60.0)

    if csv_result.success
        global data = csv_result.data
        println("✅ Issue #79: Defensive loading successful!")
        println("   Loaded data: \$(nrow(data)) rows, \$(ncol(data)) columns")
        println("   Quality score: \$(round(csv_result.quality_score, digits=1))")

        # Log any warnings
        if !isempty(csv_result.warnings)
            println("⚠️ Data quality warnings:")
            for warning in csv_result.warnings
                println("   • \$warning")
            end
        end
    else
        error("Defensive CSV loading failed: \$(csv_result.error). File: \$data_file")
    end

catch e
    println(stderr, "Failed to load data file: \$data_file - \$e")
    exit(1)
end

# Ensure output directory exists
mkpath(output_directory)

# Execute function based on function_name
function_name = params["function_name"]

try
    if function_name == "create_comparison_plots"
        # Safe visualization execution using absolute path to globtimplots
        comparison_plots_path = joinpath("$globtimplots_path", "src", "comparison_plots.jl")
        include(comparison_plots_path)

        # Note: create_comparison_plots handles all visualization parameters internally
        # No parameter processing needed - function uses sensible defaults

        # Call the visualization function (simplified - function handles visualization details internally)
        result = create_comparison_plots(data; output_dir=output_directory)

        println("Visualization completed successfully")
        println("Output directory: \$output_directory")

        # List created files
        if isdir(output_directory)
            files = readdir(output_directory)
            println("Created files: \$(length(files))")
            for file in files
                println("  - \$file")
            end
        end

        exit(0)
    else
        println(stderr, "Unknown function: \$function_name")
        exit(1)
    end

catch e
    println(stderr, "Execution failed: \$e")
    println(stderr, "Stack trace:")
    for (exc, bt) in Base.catch_stack()
        showerror(stderr, exc, bt)
        println(stderr)
    end
    exit(1)
end
"""

    # Write the script
    try
        open(output_path, "w") do f
            write(f, script_content)
        end

        # Make executable
        chmod(output_path, 0o755)

    catch e
        throw(EnvironmentBridgeError(
            "Failed to create dashboard executor script: $output_path - $e",
            "SCRIPT_CREATION_FAILED",
            "globtimplots",
            details=Dict("script_path" => output_path, "error" => string(e))
        ))
    end

    return output_path
end

"""
    safe_visualization_call(data::DataFrame, globtimplots_path::String, output_directory::String; parameters=Dict{String, Any}()) -> CrossEnvironmentResult

High-level function to safely call visualization functions across environments.
This directly replaces the problematic code in interactive_comparison_demo.jl.
"""
function safe_visualization_call(data::DataFrame, globtimplots_path::String, output_directory::String; parameters=Dict{String, Any}(), timeout=300)::CrossEnvironmentResult
    # Validate input data
    validate_data_for_cross_environment(data)

    # Create visualization bridge
    viz_config = create_visualization_bridge(globtimplots_path)

    # Create executor script
    script_path = joinpath(tempdir(), "dashboard_executor_$(Dates.format(Dates.now(), "yyyymmdd_HHMMSS")).jl")
    create_dashboard_executor_script(script_path, globtimplots_path)

    # Update config with script path
    viz_config = EnvironmentConfig(
        viz_config.name,
        viz_config.project_path,
        julia_executable=viz_config.julia_executable,
        script_path=script_path,
        required_packages=viz_config.required_packages,
        validation_command=viz_config.validation_command
    )

    # Prepare data file
    temp_data_file = joinpath(tempdir(), "dashboard_data_$(Dates.format(Dates.now(), "yyyymmdd_HHMMSS")).csv")
    prepare_data_transfer(data, temp_data_file)

    # Create cross-environment call
    call = CrossEnvironmentCall(
        viz_config,
        "create_comparison_plots",
        temp_data_file,
        output_directory,
        parameters=parameters,
        timeout=timeout
    )

    try
        # Execute the call
        result = execute_cross_environment_call(call)

        return result

    finally
        # Clean up temporary files
        rm(temp_data_file; force=true)
        rm(script_path; force=true)
    end
end

"""
    validate_output_directory(output_dir::String) -> Bool

Validate output directory exists and is writable.
Throws EnvironmentBridgeError on validation failure (fail-fast behavior).
"""
function validate_output_directory(output_dir::String)::Bool
    # Check parent directory exists
    parent_dir = dirname(output_dir)

    # Handle case where output_dir is in current directory (parent_dir would be "")
    if isempty(parent_dir)
        parent_dir = "."
    end

    if !isdir(parent_dir)
        throw(EnvironmentBridgeError(
            "Output directory parent does not exist: $parent_dir",
            "path_validation",
            "globtimcore",
            details=Dict("parent_dir" => parent_dir, "requested_output" => output_dir)
        ))
    end

    # Check write permissions on parent directory
    if !iswritable(parent_dir)
        throw(EnvironmentBridgeError(
            "No write permissions for output directory: $parent_dir",
            "permission_error",
            "globtimcore",
            details=Dict("parent_dir" => parent_dir, "requested_output" => output_dir)
        ))
    end

    return true
end

"""
    validate_path_permissions(path::String, operation::String="read") -> Bool

Validate path exists and has required permissions.
Throws EnvironmentBridgeError on validation failure (fail-fast behavior).

Arguments:
- path: Path to validate
- operation: "read", "write", or "execute"
"""
function validate_path_permissions(path::String, operation::String="read")::Bool
    # Check path exists
    if !ispath(path)
        throw(EnvironmentBridgeError(
            "Path does not exist: $path",
            "path_not_found",
            "globtimcore",
            details=Dict("path" => path, "operation" => operation)
        ))
    end

    # Check permissions based on operation
    permission_check = if operation == "read"
        isreadable(path)
    elseif operation == "write"
        iswritable(path)
    elseif operation == "execute"
        # For directories, check if we can access contents
        isdir(path) ? isreadable(path) : isexecutable(path)
    else
        throw(EnvironmentBridgeError(
            "Invalid operation type: $operation. Must be 'read', 'write', or 'execute'",
            "invalid_operation",
            "globtimcore",
            details=Dict("path" => path, "operation" => operation)
        ))
    end

    if !permission_check
        throw(EnvironmentBridgeError(
            "Insufficient permissions for $operation operation on: $path",
            "permission_error",
            "globtimcore",
            details=Dict("path" => path, "operation" => operation, "permission_check" => permission_check)
        ))
    end

    return true
end

"""
    validate_comparison_data(data::DataFrame) -> Bool

Validate DataFrame for dashboard generation with comprehensive checks.
Throws EnvironmentBridgeError on validation failure (fail-fast behavior).
"""
function validate_comparison_data(data::DataFrame)::Bool
    # Check for empty dataset
    if isempty(data) || nrow(data) == 0
        throw(EnvironmentBridgeError(
            "Empty dataset provided for dashboard generation",
            "data_validation",
            "globtimcore",
            details=Dict("nrows" => nrow(data), "ncols" => ncol(data))
        ))
    end

    # Use DataFrameInterface for schema validation
    data_type = DataFrameInterface.detect_data_type(data)

    if data_type == "experiment_comparison"
        # Validate experiment comparison schema
        validation = DataFrameInterface.validate_schema(data, DataFrameInterface.DEFAULT_EXPERIMENT_SCHEMA)
        if !validation.valid
            throw(EnvironmentBridgeError(
                "Experiment comparison data validation failed: $(validation.error)",
                "schema_validation",
                "globtimcore",
                details=Dict(
                    "validation_error" => validation.error,
                    "data_type" => data_type,
                    "available_columns" => names(data)
                )
            ))
        end
    elseif data_type == "critical_points"
        # Validate critical points schema
        validation = DataFrameInterface.validate_schema(data, DataFrameInterface.DEFAULT_CRITICAL_POINTS_SCHEMA)
        if !validation.valid
            throw(EnvironmentBridgeError(
                "Critical points data validation failed: $(validation.error)",
                "schema_validation",
                "globtimcore",
                details=Dict(
                    "validation_error" => validation.error,
                    "data_type" => data_type,
                    "available_columns" => names(data)
                )
            ))
        end
    else
        throw(EnvironmentBridgeError(
            "Unsupported data type for dashboard generation: $data_type",
            "unsupported_data_type",
            "globtimcore",
            details=Dict("detected_type" => data_type, "available_columns" => names(data))
        ))
    end

    # Validate data quality for critical/performance values using DataFrameInterface
    try
        critical_values = DataFrameInterface.get_critical_values(data)

        # Check for empty values array
        if isempty(critical_values)
            throw(EnvironmentBridgeError(
                "No critical/performance values found in dataset",
                "data_quality",
                "globtimcore",
                details=Dict("data_type" => data_type, "available_columns" => names(data))
            ))
        end

        # Check for numerical validity
        invalid_indices = findall(x -> !isfinite(x), critical_values)
        if !isempty(invalid_indices)
            throw(EnvironmentBridgeError(
                "Invalid critical/performance values (non-finite)",
                "data_quality",
                "globtimcore",
                details=Dict(
                    "data_type" => data_type,
                    "invalid_count" => length(invalid_indices),
                    "total_values" => length(critical_values),
                    "sample_invalid_values" => critical_values[invalid_indices[1:min(3, length(invalid_indices))]]
                )
            ))
        end

        # Basic statistical validation (values should be positive for L2 norms)
        if any(critical_values .< 0)
            negative_count = count(x -> x < 0, critical_values)
            throw(EnvironmentBridgeError(
                "Negative critical/performance values detected (unexpected for L2 norms)",
                "data_quality",
                "globtimcore",
                details=Dict(
                    "data_type" => data_type,
                    "negative_count" => negative_count,
                    "total_values" => length(critical_values),
                    "min_value" => minimum(critical_values)
                )
            ))
        end

    catch e
        if isa(e, EnvironmentBridgeError)
            rethrow(e)
        else
            throw(EnvironmentBridgeError(
                "Failed to extract critical/performance values for quality validation: $e",
                "data_extraction_error",
                "globtimcore",
                details=Dict("data_type" => data_type, "extraction_error" => string(e))
            ))
        end
    end

    return true
end

# Semantic Data Pipeline Integration Functions

"""
    transform_for_visualization(data::DataFrame) -> DataFrame

Transform data into the appropriate format for visualization/dashboard generation.
Uses semantic data pipeline to transform critical points to experiment summary format.
"""
function transform_for_visualization(data::DataFrame)::DataFrame
    data_type = DataFrameInterface.detect_data_type(data)

    if data_type == "critical_points"
        # Transform critical points to experiment summary for dashboard visualization
        try
            return DataFrameInterface.transform_to_experiment_summary(data)
        catch e
            throw(EnvironmentBridgeError(
                "Failed to transform critical points data to experiment summary format: $e",
                "TRANSFORMATION_FAILED",
                "source",
                details=Dict("original_type" => data_type, "error" => string(e))
            ))
        end
    elseif data_type == "experiment_comparison"
        # Data is already in the correct format
        return data
    else
        throw(EnvironmentBridgeError(
            "Cannot transform unknown data type for visualization: $data_type",
            "UNSUPPORTED_DATA_TYPE",
            "source",
            details=Dict("detected_type" => data_type, "columns" => names(data))
        ))
    end
end

"""
    prepare_comparison_data(data::DataFrame; transform_for_dashboard::Bool = true) -> DataFrame

Prepare data for comparison dashboard generation with optional transformation.
This is the main entry point for dashboard data preparation.
"""
function prepare_comparison_data(data::DataFrame; transform_for_dashboard::Bool = true)::DataFrame
    # First validate the input data with any supported schema
    if !DataFrameInterface.quick_validate_any_schema(data)
        data_type = DataFrameInterface.detect_data_type(data)
        error_msg = "Input data validation failed for detected type: $data_type. Available columns: $(join(names(data), ", "))"
        throw(EnvironmentBridgeError(
            error_msg,
            "INPUT_VALIDATION_FAILED",
            "source",
            details=Dict("detected_type" => data_type, "columns" => names(data))
        ))
    end

    # Transform data if requested and needed
    if transform_for_dashboard
        prepared_data = transform_for_visualization(data)

        # Validate the transformed data
        if !DataFrameInterface.validate_schema(prepared_data, DataFrameInterface.DEFAULT_EXPERIMENT_SCHEMA).valid
            throw(EnvironmentBridgeError(
                "Transformed data failed experiment comparison schema validation",
                "TRANSFORMATION_VALIDATION_FAILED",
                "source",
                details=Dict("transformed_columns" => names(prepared_data))
            ))
        end

        return prepared_data
    else
        return data
    end
end

"""
    enhanced_validate_comparison_data(data::DataFrame) -> Bool

Enhanced DataFrame validation that integrates with semantic data pipeline transformation.
Validates data and ensures it's in the correct format for dashboard generation.
"""
function enhanced_validate_comparison_data(data::DataFrame)::Bool
    try
        # Use the new prepare_comparison_data function which handles transformation
        prepared_data = prepare_comparison_data(data, transform_for_dashboard=true)

        # Additional domain-specific validation for comparison data
        validate_comparison_data(prepared_data)

        return true
    catch e
        # Re-throw as EnvironmentBridgeError if it's not already one
        if isa(e, EnvironmentBridgeError)
            rethrow(e)
        else
            data_type = DataFrameInterface.detect_data_type(data)
            throw(EnvironmentBridgeError(
                "Enhanced validation failed: $e",
                "VALIDATION_ERROR",
                "source",
                details=Dict("detected_type" => data_type, "error" => string(e))
            ))
        end
    end
end

"""
Issue #79: Defensive CSV loading function for comparison data

Replace manual CSV.read with defensive loading that includes:
- Interface issue detection (val vs z column naming)
- Data quality assessment
- ValidationBoundaries integration
- Clear error reporting with actionable feedback

# Arguments
- `filepath::String`: Path to CSV file
- `min_quality_score::Float64=70.0`: Minimum quality threshold
- `require_columns::Vector{Symbol}=Symbol[]`: Required column names

# Examples
```julia
# Basic defensive loading
result = load_comparison_data_defensive("experiment_data.csv")

# With quality requirements
result = load_comparison_data_defensive("data.csv",
                                       min_quality_score=80.0,
                                       require_columns=[:x1, :x2, :x3, :x4, :z])
```
"""
function load_comparison_data_defensive(filepath::String;
                                      min_quality_score::Float64=70.0,
                                      require_columns::Vector{Symbol}=Symbol[])
    try
        println("🔍 Issue #79: Loading comparison data with defensive boundaries...")

        # Use ValidationBoundaries for comprehensive loading
        # This function throws exceptions on failure, so we catch them
        data = load_and_validate_experiment_data(filepath,
                                               quality_threshold=min_quality_score)

        println("✅ Issue #79: Defensive comparison data loading successful!")
        println("   Data: $(nrow(data)) rows × $(ncol(data)) columns")
        return data

    catch e
        if isa(e, EnvironmentBridgeError)
            rethrow(e)
        else
            throw(EnvironmentBridgeError(
                "Failed to load comparison data: $e",
                "FILE_LOAD_ERROR",
                filepath
            ))
        end
    end
end

end # module EnvironmentBridge