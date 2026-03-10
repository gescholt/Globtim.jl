"""
Test fixtures for BatchManifest testing.

Provides helper functions to generate realistic test data for batch experiments.
"""

using Dates
using JSON3
using CSV
using DataFrames

# Load BatchManifest module if not already loaded
if !isdefined(Main, :BatchManifest)
    include("../../src/BatchManifest.jl")
    using .BatchManifest
    using .BatchManifest: ExperimentEntry, Manifest
end

"""
    create_test_batch_manifest(n_experiments::Int; batch_id="test_batch", batch_type="parameter_sweep")

Create a test batch manifest with N experiments, all in "pending" status.
Returns a proper Manifest object.
"""
function create_test_batch_manifest(n_experiments::Int;
                                   batch_id="test_batch",
                                   batch_type="parameter_sweep")
    experiments = [
        ExperimentEntry(
            "exp_$i",
            "scripts/exp_$i.jl",
            "configs/exp_$i.toml",
            "results/exp_$i",
            "pending"
        )
        for i in 1:n_experiments
    ]

    return Manifest(
        batch_id,
        batch_type,
        now(),
        n_experiments,
        experiments,
        Dict{String, Any}("test_param" => "test_value"),
        "pending"
    )
end

"""
    generate_test_results_summary(; degrees=3:5, schema_version="1.1.0")

Generate a Schema v1.1.0 compliant results_summary.json structure.
"""
function generate_test_results_summary(; degrees=3:5, schema_version="1.1.0")
    results = Dict{String, Any}("schema_version" => schema_version)

    for d in degrees
        results["degree_$d"] = Dict(
            "critical_points" => 6,
            "critical_points_in_domain" => 4,
            "critical_points_raw" => 6,
            "critical_points_refined" => 6,
            "L2_norm" => rand() * 1e-6,  # Random small error
            "total_computation_time" => rand() * 10.0,
            "refinement_stats" => Dict(
                "converged" => 6,
                "failed" => 0,
                "mean_improvement" => 1e8 * rand(),
                "max_improvement" => 2e8 * rand(),
                "mean_iterations" => 20 + rand() * 10
            )
        )
    end

    return results
end

"""
    generate_test_critical_points(; degree=3, n_points=6)

Generate test critical points data as a DataFrame (for CSV export).
Note: degree parameter is available for future use in generating degree-specific patterns.
"""
function generate_test_critical_points(; degree=3, n_points=6)
    _ = degree  # Reserved for future degree-specific generation
    df = DataFrame(
        x1 = randn(n_points),
        x2 = randn(n_points),
        x3 = randn(n_points),
        x4 = randn(n_points),
        f_value = rand(n_points) .* 1e-6,
        in_domain = rand(Bool, n_points),
        converged = fill(true, n_points),
        iterations = rand(10:50, n_points)
    )

    return df
end

"""
    create_test_results_dir(manifest::Dict, complete_exps::Vector{Int}; degrees=3:5)

Create a temporary directory with experiment results for the specified experiments.

# Arguments
- `manifest`: Batch manifest dict
- `complete_exps`: Vector of experiment indices that should have complete results
- `degrees`: Range of polynomial degrees to generate results for

# Returns
- Path to temporary directory containing the results
"""
function create_test_results_dir(manifest::Dict, complete_exps::Vector{Int}; degrees=3:5)
    tmpdir = mktempdir()

    for i in complete_exps
        exp = manifest["experiments"][i]
        exp_dir = joinpath(tmpdir, exp["experiment_id"])
        mkpath(exp_dir)

        # Generate results_summary.json
        results = generate_test_results_summary(degrees=degrees)
        open(joinpath(exp_dir, "results_summary.json"), "w") do io
            JSON3.pretty(io, results)
        end

        # Generate CSV files for each degree
        for deg in degrees
            df = generate_test_critical_points(degree=deg)
            CSV.write(joinpath(exp_dir, "critical_points_raw_deg_$deg.csv"), df)
        end
    end

    return tmpdir
end

"""
    create_test_results_dir_with_errors(manifest, complete, missing_output, missing_results, invalid_json)

Create a test results directory with various error conditions for testing error detection.

# Arguments
- `manifest`: Batch manifest dict
- `complete`: Vector of experiment indices with complete, valid results
- `missing_output`: Vector of experiment indices with no output directory
- `missing_results`: Vector of experiment indices with directory but no results_summary.json
- `invalid_json`: Vector of experiment indices with malformed JSON

# Returns
- Path to temporary directory containing the results
"""
function create_test_results_dir_with_errors(manifest::Dict,
                                            complete::Vector{Int},
                                            missing_output::Vector{Int},
                                            missing_results::Vector{Int},
                                            invalid_json::Vector{Int})
    tmpdir = mktempdir()

    # Create complete experiments
    for i in complete
        exp = manifest["experiments"][i]
        exp_dir = joinpath(tmpdir, exp["experiment_id"])
        mkpath(exp_dir)

        results = generate_test_results_summary()
        open(joinpath(exp_dir, "results_summary.json"), "w") do io
            JSON3.pretty(io, results)
        end
    end

    # missing_output: don't create directory at all
    _ = missing_output  # Intentionally not creating directories for these

    # missing_results: create directory but no results file
    for i in missing_results
        exp = manifest["experiments"][i]
        exp_dir = joinpath(tmpdir, exp["experiment_id"])
        mkpath(exp_dir)
        # Don't write results_summary.json
    end

    # invalid_json: create directory with malformed JSON
    for i in invalid_json
        exp = manifest["experiments"][i]
        exp_dir = joinpath(tmpdir, exp["experiment_id"])
        mkpath(exp_dir)

        open(joinpath(exp_dir, "results_summary.json"), "w") do io
            write(io, "{invalid json this is broken")
        end
    end

    return tmpdir
end

"""
    setup_complete_test_batch(; n_experiments=3, degrees=3:5, domain_sizes=[0.1, 0.5, 1.0])

Create a complete test batch with manifest and all results files.

# Returns
- Tuple of (batch_dir, manifest) where batch_dir contains the manifest and results
"""
function setup_complete_test_batch(; n_experiments=3,
                                    degrees=3:5,
                                    domain_sizes=[0.1, 0.5, 1.0])
    @assert n_experiments == length(domain_sizes) "n_experiments must match length of domain_sizes"

    batch_dir = mktempdir()

    # Create manifest with metadata about domain sizes
    manifest = create_test_batch_manifest(
        n_experiments,
        batch_id="test_complete_batch",
        batch_type="domain_sweep"
    )

    # Add domain size to batch params
    manifest["batch_params"]["domain_sizes"] = domain_sizes

    # Save manifest
    open(joinpath(batch_dir, "batch_manifest.json"), "w") do io
        JSON3.pretty(io, manifest)
    end

    # Create all experiment results
    for exp in manifest["experiments"]
        exp_dir = joinpath(batch_dir, exp["experiment_id"])
        mkpath(exp_dir)

        # Generate results
        results = generate_test_results_summary(degrees=degrees)
        open(joinpath(exp_dir, "results_summary.json"), "w") do io
            JSON3.pretty(io, results)
        end

        # Generate CSV files
        for deg in degrees
            df = generate_test_critical_points(degree=deg)
            CSV.write(joinpath(exp_dir, "critical_points_raw_deg_$deg.csv"), df)
        end
    end

    return (batch_dir, manifest)
end
