# chebyshev_eval.jl — basis-native evaluation of a Chebyshev surrogate's gradient and
# Hessian on its sparse support (CHEBYSHEV_NATIVE_HC_PLAN.md §3, Phase 1).
#
# The HC path solves ∇p = 0 after converting the fitted Chebyshev series to monomials,
# and that conversion loses (1+√2)^d digits of coefficient accuracy; the recorded
# symptom is recall that is not monotone in degree (d = 16 fits better than d = 12 and
# returns fewer verified critical points, SEEDING_FINDINGS.md:586-595). These kernels
# evaluate ∇p and ∇²p directly from the stored coefficients, so no monomial polynomial
# is ever formed. The HomotopyContinuation `AbstractSystem` built on them lives in
# ext/chebyshev_gradient_system.jl.
#
# Representation. `ApproxPoly` with `basis = :chebyshev` stores PLAIN T_n coefficients
# (`normalized == false`, Structures.jl `_stored_normalized`) on a support matrix
# (rows = multi-indices α, one per coefficient). The kernel keeps that sparse support
# and evaluates
#
#     ∂_k p(x) = Σ_α c_α T'_{α_k}(x_k) Π_{i≠k} T_{α_i}(x_i)
#
# from per-axis tables of T_j, T'_j, T''_j built by three-term recurrences:
#     T_j   = 2x T_{j-1} − T_{j-2}
#     T'_j  = 2 T_{j-1} + 2x T'_{j-1} − T'_{j-2}
#     T''_j = 4 T'_{j-1} + 2x T''_{j-1} − T''_{j-2}
# Cost O(m·n) per gradient and O(m·n²) per Hessian for m coefficients, with no
# (d+1)^n dense tensor (mitigation (i) of the plan: the support IS the simplex).
#
# Scalar types. Everything is generic in the element type of `x` and of the
# coefficient vector: Float64, ComplexF64, DoubleFloats' ComplexDF64 (HC's mixed
# precision), ForwardDiff duals, and the truncated Taylor scalar `TaylorScalar` below
# that the HC predictor needs (`taylor!`). Nothing converts `x` to Float64.

"""
    TaylorScalar{N,T}

Truncated power series `Σ_{k<N} a_k ε^k` with the arithmetic the Chebyshev
recurrences need (`+`, `-`, `*`, scalar multiples). `N` terms, coefficients `T`.
Used to produce the order-`N−1` Taylor coefficient of `∇p(x(t); c(t))` along a path
for HomotopyContinuation's predictor (`taylor!`), where `x(t)` and `c(t)` are known
to lower order; HC's own `TruncatedTaylorSeries` carries no arithmetic.
"""
struct TaylorScalar{N,T<:Number}
    a::NTuple{N,T}
    TaylorScalar{N,T}(a::NTuple{N,T}) where {N,T<:Number} = new{N,T}(a)
end

TaylorScalar{N}(a::NTuple{N,T}) where {N,T} = TaylorScalar{N,T}(a)
TaylorScalar{N,T}(x::Number) where {N,T} =
    TaylorScalar{N,T}(ntuple(i -> i == 1 ? convert(T, x) : zero(T), Val(N)))
function TaylorScalar{N,T}(v::AbstractVector) where {N,T}
    TaylorScalar{N,T}(ntuple(i -> i <= length(v) ? convert(T, v[i]) : zero(T), Val(N)))
end
# a shorter (or differently typed) tuple of terms: pad with zeros
function TaylorScalar{N,T}(t::Tuple) where {N,T}
    TaylorScalar{N,T}(ntuple(i -> i <= length(t) ? convert(T, t[i]) : zero(T), Val(N)))
end

Base.zero(::Type{TaylorScalar{N,T}}) where {N,T} = TaylorScalar{N,T}(ntuple(_ -> zero(T), Val(N)))
Base.zero(::TaylorScalar{N,T}) where {N,T} = zero(TaylorScalar{N,T})
Base.one(::Type{TaylorScalar{N,T}}) where {N,T} = TaylorScalar{N,T}(one(T))
Base.one(::TaylorScalar{N,T}) where {N,T} = one(TaylorScalar{N,T})
Base.getindex(x::TaylorScalar, k::Int) = x.a[k+1]   # coefficient of ε^k
Base.length(::TaylorScalar{N}) where {N} = N

