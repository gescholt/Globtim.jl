"""
    valley_walking_tables.jl

Functions for creating tabular displays of valley walking results.
Provides formatted output for analysis and reporting.
"""

using DataFrames
using Printf

"""
    display_polynomial_comparison_table(results; io=stdout)

Display a comparison table of polynomial degree test results.
"""
function display_polynomial_comparison_table(results; io=stdout)
    println(io, "\n" * "="^120)
    println(io, "POLYNOMIAL DEGREE COMPARISON TABLE")
    println(io, "="^120)
    println(io, "| Degree | Samples | Crit Pts | Condition # | Fit Error  | Valid Error | Success |")
    println(io, "|--------|---------|----------|-------------|------------|-------------|---------|")
    
    for result in results
        success_str = result.success ? "✓" : "✗"
        condition_str = isinf(result.condition_number) ? "    ∞" : 
                       @sprintf("%11.1e", result.condition_number)
        fit_error_str = isinf(result.l2_error) ? "       ∞" : 
                       @sprintf("%10.6f", result.l2_error)
        valid_error_str = if haskey(result, :validation_error)
            isinf(result.validation_error) ? "        ∞" : 
            @sprintf("%11.2e", result.validation_error)
        else
            "        N/A"
        end
        
        println(io, "| $(lpad(result.degree, 6)) | " *
                   "$(lpad(result.samples, 7)) | " *
                   "$(lpad(result.n_critical_points, 8)) | " *
                   "$condition_str | " *
                   "$fit_error_str | " *
                   "$valid_error_str | " *
                   "$(lpad(success_str, 7)) |")
    end
    println(io, "="^120)
end

"""
    display_convergence_table(convergence_data, true_minimum; io=stdout)

Display convergence analysis table showing distance to true minimum.
"""
function display_convergence_table(convergence_data, true_minimum; io=stdout)
    println(io, "\n" * "="^110)
    println(io, "CONVERGENCE TO TRUE MINIMUM $(true_minimum)")
    println(io, "="^110)
    println(io, "| Degree | Samples | Distance to True | Best Critical Point | L2 Error   |")
    println(io, "|--------|---------|------------------|---------------------|------------|")
    
    for result in convergence_data
        if result.success
            dist_str = isinf(result.min_distance_to_true) ? "        ∞" :
                      @sprintf("%16.6e", result.min_distance_to_true)
            
            point_str = result.best_critical_point === nothing ? "       None" :
                       "[" * join([@sprintf("%.4f", x) for x in result.best_critical_point], ", ") * "]"
            
            error_str = @sprintf("%10.6f", result.l2_error)
        else
            dist_str = "        ∞"
            point_str = "       None"
            error_str = "       ∞"
        end
        
        println(io, "| $(lpad(result.degree, 6)) | " *
                   "$(lpad(result.samples, 7)) | " *
                   "$dist_str | " *
                   "$(rpad(point_str, 19)) | " *
                   "$error_str |")
    end
    println(io, "="^110)
end

"""
    display_valley_walking_summary(valley_results; io=stdout)

Display summary statistics for valley walking results.
"""
function display_valley_walking_summary(valley_results; io=stdout)
    println(io, "\n" * "="^80)
    println(io, "VALLEY WALKING SUMMARY")
    println(io, "="^80)
    
    for (i, result) in enumerate(valley_results)
        println(io, "\nPath $i:")
        println(io, "  Start point: " * format_point(result.start_point))
        println(io, "  End point: " * format_point(result.points[end]))
        println(io, "  Initial f: $(@sprintf("%.6e", result.f_values[1]))")
        println(io, "  Final f: $(@sprintf("%.6e", result.f_values[end]))")
        println(io, "  Function decrease: $(@sprintf("%.6e", result.f_values[1] - result.f_values[end]))")
        println(io, "  Path length: $(length(result.points)) points")
        
        # Count step types
        n_valley = count(s -> s == "valley", result.step_types)
        n_gradient = count(s -> s == "gradient", result.step_types)
        println(io, "  Valley steps: $n_valley, Gradient steps: $n_gradient")
        println(io, "  Min eigenvalue: $(@sprintf("%.6e", minimum(result.eigenvalues)))")
    end
    
    println(io, "="^80)
end

"""
    create_critical_points_dataframe(df_critical_points)

Create a formatted DataFrame of critical points with additional analysis.
"""
function create_critical_points_dataframe(df_critical_points)
    if isempty(df_critical_points)
        return DataFrame()
    end
    
    # Create enhanced dataframe with rankings
    df_enhanced = copy(df_critical_points)
    
    # Add rank by function value
    df_enhanced.rank = sortperm(df_enhanced.z)
    
    # Sort by function value
    sort!(df_enhanced, :z)
    
    return df_enhanced
