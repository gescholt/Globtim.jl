# Common4DDeuflhard.jl - Core function and constants for 4D Deuflhard analysis

module Common4DDeuflhard

using Globtim

export deuflhard_4d_composite, get_actual_degree
export ORIGINAL_DOMAIN_RANGE, SUBDOMAIN_RANGE, DISTANCE_TOLERANCE, GN_FIXED

# Domain and approximation constants
const ORIGINAL_DOMAIN_RANGE = 1.0    # Original [-1,1]^4 domain
const SUBDOMAIN_RANGE = 0.5           # Each subdomain has range 0.5
const DISTANCE_TOLERANCE = 0.05       # Success threshold for critical point recovery
const GN_FIXED = 10                   # Fixed sample count parameter as requested

"""
    deuflhard_4d_composite(x::AbstractVector)::Float64

4D Deuflhard composite function: f(x₁,x₂,x₃,x₄) = Deuflhard([x₁,x₂]) + Deuflhard([x₃,x₄])
Tensor product construction allows known critical point locations.
"""
function deuflhard_4d_composite(x::AbstractVector)::Float64
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

"""
    get_actual_degree(pol)

Extract the actual polynomial degree from Constructor output.
Handles both Tuple and Int degree types.
"""
function get_actual_degree(pol)
    return pol.degree isa Tuple ? pol.degree[2] : pol.degree
end

end # module