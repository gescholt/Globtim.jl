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

    rel_l2_squared =
        isfinite(subdomain.relative_l2_error) ? subdomain.relative_l2_error^2 : NaN
    spec = compute_mode_spectrum(
        subdomain.polynomial;
        extended_degree = extended_degree,
        rel_l2_squared = rel_l2_squared,
    )
    n_dim = size(spec.modes, 2)
    if n_dim == 0
        return [LSFitAxisResult(:bump, NaN, NaN, 0, 0.0)]
    end
    if isempty(spec.spectrum)
        return [LSFitAxisResult(:bump, NaN, NaN, 0, 0.0) for _ in 1:n_dim]
    end

    base_degree = spec.base_degree
    eta_sq = abs2.(spec.spectrum)
    n_modes = length(spec.spectrum)

    out = Vector{LSFitAxisResult}(undef, n_dim)
    for d in 1:n_dim
        out[d] = _per_axis_lsfit_verdict(
            spec.modes,
            eta_sq,
            n_modes,
            d,
            base_degree;
            ρ_threshold = ρ_threshold,
            θ_concentration = θ_concentration,
            mass_floor = axis_mass_floor,
            shell_mass_floor = shell_mass_floor,
        )
    end
    return out
end

function _per_axis_lsfit_verdict(
    modes::AbstractMatrix{Int},
    eta_sq::AbstractVector{Float64},
    n_modes::Int,
    d::Int,
    base_degree::Int;
    ρ_threshold::Real,
    θ_concentration::Real,
    mass_floor::Real,
    shell_mass_floor::Real,
)
    n_dim = size(modes, 2)
    axis_shell_mass = Dict{Int,Float64}()
    axis_total = 0.0
    @inbounds for j in 1:n_modes
        max_a = 0
        for k in 1:n_dim
            v = Int(modes[j, k])
            if v > max_a
                max_a = v
            end
        end
        if Int(modes[j, d]) == max_a
            axis_shell_mass[max_a] = get(axis_shell_mass, max_a, 0.0) + eta_sq[j]
            axis_total += eta_sq[j]
        end
    end

    if axis_total < mass_floor
        return LSFitAxisResult(:bump, NaN, NaN, 0, axis_total)
    end

    # Concentration shortcut (matches 2-pt predicate): if mass at d+1, d+2
    # dominates, bumping +2 catches it regardless of geometric decay further out.
    conc_mass =
        get(axis_shell_mass, base_degree + 1, 0.0) +
        get(axis_shell_mass, base_degree + 2, 0.0)
    concentration = conc_mass / axis_total
    if concentration >= θ_concentration
        # Bump regardless of ρ. Still compute ρ for logging.
        slope, rho, n_used = _ls_slope_log(axis_shell_mass, base_degree, shell_mass_floor)
        return LSFitAxisResult(:bump, rho, slope, n_used, axis_total)
    end

    # General case: LS-slope on log shell mass.
    slope, rho, n_used = _ls_slope_log(axis_shell_mass, base_degree, shell_mass_floor)
    if n_used < 2 || isnan(rho)
        # Fall back to legacy bump-default when we cannot estimate.
        return LSFitAxisResult(:bump, rho, slope, n_used, axis_total)
    end

    verdict = rho >= ρ_threshold ? :bump : :split
    return LSFitAxisResult(verdict, rho, slope, n_used, axis_total)
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