end

"""
    display_critical_points_table(df_critical_points; io=stdout, max_rows=10)

Display critical points in a formatted table.
"""
function display_critical_points_table(df_critical_points; io=stdout, max_rows=10)
    if isempty(df_critical_points)
        println(io, "No critical points found.")
        return
    end
    
    df_sorted = create_critical_points_dataframe(df_critical_points)
    
    println(io, "\n" * "="^80)
    println(io, "CRITICAL POINTS (sorted by function value)")
    println(io, "="^80)
    
    # Determine dimensionality
    n_dims = count(name -> startswith(String(name), "x"), names(df_sorted))
    
    # Create header
    header_parts = ["Rank"]
    for i in 1:n_dims
        push!(header_parts, "x$i")
    end
    push!(header_parts, "f(x)")
    # Only add Type column if it exists
    if "type" in names(df_sorted)
        push!(header_parts, "Type")
    end
    
    println(io, "| " * join(rpad(h, 12) for h in header_parts) * " |")
    println(io, "|" * "-"^(14 * length(header_parts) + 1) * "|")
    
    # Display rows
    n_display = min(max_rows, nrow(df_sorted))
    for i in 1:n_display
        row = df_sorted[i, :]
        
        row_parts = [@sprintf("%4d", row.rank)]
        for j in 1:n_dims
            push!(row_parts, @sprintf("%11.6f", row[Symbol("x$j")]))
        end
        push!(row_parts, @sprintf("%11.6e", row.z))
        # Add type if column exists
        if hasproperty(row, :type)
            push!(row_parts, rpad(row.type, 11))
        end
        
        println(io, "| " * join(row_parts, " ") * " |")
    end
    
    if nrow(df_sorted) > max_rows
        println(io, "| ... $(nrow(df_sorted) - max_rows) more rows ...")
    end
    
    println(io, "="^80)
end

"""
    save_results_to_file(filename, config, polynomial, critical_points, valley_results=nothing)

Save comprehensive results to a text file.
"""
function save_results_to_file(filename, config, polynomial, critical_points, valley_results=nothing)
    open(filename, "w") do io
        # Configuration
        println(io, "CONFIGURATION")
        println(io, "="^50)
        for (key, value) in pairs(config)
            println(io, "$key: $value")
        end
        println(io)
        
        # Polynomial approximation quality
        println(io, "\nPOLYNOMIAL APPROXIMATION")
        println(io, "="^50)
        println(io, "Condition number: $(polynomial.cond_vandermonde)")
        println(io, "L2 fit error (at sample points): $(polynomial.nrm)")
        println(io, "Note: Use validation error for true approximation quality")
        println(io, "Basis: $(polynomial.basis)")
        println(io)
        
        # Critical points
        println(io, "\nCRITICAL POINTS")
        println(io, "="^50)
        display_critical_points_table(critical_points; io=io)
        
        # Valley walking results if provided
        if valley_results !== nothing
            display_valley_walking_summary(valley_results; io=io)
        end
    end
end

"""
    format_point(point; digits=4)

Format a point vector for display.
"""
function format_point(point; digits=4)
    formatted = [round(x, digits=digits) for x in point]
    return "[" * join(string.(formatted), ", ") * "]"
end

"""
    create_summary_statistics(valley_results)

Create a DataFrame with summary statistics for all valley walking paths.
"""
function create_summary_statistics(valley_results)
    summary_data = DataFrame(
        path_id = Int[],
        initial_f = Float64[],
        final_f = Float64[],
        f_decrease = Float64[],
        f_decrease_pct = Float64[],
        n_steps = Int[],
        valley_steps = Int[],
        gradient_steps = Int[],
        min_eigenvalue = Float64[],
        final_distance_from_start = Float64[]
    )
    
    for (i, result) in enumerate(valley_results)
        n_valley = count(s -> s == "valley", result.step_types)
        n_gradient = count(s -> s == "gradient", result.step_types)
        
        initial_f = result.f_values[1]
        final_f = result.f_values[end]
        f_decrease = initial_f - final_f
        f_decrease_pct = 100 * f_decrease / initial_f
        
        distance_traveled = norm(result.points[end] - result.start_point)
        
        push!(summary_data, (
            path_id = i,
            initial_f = initial_f,
            final_f = final_f,
            f_decrease = f_decrease,
            f_decrease_pct = f_decrease_pct,
            n_steps = length(result.points) - 1,
            valley_steps = n_valley,
            gradient_steps = n_gradient,
            min_eigenvalue = minimum(result.eigenvalues),
            final_distance_from_start = distance_traveled
        ))
    end
    
    return summary_data
end