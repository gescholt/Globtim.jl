# degeneracy_detector.jl
#
# Stage 0 LOGIC for the "non-zero-dimensional minima" program (the TYPE is in
# degeneracy_types.jl, included earlier). A cheap per-leaf classifier that decides
# which phenomenon defeats the isolated-critical-point assumption on a leaf, so the
# resolvers (anisotropic degree, active-subspace projection, oblique cuts,
# regularize-to-Morse) can act on the verdict.
#
# The active-subspace + fold-coherence math is lifted from
# experiments/sandbox/fold_indicator_probe.jl (the probe that proved the CR3BP L4
# box is effectively 2-D). The Hessian n_zero rule mirrors
# globtimpostprocessing/src/CriticalPointClassification.jl `_classify_eigenvalues_sub`
# EXACTLY (intentional duplication: globtim must not depend on postprocessing —
# the one-way rule — and the cheap test is just ForwardDiff on the polynomial).
#
# Default gradient source is the FITTED POLYNOMIAL (AD on `p` at the cached
# samples) ⇒ ZERO extra objective evaluations. An opt-in `:objective` source uses
# forward differences on `f` for the fold-suspect case where the fit itself is
# unreliable.

using LinearAlgebra
using Statistics

# Evaluate the FITTED subdomain polynomial at scattered normalized points. NOTE:
# the subdomain fit and `evaluate_polynomial_at_samples` share the
# `lambda_vandermonde` basis convention; `ApproxPolyEval.evaluate` does NOT
# (different normalization), so the detector must go through this path. We call
# `lambda_vandermonde_original` directly (the correct scattered-point evaluator —
# the detector's FD perturbations are not a tensor grid) to avoid the tensor-grid
# fallback warning. Pure polynomial — no objective calls.
@inline function _vander_eval(pol::ApproxPoly, P::AbstractMatrix{Float64})
    Lambda = SupportGen(size(P, 2), pol.degree)
    V = lambda_vandermonde_original(Lambda, P; basis = pol.basis)
    return V * pol.coeffs
end

@inline _peval1(pol::ApproxPoly, z::AbstractVector{<:Real}) =
    _vander_eval(pol, reshape(collect(Float64, z), 1, length(z)))[1]

# Box-normalized gradients g̃ = ∇_ẑ p at the leaf's cached (normalized [-1,1])
# samples, by central finite differences on the fitted polynomial (consistent
# basis, zero objective calls). Returns an (n_points × n_dim) matrix. Perturbations
# stay in the polynomial's analytic continuation (it extrapolates fine), so no
# in-box clamping is needed. `p` is smooth ⇒ FD is accurate.
function _leaf_box_gradients(sd::Subdomain; h::Float64 = 1e-4)
    pol = sd.polynomial
    S = sd.samples
    n_pts, n_dim = size(S)
    # Batch all ±h·e_k perturbations into one Vandermonde evaluation.
    P = Matrix{Float64}(undef, 2 * n_pts * n_dim, n_dim)
    row = 1
    @inbounds for i in 1:n_pts, k in 1:n_dim, s in (1.0, -1.0)
        for d in 1:n_dim
            P[row, d] = S[i, d]
        end
        P[row, k] += s * h
        row += 1
    end
    vals = _vander_eval(pol, P)
    G = Matrix{Float64}(undef, n_pts, n_dim)
    row = 1
    @inbounds for i in 1:n_pts, k in 1:n_dim
        G[i, k] = (vals[row] - vals[row+1]) / (2h)   # (p(+h) − p(−h)) / 2h
        row += 2
    end
    return G
end

# Opt-in objective-gradient source: forward differences on `f` at the cached
# samples, stepping toward the box interior so perturbations stay in-box. Needs
# `(n_dim+1)` extra `f` calls per sample — only for the fold-suspect case.
function _objective_box_gradients(f, sd::Subdomain, h::Float64)
    samples = sd.samples
    n_pts, n_dim = size(samples)
    hw = sd.half_widths
    ctr = sd.center
    G = Matrix{Float64}(undef, n_pts, n_dim)
    @inbounds for i in 1:n_pts
        ẑ = collect(@view samples[i, :])
        x0 = ctr .+ ẑ .* hw
        f0 = f(x0)
        for k in 1:n_dim
            step = ẑ[k] > 0 ? -h : h     # toward interior (normalized fraction of box)
            zk = copy(ẑ)
            zk[k] += step
            xk = ctr .+ zk .* hw
            G[i, k] = (f(xk) - f0) / step
        end
    end
    return G
