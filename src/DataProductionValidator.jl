# DataProductionValidator.jl - Validate HPC Cluster Data Production Quality
# Ensures output data meets quality standards before processing or analysis

module DataProductionValidator

using DataFrames
using CSV
using Statistics

export validate_experiment_output, DataProductionError, ProductionValidationResult
export validate_column_types, validate_column_content, validate_experiment_metadata
export check_for_filename_contamination, validate_parameter_ranges
export create_data_quality_report

# Custom error type for data production validation failures
struct DataProductionError <: Exception
    message::String
    error_type::String
    file_path::String
    details::Dict{String, Any}

    function DataProductionError(message::String, error_type::String, file_path::String="unknown"; details=Dict{String, Any}())
        new(message, error_type, file_path, details)
    end
end

# Validation result structure
struct ProductionValidationResult
    valid::Bool
    warnings::Vector{String}
    errors::Vector{String}
    quality_score::Float64
    details::Dict{String, Any}

    function ProductionValidationResult(valid::Bool, warnings::Vector{String}, errors::Vector{String};
                                      quality_score::Float64=0.0, details::Dict{String, Any}=Dict())
        new(valid, warnings, errors, quality_score, details)
    end
end

"""
    validate_experiment_output(file_path::String) -> ProductionValidationResult

Comprehensive validation of HPC experiment output files.
Checks for data quality, column integrity, and meaningful content.
"""
function validate_experiment_output(file_path::String)::ProductionValidationResult
    warnings = String[]
    errors = String[]
    details = Dict{String, Any}()

    # Check file exists and is readable
    if !isfile(file_path)
        push!(errors, "File does not exist: $file_path")
        return ProductionValidationResult(false, warnings, errors)
    end

    try
        # Load the data
        df = CSV.read(file_path, DataFrame)
        details["file_path"] = file_path
        details["dimensions"] = size(df)
        details["columns"] = names(df)

        # 1. Basic structure validation
        structure_result = validate_basic_structure(df, file_path)
        append!(warnings, structure_result.warnings)
        append!(errors, structure_result.errors)
        merge!(details, structure_result.details)

        # 2. Column type validation
        type_result = validate_column_types(df, file_path)
        append!(warnings, type_result.warnings)
        append!(errors, type_result.errors)
        merge!(details, type_result.details)

        # 3. Content quality validation
        content_result = validate_column_content(df, file_path)
        append!(warnings, content_result.warnings)
        append!(errors, content_result.errors)
        merge!(details, content_result.details)

        # 4. Filename contamination check (critical issue you identified)
        contamination_result = check_for_filename_contamination(df, file_path)
        append!(warnings, contamination_result.warnings)
        append!(errors, contamination_result.errors)
        merge!(details, contamination_result.details)

        # 5. Parameter range validation
        range_result = validate_parameter_ranges(df, file_path)
        append!(warnings, range_result.warnings)
        append!(errors, range_result.errors)
        merge!(details, range_result.details)

        # 6. Experiment metadata validation
        metadata_result = validate_experiment_metadata(df, file_path)
        append!(warnings, metadata_result.warnings)
        append!(errors, metadata_result.errors)
        merge!(details, metadata_result.details)

        # Calculate quality score
        quality_score = calculate_quality_score(df, warnings, errors)
        details["quality_score"] = quality_score

        # Determine overall validity
        is_valid = isempty(errors)

        return ProductionValidationResult(is_valid, warnings, errors,
                                        quality_score=quality_score, details=details)

    catch e
        push!(errors, "Failed to process file $file_path: $e")
        return ProductionValidationResult(false, warnings, errors, details=details)
    end
end

"""
    validate_basic_structure(df::DataFrame, file_path::String) -> ProductionValidationResult

Validate basic DataFrame structure and dimensions.
"""
function validate_basic_structure(df::DataFrame, file_path::String)::ProductionValidationResult
    warnings = String[]
    errors = String[]
    details = Dict{String, Any}()

    # Check for empty DataFrame
    if nrow(df) == 0
        push!(errors, "DataFrame is empty - no data rows")
    elseif nrow(df) < 3
        push!(warnings, "Very few data rows ($(nrow(df))) - may indicate incomplete experiment")
    end

    if ncol(df) == 0
        push!(errors, "DataFrame has no columns")
    elseif ncol(df) < 5
        push!(warnings, "Few columns ($(ncol(df))) - may be missing essential data")
    end

    # Check for duplicate column names
    col_names = names(df)
    unique_names = unique(col_names)
    if length(col_names) != length(unique_names)
        duplicates = [name for name in unique_names if count(==(name), col_names) > 1]
        push!(errors, "Duplicate column names detected: $(join(duplicates, ", "))")
    end

    details["basic_structure"] = Dict(
        "rows" => nrow(df),
        "columns" => ncol(df),
        "column_names" => col_names
    )

    return ProductionValidationResult(isempty(errors), warnings, errors, details=details)
