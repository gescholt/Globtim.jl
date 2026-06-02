# christoffel_sampling.jl
#
# E1 — Christoffel-preconditioned random sampling + weighted LS for the
# Cohen-Migliorati 2017 stability regime. Opt-in alternative to the default
# tensor-grid + unweighted LS path. See:
#   experiments/sandbox/e1_k_measurement.md
#   /home/georgy/.claude/plans/quizzical-knitting-cake.md
#
# The Vandermonde used downstream (and the coefficient basis HC consumes)
# is the *unnormalized* tensor-Chebyshev:  V[i,α] = ∏_k T_{α_k}(x_{i,k}).
# The orthonormal basis used for the Christoffel kernel is
#   ψ_α(x) = ∏_k ψ_{α_k}(x_k), where ψ_0=1, ψ_k = √2·T_k  (k ≥ 1),
# so  ψ_α(x)² = 2^{nnz(α)} · ∏_k T_{α_k}(x_k)².

using Random: AbstractRNG, default_rng

"""
    christoffel_kernel_chebyshev(Λdata::AbstractMatrix{<:Integer}, x::AbstractVector{<:Real}) -> Float64

Reproducing-kernel diagonal `K_Λ(x) = Σ_{α ∈ Λ} ψ_α(x)²` for the orthonormal
tensor-Chebyshev (first-kind) basis on `[-1,1]^n`. `Λdata` is the multi-index
matrix (m × n; row j is the multi-index of monomial j).

O(m·n) per evaluation; uses the Chebyshev three-term recurrence.
"""
function christoffel_kernel_chebyshev(
    Λdata::AbstractMatrix{<:Integer},
    x::AbstractVector{<:Real},
)
    n = length(x)
    m = size(Λdata, 1)
    @assert size(Λdata, 2) == n "Λdata column count must equal length(x)"

    max_deg = maximum(Λdata)
    # Per-axis Chebyshev table:  T_tab[k+1, i] = T_k(x_i)   (Julia 1-indexed)
    T_tab = Matrix{Float64}(undef, max_deg + 1, n)
    @inbounds for i in 1:n
        xi = Float64(x[i])
        T_tab[1, i] = 1.0
        if max_deg >= 1
            T_tab[2, i] = xi
        end
        for k in 2:max_deg
            T_tab[k+1, i] = 2.0 * xi * T_tab[k, i] - T_tab[k-1, i]
        end
    end

    K_val = 0.0
    @inbounds for j in 1:m
        prod_sq = 1.0
        nnz = 0
        for k in 1:n
            αk = Int(Λdata[j, k])
            t = T_tab[αk+1, k]
            prod_sq *= t * t
            if αk >= 1
                nnz += 1
            end
        end
        K_val += (1 << nnz) * prod_sq   # 2^nnz · ∏ T_{α_k}(x_k)²
    end
    return K_val
end

"""
    christoffel_random_sample_chebyshev(n::Int, Λdata, K::Int; rng=default_rng())
        -> (S::Matrix{Float64} (K × n), sqrt_w::Vector{Float64} (K))

Draw `K` points i.i.d. from the product arcsine measure on `[-1,1]^n`
(which is the orthogonality measure for the first-kind Chebyshev basis),
and assign each point the Christoffel weight `w_i = m / K_Λ(x_i)`.

Returns the sample matrix (row = sample, column = dim — matches the
`N × n_dim` convention `lambda_vandermonde_original` expects) and the
**square-root** of the weights (suitable for left-multiplication on V and F
to build the weighted normal equations).

This is the "μ-sampling + Christoffel reweighting" variant — a slightly weaker
guarantee than the Cohen-Migliorati 2017 optimal-density sampling (which would
draw from `ν ∝ K_Λ · μ`), but trivial to implement and adequate for the E1
smoke. Upgrade to full optimal sampling is a follow-up if E1 passes.
"""
function christoffel_random_sample_chebyshev(
    n::Int,
    Λdata::AbstractMatrix{<:Integer},
    K::Int;
    rng::AbstractRNG = default_rng(),
)
    m = size(Λdata, 1)
    @assert size(Λdata, 2) == n
    S = Matrix{Float64}(undef, K, n)
    sqrt_w = Vector{Float64}(undef, K)
    @inbounds for i in 1:K
        for d in 1:n
            S[i, d] = cos(pi * rand(rng))   # arcsine: x = cos(π U), U ~ Unif(0,1)
        end
        x_i = @view S[i, :]
        K_x = christoffel_kernel_chebyshev(Λdata, x_i)
        sqrt_w[i] = sqrt(m / K_x)
    end
    return S, sqrt_w
end

"""
    christoffel_K_default(m::Int; oversampling_c=3.0) -> Int

Recommended sample count `K = ⌈c · m · log m⌉` (Cohen-Migliorati 2017,
constant `c` empirically 1-3 for tensor-Chebyshev with total-degree).
Default `c = 3.0` is conservative.
"""
function christoffel_K_default(m::Int; oversampling_c::Float64 = 3.0)
    return Int(ceil(oversampling_c * m * log(m)))
