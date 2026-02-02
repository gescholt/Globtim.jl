module HPCValidationIntegration
# Integration examples for ValidationBoundaries in HPC workflows

using DataFrames
using CSV
# ValidationBoundaries module should be included before this module
# Access ValidationBoundaries functions through module prefix

# HPC Data Generation with Validation Boundaries
function hpc_safe_data_generation(experiment_params::Dict)
    try
        println("🔬 Running HPC experiment with parameters: $experiment_params")

        # Simulate running optimization experiment
        raw_results = simulate_optimization_experiment(experiment_params)

        # CRITICAL VALIDATION BOUNDARY
        println("🔍 Validating experiment output...")
        validation = ValidationBoundaries.validate_experiment_output_strict(raw_results)

        if !validation.success
            quality_score = validation.quality_score
            errors = join([format_validation_error(e) for e in validation.errors], "\n  ")
            @error "🚨 HPC Data Generation Failed" quality_score=quality_score
            println("❌ VALIDATION ERRORS:")
            println("  $errors")

            throw(ValidationBoundaries.DataProductionError("hpc_data_generation",
                                    "Invalid data generated during HPC experiment",
                                    Dict("quality_score" => quality_score,
                                         "experiment_params" => experiment_params)))
        end

        println("✅ Data validation passed (Quality: $(round(validation.quality_score, digits=1))/100)")

        # Save with validation
        output_file = generate_output_filename(experiment_params)
        save_result = save_experiment_results_safe(raw_results, output_file)

        if save_result.success
            println("💾 Results saved to: $(save_result.data)")
            return save_result.data
        else
            errors = join([format_validation_error(e) for e in save_result.errors], "\n  ")
            throw(ValidationBoundaries.DataProductionError("hpc_file_save", "Failed to save results: $errors",
                                    Dict("output_file" => output_file)))
        end

    catch e
        @error "🚨 HPC Experiment Failed" error=string(e) experiment_params=experiment_params
        rethrow(e)
    end
end

# Simulate optimization experiment (replace with actual HPC computation)
function simulate_optimization_experiment(params::Dict)
    n_points = get(params, "n_critical_points", 10)
    experiment_id = get(params, "experiment_id", "exp_$(rand(1000:9999))")

    # Simulate some realistic parameter values
    x1_vals = 1.0 .+ 0.1 * randn(n_points)
    x2_vals = 0.5 .+ 0.2 * randn(n_points)
    x3_vals = 0.1 .+ 0.05 * randn(n_points)
    x4_vals = 0.05 .+ 0.02 * randn(n_points)
    z_vals = 2.0 .+ 0.3 * randn(n_points)  # L2 norms

    # Create DataFrame with proper structure
    df = DataFrame(
        x1 = clamp.(x1_vals, 0.1, 5.0),  # Biological parameter bounds
        x2 = clamp.(x2_vals, 0.1, 3.0),
        x3 = clamp.(x3_vals, 0.01, 1.0),
        x4 = clamp.(x4_vals, 0.01, 0.5),
        z = abs.(z_vals),  # L2 norms must be positive
        experiment_id = repeat([experiment_id], n_points),
        degree = repeat([get(params, "degree", 4)], n_points),
        domain_size = repeat([get(params, "domain_size", 0.1)], n_points),
        timestamp = repeat([string(Dates.now())], n_points)
    )

    return df
end

function generate_output_filename(params::Dict)
    timestamp = replace(string(Dates.now()), ":" => "", "." => "", " " => "_")
    exp_id = get(params, "experiment_id", "unknown")
    return "/tmp/claude/hpc_experiment_$(exp_id)_$(timestamp).csv"
end

