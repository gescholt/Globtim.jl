# active_subspace.jl
#
# Stage 2 of the "non-zero-dimensional minima" program: the active-subspace
# ROTATION resolver for the sloppy-valley case. Given an objective whose hard
# structure is not axis-aligned (the CR3BP L4 5-D box is effectively 2-3D, active
# plane ≈ (lv_x,lv_y)), compute the gradient-covariance eigenbasis, rotate the
# box's coordinate frame to it (`Subdomain.transform = Q`), and assign anisotropic
# per-axis degree from the spectrum (high on active axes, floored ≥2 on the sloppy
# tail — the lx_z "sloppy-but-essential" lesson). The fit then happens in the frame
# where the active subspace aligns with axes, so anisotropic degree pays off
# maximally and the dim-N tensor-grid cost collapses.
#
# The covariance math is the same Constantine active-subspace primitive prototyped
# in experiments/sandbox/fold_indicator_probe.jl. Gradients are box-normalized
# (∇_ẑ f) by forward differences on the objective over a cell-centered grid (cells
# are interior so perturbations stay in-box). The rotation enters f-evaluation only
# through box_to_physical! (so it composes with the current frame).

using LinearAlgebra
using Statistics
using Base.Threads

# Interior cell-centers of the normalized box [-1,1]ⁿ: nⁿ points, each strictly
# inside a cell so a small forward step stays in-box (no boundary clamping).
function _cell_centers(n_dim::Int, n_cells::Int)
    ax = [-1.0 + 2.0 * (i - 0.5) / n_cells for i in 1:n_cells]
    pts = Vector{Vector{Float64}}(undef, n_cells^n_dim)
    @inbounds for lin in 0:(n_cells^n_dim-1)
        r = lin
        p = Vector{Float64}(undef, n_dim)
        for d in 1:n_dim
            p[d] = ax[r%n_cells+1]
            r ÷= n_cells
        end
        pts[lin+1] = p
    end
    return pts
end

# Box-normalized objective gradients g̃ = ∇_ẑ f at the cell centers (in the box's
# CURRENT frame; box_to_physical! applies any existing transform). Returns an
# (N × n_dim) matrix. Rows are written independently → thread-safe with no
# threadid() accumulation pitfall. Costs (n_dim+1)·nⁿ objective evaluations.
function _objective_cell_gradients(f, sd::Subdomain, n_cells::Int, h::Float64)
    n_dim = length(sd.center)
    pts = _cell_centers(n_dim, n_cells)
    N = length(pts)
    G = Matrix{Float64}(undef, N, n_dim)
    Threads.@threads for i in 1:N
        ẑ = pts[i]
        x0 = Vector{Float64}(undef, n_dim)
        box_to_physical!(x0, ẑ, sd)
        f0 = f(x0)
        xk = Vector{Float64}(undef, n_dim)
        zk = similar(ẑ)
        @inbounds for k in 1:n_dim
            step = ẑ[k] > 0 ? -h : h          # toward interior (normalized)
            copyto!(zk, ẑ)
            zk[k] += step
            box_to_physical!(xk, zk, sd)
            G[i, k] = (f(xk) - f0) / step       # ∂f/∂ẑ_k
        end
    end
    return G
end

# Active-subspace covariance C = mean over the FINITE gradient rows of g gᵀ, plus the
# (used, dropped) row counts. Real ODE objectives return Inf/NaN on infeasible inputs;
# a single non-finite gradient row would poison eigen(C) ("matrix contains Infs or
# NaNs"). Dropping the non-finite rows is NOT a silent fallback — the count is returned
# so every caller can surface it — and an all-non-finite grid RAISES (no usable signal).
function _finite_gradient_covariance(G::AbstractMatrix{<:Real})
    n_pts, n_dim = size(G)
    C = zeros(n_dim, n_dim)
    used = 0
    @inbounds for i in 1:n_pts
        ok = true
        for k in 1:n_dim
            isfinite(G[i, k]) || (ok = false; break)
        end
        ok || continue
        for a in 1:n_dim, b in 1:n_dim
            C[a, b] += G[i, a] * G[i, b]
        end
        used += 1
    end
    used == 0 && error(
        "active-subspace covariance: all $n_pts gradient samples were non-finite " *
        "(objective returned Inf/NaN across the whole grid) — cannot form C",
    )
    C ./= used
    return C, used, n_pts - used
end