Base.:+(x::TaylorScalar{N,T}, y::TaylorScalar{N,T}) where {N,T} = TaylorScalar{N,T}(x.a .+ y.a)
Base.:-(x::TaylorScalar{N,T}, y::TaylorScalar{N,T}) where {N,T} = TaylorScalar{N,T}(x.a .- y.a)
Base.:-(x::TaylorScalar{N,T}) where {N,T} = TaylorScalar{N,T}(.-x.a)
function Base.:*(x::TaylorScalar{N,T}, y::TaylorScalar{N,T}) where {N,T}
    TaylorScalar{N,T}(ntuple(Val(N)) do k
        s = zero(T)
        for i in 1:k
            s += x.a[i] * y.a[k+1-i]
        end
        s
    end)
end
Base.:*(s::Number, x::TaylorScalar{N,T}) where {N,T} = TaylorScalar{N,T}(convert(T, s) .* x.a)
Base.:*(x::TaylorScalar, s::Number) = s * x
Base.:+(x::TaylorScalar{N,T}, s::Number) where {N,T} = x + TaylorScalar{N,T}(s)
Base.:+(s::Number, x::TaylorScalar) = x + s
Base.:-(x::TaylorScalar{N,T}, s::Number) where {N,T} = x - TaylorScalar{N,T}(s)
Base.:-(s::Number, x::TaylorScalar{N,T}) where {N,T} = TaylorScalar{N,T}(s) - x
Base.promote_rule(::Type{TaylorScalar{N,T}}, ::Type{S}) where {N,T,S<:Number} =
    TaylorScalar{N,promote_type(T, S)}
Base.convert(::Type{TaylorScalar{N,T}}, x::Number) where {N,T} = TaylorScalar{N,T}(x)
Base.convert(::Type{TaylorScalar{N,T}}, x::TaylorScalar{N,S}) where {N,T,S} =
    TaylorScalar{N,T}(convert.(T, x.a))

"""
    clenshaw(c::AbstractVector, x) -> scalar

`Σ_{k=0}^{m} c[k+1] T_k(x)` by Clenshaw's recurrence: `b_k = c_k + 2x b_{k+1} − b_{k+2}`
descending, result `c_0 + x b_1 − b_2`. Backward stable; `x` any scalar with `+`, `*`
against `eltype(c)` (never converted to Float64).
"""
function clenshaw(c::AbstractVector, x)
    m = length(c) - 1
    m < 0 && return zero(promote_type(eltype(c), typeof(x)))
    b1 = zero(x) * zero(eltype(c))
    b2 = b1
    for k in m:-1:1
        b1, b2 = c[k+1] + 2 * x * b1 - b2, b1
    end
    return c[1] + x * b1 - b2
end

"""
    chebyshev_derivative_coeffs(c::AbstractVector) -> Vector

Coefficients of `d/dx Σ c_k T_k`: `c'_{k-1} = c'_{k+1} + 2k c_k` descending from `k = m`,
then `c'_0 /= 2`. Length `max(length(c) − 1, 1)`.
"""
function chebyshev_derivative_coeffs(c::AbstractVector)
    m = length(c) - 1
    T = typeof(zero(eltype(c)) * 2)
    m <= 0 && return T[zero(T)]
    d = zeros(T, m)          # d[k] = c'_{k-1}, k = 1..m
    for k in m:-1:1
        d[k] = (k + 2 <= m ? d[k+2] : zero(T)) + 2 * k * c[k+1]
    end
    d[1] /= 2
    return d
end

"""
    chebyshev_tables!(T, dT, d2T, x, d)

Fill `T[j+1] = T_j(x)`, `dT[j+1] = T'_j(x)`, `d2T[j+1] = T''_j(x)` for `j = 0…d` by the
three-term recurrences (`d2T === nothing` skips the second derivatives).
"""
function chebyshev_tables!(T::AbstractVector, dT::AbstractVector, d2T, x, d::Int)
    E = eltype(T)
    o = one(E)
    z = zero(E)
    xe = convert(E, x)
    T[1] = o
    dT[1] = z
    d2T === nothing || (d2T[1] = z)
    d >= 1 || return nothing
    T[2] = xe
    dT[2] = o
    d2T === nothing || (d2T[2] = z)
    for j in 2:d
        T[j+1] = 2 * xe * T[j] - T[j-1]
        dT[j+1] = 2 * T[j] + 2 * xe * dT[j] - dT[j-1]
        d2T === nothing || (d2T[j+1] = 4 * dT[j] + 2 * xe * d2T[j] - d2T[j-1])
    end
    return nothing
