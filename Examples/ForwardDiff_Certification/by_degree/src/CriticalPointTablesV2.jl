module CriticalPointTablesV2

using DataFrames
using CSV
using LinearAlgebra
using Printf
using PrettyTables
using Statistics

export generate_subdomain_critical_point_tables, export_tables_to_csv, 
       generate_latex_tables, create_summary_table, create_computed_points_summary

"""
    generate_subdomain_critical_point_tables(theoretical_points, theoretical_types, 
                                           all_critical_points_with_labels, degrees, subdomains)

Generate tables showing distances from theoretical critical points to computed points
for each subdomain, organized by polynomial degree.

Since critical points are computed per subdomain, all_critical_points_with_labels already
contains the subdomain assignment in the 'subdomain' column.

Returns a Dict{String, DataFrame} where keys are subdomain labels.
"""
function generate_subdomain_critical_point_tables(
    theoretical_points::Vector{Vector{Float64}},
    theoretical_types::Vector{String},
    all_critical_points_with_labels::Dict{Int, DataFrame},
    degrees::Vector{Int},
    subdomains;
    tolerance::Float64 = 0.0,
    is_point_in_subdomain_func = nothing
)
    # First, assign theoretical points to subdomains
    theory_assignments = Dict{String, Vector{Int}}()
    subdomain_labels = [subdomain.label for subdomain in subdomains]
    
    for label in subdomain_labels
        theory_assignments[label] = Int[]
    end
    
    # Check if function was provided
    if is_point_in_subdomain_func === nothing
        error("is_point_in_subdomain_func must be provided")
    end
    
    # Assign theoretical points to subdomains
    for (idx, point) in enumerate(theoretical_points)
        for subdomain in subdomains
            if is_point_in_subdomain_func(point, subdomain, tolerance=tolerance)
                push!(theory_assignments[subdomain.label], idx)
                break
            end
        end
    end
    
    # Create tables for each subdomain with theoretical points
    subdomain_tables = Dict{String, DataFrame}()
    
    for (subdomain_label, theory_indices) in theory_assignments
        if isempty(theory_indices)
            continue
        end
        
        # Initialize table with theoretical points
        n_points = length(theory_indices)
        table_data = DataFrame(
            point_id = ["CP_$(lpad(i, 3, '0'))" for i in 1:n_points],
            type = theoretical_types[theory_indices],
            x1 = [theoretical_points[idx][1] for idx in theory_indices],
            x2 = [theoretical_points[idx][2] for idx in theory_indices],
            x3 = [theoretical_points[idx][3] for idx in theory_indices],
            x4 = [theoretical_points[idx][4] for idx in theory_indices]
        )
        
        # Add columns for each degree
        for degree in degrees
            col_name = Symbol("degree_$degree")
            table_data[!, col_name] = fill(NaN, n_points)
            
            # Get computed points for this degree and subdomain
            if haskey(all_critical_points_with_labels, degree)
                df = all_critical_points_with_labels[degree]
                if !isempty(df)
                    # Filter to this subdomain - computed points already have subdomain labels!
                    subdomain_df = filter(row -> row.subdomain == subdomain_label, df)
                    
                    if !isempty(subdomain_df)
                        # Calculate distances for each theoretical point
                        for (i, theory_idx) in enumerate(theory_indices)
                            theory_pt = theoretical_points[theory_idx]
                            
                            # Find minimum distance to any computed point in this subdomain
                            min_dist = Inf
                            for row in eachrow(subdomain_df)
                                computed_pt = [row.x1, row.x2, row.x3, row.x4]
                                dist = norm(theory_pt - computed_pt)
                                min_dist = min(min_dist, dist)
                            end
                            
                            if min_dist < Inf
                                table_data[i, col_name] = min_dist
                            end
                        end
                    end
                end
            end
        end
        
        subdomain_tables[subdomain_label] = table_data
    end
    
    return subdomain_tables
end

