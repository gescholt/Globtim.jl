# FunctionValueAnalysis.jl - Compare function values at theoretical vs computed critical points

module FunctionValueAnalysis

using DataFrames
using Statistics
using LinearAlgebra

export evaluate_function_values
export create_function_value_comparison_table
export calculate_relative_errors
export summarize_function_value_errors

"""
    evaluate_function_values(points, f)

Evaluate function f at all points and return values.

# Arguments
- `points`: Vector of points (each point is a vector)
- `f`: Function to evaluate

# Returns
- Vector of function values
"""
function evaluate_function_values(points::Vector{Vector{Float64}}, f)
    return [f(p) for p in points]
end

"""
    calculate_relative_errors(theoretical_values, computed_values)

Calculate relative errors between theoretical and computed function values.

# Arguments
- `theoretical_values`: Function values at theoretical critical points
- `computed_values`: Function values at computed critical points

# Returns
- Vector of relative errors |f(computed) - f(theoretical)| / |f(theoretical)|
"""
function calculate_relative_errors(theoretical_values::Vector{Float64}, computed_values::Vector{Float64})
    @assert length(theoretical_values) == length(computed_values) "Vectors must have same length"
    
    relative_errors = Float64[]
    for (f_theo, f_comp) in zip(theoretical_values, computed_values)
        if abs(f_theo) > 1e-10  # Avoid division by very small numbers
            rel_err = abs(f_comp - f_theo) / abs(f_theo)
        else
            # For near-zero theoretical values, use absolute error
            rel_err = abs(f_comp - f_theo)
        end
        push!(relative_errors, rel_err)
    end
    
    return relative_errors
end

"""
    create_function_value_comparison_table(theoretical_points, theoretical_types, 
                                         computed_points_df, f, degree, subdomain_label)

Create a detailed comparison table of function values at theoretical vs computed critical points.

# Arguments
- `theoretical_points`: Vector of theoretical critical points
- `theoretical_types`: Vector of point types ("min", "max", "saddle")
- `computed_points_df`: DataFrame of computed critical points
- `f`: Function to evaluate
- `degree`: Polynomial degree used
- `subdomain_label`: Label for the subdomain

# Returns
- DataFrame with columns: point_type, n_theoretical, n_computed, avg_f_theoretical, 
  avg_f_computed, avg_relative_error, max_relative_error
"""
function create_function_value_comparison_table(
    theoretical_points::Vector{Vector{Float64}},
    theoretical_types::Vector{String},
    computed_points_df::DataFrame,
    f::Function,
    degree::Int,
    subdomain_label::String
)
    # Evaluate function at theoretical points
    theoretical_values = evaluate_function_values(theoretical_points, f)
    
    # Extract computed points from DataFrame
    computed_points = [[row.x1, row.x2, row.x3, row.x4] for row in eachrow(computed_points_df)]
    
    # For each type of critical point, find closest matches and compare
    point_types = unique(theoretical_types)
    comparison_data = []
    
    for ptype in point_types
        # Get theoretical points of this type
        type_mask = theoretical_types .== ptype
        theo_points_type = theoretical_points[type_mask]
        theo_values_type = theoretical_values[type_mask]
        
        if isempty(theo_points_type)
            continue
        end
        
        # For each theoretical point, find the closest computed point
        matched_computed_values = Float64[]
        
        for theo_pt in theo_points_type
            if !isempty(computed_points)
                # Find closest computed point
                distances = [norm(theo_pt - cp) for cp in computed_points]
                min_idx = argmin(distances)
                
                # Only match if reasonably close (within 0.1)
                if distances[min_idx] < 0.1
                    comp_val = f(computed_points[min_idx])
                    push!(matched_computed_values, comp_val)
                end
            end
        end
        
        # Calculate statistics
        if !isempty(matched_computed_values)
            # Match theoretical values to the same number of computed values
            n_matched = length(matched_computed_values)
            matched_theo_values = theo_values_type[1:n_matched]
            
            relative_errors = calculate_relative_errors(matched_theo_values, matched_computed_values)
            
            push!(comparison_data, (
                subdomain = subdomain_label,
                degree = degree,
                point_type = ptype,
                n_theoretical = length(theo_points_type),
                n_computed = nrow(computed_points_df),
                n_matched = n_matched,
                avg_f_theoretical = mean(theo_values_type),
                avg_f_computed = mean(matched_computed_values),
                min_f_theoretical = minimum(theo_values_type),
                min_f_computed = minimum(matched_computed_values),
                avg_relative_error = mean(relative_errors),
                max_relative_error = maximum(relative_errors),
                median_relative_error = median(relative_errors)
            ))
        else
            # No matches found
            push!(comparison_data, (
                subdomain = subdomain_label,
                degree = degree,
                point_type = ptype,
                n_theoretical = length(theo_points_type),
                n_computed = nrow(computed_points_df),
                n_matched = 0,
                avg_f_theoretical = mean(theo_values_type),
                avg_f_computed = NaN,
                min_f_theoretical = minimum(theo_values_type),
                min_f_computed = NaN,
                avg_relative_error = NaN,
                max_relative_error = NaN,
                median_relative_error = NaN
            ))
        end
    end
    
    return DataFrame(comparison_data)
end

"""
    summarize_function_value_errors(comparison_tables)

Create a summary table of function value errors across all subdomains and degrees.

# Arguments
- `comparison_tables`: Dictionary of comparison tables by subdomain and degree

# Returns
- DataFrame with summary statistics
"""
function summarize_function_value_errors(comparison_tables::Dict{String, DataFrame})
    summary_data = []
    
    # Group by degree and point type
    all_data = vcat(values(comparison_tables)...)
    
    for degree in unique(all_data.degree)
        degree_data = all_data[all_data.degree .== degree, :]
        
        for ptype in unique(degree_data.point_type)
            type_data = degree_data[degree_data.point_type .== ptype, :]
            
            # Filter out NaN values
            valid_avg_errors = filter(!isnan, type_data.avg_relative_error)
            valid_max_errors = filter(!isnan, type_data.max_relative_error)
            
            if !isempty(valid_avg_errors)
                push!(summary_data, (
                    degree = degree,
                    point_type = ptype,
                    n_subdomains = nrow(type_data),
                    n_matched_subdomains = length(valid_avg_errors),
                    total_theoretical = sum(type_data.n_theoretical),
                    total_matched = sum(skipmissing(type_data.n_matched)),
                    avg_relative_error = mean(valid_avg_errors),
                    max_relative_error = maximum(valid_max_errors),
                    median_relative_error = median(valid_avg_errors)
                ))
            end
        end
    end
    
    return DataFrame(summary_data)
end

end # module