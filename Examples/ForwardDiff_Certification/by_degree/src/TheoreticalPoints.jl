# TheoreticalPoints.jl - Loading and classification of theoretical critical points

module TheoreticalPoints

using DataFrames, CSV, LinearAlgebra
using ForwardDiff
using Globtim
using ..Common4DDeuflhard: deuflhard_4d_composite
using ..SubdomainManagement: Subdomain, is_point_in_subdomain

export load_2d_critical_points, generate_4d_tensor_products
export load_theoretical_4d_points, load_theoretical_points_for_subdomain
export load_2d_critical_points_orthant, generate_4d_tensor_products_orthant
export load_theoretical_4d_points_orthant, load_theoretical_points_for_subdomain_orthant
export generate_and_save_all_4d_critical_points

"""
    load_2d_critical_points()

Load and classify 2D Deuflhard critical points from CSV file.

# Returns
- `critical_2d::Vector{Vector{Float64}}`: 2D critical point coordinates
- `critical_2d_types::Vector{String}`: Point classifications ("min", "max", "saddle")
"""
function load_2d_critical_points()
    csv_path = joinpath(@__DIR__, "../../../../data/matlab_critical_points/valid_points_deuflhard.csv")
    
    if !isfile(csv_path)
        error("Critical points CSV file not found at: $csv_path")
    end
    
    csv_data = CSV.read(csv_path, DataFrame)
    critical_2d = [[row.x, row.y] for row in eachrow(csv_data)]
    
    # Classify 2D points using Hessian analysis
    critical_2d_types = String[]
    for pt in critical_2d
        hess = ForwardDiff.hessian(Deuflhard, pt)
        eigenvals = eigvals(hess)
        
        if all(eigenvals .> 1e-6)
            push!(critical_2d_types, "min")
        elseif all(eigenvals .< -1e-6)
            push!(critical_2d_types, "max")
        else
            push!(critical_2d_types, "saddle")
        end
    end
    
    return critical_2d, critical_2d_types
end

"""
    generate_4d_tensor_products(critical_2d, critical_2d_types)

Generate 4D tensor product critical points from 2D points.

# Arguments
- `critical_2d`: Vector of 2D critical points
- `critical_2d_types`: Classifications of 2D points

# Returns
- `theoretical_points_4d::Vector{Vector{Float64}}`: 4D critical point coordinates
- `theoretical_values_4d::Vector{Float64}`: Function values at critical points
- `theoretical_types::Vector{String}`: Classifications (e.g., "min+min", "min+saddle")
- `theoretical_4d_types::Vector{String}`: Resulting 4D point type ("min", "max", "saddle")
"""
function generate_4d_tensor_products(critical_2d, critical_2d_types)
    theoretical_points_4d = Vector{Vector{Float64}}()
    theoretical_values_4d = Float64[]
    theoretical_types = String[]
    theoretical_4d_types = String[]
    
    for (i, pt1) in enumerate(critical_2d)
        for (j, pt2) in enumerate(critical_2d)
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            value_4d = deuflhard_4d_composite(point_4d)
            type_label = "$(critical_2d_types[i])+$(critical_2d_types[j])"
            
            # Determine 4D critical point type
            type1 = critical_2d_types[i]
            type2 = critical_2d_types[j]
            
            if type1 == "min" && type2 == "min"
                type_4d = "min"
            elseif type1 == "max" && type2 == "max"
                type_4d = "max"
            else
                type_4d = "saddle"
            end
            
            push!(theoretical_points_4d, point_4d)
            push!(theoretical_values_4d, value_4d)
            push!(theoretical_types, type_label)
            push!(theoretical_4d_types, type_4d)
        end
    end
    
    return theoretical_points_4d, theoretical_values_4d, theoretical_types, theoretical_4d_types
end

"""
    load_theoretical_4d_points()

Load all theoretical 4D critical points for full domain analysis.

# Returns
- `Tuple`: (theoretical_points, theoretical_values, theoretical_types, theoretical_4d_types)
"""
function load_theoretical_4d_points()
    critical_2d, critical_2d_types = load_2d_critical_points()
    return generate_4d_tensor_products(critical_2d, critical_2d_types)
end