"""
    gradient_covariance(f, sd::Subdomain; n_cells=5, h=0.01) -> Matrix{Float64}

The active-subspace matrix `C = mean(g̃ g̃ᵀ)` over box-normalized objective gradients
on a cell-centered grid of the leaf's box (Constantine). Its eigen-decomposition is
the active-subspace spectrum.

Cells where the objective is non-finite (Inf/NaN — infeasible parameters / failed
ODE solves) are dropped from the average; a `@warn` reports how many. If EVERY cell
is non-finite it raises (no usable signal). Use `rotate_to_active_frame!` if you need
the drop counts programmatically.
"""
function gradient_covariance(f, sd::Subdomain; n_cells::Int = 5, h::Float64 = 0.01)
    G = _objective_cell_gradients(f, sd, n_cells, h)
    C, used, dropped = _finite_gradient_covariance(G)
    dropped > 0 &&
        @warn "gradient_covariance: dropped $dropped/$(used + dropped) non-finite gradient samples (objective Inf/NaN on infeasible cells)"
    return C
end

"""
    active_subspace(C::AbstractMatrix{Float64}) -> (Q, eigenvalues, cum)

Eigen-decomposition of the active-subspace matrix `C`. Returns the eigenvectors `Q`
(columns, descending eigenvalue), the energy-normalized eigenvalues `eigenvalues`
(sum 1), and their cumulative sum `cum`. `Q[:,1]` is the dominant active direction;
using `Q` as `Subdomain.transform` makes normalized axis 1 align with it.
"""
function active_subspace(C::AbstractMatrix{Float64})
    n = size(C, 1)
    ev = eigen(Symmetric(Matrix(C)))
    ord = sortperm(ev.values; rev = true)
    λ = max.(ev.values[ord], 0.0)
    Q = Matrix(ev.vectors[:, ord])
    tot = sum(λ)
    frac = tot > 0 ? λ ./ tot : fill(0.0, n)
    return (Q, frac, cumsum(frac))
end

"""
    spectral_effective_dimension(eigenvalues; gap_dominance_min=1.5) -> NamedTuple

Threshold-free effective dimension of a sensitivity / active-subspace spectrum, so
"how many directions actually matter" is decided by the spectrum's own shape rather
than an arbitrary cumulative-energy cutoff (the cutoff is the source of the
"effectively 2- or 3-D?" ambiguity on the CR3BP box — at 0.90 it reads 2, at 0.95 it
reads 3). `eigenvalues` is the descending spectrum (e.g. `frac` from
[`active_subspace`](@ref)); it is renormalized internally, so it need not sum to 1.

Returns a NamedTuple. The dimension is reported three independent ways plus a flag:

- `participation::Float64` — participation ratio (effective rank) `(Σλ)² / Σλ²` ∈ [1, n]:
  `n` for a flat spectrum, `→1` for a single dominant direction. The primary
  *continuous* effective dimension (`n_round` is its rounding).
- `entropy::Float64` — spectral-entropy dimension `exp(−Σ pᵢ ln pᵢ)` ∈ [1, n], a second
  independent continuous estimate (agreement with `participation` is corroboration).
- `gap_dim::Int` — integer cutoff at the largest *multiplicative* drop
  `argmaxₖ log(λₖ/λₖ₊₁)`: the rank where the spectrum falls off a cliff.
- `gap_log_ratio::Float64` — magnitude of that dominant log-gap (how steep the cliff is).
- `gap_dominance::Float64` — dominant log-gap ÷ median log-gap. `≈1` ⇒ every step drops
  by the same factor (a geometric *sloppy* ramp with NO clean gap); `≫1` ⇒ one decisive
  separation.
- `n_round::Int` — `round(participation)` clamped to `[1, n]`: the recommended integer
  (drives the anisotropic-degree active block, [`anisotropic_degree_from_spectrum`](@ref)).
- `ambiguous::Bool` — the effective dimension is ill-posed: the estimators disagree
  (`|participation − gap_dim| > 1`) or there is no decisive gap
  (`gap_dominance < gap_dominance_min`). Sloppy parameter-estimation spectra (smooth
  decay over many decades) land here — exactly the regime where forcing one integer
  dimension is meaningless, so the caller should fall back to an isotropic / floored
  budget rather than trust a projected rank.
"""
function spectral_effective_dimension(
    eigenvalues::AbstractVector{<:Real};
    gap_dominance_min::Float64 = 1.5,
    floor_ratio::Float64 = 1e-12,
)
    λ = max.(float.(collect(eigenvalues)), 0.0)
    n = length(λ)
    n == 0 && return (
        participation = 0.0,
        entropy = 0.0,
        gap_dim = 0,
        gap_log_ratio = 0.0,
        gap_dominance = 1.0,
        n_round = 0,
        ambiguous = true,
    )
    tot = sum(λ)
    if tot <= 0   # no gradient signal anywhere ⇒ degenerate; report full dim, flag it
        return (
            participation = Float64(n),
            entropy = Float64(n),
            gap_dim = n,
            gap_log_ratio = 0.0,
            gap_dominance = 1.0,
            n_round = n,
            ambiguous = true,
        )
    end
    p = λ ./ tot
    participation = 1.0 / sum(abs2, p)              # Σp = 1 ⇒ PR = 1/Σp²
    H = 0.0
    @inbounds for pi in p
        pi > 0 && (H -= pi * log(pi))
    end
    entropy = exp(H)
    n_round = clamp(round(Int, participation), 1, n)
    if n == 1
        return (
            participation = participation,
            entropy = entropy,
            gap_dim = 1,
            gap_log_ratio = 0.0,
            gap_dominance = 1.0,
            n_round = 1,
            ambiguous = false,
        )
    end
    # Log-gaps between consecutive eigenvalues (floored so a hard zero gives a large
    # but finite gap = a clean rank cutoff there, not Inf).
    flo = floor_ratio * maximum(λ)
    gaps = Vector{Float64}(undef, n - 1)
    @inbounds for k in 1:(n-1)
        gaps[k] = log(max(λ[k], flo)) - log(max(λ[k+1], flo))   # ≥ 0 (descending)
    end
    gap_dim = argmax(gaps)
    gap_log_ratio = gaps[gap_dim]
    # Dominance = how far the top gap stands out from the OTHER gaps (not from all
    # gaps, which would include itself and make dominance ≡ 1 whenever there is a
    # single gap, i.e. n = 2). A lone gap is by definition fully decisive ⇒ Inf.
    others = deleteat!(copy(gaps), gap_dim)
    med = isempty(others) ? 0.0 : median(others)
    gap_dominance = med > 0 ? gap_log_ratio / med : Inf
    ambiguous = (abs(participation - gap_dim) > 1.0) || (gap_dominance < gap_dominance_min)
    return (
        participation = participation,
        entropy = entropy,
        gap_dim = gap_dim,
        gap_log_ratio = gap_log_ratio,
        gap_dominance = gap_dominance,
        n_round = n_round,
        ambiguous = ambiguous,
    )
