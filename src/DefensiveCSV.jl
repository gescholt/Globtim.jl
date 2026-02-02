"""
DefensiveCSV Module - Issue #79 Implementation

Provides defensive CSV loading functionality with comprehensive error boundaries
for production HPC deployment and dashboard integration.

Author: GlobTim Project
Date: September 26, 2025
"""

module DefensiveCSV

using CSV
using DataFrames
using Dates

export defensive_csv_read, CSVLoadResult

"""
Result structure for defensive CSV loading
"""
struct CSVLoadResult
    success::Bool
    data::Union{DataFrame, Nothing}
    warnings::Vector{String}
    error::Union{String, Nothing}
    file::String
    load_time::Float64
end

"""
    defensive_csv_read(file_path::String; kwargs...) -> CSVLoadResult

Defensive CSV loading with comprehensive error boundaries and interface issue detection.

# Arguments
- `file_path::String`: Path to CSV file
- `validate_columns::Bool = true`: Whether to validate column structure
- `required_columns::Vector{String} = String[]`: Required columns that must be present
- `detect_interface_issues::Bool = true`: Whether to detect common interface issues
- `max_file_size::Int = 1024*1024*1024`: Maximum file size in bytes (1GB default)
- `csv_options...`: Additional options passed to CSV.read

# Returns
`CSVLoadResult` with success status, data, warnings, and error information.

# Examples
```julia
# Basic loading
result = defensive_csv_read("experiment.csv")
if result.success
    df = result.data
    if !isempty(result.warnings)
        @warn "CSV loaded with warnings: \$(join(result.warnings, "; "))"
    end
else
    @error "Failed to load CSV: \$(result.error)"
end

# With column validation
result = defensive_csv_read("experiment.csv",
                          required_columns=["experiment_id", "degree", "z"])

# With interface issue detection
result = defensive_csv_read("experiment.csv",
                          detect_interface_issues=true)
```
"""
function defensive_csv_read(file_path::String;
                          validate_columns::Bool = true,
                          required_columns::Vector{String} = String[],
                          detect_interface_issues::Bool = true,
                          max_file_size::Int = 1024*1024*1024,  # 1GB
                          csv_options...)

    start_time = time()
    warnings = String[]

    try
        # 1. Pre-validation checks
        if !isfile(file_path)
            return CSVLoadResult(false, nothing, warnings,
                               "File not found: $file_path",
                               basename(file_path), time() - start_time)
        end

        file_size = stat(file_path).size
        if file_size == 0
            return CSVLoadResult(false, nothing, warnings,
                               "File is empty: $file_path",
                               basename(file_path), time() - start_time)
        end

        if file_size > max_file_size
            return CSVLoadResult(false, nothing, warnings,
                               "File too large ($(file_size) bytes > $(max_file_size) bytes): $file_path",
                               basename(file_path), time() - start_time)
        end

        # 2. CSV parsing with error boundary
        df = try
            CSV.read(file_path, DataFrame; csv_options...)
        catch e
            if isa(e, CSV.Error) || isa(e, ArgumentError)
                return CSVLoadResult(false, nothing, warnings,
                                   "CSV parsing failed: $e",
                                   basename(file_path), time() - start_time)
            else
                rethrow(e)
            end
        end

        # 3. Post-load validation
        if nrow(df) == 0
            return CSVLoadResult(false, nothing, warnings,
                               "CSV file contains no data rows",
                               basename(file_path), time() - start_time)
        end

        # 4. Column validation
        if validate_columns && !isempty(required_columns)
            missing_cols = setdiff(required_columns, names(df))
            if !isempty(missing_cols)
                return CSVLoadResult(false, nothing, warnings,
                                   "Missing required columns: $(join(missing_cols, ", "))",
                                   basename(file_path), time() - start_time)
            end
        end

        # 5. Interface issue detection (Issue #79 specific)
        if detect_interface_issues
            # Check for common column naming issues
            if "val" in names(df) && !("z" in names(df))
                push!(warnings, "INTERFACE ISSUE: Column 'val' found instead of expected 'z' - this may cause computation errors")
            end

            if "exp_name" in names(df) && !("experiment_id" in names(df))
                push!(warnings, "INTERFACE ISSUE: Column 'exp_name' found instead of expected 'experiment_id'")
            end

            if "polynomial_degree" in names(df) && !("degree" in names(df))
                push!(warnings, "INTERFACE ISSUE: Column 'polynomial_degree' found instead of expected 'degree'")
            end

            if "l2_value" in names(df) && !("z" in names(df))
                push!(warnings, "INTERFACE ISSUE: Column 'l2_value' found instead of expected 'z'")
            end

            # Check for suspicious data patterns
            if "degree" in names(df)
                degrees = collect(skipmissing(df.degree))
                if !isempty(degrees)
                    if any(d -> (isa(d, Number) && (d < 0 || d > 20)), degrees)
                        suspicious_degrees = filter(d -> (isa(d, Number) && (d < 0 || d > 20)), degrees)
                        push!(warnings, "DATA ISSUE: Suspicious degree values detected: $(unique(suspicious_degrees))")
                    end
                end
            end

            # Check for potential L2 norm issues
            if "z" in names(df)
                z_values = collect(skipmissing(df.z))
                if !isempty(z_values) && all(isa.(z_values, Number))
                    if any(z -> z < 0, z_values)
                        push!(warnings, "DATA ISSUE: Negative L2 norm values detected - this may indicate computation errors")
                    end
                    if any(z -> z > 100, z_values)
                        push!(warnings, "DATA ISSUE: Very large L2 norm values (>100) detected - this may indicate convergence failures")
                    end
                end
            end

            # Check for missing experiment metadata
            if "experiment_id" in names(df)
                exp_ids = unique(skipmissing(df.experiment_id))
                if length(exp_ids) == 1 && length(string(exp_ids[1])) < 3
                    push!(warnings, "DATA ISSUE: Very short experiment ID detected - this may cause tracking issues")
                end
            end
        end

        # 6. Additional data quality checks
        # Check for completely empty columns
        empty_cols = String[]
        for col in names(df)
            if all(ismissing, df[!, col])
                push!(empty_cols, col)
            end
        end
        if !isempty(empty_cols)
            push!(warnings, "DATA QUALITY: Completely empty columns detected: $(join(empty_cols, ", "))")
        end

        # Check for duplicate rows
        if nrow(df) != nrow(unique(df))
            duplicate_count = nrow(df) - nrow(unique(df))
            push!(warnings, "DATA QUALITY: $duplicate_count duplicate rows detected")
        end

        load_time = time() - start_time

        return CSVLoadResult(true, df, warnings, nothing, basename(file_path), load_time)

    catch e
        load_time = time() - start_time
        return CSVLoadResult(false, nothing, warnings,
                           "Unexpected error during CSV loading: $e",
                           basename(file_path), load_time)
    end
