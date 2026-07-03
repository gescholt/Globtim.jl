# per_cut_predicate_lsfit.jl
#
# E2 — Eibner-Melenk-style LS-slope ρ_k estimator (survey Thread E REFINE).
# Parallel to `pick_strategy_per_axis` in per_cut_predicate.jl. The current
# 2-point `decay_k = 0.5·log(m_d+2 / m_d+4)` is replaced by a least-squares
# fit `log(m_s) ~ -2·log(ρ_k)·s + const` over all available offender shells,
# giving (a) less noisy slope on noisy spectra, (b) an *interpretable*
# Bernstein-ellipse radius per axis that audit drivers can log per leaf.
#
# This file is opt-in (research probe). The default predicate threading
# remains `pick_strategy_per_axis`. See:
#   /home/georgy/.claude/plans/quizzical-knitting-cake.md  (E2 in tier 2)
#   experiments/sandbox/run_e2_synthetic_3d.jl             (validation driver)

"""
    LSFitAxisResult

Per-axis output of `pick_strategy_per_axis_lsfit` for a single leaf.

Fields:
- `verdict::Symbol`              — `:bump` or `:split`
- `rho::Float64`                 — Bernstein-ellipse parameter estimate; `NaN`
  when there is no signal (fewer than 2 populated shells in the restricted
  spectrum or all masses below the noise floor)
- `slope::Float64`               — raw OLS slope of `log(m_s)` vs shell `s`;
  related by `slope = -2·log(rho)`
- `n_shells::Int`                — number of shells that participated in the
  fit (informational; ≥ 2 required for `rho ≠ NaN`)
- `axis_mass::Float64`           — total restricted η²-mass on this axis
  (the same number used by `_per_axis_verdict` for the `mass_floor` gate)
"""
struct LSFitAxisResult
    verdict::Symbol
    rho::Float64
    slope::Float64
    n_shells::Int
    axis_mass::Float64
end

"""
    pick_strategy_per_axis_lsfit(subdomain::Subdomain;
        ρ_threshold::Real = exp(1.0),
        θ_concentration::Real = 0.5,
        extended_degree::Int = 0,
        axis_mass_floor::Real = 1e-12,
        shell_mass_floor::Real = 1e-32,
    ) -> Vector{LSFitAxisResult}

Per-axis verdict using an LS-slope ρ_k estimator (Eibner-Melenk-style).

For each axis k, restrict the residual mode spectrum to offender modes
`S_k = {α : α[k] = |α|_∞}` (same restriction as the existing 2-point
predicate). Sum η²-mass per shell s ∈ (base_d, extended_d]. Fit

    log(m_s) = -2·log(ρ_k)·s + intercept                    (OLS)

over all shells with `m_s > shell_mass_floor`. Bernstein-radius estimate:

    ρ_k = exp(-slope/2)

Bump-vs-split rule (matches the 2-pt predicate in spirit):

- If `axis_mass < axis_mass_floor` → `:bump` (no signal; legacy default).
- If fewer than 2 populated shells → `:bump` (cannot fit, fall back to
  legacy default).
- Concentration shortcut: if `m(d+1) + m(d+2) ≥ θ_concentration · total`,
  `:bump` (matches the existing rule — bumping +2 catches everything).
- Else: `:bump` iff `ρ_k ≥ ρ_threshold` (large analytic region — bumping
  pays off geometrically), `:split` otherwise (small analytic region or
  non-analytic — localize via subdivision).

Default `ρ_threshold = e ≈ 2.718` is a meaningful analyticity threshold:
ρ ≥ e means the next two degree-bumps reduce coefficient mass by ≥ e^2 ≈
7.4×. Below that, geometric returns on degree bumps slow down enough
that subdivision is the better lever.

The audit-driver caller can use the returned `Vector{LSFitAxisResult}`
either as a drop-in (call `decide_action` on the `.verdict` slice) or
to log `ρ_k` per leaf for survey Thread E measurement.
"""
function pick_strategy_per_axis_lsfit(
    subdomain::Subdomain;
    ρ_threshold::Real = exp(1.0),
    θ_concentration::Real = 0.5,
    extended_degree::Int = 0,
    axis_mass_floor::Real = 1e-12,
    shell_mass_floor::Real = 1e-32,
)
    if subdomain.polynomial === nothing
        return [
            LSFitAxisResult(:bump, NaN, NaN, 0, 0.0) for _ in 1:length(subdomain.center)
        ]
    end
    spec = subdomain_mode_spectrum(subdomain; extended_degree = extended_degree)
    return pick_strategy_per_axis_lsfit(
        spec;
        ρ_threshold = ρ_threshold,
        θ_concentration = θ_concentration,
        axis_mass_floor = axis_mass_floor,
        shell_mass_floor = shell_mass_floor,
    )
