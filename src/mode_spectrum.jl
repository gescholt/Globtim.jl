# mode_spectrum.jl
# Per-Chebyshev-mode residual decomposition for adaptive subdivision (bead dksx.0).
#
# For a degree-d Chebyshev fit p of f on a leaf, the residual r = f - p has L2
# norm decomposable mode-wise: ‖r‖² = Σ_α |c_α(f)|² over multi-indices α with
# |α|_∞ > d. The current `relative_l2_error` is the SUM of these squared
# coefficients — a scalar. Keeping the per-mode vector preserves the same total
# energy AND tells us *where* the error sits in mode space.
#
# Empirically (see bead `dksx` epic), ODE-error landscapes cluster near the same
# scalar fingerprint L2(d=6)/L2(d=4) ≈ 0.62 regardless of family or radius —
# the scalar is uninformative within that cluster. The mode spectrum gives the
# missing discriminative power: bump-friendly fits concentrate residual mass at
# d+1, d+2; stagnant fits spread it across higher modes.

"""
    compute_mode_spectrum(poly::ApproxPoly; extended_degree::Int = 0,
                          rel_l2_squared::Real = NaN)

Compute the per-Chebyshev-mode residual coefficient spectrum η_α for the fit
`poly`, evaluated at multi-indices α with `base_degree < |α|_∞ ≤ extended_degree`,
where `base_degree = maximum(poly.support)` is the degree of the existing fit.

The residual `r = f - p` decomposes (in the orthogonal-basis idealization) as

    ‖r‖² = Σ_{|α|_∞ > base_degree} |c_α(f)|²

so `relative_l2_error² ≈ Σ η_α²` with `η_α = |c_α| / ‖f‖_L2`. This function
extracts the per-mode `η_α` *vector* by re-fitting on the existing samples at
the wider support `|α|_∞ ≤ extended_degree` and reading off the coefficients
on the new modes. **No new objective evaluations are made** — the marginal
cost is one Vandermonde build + one least-squares solve over the same grid.

# Arguments
- `poly::ApproxPoly`: a fit produced by `construct_polynomial_on_subdomain`
  (or any callsite that keeps `poly.grid` and `poly.z` populated).
- `extended_degree::Int = 0`: ceiling on `|α|_∞`. `0` means `2 * base_degree`
  (the maximum exactly representable on a 2d-degree-2d Chebyshev grid).
- `rel_l2_squared::Real = NaN`: optional. If provided, `window_coverage` in
  the result is set to `Σ η_α² / rel_l2_squared` — the fraction of residual
  squared-energy captured inside the visible window `|α|_∞ ≤ extended_degree`.
  Caller typically passes `subdomain.relative_l2_error^2`.

# Returns
A `NamedTuple` with fields:
- `spectrum::Vector{Float64}`: the η_α values for the new modes, length =
  number of multi-indices with `base_degree < |α|_∞ ≤ extended_degree`.
- `modes::Matrix{Int}`: parallel `(n_modes_new, n_dim)` matrix of the
  multi-indices α corresponding to `spectrum`.
- `dominant_mode::Vector{Int}`: argmax_α η_α (length n_dim).
- `spectral_concentration::Float64`: fraction of squared η-mass sitting in
  modes with `|α|_∞ ∈ {base_degree+1, base_degree+2}`. HIGH (≥ θ) suggests
  the residual lives just above the cutoff — a degree bump should catch it.
  LOW (< θ) suggests the residual is spread across many shells in the visible
  window. NOTE (dksx.0a finding): this metric alone is NOT a reliable
  bump-vs-split discriminator — see `shell_decay` and `window_coverage`.
- `shell_mass::Dict{Int,Float64}`: keys are `|α|_∞` shell indices in
  `(base_degree, extended_degree]`, values are summed η²-mass per shell.
- `shell_decay::Float64`: `0.5 * log(m(d+2) / m(d+4))` where `m(s)` is the
  η²-mass at shell `s`. POSITIVE ⇒ shell mass decreasing ⇒ a +2 degree bump
  catches most of the residual; NON-POSITIVE ⇒ mass holds or grows past d+2,
  bumping just shifts the problem to a worse shell (split is preferred).
  `NaN` if either shell is empty (e.g. functions with even-only symmetry
  produce `m(d+1) = m(d+3) = 0` — `shell_decay` between d+2 and d+4 stays
  defined, but `m(d+1)/m(d+2)` would not).
  DEPRECATED (bead 4vtd.1): comparing two fixed shells NaNs or reads roundoff
  garbage on single-parity residuals; prefer [`shell_decay_parity`](@ref),
  which `pick_strategy` now consumes. Kept for one release cycle.
- `window_coverage::Float64`: `Σ η_α² / rel_l2_squared` if `rel_l2_squared`
  was provided, else NaN. Values near 1 indicate the residual lives entirely
  inside the visible window; values ≪ 1 indicate a long high-frequency tail
  beyond `extended_degree` (split is preferred over a small degree bump).
  CAVEAT: η_α here are LS-fit coefficients, not strict Chebyshev-orthonormal
  coefficients (LS uses Euclidean inner product, not the weighted Chebyshev
  one), so this ratio is a relative comparison across leaves rather than a
  strict orthonormal energy fraction. Concretely it under-counts each mode's
  sample energy by `2^(#zero components of α)` — a dimension- and sparsity-
  dependent factor. DEPRECATED (bead 4vtd.2): prefer `window_coverage_sample`.
- `window_coverage_sample::Float64`: Parseval-true in-window energy fraction
  (bead 4vtd.2), computed from the residual AT THE CACHED SAMPLES with no
  unit mixing: `1 - ‖f - p_ext‖² / ‖f - p‖²` (Euclidean over the sample
  grid), where `p` is the existing base fit and `p_ext` the extended-window
  LS re-fit. Base span ⊆ extended span makes this exact Pythagoras, so the
  value is a true fraction in [0, 1] comparable across leaves, dimensions,
  and leaf sizes. A residual at the FP-roundoff floor (relative to `‖f‖²`)
  returns 1.0 — perfect coverage, never NaN. `NaN` only on the empty
  spectrum. NOTE: like every sample statistic it cannot see aliasing —
  energy beyond the grid's Nyquist band folds INTO the window and inflates
  the fraction; grid density is the only cure.
- `base_degree::Int`: the degree the fit was originally built at.
- `extended_degree::Int`: the actual ceiling used (may have been clamped if
  the sample grid did not support the requested ceiling).

If the sample grid is too small to support any extension beyond `base_degree`,
returns an empty spectrum (all zero summary statistics) — the caller should
treat this as "no signal available; fall back to default predicate."
"""
function compute_mode_spectrum(
    poly::ApproxPoly;
    extended_degree::Int = 0,
    rel_l2_squared::Real = NaN,
)
    if poly.support === nothing
        return _empty_mode_spectrum(0, 0, 0)
    end
    n_dim = size(poly.support, 2)
    base_degree = isempty(poly.support) ? 0 : Int(maximum(poly.support))

    # poly.grid is stored as (n_dim, n_samples); lambda_vandermonde wants
    # (n_samples, n_dim), matching `samples` in construct_polynomial_on_subdomain.
    samples = collect(poly.grid')
    f_values = poly.z

    n_samples = size(samples, 1)
    if n_samples == 0 || length(f_values) != n_samples
        return _empty_mode_spectrum(n_dim, base_degree, base_degree)
    end

    requested = extended_degree > 0 ? extended_degree : 2 * base_degree
    # Largest d such that the standard isotropic support (d+1)^n_dim does not
    # exceed the sample count — clamp so the LS solve stays well-posed.
    # Integer search avoids float-roundoff on n_dim'th roots: e.g. 729^(1/3)
    # in Float64 lands just below 9.0, so `floor(...) - 1` would give 7 here
    # when 8 is the true answer. Walk d up while (d+2)^n_dim ≤ n_samples.
    d_safe = 0
    while (d_safe + 2)^n_dim <= n_samples
        d_safe += 1
    end
    ext_d = min(requested, d_safe)
    if ext_d <= base_degree
        return _empty_mode_spectrum(n_dim, base_degree, base_degree)
    end

    Lambda_ext = SupportGen(n_dim, (:one_d_for_all, ext_d))
    V_ext = lambda_vandermonde(Lambda_ext, samples; basis = poly.basis)
    coeffs_ext = V_ext \ f_values

    # ‖f‖_L2 in the same Clenshaw–Curtis-like quadrature used by
    # estimate_subdomain_error: weight = ∏ 2 / (GN_d + 1) with GN_d = 2 d.
    per_dim_GN = fill(2 * base_degree, n_dim)
    weight = prod(2.0 ./ (per_dim_GN .+ 1))
    norm_f = sqrt(sum(abs2, f_values) * weight)
    norm_f_safe = norm_f > 0 ? norm_f : 1.0

    multi_indices = Lambda_ext.data
    n_modes = size(multi_indices, 1)
    excess_idx = Int[]
    for j in 1:n_modes
        max_alpha = 0
        for k in 1:n_dim
            v = Int(multi_indices[j, k])
            if v > max_alpha
                max_alpha = v
            end
        end
        if max_alpha > base_degree
            push!(excess_idx, j)
        end
    end
    if isempty(excess_idx)
        return _empty_mode_spectrum(n_dim, base_degree, ext_d)
    end

    eta = abs.(view(coeffs_ext, excess_idx)) ./ norm_f_safe
    excess_modes = Matrix{Int}(undef, length(excess_idx), n_dim)
    for (k, j) in enumerate(excess_idx)
        for d in 1:n_dim
            excess_modes[k, d] = Int(multi_indices[j, d])
        end
    end

    total_mass_sq = sum(abs2, eta)
    conc_mass_sq = 0.0
    shell_mass = Dict{Int,Float64}()
    @inbounds for k in eachindex(excess_idx)
        max_alpha = 0
        for d in 1:n_dim
            v = excess_modes[k, d]
            if v > max_alpha
                max_alpha = v
            end
        end
        η² = abs2(eta[k])
        shell_mass[max_alpha] = get(shell_mass, max_alpha, 0.0) + η²
        if max_alpha == base_degree + 1 || max_alpha == base_degree + 2
            conc_mass_sq += η²
        end
    end
    spectral_concentration = total_mass_sq > 0 ? conc_mass_sq / total_mass_sq : 0.0

    # Shell-decay across d+2 → d+4: the shells that matter for "does +2
    # degrees of bump catch the residual?". Even-symmetry functions populate
    # only even shells (Ackley, Griewank), so picking d+2 vs d+4 stays
    # defined for them while d+1 vs d+2 would compare a roundoff-zero shell
    # to a real one.
    m_dp2 = get(shell_mass, base_degree + 2, 0.0)
    m_dp4 = get(shell_mass, base_degree + 4, 0.0)
    shell_decay = (m_dp2 > 0 && m_dp4 > 0) ? 0.5 * log(m_dp2 / m_dp4) : NaN

    # Legacy window coverage: how much of the (squared) residual sits inside
    # the visible window. Requires the caller to pass relative_l2² since that
    # information is on the Subdomain, not the ApproxPoly. NaN signals "no
    # reference available, treat coverage as unknown."
    window_coverage = if isnan(rel_l2_squared) || rel_l2_squared <= 0
        NaN
    else
        total_mass_sq / Float64(rel_l2_squared)
    end

    # Sample-based (Parseval-true) window coverage (bead 4vtd.2): the fraction
    # of the base-fit residual's SAMPLE energy that the extended-window re-fit
    # absorbs. Both fits are LS projections onto nested spans, so Pythagoras
    # ‖f-p‖² = ‖f-p_ext‖² + ‖p_ext-p‖² holds exactly in the Euclidean sample
    # inner product and the fraction lives in [0, 1] (clamped for the
    # weighted/non-nested christoffel fit path, where it is approximate).
    # A residual at the FP-roundoff floor means the fit already converged at
    # the samples: coverage 1.0 by convention, never NaN.
    p_values = evaluate_polynomial_at_samples(poly, samples)
    total_res_sq = sum(abs2, f_values .- p_values)
    outside_res_sq = sum(abs2, f_values .- V_ext * coeffs_ext)
    window_coverage_sample = if total_res_sq <= 1e-28 * sum(abs2, f_values)
        1.0
    else
        clamp((total_res_sq - outside_res_sq) / total_res_sq, 0.0, 1.0)
    end

    dom_local_idx = argmax(eta)
    dominant_mode = collect(view(excess_modes, dom_local_idx, :))

    return (
        spectrum = collect(eta),
        modes = excess_modes,
        dominant_mode = dominant_mode,
        spectral_concentration = spectral_concentration,
        shell_mass = shell_mass,
        shell_decay = shell_decay,
        window_coverage = window_coverage,
        window_coverage_sample = window_coverage_sample,
        base_degree = base_degree,
        extended_degree = ext_d,
    )
end

function _empty_mode_spectrum(n_dim::Int, base_degree::Int, extended_degree::Int)
    return (
        spectrum = Float64[],
        modes = zeros(Int, 0, n_dim),
        dominant_mode = zeros(Int, n_dim),
        spectral_concentration = 0.0,
        shell_mass = Dict{Int,Float64}(),
        shell_decay = NaN,
        window_coverage = NaN,
        window_coverage_sample = NaN,
        base_degree = base_degree,
        extended_degree = extended_degree,
    )
end

"""
    subdomain_mode_spectrum(subdomain::Subdomain; extended_degree::Int = 0)

Non-mutating sibling of `compute_subdomain_mode_spectrum!`: compute the mode
spectrum for a leaf, passing `relative_l2_error²` through so `window_coverage`
is populated. If `subdomain.polynomial === nothing`, returns the empty
spectrum sized to the leaf dimension — downstream predicates then produce
their legacy all-`:bump` fallbacks, so calling any spectrum-accepting
predicate on this result matches calling its `Subdomain` method directly.

This is the single-compute entry point for callers that consult several
predicates per leaf (bead 8f4p.5.1 DR-INSTR): compute once here, then pass
the result to `pick_strategy`, `pick_strategy_per_axis`,
`pick_strategy_per_axis_lsfit`, and `axis_shell_stats`.
"""
function subdomain_mode_spectrum(subdomain::Subdomain; extended_degree::Int = 0)
    if subdomain.polynomial === nothing
        return _empty_mode_spectrum(length(subdomain.center), 0, 0)
    end
    rel_l2_squared =
        isfinite(subdomain.relative_l2_error) ? subdomain.relative_l2_error^2 : NaN
    return compute_mode_spectrum(
        subdomain.polynomial;
        extended_degree = extended_degree,
        rel_l2_squared = rel_l2_squared,
    )
end

"""
    shell_decay_parity(shell_mass::AbstractDict{Int,<:Real};
                       rtol_shell::Real = 1e-9, atol_total::Real = 1e-12)
    shell_decay_parity(spec::NamedTuple; ...)

Parity-stratified shell-decay rate (bead 4vtd.1): fit `m(s) ∝ λ^s` by least
squares on `log m(s)` vs `s` SEPARATELY over the even and the odd shells, so
single-parity residuals (even-symmetric functions like Ackley/Griewank
populate even shells only) get a finite rate instead of the NaN / roundoff
garbage the fixed-shell `shell_decay = 0.5·log(m(d+2)/m(d+4))` produces.
Units match the old scalar — the old scalar IS the 2-point even-pair fit —
so existing `θ_decay` thresholds carry over.

Shells whose mass is below `rtol_shell` of the total are treated as
unpopulated (FP-roundoff coefficients of the absent parity would otherwise
produce an arbitrary-sign garbage rate). A parity class with fewer than 2
populated shells gets `NaN`.

`combined` is the arithmetic mean of the finite parity rates (in log-rate
units, i.e. the geometric mean of the multiplicative per-shell factors), the
single finite one if only one parity is fittable, or `NaN` if neither is.

SENTINEL: an all-zero / empty `shell_mass` (total ≤ `atol_total` — a perfect
fit) returns `+Inf` for all three rates with `n_even = n_odd = 0`: the
residual has already decayed away, which any `θ_decay` threshold reads as
maximally bump-friendly — vacuously right on a converged leaf, and
distinguishable from "populated but unfittable" (`NaN`, `n_* ≥ 1`).

Returns `(decay_even, decay_odd, combined, n_even, n_odd)` where `n_*` count
the populated shells per parity.
"""
function shell_decay_parity(
    shell_mass::AbstractDict{Int,<:Real};
    rtol_shell::Real = 1e-9,
    atol_total::Real = 1e-12,
)
    total = 0.0
    for m in values(shell_mass)
        total += Float64(m)
    end
    if total <= atol_total
        return (decay_even = Inf, decay_odd = Inf, combined = Inf, n_even = 0, n_odd = 0)
    end

    floor_mass = rtol_shell * total
    s_even = Float64[]
    y_even = Float64[]
    s_odd = Float64[]
    y_odd = Float64[]
    for (s, m) in shell_mass
        m > floor_mass || continue
        if iseven(s)
            push!(s_even, s)
            push!(y_even, log(m))
        else
            push!(s_odd, s)
            push!(y_odd, log(m))
        end
    end

    decay_even = _parity_ls_decay(s_even, y_even)
    decay_odd = _parity_ls_decay(s_odd, y_odd)
    combined = if isfinite(decay_even) && isfinite(decay_odd)
        (decay_even + decay_odd) / 2
    elseif isfinite(decay_even)
        decay_even
    elseif isfinite(decay_odd)
        decay_odd
    else
        NaN
    end
    return (
        decay_even = decay_even,
        decay_odd = decay_odd,
        combined = combined,
        n_even = length(s_even),
        n_odd = length(s_odd),
    )
end

shell_decay_parity(spec::NamedTuple; kwargs...) =
    shell_decay_parity(spec.shell_mass; kwargs...)

# -slope of the LS line log m(s) = a + b·s over one parity class; NaN when the
# class has fewer than 2 populated shells. For exactly 2 shells (spacing 2)
# this reduces to 0.5·log(m(s₁)/m(s₂)) — the old fixed-shell scalar.
function _parity_ls_decay(s::Vector{Float64}, y::Vector{Float64})
    n = length(s)
    n >= 2 || return NaN
    s̄ = sum(s) / n
    ȳ = sum(y) / n
    num = 0.0
    den = 0.0
    @inbounds for i in 1:n
        ds = s[i] - s̄
        num += ds * (y[i] - ȳ)
        den += ds * ds
    end
    return -num / den
end

"""
    axis_shell_stats(spec::NamedTuple) -> Vector{NamedTuple}

Per-axis offender-restricted shell statistics from a `compute_mode_spectrum`
result, computed in one pass over the modes. For each axis k the spectrum is
restricted to the offender modes `S_k = {α : α[k] = |α|_∞}` (ties counted
toward every tied axis, matching `pick_strategy_per_axis` and
`pick_strategy_per_axis_lsfit`, which previously each redid this restriction).

Returns a length-`n_dim` vector of NamedTuples with fields:
- `shell_mass::Dict{Int,Float64}` — η²-mass per shell `s = |α|_∞` on axis k
- `total::Float64` — total restricted η²-mass (the `axis_mass_floor` gate input)
- `concentration::Float64` — `(m(d+1) + m(d+2)) / total`, `NaN` when `total == 0`
- `decay::Float64` — 2-pt `0.5·log(m(d+2)/m(d+4))` with the 4vtd.3 noise-floor
  guard (shells d+2, d+4 must jointly carry ≥ 1e-3 of the axis mass); `NaN`
  when undefined

Empty spectrum ⇒ per-axis zero masses with `NaN` concentration/decay.
"""
function axis_shell_stats(spec::NamedTuple)
    n_dim = size(spec.modes, 2)
    base_degree = spec.base_degree
    eta_sq = abs2.(spec.spectrum)
    n_modes = length(spec.spectrum)

    shell_masses = [Dict{Int,Float64}() for _ in 1:n_dim]
    totals = zeros(n_dim)
    @inbounds for j in 1:n_modes
        max_a = 0
        for k in 1:n_dim
            v = Int(spec.modes[j, k])
            if v > max_a
                max_a = v
            end
        end
        for d in 1:n_dim
            if Int(spec.modes[j, d]) == max_a
                shell_masses[d][max_a] = get(shell_masses[d], max_a, 0.0) + eta_sq[j]
                totals[d] += eta_sq[j]
            end
        end
    end

    return [
        begin
            sm = shell_masses[d]
            total = totals[d]
            conc_mass = get(sm, base_degree + 1, 0.0) + get(sm, base_degree + 2, 0.0)
            concentration = total > 0 ? conc_mass / total : NaN
            m_dp2 = get(sm, base_degree + 2, 0.0)
            m_dp4 = get(sm, base_degree + 4, 0.0)
            decay_signal_meaningful = (m_dp2 + m_dp4) >= 1e-3 * total
            decay =
                (total > 0 && decay_signal_meaningful && m_dp2 > 0 && m_dp4 > 0) ?
                0.5 * log(m_dp2 / m_dp4) : NaN
            (shell_mass = sm, total = total, concentration = concentration, decay = decay)
        end for d in 1:n_dim
    ]
end

"""
    compute_subdomain_mode_spectrum!(subdomain::Subdomain; extended_degree::Int = 0)

Convenience wrapper that calls `compute_mode_spectrum` on the subdomain's
cached polynomial and writes the summary fields back onto the subdomain:
`mode_spectrum`, `dominant_mode`, `spectral_concentration`. Returns the full
NamedTuple so callers that want the raw `modes` matrix can keep it.

If `subdomain.polynomial` is `nothing` (uncomputed leaf or infeasible region),
this no-ops and returns the empty-spectrum NamedTuple.
"""
function compute_subdomain_mode_spectrum!(subdomain::Subdomain; extended_degree::Int = 0)
    if subdomain.polynomial === nothing
        n_dim = length(subdomain.center)
        result = _empty_mode_spectrum(n_dim, 0, 0)
        subdomain.mode_spectrum = Float64[]
        subdomain.dominant_mode = zeros(Int, n_dim)
        subdomain.spectral_concentration = NaN
        return result
    end
    rel_l2_squared =
        isfinite(subdomain.relative_l2_error) ? subdomain.relative_l2_error^2 : NaN
    result = compute_mode_spectrum(
        subdomain.polynomial;
        extended_degree = extended_degree,
        rel_l2_squared = rel_l2_squared,
    )
    subdomain.mode_spectrum = result.spectrum
    subdomain.dominant_mode = collect(result.dominant_mode)
    subdomain.spectral_concentration = result.spectral_concentration
    return result
end
