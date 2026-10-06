# gradient_fit.jl
# Gradient information in the approximation step.
#
# The critical points globtim reports are zeros of ∇p, not of p − f, so the quantity that
# decides whether they are the critical points of f is ‖∇f − ∇p‖, which the value-only
# relative L2 error does not control (two fits with the same rel-L2 can place ∇p = 0 far
# apart — the Chebyshev-vs-Legendre LV4D comparison: Legendre had the better L2 and the
# much worse minimizer). Two tools:
#
#   1. Gradient-enhanced least squares (`gradient_weight > 0` in `Constructor` /
#      `MainGenerate`): stack the derivative Vandermonde rows under the value rows,
#
#          [ V        ]       [ f        ]
#          [ w·∂₁V    ]  c ≈  [ w·∂₁f    ]        (derivatives in box coordinates ẑ ∈ [-1,1]ⁿ)
#          [   ⋮      ]       [   ⋮      ]
#          [ w·∂ₙV    ]       [ w·∂ₙf    ]
#
#      a discrete H¹ fit. One gradient per sample point: ForwardDiff for AD-compatible
#      objectives (the Dynamic_objectives convention), central differences otherwise.
#
#   2. The gradient check `relative_gradient_error`: ‖∇f − ∇p‖ / ‖∇f‖ over the sample
#      points, in box coordinates. Used by `adaptive_refine(...; gradient_tolerance)` as an
#      additional per-leaf convergence condition.
#
# Box coordinates: every derivative here is ∂/∂ẑ with x = center + scale .* ẑ, so the
# measure weights each axis by its half-width — the same frame the basis lives in, and
# invariant under a uniform rescaling of the physical units of one coordinate.

# ── 1-D basis values and derivatives ──────────────────────────────────────────

# Raw (unnormalized) T_d or P_d and their derivatives at t, d = 0..dmax.
function _raw_basis_and_derivative(basis::Symbol, t::Real, dmax::Int)
    v = zeros(Float64, dmax + 1)
    dv = zeros(Float64, dmax + 1)
    v[1] = 1.0
    dmax >= 1 || return v, dv
    v[2] = t
    dv[2] = 1.0
    if basis == :chebyshev
        # T_d = 2t T_{d-1} − T_{d-2};  T_d' = 2 T_{d-1} + 2t T_{d-1}' − T_{d-2}'
        for d in 2:dmax
            v[d+1] = 2t * v[d] - v[d-1]
            dv[d+1] = 2 * v[d] + 2t * dv[d] - dv[d-1]
        end
    elseif basis == :legendre
        # d P_d = (2d−1) t P_{d-1} − (d−1) P_{d-2};  differentiate the same recurrence
        for d in 2:dmax
            v[d+1] = ((2d - 1) * t * v[d] - (d - 1) * v[d-1]) / d
            dv[d+1] = ((2d - 1) * (v[d] + t * dv[d]) - (d - 1) * dv[d-1]) / d
        end
    else
        throw(ArgumentError("basis must be :chebyshev or :legendre, got :$basis"))
    end
    return v, dv
end

# Normalization constants c_d with φ_d = c_d · (raw T_d or P_d), read off the 1-D
# Vandermonde the fit itself uses (T_d(1) = P_d(1) = 1, so c_d = φ_d(1)). This keeps the
# derivative rows consistent with whatever normalization lambda_vandermonde applies.
function _basis_normalization(basis::Symbol, dmax::Int)
    L1 = SupportGen(1, (:one_d_for_all, dmax))
    V1 = lambda_vandermonde(L1, reshape([1.0], 1, 1), basis = basis)
    c = zeros(Float64, dmax + 1)
    for j in 1:size(L1.data, 1)
        c[L1.data[j, 1]+1] = V1[1, j]
    end
    return c
end