end

"""
    pick_strategy_per_axis_lsfit(spec::NamedTuple; ρ_threshold, θ_concentration,
                                 axis_mass_floor, shell_mass_floor)
        -> Vector{LSFitAxisResult}

Spectrum-accepting method: same LS-slope rule, operating on a precomputed
`compute_mode_spectrum` / `subdomain_mode_spectrum` result. The offender-mode
restriction is shared with `pick_strategy_per_axis` via `axis_shell_stats`
(bead 8f4p.5.1 DR-INSTR).
"""
function pick_strategy_per_axis_lsfit(
    spec::NamedTuple;
    ρ_threshold::Real = exp(1.0),
    θ_concentration::Real = 0.5,
    axis_mass_floor::Real = 1e-12,
    shell_mass_floor::Real = 1e-32,
)
    n_dim = size(spec.modes, 2)
    if n_dim == 0
        return [LSFitAxisResult(:bump, NaN, NaN, 0, 0.0)]
    end
    if isempty(spec.spectrum)
        return [LSFitAxisResult(:bump, NaN, NaN, 0, 0.0) for _ in 1:n_dim]
    end
    return [
        _per_axis_lsfit_verdict(
            stat,
            spec.base_degree;
            ρ_threshold = ρ_threshold,
            θ_concentration = θ_concentration,
            mass_floor = axis_mass_floor,
            shell_mass_floor = shell_mass_floor,
        ) for stat in axis_shell_stats(spec)
    ]
end

function _per_axis_lsfit_verdict(
    stat::NamedTuple,
    base_degree::Int;
    ρ_threshold::Real,
    θ_concentration::Real,
    mass_floor::Real,
    shell_mass_floor::Real,
)
    if stat.total < mass_floor
        return LSFitAxisResult(:bump, NaN, NaN, 0, stat.total)
    end

    slope, rho, n_used = _ls_slope_log(stat.shell_mass, base_degree, shell_mass_floor)

    # Concentration shortcut (matches 2-pt predicate): if mass at d+1, d+2
    # dominates, bumping +2 catches it regardless of geometric decay further
    # out. ρ is still reported for logging.
    if stat.concentration >= θ_concentration
        return LSFitAxisResult(:bump, rho, slope, n_used, stat.total)
    end

    if n_used < 2 || isnan(rho)
        # Fall back to legacy bump-default when we cannot estimate.
        return LSFitAxisResult(:bump, rho, slope, n_used, stat.total)
    end

    verdict = rho >= ρ_threshold ? :bump : :split
    return LSFitAxisResult(verdict, rho, slope, n_used, stat.total)
end