end

"""
    christoffel_fit_chebyshev(f, n::Int, d::Int;
                              K=nothing, oversampling_c=3.0,
                              rng=default_rng()) -> NamedTuple

Fit a degree-`d` total-degree polynomial approximant to `f: [-1,1]^n → ℝ`
via Christoffel-preconditioned weighted least squares.

Returns `(coeffs, Λdata, l2_residual, kappa_G, K_used, m, wall_s)`.

`coeffs[j]` is the coefficient of `∏_k T_{α_k}(x_k)` for multi-index
`α = Λdata[j, :]` — the same coefficient convention as the rest of globtim,
so the result can feed `construct_chebyshev_approx` / HC unchanged.

This is the Phase-1 standalone fit (no `MainGenerate` plumbing yet). The
Phase-2 audit-driver wiring will reuse `christoffel_random_sample_chebyshev`
and the weighted-normal-equations solve directly.
"""
function christoffel_fit_chebyshev(
    f,
    n::Int,
    d::Int;
    K::Union{Nothing,Int} = nothing,
    oversampling_c::Float64 = 3.0,
    rng::AbstractRNG = default_rng(),
)
    # Total-degree index set |α| ≤ d in n dimensions
    Λ = SupportGen(n, (:one_d_for_all, d))
    Λdata = Λ.data       # m × n matrix
    m = Λ.size[1]
    if K === nothing
        K = christoffel_K_default(m; oversampling_c = oversampling_c)
    end

    t0 = time()
    S, sqrt_w = christoffel_random_sample_chebyshev(n, Λdata, K; rng = rng)

    # Build V (K × m) using globtim's existing Vandermonde routine
    # lambda_vandermonde_original expects S as N × n_dim (row = sample).
    V = lambda_vandermonde_original(Λ, S; basis = :chebyshev)

    # Evaluate f at the K sample points (rows of S)
    F = Vector{Float64}(undef, K)
    @inbounds for i in 1:K
        F[i] = Float64(f(@view S[i, :]))
    end

    # Weighted LS — left-multiply rows of V, F by sqrt(W) then solve normal eq.
    Vw = sqrt_w .* V                      # K × m
    Fw = sqrt_w .* F                      # K
    G_w = Vw' * Vw                        # m × m
    rhs = Vw' * Fw                        # m

    kappa_G = LinearAlgebra.cond(G_w)
    prob = LinearSolve.LinearProblem(G_w, rhs)
    sol = LinearSolve.solve(prob, LinearSolve.LUFactorization())
    coeffs = sol.u

    # Weighted RMS residual (matches globtim's per-grid L² convention modulo
    # the weight normalisation; exact comparison with the tensor-grid baseline
    # requires evaluating the residual on a common quadrature set)
    resid = Vw * coeffs .- Fw
    l2_residual = sqrt(sum(abs2, resid) / sum(abs2, sqrt_w))

    wall_s = time() - t0
    return (
        coeffs = coeffs,
        Λdata = Λdata,
        l2_residual = l2_residual,
        kappa_G = kappa_G,
        K_used = K,
        m = m,
        wall_s = wall_s,
    )
end

# ── Adaptive-subdivision integration (Phase 2) ────────────────────────────────
#
# The audit driver (`adaptive_refine` → `process_subdomain` → `estimate_subdomain_error`)
# builds a (2d+1)^n tensor-Chebyshev grid per leaf, evaluates f at affine-
# mapped physical coords, then fits via unweighted normal equations.
#
# `christoffel_subdomain_fit` is the drop-in alternative: it Christoffel-
# samples on the subdomain's normalized `[-1,1]^n`, evaluates f at the same
# affine-mapped physical coords, and fits via weighted normal equations.
# Returns the same (coeffs, Lambda, samples_n×n_dim, f_values, l2, rel_l2,
# kappa) shape that `construct_polynomial_on_subdomain` consumers expect.
#
# Per the Phase-1 decision, the L²-tolerance subdivision predicate uses a
# plain Monte-Carlo estimator on the Christoffel samples themselves (option (b)
# in the plan, simpler than option (a) of building a separate verification
# grid). This is consistent because the same samples are drawn from the
# arcsine measure that defines the natural Chebyshev L² norm — so
# (1/K)·Σ residual_i² is the consistent estimator of ‖f-p‖²_{L²(μ_arcsine)}.

