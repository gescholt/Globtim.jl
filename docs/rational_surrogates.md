# Rational surrogates `r = p/q` (Phase 1)

Globtim can fit a multivariate rational function `r = p/q` instead of a
polynomial and find its critical points with the same HomotopyContinuation
machinery. Phase 1 (docs/RATIONAL_SURROGATE_PHASE1_BRIEF.md) adds the fit, the
lifted critical-point system, a Morse index without division, and a
positivity certificate for the denominator. Source: `src/rational_approx.jl`,
`src/rational_solver.jl`, and one new method in
`ext/GlobtimHomotopyContinuationExt.jl`. Nothing on the polynomial path was
changed.

## Call sequence

```julia
using Globtim, HomotopyContinuation        # HC activates the solver extension

f  = x -> 1 / ((x[1] - 1.15)^2 + (x[2] - 0.30)^2 + 0.04) + sin(3x[1]) * cos(2x[2])
TR = TestInput(f; dim = 2, center = [0.0, 0.0], sample_range = 1.0, GN = 24)

R    = RationalConstructor(TR, 8, 4)        # p of total degree 8, q of total degree 4
cert = certify_positive_denominator(R)      # q > 0 on the closed box?
res  = solve_rational_critical_points(R)    # lifted system, HC, polyhedral start

res.points        # critical points in surrogate coordinates [-1,1]^n
res.values        # y* = r(x*)
res.index         # Morse index of r at each point
to_original_coordinates(R, res.points[1])   # back to the user's box
```

`RationalConstructor` uses the same tensor Chebyshev-Gauss grid, the same
`lambda_vandermonde` basis and the same coordinate map as `Constructor`. Grid
size precedence: the `GN` keyword, then `TR.GN`, then the smallest grid with
`(GN+1)^n ≥ oversample · (α(M) + α(N))`, `α(d) = binomial(n+d, d)`,
`oversample = 2` by default. Basis conventions are inherited: the stored
`normalized` flag is `_stored_normalized(basis)` (plain `T_k` for Chebyshev,
orthonormal Legendre), and passing a contradicting `normalized` keyword is an
error rather than a silent reinterpretation.

## Scattered samples instead of the grid

The grid costs `(GN+1)^n` evaluations of `f`, and `GN` must be at least
`max(M, N)`, so in 4-D a type-(8,4) fit needs 9⁴ = 6561 evaluations while it has
only α(8) + α(4) = 565 unknowns. On an ODE objective that is the cost that
matters. The fit itself is a least-squares problem on any point set, so it can
use scattered samples instead:

```julia
using Random: Xoshiro
R = RationalConstructor(TR, 8, 4; sampling = :christoffel, n_samples = 3 * 60, rng = Xoshiro(1))
```

The `n_samples` points are drawn i.i.d. from the product arcsine (Chebyshev)
measure on `[-1,1]^n`. The least squares is weighted with the Christoffel
weights `m / K_Λ(x)` of the total-degree-`max(M, N)` Chebyshev space, using the
same sampler as `christoffel_fit_chebyshev` (`rational_ls_fit(...; sqrt_w)`).
The normalisation of `q` stays unweighted, so both paths scale `q` alike.

`n_samples` and `rng` are required: the sample set must be replayable, and there
is no default generator. Only the Chebyshev basis is supported, and `GN` must
not be given. `R.sampling`, `R.sample_weights` and `R.grid` (now the samples)
record what was used.

`R.nrm` is the Monte Carlo estimate `(1/K) Σ rᵢ² ∏ₖ π√(1 − xᵢₖ²)` of the same
Lebesgue L2 integral the grid path computes by quadrature. It is in-sample and
optimistic when there are few samples per unknown, so compare fits from
different sample sets on a common grid. The audit reports that residual as
`nrm (grid)`.