# OLS fit of `log(m_s) = slope · s + intercept` over shells with m_s > floor.
# Returns (slope, rho, n_used) where rho = exp(-slope/2).
# n_used < 2 ⇒ rho = NaN.
function _ls_slope_log(shell_mass::Dict{Int,Float64}, base_degree::Int, floor::Real)
    shells = sort!(collect(keys(shell_mass)))
    xs = Float64[]
    ys = Float64[]
    for s in shells
        m = shell_mass[s]
        if m > floor
            push!(xs, Float64(s))
            push!(ys, log(m))
        end
    end
    n = length(xs)
    if n < 2
        return (NaN, NaN, n)
    end
    x̄ = sum(xs) / n
    ȳ = sum(ys) / n
    num = 0.0
    den = 0.0
    @inbounds for i in 1:n
        Δx = xs[i] - x̄
        num += Δx * (ys[i] - ȳ)
        den += Δx * Δx
    end
    if den == 0.0
        return (NaN, NaN, n)
    end
    slope = num / den
    rho = exp(-slope / 2)
    return (slope, rho, n)
end

"""
    decide_action_lsfit(results::AbstractVector{LSFitAxisResult})
        -> (action::Symbol, cut_dim::Union{Int,Nothing})

Same combination rule as `decide_action`: any `:split` wins, lowest-indexed
ties win. Operates on the `.verdict` slice of an `LSFitAxisResult` vector.
"""
function decide_action_lsfit(results::AbstractVector{LSFitAxisResult})
    split_idx = findfirst(r -> r.verdict === :split, results)
    if split_idx === nothing
        return (:bump, nothing)
    else
        return (:split, split_idx)
    end
end

"""
    choose_per_dim_degree_lsfit(subdomain::Subdomain;
        c::Real = 4.0,
        floor_degree::Int = 2,
        max_degree::Int = 12,
        extended_degree::Int = 0,
        kwargs...) -> Vector{Int}

jl9z.7 — data-driven anisotropic per-axis degree from the per-axis Bernstein
radius ρ_k (the E2 LS-slope estimator, bead jaw4). For each axis the analytic
geometric-decay model says the coefficient mass on axis `k` decays like ρ_k^{-d},
so the degree needed to hit a fixed accuracy is

    d_k = ⌈ c / log(ρ_k) ⌉,   clamped to [floor_degree, max_degree].

A *flat / sloppy* axis has large ρ_k (fast decay) → small `d_k`; a steep axis has
ρ_k near 1 → large `d_k`. The **floor is the load-bearing lesson** from the CR3BP
relocated L4 5-D box: a sloppy axis is NOT degree 0/1. `lx_z` carries only 0.3% of
the gradient energy yet still needs `d ≥ 2` to *place* the deep optimum at
lx_z≈0.18 — `[6,6,1,1,1]` degrades (3.34e-2) while `[6,6,2,2,2]` does not
(1.60e-2). So `floor_degree` defaults to 2, never 0/1.

Axes with no usable signal (`ρ_k` is `NaN`, ≤ 1, or non-finite) fall back to
`max_degree` — the conservative choice (we have no evidence the axis is flat, so
don't starve it). Requires `subdomain.polynomial !== nothing`; the leaf must have
been fit (and `extended_degree` should exceed its base degree so offender shells
exist to fit the slope). `c` calibrates the accuracy target; `c=4` ⇒ a ρ=e axis
gets degree 4. Extra kwargs pass through to `pick_strategy_per_axis_lsfit`.
"""
function choose_per_dim_degree_lsfit(
    subdomain::Subdomain;
    c::Real = 4.0,
    floor_degree::Int = 2,
    max_degree::Int = 12,
    extended_degree::Int = 0,
    kwargs...,
)
    floor_degree >= 0 || error("floor_degree must be ≥ 0, got $floor_degree")
    floor_degree <= max_degree ||
        error("floor_degree=$floor_degree exceeds max_degree=$max_degree")
    results = pick_strategy_per_axis_lsfit(
        subdomain;
        extended_degree = extended_degree,
        kwargs...,
    )
    return [
        begin
            ρ = r.rho
            d = (!isfinite(ρ) || ρ <= 1.0) ? max_degree : ceil(Int, c / log(ρ))
            clamp(d, floor_degree, max_degree)
        end for r in results
    ]
end
