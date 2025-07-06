# Test script to generate just the distance convergence plot

println("="^80)
println("Running Distance Convergence Analysis Only")
println("="^80)

# Include the main analysis file
include("examples/simplified_subdomain_analysis.jl")

# Load existing results from CSV files
using DataFrames, CSV

# Use the directory with complete distance analysis
latest_dir = "outputs/simplified_23-16"

println("\nUsing data from: $(basename(latest_dir))")

# Load subdomain distance results
df_subdomain = CSV.read(joinpath(latest_dir, "subdomain_distance_results.csv"), DataFrame)

# Load full domain distance results  
df_full = CSV.read(joinpath(latest_dir, "full_domain_distance_results.csv"), DataFrame)

# Convert back to the expected format
subdomain_distance_results = Dict{String, Vector{NamedTuple}}()

for subdomain in unique(df_subdomain.subdomain)
    subdomain_df = filter(row -> row.subdomain == subdomain, df_subdomain)
    results = [
        (degree=row.degree, 
         avg_min_distance=row.avg_min_distance, 
         min_min_distance=row.min_min_distance,
         n_minimizers=row.n_minimizers,
         n_critical_points=row.n_critical_points)
        for row in eachrow(subdomain_df)
    ]
    subdomain_distance_results[string(subdomain)] = results
end

full_domain_distance_results = [
    (degree=row.degree, 
     avg_min_distance=row.avg_min_distance, 
     min_min_distance=row.min_min_distance)
    for row in eachrow(df_full)
]

# Generate the updated plot
println("\nGenerating updated distance convergence plot...")
fig = plot_distance_convergence(subdomain_distance_results, full_domain_distance_results, 
                               save_plot=true, output_dir="outputs/test_plot")

# Also display the plot
display(fig)

println("\nPlot saved to: outputs/test_plot/distance_convergence.png")