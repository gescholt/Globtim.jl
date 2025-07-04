# SubdomainManagement.jl - Subdomain structures and generation for spatial analysis

module SubdomainManagement

export Subdomain, generate_16_subdivisions, is_point_in_subdomain

"""
    Subdomain

Structure representing a single subdomain of the 4D hypercube.

# Fields
- `label::String`: Binary label (e.g., "0000", "0001", ..., "1111")
- `center::Vector{Float64}`: Center point of subdomain
- `range::Float64`: Half-width of subdomain
- `bounds::Vector{Tuple{Float64,Float64}}`: Domain bounds [(x1_min,x1_max), ...]
"""
struct Subdomain
    label::String
    center::Vector{Float64}
    range::Float64
    bounds::Vector{Tuple{Float64,Float64}}
end

"""
    generate_16_subdivisions()

Generate all 16 subdomains by dividing [-1,1]^4 at x=0 in each dimension.

# Returns
- `Vector{Subdomain}`: Array of 16 subdomain structures with labels and centers

# Description
Creates binary subdivision of 4D hypercube where each dimension is split at 0.
Labels use binary encoding: "0000" = all negative quadrants, "1111" = all positive.
"""
function generate_16_subdivisions()
    subdivisions = Subdomain[]
    
    for i in 0:15
        # Convert to 4-bit binary representation
        binary_repr = string(i, base=2, pad=4)
        
        # Calculate center based on binary representation
        center = Float64[]
        bounds = Tuple{Float64,Float64}[]
        
        for bit_char in binary_repr
            if bit_char == '0'
                # Negative subdomain: [-1, 0]
                push!(center, -0.5)
                push!(bounds, (-1.0, 0.0))
            else
                # Positive subdomain: [0, 1]  
                push!(center, 0.5)
                push!(bounds, (0.0, 1.0))
            end
        end
        
        subdomain = Subdomain(binary_repr, center, 0.5, bounds)
        push!(subdivisions, subdomain)
    end
    
    return subdivisions
end

"""
    is_point_in_subdomain(point::Vector{Float64}, subdomain::Subdomain; tolerance::Float64=0.1)

Check if a point falls within the specified subdomain bounds.

# Arguments
- `point`: 4D point coordinates
- `subdomain`: Subdomain structure defining spatial bounds
- `tolerance`: Boundary tolerance for numerical safety

# Returns
- `Bool`: true if point is within subdomain bounds (including tolerance)
"""
function is_point_in_subdomain(point::Vector{Float64}, subdomain::Subdomain; tolerance::Float64=0.1)
    for (dim, coord) in enumerate(point)
        lower, upper = subdomain.bounds[dim]
        if coord < lower - tolerance || coord > upper + tolerance
            return false
        end
    end
    return true
end

end # module