end

"""
    ChebyshevGradientKernel(support::AbstractMatrix{<:Integer})
    ChebyshevGradientKernel(pol::ApproxPoly)

The support (one row per coefficient) and per-axis degrees of a plain-`T_n` Chebyshev
surrogate on `[-1,1]^n`. The coefficient vector is passed to every evaluation, so one
kernel serves every fit with the same support (a degree sweep, a leaf set, a parameter
homotopy over the coefficients). From an `ApproxPoly` the basis must be `:chebyshev`
and `normalized == false` (the stored representation; Legendre is out of scope).
"""
struct ChebyshevGradientKernel
    support::Matrix{Int}
    dmax::Vector{Int}
    n::Int
    m::Int
end

function ChebyshevGradientKernel(support::AbstractMatrix{<:Integer})
    S = Matrix{Int}(support)
    m, n = size(S)
    n >= 1 || throw(ArgumentError("support has no columns"))
    any(<(0), S) && throw(ArgumentError("support has negative degrees"))
    dmax = [m == 0 ? 0 : maximum(view(S, :, k)) for k in 1:n]
    return ChebyshevGradientKernel(S, dmax, n, m)
end

function ChebyshevGradientKernel(pol::ApproxPoly)
    pol.basis === :chebyshev ||
        throw(ArgumentError("ChebyshevGradientKernel: basis $(pol.basis) is not :chebyshev"))
    pol.normalized && throw(
        ArgumentError("ChebyshevGradientKernel: normalized Chebyshev coefficients are a different basis; the stored representation is plain T_n"),
    )
    S = _support_matrix(pol)
    return ChebyshevGradientKernel(S)
end

# Per-axis tables for the point x; element type is the promotion of eltype(x) and the
# coefficient type (so TaylorScalar / Dual / Complex inputs just work).
function _tables(K::ChebyshevGradientKernel, x, ::Type{E}, second::Bool) where {E}
    T = [Vector{E}(undef, K.dmax[k] + 1) for k in 1:K.n]
    dT = [Vector{E}(undef, K.dmax[k] + 1) for k in 1:K.n]
    d2T = second ? [Vector{E}(undef, K.dmax[k] + 1) for k in 1:K.n] : nothing
    for k in 1:K.n
        chebyshev_tables!(T[k], dT[k], second ? d2T[k] : nothing, convert(E, x[k]), K.dmax[k])
    end
    return T, dT, d2T
end

# Element type of the evaluation by operator inference rather than numeric promotion, so
# that HC's symbolic scalars (Variable ⋅ Variable + Variable is an Expression), duals and
# TaylorScalars all land on a type that `zero`, `one` and `convert` accept.
_eltype(K::ChebyshevGradientKernel, x, c) =
    Base.promote_op((a, b) -> a * b + a, eltype(x), eltype(c))

"""
    value(K::ChebyshevGradientKernel, x, c) -> scalar

`p(x) = Σ_α c_α Π_k T_{α_k}(x_k)` on the kernel's support.
"""
function value(K::ChebyshevGradientKernel, x, c::AbstractVector)
    length(c) == K.m || throw(DimensionMismatch("coefficient vector has $(length(c)) entries for $(K.m) support rows"))
    E = _eltype(K, x, c)
    T, _, _ = _tables(K, x, E, false)
    s = zero(E)
    @inbounds for r in 1:K.m
        t = convert(E, c[r])
        for k in 1:K.n
            t *= T[k][K.support[r, k]+1]
        end
        s += t
    end
    return s
end