"""
    load_theoretical_points_for_subdomain(subdomain::Subdomain)

Load theoretical critical points that fall within the specified subdomain.

# Arguments
- `subdomain`: Subdomain structure defining spatial bounds

# Returns
- `Tuple`: (theoretical_points, theoretical_values, theoretical_types) within subdomain
"""
function load_theoretical_points_for_subdomain(subdomain::Subdomain)
    # Get all 4D points
    all_points, all_values, all_types, _ = load_theoretical_4d_points()
    
    # Filter by subdomain
    filtered_points = Vector{Vector{Float64}}()
    filtered_values = Float64[]
    filtered_types = String[]
    
    for (i, point) in enumerate(all_points)
        if is_point_in_subdomain(point, subdomain, tolerance=0.0)
            push!(filtered_points, point)
            push!(filtered_values, all_values[i])
            push!(filtered_types, all_types[i])
        end
    end
    
    return filtered_points, filtered_values, filtered_types
end

"""
    load_2d_critical_points_orthant()

Load and classify 2D Deuflhard critical points that lie in the (+,-) orthant within bounds [0,1.1] × [-1.1,0].

# Returns
- `critical_2d::Vector{Vector{Float64}}`: 2D critical point coordinates in (+,-) orthant within bounds
- `critical_2d_types::Vector{String}`: Point classifications ("min", "max", "saddle")
"""
function load_2d_critical_points_orthant()
    # Get all 2D critical points
    all_critical_2d, all_critical_2d_types = load_2d_critical_points()
    
    # Filter for (+,-) orthant with specific bounds: x ∈ [0,1.1], y ∈ [-1.1,0]
    critical_2d = Vector{Vector{Float64}}()
    critical_2d_types = String[]
    
    for (i, pt) in enumerate(all_critical_2d)
        if pt[1] >= 0 && pt[1] <= 1.1 && pt[2] >= -1.1 && pt[2] <= 0
            push!(critical_2d, pt)
            push!(critical_2d_types, all_critical_2d_types[i])
        end
    end
    
    return critical_2d, critical_2d_types
end

"""
    generate_4d_tensor_products_orthant(critical_2d_pos_neg, critical_2d_types_pos_neg)

Generate 4D tensor product critical points for (+,-,+,-) orthant pattern.

# Arguments
- `critical_2d_pos_neg`: Vector of 2D critical points in (+,-) orthant
- `critical_2d_types_pos_neg`: Classifications of these 2D points

# Returns
- `theoretical_points_4d::Vector{Vector{Float64}}`: 4D critical points in (+,-,+,-) pattern
- `theoretical_values_4d::Vector{Float64}`: Function values at critical points
- `theoretical_types::Vector{String}`: Classifications (e.g., "min+min", "min+saddle")
- `theoretical_4d_types::Vector{String}`: Resulting 4D point type
"""
function generate_4d_tensor_products_orthant(critical_2d_pos_neg, critical_2d_types_pos_neg)
    # For (+,-,+,-) orthant, we take tensor product of (+,-) orthant points
    # This ensures x1 > 0, x2 < 0, x3 > 0, x4 < 0
    return generate_4d_tensor_products(critical_2d_pos_neg, critical_2d_types_pos_neg)
end

"""
    load_theoretical_4d_points_orthant()

Load theoretical 4D critical points for (+,-,+,-) orthant analysis.

# Returns
- `Tuple`: (theoretical_points, theoretical_values, theoretical_types, theoretical_4d_types)
"""
function load_theoretical_4d_points_orthant()
    critical_2d_orthant, critical_2d_types_orthant = load_2d_critical_points_orthant()
    return generate_4d_tensor_products_orthant(critical_2d_orthant, critical_2d_types_orthant)
end

