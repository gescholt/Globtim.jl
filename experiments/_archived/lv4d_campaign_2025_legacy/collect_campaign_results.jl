#!/usr/bin/env julia
#=
Collection and analysis script for LV4D campaign results
Aggregates results from all 8 experiments
=#

using Pkg
Pkg.activate(".")

using JSON
using DataFrames
using CSV
using Dates
using Statistics
using Printf

println("\n" * "="^60)
println("LV4D CAMPAIGN RESULTS COLLECTION")
println("="^60)

# Find all experiment directories
exp_dirs = filter(d -> occursin(r"lv4d_(float64|adaptive)_\d+\.?\d*_GN16", d),
                  readdir("hpc_results", join=true))

println("Found $(length(exp_dirs)) experiment directories")
println()

# Collect results from each experiment
all_results = DataFrame()
experiment_summaries = []

for exp_dir in exp_dirs
    exp_name = basename(exp_dir)

    # Parse experiment configuration
    m = match(r"lv4d_(float64|adaptive)_([\d\.]+)_GN16", exp_name)
    if isnothing(m)
        println("⚠ Skipping unrecognized directory: $exp_name")
        continue
    end

    precision = m.captures[1]
    domain = parse(Float64, m.captures[2])

    println("Processing: $exp_name")
    println("  Precision: $precision, Domain: ±$domain")

    # Load results summary if available
    summary_file = joinpath(exp_dir, "results_summary.json")
    if !isfile(summary_file)
        println("  ⚠ No results summary found - experiment may be incomplete")
        continue
    end

    summary = JSON.parsefile(summary_file)

    # Extract key metrics
    push!(experiment_summaries, Dict(
        "experiment_id" => summary["experiment_id"],
        "precision_mode" => precision,
        "domain_range" => domain,
        "total_time" => summary["total_time"],
        "successful_degrees" => summary["successful_degrees"],
        "completion_time" => summary["completion_time"]
    ))

    # Collect degree-specific results
    for result in summary["results"]
        if result["success"]
            push!(all_results, (
                precision = precision,
                domain = domain,
                degree = result["degree"],
                critical_points = result["critical_points"],
                real_solutions = result["real_solutions"],
                computation_time = result["computation_time"]
            ))
        end
    end

    println("  ✓ Collected $(summary["successful_degrees"]) degrees")
end

println("\n" * "-"^60)
println("CAMPAIGN SUMMARY")
println("-"^60)

# Overall statistics
total_experiments = length(experiment_summaries)
total_computations = nrow(all_results)
total_time = sum(s["total_time"] for s in experiment_summaries)

println("Total Experiments: $total_experiments/8")
println("Total Successful Computations: $total_computations/72")
println("Total Computation Time: $(round(total_time/60, digits=2)) minutes")
println()

# Precision comparison
println("BY PRECISION MODE:")
for precision in ["float64", "adaptive"]
    precision_data = filter(row -> row.precision == precision, all_results)
    if nrow(precision_data) > 0
        avg_time = mean(precision_data.computation_time)
        avg_real = mean(precision_data.real_solutions)
        println("  $precision:")
        println("    - Computations: $(nrow(precision_data))")
        println("    - Avg time/degree: $(round(avg_time, digits=2))s")
        println("    - Avg real solutions: $(round(avg_real, digits=1))")
    end
end
println()

# Domain comparison
println("BY DOMAIN RANGE:")
for domain in [0.05, 0.1, 0.15, 0.2]
    domain_data = filter(row -> row.domain == domain, all_results)
    if nrow(domain_data) > 0
        avg_time = mean(domain_data.computation_time)
        avg_real = mean(domain_data.real_solutions)
        println("  ±$domain:")
        println("    - Computations: $(nrow(domain_data))")
        println("    - Avg time/degree: $(round(avg_time, digits=2))s")
        println("    - Avg real solutions: $(round(avg_real, digits=1))")
    end
end
println()

# Degree analysis
println("BY POLYNOMIAL DEGREE:")
for degree in 4:12
    degree_data = filter(row -> row.degree == degree, all_results)
    if nrow(degree_data) > 0
        avg_time = mean(degree_data.computation_time)
        avg_real = mean(degree_data.real_solutions)
        count = nrow(degree_data)
        println("  Degree $degree: $count experiments, $(round(avg_time, digits=1))s avg, $(round(avg_real, digits=0)) real solutions")
    end
end

# Save aggregated results
output_dir = "experiments/lv4d_campaign_2025/results"
mkpath(output_dir)

# Save detailed results
CSV.write(joinpath(output_dir, "all_results.csv"), all_results)

# Save campaign summary
campaign_summary = Dict(
    "campaign_id" => "lv4d_extended_2025",
    "collection_time" => now(),
    "total_experiments" => total_experiments,
    "total_computations" => total_computations,
    "total_time_minutes" => total_time / 60,
    "experiment_summaries" => experiment_summaries,
    "statistics" => Dict(
        "by_precision" => Dict(),
        "by_domain" => Dict(),
        "by_degree" => Dict()
    )
)

# Add detailed statistics
for precision in ["float64", "adaptive"]
    precision_data = filter(row -> row.precision == precision, all_results)
    if nrow(precision_data) > 0
        campaign_summary["statistics"]["by_precision"][precision] = Dict(
            "count" => nrow(precision_data),
            "avg_time" => mean(precision_data.computation_time),
            "avg_real_solutions" => mean(precision_data.real_solutions)
        )
    end
end

for domain in [0.05, 0.1, 0.15, 0.2]
    domain_data = filter(row -> row.domain == domain, all_results)
    if nrow(domain_data) > 0
        campaign_summary["statistics"]["by_domain"][string(domain)] = Dict(
            "count" => nrow(domain_data),
            "avg_time" => mean(domain_data.computation_time),
            "avg_real_solutions" => mean(domain_data.real_solutions)
        )
    end
end

open(joinpath(output_dir, "campaign_summary.json"), "w") do f
    JSON.print(f, campaign_summary, 4)
end

println("\n" * "="^60)
println("RESULTS SAVED")
println("="^60)
println("Detailed results: $(joinpath(output_dir, "all_results.csv"))")
println("Campaign summary: $(joinpath(output_dir, "campaign_summary.json"))")
println("="^60)