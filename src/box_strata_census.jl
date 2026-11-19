# box_strata_census.jl
# Closed Poincaré–Hopf census of a polynomial surrogate on the box [-1,1]ⁿ.
#
# The interior count Σ(−1)^index over critical points of p in the open box equals
# χ(box) = 1 only when no admissible critical point sits on the boundary — and boundary
# minima are exactly what wide-domain runs (LV-2D at relative L2 0.056) produce. The box is
# a stratified space: its strata are the 3ⁿ open faces F (each coordinate fixed at −1, at
# +1, or free; the open box itself is the all-free face). Stratified Morse theory for a
# generic function on a polytope gives
#
#     χ(box) = 1 = Σ_F  Σ_{x ∈ crit(p|F), ∇p(x) points inward on every fixed coordinate}  (−1)^{ind(p|F, x)}
#
# where "inward" means ∂ᵢp(x) > 0 at xᵢ = −1 and ∂ᵢp(x) < 0 at xᵢ = +1. Those points are
# precisely the KKT points of min p on the box whose constraint multipliers are all
# strictly positive — the boundary local minima of the box-constrained problem are among
# them (ind = 0 on their face). A vertex contributes +1 iff ∇p points into the box there.
# Sanity examples (all sum to 1): p = |x|² (interior minimum only); p = −|x|² in 2-D (max
# +1, four edge maxima −4, four vertices +4); p = x₁ + 0.1x₂ (one vertex).
#
# A missed critical point anywhere — interior or on a face — shows up as a sum ≠ 1, so this
# is a completeness check on the SURROGATE's census. It certifies nothing about f: the
# verified census (refinement on f) remains the measure of a run.
#
# Faces are solved with HomotopyContinuation through `_solve_rational_hc` (the generic
# square-system entry point of the HC extension; same per-face pattern as
# `certify_positive_denominator(:recursion)`): requires `using HomotopyContinuation`.

# Generic offset (irrational ratio to the box scale) for homogeneous face systems.
const _STRATA_SHIFT = 0.1 * (sqrt(5) - 1) / 2

"""
    surrogate_monomial_polynomial(pol::ApproxPoly) -> (p, x)

The surrogate as a DynamicPolynomials polynomial in fresh variables `x[1:n]` on the box
`[-1,1]ⁿ`, built exactly as the HC solve builds it (`main_nd`: exact orthogonal→monomial
conversion, then Float64 coefficients).
"""
function surrogate_monomial_polynomial(pol::ApproxPoly)
    n = size(pol.support, 2)
    @polyvar x[1:n]
    xv = collect(x)
    p = main_nd(
        xv,
        n,
        pol.degree,
        pol.coeffs;
        basis = pol.basis,
        precision = pol.precision,
        normalized = pol.normalized,
        power_of_two_denom = pol.power_of_two_denom,
    )
    return p, xv
end

"""
    box_strata_census(pol::ApproxPoly; kwargs...) -> NamedTuple
    box_strata_census(p, x; kwargs...) -> NamedTuple

Poincaré–Hopf census of the surrogate over all `3ⁿ` strata of `[-1,1]ⁿ` (see the file
header for the formula). The second method takes a DynamicPolynomials polynomial `p` in
the variables `x` directly.

# Keyword arguments
- `edge_tol = 1e-8`: a face solution with some free coordinate within `edge_tol` of ±1
  sits on a lower stratum to numerical precision; it is counted as `ambiguous` and the
  census is not `exact`.
- `inward_tol = 1e-10`: `|∂ᵢp|` on a fixed coordinate at or below
  `inward_tol·max(1, ‖∇p‖)` is tangential (non-generic) → `ambiguous`.
- `hessian_tol = 1e-8`: a face-Hessian eigenvalue with `|λ| ≤ hessian_tol·max(1, max|λ|)`
  makes the point degenerate → `ambiguous`.
- `max_dim = 8`: refuse `n > max_dim` (3ⁿ faces, one HC solve each).

# Returns
`(; sum, ok, exact, points, n_counted, n_interior, n_boundary_counted, n_ambiguous,
n_singular_faces, n_degenerate_faces, n_failed_faces, n_faces)`:
- `sum`: Σ(−1)^index over counted points; `ok = exact && sum == 1`.
- `exact`: no ambiguous point, no face with singular HC endpoints, no face with a failed
  HC path (`n_failed_faces`: a root of that face may be missing), no face whose
  gradient system has an identically-zero equation (p independent of a free variable on
  that face: the stationary set is not isolated).
- `points`: every in-face critical point of every stratum as
  `(; x, stratum_dim, fixed, index, inward, counted, value, status)` in box coordinates
  (`status ∈ (:counted, :outward, :ambiguous)`); `counted` points are the census.
- `n_boundary_counted`: counted points on proper faces — boundary KKT points the
  interior-only census misses.
"""
function box_strata_census(pol::ApproxPoly; kwargs...)
    p, x = surrogate_monomial_polynomial(pol)
    return box_strata_census(p, x; kwargs...)
end

