module FunctionValueErrorSummary

using DataFrames
using Statistics
using Printf
using LinearAlgebra
using PrettyTables

export generate_error_summary_table, print_error_summary_table, to_latex_summary, save_latex_summary

"""
Generate a summary table showing captured points and error statistics by degree.
Returns a DataFrame with one row per degree.
"""
function generate_error_summary_table(
    all_critical_points_with_labels::Dict{Int, DataFrame},
    theoretical_points::Vector{Vector{Float64}},
    theoretical_types::Vector{String},
    degrees::Vector{Int},
    f::Function;
    matching_threshold::Float64 = 0.1
)
    # Count theoretical points by type
    theo_min_indices = findall(t -> t == "min", theoretical_types)
    theo_saddle_indices = findall(t -> t == "saddle", theoretical_types)
    
    n_theo_min = length(theo_min_indices)
    n_theo_saddle = length(theo_saddle_indices)
    
    # Separate theoretical points
    theoretical_mins = theoretical_points[theo_min_indices]
    theoretical_saddles = theoretical_points[theo_saddle_indices]
    
    # Initialize result table
    summary_data = DataFrame(
        Degree = Int[],
        Min_Captured = String[],
        Avg_Rel_Error = String[],
        Max_Error = String[],
        Saddle_Captured = String[],
        Avg_Error_Saddle = String[],
        Max_Error_Saddle = String[]
    )
    
    # Process each degree
    for degree in sort(degrees)
        # Skip if no data for this degree
        if !haskey(all_critical_points_with_labels, degree) || isempty(all_critical_points_with_labels[degree])
            push!(summary_data, (
                Degree = degree,
                Min_Captured = "0/$n_theo_min",
                Avg_Rel_Error = "-",
                Max_Error = "-",
                Saddle_Captured = "0/$n_theo_saddle",
                Avg_Error_Saddle = "-",
                Max_Error_Saddle = "-"
            ))
            continue
        end
        
        df_cheb = all_critical_points_with_labels[degree]
        
        # Extract computed points
        computed_points = [Vector{Float64}([row.x1, row.x2, row.x3, row.x4]) for row in eachrow(df_cheb)]
        
        # Process minima by matching to theoretical minima
        min_captured = 0
        min_rel_errors = Float64[]
        min_raw_errors = Float64[]
        
        for theo_pt in theoretical_mins
            f_theo = f(theo_pt)
            
            # Find closest computed point
            min_dist = Inf
            closest_idx = 0
            for (j, comp_pt) in enumerate(computed_points)
                dist = norm(theo_pt - comp_pt)
                if dist < min_dist
                    min_dist = dist
                    closest_idx = j
                end
            end
            
            # If closest point is within threshold, consider it matched
            if min_dist < matching_threshold && closest_idx > 0
                min_captured += 1
                comp_pt = computed_points[closest_idx]
                f_comp = f(comp_pt)
                raw_error = abs(f_comp - f_theo)
                
                # Calculate relative error carefully
                if abs(f_theo) > 1e-10
                    rel_error = raw_error / abs(f_theo)
                    push!(min_rel_errors, rel_error)
                else
                    # If f_theo is near zero, use raw error as fallback
                    push!(min_rel_errors, raw_error)
                end
                
                push!(min_raw_errors, raw_error)
            end
        end
        
        # Process saddle points by matching to theoretical saddles
        saddle_captured = 0
        saddle_raw_errors = Float64[]
        
        for theo_pt in theoretical_saddles
            f_theo = f(theo_pt)
            
            # Find closest computed point
            min_dist = Inf
            closest_idx = 0
            for (j, comp_pt) in enumerate(computed_points)
                dist = norm(theo_pt - comp_pt)
                if dist < min_dist
                    min_dist = dist
                    closest_idx = j
                end
            end
            
            # If closest point is within threshold, consider it matched
            if min_dist < matching_threshold && closest_idx > 0
                saddle_captured += 1
                comp_pt = computed_points[closest_idx]
                f_comp = f(comp_pt)
                raw_error = abs(f_comp - f_theo)
                push!(saddle_raw_errors, raw_error)
            end
        end
        
        # Format results for this degree
        min_captured_str = "$min_captured/$n_theo_min"
        saddle_captured_str = "$saddle_captured/$n_theo_saddle"
        
        # Calculate and format statistics
        avg_rel_error_str = if !isempty(min_rel_errors)
            @sprintf("%.3f%%", mean(min_rel_errors) * 100)
        else
            "-"
        end
        
        max_error_str = if !isempty(min_raw_errors)
            @sprintf("%.1e", maximum(min_raw_errors))
        else
            "-"
        end
        
        avg_error_saddle_str = if !isempty(saddle_raw_errors)
            @sprintf("%.1e", mean(saddle_raw_errors))
        else
            "-"
        end
        
        max_error_saddle_str = if !isempty(saddle_raw_errors)
            @sprintf("%.1e", maximum(saddle_raw_errors))
        else
            "-"
        end
        
        # Add row to summary table
        push!(summary_data, (
            Degree = degree,
            Min_Captured = min_captured_str,
            Avg_Rel_Error = avg_rel_error_str,
            Max_Error = max_error_str,
            Saddle_Captured = saddle_captured_str,
            Avg_Error_Saddle = avg_error_saddle_str,
            Max_Error_Saddle = max_error_saddle_str
        ))
    end
    
    return summary_data