How many samples are enough is an empirical question. The stability theory
(Cohen–Migliorati) covers polynomial least squares with `O(m log m)` samples.
The `F·V_N` block of the rational problem is not a polynomial space. On the 2-D
pole pair at (8,4), 3 samples per unknown (180 points, against 625 on the grid)
already match the grid fit's residual, and q stays certified. Below that the
fit becomes seed-dependent. `experiments/sandbox/rational_sparse/` measures it
in 2-D, 3-D and 4-D with the census (`--sampling grid,christoffel:<s>
--replicates <r>`).

## The fit

Austin, Krishnamoorthy, Leyffer, Mrenna, Müller, Schulz, *CPC* 261 (2021)
107663, §3. With `V_M`, `V_N` the Vandermonde matrices of numerator and
denominator on the grid and `F = Diagonal(z)`,

    min ‖V_M a − F V_N b‖₂   s.t.  ‖b‖₂ = 1.

Thin QR `V_M = QR` turns this into the smallest right singular vector of
`W = (I − QQᵀ) F V_N`; `a = R⁻¹Qᵀ F V_N b`. `rational_ls_fit(V_M, V_N, z)` does
exactly this and rescales `(a, b)` so that the **mean of `q` over the grid is 1**
(sign and scale fixed, monomial coefficients O(1)). Do not renormalise to
`‖b‖ = 1` downstream: the sign would be arbitrary and `q` could come out
negative everywhere, which the certificate would reject for the wrong reason.
If the fitted `q` has zero mean on the grid (it then changes sign there;
typically an odd `q` on a symmetric grid for an even objective, a legitimate
solution of the linearised problem), the pair is scaled by `max |q|` instead
and `R.q_normalization` is `:maxabs` rather than `:mean`. Such a fit is still
returned, and it is the certificate that rejects it.

Degree reduction (their Algorithm 3.3): if the *second*-smallest singular value
of `W` is also below `eta · σ_max` (`eta = 1e-12`, noise-free), the linearised
problem has a solution space of dimension ≥ 2, the denominator is
over-parameterised (Froissart doublets), and the fit is repeated with `N − 1`.
`R.N` is the post-reduction degree and `R.n_reductions` counts the steps. Note
that reduction needs slack in *both* degrees: for an exact type-(2,2) rational,
`(M,N) = (4,4)` reduces to `N = 2`, but `(2,4)` does not, because with `M = 2`
the only extra solutions `(p·s, q·s)` have `deg s = 0`.

## Diagnostics

| field | meaning |
|---|---|
| `R.nrm` | quadrature-weighted L2 norm on `[-1,1]^n` of the **nonlinear** residual `p/q − f` on the grid, with the weights `Constructor` uses for `ApproxPoly.nrm`. The two numbers are directly comparable. Never read `‖W b‖` as the error: the linearised residual is weighted by `q`. |
| `R.rms` | plain RMS of the same residual over the grid. |
| `R.sigma_ratio` | `σ_min/σ_max` of `W`. Near machine precision means `f` is, on the grid, a rational function of type ≤ `(M,N)`: the fit is exact. |
| `R.singular_values` | the full spectrum of `W` at the final `N` (the Phase-2 input for adaptive `(M,N)`). |
| `R.qmin_grid` | minimum of `q` over the grid. A hint, not a certificate. |
| `res.n_rejected_q` | real solutions of the lifted system inside the box with `\|q(x*)\| ≤ q_tol` (near-Froissart). They are kept in `res.raw` with status `:q_zero` so an audit can count them, but not returned as critical points. |
| `res.n_inconsistent_y` | solutions whose `y*` disagrees with `p(x*)/q(x*)` beyond `y_tol`; kept in `res.raw` as `:y_mismatch`. |
| `res.n_outside`, `res.n_singular`, `res.n_paths` | real solutions outside `[-1,1]^n`, HC singular endpoints, paths tracked. A nonzero `n_singular` on the lifted system deserves a look. |
| `cert.qmin`, `cert.argmin`, `cert.ok` | minimum of `q` over its interior critical points and the sampled faces, where it is attained, and `qmin > tau`. |

