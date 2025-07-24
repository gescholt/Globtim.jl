# anisotropic_grids.jl
# Support for anisotropic grids with different number of points per dimension

using StaticArrays
using IterTools

"""
    generate_anisotropic_grid(grid_sizes::Vector{Int}; basis=:chebyshev)

Generate an anisotropic grid with different number of points in each dimension.

# Arguments
- `grid_sizes::Vector{Int}`: Number of points in each dimension (will generate grid_sizes[i] + 1 points in dimension i)
- `basis::Symbol=:chebyshev`: Choice of basis for node generation (:chebyshev, :legendre, or :uniform)

# Returns
- Array of SVectors containing the grid points

# Examples
```julia
# 2D grid with 5 points in x and 10 points in y
grid = generate_anisotropic_grid([4, 9], basis=:chebyshev)

# 3D grid with different resolution per axis
grid = generate_anisotropic_grid([10, 5, 3], basis=:legendre)
```
"""
function generate_anisotropic_grid(grid_sizes::Vector{Int}; basis::Symbol=:chebyshev)
    n_dims = length(grid_sizes)
    
    # Generate nodes for each dimension
    nodes_per_dim = Vector{Vector{Float64}}()
    
    for GN in grid_sizes
        nodes = if basis == :chebyshev
            [cos((2i + 1) * π / (2 * GN + 2)) for i = 0:GN]
        elseif basis == :legendre
            [-1 + 2 * i / GN for i = 0:GN]
        elseif basis == :uniform
            # True uniform spacing including endpoints
            range(-1, 1, length=GN+1) |> collect
        else
            error("Unsupported basis: $basis. Use :chebyshev, :legendre, or :uniform")
        end
        push!(nodes_per_dim, nodes)
    end
    
    # Create the grid using tensor product
    grid_shape = tuple((GN + 1 for GN in grid_sizes)...)
    
    # Use array comprehension with direct SVector construction
    grid = [
        SVector{n_dims,Float64}(ntuple(d -> nodes_per_dim[d][idx[d]], n_dims)) for
        idx in Iterators.product((1:length(nodes) for nodes in nodes_per_dim)...)
    ]
    
    # Reshape to match the grid structure
    reshape(grid, grid_shape)
end

"""
    generate_grid(grid_spec::Union{Int,Vector{Int}}, n_dims::Union{Int,Nothing}=nothing; basis=:chebyshev)

Unified interface for generating isotropic or anisotropic grids.

# Arguments
- `grid_spec`: Either:
  - `Int`: Number of points per dimension (isotropic grid)
  - `Vector{Int}`: Number of points for each dimension (anisotropic grid)
- `n_dims`: Number of dimensions (only needed for isotropic case)
- `basis`: Node type (:chebyshev, :legendre, or :uniform)

# Examples
```julia
# Isotropic 3D grid with 10 points per dimension
grid = generate_grid(9, 3)

# Anisotropic 3D grid
grid = generate_grid([9, 5, 3])
```
"""
function generate_grid(grid_spec::Vector{Int}; basis::Symbol=:chebyshev)
    generate_anisotropic_grid(grid_spec; basis=basis)
end

# Extension of generate_grid for anisotropic case
# The original generate_grid(n::Int, GN::Int; basis) is in Samples.jl

"""
    get_grid_dimensions(grid::Array{<:SVector})

Extract the number of points in each dimension from a grid.

# Returns
- Vector{Int}: Number of points in each dimension
"""
function get_grid_dimensions(grid::Array{<:SVector})
    collect(size(grid))
end

"""
    is_anisotropic(grid::Array{<:SVector})

Check if a grid is anisotropic (different number of points per dimension).

# Returns
- Bool: true if anisotropic, false if isotropic
"""
function is_anisotropic(grid::Array{<:SVector})
    dims = size(grid)
    return !all(d -> d == dims[1], dims)
end

# Export functions
export generate_anisotropic_grid, get_grid_dimensions, is_anisotropic