end

"""
    validate_column_types(df::DataFrame, file_path::String) -> ProductionValidationResult

Validate that columns contain expected data types.
"""
function validate_column_types(df::DataFrame, file_path::String)::ProductionValidationResult
    warnings = String[]
    errors = String[]
    details = Dict{String, Any}()

    type_info = Dict{String, Any}()

    for col in names(df)
        col_type = eltype(df[!, col])
        type_info[col] = string(col_type)

        # Check for string columns that should be numeric
        if col_type <: AbstractString
            # Parameter columns should be numeric
            if startswith(col, "x") && length(col) == 2 && isdigit(col[2])
                push!(errors, "Parameter column '$col' contains strings instead of numbers")
            elseif col == "z" || col == "val"
                push!(errors, "Critical value column '$col' contains strings instead of numbers")
            elseif col in ["degree", "domain_size", "num_critical_points"]
                push!(errors, "Numeric metadata column '$col' contains strings instead of numbers")
            end

            # Check if string column contains only filename-like values
            sample_values = first(df[!, col], min(5, nrow(df)))
            if all(v -> occursin(".csv", v) || occursin(".jl", v) || occursin(".txt", v), sample_values)
                push!(warnings, "Column '$col' appears to contain only filenames - verify this is intentional")
            end
        end

        # Check for missing value issues
        missing_count = count(ismissing, df[!, col])
        if missing_count > 0
            missing_pct = (missing_count / nrow(df)) * 100
            if missing_pct > 50
                push!(errors, "Column '$col' has >50% missing values ($missing_pct%)")
            elseif missing_pct > 10
                push!(warnings, "Column '$col' has significant missing values ($missing_pct%)")
            end
        end
    end

    details["column_types"] = type_info

    return ProductionValidationResult(isempty(errors), warnings, errors, details=details)
end

"""
    validate_column_content(df::DataFrame, file_path::String) -> ProductionValidationResult

Validate the actual content of columns for meaningful values.
"""
function validate_column_content(df::DataFrame, file_path::String)::ProductionValidationResult
    warnings = String[]
    errors = String[]
    details = Dict{String, Any}()

    content_stats = Dict{String, Any}()

    for col in names(df)
        if eltype(df[!, col]) <: Number
            values = collect(skipmissing(df[!, col]))
            if !isempty(values)
                stats = Dict(
                    "min" => minimum(values),
                    "max" => maximum(values),
                    "mean" => mean(values),
                    "std" => length(values) > 1 ? std(values) : 0.0,
                    "unique_count" => length(unique(values))
                )
                content_stats[col] = stats

                # Check for suspicious patterns
                if stats["std"] == 0.0
                    push!(warnings, "Column '$col' has zero variance - all values identical ($(stats["min"]))")
                elseif stats["std"] < 1e-10
                    push!(warnings, "Column '$col' has extremely low variance (std=$(stats["std"])) - may indicate computation issues")
                end

                # Check for infinite or NaN values
                if any(!isfinite, values)
                    invalid_count = count(!isfinite, values)
                    push!(errors, "Column '$col' contains $invalid_count infinite/NaN values")
                end

                # Parameter-specific validation
                if startswith(col, "x") && length(col) == 2
                    if stats["min"] < -100 || stats["max"] > 100
                        push!(warnings, "Parameter column '$col' has extreme values ($(stats["min"]) to $(stats["max"])) - verify parameter bounds")
                    end
                end

                # L2 norm validation
                if col in ["z", "val", "mean_l2_overall", "best_l2", "worst_l2"]
                    if stats["min"] < 0
                        push!(errors, "L2 norm column '$col' contains negative values - impossible for norms")
                    elseif stats["max"] > 1000
                        push!(warnings, "L2 norm column '$col' has very large values (max=$(stats["max"])) - verify computation")
                    end
                end
            end
        else
            # String column analysis
            values = collect(skipmissing(df[!, col]))
            if !isempty(values)
                unique_vals = unique(values)
                content_stats[col] = Dict(
                    "unique_count" => length(unique_vals),
                    "sample_values" => first(unique_vals, min(3, length(unique_vals)))
                )
            end
        end
    end

    details["content_stats"] = content_stats

    return ProductionValidationResult(isempty(errors), warnings, errors, details=details)
end

