# rational_approx.jl — multivariate rational surrogates r = p/q
#
# Phase 1 of docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md. The fit is the
# linear-algebra step of Austin, Krishnamoorthy, Leyffer, Mrenna, Müller,
# Schulz, "Practical algorithms for multivariate rational approximation",
# CPC 261 (2021) 107663, §3, with the denominator-degree reduction of their
# Algorithm 3.3. Everything here is linear algebra on the same tensorised
# orthogonal basis, Chebyshev-Gauss grid and coordinate conventions as
# `Constructor` / `ApproxPoly`; the critical-point machinery lives in
# rational_solver.jl.
#
# Conventions shared with the polynomial path (do not drift from them):
#   * grid rows are points of [-1,1]^n, in `generate_grid` order, so the
#     quadrature weights of `compute_quadrature_weights` line up with them;
#   * coefficients live in the basis `lambda_vandermonde` evaluates, which is
#     plain T_k for Chebyshev and orthonormal P_k for Legendre — the stored
#     `normalized` flag is `_stored_normalized(basis)`, exactly as for
#     `ApproxPoly`, and is what `construct_orthopoly_polynomial` must be given;
#   * original coordinates are `scale_factor .* x .+ center`.

"""
    ApproxRational{T,S}

A rational surrogate `r(x) = p(x) / q(x)` on `[-1,1]^n`, `p` of total degree `M` and
`q` of total degree `N`, both expanded in the tensorised orthogonal basis of
`lambda_vandermonde` (plain Chebyshev `T_k`, or orthonormal Legendre).

# Fields
- `a`, `b`: coefficient vectors of `p` and `q` (lengths `binomial(n+M, M)` and
  `binomial(n+N, N)`), normalised so that the mean of `q` over the grid is 1.
- `Lambda_M`, `Lambda_N`: the `SupportGen` multi-index sets of `p` and `q`.
- `M`, `N`: total degrees; `N` is the **post-reduction** denominator degree.
- `basis`, `normalized`, `precision`: as for `ApproxPoly` (`normalized` is
  basis-determined, see `_stored_normalized`).
- `scale_factor`, `center`: the affine map `x_orig = scale_factor .* x .+ center`.
- `GN`: the grid has `GN + 1` nodes per dimension; `-1` for scattered samples.
- `grid`: `n_points × n` matrix of the fit's points in `[-1,1]^n` — the tensor grid
  (same layout as `ApproxPoly.grid`) or the scattered samples.
- `z`: objective values at those points.
- `nrm`: L2 norm on `[-1,1]^n` (Lebesgue measure) of the **nonlinear** residual
  `p/q - f` at the fit's points. On the grid it is quadrature-weighted with the
  weights `Constructor` uses for `ApproxPoly.nrm`, so the two are directly
  comparable; on scattered samples it is the Monte Carlo estimate of the same
  integral (see `sampling`). Either way it is in-sample.
- `rms`: plain root-mean-square of the same residual over the grid.
- `sigma_ratio`: `σ_min / σ_max` of the projected matrix `W = (I - QQᵀ) F V_N`; a value
  near machine precision means the linearised problem `p = f q` is solved exactly on
  the grid (f is, on the grid, a rational function of type ≤ (M,N)).
- `singular_values`: the full σ-spectrum of `W` at the final `N` (the Phase-2
  adaptive-(M,N) input).
- `qmin_grid`: minimum of `q` over the grid. A hint only: `certify_positive_denominator`
  is the certificate.
- `n_reductions`: how many times Algorithm 3.3 lowered `N`.
- `q_normalization`: `:mean` (mean of `q` over the grid is 1, the convention) or
  `:maxabs` (the fitted `q` had zero mean, i.e. changes sign on the grid, and was
  scaled by `max |q|` instead; such a fit fails `certify_positive_denominator`).
- `sampling`: `:grid` (tensor Chebyshev/Legendre grid) or `:christoffel` (i.i.d.
  draws from the product arcsine measure, weighted least squares with the
  Christoffel weights of the total-degree-`max(M,N)` Chebyshev space).
- `sample_weights`: the least-squares weight of each point (`m / K_Λ(x)` for
  `:christoffel`, all ones for `:grid`).

Callable: `R(x)` evaluates `p(x)/q(x)` at `x` in surrogate coordinates `[-1,1]^n`
(ForwardDiff-compatible). `evaluate(R, x_orig)` takes original coordinates.
"""
struct ApproxRational{T<:Real,S<:Union{Float64,Vector{Float64}}}
    a::Vector{T}
    b::Vector{T}
    Lambda_M::NamedTuple
    Lambda_N::NamedTuple
    M::Int
    N::Int
    basis::Symbol
    normalized::Bool
    precision::PrecisionType
    scale_factor::S
    center::Vector{Float64}
    GN::Int
    grid::Matrix{Float64}
    z::Vector{Float64}
    nrm::Float64
    rms::Float64
    sigma_ratio::Float64
    singular_values::Vector{Float64}
    qmin_grid::Float64
    n_reductions::Int
    q_normalization::Symbol
    sampling::Symbol
    sample_weights::Vector{Float64}
