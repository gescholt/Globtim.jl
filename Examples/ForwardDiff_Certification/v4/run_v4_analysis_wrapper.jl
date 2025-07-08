#!/usr/bin/env julia

# Wrapper function for interactive use of V4 analysis
# This provides a convenient function interface to run_v4_analysis.jl

"""
    run_v4_analysis(; degrees=[3,4], GN=20, output_dir=nothing, plot_results=true, enhanced=true)

Run enhanced V4 analysis with BFGS refinement using a function interface.

# Keyword Arguments
- `degrees`: Vector of polynomial degrees (default: [3,4])
- `GN`: Grid resolution (default: 20)
- `output_dir`: Output directory (auto-generated with timestamp if nothing)
- `plot_results`: Generate plots (default: true)
- `enhanced`: Run enhanced analysis with BFGS refinement (default: true)

# Returns
Named tuple with:
- `subdomain_tables`: V4 tables for each subdomain
- `refinement_metrics`: BFGS refinement effectiveness metrics
- `all_min_refined_points`: Refined points by degree

# Examples
```julia
# First, include this wrapper
include("run_v4_analysis_wrapper.jl")

# Default run
results = run_v4_analysis()

# Higher degrees with custom grid
results = run_v4_analysis(degrees=[3,4,5,6], GN=30)

# Custom output directory
results = run_v4_analysis(degrees=[3,4,5], GN=25, output_dir="outputs/my_analysis")

# Without plots (faster)
results = run_v4_analysis(degrees=[3,4,5,6,7,8], GN=40, plot_results=false)

# Access results
results.subdomain_tables["0000"]  # View specific subdomain
results.refinement_metrics        # View refinement effectiveness
```
"""
function run_v4_analysis(; degrees=[3,4], GN=20, output_dir=nothing, plot_results=true, enhanced=true)
    # Save original ARGS
    original_args = copy(ARGS)
    
    try
        # Clear and set ARGS for the script
        empty!(ARGS)
        
        # Add degrees argument
        push!(ARGS, join(degrees, ","))
        
        # Add GN argument
        push!(ARGS, string(GN))
        
        # Add output directory if specified
        if output_dir !== nothing
            push!(ARGS, output_dir)
        end
        
        # Check if modules are already loaded to avoid reloading
        if !@isdefined(TheoreticalPointTables)
            # First run - include the full script
            result = include(joinpath(@__DIR__, "run_v4_analysis.jl"))
        else
            # Modules already loaded - run the analysis directly
            using Dates
            
            # Set output directory with timestamp if not specified
            if output_dir === nothing
                output_dir = "outputs/enhanced_$(Dates.format(Dates.now(), "HH-MM"))"
            end
            
            println("\n" * "="^80)
            println("🚀 ENHANCED V4 ANALYSIS WITH REFINED POINTS")
            println("="^80)
            println("\nParameters:")
            println("  Degrees: $degrees")
            println("  GN: $GN")
            println("  Output: $output_dir")
            
            # Run the core analysis logic
            # (This duplicates the main logic from run_v4_analysis.jl to avoid re-including)
            
            # Load theoretical points
            println("\n📊 Loading theoretical points...")
            theoretical_points, _, _, theoretical_types = TheoreticalPoints.load_theoretical_4d_points_orthant()
            println("   Loaded $(length(theoretical_points)) theoretical points")
            
            # Generate subdomains
            println("\n📊 Generating subdomains...")
            subdomains = SubdomainManagement.generate_16_subdivisions_orthant()
            println("   Generated $(length(subdomains)) subdomains")
            
            # Run enhanced analysis
            println("\n📊 Running enhanced analysis with BFGS refinement...")
            println("   This may take a few minutes...")
            
            analysis_results = Main.run_enhanced_analysis_with_refinement(
                degrees, GN,
                analyze_global=false,
                threshold=0.1,
                tol_dist=0.05
            )
            
            # Generate V4 tables
            println("\n📊 Generating V4 theoretical point tables...")
            subdomain_tables_v4 = TheoreticalPointTables.generate_theoretical_point_tables(
                theoretical_points,
                theoretical_types,
                analysis_results.all_critical_points,
                degrees,
                subdomains,
                SubdomainManagement.is_point_in_subdomain
            )
            
            # Analyze refined points and create plots if requested
            refinement_metrics = Dict{Int, Any}()
            all_min_refined_points = analysis_results.all_min_refined_points
            
            if enhanced
                # Run the full refined point analysis
                include_string(Main, """
                    # This code block runs the refinement analysis
                    refinement_metrics = Dict{Int, Any}()
                    refined_tables = Dict{String, DataFrame}()
                    refined_to_cheb_distances = Dict{Int, Vector{Float64}}()
                    
                    for degree in $degrees
                        if haskey($(analysis_results.all_critical_points), degree) && haskey($all_min_refined_points, degree)
                            df_cheb = $(analysis_results.all_critical_points)[degree]
                            df_min_refined = $all_min_refined_points[degree]
                            
                            all_refined_to_cheb = Float64[]
                            
                            for subdomain in $subdomains
                                subdomain_label = subdomain.label
                                
                                cheb_mask = df_cheb.subdomain .== subdomain_label
                                refined_mask = df_min_refined.subdomain .== subdomain_label
                                
                                subdomain_cheb = df_cheb[cheb_mask, :]
                                subdomain_refined = df_min_refined[refined_mask, :]
                                
                                if nrow(subdomain_refined) > 0 && nrow(subdomain_cheb) > 0
                                    refined_table = RefinedPointAnalysis.create_refined_distance_table(
                                        subdomain_refined,
                                        subdomain_cheb,
                                        subdomain_label,
                                        degree
                                    )
                                    
                                    table_key = "\$(subdomain_label)_d\$(degree)"
                                    refined_tables[table_key] = refined_table
                                    
                                    append!(all_refined_to_cheb, refined_table[!, Symbol("d\$degree")])
                                end
                            end
                            
                            refined_to_cheb_distances[degree] = all_refined_to_cheb
                            
                            theoretical_minima = [p for (p, t) in zip($theoretical_points, $theoretical_types) if t == "min"]
                            metrics = RefinedPointAnalysis.calculate_refinement_metrics(
                                theoretical_minima,
                                df_cheb,
                                df_min_refined,
                                degree
                            )
                            
                            avg_refined_to_cheb = isempty(all_refined_to_cheb) ? 0.0 : mean(all_refined_to_cheb)
                            refinement_metrics[degree] = (
                                n_computed = nrow(df_cheb),
                                n_refined = nrow(df_min_refined),
                                avg_theo_to_cheb = metrics.avg_theo_to_cheb,
                                avg_theo_to_refined = metrics.avg_theo_to_refined,
                                avg_refined_to_cheb = avg_refined_to_cheb,
                                avg_improvement = metrics.avg_improvement
                            )
                            
                            println("   Degree \$degree: \$(nrow(df_cheb)) → \$(nrow(df_min_refined)) points")
                            println("            Improvement: \$(round(metrics.avg_improvement * 100, digits=1))%")
                        end
                    end
                """)
            end
            
            # Save outputs
            mkpath(output_dir)
            
            # Save V4 tables
            for (label, table) in subdomain_tables_v4
                filename = joinpath(output_dir, "subdomain_$(label)_v4.csv")
                CSV.write(filename, table)
            end
            
            # Save refinement summary if enhanced
            if enhanced && !isempty(refinement_metrics)
                refinement_summary = DataFrame(
                    degree = Int[],
                    n_computed = Int[],
                    n_refined = Int[],
                    avg_theo_to_cheb = Float64[],
                    avg_theo_to_refined = Float64[],
                    avg_refined_to_cheb = Float64[],
                    improvement_pct = Float64[]
                )
                
                for (deg, metrics) in sort(collect(refinement_metrics), by=x->x[1])
                    push!(refinement_summary, (
                        degree = deg,
                        n_computed = metrics.n_computed,
                        n_refined = metrics.n_refined,
                        avg_theo_to_cheb = round(metrics.avg_theo_to_cheb, digits=4),
                        avg_theo_to_refined = round(metrics.avg_theo_to_refined, digits=4),
                        avg_refined_to_cheb = round(metrics.avg_refined_to_cheb, digits=4),
                        improvement_pct = round(metrics.avg_improvement * 100, digits=1)
                    ))
                end
                
                CSV.write(joinpath(output_dir, "refinement_summary.csv"), refinement_summary)
            end
            
            println("\n✅ Tables saved to: $output_dir")
            
            # Create plots if requested
            if plot_results && enhanced
                println("\n📊 Creating enhanced V4 plots...")
                
                # Run the plotting code from the original script
                include_string(Main, """
                    # Prepare data for enhanced plotting
                    plot_data = Dict(
                        "subdomain_tables" => $subdomain_tables_v4,
                        "degrees" => $degrees,
                        "l2_data" => $(analysis_results.l2_data),
                        "distance_data" => $(analysis_results.distance_data),
                        "subdomain_distance_data" => $(analysis_results.subdomain_distance_data),
                        "refined_to_cheb_distances" => refined_to_cheb_distances,
                        "refinement_metrics" => refinement_metrics
                    )
                    
                    # Create theoretical minima to refined distances data
                    minima_to_refined_by_degree = Dict{Int, Dict{String, Vector{Float64}}}()
                    for degree in $degrees
                        if haskey($all_min_refined_points, degree)
                            minima_to_refined_by_degree[degree] = Dict{String, Vector{Float64}}()
                            df_min_refined = $all_min_refined_points[degree]
                            
                            for subdomain in $subdomains
                                subdomain_minima = [p for (p, t) in zip($theoretical_points, $theoretical_types) 
                                    if t == "min" && SubdomainManagement.is_point_in_subdomain(p, subdomain)]
                                
                                subdomain_mask = df_min_refined.subdomain .== subdomain.label
                                subdomain_refined = df_min_refined[subdomain_mask, :]
                                
                                if !isempty(subdomain_minima) && nrow(subdomain_refined) > 0
                                    refined_points = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(subdomain_refined)]
                                    distances = Float64[]
                                    for theo_min in subdomain_minima
                                        min_dist = minimum(norm(theo_min - rp) for rp in refined_points)
                                        push!(distances, min_dist)
                                    end
                                    minima_to_refined_by_degree[degree][subdomain.label] = distances
                                end
                            end
                        end
                    end
                    
                    plot_data["minima_to_refined_distances"] = minima_to_refined_by_degree
                    
                    # Create all plots using V4PlottingEnhanced
                    plots = V4PlottingEnhanced.create_all_v4_plots(
                        plot_data,
                        output_dir = "$output_dir",
                        plot_config = Dict("threshold" => 0.1)
                    )
                """)
                
                println("\n✅ Enhanced plots saved to: $output_dir")
            end
            
            # Print summary
            println("\n" * "="^80)
            println("🎉 ENHANCED V4 ANALYSIS COMPLETE!")
            println("="^80)
            println("\nResults saved to: $output_dir/")
            
            result = (
                subdomain_tables = subdomain_tables_v4,
                refinement_metrics = refinement_metrics,
                all_min_refined_points = all_min_refined_points
            )
        end
        
        return result
        
    finally
        # Restore original ARGS
        empty!(ARGS)
        append!(ARGS, original_args)
    end
end

# Also provide the old function name for compatibility
const run_v4_enhanced = run_v4_analysis

# Print usage information when loaded
println("\n✅ V4 Analysis Wrapper Loaded!")
println("\nUsage:")
println("  results = run_v4_analysis()                    # Default: degrees [3,4], GN=20")
println("  results = run_v4_analysis(degrees=[3,4,5,6])   # Custom degrees")
println("  results = run_v4_analysis(degrees=[3,4,5], GN=30)  # Custom degrees and grid")
println("  results = run_v4_enhanced(...)                 # Alias for compatibility")
println("\nThe function returns:")
println("  - results.subdomain_tables   # V4 tables by subdomain")
println("  - results.refinement_metrics # BFGS refinement summary")
println("  - results.all_min_refined_points # Refined points by degree")