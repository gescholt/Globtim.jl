# chebyshev_eval.jl — SKELETON (not included by Globtim.jl yet)
#
# Basis-native evaluation of a tensor-Chebyshev surrogate and its first and second
# derivatives by Clenshaw's recurrence, generic in the scalar type so the same code
# serves Float64, ComplexF64, DoubleFloats' ComplexDF64 (HC.jl mixed precision),
# IntervalArithmetic intervals (certification) and truncated-Taylor scalars (HC.jl
# predictor). Plan: docs/research/plans/CHEBYSHEV_NATIVE_HC_PLAN.md §3.
#
# No dependency beyond Base/LinearAlgebra. The HC.jl AbstractSystem built on these
# kernels lives in ext/chebyshev_gradient_system.jl.
#
# Conventions
# - Plain T_n basis, p(x) = Σ_α c_α Π_k T_{α_k}(x_k), on the box [-1,1]^n — the basis
#   `ApproxPoly.coeffs` is stored in for `basis = :chebyshev` (Structures.jl,
#   `_stored_normalized`). Legendre fits are out of scope for Phase 1 (they would need
#   the Legendre three-term Clenshaw and the orthonormal scaling).
# - Coefficient tensor C::Array{T,n} with C[i_1,…,i_n] = c_{(i_1-1,…,i_n-1)}; a
#   total-degree support is zero-padded onto the per-axis index box.

"""
    chebyshev_coefficient_tensor(pol::ApproxPoly) -> Array{Float64,n}

Scatter `pol.coeffs` onto the per-axis index box `(d_1+1) × … × (d_n+1)` given by the
column maxima of `pol.support` (zero-padded off the support). Errors for
`pol.basis != :chebyshev` or `pol.normalized == true` (that is a different basis).
"""
function chebyshev_coefficient_tensor(pol)
    error("not implemented: chebyshev_coefficient_tensor (CHEBYSHEV_NATIVE_HC_PLAN.md §3)")
end

"""
    clenshaw(c::AbstractVector, x) -> scalar

`Σ_{k=0}^{m} c[k+1] T_k(x)` by Clenshaw's recurrence [clenshaw1955note]:

    b_{m+1} = b_{m+2} = 0
    b_k     = c_k + 2x·b_{k+1} − b_{k+2},   k = m, …, 1
    result  = c_0 + x·b_1 − b_2

Backward stable with error `≲ 2m·u·Σ|c_k|` [barrio2002rounding]. `x` may be any
scalar supporting `+, *` with `eltype(c)` promotion: Float64, Complex, DoubleFloat,
Interval, TaylorVector element. Never converts `x` to Float64.
"""
function clenshaw(c::AbstractVector, x)
    error("not implemented: clenshaw")
end

"""
    chebyshev_derivative_coeffs(c::AbstractVector) -> Vector

Coefficients `c'` of `d/dx Σ c_k T_k(x)` [mason2003chebyshev, §2.4.5]:

    c'_{m} = c'_{m+1} = 0
    c'_{k-1} = c'_{k+1} + 2k·c_k,   k = m, …, 1
    c'_0 /= 2

Length `max(length(c) − 1, 1)`. Applied along one axis of a tensor by
[`differentiate_axis`](@ref). Used at construction time only, so the gradient and
Hessian are themselves Chebyshev series and the tracker loop is pure Clenshaw.
"""
function chebyshev_derivative_coeffs(c::AbstractVector)
    error("not implemented: chebyshev_derivative_coeffs")
end

"""
    differentiate_axis(C::AbstractArray{T,n}, k::Int) -> Array{T,n}

Apply [`chebyshev_derivative_coeffs`](@ref) to every fiber of `C` along axis `k`.
Result has size `size(C)` with axis `k` shortened by one (or kept at 1).
"""
function differentiate_axis(C::AbstractArray, k::Int)
    error("not implemented: differentiate_axis")
end

"""
    tensor_clenshaw(C::AbstractArray{T,n}, x::AbstractVector) -> scalar

`Σ_i C[i] Π_k T_{i_k − 1}(x_k)` by contracting the last axis with
[`clenshaw`](@ref) in `x_n`, then the next, …, leaving a scalar. Cost
`O(Π_k (d_k+1))` multiply-adds and no temporaries beyond one slice per level
(implementation: recursive on `n` with `selectdim`, or an explicit workspace
`Vector` of length `Π_{k<n}(d_k+1)` reused across calls). Element type is the
promotion of `T` and `eltype(x)`.
"""
function tensor_clenshaw(C::AbstractArray, x::AbstractVector)
    error("not implemented: tensor_clenshaw")
end

"""
    ChebyshevGradientKernel(C::AbstractArray{T,n})

Precomputed data for evaluating `p`, `∇p`, `∇²p` of the surrogate with coefficient
tensor `C`:

- `C`            — the value tensor;
- `G[k]`         — `differentiate_axis(C, k)`, `k = 1…n` (first derivatives);
- second derivatives are **not stored** (Phase 1 mitigation (ii) of the plan): the
  Hessian entry `∂_j ∂_k p` is evaluated by one more `clenshaw`-level differentiation
  of the `G[k]` contraction in `x_j` during `evaluate_and_jacobian!`, at `n×` the
  cost of a gradient evaluation and zero extra storage. Switch to stored
  `H[j,k]` tensors when `n ≤ 3` and memory allows (a constructor flag).

Memory: `(1 + n)·Π(d_k+1)` scalars.
"""
struct ChebyshevGradientKernel{T,N,A<:AbstractArray{T,N}}
    C::A
    G::Vector{A}
    function ChebyshevGradientKernel(C::AbstractArray{T,N}) where {T,N}
        error("not implemented: ChebyshevGradientKernel constructor")
    end
end

"""
    evaluate!(u, K::ChebyshevGradientKernel, x) -> u

`u[k] = ∂_k p(x)`, `k = 1…n`, by `tensor_clenshaw(K.G[k], x)`. `u` and `x` may be
complex, interval or Taylor-valued; `eltype(u)` must hold the promotion.
"""
function evaluate!(u, K::ChebyshevGradientKernel, x)
    error("not implemented: evaluate!(ChebyshevGradientKernel)")
end

"""
    evaluate_and_jacobian!(u, U, K::ChebyshevGradientKernel, x) -> (u, U)

`u = ∇p(x)`, `U = ∇²p(x)` (symmetric; both triangles filled). The Jacobian of the
gradient system *is* the Hessian of the surrogate, so `κ(U)` at a solution is the
conditioning of the critical point itself — the quantity the plan's benchmark B2
records as `cond_jacobian_median`.
"""
function evaluate_and_jacobian!(u, U, K::ChebyshevGradientKernel, x)
    error("not implemented: evaluate_and_jacobian!(ChebyshevGradientKernel)")
end

"""
    value(K::ChebyshevGradientKernel, x) -> scalar

`p(x)` itself, `tensor_clenshaw(K.C, x)`. Not needed by the tracker; used by tests
(agreement with `Globtim.evaluate(pol, x)` on the fit grid to `1e-13`) and by the
rational/lifted systems that need `p` alongside `∇p`.
"""
function value(K::ChebyshevGradientKernel, x)
    error("not implemented: value(ChebyshevGradientKernel)")
end
