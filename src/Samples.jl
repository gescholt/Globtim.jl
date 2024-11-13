# ======================================================= Functions =======================================================
# using IterTools

"""
    zeta(x::Float64)::Float64

Relative tolerance function for the number of samples.

# Arguments
- `x::Float64`: Input value.

# Returns
- The relative tolerance value.

# Example
```julia
zeta(0.5)
```
"""
function zeta(x::Float64)::Float64
    return x + (1 - x) * log(1 - x)
end

"""
    calculate_samples(m::Int, delta::Float64, alph::Float64)::Int

Generate enough samples to satisfy the error bound with respect to the tensorized Chebyshev polynomial basis.

# Arguments
- `m::Int`: Dimension of the polynomial space.
- `delta::Float64`: Relative error bound.
- `alph::Float64`: Probability, confidence level.

# Returns
- The required number of samples.

# Example
```julia
calculate_samples(10, 0.1, 0.05)
```
"""
function calculate_samples(m::Int, delta::Float64, alph::Float64)::Int
    K = 1
    condition = m^(log(3) / log(2)) / zeta(delta)
    while condition > K / (log(K) + log(6 * alph^(-1)))
        K += m
    end
    return K
end

"""
    generate_grid(n::Int, GN::Int)

Generate enough samples to satisfy the error bound with respect to the tensorized Chebyshev polynomial basis.

# Arguments
- `n::Int`: Dimension.
- `GN::Int`: Number of samples in a coordinate direction.

# Returns
- The required number of samples.

# Example
```julia
calculate_samples(3, 10)
```
"""

function generate_grid(n::Int, GN::Int; basis=:chebyshev)
    if basis == :chebyshev
        # Generate grid using Chebyshev nodes
        ChebyshevNodes = [cos((2i + 1) * π / (2 * GN + 2)) for i in 0:GN]
        cart_cheb = [ChebyshevNodes for _ in 1:n]
        grid = collect(Iterators.product(cart_cheb...))
    elseif basis == :legendre
        # Generate grid using Legendre nodes
        LegendreNodes = [-1 + 2*i/GN for i in 0:GN]
        cart_legendre = [LegendreNodes for _ in 1:n]
        grid = collect(Iterators.product(cart_legendre...))
        
    else
        error("Unsupported basis: $basis")
    end
    matrix_grid = reduce(hcat, map(t -> collect(t), grid))'
    return matrix_grid
end


"""
uniform_grid(n; range_min=-1.0, range_max=1.0, num_points_per_dim=20)

"""
function uniform_grid(n; range_min=-1.0, range_max=1.0, num_points_per_dim=20)
    # Create a range of points for each dimension
    ranges = [range(range_min, stop=range_max, length=num_points_per_dim) for _ in 1:n]

    # Generate the Cartesian product of the ranges to create the grid
    grid_points = collect(IterTools.product(ranges...))
    # Convert the grid points to a matrix where each row is a point
    uniform_grid_matrix = reduce(hcat, map(x -> collect(x), grid_points))'
    # Print the grid points
    uniform_grid_vectors = [collect(row) for row in eachrow(uniform_grid_matrix)]
    return uniform_grid_vectors
end