end

"""
    log_csv_result(result::CSVLoadResult; level::String = "INFO")

Log the result of a defensive CSV loading operation.
"""
function log_csv_result(result::CSVLoadResult; level::String = "INFO")
    if result.success
        println("[$level] Successfully loaded $(result.file): $(nrow(result.data)) rows, $(ncol(result.data)) columns ($(round(result.load_time, digits=3))s)")

        if !isempty(result.warnings)
            for warning in result.warnings
                println("[WARN] $(result.file): $warning")
            end
        end
    else
        println("[ERROR] Failed to load $(result.file): $(result.error) ($(round(result.load_time, digits=3))s)")
    end
end

"""
    safe_csv_read(file_path::String; kwargs...) -> DataFrame

Convenience function that throws an exception on failure but logs warnings.
This provides a drop-in replacement for CSV.read with defensive capabilities.

# Arguments
Same as `defensive_csv_read`

# Returns
DataFrame on success, throws ArgumentError on failure.

# Examples
```julia
# Drop-in replacement for CSV.read
df = safe_csv_read("experiment.csv")

# With options
df = safe_csv_read("experiment.csv", required_columns=["z", "degree"])
```
"""
function safe_csv_read(file_path::String; silent::Bool = false, kwargs...)
    result = defensive_csv_read(file_path; kwargs...)

    if !silent
        log_csv_result(result)
    end

    if result.success
        return result.data
    else
        throw(ArgumentError("CSV loading failed for $file_path: $(result.error)"))
    end
end

end # module DefensiveCSV