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
    compute_mode_spectrum(poly::ApproxPoly; extended_degree::Int = 0)

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
  LOW (< θ) suggests the residual is spread to high frequencies — a smaller
  leaf (split) is more efficient than chasing higher degrees.
- `base_degree::Int`: the degree the fit was originally built at.
- `extended_degree::Int`: the actual ceiling used (may have been clamped if
  the sample grid did not support the requested ceiling).

If the sample grid is too small to support any extension beyond `base_degree`,
returns an empty spectrum (all zero summary statistics) — the caller should
treat this as "no signal available; fall back to default predicate."
"""
function compute_mode_spectrum(poly::ApproxPoly; extended_degree::Int = 0)
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
    d_safe = max(0, floor(Int, n_samples^(1 / n_dim)) - 1)
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
    @inbounds for k in eachindex(excess_idx)
        max_alpha = 0
        for d in 1:n_dim
            v = excess_modes[k, d]
            if v > max_alpha
                max_alpha = v
            end
        end
        if max_alpha == base_degree + 1 || max_alpha == base_degree + 2
            conc_mass_sq += abs2(eta[k])
        end
    end
    spectral_concentration = total_mass_sq > 0 ? conc_mass_sq / total_mass_sq : 0.0

    dom_local_idx = argmax(eta)
    dominant_mode = collect(view(excess_modes, dom_local_idx, :))

    return (
        spectrum = collect(eta),
        modes = excess_modes,
        dominant_mode = dominant_mode,
        spectral_concentration = spectral_concentration,
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
        base_degree = base_degree,
        extended_degree = extended_degree,
    )
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
function compute_subdomain_mode_spectrum!(
    subdomain::Subdomain;
    extended_degree::Int = 0,
)
    if subdomain.polynomial === nothing
        n_dim = length(subdomain.center)
        result = _empty_mode_spectrum(n_dim, 0, 0)
        subdomain.mode_spectrum = Float64[]
        subdomain.dominant_mode = zeros(Int, n_dim)
        subdomain.spectral_concentration = NaN
        return result
    end
    result = compute_mode_spectrum(subdomain.polynomial; extended_degree = extended_degree)
    subdomain.mode_spectrum = result.spectrum
    subdomain.dominant_mode = collect(result.dominant_mode)
    subdomain.spectral_concentration = result.spectral_concentration
    return result
end