"""
    check_for_filename_contamination(df::DataFrame, file_path::String) -> ProductionValidationResult

Critical check: Detect if columns contain filenames instead of actual data.
This addresses the specific issue you identified.
"""
function check_for_filename_contamination(df::DataFrame, file_path::String)::ProductionValidationResult
    warnings = String[]
    errors = String[]
    details = Dict{String, Any}()

    contamination_detected = false
    contaminated_columns = String[]

    for col in names(df)
        values = collect(skipmissing(df[!, col]))
        if !isempty(values)
            # Check if values look like filenames
            filename_patterns = [r"\.csv$", r"\.jl$", r"\.txt$", r"\.dat$", r"\.h5$", r"\.json$"]
            filename_like_count = 0

            for val in values
                val_str = string(val)
                if any(pattern -> occursin(pattern, val_str), filename_patterns)
                    filename_like_count += 1
                end
            end

            filename_pct = (filename_like_count / length(values)) * 100

            if filename_pct > 90
                push!(errors, "Column '$col' appears to contain filenames instead of data ($filename_pct% filename-like values)")
                contamination_detected = true
                push!(contaminated_columns, col)
            elseif filename_pct > 50
                push!(warnings, "Column '$col' may contain mixed filenames and data ($filename_pct% filename-like values)")
                contamination_detected = true
                push!(contaminated_columns, col)
            elseif filename_pct > 10
                push!(warnings, "Column '$col' contains some filename-like values ($filename_pct%) - verify data integrity")
            end

            # Specific check for columns that should NEVER contain filenames
            if col in ["x1", "x2", "x3", "x4", "z", "val", "degree", "domain_size"] && filename_pct > 0
                push!(errors, "Critical parameter/value column '$col' contains filename-like values - data corruption detected")
                contamination_detected = true
            end
        end
    end

    details["filename_contamination"] = Dict(
        "detected" => contamination_detected,
        "contaminated_columns" => contaminated_columns
    )

    return ProductionValidationResult(isempty(errors), warnings, errors, details=details)
end

"""
    validate_parameter_ranges(df::DataFrame, file_path::String) -> ProductionValidationResult

Validate that parameter values are within reasonable ranges for the problem domain.
"""
function validate_parameter_ranges(df::DataFrame, file_path::String)::ProductionValidationResult
    warnings = String[]
    errors = String[]
    details = Dict{String, Any}()

    range_info = Dict{String, Any}()

    # Expected reasonable ranges for 4D Lotka-Volterra parameters
    expected_ranges = Dict(
        "x1" => (0.0, 10.0),    # Prey growth rate
        "x2" => (0.0, 5.0),     # Predation rate
        "x3" => (0.0, 5.0),     # Predator efficiency
        "x4" => (0.0, 10.0)     # Predator death rate
    )

    for (param, (min_expected, max_expected)) in expected_ranges
        if param in names(df)
            values = collect(skipmissing(df[!, param]))
            if !isempty(values)
                actual_min, actual_max = extrema(values)
                range_info[param] = (actual_min, actual_max)

                # Check if values are outside biologically reasonable ranges
                if actual_min < -1.0
                    push!(errors, "Parameter '$param' has negative values (min=$actual_min) - biologically unrealistic")
                elseif actual_min < 0
                    push!(warnings, "Parameter '$param' has values near zero (min=$actual_min) - verify biological meaning")
                end

                if actual_max > max_expected * 2
                    push!(warnings, "Parameter '$param' has very large values (max=$actual_max) - verify parameter scaling")
                elseif actual_max > max_expected * 10
                    push!(errors, "Parameter '$param' has extremely large values (max=$actual_max) - likely scaling error")
                end

                # Check for clustering (may indicate optimization not exploring parameter space)
                if length(values) > 3
                    range_span = actual_max - actual_min
                    expected_span = max_expected - min_expected
                    if range_span < expected_span * 0.01
                        push!(warnings, "Parameter '$param' shows very narrow range (span=$range_span) - optimization may not be exploring parameter space")
                    end
                end
            end
        end
    end

    details["parameter_ranges"] = range_info

    return ProductionValidationResult(isempty(errors), warnings, errors, details=details)
end

