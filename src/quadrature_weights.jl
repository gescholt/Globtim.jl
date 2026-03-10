"""
    quadrature_weights.jl

Quadrature weight computation for L2-norm approximation on tensorized grids.

This module provides proper quadrature weights for computing L2-norms on
Chebyshev and Legendre grids, ensuring that the approximation error decreases
monotonically with polynomial degree (by containment).
"""

"""
    chebyshev_clenshaw_curtis_weights(GN::Int) -> Vector{Float64}

Compute Clenshaw-Curtis quadrature weights for GN+1 Chebyshev nodes.

# Arguments
- `GN::Int`: Grid parameter (generates GN+1 nodes)

# Returns
- `Vector{Float64}`: Quadrature weights of length GN+1

# Notes
- Nodes are: cos((2i+1)π/(2GN+2)) for i = 0, 1, ..., GN
- Weights are exact for polynomials up to degree GN
- Integrates over [-1, 1] with measure dx (not the Chebyshev weight)
"""
function chebyshev_clenshaw_curtis_weights(GN::Int)
    n = GN + 1  # Number of nodes
    weights = zeros(Float64, n)

    # Clenshaw-Curtis weights for Chebyshev nodes of the first kind
    # Formula from Waldvogel (2006) "Fast Construction of the Fejér and Clenshaw-Curtis Quadrature Rules"

    for j in 0:GN
        w = 0.0
        for k in 0:div(GN, 2)
            if k == 0
                # Special case for k=0
                w += 1.0 / (1 - 4*k^2)
            elseif 2*k <= GN
                # General case
                b_k = (k == div(GN, 2) && GN % 2 == 0) ? 1.0 : 2.0
                w += b_k * cos(2*k*(2*j+1)*π/(2*GN+2)) / (1 - 4*k^2)
            end
        end
        weights[j+1] = 2 * w / (GN + 1)
    end

    return weights
end

"""
    uniform_grid_weights(GN::Int) -> Vector{Float64}

Compute trapezoidal rule weights for GN+1 uniformly spaced points.

# Arguments
- `GN::Int`: Grid parameter (generates GN+1 nodes)

# Returns
- `Vector{Float64}`: Quadrature weights of length GN+1

# Notes
- Nodes are: -1 + 2i/GN for i = 0, 1, ..., GN
- Uses trapezoidal rule: weights are h for interior points, h/2 for endpoints
- h = 2/GN (spacing between nodes)
"""
function uniform_grid_weights(GN::Int)
    n = GN + 1
    h = 2.0 / GN  # Spacing between nodes

    weights = fill(h, n)
    weights[1] = h / 2     # First endpoint
    weights[end] = h / 2   # Last endpoint

    return weights
end

"""
    tensorized_weights(weights_1d::Vector{Float64}, dim::Int) -> Vector{Float64}

Compute tensorized quadrature weights for multi-dimensional grids.

# Arguments
- `weights_1d::Vector{Float64}`: 1D quadrature weights
- `dim::Int`: Number of dimensions

# Returns
- `Vector{Float64}`: Tensorized weights as a flat vector

# Notes
- For tensorized grids, the weight at point (i₁, i₂, ..., iₙ) is:
  w[i₁, i₂, ..., iₙ] = w_1d[i₁] * w_1d[i₂] * ... * w_1d[iₙ]
- Returns weights in the same order as the flattened grid
- Total number of weights: (length(weights_1d))^dim
"""
function tensorized_weights(weights_1d::Vector{Float64}, dim::Int)
    n_1d = length(weights_1d)
    n_total = n_1d^dim

    weights = zeros(Float64, n_total)

    # Iterate over all multi-indices
    idx = 1
    for multi_idx in Iterators.product(fill(1:n_1d, dim)...)
        # Compute product weight
        w = 1.0
        for i in multi_idx
            w *= weights_1d[i]
        end
        weights[idx] = w
        idx += 1
    end

    return weights
end

"""
    compute_quadrature_weights(basis::Symbol, GN::Int, dim::Int) -> Vector{Float64}

Compute appropriate quadrature weights for the given basis and grid configuration.

# Arguments
- `basis::Symbol`: Basis type (`:chebyshev` or `:legendre`)
- `GN::Int`: Grid parameter (generates GN+1 nodes per dimension)
- `dim::Int`: Number of dimensions

# Returns
- `Vector{Float64}`: Quadrature weights for the tensorized grid

# Notes
- For Chebyshev: Uses Clenshaw-Curtis weights
- For Legendre (uniform grid): Uses trapezoidal rule weights
- Automatically tensorizes weights for multi-dimensional grids
"""
function compute_quadrature_weights(basis::Symbol, GN::Int, dim::Int)
    # Compute 1D weights based on basis
    weights_1d = if basis == :chebyshev
        chebyshev_clenshaw_curtis_weights(GN)
    elseif basis == :legendre
        uniform_grid_weights(GN)
    else
        error("Unsupported basis: $basis. Use :chebyshev or :legendre")
    end

    # Tensorize for multi-dimensional grids
    return tensorized_weights(weights_1d, dim)
end
