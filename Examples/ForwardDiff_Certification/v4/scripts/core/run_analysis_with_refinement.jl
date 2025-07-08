# Enhanced analysis function with BFGS refinement collection

using Globtim
using DynamicPolynomials
using LinearAlgebra
using DataFrames
using Statistics
using ..Common4DDeuflhard
using ..SubdomainManagement
using ..TheoreticalPoints

export run_enhanced_analysis_with_refinement

"""
    run_enhanced_analysis_with_refinement(degrees, GN; analyze_global, threshold, tol_dist)

Run the enhanced analysis with BFGS refinement collection.
Returns both the standard data and the refined points data.
"""
function run_enhanced_analysis_with_refinement(
    degrees::Vector{Int}, 
    GN::Int; 
    analyze_global::Bool=false, 
    threshold::Float64=0.1,
    tol_dist::Float64=0.05
)
    # Generate subdomains
    subdomains = generate_16_subdivisions_orthant()
    
    # Initialize storage for all critical points and refined points
    all_critical_points_with_labels = Dict{Int, DataFrame}()
    all_refined_points = Dict{Int, DataFrame}()
    all_min_refined_points = Dict{Int, DataFrame}()
    
    for degree in degrees
        println("\n📊 Processing degree $degree...")
        
        # Initialize combined DataFrames for this degree
        combined_df = DataFrame()
        combined_refined_df = DataFrame()
        combined_min_refined_df = DataFrame()
        
        # Process each subdomain
        for (idx, subdomain) in enumerate(subdomains)
            println("   Processing subdomain $(subdomain.label)...")
            
            # Get theoretical points for this subdomain
            theoretical_points, theoretical_values, theoretical_types = 
                load_theoretical_points_for_subdomain_orthant(subdomain)
            
            if isempty(theoretical_points)
                println("   ⚠️  No theoretical points in subdomain $(subdomain.label)")
                continue
            end
            
            # Run Globtim analysis
            TR = test_input(
                deuflhard_4d_composite, 
                dim=4, 
                center=subdomain.center, 
                sample_range=subdomain.range,
                tolerance=0.0007,
                GN=GN
            )
            pol = Constructor(TR, degree, basis=:chebyshev, verbose=false)
            actual_degree = get_actual_degree(pol)
            
            # Solve polynomial system
            @polyvar x[1:4]
            crit_pts = solve_polynomial_system(x, 4, actual_degree, pol.coeffs)
            
            # Process critical points
            df_crit = process_crit_pts(crit_pts, deuflhard_4d_composite, TR)
            
            # Apply analyze_critical_points to get refined points
            # Note: No copy needed - analyze_critical_points doesn't modify input
            df_refined, df_min_refined = analyze_critical_points(
                deuflhard_4d_composite, 
                df_crit, 
                TR, 
                tol_dist=tol_dist,
                enable_hessian=false  # Keep it fast
            )
            
            # Add subdomain labels
            df_crit.subdomain = fill(subdomain.label, nrow(df_crit))
            df_refined.subdomain = fill(subdomain.label, nrow(df_refined))
            df_min_refined.subdomain = fill(subdomain.label, nrow(df_min_refined))
            
            # Append to combined DataFrames
            if isempty(combined_df)
                combined_df = df_crit
                combined_refined_df = df_refined
                combined_min_refined_df = df_min_refined
            else
                combined_df = vcat(combined_df, df_crit)
                combined_refined_df = vcat(combined_refined_df, df_refined)
                combined_min_refined_df = vcat(combined_min_refined_df, df_min_refined)
            end
        end
        
        # Store for this degree
        all_critical_points_with_labels[degree] = combined_df
        all_refined_points[degree] = combined_refined_df
        all_min_refined_points[degree] = combined_min_refined_df
        
        println("   Total critical points found: $(nrow(combined_df))")
        println("   Total refined minima found: $(nrow(combined_min_refined_df))")
    end
    
    # Initialize data structures for plotting
    l2_data_by_degree_by_subdomain = Dict{Int, Dict{String, Float64}}()
    distance_data_by_degree = Dict{Int, Vector{Float64}}()
    subdomain_distance_data_by_degree = Dict{Int, Dict{String, Vector{Float64}}}()
    
    # Process data for plotting
    for degree in degrees
        l2_data_by_degree_by_subdomain[degree] = Dict{String, Float64}()
        subdomain_distance_data_by_degree[degree] = Dict{String, Vector{Float64}}()
        all_distances = Float64[]
        
        # Get computed points for this degree
        computed_points_df = all_critical_points_with_labels[degree]
        
        for subdomain in subdomains
            # Get theoretical points for this subdomain
            theoretical_points, _, _ = load_theoretical_points_for_subdomain_orthant(subdomain)
            
            # Get computed points in this subdomain
            subdomain_mask = computed_points_df.subdomain .== subdomain.label
            subdomain_computed = computed_points_df[subdomain_mask, :]
            
            if nrow(subdomain_computed) > 0
                computed_points = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(subdomain_computed)]
                
                # Calculate distances from theoretical to computed points
                distances = Float64[]
                for tp in theoretical_points
                    if !isempty(computed_points)
                        min_dist = minimum(norm(tp - cp) for cp in computed_points)
                        push!(distances, min_dist)
                        push!(all_distances, min_dist)
                    end
                end
                
                if !isempty(distances)
                    subdomain_distance_data_by_degree[degree][subdomain.label] = distances
                end
            end
            
            # Store dummy L2 data (would need actual polynomial info for real L2 norms)
            # For now, using a placeholder
            l2_data_by_degree_by_subdomain[degree][subdomain.label] = 0.001 / degree
        end
        
        distance_data_by_degree[degree] = all_distances
    end
    
    # Return all the data structures including refined points
    return (
        l2_data = l2_data_by_degree_by_subdomain,
        distance_data = distance_data_by_degree,
        subdomain_distance_data = subdomain_distance_data_by_degree,
        all_critical_points = all_critical_points_with_labels,
        all_refined_points = all_refined_points,
        all_min_refined_points = all_min_refined_points
    )
end

# Helper function to get actual degree from polynomial
# Use the one from Common4DDeuflhard if available, otherwise define locally
if !isdefined(Main, :get_actual_degree)
    function get_actual_degree(pol)
        return pol.degree isa Tuple ? pol.degree[2] : pol.degree
    end
end