"""
    export_tables_to_csv(subdomain_tables, output_dir)

Export all subdomain tables to CSV files.
"""
function export_tables_to_csv(subdomain_tables::Dict{String, DataFrame}, output_dir::String)
    mkpath(output_dir)
    
    for (subdomain_label, table) in subdomain_tables
        filename = joinpath(output_dir, "subdomain_$(subdomain_label)_critical_points.csv")
        CSV.write(filename, table)
    end
    
    println("Exported $(length(subdomain_tables)) tables to $output_dir")
end

"""
    generate_latex_tables(subdomain_tables, output_file)

Generate LaTeX tables for inclusion in papers.
"""
function generate_latex_tables(subdomain_tables::Dict{String, DataFrame}, output_file::String)
    open(output_file, "w") do io
        for (subdomain_label, table) in sort(collect(subdomain_tables), by=x->x[1])
            println(io, "\\subsection*{Subdomain $subdomain_label}")
            println(io)
            
            # Format table for LaTeX
            # Select a subset of degrees for space
            degree_cols = [col for col in names(table) if startswith(String(col), "degree_")]
            selected_degrees = degree_cols[1:min(5, length(degree_cols)):end]  # Every 5th degree
            
            display_table = select(table, :point_id, :type, selected_degrees...)
            
            # Use PrettyTables for LaTeX output
            pretty_table(io, display_table, 
                        backend = Val(:latex),
                        formatters = (v, i, j) -> begin
                            if j > 2 && isa(v, Float64)
                                isnan(v) ? "--" : @sprintf("%.4f", v)
                            else
                                v
                            end
                        end)
            
            println(io)
            println(io)
        end
    end
    
    println("LaTeX tables written to $output_file")
end

"""
    create_summary_table(subdomain_tables, degrees)

Create a summary table showing recovery statistics for each subdomain.
"""
function create_summary_table(subdomain_tables::Dict{String, DataFrame}, degrees::Vector{Int})
    summary_data = DataFrame(
        subdomain = String[],
        n_theoretical = Int[],
        n_minima = Int[],
        n_saddles = Int[]
    )
    
    # Add columns for recovery rates by degree
    for degree in degrees
        col_name = Symbol("recovered_deg_$degree")
        summary_data[!, col_name] = Int[]
    end
    
    for (subdomain_label, table) in sort(collect(subdomain_tables), by=x->x[1])
        row_data = Dict{Symbol, Any}(
            :subdomain => subdomain_label,
            :n_theoretical => nrow(table),
            :n_minima => count(x -> x == "min", table.type),
            :n_saddles => count(x -> x == "saddle", table.type)
        )
        
        for degree in degrees
            col_name = Symbol("degree_$degree")
            recovery_col = Symbol("recovered_deg_$degree")
            
            if col_name in names(table)
                n_recovered = count(!isnan, table[!, col_name])
                row_data[recovery_col] = n_recovered
            else
                row_data[recovery_col] = 0
            end
        end
        
        push!(summary_data, row_data)
    end
    
    return summary_data
end

"""
    create_computed_points_summary(all_critical_points_with_labels, degrees)

Create a summary of computed critical points by subdomain and degree.
This directly uses the subdomain labels from the computation.
"""
function create_computed_points_summary(all_critical_points_with_labels::Dict{Int, DataFrame}, 
                                      degrees::Vector{Int})
    summary_data = DataFrame(
        degree = Int[],
        subdomain = String[],
        n_computed = Int[],
        min_function_value = Float64[],
        max_function_value = Float64[]
    )
    
    for degree in degrees
        if haskey(all_critical_points_with_labels, degree)
            df = all_critical_points_with_labels[degree]
            if !isempty(df)
                # Group by subdomain
                grouped = groupby(df, :subdomain)
                for group in grouped
                    subdomain_label = first(group.subdomain)
                    push!(summary_data, (
                        degree = degree,
                        subdomain = subdomain_label,
                        n_computed = nrow(group),
                        min_function_value = minimum(group.function_value),
                        max_function_value = maximum(group.function_value)
                    ))
                end
            end
        end
    end
    
    return summary_data
end

end # module