"""
    evaluate!(u, K::ChebyshevGradientKernel, x, c) -> u

`u[k] = ∂_k p(x)`, `k = 1…n`. `u`, `x` and `c` may be real, complex, dual or
`TaylorScalar`-valued; `eltype(u)` must hold the promotion of `eltype(x)` and `eltype(c)`.
"""
function evaluate!(u, K::ChebyshevGradientKernel, x, c::AbstractVector)
    length(c) == K.m || throw(DimensionMismatch("coefficient vector has $(length(c)) entries for $(K.m) support rows"))
    E = _eltype(K, x, c)
    T, dT, _ = _tables(K, x, E, false)
    n = K.n
    pre = Vector{E}(undef, n + 1)   # pre[k] = Π_{i<k} T_i
    suf = Vector{E}(undef, n + 1)   # suf[k] = Π_{i>k} T_i
    acc = zeros(E, n)
    @inbounds for r in 1:K.m
        pre[1] = one(E)
        for k in 1:n
            pre[k+1] = pre[k] * T[k][K.support[r, k]+1]
        end
        suf[n+1] = one(E)
        for k in n:-1:1
            suf[k] = suf[k+1] * T[k][K.support[r, k]+1]
        end
        cr = convert(E, c[r])
        for k in 1:n
            acc[k] += cr * pre[k] * dT[k][K.support[r, k]+1] * suf[k+1]
        end
    end
    for k in 1:n
        u[k] = acc[k]
    end
    return u
end

"""
    evaluate_and_jacobian!(u, U, K::ChebyshevGradientKernel, x, c) -> (u, U)

`u = ∇p(x)`, `U = ∇²p(x)` (both triangles). The Jacobian of the gradient system IS the
Hessian of the surrogate, so `cond(U)` at a solution is the conditioning of the critical
point itself (the plan's `cond_jacobian_median`).
"""
function evaluate_and_jacobian!(u, U, K::ChebyshevGradientKernel, x, c::AbstractVector)
    length(c) == K.m || throw(DimensionMismatch("coefficient vector has $(length(c)) entries for $(K.m) support rows"))
    E = _eltype(K, x, c)
    T, dT, d2T = _tables(K, x, E, true)
    n = K.n
    pre = Vector{E}(undef, n + 1)
    suf = Vector{E}(undef, n + 1)
    acc = zeros(E, n)
    H = zeros(E, n, n)
    @inbounds for r in 1:K.m
        pre[1] = one(E)
        for k in 1:n
            pre[k+1] = pre[k] * T[k][K.support[r, k]+1]
        end
        suf[n+1] = one(E)
        for k in n:-1:1
            suf[k] = suf[k+1] * T[k][K.support[r, k]+1]
        end
        cr = convert(E, c[r])
        for j in 1:n
            aj = K.support[r, j] + 1
            acc[j] += cr * pre[j] * dT[j][aj] * suf[j+1]
            H[j, j] += cr * pre[j] * d2T[j][aj] * suf[j+1]
            # off-diagonal j < k: Π_{i<j} T · T'_j · Π_{j<i<k} T · T'_k · Π_{i>k} T
            left = cr * pre[j] * dT[j][aj]
            mid = one(E)
            for k in j+1:n
                ak = K.support[r, k] + 1
                v = left * mid * dT[k][ak] * suf[k+1]
                H[j, k] += v
                mid *= T[k][ak]
            end
        end
    end
    for j in 1:n
        u[j] = acc[j]
        for k in 1:n
            U[j, k] = k >= j ? H[j, k] : H[k, j]
        end
    end
    return u, U
end

"""
    gradient_basis_matrix(K::ChebyshevGradientKernel, x) -> Matrix

`A[k, r] = ∂_k T_{α_r}(x)`: the gradient system is linear in the coefficients,
`∇p(x; c) = A(x) c`. Used to build a start pair for the monodromy anchor (any `c` in the
null space of `A(x₀)` makes `x₀` a critical point of `p(·; c)`).
"""
function gradient_basis_matrix(K::ChebyshevGradientKernel, x)
    E = promote_type(eltype(x), Float64)
    T, dT, _ = _tables(K, x, E, false)
    n = K.n
    A = zeros(E, n, K.m)
    pre = Vector{E}(undef, n + 1)
    suf = Vector{E}(undef, n + 1)
    @inbounds for r in 1:K.m
        pre[1] = one(E)
        for k in 1:n
            pre[k+1] = pre[k] * T[k][K.support[r, k]+1]
        end
        suf[n+1] = one(E)
        for k in n:-1:1
            suf[k] = suf[k+1] * T[k][K.support[r, k]+1]
        end
        for k in 1:n
            A[k, r] = pre[k] * dT[k][K.support[r, k]+1] * suf[k+1]
        end
    end
    return A
end