"""
    validate_experiment_metadata(df::DataFrame, file_path::String) -> ProductionValidationResult

Validate experiment metadata for consistency and meaningfulness.
"""
function validate_experiment_metadata(df::DataFrame, file_path::String)::ProductionValidationResult
    warnings = String[]
    errors = String[]
    details = Dict{String, Any}()

    metadata_info = Dict{String, Any}()

    # Check for required metadata columns
    required_metadata = ["experiment_id", "timestamp"]
    missing_metadata = setdiff(required_metadata, names(df))
    if !isempty(missing_metadata)
        push!(warnings, "Missing recommended metadata columns: $(join(missing_metadata, ", "))")
    end

    # Validate experiment_id
    if "experiment_id" in names(df)
        exp_ids = collect(skipmissing(df[!, "experiment_id"]))
        unique_ids = unique(exp_ids)
        metadata_info["experiment_count"] = length(unique_ids)
        metadata_info["total_points"] = length(exp_ids)

        if length(unique_ids) == 1
            push!(warnings, "All rows have same experiment_id - may be missing experiment variation")
        end

        # Check for reasonable experiment ID format
        sample_id = first(exp_ids)
        if !occursin("_", string(sample_id)) || length(string(sample_id)) < 10
            push!(warnings, "Experiment IDs may not be sufficiently descriptive: '$(sample_id)'")
        end
    end

    # Validate timestamps
    if "timestamp" in names(df)
        timestamps = collect(skipmissing(df[!, "timestamp"]))
        unique_timestamps = unique(timestamps)

        if length(unique_timestamps) == 1
            push!(warnings, "All data has same timestamp - may indicate batch processing issue")
        end

        # Check timestamp format
        sample_timestamp = string(first(timestamps))
        if !occursin(r"\d{8}", sample_timestamp)
            push!(warnings, "Timestamp format may not be standard: '$sample_timestamp'")
        end
    end

    # Validate degree consistency
    if "degree" in names(df)
        degrees = collect(skipmissing(df[!, "degree"]))
        unique_degrees = unique(degrees)

        if any(d -> d < 1 || d > 20, degrees)
            invalid_degrees = filter(d -> d < 1 || d > 20, degrees)
            push!(warnings, "Unusual polynomial degrees detected: $(unique(invalid_degrees))")
        end
    end

    details["metadata_info"] = metadata_info

    return ProductionValidationResult(isempty(errors), warnings, errors, details=details)
end

"""
    calculate_quality_score(df::DataFrame, warnings::Vector{String}, errors::Vector{String}) -> Float64

Calculate an overall quality score (0-100) for the dataset.
"""
function calculate_quality_score(df::DataFrame, warnings::Vector{String}, errors::Vector{String})::Float64
    base_score = 100.0

    # Deduct for errors (severe)
    base_score -= length(errors) * 15.0

    # Deduct for warnings (moderate)
    base_score -= length(warnings) * 5.0

    # Deduct for structural issues
    if nrow(df) < 5
        base_score -= 10.0
    end

    if ncol(df) < 5
        base_score -= 10.0
    end

    return max(0.0, min(100.0, base_score))
end

"""
    create_data_quality_report(validation_result::ProductionValidationResult) -> String

Generate a human-readable quality report.
"""
function create_data_quality_report(validation_result::ProductionValidationResult)::String
    report = """
    ═══════════════════════════════════════════════════════════════
    HPC DATA PRODUCTION QUALITY REPORT
    ═══════════════════════════════════════════════════════════════

    Overall Status: $(validation_result.valid ? "✅ VALID" : "❌ INVALID")
    Quality Score: $(round(validation_result.quality_score, digits=1))/100.0

    """

    if haskey(validation_result.details, "file_path")
        report *= "File: $(validation_result.details["file_path"])\n"
    end

    if haskey(validation_result.details, "dimensions")
        dims = validation_result.details["dimensions"]
        report *= "Dimensions: $(dims[1]) rows × $(dims[2]) columns\n"
    end

    if !isempty(validation_result.errors)
        report *= "\n❌ CRITICAL ERRORS ($(length(validation_result.errors))):\n"
        for (i, error) in enumerate(validation_result.errors)
            report *= "  $i. $error\n"
        end
    end

    if !isempty(validation_result.warnings)
        report *= "\n⚠️  WARNINGS ($(length(validation_result.warnings))):\n"
        for (i, warning) in enumerate(validation_result.warnings)
            report *= "  $i. $warning\n"
        end
    end

    # Add specific details
    if haskey(validation_result.details, "filename_contamination")
        contam = validation_result.details["filename_contamination"]
        if contam["detected"]
            report *= "\n🚨 FILENAME CONTAMINATION DETECTED:\n"
            report *= "  Contaminated columns: $(join(contam["contaminated_columns"], ", "))\n"
        end
    end

    if haskey(validation_result.details, "content_stats")
        report *= "\n📊 DATA SUMMARY:\n"
        stats = validation_result.details["content_stats"]
        for (col, info) in stats
            if isa(info, Dict) && haskey(info, "min")
                report *= "  $col: $(round(info["min"], digits=3)) to $(round(info["max"], digits=3)) (std=$(round(info["std"], digits=3)))\n"
            end
        end
    end

    report *= "\n═══════════════════════════════════════════════════════════════\n"

    return report
end

end # module DataProductionValidator