end

"""
Print the error summary table in a formatted way.
"""
function print_error_summary_table(summary_table::DataFrame)
    println("\n" * "="^80)
    println("📊 FUNCTION VALUE ERROR SUMMARY")
    println("="^80)
    
    # Create custom formatting for better alignment
    println("┌────────┬──────────────┬───────────────┬───────────┬─────────────────┬───────────────┬───────────────┐")
    println("│ Degree │ Min Captured │ Avg Rel Error │ Max Error │ Saddle Captured │ Avg Error     │ Max Error     │")
    println("├────────┼──────────────┼───────────────┼───────────┼─────────────────┼───────────────┼───────────────┤")
    
    for row in eachrow(summary_table)
        @printf("│   %2d   │    %-9s │    %-10s │  %-8s │      %-10s │    %-10s │    %-10s │\n",
            row.Degree,
            row.Min_Captured,
            row.Avg_Rel_Error,
            row.Max_Error,
            row.Saddle_Captured,
            row.Avg_Error_Saddle,
            row.Max_Error_Saddle
        )
    end
    
    println("└────────┴──────────────┴───────────────┴───────────┴─────────────────┴───────────────┴───────────────┘")
    
    # Add legend
    println("\nLegend:")
    println("  - Min/Saddle Captured: Number of theoretical points matched (within threshold)")
    println("  - Avg Rel Error: Average relative error for matched minima")
    println("  - Max Error: Maximum absolute error for matched minima")
    println("  - Avg/Max Error (Saddle): Absolute errors for matched saddle points")
end

"""
Convert the error summary table to LaTeX format using PrettyTables.
Returns a string containing the complete LaTeX table.
"""
function to_latex_summary(summary_table::DataFrame; 
                         caption::String = "Function value error summary by polynomial degree",
                         label::String = "tab:error_summary",
                         use_booktabs::Bool = true)
    io = IOBuffer()
    
    # Write table wrapper
    println(io, "\\begin{table}[htbp]")
    println(io, "\\centering")
    println(io, "\\caption{$caption}")
    println(io, "\\label{$label}")
    
    # Use PrettyTables to generate the tabular part
    tf = use_booktabs ? tf_latex_booktabs : tf_latex_default
    
    # Custom header names for better LaTeX formatting
    header = (
        ["Degree", "Captured", "Avg. Rel. Error", "Max Error", "Captured", "Avg. Error", "Max Error"],
        ["", "\\multicolumn{2}{c}{Local Minima}", "", "\\multicolumn{2}{c}{Saddle Points}", ""]
    )
    
    # Generate the table
    pretty_table(io, summary_table,
        backend = Val(:latex),
        tf = tf,
        show_subheader = false,  # Don't show type row
        alignment = [:c, :c, :r, :r, :c, :r, :r]
    )
    
    println(io, "\\end{table}")
    
    return String(take!(io))
end

"""
Save the error summary table to a LaTeX file using PrettyTables.
Also creates a simpler version without table environment wrapper.
"""
function save_latex_summary(summary_table::DataFrame, filepath::String; 
                           caption::String = "Function value error summary by polynomial degree",
                           label::String = "tab:error_summary",
                           use_booktabs::Bool = true,
                           wrap_table::Bool = true)
    
    open(filepath, "w") do io
        if wrap_table
            # Full table with wrapper
            println(io, "\\begin{table}[htbp]")
            println(io, "\\centering")
            println(io, "\\caption{$caption}")
            println(io, "\\label{$label}")
        end
        
        # Generate the tabular part
        tf = use_booktabs ? tf_latex_booktabs : tf_latex_default
        pretty_table(io, summary_table,
            backend = Val(:latex),
            tf = tf,
            show_subheader = false,
            alignment = [:c, :c, :r, :r, :c, :r, :r]
        )
        
        if wrap_table
            println(io, "\\end{table}")
        end
    end
    
    println("LaTeX table saved to: $filepath")
    
    # Also save a simple version without wrapper
    if wrap_table
        simple_filepath = replace(filepath, ".tex" => "_simple.tex")
        save_latex_summary(summary_table, simple_filepath; 
                          caption=caption, label=label, use_booktabs=use_booktabs, 
                          wrap_table=false)
    end
end

end # module