## Why the lifted system

The critical points of `r` are found from

    p(x) − y·q(x) = 0,    ∂ᵢp(x) − y·∂ᵢq(x) = 0   (i = 1..n)

in the `n+1` unknowns `(x, y)` (`rational_critical_system`), not from the
product form `q∇p − p∇q = 0`. The product form vanishes identically on
`{p = q = 0}`, which is positive-dimensional for `n ≥ 3`: HC then reports
singular, non-isolated endpoints and msolve has no zero-dimensional ideal to
work with (`rational_product_system` exists only so the tests can exhibit
this). In the lifted system a point with `q = 0, p ≠ 0` violates the first
equation, and a common zero of `p` and `q` survives only if additionally
`∇p ∥ ∇q`, which generically never happens. No saturation is computed; the
extra variable does it implicitly, and `y* = r(x*)` comes out for free. Since
`y` enters linearly, the polyhedral start system is the default at every `n`.

`solve_rational_critical_points` filters to `-1 ≤ xᵢ ≤ 1` (the box test of
`process_crit_pts`), drops `|q| ≤ q_tol`, checks `y*` against `p/q`, and
classifies each point with `rational_hessian_index`: at a critical point
`H_r = (q·H_p − p·H_q)/q²`, so the Morse index is the inertia of `q·H_p − p·H_q`
with no division, whatever the sign of `q` (`rational_hessian_inertia` returns the
eigenvalues).

## The `q > 0` requirement

Poincaré–Hopf holds for `r` on the box only if `q` has no zero on the closed
box. `certify_positive_denominator(R; tau = 0.0)` reuses the polynomial path
on `q` itself — `solve_polynomial_system(x, n, R.N, R.b; …)`, since `R.b` is
already a degree-`N` coefficient vector in the orthogonal basis — for the
interior candidates, and in Phase 1 samples the `2n` faces on a lattice with
`face_samples = 41` points per face dimension for the boundary. The boundary
part is a stand-in: Phase 2 recurses Globtim on the faces. A fit with
`cert.ok == false` (for example `(6,3)` on the pole-pair objective, where
`min q ≈ −0.05` inside the box) must not be used for a census.

## Tests and audit

- `test/test_rational_approx.jl` — the fit (exact recovery, degree reduction,
  `N = 0` parity with `Constructor`, the pole-pair win over degree 20).
- `test/test_rational_solver.jl` — the lifted solve against a multistart Newton
  oracle on `f`, the 3-D case, the product-form failure mode, the certificate.
  Everything HC-dependent is `@test_skip`ped loudly if the extension is
  missing; a missing extension is never "0 critical points".
- `scripts/audit_rational_phase1.jl` — the comparison at matched degrees of
  freedom with the gate of the brief §3, scored by the verified critical-point
  census: every in-box candidate refined on `f` by Newton (verified when
  `|∇f| < gradtol` is reached inside the box), verified points merged into
  distinct critical points (1e-3 in box units), each distinct point *tight* when
  a candidate started within 0.05 box units of it and *transported* otherwise,
  and every candidate that is not the tight seed of its own point counted as
  spurious. Closed-form objectives also get an independent truth set (Newton
  from a lattice of starts) and report recall. A fit with `cert.ok == false` is
  reported but never selected as the gate's R*. `--sampling grid,christoffel:<s>
  --replicates <r>` adds scattered-sample arms (and Christoffel polynomial
  controls) to every configuration. Each arm records its evaluation count and
  its residual on the common grid. The gate ranks grid fits only.

## Phase 2

- msolve for the lifted system (a `msolve_polynomial_system` variant taking a
  vector of `DynamicPolynomials` in `n+1` variables).
- QP-based pole-free fit with `q ≥ 1`, with the certified minimiser in the
  outer-approximation loop.
- adaptive `(M, N)` from the σ-spectrum of `W`.
- face recursion for the boundary part of the certificate.