end

# Active-subspace spectrum of C = mean(g̃ g̃ᵀ): energy-normalized eigenvalues
# (descending), eigenvectors, and the #dirs holding cum95 / cum_eff of the energy.
function _active_subspace(G::AbstractMatrix{Float64}, cum95::Float64, cum_eff::Float64)
    n_dim = size(G, 2)
    C = (G' * G) ./ max(size(G, 1), 1)
    ev = eigen(Symmetric(Matrix(C)))
    order = sortperm(ev.values; rev = true)
    λ = max.(ev.values[order], 0.0)
    V = ev.vectors[:, order]
    tot = sum(λ)
    frac = tot > 0 ? λ ./ tot : fill(0.0, n_dim)
    cum = cumsum(frac)
    a95 = something(findfirst(>=(cum95), cum), n_dim)
    aeff = something(findfirst(>=(cum_eff), cum), n_dim)
    return frac, Matrix(V), a95, aeff
end

# Fold-normal coherence among the top-‖g̃‖ points: leading-eigenvalue fraction of
# Σ ĝ ĝᵀ (∈ [1/n, 1]; 1 = single flat sheet) and the dominant fold normal.
# Also returns the per-point ‖g̃‖ for the spike statistics.
function _fold_coherence(G::AbstractMatrix{Float64}, topq::Float64)
    n_pts, n_dim = size(G)
    normg = [norm(@view G[i, :]) for i in 1:n_pts]
    order = sortperm(normg; rev = true)
    ntop = max(1, round(Int, topq * n_pts))
    top = order[1:min(ntop, n_pts)]
    M = zeros(n_dim, n_dim)
    cnt = 0
    @inbounds for i in top
        normg[i] <= 0 && continue
        u = (@view G[i, :]) ./ normg[i]
        M .+= u * u'
        cnt += 1
    end
    cnt == 0 && return (NaN, zeros(n_dim), normg)
    M ./= cnt
    evM = eigen(Symmetric(M))
    λM = evM.values
    coh = sum(λM) > 0 ? maximum(λM) / sum(λM) : NaN
    normal = evM.vectors[:, argmax(λM)]
    return (coh, normal, normg)
end

# Hessian eigenvalue signature of the polynomial at a critical point given in
# NORMALIZED [-1,1] coords (the frame `evaluate_polynomial_at_samples` uses; the
# diagonal box scaling is a congruence, so by Sylvester's law it preserves the
# eigenvalue inertia — n_pos/n_neg/n_zero — that the verdict relies on). Computed
# by central finite differences on the fitted polynomial. The n_zero rule mirrors
# _classify_eigenvalues_sub for cross-package parity.
function _poly_hessian_signature(
    poly::ApproxPoly,
    cp::AbstractVector{<:Real};
    tol::Float64 = 1e-6,
    relative_tol::Float64 = 0.0,
    h::Float64 = 1e-3,
)
    n = length(cp)
    z = collect(Float64, cp)
    H = zeros(n, n)
    f0 = _peval1(poly, z)
    for k in 1:n
        zp = copy(z); zp[k] += h
        zm = copy(z); zm[k] -= h
        H[k, k] = (_peval1(poly, zp) - 2 * f0 + _peval1(poly, zm)) / h^2
    end
    for k in 1:n, l in (k+1):n
        zpp = copy(z); zpp[k] += h; zpp[l] += h
        zpm = copy(z); zpm[k] += h; zpm[l] -= h
        zmp = copy(z); zmp[k] -= h; zmp[l] += h
        zmm = copy(z); zmm[k] -= h; zmm[l] -= h
        H[k, l] = H[l, k] =
            (_peval1(poly, zpp) - _peval1(poly, zpm) - _peval1(poly, zmp) +
             _peval1(poly, zmm)) / (4 * h^2)
    end
    eig = sort(eigvals(Symmetric(H)))
    effective_tol =
        (relative_tol > 0.0 && !isempty(eig)) ? max(tol, relative_tol * maximum(abs, eig)) :
        tol
    n_pos = count(λ -> λ > effective_tol, eig)
    n_neg = count(λ -> λ < -effective_tol, eig)
    n_zero = count(λ -> abs(λ) <= effective_tol, eig)
    max_abs = maximum(abs, eig)
    min_abs = minimum(abs, eig)
    cond = min_abs > 1e-30 ? max_abs / min_abs : Inf
    return (eigenvalues = eig, n_pos = n_pos, n_neg = n_neg, n_zero = n_zero, cond = cond)
end

# Intrinsic dimension of a critical-point cluster via PCA (SVD of the centered
# coordinate matrix). A curve of minimizers → 1, a surface → 2. -1 if <2 points.
function _cluster_intrinsic_dim(
    cps::Vector{Vector{Float64}};
    rel_thresh::Float64 = 0.1,
)
    length(cps) < 2 && return -1
    X = permutedims(reduce(hcat, cps))     # (n_cps × n_dim)
    μ = vec(mean(X; dims = 1))
    Xc = X .- μ'
    s = svdvals(Xc)
    (isempty(s) || maximum(s) <= 0) && return 0
    return count(>(rel_thresh * maximum(s)), s)
end

# The 5-way verdict (+ :undetermined). See degeneracy_types.jl for the taxonomy.
function _degeneracy_verdict(
    n_dim::Int,
    a95::Int,
    coh::Float64,
    spike::Float64,
    rel_l2::Float64,
    n_zero::Int,
    cdim::Int;
    k_sloppy::Int,
    coh_threshold::Float64,
    spike_threshold::Float64,
    fold_rel_l2::Float64,
)
    # 1. genuine positive-dimensional argmin: a degenerate-Hessian CP whose kernel
    #    is matched by a low-dimensional CP necklace (both signals required).
    if n_zero >= 1 && cdim >= 1
        return :positive_dim_argmin
    end
    is_spiky = isfinite(spike) && spike >= spike_threshold
    poor_fit = isfinite(rel_l2) && rel_l2 >= fold_rel_l2
    coherent = isfinite(coh) && coh >= coh_threshold
    nonsmooth = is_spiky || poor_fit       # the fit can't capture a crease
    # 2/3. a non-smooth leaf: a single coherent sheet is a fold; otherwise it is
    #      curved / multi-sheet.
    if nonsmooth
        return coherent ? :fold_caustic : :multi_sheet
    end
    # 4. smooth + active subspace collapses ⇒ sloppy valley (isolated argmin,
    #    near-flat directions). This is the CR3BP case.
    if a95 <= k_sloppy
        return :sloppy_valley
    end
    # 5. full-rank, smooth ⇒ ordinary isolated Morse structure.
    return :isolated_morse
end

"""
    detect_degeneracy!(sd::Subdomain; kwargs...) -> DegeneracyDiagnostics

Classify the degeneracy phenomenon on a fitted leaf and store the verdict in
`sd.degeneracy` (mirrors how `compute_subdomain_mode_spectrum!` fills the spectral
fields). Non-terminal: it only annotates — the resolvers read the verdict.

Cheap by default: gradients come from AD on the already-fitted polynomial at the
cached samples (`gradient_source = :polynomial`) ⇒ **zero extra objective calls**.
Pass `gradient_source = :objective` with `f` to forward-difference the objective
instead (for the fold-suspect case where the fit is unreliable).

When critical points `cps` are supplied (post-solve), the Hessian signature at the
best CP and the PCA intrinsic dimension of the CP cluster are added, enabling the
`:positive_dim_argmin` verdict.

# Keyword arguments
- `cps`, `f`, `gradient_source` — as above.
- `cum95 = 0.95`, `cum_eff = 0.99` — active-subspace cumulative-energy thresholds.
- `topq = 0.05` — top-gradient fraction for fold coherence.
- `coh_threshold = 0.7` — coherence above which a non-smooth leaf is a single sheet.
- `spike_threshold = 6.0` — ‖g̃‖ p99/median ratio flagging a gradient spike.
- `fold_rel_l2 = 0.05` — relative-L2 above which the fit is "poor" (crease/Gibbs).
- `hessian_tol = 1e-6`, `hessian_relative_tol = 0.0` — zero-eigenvalue rule (parity
  with `classify_cp_on_approximant`).
- `cluster_rel_thresh = 0.1` — PCA singular-value cutoff for cluster intrinsic dim.
- `fd_h = 0.01` — normalized forward-difference step for `:objective` gradients.
"""
function detect_degeneracy!(
    sd::Subdomain;
    cps::Union{Nothing,Vector{Vector{Float64}}} = nothing,
    f = nothing,
    gradient_source::Symbol = :polynomial,
    cum95::Float64 = 0.95,
    cum_eff::Float64 = 0.99,
    topq::Float64 = 0.05,
    coh_threshold::Float64 = 0.7,
    spike_threshold::Float64 = 6.0,
    fold_rel_l2::Float64 = 0.05,
    hessian_tol::Float64 = 1e-6,
    hessian_relative_tol::Float64 = 0.0,
    cluster_rel_thresh::Float64 = 0.1,
    fd_h::Float64 = 0.01,
)
    n_dim = length(sd.center)

    # No fit / no samples → nothing to analyze.
    if sd.polynomial === nothing || sd.samples === nothing || size(sd.samples, 1) == 0
        sd.degeneracy = DegeneracyDiagnostics(
            :undetermined, Float64[], 0, 0, zeros(n_dim, 0), NaN, zeros(n_dim),
            -1, NaN, -1, Dict{Symbol,Float64}(),
        )
        return sd.degeneracy
    end

    G =
        (gradient_source === :objective && f !== nothing) ?
        _objective_box_gradients(f, sd, fd_h) : _leaf_box_gradients(sd)

    frac, V, a95, aeff = _active_subspace(G, cum95, cum_eff)
    coh, normal, normg = _fold_coherence(G, topq)
    med = isempty(normg) ? 0.0 : median(normg)
    p99 = isempty(normg) ? 0.0 : quantile(normg, 0.99)
    spike = med > 0 ? p99 / med : Inf
    rel_l2 = isfinite(sd.relative_l2_error) ? sd.relative_l2_error : NaN

    # Post-solve signals (only when critical points are supplied). CPs arrive in
    # PHYSICAL coords; convert to the leaf's normalized frame for the polynomial
    # evaluations (z = (x − center) ./ half_widths).
    n_zero = -1
    hcond = NaN
    if cps !== nothing && !isempty(cps)
        to_norm(c) = (c .- sd.center) ./ sd.half_widths
        best = argmin([_peval1(sd.polynomial, to_norm(c)) for c in cps])
        sig = _poly_hessian_signature(
            sd.polynomial, to_norm(cps[best]);
            tol = hessian_tol, relative_tol = hessian_relative_tol,
        )
        n_zero = sig.n_zero
        hcond = sig.cond
    end
    cdim = cps === nothing ? -1 : _cluster_intrinsic_dim(cps; rel_thresh = cluster_rel_thresh)

    verdict = _degeneracy_verdict(
        n_dim, a95, coh, spike, rel_l2, n_zero, cdim;
        k_sloppy = cld(n_dim, 2),
        coh_threshold = coh_threshold,
        spike_threshold = spike_threshold,
        fold_rel_l2 = fold_rel_l2,
    )

    signals = Dict{Symbol,Float64}(
        :spike_ratio => spike,
        :median_grad => med,
        :p99_grad => p99,
        :rel_l2 => rel_l2,
        :n_points => Float64(size(G, 1)),
    )
    sd.degeneracy = DegeneracyDiagnostics(
        verdict, frac, a95, aeff, V, coh, normal, n_zero, hcond, cdim, signals,
    )
    return sd.degeneracy
end