"""
    derivative_vandermonde(Lambda, S; basis = :chebyshev, reference = nothing)
        -> (V, D::Vector{Matrix{Float64}})

Value and partial-derivative Vandermonde matrices of the tensor basis `Lambda`
(`SupportGen` output, rows = multi-indices) at the points `S` (one point per row, in
[-1,1]ⁿ): `V[i,j] = φ_α(j)(sᵢ)`, `D[k][i,j] = ∂φ_α(j)/∂ẑ_k (sᵢ)`.

When `reference` is given (the `lambda_vandermonde` matrix of the same `Lambda`, `S`,
`basis`), `V` is checked against it and a mismatch is an error: the derivative rows are
only meaningful if they differentiate exactly the basis the value rows use.
"""
function derivative_vandermonde(
    Lambda::NamedTuple,
    S::AbstractMatrix{<:Real};
    basis::Symbol = :chebyshev,
    reference::Union{Nothing,AbstractMatrix} = nothing,
)
    A = Lambda.data
    m, n = size(A)
    N = size(S, 1)
    size(S, 2) == n ||
        throw(DimensionMismatch("points have $(size(S, 2)) coordinates, support has $n"))
    dmax = maximum(A)
    c = _basis_normalization(basis, dmax)
    # per point, per coordinate: normalized values and derivatives of φ_0..φ_dmax
    phi = Array{Float64}(undef, N, n, dmax + 1)
    dphi = Array{Float64}(undef, N, n, dmax + 1)
    for i in 1:N, k in 1:n
        v, dv = _raw_basis_and_derivative(basis, Float64(S[i, k]), dmax)
        @views phi[i, k, :] .= c .* v
        @views dphi[i, k, :] .= c .* dv
    end
    V = ones(Float64, N, m)
    D = [ones(Float64, N, m) for _ in 1:n]
    for j in 1:m, i in 1:N
        for l in 1:n
            pl = phi[i, l, A[j, l]+1]
            V[i, j] *= pl
            for k in 1:n
                D[k][i, j] *= (k == l ? dphi[i, l, A[j, l]+1] : pl)
            end
        end
    end
    if reference !== nothing
        size(reference) == size(V) || throw(
            DimensionMismatch(
                "reference Vandermonde is $(size(reference)), expected $(size(V))",
            ),
        )
        err = maximum(abs, V .- reference)
        scale = max(1.0, maximum(abs, reference))
        err <= 1e-8 * scale || error(
            "derivative_vandermonde: rebuilt value Vandermonde differs from lambda_vandermonde " *
            "by $err (basis = :$basis) — the basis normalization is not the one assumed; " *
            "gradient-enhanced fitting would differentiate the wrong functions",
        )
    end
    return V, D
end

# ── objective gradients in box coordinates ───────────────────────────────────

# x = center + scale .* ẑ as a plain (Dual-friendly) vector
_box_point(ẑ, scale::Number, center) = center .+ scale .* ẑ
_box_point(ẑ, scale::AbstractVector, center) = center .+ scale .* ẑ

function _call_objective(f, x::AbstractVector)
    return length(x) == 1 ? f(x[1]) : f(x)
end

"""
    objective_gradients_box(f, S, scale_factor, center; method = :forwarddiff, h = 1e-6)
        -> Matrix{Float64}

`G[i, k] = ∂/∂ẑ_k f(center + scale_factor .* ẑ)` at the box point `ẑ = S[i, :]`, i.e. the
physical gradient times the half-width of axis k. `method = :forwarddiff` needs an
AD-compatible objective; `:finitediff` uses central differences of step `h` in box units.
A non-finite gradient is an error (no silent fallback).
"""
function objective_gradients_box(
    f,
    S::AbstractMatrix{<:Real},
    scale_factor,
    center::AbstractVector;
    method::Symbol = :forwarddiff,
    h::Real = 1e-6,
)
    method in (:forwarddiff, :finitediff) || throw(
        ArgumentError("gradient method must be :forwarddiff or :finitediff, got :$method"),
    )
    N, n = size(S)
    c = Vector{Float64}(center)
    g(ẑ) = _call_objective(f, _box_point(ẑ, scale_factor, c))
    G = Matrix{Float64}(undef, N, n)
    for i in 1:N
        z = Vector{Float64}(S[i, :])
        if method == :forwarddiff
            G[i, :] .= ForwardDiff.gradient(g, z)
        else
            for k in 1:n
                zp = copy(z)
                zm = copy(z)
                zp[k] += h
                zm[k] -= h
                G[i, k] = (g(zp) - g(zm)) / (2h)
            end
        end
        all(isfinite, view(G, i, :)) || error(
            "objective gradient is not finite at box point $(z) (method = :$method); " *
            "gradient-enhanced fitting needs ∇f at every sample point",
        )
    end
    return G
end

"""
    gradient_enhanced_coefficients(V, F, D, G, w) -> Vector{Float64}

Least-squares coefficients of the stacked system `[V; w·D₁; …; w·Dₙ] c ≈ [F; w·G[:,1]; …]`
(pivoted QR through `\\`, like the value-only fit).
"""
function gradient_enhanced_coefficients(
    V::AbstractMatrix,
    F::AbstractVector,
    D::AbstractVector{<:AbstractMatrix},
    G::AbstractMatrix,
    w::Real,
)
    n = length(D)
    size(G, 2) == n || throw(DimensionMismatch("G has $(size(G, 2)) columns, expected $n"))
    A = vcat(V, (w .* D[k] for k in 1:n)...)
    b = vcat(F, (w .* G[:, k] for k in 1:n)...)
    return A \ b
