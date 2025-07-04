# TheoreticalPoints.jl - Loading and classification of theoretical critical points

module TheoreticalPoints

using DataFrames, CSV, LinearAlgebra
using ForwardDiff
using Globtim
using Common4DDeuflhard: deuflhard_4d_composite
using SubdomainManagement: Subdomain, is_point_in_subdomain

export load_2d_critical_points, generate_4d_tensor_products
export load_theoretical_4d_points, load_theoretical_points_for_subdomain
export load_2d_critical_points_orthant, generate_4d_tensor_products_orthant
export load_theoretical_4d_points_orthant, load_theoretical_points_for_subdomain_orthant

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
"""
function generate_4d_tensor_products(critical_2d, critical_2d_types)
    theoretical_points_4d = Vector{Vector{Float64}}()
    theoretical_values_4d = Float64[]
    theoretical_types = String[]
    
    for (i, pt1) in enumerate(critical_2d)
        for (j, pt2) in enumerate(critical_2d)
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            value_4d = deuflhard_4d_composite(point_4d)
            type_4d = "$(critical_2d_types[i])+$(critical_2d_types[j])"
            
            push!(theoretical_points_4d, point_4d)
            push!(theoretical_values_4d, value_4d)
            push!(theoretical_types, type_4d)
        end
    end
    
    return theoretical_points_4d, theoretical_values_4d, theoretical_types
end

"""
    load_theoretical_4d_points()

Load all theoretical 4D critical points for full domain analysis.

# Returns
- `Tuple`: (theoretical_points, theoretical_values, theoretical_types)
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
    all_points, all_values, all_types = load_theoretical_4d_points()
    
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

Load and classify 2D Deuflhard critical points that lie in the (+,-) orthant.

# Returns
- `critical_2d::Vector{Vector{Float64}}`: 2D critical point coordinates in (+,-) orthant
- `critical_2d_types::Vector{String}`: Point classifications ("min", "max", "saddle")
"""
function load_2d_critical_points_orthant()
    # Get all 2D critical points
    all_critical_2d, all_critical_2d_types = load_2d_critical_points()
    
    # Filter for (+,-) orthant: x > 0, y < 0
    critical_2d = Vector{Vector{Float64}}()
    critical_2d_types = String[]
    
    for (i, pt) in enumerate(all_critical_2d)
        if pt[1] > 0 && pt[2] < 0
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
- `Tuple`: (theoretical_points, theoretical_values, theoretical_types)
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
    all_points, all_values, all_types = load_theoretical_4d_points_orthant()
    
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

end # module