"""
    load_theoretical_points_for_subdomain_orthant(subdomain::Subdomain)

Load theoretical critical points for (+,-,+,-) orthant that fall within the specified subdomain.

# Arguments
- `subdomain`: Subdomain structure defining spatial bounds within the orthant

# Returns
- `Tuple`: (theoretical_points, theoretical_values, theoretical_types) within subdomain
"""
function load_theoretical_points_for_subdomain_orthant(subdomain::Subdomain)
    # Get all 4D points for the orthant
    all_points, all_values, all_types, _ = load_theoretical_4d_points_orthant()
    
    # Filter by subdomain
    filtered_points = Vector{Vector{Float64}}()
    filtered_values = Float64[]
    filtered_types = String[]
    
    for (i, point) in enumerate(all_points)
        if is_point_in_subdomain(point, subdomain, tolerance=0.0)
            push!(filtered_points, point)
            push!(filtered_values, all_values[i])
            push!(filtered_types, all_types[i])
        end
    end
    
    return filtered_points, filtered_values, filtered_types
end

"""
    generate_and_save_all_4d_critical_points(; 
        output_dir="../data",
        save_full=true,
        save_orthant=true)

Generate and save all 4D critical points to CSV files.

# Arguments
- `output_dir`: Directory to save CSV files
- `save_full`: Save all 225 critical points
- `save_orthant`: Save points in (+,-,+,-) orthant
"""
function generate_and_save_all_4d_critical_points(;
    output_dir::String = joinpath(@__DIR__, "../data"),
    save_full::Bool = true,
    save_orthant::Bool = true)
    
    # Load 2D critical points
    critical_2d, critical_2d_types = load_2d_critical_points()
    
    println("📊 2D Critical Points Summary:")
    println("  Total: $(length(critical_2d))")
    println("  Min: $(sum(critical_2d_types .== "min"))")
    println("  Max: $(sum(critical_2d_types .== "max"))")
    println("  Saddle: $(sum(critical_2d_types .== "saddle"))")
    
    # Generate all 4D points
    if save_full
        points_4d, values_4d, types_combined, types_4d = generate_4d_tensor_products(critical_2d, critical_2d_types)
        
        # Create DataFrame
        df_full = DataFrame(
            x1 = [p[1] for p in points_4d],
            x2 = [p[2] for p in points_4d],
            x3 = [p[3] for p in points_4d],
            x4 = [p[4] for p in points_4d],
            function_value = values_4d,
            combined_label = types_combined,
            type_4d = types_4d
        )
        
        # Add columns for individual 2D types
        df_full.label_12 = [split(t, "+")[1] for t in types_combined]
        df_full.label_34 = [split(t, "+")[2] for t in types_combined]
        
        # Save full dataset
        full_path = joinpath(output_dir, "4d_all_critical_points_full.csv")
        CSV.write(full_path, df_full)
        
        println("\n✅ Saved all $(nrow(df_full)) critical points to:")
        println("   $full_path")
        
        # Statistics
        println("\n📊 4D Critical Points (Full Domain):")
        for type in ["min", "max", "saddle"]
            count = sum(df_full.type_4d .== type)
            println("  $type: $count")
        end
    end
    
    # Generate orthant-restricted points
    if save_orthant
        critical_2d_orthant, critical_2d_types_orthant = load_2d_critical_points_orthant()
        points_4d_orthant, values_4d_orthant, types_combined_orthant, types_4d_orthant = 
            generate_4d_tensor_products_orthant(critical_2d_orthant, critical_2d_types_orthant)
        
        # Create DataFrame
        df_orthant = DataFrame(
            x1 = [p[1] for p in points_4d_orthant],
            x2 = [p[2] for p in points_4d_orthant],
            x3 = [p[3] for p in points_4d_orthant],
            x4 = [p[4] for p in points_4d_orthant],
            function_value = values_4d_orthant,
            combined_label = types_combined_orthant,
            type_4d = types_4d_orthant
        )
        
        # Add columns for individual 2D types
        df_orthant.label_12 = [split(t, "+")[1] for t in types_combined_orthant]
        df_orthant.label_34 = [split(t, "+")[2] for t in types_combined_orthant]
        
        # Save orthant dataset
        orthant_path = joinpath(output_dir, "4d_all_critical_points_orthant.csv")
        CSV.write(orthant_path, df_orthant)
        
        println("\n✅ Saved $(nrow(df_orthant)) orthant critical points to:")
        println("   $orthant_path")
        
        # Statistics
        println("\n📊 4D Critical Points in (+,-,+,-) Orthant:")
        for type in ["min", "max", "saddle"]
            count = sum(df_orthant.type_4d .== type)
            println("  $type: $count")
        end
    end
end

end # module