end

"""
    anisotropic_degree_from_spectrum(eigenvalues, deg_max; floor_deg=2,
                                     active_cum=0.95, n_active=nothing)
        -> Vector{Int}

Per-axis degree from the (energy-normalized, descending) active-subspace spectrum,
in the ROTATED frame. The FLOOR is load-bearing — a sloppy axis is NOT degree 0/1
(lx_z carries 0.3% of the energy yet still needs d≥2 to place the optimum), so
`floor_deg` defaults to 2.

Two ways to choose how many leading directions are kept at `deg_max`:

- `n_active::Int` (preferred, *dimension-adaptive*): exactly the first `n_active`
  directions are active, the rest drop to `floor_deg`. Pass
  `spectral_effective_dimension(eigenvalues).n_round` to let the spectrum's own shape
  pick the rank — no arbitrary cutoff.
- `active_cum::Float64` (legacy cumulative-energy cutoff, used when `n_active===nothing`):
  directions stay at `deg_max` until the preceding cumulative energy reaches `active_cum`.
  Lower `active_cum` ⇒ fewer high-degree axes; e.g. on the CR3BP spectrum `[72,21,6,…]%`,
  `active_cum=0.90` ⇒ `[6,6,2,2,2]` (the proven pattern) and `0.95` ⇒ `[6,6,6,2,2]`. The
  threshold sensitivity here (2 vs 3 active axes) is precisely what `n_active` removes.
"""
function anisotropic_degree_from_spectrum(
    eigenvalues::AbstractVector{<:Real},
    deg_max::Int;
    floor_deg::Int = 2,
    active_cum::Float64 = 0.95,
    n_active::Union{Nothing,Int} = nothing,
)
    floor_deg >= 0 || error("floor_deg must be ≥ 0, got $floor_deg")
    floor_deg <= deg_max || error("floor_deg=$floor_deg exceeds deg_max=$deg_max")
    nλ = length(eigenvalues)
    degs = Vector{Int}(undef, nλ)
    if n_active !== nothing
        na = clamp(n_active, 0, nλ)
        @inbounds for k in 1:nλ
            degs[k] = k <= na ? deg_max : floor_deg
        end
        return degs
    end
    cum = cumsum(eigenvalues)
    @inbounds for k in eachindex(eigenvalues)
        prev = k == 1 ? 0.0 : cum[k-1]
        degs[k] = prev < active_cum ? deg_max : floor_deg
    end
    return degs
end

