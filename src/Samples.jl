# ======================================================= Functions =======================================================

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
function generate_grid(n::Int, GN::Int)
    ChebyshevNodes = [cos((2i + 1) * π / (2 * GN + 2)) for i in 0:GN]
    cart_cheb = [ChebyshevNodes for _ in 1:n]
    grid = Iterators.product(cart_cheb...)
    return collect(grid)
end