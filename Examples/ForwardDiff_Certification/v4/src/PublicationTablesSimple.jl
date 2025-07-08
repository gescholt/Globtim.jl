module PublicationTablesSimple

using DataFrames
using Statistics
using Printf
using LinearAlgebra

export generate_function_value_error_tables_simple, print_publication_tables_simple

"""
Generate publication-ready tables showing relative errors in function values.
This is a simplified version that focuses on clarity.
"""
function generate_function_value_error_tables_simple(
    all_critical_points_with_labels::Dict{Int, DataFrame},
    theoretical_points::Vector{Vector{Float64}},
    theoretical_types::Vector{String},
    degrees::Vector{Int},
    f::Function
)
    # Separate theoretical points by type
    min_indices = findall(t -> t == "min", theoretical_types)
    saddle_indices = findall(t -> t == "saddle", theoretical_types)
    
    theoretical_mins = theoretical_points[min_indices]
    theoretical_saddles = theoretical_points[saddle_indices]
    
    # Initialize result data structures
    min_errors = Dict{Int, Vector{Float64}}()
    saddle_errors = Dict{Int, Vector{Float64}}()
    min_raw_errors = Dict{Int, Vector{Float64}}()
    saddle_raw_errors = Dict{Int, Vector{Float64}}()
    
    for degree in degrees
        min_errors[degree] = fill(NaN, length(theoretical_mins))
        saddle_errors[degree] = fill(NaN, length(theoretical_saddles))
        min_raw_errors[degree] = fill(NaN, length(theoretical_mins))
        saddle_raw_errors[degree] = fill(NaN, length(theoretical_saddles))
    end
    
    # Process each degree
    for degree in sort(degrees)
        if !haskey(all_critical_points_with_labels, degree)
            continue
        end
        
        df_cheb = all_critical_points_with_labels[degree]
        
        # Extract computed points and their types
        computed_points = [Vector{Float64}([row.x1, row.x2, row.x3, row.x4]) for row in eachrow(df_cheb)]
        computed_types = df_cheb.type_classification
        
        # Match and calculate errors for minima
        for (i, theo_pt) in enumerate(theoretical_mins)
            f_theo = f(theo_pt)
            
            # Find closest computed minimum
            best_rel_error = NaN
            best_raw_error = NaN
            for (j, comp_pt) in enumerate(computed_points)
                if computed_types[j] == "min" && norm(theo_pt - comp_pt) < 0.1
                    f_comp = f(comp_pt)
                    raw_error = abs(f_comp - f_theo)
                    rel_error = abs(f_theo) > 1e-10 ? raw_error / abs(f_theo) : raw_error
                    if isnan(best_rel_error) || rel_error < best_rel_error
                        best_rel_error = rel_error
                        best_raw_error = raw_error
                    end
                end
            end
            min_errors[degree][i] = best_rel_error
            min_raw_errors[degree][i] = best_raw_error
        end
        
        # Match and calculate errors for saddle points
        for (i, theo_pt) in enumerate(theoretical_saddles)
            f_theo = f(theo_pt)
            
            # Find closest computed saddle
            best_rel_error = NaN
            best_raw_error = NaN
            for (j, comp_pt) in enumerate(computed_points)
                if computed_types[j] == "saddle" && norm(theo_pt - comp_pt) < 0.1
                    f_comp = f(comp_pt)
                    raw_error = abs(f_comp - f_theo)
                    rel_error = abs(f_theo) > 1e-10 ? raw_error / abs(f_theo) : raw_error
                    if isnan(best_rel_error) || rel_error < best_rel_error
                        best_rel_error = rel_error
                        best_raw_error = raw_error
                    end
                end
            end
            saddle_errors[degree][i] = best_rel_error
            saddle_raw_errors[degree][i] = best_raw_error
        end
    end
    
    # Build tables
    min_table = build_error_table(min_errors, min_raw_errors, degrees, length(theoretical_mins), "min")
    saddle_table = build_error_table(saddle_errors, saddle_raw_errors, degrees, length(theoretical_saddles), "saddle")
    
    return min_table, saddle_table
end

"""
Build a formatted error table from error data.
"""
function build_error_table(errors::Dict{Int, Vector{Float64}}, raw_errors::Dict{Int, Vector{Float64}}, 
                          degrees::Vector{Int}, n_points::Int, point_type::String)
    # Initialize table with Point_ID column
    offset = point_type == "min" ? 0 : 9  # Saddle points start at TP_010
    table = DataFrame(Point_ID = ["TP_$(lpad(i + offset, 3, '0'))" for i in 1:n_points])
    
    # Add degree columns
    for degree in sort(degrees)
        col_data = String[]
        rel_data = Float64[]
        abs_data = Float64[]
        
        for i in 1:n_points
            rel_error = errors[degree][i]
            raw_error = raw_errors[degree][i]
            if isnan(rel_error)
                push!(col_data, "-")
                push!(rel_data, NaN)
                push!(abs_data, NaN)
            else
                push!(col_data, @sprintf("%.3f%%", rel_error * 100))
                push!(rel_data, rel_error)
                push!(abs_data, raw_error)
            end
        end
        
        table[!, Symbol("Degree_$degree")] = col_data
        table[!, Symbol("Rel_$degree")] = rel_data
        table[!, Symbol("Raw_$degree")] = abs_data
    end
    
    # Calculate summaries
    avg_rel_row = String["Avg Rel"]
    avg_raw_row = String["Avg Raw"]
    
    for degree in sort(degrees)
        rel_col = Symbol("Rel_$degree")
        raw_col = Symbol("Raw_$degree")
        
        rel_values = filter(!isnan, table[!, rel_col])
        raw_values = filter(!isnan, table[!, raw_col])
        
        if !isempty(rel_values)
            avg_rel = mean(rel_values)
            avg_raw = mean(raw_values)
            push!(avg_rel_row, @sprintf("%.3f%%", avg_rel * 100))
            push!(avg_raw_row, @sprintf("%.1e", avg_raw))
        else
            push!(avg_rel_row, "-")
            push!(avg_raw_row, "-")
        end
    end
    
    # Remove raw and rel columns (keep only display columns)
    for degree in degrees
        select!(table, Not(Symbol("Raw_$degree")))
        select!(table, Not(Symbol("Rel_$degree")))
    end
    
    # Add summary rows
    push!(table, fill("─"^8, ncol(table)))
    push!(table, avg_rel_row)
    push!(table, avg_raw_row)
    
    return table
end

"""
Print the tables in a publication-ready format.
"""
function print_publication_tables_simple(min_table::DataFrame, saddle_table::DataFrame)
    println("\n" * "="^80)
    println("📊 FUNCTION VALUE RELATIVE ERRORS")
    println("="^80)
    
    println("\n### Table 1: Relative Errors for Local Minima ($(nrow(min_table)-3) points)")
    println()
    show(min_table, allrows=true, allcols=true)
    
    println("\n\n### Table 2: Relative Errors for Saddle Points ($(nrow(saddle_table)-3) points)")
    println()
    show(saddle_table, allrows=true, allcols=true)
    
    println("\n" * "="^80)
end

end # module