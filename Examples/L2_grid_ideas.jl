using PolyChaos

function compute_L2_norm_tensor(f, S::Vector{Int}, poly_type = :chebyshev)
    n = length(S)  # number of dimensions

    # Create univariate orthogonal polynomials for each dimension
    ops = []
    for i = 1:n
        if poly_type == :chebyshev
            # Chebyshev polynomials on [-1,1]
            push!(ops, Uniform_11OrthoPoly(S[i]))  # degree = nodes
        elseif poly_type == :legendre
            # Legendre polynomials on [-1,1]
            push!(ops, LegendreOrthoPoly(S[i]))
        elseif poly_type == :uniform
            # For uniform measure on [-1,1]
            push!(ops, Uniform_11OrthoPoly(S[i]))
        end
    end

    # Extract nodes and weights for each dimension
    nodes_1d = [op.quad.nodes for op in ops]
    weights_1d = [op.quad.weights for op in ops]

    # Compute tensor product quadrature
    L2_norm_squared = 0.0

    # Iterate over all combinations (tensor product)
    for idx in Iterators.product([1:S[i] for i = 1:n]...)
        # Get the n-dimensional point
        x = [nodes_1d[i][idx[i]] for i = 1:n]

        # Get the n-dimensional weight (product of 1D weights)
        w = prod(weights_1d[i][idx[i]] for i = 1:n)

        # Evaluate function and accumulate
        L2_norm_squared += w * abs2(f(x))
    end

    return sqrt(L2_norm_squared)
end

# Example usage:
# 3D function on [-1,1]^3
# f(x) = exp(-(x[1]^2 + x[2]^2 + x[3]^2))
#
# # Different number of samples per dimension
# S = [10, 15, 8]  # 10 points in x, 15 in y, 8 in z
#
# L2_norm = compute_L2_norm_tensor(f, S, :chebyshev)
# println("L2 norm estimate: ", L2_norm)

# --- 

function compute_L2_norm_mixed(f, specs)
    # specs is a vector of (n_points, poly_type) tuples
    n = length(specs)

    ops = []
    for (s, ptype) in specs
        if ptype == :chebyshev
            push!(ops, Uniform_11OrthoPoly(s))
        elseif ptype == :legendre
            push!(ops, LegendreOrthoPoly(s))
        elseif ptype == :jacobi
            # Can add parameters for Jacobi
            push!(ops, JacobiOrthoPoly(s - 1, 0.5, 0.5))  # α=β=0.5
        end
    end

    # Rest is the same...
    nodes_1d = [op.quad.nodes for op in ops]
    weights_1d = [op.quad.weights for op in ops]

    L2_norm_squared = 0.0
    S = [s for (s, _) in specs]

    for idx in Iterators.product([1:S[i] for i = 1:n]...)
        x = [nodes_1d[i][idx[i]] for i = 1:n]
        w = prod(weights_1d[i][idx[i]] for i = 1:n)
        L2_norm_squared += w * abs2(f(x))
    end

    return sqrt(L2_norm_squared)
end

# Example: Chebyshev in x, Legendre in y, Jacobi in z
# specs = [(10, :chebyshev), (15, :legendre), (8, :jacobi)]
# L2_norm = compute_L2_norm_mixed(f, specs)

# --- 

using PolyChaos

function setup_tensor_quadrature(S::Vector{Int}, poly_types = nothing)
    n = length(S)

    if poly_types === nothing
        # Default to Chebyshev
        ops = [Uniform_11OrthoPoly(S[i] - 1) for i = 1:n]
    else
        ops = [construct_poly(S[i] - 1, poly_types[i]) for i = 1:n]
    end

    # Create multivariate orthogonal polynomial
    # (using minimum degree for the multi-index construction)
    mop = MultiOrthoPoly(ops, minimum(S))

    return mop, ops
end

# Helper to construct different polynomial types
function construct_poly(deg, ptype)
    if ptype == :chebyshev
        return Uniform_11OrthoPoly(deg)
    elseif ptype == :legendre
        return LegendreOrthoPoly(deg)
        # Add more as needed
    end
end