end

# ── the gradient check ────────────────────────────────────────────────────────

# ∇ of the surrogate in box coordinates at box point ẑ (pol.center / pol.scale_factor
# define the same affine map the fit used, also for a rotated leaf: the leaf polynomial
# lives in its own normalized frame).
function _surrogate_gradient_box(pol::ApproxPoly, ẑ::AbstractVector)
    return ForwardDiff.gradient(
        z -> evaluate(pol, pol.center .+ pol.scale_factor .* z),
        Vector{Float64}(ẑ),
    )
end

"""
    relative_gradient_error(pol::ApproxPoly, f; points = nothing, weights = nothing,
                            method = :forwarddiff, objective_point = nothing) -> Float64

Gradient check of a surrogate: `sqrt(Σ wᵢ‖∇g(ẑᵢ) − ∇p̂(ẑᵢ)‖²) / sqrt(Σ wᵢ‖∇g(ẑᵢ)‖²)` with
`g(ẑ) = f(x(ẑ))` and `p̂(ẑ) = p(x(ẑ))`, derivatives in box coordinates.

- `points`: box points, one per row; default the fit's own grid (`pol.grid`, rows =
  points, as `Constructor` stores it), weighted by the tensor quadrature weights when the
  grid is a full tensor grid and uniformly otherwise.
- `n_points`: when > 0 and smaller than the grid, check only `n_points` grid rows chosen
  by a fixed stride (deterministic, spread over the grid), uniformly weighted — the check
  costs one gradient of f per point, which matters for ODE objectives.
- `objective_point`: the map ẑ ↦ x used for f, default `pol.center .+ pol.scale_factor .* ẑ`.
  Pass the leaf's own map for a rotated subdivision leaf.

Returns `NaN` when ∇f vanishes at every point (relative error undefined).
"""
function relative_gradient_error(
    pol::ApproxPoly,
    f;
    points::Union{Nothing,AbstractMatrix} = nothing,
    weights::Union{Nothing,AbstractVector} = nothing,
    method::Symbol = :forwarddiff,
    objective_point::Union{Nothing,Function} = nothing,
    h::Real = 1e-6,
    n_points::Int = 0,
)
    S = points === nothing ? pol.grid : points
    subset = points === nothing && 0 < n_points < size(S, 1)
    if subset
        S = S[_strided_rows(size(S, 1), n_points), :]
    end
    N, n = size(S)
    w = if weights !== nothing
        length(weights) == N ||
            throw(DimensionMismatch("$(length(weights)) weights for $N points"))
        weights
    elseif points === nothing && !subset && (round(Int, N^(1 / n)))^n == N
        compute_quadrature_weights(pol.basis, round(Int, N^(1 / n)) - 1, n)
    else
        fill(1.0 / N, N)
    end
    xmap =
        objective_point === nothing ? (z -> pol.center .+ pol.scale_factor .* z) :
        objective_point
    g(z) = _call_objective(f, xmap(z))
    num = 0.0
    den = 0.0
    for i in 1:N
        z = Vector{Float64}(S[i, :])
        gf = if method == :forwarddiff
            ForwardDiff.gradient(g, z)
        elseif method == :finitediff
            [
                begin
                    zp = copy(z)
                    zm = copy(z)
                    zp[k] += h
                    zm[k] -= h
                    (g(zp) - g(zm)) / (2h)
                end for k in 1:n
            ]
        else
            throw(
                ArgumentError(
                    "gradient method must be :forwarddiff or :finitediff, got :$method",
                ),
            )
        end
        all(isfinite, gf) || error("objective gradient is not finite at box point $z")
        gp = _surrogate_gradient_box(pol, z)
        num += w[i] * sum(abs2, gf .- gp)
        den += w[i] * sum(abs2, gf)
    end
    return den > 0 ? sqrt(num / den) : NaN
end

# `k` row indices spread evenly over 1:N (deterministic; first and last row included).
function _strided_rows(N::Int, k::Int)
    k >= N && return collect(1:N)
    k == 1 && return [cld(N, 2)]
    return unique(round.(Int, range(1, N; length = k)))
end
