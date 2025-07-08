module TheoreticalPointTables

using DataFrames
using LinearAlgebra
using Statistics

export create_theoretical_point_table, calculate_minimal_distance, 
       populate_distances_for_subdomain, add_summary_row,
       generate_theoretical_point_tables

"""
    create_theoretical_point_table(theoretical_points, theoretical_types, degrees)

Create empty table structure for theoretical points with distance columns for each degree.
"""
function create_theoretical_point_table(
    theoretical_points::Vector{Vector{Float64}},
    theoretical_types::Vector{String},
    degrees::Vector{Int}
)
    n_points = length(theoretical_points)
    
    # Create base DataFrame
    df = DataFrame(
        theoretical_point_id = ["TP_$(lpad(i, 3, '0'))" for i in 1:n_points],
        type = theoretical_types,
        x1 = [p[1] for p in theoretical_points],
        x2 = [p[2] for p in theoretical_points],
        x3 = [p[3] for p in theoretical_points],
        x4 = [p[4] for p in theoretical_points]
    )
    
    # Add distance columns for each degree
    for degree in degrees
        df[!, Symbol("d$degree")] = fill(NaN, n_points)
    end
    
    return df
end

"""
    calculate_minimal_distance(theory_point, computed_points)

Calculate minimal distance from theoretical point to nearest computed point.
"""
function calculate_minimal_distance(
    theory_point::Vector{Float64},
    computed_points::Vector{Vector{Float64}}
)
    if isempty(computed_points)
        return NaN
    end
    
    distances = [norm(theory_point - cp) for cp in computed_points]
    return minimum(distances)
end

"""
    populate_distances_for_subdomain(table, theory_indices, theoretical_points,
                                   computed_points_by_degree, subdomain_label)

Populate distance columns for theoretical points in a subdomain.
"""
function populate_distances_for_subdomain(
    table::DataFrame,
    theory_indices::Vector{Int},
    theoretical_points::Vector{Vector{Float64}},
    computed_points_by_degree::Dict{Int, DataFrame},
    subdomain_label::String
)
    # Get degree columns
    degree_cols = [String(col) for col in names(table) if startswith(String(col), "d")]
    degrees = [parse(Int, col[2:end]) for col in degree_cols]
    
    # For each theoretical point in this subdomain
    for (table_row, theory_idx) in enumerate(theory_indices)
        theory_pt = theoretical_points[theory_idx]
        
        # For each degree
        for degree in degrees
            if haskey(computed_points_by_degree, degree)
                df = computed_points_by_degree[degree]
                
                # Filter to this subdomain
                subdomain_df = filter(row -> row.subdomain == subdomain_label, df)
                
                if !isempty(subdomain_df)
                    # Extract computed points
                    computed_pts = [
                        [row.x1, row.x2, row.x3, row.x4] 
                        for row in eachrow(subdomain_df)
                    ]
                    
                    # Calculate minimal distance
                    min_dist = calculate_minimal_distance(theory_pt, computed_pts)
                    table[table_row, Symbol("d$degree")] = min_dist
                end
            end
        end
    end
    
    return table
end

"""
    add_summary_row(table)

Add AVERAGE row with mean of non-NaN distances for each degree.
"""
function add_summary_row(table::DataFrame)
    # Get degree columns
    degree_cols = [col for col in names(table) if startswith(String(col), "d")]
    
    # Create summary row
    summary_row = Dict{Symbol, Any}(
        :theoretical_point_id => "AVERAGE",
        :type => "-",
        :x1 => NaN,
        :x2 => NaN,
        :x3 => NaN,
        :x4 => NaN
    )
    
    # Calculate averages for each degree
    for col in degree_cols
        col_sym = Symbol(col)
        valid_values = filter(!isnan, table[!, col_sym])
        if !isempty(valid_values)
            summary_row[col_sym] = mean(valid_values)
        else
            summary_row[col_sym] = NaN
        end
    end
    
    # Add to table
    push!(table, summary_row)
    
    return table
end

"""
    generate_theoretical_point_tables(theoretical_points, theoretical_types,
                                    computed_points_by_degree, degrees, subdomains,
                                    is_point_in_subdomain_func)

Generate tables for all subdomains containing theoretical points.
Returns Dict{String, DataFrame} mapping subdomain label to table.
"""
function generate_theoretical_point_tables(
    theoretical_points::Vector{Vector{Float64}},
    theoretical_types::Vector{String},
    computed_points_by_degree::Dict{Int, DataFrame},
    degrees::Vector{Int},
    subdomains,
    is_point_in_subdomain_func
)
    # Assign theoretical points to subdomains
    theory_assignments = Dict{String, Vector{Int}}()
    for subdomain in subdomains
        theory_assignments[subdomain.label] = Int[]
    end
    
    for (idx, point) in enumerate(theoretical_points)
        for subdomain in subdomains
            if is_point_in_subdomain_func(point, subdomain, tolerance=0.0)
                push!(theory_assignments[subdomain.label], idx)
                break
            end
        end
    end
    
    # Create tables for subdomains with theoretical points
    subdomain_tables = Dict{String, DataFrame}()
    
    for (subdomain_label, theory_indices) in theory_assignments
        if isempty(theory_indices)
            continue
        end
        
        # Extract theoretical points for this subdomain
        subdomain_theory_points = theoretical_points[theory_indices]
        subdomain_theory_types = theoretical_types[theory_indices]
        
        # Create table
        table = create_theoretical_point_table(
            subdomain_theory_points,
            subdomain_theory_types,
            degrees
        )
        
        # Populate distances
        table = populate_distances_for_subdomain(
            table,
            theory_indices,
            theoretical_points,
            computed_points_by_degree,
            subdomain_label
        )
        
        # Add summary row
        table = add_summary_row(table)
        
        subdomain_tables[subdomain_label] = table
    end
    
    return subdomain_tables
end

end # module