"""
    taylor_series(::Val{M}, K::ChebyshevGradientKernel, x_terms, c_terms) -> Vector{TaylorScalar{M+1}}

The first `M+1` Taylor coefficients of `∇p(x(t); c(t))` where `x(t)` is given by its
first coefficients (`x_terms[k][j+1]`, `j = 0…`, missing orders zero) and `c(t)` by
`c_terms[r][j+1]`, through the same recurrences on [`TaylorScalar`](@ref) arithmetic.
"""
function taylor_series(::Val{M}, K::ChebyshevGradientKernel, x_terms, c_terms) where {M}
    N = M + 1
    Tx = promote_type(eltype(first(x_terms)), eltype(first(c_terms)))
    S = TaylorScalar{N,Tx}
    x = [S(x_terms[k]) for k in 1:K.n]
    # The system is linear in the coefficients, so c(t) = Σ_j c_j t^j splits the series:
    # ∇p(x(t); c(t)) = Σ_j t^j · [A(x(t)) c_j]. Each c_j is a PLAIN vector and the
    # contraction runs with scalar × TaylorScalar products — no per-coefficient Taylor
    # object (4 845 of them per call at degree 16 in 4-D, three calls per tracker step).
    nc = min(maximum(length(t) for t in c_terms), N)
    cs = [[length(c_terms[r]) >= j ? convert(Tx, c_terms[r][j]) : zero(Tx) for r in 1:K.m] for j in 1:nc]
    keep = [j for j in 1:nc if !all(iszero, cs[j])]
    w = [zero(S) for _ in 1:K.n]
    isempty(keep) && return w
    ws = [Vector{S}(undef, K.n) for _ in keep]
    evaluate_multi!(ws, K, x, cs[keep])   # one pass over the support for all orders
    for (i, j) in enumerate(keep), k in 1:K.n
        w[k] = w[k] + _shift(ws[i][k], j - 1)
    end
    return w
end

"""
    evaluate_multi!(us, K::ChebyshevGradientKernel, x, cs) -> us

`us[i][k] = ∂_k p(x; cs[i])` for several coefficient vectors on the same support and the
same point, sharing the basis products (one pass over the support).
"""
function evaluate_multi!(us, K::ChebyshevGradientKernel, x, cs::AbstractVector{<:AbstractVector})
    L = length(cs)
    L == length(us) || throw(DimensionMismatch("$(length(us)) outputs for $L coefficient vectors"))
    for c in cs
        length(c) == K.m || throw(DimensionMismatch("coefficient vector has $(length(c)) entries for $(K.m) support rows"))
    end
    E = L == 0 ? eltype(x) : _eltype(K, x, cs[1])
    T, dT, _ = _tables(K, x, E, false)
    n = K.n
    pre = Vector{E}(undef, n + 1)
    suf = Vector{E}(undef, n + 1)
    acc = [zeros(E, n) for _ in 1:L]
    @inbounds for r in 1:K.m
        pre[1] = one(E)
        for k in 1:n
            pre[k+1] = pre[k] * T[k][K.support[r, k]+1]
        end
        suf[n+1] = one(E)
        for k in n:-1:1
            suf[k] = suf[k+1] * T[k][K.support[r, k]+1]
        end
        for k in 1:n
            term = pre[k] * dT[k][K.support[r, k]+1] * suf[k+1]
            for i in 1:L
                acc[i][k] += cs[i][r] * term
            end
        end
    end
    for i in 1:L, k in 1:n
        us[i][k] = acc[i][k]
    end
    return us
end

# multiply a truncated series by ε^s (drop the terms that fall off the end)
function _shift(x::TaylorScalar{N,T}, s::Int) where {N,T}
    s == 0 && return x
    TaylorScalar{N,T}(ntuple(i -> i > s ? x.a[i-s] : zero(T), Val(N)))
end

"""
    taylor_coefficient!(u, ::Val{M}, K::ChebyshevGradientKernel, x_terms, c_terms) -> u

Order-`M` Taylor coefficient of `∇p(x(t); c(t))` (see [`taylor_series`](@ref)). This is
what HomotopyContinuation's predictor asks a system for (`taylor!` with `Val(M)` and
`assign_highest_order_only`): the lower orders of `x` are known, the order-`M` one is
solved for from `J x_M = −u`.
"""
function taylor_coefficient!(u, v::Val{M}, K::ChebyshevGradientKernel, x_terms, c_terms) where {M}
    w = taylor_series(v, K, x_terms, c_terms)
    for k in 1:K.n
        u[k] = w[k][M]
    end
    return u
end