"""
    rotate_to_active_frame!(f, sd::Subdomain; n_cells=5, h=0.01, deg_max=6,
                            floor_deg=2, active_cum=0.95, degree_mode=:cumulative)
        -> (transform, eigenvalues, degrees, effective_dim, n_used, n_dropped)

Stage 2 root-first resolver: measure the active subspace of `f` on `sd`, set
`sd.transform` to its eigenbasis (composed with any existing frame), and set
`sd.per_dim_degree` to the spectrum-derived anisotropic degrees. After this the fit
on `sd` (and its inheriting children) happens in the rotated, anisotropic frame.
Raises if the eigenbasis is not orthonormal (no silent fallback).

`degree_mode` chooses how many leading axes get `deg_max`:
- `:cumulative` (default, back-compatible) — legacy `active_cum` energy cutoff.
- `:adaptive` — the threshold-free [`spectral_effective_dimension`](@ref) rank
  (`n_round`); `active_cum` is ignored. The returned `effective_dim` is the full
  estimator NamedTuple (or `nothing` under `:cumulative`).

`skip_if_ambiguous` (`:adaptive` only): when the spectral effective dimension is
flagged `ambiguous` (estimators disagree, or a geometric sloppy ramp with no
decisive gap), do NOT mutate `sd` — no rotation, no per-dim degrees — and return
with `degrees = nothing`. Forcing a projected rank on such a spectrum is
meaningless (see [`spectral_effective_dimension`](@ref)); the caller keeps its
isotropic budget instead. This is the jl9z.7 Stage-2 in-loop contract: the
subdivision loop must be able to consult the probe without committing to it.

`n_used`/`n_dropped` report how many cell gradients entered the covariance vs were
dropped as non-finite (infeasible parameters / failed ODE solves).
"""
function rotate_to_active_frame!(
    f,
    sd::Subdomain;
    n_cells::Int = 5,
    h::Float64 = 0.01,
    deg_max::Int = 6,
    floor_deg::Int = 2,
    active_cum::Float64 = 0.95,
    degree_mode::Symbol = :cumulative,
    skip_if_ambiguous::Bool = false,
)
    degree_mode in (:cumulative, :adaptive) || error(
        "rotate_to_active_frame!: unknown degree_mode $(degree_mode) (expected :cumulative or :adaptive)",
    )
    skip_if_ambiguous &&
        degree_mode !== :adaptive &&
        error("rotate_to_active_frame!: skip_if_ambiguous requires degree_mode = :adaptive")
    n = length(sd.center)
    G = _objective_cell_gradients(f, sd, n_cells, h)
    C, n_used, n_dropped = _finite_gradient_covariance(G)
    n_dropped > 0 &&
        @warn "rotate_to_active_frame!: dropped $n_dropped/$(n_used + n_dropped) non-finite gradient samples (objective Inf/NaN on infeasible cells)"
    Q, frac, _ = active_subspace(C)
    # Decide BEFORE mutating: under skip_if_ambiguous an ambiguous spectrum must
    # leave `sd` untouched (no half-installed rotation).
    eff = nothing
    degs = nothing
    if degree_mode === :adaptive
        eff = spectral_effective_dimension(frac)
        if !(skip_if_ambiguous && eff.ambiguous)
            degs = anisotropic_degree_from_spectrum(
                frac,
                deg_max;
                floor_deg = floor_deg,
                n_active = eff.n_round,
            )
        end
    else
        degs = anisotropic_degree_from_spectrum(
            frac,
            deg_max;
            floor_deg = floor_deg,
            active_cum = active_cum,
        )
    end
    if degs === nothing
        return (
            transform = nothing,
            eigenvalues = frac,
            degrees = nothing,
            effective_dim = eff,
            n_used = n_used,
            n_dropped = n_dropped,
        )
    end
    # Eigenvectors are in the box's CURRENT frame; compose with it to land in the
    # original physical frame: physical = center + (T·Q)·(ẑ .* half_widths).
    Qtot = sd.transform === nothing ? Q : sd.transform * Q
    _validate_transform(Qtot, n)
    sd.transform = Qtot
    sd.per_dim_degree = degs
    return (
        transform = Qtot,
        eigenvalues = frac,
        degrees = degs,
        effective_dim = eff,
        n_used = n_used,
        n_dropped = n_dropped,
    )
end

"""
    fold_normal_coherence(f, sd::Subdomain; n_cells=5, h=0.01, top_q=0.05)
        -> (coherence, normal)

Stage 3 primitive: among the top-`‖g̃‖` cell centers, the leading-eigenvalue fraction
of `Σ ĝ ĝᵀ` (∈ [1/n, 1]; ≈1 ⇒ a single coherent non-axis sheet — a fold) and the
dominant fold normal (box-normalized). Reuses the detector's `_fold_coherence`.
"""
function fold_normal_coherence(
    f,
    sd::Subdomain;
    n_cells::Int = 5,
    h::Float64 = 0.01,
    top_q::Float64 = 0.05,
)
    G = _objective_cell_gradients(f, sd, n_cells, h)
    coh, normal, _ = _fold_coherence(G, top_q)
    return (coh, normal)
end