"""
    christoffel_subdomain_fit(f, subdomain, degree;
        oversampling_c=2.0, basis=:chebyshev, rng=default_rng(),
        thread_evals::Bool=false)

Per-leaf Christoffel-sampled fit. Used by `estimate_subdomain_error` when
`sampling = :christoffel`. The signature mirrors what the audit-driver
internal loop needs.

Returns NamedTuple:
- `samples::Matrix{Float64}`  — K × n_dim, normalized [-1,1]^n coords
- `f_values::Vector{Float64}` — K (with Inf→penalty replacement, same policy
  as `estimate_subdomain_error`)
- `coeffs::Vector{Float64}`   — m, in unnormalized tensor-Chebyshev basis
- `Lambda::NamedTuple`        — multi-index spec (data, size)
- `l2_error::Float64`         — sqrt((1/K) Σ residual²) — MC estimate of
  ‖f-p‖_{L²(μ_arcsine)}
- `relative_l2_error::Float64` — l2_error / sqrt((1/K) Σ f²)
- `kappa::Float64`            — κ(weighted Gram)
- `K_used::Int`               — number of samples
- `m::Int`                    — polynomial-space dimension
- `wall_s::Float64`           — total wall (eval + fit)

Currently only :chebyshev is supported (the :legendre case requires a
different orthonormal Christoffel kernel; deferred until needed).
"""
function christoffel_subdomain_fit(
    f,
    subdomain,
    degree;
    oversampling_c::Float64 = 2.0,
    basis::Symbol = :chebyshev,
    rng::AbstractRNG = default_rng(),
    thread_evals::Bool = false,
)
    basis == :chebyshev || error(
        "christoffel_subdomain_fit currently supports :chebyshev only; " *
        "got basis = $basis (Legendre Christoffel kernel deferred to follow-up)",
    )
    n_dim = length(subdomain.center)

    # Multi-index set (same convention as construct_polynomial_on_subdomain)
    d_spec = degree isa Tuple ? degree : (:one_d_for_all, degree)
    Lambda = SupportGen(n_dim, d_spec)
    Λdata = Lambda.data
    m = Lambda.size[1]
    K = christoffel_K_default(m; oversampling_c = oversampling_c)

    t0 = time()
    # Christoffel-sample in normalized [-1,1]^n
    S_norm, sqrt_w = christoffel_random_sample_chebyshev(n_dim, Λdata, K; rng = rng)

    # Evaluate f at affine-mapped physical coordinates
    f_values = Vector{Float64}(undef, K)
    if thread_evals && Threads.nthreads() > 1
        chunk_size = max(1, cld(K, 4 * Threads.nthreads()))
        @sync for chunk_start in 1:chunk_size:K
            chunk_end = min(chunk_start + chunk_size - 1, K)
            Threads.@spawn begin
                x_buf = Vector{Float64}(undef, n_dim)
                for k in chunk_start:chunk_end
                    @inbounds for d in 1:n_dim
                        x_buf[d] =
                            subdomain.center[d] + S_norm[k, d] * subdomain.half_widths[d]
                    end
                    f_values[k] = f(x_buf)
                end
            end
        end
    else
        x_physical = Vector{Float64}(undef, n_dim)
        for k in 1:K
            @inbounds for d in 1:n_dim
                x_physical[d] =
                    subdomain.center[d] + S_norm[k, d] * subdomain.half_widths[d]
            end
            f_values[k] = f(x_physical)
        end
    end

    # Handle Inf values (failed ODE integrations etc.) — same policy as
    # estimate_subdomain_error: replace with 10× max finite, mark infeasible
    # if all failed.
    n_inf = count(isinf, f_values)
    infeasible = false
    if n_inf == K
        infeasible = true
    elseif n_inf > 0
        finite_vals = filter(isfinite, f_values)
        penalty = 10.0 * maximum(abs, finite_vals)
        for i in 1:K
            if isinf(f_values[i])
                f_values[i] = penalty
            end
        end
    end

    if infeasible
        wall_s = time() - t0
        return (
            samples = S_norm,
            f_values = f_values,
            coeffs = Float64[],
            Lambda = Lambda,
            l2_error = Inf,
            relative_l2_error = Inf,
            kappa = Inf,
            K_used = K,
            m = m,
            wall_s = wall_s,
            infeasible = true,
        )
    end

    # Build Vandermonde and weighted-LS solve
    V = lambda_vandermonde_original(Lambda, S_norm; basis = :chebyshev)  # K × m
    Vw = sqrt_w .* V
    Fw = sqrt_w .* f_values
    G_w = Vw' * Vw
    rhs = Vw' * Fw
    kappa_G = LinearAlgebra.cond(G_w)
    coeffs = G_w \ rhs

    # Residual evaluated at the Christoffel samples (plain MC estimator of
    # ‖f - p‖_{L²(μ_arcsine)}; consistent because samples are from μ_arcsine).
    poly_values = V * coeffs
    residuals = f_values .- poly_values
    l2_error = sqrt(sum(abs2, residuals) / K)
    norm_f = sqrt(sum(abs2, f_values) / K)
    rel_l2 = norm_f > 0 ? l2_error / norm_f : (l2_error == 0.0 ? 0.0 : Inf)
    if isnan(l2_error)
        l2_error = Inf
        rel_l2 = Inf
    end

    wall_s = time() - t0
    return (
        samples = S_norm,
        f_values = f_values,
        coeffs = coeffs,
        Lambda = Lambda,
        l2_error = l2_error,
        relative_l2_error = rel_l2,
        kappa = kappa_G,
        K_used = K,
        m = m,
        wall_s = wall_s,
        infeasible = false,
    )
end