# Data Loading with Quality Gates for Analysis/Dashboard
function load_hpc_results_for_analysis(filepath::String;
                                     min_quality_score::Float64=75.0,
                                     require_columns::Vector{Symbol}=Symbol[])
    println("📊 Loading HPC results for analysis: $filepath")

    try
        # Defensive loading with schema validation
        required_cols = isempty(require_columns) ?
                       [:x1, :x2, :x3, :x4, :z, :experiment_id] : require_columns

        load_result = safe_read_csv(filepath;
            required_columns=required_cols,
            expected_types=Dict{Symbol,DataType}(
                :x1=>Float64, :x2=>Float64, :x3=>Float64, :x4=>Float64, :z=>Float64
            )
        )

        if !load_result.success
            errors = join([format_validation_error(e) for e in load_result.errors], "\n  ")
            throw(ValidationBoundaries.DataLoadError(filepath, "Schema validation failed:\n  $errors"))
        end

        df = load_result.data
        println("✅ Data loaded successfully: $(nrow(df)) rows, $(ncol(df)) columns")

        # Quality gate using existing DataProductionValidator
        include("DataProductionValidator.jl")
        quality_check = DataProductionValidator.validate_experiment_output(filepath)

        if quality_check.quality_score < min_quality_score
            @warn "⚠️  Data Quality Below Threshold" quality_score=quality_check.quality_score threshold=min_quality_score

            # Log quality issues
            if haskey(quality_check.details, "filename_contamination") &&
               quality_check.details["filename_contamination"]["detected"]

                contaminated_cols = quality_check.details["filename_contamination"]["contaminated_columns"]
                @error "🚨 FILENAME CONTAMINATION DETECTED" columns=contaminated_cols
                throw(ValidationBoundaries.DataQualityError(quality_check.quality_score, min_quality_score,
                                     "Filename contamination in columns: $(join(contaminated_cols, ", "))"))
            end

            if quality_check.quality_score < 50.0
                throw(ValidationBoundaries.DataQualityError(quality_check.quality_score, min_quality_score,
                                     "Data quality critically low: $(quality_check.quality_score)"))
            end
        else
            println("✅ Data quality acceptable: $(round(quality_check.quality_score, digits=1))/100")
        end

        return df

    catch e
        @error "❌ Failed to load HPC results" filepath=filepath error=string(e)
        rethrow(e)
    end
end

# Integration with interactive_comparison_demo.jl
function generate_validated_dashboard(data_sources::Vector{String})
    println("🎨 Generating dashboard with validation boundaries...")

    validated_data = DataFrame[]

    for source in data_sources
        try
            df = load_hpc_results_for_analysis(source; min_quality_score=70.0)
            push!(validated_data, df)
            println("✅ Validated data source: $source")
        catch e
            @warn "⚠️  Skipping invalid data source" source=source error=string(e)
        end
    end

    if isempty(validated_data)
        throw(DataQualityError(0.0, 70.0, "No valid data sources available for dashboard generation"))
    end

    # Combine validated data
    combined_df = vcat(validated_data...)
    println("📊 Combined $(length(validated_data)) validated sources into $(nrow(combined_df)) rows")

    # Final validation on combined data
    final_validation = ValidationBoundaries.validate_experiment_output_strict(combined_df)
    if !final_validation.success
        errors = join([format_validation_error(e) for e in final_validation.errors], "\n  ")
        throw(ValidationBoundaries.DataQualityError(final_validation.quality_score, 70.0,
                             "Combined dataset failed validation:\n  $errors"))
    end

    println("✅ Combined dataset validation passed (Quality: $(round(final_validation.quality_score, digits=1))/100)")
    return combined_df
end

# Example usage functions
function run_hpc_experiment_example()
    println("=== HPC Validation Integration Example ===")

    # Example experiment parameters
    experiment_configs = [
        Dict("experiment_id" => "lv_test_1", "n_critical_points" => 12, "degree" => 4),
        Dict("experiment_id" => "lv_test_2", "n_critical_points" => 8, "degree" => 5),
        Dict("experiment_id" => "lv_test_3", "n_critical_points" => 15, "degree" => 4)
    ]

    output_files = String[]

    for config in experiment_configs
        try
            output_file = hpc_safe_data_generation(config)
            push!(output_files, output_file)
        catch e
            @warn "Experiment failed" config=config error=string(e)
        end
    end

    println("\n=== Dashboard Generation with Validation ===")
    try
        validated_dashboard_data = generate_validated_dashboard(output_files)
        println("🎉 Successfully generated validated dashboard with $(nrow(validated_dashboard_data)) data points")
        return validated_dashboard_data
    catch e
        @error "Dashboard generation failed" error=string(e)
        return nothing
    end
end

# Export functions for integration
export hpc_safe_data_generation, load_hpc_results_for_analysis
export generate_validated_dashboard, run_hpc_experiment_example

end # module HPCValidationIntegration