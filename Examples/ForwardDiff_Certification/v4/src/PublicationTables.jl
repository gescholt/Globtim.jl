module PublicationTables

using DataFrames
using CSV
using Statistics
using LinearAlgebra
using Printf

export generate_function_value_error_tables, print_publication_tables

"""
    generate_function_value_error_tables(all_critical_points_with_labels, theoretical_points, theoretical_types, degrees, f)

Generate publication-ready tables showing relative errors in function values between theoretical
and computed critical points, with separate tables for minima and saddle points.
"""
function generate_function_value_error_tables(
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
    
    # Initialize result tables
    min_table = DataFrame(Point_ID = ["TP_$(lpad(i, 3, '0'))" for i in 1:length(theoretical_mins)])
    saddle_table = DataFrame(Point_ID = ["TP_$(lpad(i+length(theoretical_mins), 3, '0'))" for i in 1:length(theoretical_saddles)])
    
    # Process each degree
    for degree in sort(degrees)
        if !haskey(all_critical_points_with_labels, degree)
            continue
        end
        
        df_cheb = all_critical_points_with_labels[degree]
        
        # Extract computed points and their types
        computed_points = [Vector{Float64}([row.x1, row.x2, row.x3, row.x4]) for row in eachrow(df_cheb)]
        computed_types = df_cheb.type_classification
        
        # Initialize columns for this degree
        min_rel_errors = fill(NaN, length(theoretical_mins))
        min_raw_errors = fill(NaN, length(theoretical_mins))
        saddle_rel_errors = fill(NaN, length(theoretical_saddles))
        saddle_raw_errors = fill(NaN, length(theoretical_saddles))
        
        # Match and calculate errors for minima
        for (i, theo_pt) in enumerate(theoretical_mins)
            f_theo = f(theo_pt)
            
            # Find closest computed minimum
            min_distances = Float64[]
            min_indices_comp = Int[]
            
            for (j, comp_pt) in enumerate(computed_points)
                if computed_types[j] == "min"
                    push!(min_distances, norm(theo_pt - comp_pt))
                    push!(min_indices_comp, j)
                end
            end
            
            if !isempty(min_distances)
                min_dist, idx = findmin(min_distances)
                if min_dist < 0.1  # Match threshold
                    comp_idx = min_indices_comp[idx]
                    f_comp = f(computed_points[comp_idx])
                    
                    # Calculate errors
                    raw_error = abs(f_comp - f_theo)
                    rel_error = abs(f_theo) > 1e-10 ? raw_error / abs(f_theo) : raw_error
                    
                    min_rel_errors[i] = rel_error
                    min_raw_errors[i] = raw_error
                end
            end
        end
        
        # Match and calculate errors for saddle points
        for (i, theo_pt) in enumerate(theoretical_saddles)
            f_theo = f(theo_pt)
            
            # Find closest computed saddle
            saddle_distances = Float64[]
            saddle_indices_comp = Int[]
            
            for (j, comp_pt) in enumerate(computed_points)
                if computed_types[j] == "saddle"
                    push!(saddle_distances, norm(theo_pt - comp_pt))
                    push!(saddle_indices_comp, j)
                end
            end
            
            if !isempty(saddle_distances)
                min_dist, idx = findmin(saddle_distances)
                if min_dist < 0.1  # Match threshold
                    comp_idx = saddle_indices_comp[idx]
                    f_comp = f(computed_points[comp_idx])
                    
                    # Calculate errors
                    raw_error = abs(f_comp - f_theo)
                    rel_error = abs(f_theo) > 1e-10 ? raw_error / abs(f_theo) : raw_error
                    
                    saddle_rel_errors[i] = rel_error
                    saddle_raw_errors[i] = raw_error
                end
            end
        end
        
        # Add columns to tables (relative errors as percentages)
        min_table[!, Symbol("Degree_$degree")] = [isnan(e) ? "-" : @sprintf("%.3f%%", e * 100) for e in min_rel_errors]
        saddle_table[!, Symbol("Degree_$degree")] = [isnan(e) ? "-" : @sprintf("%.3f%%", e * 100) for e in saddle_rel_errors]
        
        # Store raw errors for summary rows
        min_table[!, Symbol("Raw_$degree")] = min_raw_errors
        saddle_table[!, Symbol("Raw_$degree")] = saddle_raw_errors
    end
    
    # Add summary rows
    min_table = add_summary_rows(min_table, degrees)
    saddle_table = add_summary_rows(saddle_table, degrees)
    
    return min_table, saddle_table
end

"""
Add average relative error and average raw error summary rows to the table.
Returns a new table with summary rows added.
"""
function add_summary_rows(table::DataFrame, degrees::Vector{Int})
    println("Debug: add_summary_rows called with degrees=$degrees")
    println("Debug: table columns = $(names(table))")
    
    # Store raw values before processing
    raw_data = Dict{Int, Vector{Float64}}()
    rel_data = Dict{Int, Vector{Float64}}()
    
    for degree in sort(degrees)
        degree_col = Symbol("Degree_$degree")
        raw_col = Symbol("Raw_$degree")
        
        if degree_col in names(table) && raw_col in names(table)
            println("Debug: Processing degree=$degree")
            # Get non-missing values
            rel_values = Float64[]
            raw_values = Float64[]
            
            for (i, val) in enumerate(table[!, degree_col])
                if val != "-"
                    # Parse percentage back to number
                    push!(rel_values, parse(Float64, replace(val, "%" => "")) / 100)
                    raw_val = table[i, raw_col]
                    if !isnan(raw_val)
                        push!(raw_values, raw_val)
                    end
                end
            end
            
            if !isempty(rel_values)
                raw_data[degree] = raw_values
                rel_data[degree] = rel_values
                # Debug
                println("Debug: degree=$degree, rel_values count=$(length(rel_values))")
            end
        end
    end
    
    # Now build summary rows with correct number of columns
    avg_rel_row = String["Avg Rel"]
    avg_raw_row = String["Avg Raw"]
    
    for degree in sort(degrees)
        degree_col = Symbol("Degree_$degree")
        
        if degree_col in names(table)
            println("Debug summary: degree=$degree, haskey=$(haskey(rel_data, degree))")
            if haskey(rel_data, degree) && !isempty(rel_data[degree])
                avg_rel = mean(rel_data[degree])
                avg_raw = mean(raw_data[degree])
                push!(avg_rel_row, @sprintf("%.3f%%", avg_rel * 100))
                push!(avg_raw_row, @sprintf("%.1e", avg_raw))
            else
                push!(avg_rel_row, "-")
                push!(avg_raw_row, "-")
            end
        end
    end
    
    # Remove raw columns before adding summary rows
    cols_to_keep = [col for col in names(table) if !startswith(string(col), "Raw_")]
    table_final = select(table, cols_to_keep)
    
    # Convert table to all strings before adding summary rows
    for col in names(table_final)
        if col != :Point_ID  # Keep Point_ID as is
            table_final[!, col] = string.(table_final[!, col])
        end
    end
    
    # Add separator row with correct number of columns
    separator_row = fill("─"^8, ncol(table_final))
    separator_row[1] = "─"^8
    
    # Create proper rows with all columns
    sep_row_dict = Dict{Symbol, String}()
    rel_row_dict = Dict{Symbol, String}()
    raw_row_dict = Dict{Symbol, String}()
    
    col_names = names(table_final)
    for (i, col) in enumerate(col_names)
        sep_row_dict[Symbol(col)] = i <= length(separator_row) ? separator_row[i] : "─"^8
        rel_row_dict[Symbol(col)] = i <= length(avg_rel_row) ? avg_rel_row[i] : "-"
        raw_row_dict[Symbol(col)] = i <= length(avg_raw_row) ? avg_raw_row[i] : "-"
    end
    
    # Add summary rows
    push!(table_final, sep_row_dict)
    push!(table_final, rel_row_dict) 
    push!(table_final, raw_row_dict)
    
    # Return the final table
    return table_final
end

"""
Print the tables in a publication-ready format.
"""
function print_publication_tables(min_table::DataFrame, saddle_table::DataFrame)
    println("\n" * "="^80)
    println("📊 FUNCTION VALUE RELATIVE ERRORS")
    println("="^80)
    
    # Select only the degree columns (not raw columns)
    degree_cols = [col for col in names(min_table) if startswith(string(col), "Degree_") || col == :Point_ID]
    
    println("\n### Table 1: Relative Errors for Local Minima ($(nrow(min_table)-3) points)")
    println()
    show(select(min_table, degree_cols), allrows=true, allcols=true)
    
    println("\n\n### Table 2: Relative Errors for Saddle Points ($(nrow(saddle_table)-3) points)")
    println()
    show(select(saddle_table, degree_cols), allrows=true, allcols=true)
    
    println("\n" * "="^80)
end

end # module