function box_strata_census(
    p,
    x::AbstractVector;
    edge_tol::Real = 1e-8,
    inward_tol::Real = 1e-10,
    hessian_tol::Real = 1e-8,
    max_dim::Int = 8,
)
    n = length(x)
    n <= max_dim || throw(
        ArgumentError("box_strata_census: n = $n > max_dim = $max_dim (3ⁿ face solves)"),
    )
    grad = differentiate(p, x)
    hess = [differentiate(grad[i], x[j]) for i in 1:n, j in 1:n]
    evalat(q, pt) = Float64(q(x => pt))

    points = NamedTuple[]
    total = 0
    n_singular_faces = 0
    n_degenerate_faces = 0
    n_failed_faces = 0
    digits_ = zeros(Int, n)
    for code in 0:(3^n-1)
        k = code
        for i in 1:n
            digits_[i] = k % 3
            k ÷= 3
        end
        base = [d == 1 ? -1.0 : d == 2 ? 1.0 : 0.0 for d in digits_]
        free = findall(==(0), digits_)
        fixed = findall(!=(0), digits_)

        candidates = Vector{Vector{Float64}}()
        if isempty(free)
            push!(candidates, base)
        else
            pF = isempty(fixed) ? p : subs(p, (x[j] => base[j] for j in fixed)...)
            eqs = [differentiate(pF, x[i]) for i in free]
            if any(iszero, eqs)
                # p|F does not depend on a free variable: non-isolated stationary set
                n_degenerate_faces += 1
                continue
            end
            # a nonzero constant equation: no stationary point on this face
            any(e -> maxdegree(e) == 0, eqs) && continue
            # HC solves a system of homogeneous equations projectively, where the
            # affine root 0 is not a point and is dropped as an excess solution
            # (p = |x|² loses its minimum). Shift such a system off the origin.
            shift = zeros(length(free))
            if all(e -> mindegree(e) == maxdegree(e), eqs)
                shift .= _STRATA_SHIFT .* (1:length(free))
                eqs = [
                    subs(e, (x[i] => x[i] + s for (i, s) in zip(free, shift))...) for
                    e in eqs
                ]
            end
            sols, st = _solve_rational_hc(
                eqs,
                x[free];
                # Total-degree start on every face. HC's polyhedral tracker loses paths
                # now and then (Σ yᵢ⁴ − yᵢ² in 3-D: 25 of 300 solves returned 26, 24, 18
                # or 9 of the 27 roots), and a face polynomial of a fitted surrogate is
                # dense, so the mixed volume buys nothing over the Bézout count here.
                start_system = :total_degree,
                compile = false,
            )
            st.n_singular > 0 && (n_singular_faces += 1)
            # a failed path is a root that may be missing: the census cannot close
            st.n_path_failures > 0 && (n_failed_faces += 1)
            for s in sols
                y = Vector{Float64}(real.(s)) .+ shift
                all(abs.(y) .<= 1 + edge_tol) || continue
                pt = copy(base)
                pt[free] .= clamp.(y, -1.0, 1.0)
                if any(abs.(y) .> 1 - edge_tol)
                    push!(
                        points,
                        (;
                            x = pt,
                            stratum_dim = length(free),
                            fixed = fixed,
                            index = -1,
                            inward = false,
                            counted = false,
                            value = evalat(p, pt),
                            status = :ambiguous,
                        ),
                    )
                    continue
                end
                push!(candidates, pt)
            end
        end

        for pt in candidates
            g = [evalat(grad[i], pt) for i in 1:n]
            gscale = max(1.0, maximum(abs, g))
            # inward on every fixed coordinate: ∂ᵢp > 0 at −1, < 0 at +1
            margins = [-base[j] * g[j] for j in fixed]
            tangential = any(m -> abs(m) <= inward_tol * gscale, margins)
            inward = !tangential && all(>(0), margins)
            index = -1
            degenerate = false
            if !isempty(free)
                H = Symmetric([evalat(hess[i, j], pt) for i in free, j in free])
                λ = eigvals(H)
                thr = hessian_tol * max(1.0, maximum(abs, λ))
                degenerate = any(v -> abs(v) <= thr, λ)
                index = count(<(0), λ)
            else
                index = 0
            end
            status =
                (tangential || degenerate) ? :ambiguous : (inward ? :counted : :outward)
            counted = status == :counted
            counted && (total += isodd(index) ? -1 : 1)
            push!(
                points,
                (;
                    x = pt,
                    stratum_dim = length(free),
                    fixed = fixed,
                    index = index,
                    inward = inward,
                    counted = counted,
                    value = evalat(p, pt),
                    status = status,
                ),
            )
        end
    end

    n_ambiguous = count(q -> q.status == :ambiguous, points)
    exact =
        n_ambiguous == 0 &&
        n_singular_faces == 0 &&
        n_degenerate_faces == 0 &&
        n_failed_faces == 0
    n_counted = count(q -> q.counted, points)
    n_interior = count(q -> q.counted && q.stratum_dim == n, points)
    return (;
        sum = total,
        ok = exact && total == 1,
        exact = exact,
        points = points,
        n_counted = n_counted,
        n_interior = n_interior,
        n_boundary_counted = n_counted - n_interior,
        n_ambiguous = n_ambiguous,
        n_singular_faces = n_singular_faces,
        n_degenerate_faces = n_degenerate_faces,
        n_failed_faces = n_failed_faces,
        n_faces = 3^n,
    )
end