end

function Base.show(io::IO, R::ApproxRational)
    n = size(R.grid, 2)
    pts = R.sampling == :grid ? "GN=$(R.GN)" : "$(R.sampling) K=$(size(R.grid, 1))"
    print(
        io,
        "ApproxRational(n=$n, M=$(R.M), N=$(R.N), basis=$(R.basis), $pts, ",
        "dof=$(rational_dof(R)), nrm=$(round(R.nrm; sigdigits=3)), ",
        "sigma_ratio=$(round(R.sigma_ratio; sigdigits=3)), ",
        "qmin_grid=$(round(R.qmin_grid; sigdigits=3)))",
    )
end

"""
    rational_dof(R::ApproxRational) -> Int
    rational_dof(n, M, N) -> Int

Degrees of freedom of a type-(M,N) rational in `n` variables: `α(M) + α(N) - 1`
with `α(d) = binomial(n + d, d)` (one is removed by the normalisation of `q`).
"""
rational_dof(n::Int, M::Int, N::Int) = binomial(n + M, M) + binomial(n + N, N) - 1
rational_dof(R::ApproxRational) = rational_dof(size(R.grid, 2), R.M, R.N)

"""
    rational_ls_fit(V_M, V_N, z; eta = 1e-12)
        -> (; a, b, singular_values, reduce_N, normalization)

The linear-algebra rational fit of Austin et al. (2021) §3. With `V_M`, `V_N` the
Vandermonde matrices of numerator and denominator on a common point set and
`F = Diagonal(z)`, solve

    min ‖V_M a − F V_N b‖₂   subject to   ‖b‖₂ = 1.

Thin QR `V_M = QR` reduces this to the smallest right singular vector of
`W = (I − QQᵀ) F V_N`: `b` is that vector and `a = R⁻¹ Qᵀ F V_N b`. The pair is then
rescaled so that the mean of `q = V_N b` over the points is 1 — this fixes the
otherwise arbitrary sign and scale of `(a, b)` and keeps the monomial coefficients
O(1); do **not** renormalise to `‖b‖ = 1` downstream (the sign would be arbitrary and
`q` could come out negative everywhere). When the fitted `q` has (numerically) zero
mean — it then changes sign on the grid, e.g. an odd `q` on a symmetric grid — the
pair is scaled by `max |q|` with `q > 0` where `|q|` is largest, and `normalization`
is `:maxabs` instead of `:mean`; the certificate is what rejects such a fit.

`reduce_N` is the Algorithm 3.3 flag: `true` when the *second*-smallest singular value
of `W` is also below `eta · σ_max`, i.e. the linearised problem has a solution space of
dimension ≥ 2 and the denominator degree is over-parameterised (Froissart doublets).
`eta = 1e-12` is the noise-free setting.

`sqrt_w` (positive, one per point) weights the rows: the problem becomes
`min ‖diag(sqrt_w)(V_M a − F V_N b)‖₂`, the Christoffel-preconditioned least squares
of scattered samples. The normalisation above is still taken on `q` itself (unweighted
mean over the points), so weighted and unweighted fits are scaled alike.

Throws `ArgumentError` on inconsistent sizes, fewer points than unknowns, or
non-positive weights.
"""
function rational_ls_fit(
    V_M::AbstractMatrix,
    V_N::AbstractMatrix,
    z::AbstractVector;
    eta::Real = 1e-12,
    sqrt_w::Union{Nothing,AbstractVector{<:Real}} = nothing,
)
    K, mM = size(V_M)
    K2, mN = size(V_N)
    (K == K2 && K == length(z)) || throw(
        ArgumentError(
            "rational_ls_fit: V_M is $(K)×$(mM), V_N is $(K2)×$(mN), z has length $(length(z)); row counts must agree",
        ),
    )
    K >= mM + mN || throw(
        ArgumentError(
            "rational_ls_fit: $(K) points cannot determine $(mM) + $(mN) coefficients; enlarge the grid",
        ),
    )
    if sqrt_w !== nothing
        length(sqrt_w) == K || throw(
            ArgumentError("rational_ls_fit: sqrt_w has length $(length(sqrt_w)), expected one weight per point ($K)"),
        )
        all(w -> isfinite(w) && w > 0, sqrt_w) ||
            throw(ArgumentError("rational_ls_fit: sqrt_w must be positive and finite"))
    end
    sw = sqrt_w === nothing ? ones(K) : Vector{Float64}(sqrt_w)
    Qr = qr(Matrix{Float64}(sw .* V_M))
    Q = Matrix(Qr.Q)                 # thin K × mM
    Rm = Qr.R
    dR = abs.(diag(Rm))
    minimum(dR) > 1e-13 * maximum(dR) || error(
        "rational_ls_fit: the numerator Vandermonde is rank-deficient on this point set " *
        "(min |R_ii| / max |R_ii| = $(minimum(dR) / maximum(dR))); the basis functions " *
        "are not independent on the grid — use more nodes per dimension than the degree",
    )
    FVN = (sw .* z) .* V_N
    W = FVN - Q * (Q' * FVN)
    S = svd(W)
    σ = S.S
    reduce_N = length(σ) > 1 && σ[end-1] < eta * σ[1]
    b = S.V[:, end]
    a = Rm \ (Q' * (FVN * b))
    qvals = V_N * b
    qm = sum(qvals) / K
    qmax = maximum(abs, qvals)
    # Mean-of-q = 1 is the convention (sign and scale fixed, O(1) coefficients).
    # A denominator with (numerically) zero mean changes sign on the grid — e.g.
    # an odd q on a symmetric grid for an even objective, where (p, q) odd is a
    # legitimate solution of the linearised problem. That fit is still a fit
    # (the certificate is what rejects it), so scale it by max |q| instead, with
    # the sign that makes q positive where |q| is largest, and say so.
    normalization = abs(qm) > 1e-3 * qmax ? :mean : :maxabs
    scale = normalization == :mean ? qm : sign(qvals[argmax(abs.(qvals))]) * qmax
    return (
        a = a ./ scale,
        b = b ./ scale,
        singular_values = σ,
        reduce_N = reduce_N,
        normalization = normalization,
    )
end

# ── grid + objective evaluation (mirrors MainGenerate without its GN heuristics) ──

"""
    _rational_grid_size(n, M, N, oversample) -> GN

Smallest `GN` such that the tensor grid with `GN + 1` nodes per dimension has at least
`oversample · (α(M) + α(N))` points, `α(d) = binomial(n + d, d)`.
"""
function _rational_grid_size(n::Int, M::Int, N::Int, oversample::Real)
    need = oversample * (binomial(n + M, M) + binomial(n + N, N))
    GN = 0
    while (GN + 1)^n < need
        GN += 1
    end
    return GN
end

"""
    _grid_matrix(n, GN, basis) -> Matrix{Float64}

The `generate_grid` tensor grid flattened to an `n_points × n` matrix, in the same
order `MainGenerate` uses (so `compute_quadrature_weights` lines up with the rows).
"""
function _grid_matrix(n::Int, GN::Int, basis::Symbol)
    grid = generate_grid(n, GN; basis = basis)
    return reduce(vcat, map(x -> x', reshape(grid, :)))
end

"""
    _evaluate_objective_rows(f, S, scale_factor, center) -> Vector{Float64}

Evaluate `f` at the original-coordinate image of every row of `S`. A 1-D objective is
called with a scalar, as `MainGenerate` does.
"""
function _evaluate_objective_rows(f, S::AbstractMatrix, scale_factor, center)
    n = size(S, 2)
    K = size(S, 1)
    z = Vector{Float64}(undef, K)
    for i in 1:K
        xo = to_original_coordinates(S[i, :], scale_factor, center)
        v = n == 1 ? f(xo[1]) : f(xo)
        z[i] = Float64(v)
    end
    return z
end

to_original_coordinates(x::AbstractVector, scale_factor, center) =
    scale_factor .* x .+ center
to_surrogate_coordinates(x::AbstractVector, scale_factor, center) =
    (x .- center) ./ scale_factor

"""
    to_original_coordinates(R::ApproxRational, x)
    to_surrogate_coordinates(R::ApproxRational, x_orig)

The affine map between surrogate coordinates `[-1,1]^n` and the original domain, in
the convention of `process_crit_pts` / `ApproxPoly` (`x_orig = scale_factor .* x .+ center`).
"""
to_original_coordinates(R::ApproxRational, x::AbstractVector) =
    to_original_coordinates(x, R.scale_factor, R.center)
to_surrogate_coordinates(R::ApproxRational, x::AbstractVector) =
    to_surrogate_coordinates(x, R.scale_factor, R.center)

"""
    RationalConstructor(TR::TestInput, M, N; kwargs...) -> ApproxRational

Fit a rational surrogate `p/q` of type `(M, N)` to `TR.objective` on the box
`TR.center ± TR.sample_range` by the linear-algebra least-squares of Austin et al.
(2021), with Algorithm 3.3 denominator-degree reduction.

# Keyword arguments
- `basis::Symbol = :chebyshev`: `:chebyshev` or `:legendre` (nodes and basis, as `Constructor`).
- `GN::Union{Int,Nothing} = nothing`: nodes per dimension minus one. Precedence: this
  kwarg, then `TR.GN`, then the smallest grid with `(GN+1)^n ≥ oversample · (α(M) + α(N))`.
- `oversample::Real = 2`: see `GN`.
- `eta::Real = 1e-12`: Algorithm 3.3 threshold (noise-free default).
- `reduce::Bool = true`: apply the degree reduction; the returned `R.N` is the reduced degree.
- `precision::PrecisionType = RationalPrecision`: precision tag handed to
  `construct_orthopoly_polynomial` when the surrogate is converted to monomials.
- `normalized::Union{Nothing,Bool} = nothing`: the stored flag is always
  `_stored_normalized(basis)` (plain `T_k` for Chebyshev, orthonormal Legendre); passing
  a contradicting value is an `ArgumentError` rather than a silent re-interpretation.
- `sampling::Symbol = :grid`: `:grid` fits on the tensor grid above; `:christoffel`
  fits on `n_samples` points drawn i.i.d. from the product arcsine (Chebyshev) measure,
  by least squares weighted with the Christoffel weights `m / K_Λ(x)` of the
  total-degree-`max(M, N)` Chebyshev space (Cohen–Migliorati; the same sampler as
  `christoffel_fit_chebyshev`). The objective is evaluated `n_samples` times instead of
  `(GN+1)^n`. Chebyshev basis only; `GN` must not be given.
- `n_samples::Union{Int,Nothing} = nothing`: required for `:christoffel`, at least
  `α(M) + α(N)`. The stability theory for polynomial least squares asks for
  `O(m log m)`; the `F·V_N` block is not a polynomial space, so what suffices for the
  rational fit is an empirical question (measure it with the audit's census).
- `rng::Union{AbstractRNG,Nothing} = nothing`: required for `:christoffel` (the sample
  set must be replayable; there is no default generator).
- `verbose::Int = 0`.

`nrm` is the L2 norm on `[-1,1]^n` of the nonlinear residual `p/q − f` at the fit's
points: quadrature-weighted on the grid, with the same weights as `ApproxPoly.nrm`; on
arcsine samples the Monte Carlo estimate `(1/K) Σ rᵢ² ∏ₖ π√(1 − xᵢₖ²)` of the same
integral. Both are in-sample; with few samples per unknown the scattered estimate is
optimistic, so compare fits on a common validation set.
"""
function RationalConstructor(
    TR::TestInput,
    M::Int,
    N::Int;
    basis::Symbol = :chebyshev,
    GN::Union{Int,Nothing} = nothing,
    oversample::Real = 2,
    eta::Real = 1e-12,
    reduce::Bool = true,
    precision::PrecisionType = RationalPrecision,
    normalized::Union{Nothing,Bool} = nothing,
    sampling::Symbol = :grid,
    n_samples::Union{Int,Nothing} = nothing,
    rng::Union{AbstractRNG,Nothing} = nothing,
    verbose::Int = 0,
)
    basis in (:chebyshev, :legendre) ||
        throw(ArgumentError("basis must be :chebyshev or :legendre, got $basis"))
    sampling in (:grid, :christoffel) ||
        throw(ArgumentError("sampling must be :grid or :christoffel, got $sampling"))
    if sampling == :christoffel
        basis == :chebyshev || throw(
            ArgumentError("sampling = :christoffel needs basis = :chebyshev (the Christoffel kernel is Chebyshev), got $basis"),
        )
        GN === nothing || throw(ArgumentError("GN = $GN has no meaning with sampling = :christoffel; pass n_samples"))
        n_samples === nothing && throw(ArgumentError("sampling = :christoffel needs n_samples"))
        rng === nothing && throw(
            ArgumentError("sampling = :christoffel needs an explicit rng (the sample set must be replayable)"),
        )
        need = binomial(TR.dim + M, M) + binomial(TR.dim + N, N)
        n_samples >= need || throw(
            ArgumentError("n_samples = $n_samples cannot determine α(M) + α(N) = $need coefficients"),
        )
    else
        n_samples === nothing ||
            throw(ArgumentError("n_samples is for sampling = :christoffel; the grid is set by GN"))
        rng === nothing || throw(ArgumentError("rng is for sampling = :christoffel; the grid is deterministic"))
    end
    M >= 0 || throw(ArgumentError("numerator degree M must be ≥ 0, got $M"))
    N >= 0 || throw(ArgumentError("denominator degree N must be ≥ 0, got $N"))
    oversample > 0 || throw(ArgumentError("oversample must be positive"))
    stored_norm = _stored_normalized(basis)
    if normalized !== nothing && normalized != stored_norm
        throw(
            ArgumentError(
                "normalized=$normalized contradicts the $basis coefficient convention " *
                "(lambda_vandermonde evaluates the $(stored_norm ? "orthonormal" : "plain") basis, " *
                "so the stored flag must be $stored_norm); omit the kwarg",
            ),
        )
    end
    isnothing(TR.sample_range) && throw(ArgumentError("TestInput.sample_range must be set"))

    n = TR.dim
    scale_factor = TR.sample_range
    center = TR.center
    dmax = max(M, N)
    if sampling == :grid
        actual_GN = if GN !== nothing
            GN
        elseif TR.GN !== nothing
            TR.GN
        else
            _rational_grid_size(n, M, N, oversample)
        end
        actual_GN >= 0 || throw(ArgumentError("GN must be ≥ 0, got $actual_GN"))
        # GN + 1 nodes per dimension determine polynomials of degree ≤ GN only: the
        # Chebyshev nodes are the zeros of T_{GN+1}, so every basis function of degree
        # GN + 1 in one variable vanishes on the whole grid and the Vandermonde is
        # rank-deficient (the fit then looks perfect on the grid and is garbage off it —
        # observed in 3-D at (8,4) with 8 nodes: 0 real solutions of 659 HC paths).
        if GN === nothing && TR.GN === nothing
            actual_GN = max(actual_GN, dmax)
        elseif actual_GN < dmax
            throw(
                ArgumentError(
                    "GN=$actual_GN gives $(actual_GN + 1) nodes per dimension, too few for degree " *
                    "$dmax basis functions (they are not independent on the grid); need GN ≥ $dmax",
                ),
            )
        end
        S = _grid_matrix(n, actual_GN, basis)
        sqrt_w = nothing
    else
        # TR.GN, if set, belongs to the grid path and is not used here
        actual_GN = -1
        Lambda_w = SupportGen(n, (:one_d_for_all, dmax))
        S, sqrt_w = christoffel_random_sample_chebyshev(n, Lambda_w.data, n_samples; rng = rng)
    end
    K = size(S, 1)
    verbose >= 1 && @info "RationalConstructor: n=$n (M,N)=($M,$N) sampling=$sampling " *
          (sampling == :grid ? "GN=$actual_GN " : "") * "($K points)"
    z = _evaluate_objective_rows(TR.objective, S, scale_factor, center)
    all(isfinite, z) || error(
        "RationalConstructor: objective is not finite at the fit's points " *
        "($(count(!isfinite, z)) of $K); the fit needs finite samples",
    )

    Lambda_M = SupportGen(n, (:one_d_for_all, M))
    V_M = lambda_vandermonde(Lambda_M, S; basis = basis)

    N_cur = N
    n_red = 0
    local Lambda_N, V_N, fit
    while true
        Lambda_N = SupportGen(n, (:one_d_for_all, N_cur))
        V_N = lambda_vandermonde(Lambda_N, S; basis = basis)
        fit = rational_ls_fit(V_M, V_N, z; eta = eta, sqrt_w = sqrt_w)
        if reduce && fit.reduce_N && N_cur > 0
            verbose >= 1 &&
                @info "  degree reduction: σ₂/σ₁ = $(fit.singular_values[end-1] / fit.singular_values[1]) < $eta, N $N_cur → $(N_cur - 1)"
            N_cur -= 1
            n_red += 1
            continue
        end
        break
    end

    pvals = V_M * fit.a
    qvals = V_N * fit.b
    resid = pvals ./ qvals .- z
    weights = if sampling == :grid
        compute_quadrature_weights(basis, actual_GN, n)
    else
        # Monte Carlo on arcsine draws: ∫ r² dx = E_μ[r² / ρ_μ], ρ_μ(x) = ∏ₖ 1/(π√(1 − xₖ²))
        [prod(π * sqrt(1 - S[i, k]^2) for k in 1:n) for i in 1:K] ./ K
    end
    length(weights) == K || error(
        "RationalConstructor: residual weights ($(length(weights))) do not match the points ($K)",
    )
    nrm = sqrt(sum(weights .* abs2.(resid)))
    rms = sqrt(sum(abs2, resid) / K)
    σ = fit.singular_values
    sigma_ratio = σ[end] / σ[1]
    (isfinite(nrm) && isfinite(sigma_ratio)) || error(
        "RationalConstructor: non-finite fit diagnostics (nrm=$nrm, sigma_ratio=$sigma_ratio) " *
        "at (M,N)=($M,$N_cur), $K $sampling points — the denominator vanishes at a fit point",
    )
    verbose >= 1 &&
        @info "  nrm=$nrm rms=$rms sigma_ratio=$sigma_ratio qmin_grid=$(minimum(qvals)) N=$N_cur"

    return ApproxRational{Float64,typeof(scale_factor)}(
        Vector{Float64}(fit.a),
        Vector{Float64}(fit.b),
        Lambda_M,
        Lambda_N,
        M,
        N_cur,
        basis,
        stored_norm,
        precision,
        scale_factor,
        collect(Float64, center),
        actual_GN,
        S,
        z,
        nrm,
        rms,
        sigma_ratio,
        Vector{Float64}(σ),
        minimum(qvals),
        n_red,
        fit.normalization,
        sampling,
        sqrt_w === nothing ? ones(K) : sqrt_w .^ 2,
    )
end

# ── evaluation in surrogate coordinates (ForwardDiff-compatible) ──────────────

"""
    _tensor_basis_values(Lambda, x, basis, normalized) -> Vector

Values of the tensorised basis functions indexed by the rows of `Lambda.data` at `x`,
by the same recurrences and normalisation `evaluate(::ApproxPoly, x)` uses. Generic in
`eltype(x)` so ForwardDiff duals pass through.
"""
function _tensor_basis_values(
    Lambda::NamedTuple,
    x::AbstractVector,
    basis::Symbol,
    normalized::Bool,
)
    data = Lambda.data
    m, n = Lambda.size
    length(x) == n ||
        throw(DimensionMismatch("expected a point of dimension $n, got $(length(x))"))
    maxdeg = m == 0 ? 0 : maximum(data)
    T = promote_type(eltype(x), Float64)
    B = Matrix{T}(undef, n, maxdeg + 1)
    for k in 1:n
        xk = x[k]
        if basis == :chebyshev
            Tp = one(T)
            Tc = T(xk)
            B[k, 1] = normalized ? Tp / sqrt(π) : Tp
            if maxdeg >= 1
                B[k, 2] = normalized ? Tc * sqrt(2 / π) : Tc
            end
            for d in 2:maxdeg
                Tn = 2 * xk * Tc - Tp
                B[k, d+1] = normalized ? Tn * sqrt(2 / π) : Tn
                Tp, Tc = Tc, Tn
            end
        elseif basis == :legendre
            Pp = one(T)
            Pc = T(xk)
            B[k, 1] = normalized ? Pp * sqrt(0.5) : Pp
            if maxdeg >= 1
                B[k, 2] = normalized ? Pc * sqrt(1.5) : Pc
            end
            for d in 2:maxdeg
                Pn = ((2d - 1) * xk * Pc - (d - 1) * Pp) / d
                B[k, d+1] = normalized ? Pn * sqrt((2d + 1) / 2) : Pn
                Pp, Pc = Pc, Pn
            end
        else
            throw(ArgumentError("unsupported basis $basis"))
        end
    end
    vals = Vector{T}(undef, m)
    for j in 1:m
        v = one(T)
        for k in 1:n
            v *= B[k, Int(data[j, k])+1]
        end
        vals[j] = v
    end
    return vals
end

"""
    rational_numerator(R::ApproxRational, x) -> p(x)
    rational_denominator(R::ApproxRational, x) -> q(x)

Numerator and denominator at `x` in surrogate coordinates `[-1,1]^n`. Generic in
`eltype(x)` (ForwardDiff-compatible).
"""
rational_numerator(R::ApproxRational, x::AbstractVector) =
    dot(R.a, _tensor_basis_values(R.Lambda_M, x, R.basis, R.normalized))
rational_denominator(R::ApproxRational, x::AbstractVector) =
    dot(R.b, _tensor_basis_values(R.Lambda_N, x, R.basis, R.normalized))

"""
    (R::ApproxRational)(x) -> p(x) / q(x)

Evaluate the surrogate at `x` in surrogate coordinates `[-1,1]^n`.
"""
(R::ApproxRational)(x::AbstractVector) =
    rational_numerator(R, x) / rational_denominator(R, x)

"""
    evaluate(R::ApproxRational, x_orig) -> r(x)

Evaluate the surrogate at a point of the **original** domain (the `ApproxPoly`
`evaluate` convention).
"""
evaluate(R::ApproxRational, x::AbstractVector) = R(to_surrogate_coordinates(R, x))
