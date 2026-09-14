# Glued Objectives

Higher-dimensional test problems with **known** critical-point sets, generated
by Cartesian-product gluing of lower-dimensional objectives.

The construction and the `glue` API below are provided by
[DynamicObjectives.jl](https://github.com/gescholt/DynamicObjectives.jl); the recall
results are Globtim's. This is the one family of test problems where "did we find
*every* critical point?" is a decidable question, which makes it the sharpest available
check on the critical-point solver.

## The construction

Given two objectives `f₁(x): ℝⁿ¹ → ℝ` and `f₂(y): ℝⁿ² → ℝ`:

```
F(z) := f₁(x) + f₂(y),   where z = [x; y] ∈ ℝⁿ¹⁺ⁿ²
```

Three properties fall out of this independent-coordinate sum:

1. **Stationary-point factorization.** `∇F(z) = 0` iff `∇f₁(x) = 0` *and*
   `∇f₂(y) = 0`. So:
   ```
   CP(F) = CP(f₁) × CP(f₂)        (Cartesian product)
   ```

2. **Block-diagonal Hessian.**
   ```
   H_F(z) = [ H_f₁(x)    0     ]
            [   0      H_f₂(y) ]
   ```
   Eigenvalues of `H_F` are the union of eigenvalues of the two blocks, so the
   Morse index decomposes:
   `index_F(p, q) = index_f₁(p) + index_f₂(q)`. A 4D minimum needs both
   factors at minima; an index-2 saddle needs `(saddle, saddle)`,
   `(min, max)`, or `(max, min)`.

3. **Cheap evaluation.** F is a sum of two independent function calls — the
   ODE solves (or whatever expensive evaluations) happen on disjoint
   coordinate slices.

## Why we want this

The [catalogue's](model_catalog.md) 4D entries (`lv4d`, `daisy4d`, `goodwin4d`,
`lv4d_simple`) all expose a true parameter `p_true` but no oracle for the **full**
critical-point set. We can ask "did subdivision find the global min?", but we can't ask
"did we find every local min?". With glued problems we can.

For benchmark validation this gives:
- Exact CP counts: `|CP(F)| = |CP(f₁)| × |CP(f₂)|`
- Tunable difficulty by choosing factor pairs (e.g. quartic × quartic, lv2d × lv2d)
- Friendly Newton convergence (block-diagonal Hessian)

## API

These three functions are exported by `DynamicObjectives`, not by `Globtim`.

```julia
glue(f1, bounds1, f2, bounds2; cps1=nothing, cps2=nothing) -> NamedTuple
```

Returns `(; F, bounds, dim, n1, n2, oracle_cps)` where `oracle_cps` is the
analytic Cartesian product when both factor CP sets are supplied.

```julia
glue_catalogue(name1, cat_path1, name2, cat_path2;
               cps1=nothing, cps2=nothing,
               solver_method="Tsit5", abstol=1e-4, reltol=1e-4) -> NamedTuple
```

Same construction, but each factor is read from an entry of a JSONL screening
catalogue (`cat_path1`, `cat_path2` name the file; `name1`, `name2` the entry) rather
than passed as a closure — useful for `lv2d × lv2d`-style ODE benchmarks. Entry names
are only unique *within* a catalogue file, so always name the path explicitly.

```julia
count_oracle_cps_in_box(oracle_cps, bounds) -> Int
```

Counts oracle CPs that fall inside a hyperrectangle. Use this to sanity-check
subdivision recovery against the full oracle, especially after restricting
the domain.

## Example: synthetic 4D from two 2D quartics

```julia
using DynamicObjectives

# Each factor: 2D quartic with 3 stationary points (±1, 0) min, (0, 0) saddle
f1(x) = (x[1]^2 - 1.0)^2 + x[2]^2
f2(y) = (y[1]^2 - 1.0)^2 + y[2]^2

cps1 = [[1.0, 0.0], [-1.0, 0.0], [0.0, 0.0]]   # 2 min + 1 saddle
cps2 = [[1.0, 0.0], [-1.0, 0.0], [0.0, 0.0]]

g = glue(
    f1, [(-2.0, 2.0), (-1.0, 1.0)],
    f2, [(-2.0, 2.0), (-1.0, 1.0)];
    cps1 = cps1, cps2 = cps2,
)

g.dim                    # 4
length(g.oracle_cps)     # 9 = 3 × 3
g.F([1.0, 0.0, 1.0, 0.0])  # 0.0 — the (min, min) joint minimum
```

By Morse decomposition the 9 oracle CPs split as:
- **4 minima** at `(±1, 0, ±1, 0)`
- **4 saddles** of index 1 at `(±1, 0, 0, 0)` and `(0, 0, ±1, 0)`
- **1 saddle** of index 2 at `(0, 0, 0, 0)`

## Example: counting CPs in a sub-box

```julia
# Restrict to the upper-half of factor 2's first coordinate
sub_box = [(-2.0, 2.0), (-1.0, 1.0), (0.0, 2.0), (-1.0, 1.0)]
count_oracle_cps_in_box(g.oracle_cps, sub_box)  # 6 of the 9 oracle CPs
```

Use this to verify that subdivision on a sub-box recovers exactly the CPs
predicted by the oracle restriction — no spurious extras above the L2
tolerance.

## Example: subdivision on a glued problem

```julia
using Globtim
using HomotopyContinuation   # activates the HC extension

# Glue two simple bowls — single 4D minimum at (1, -0.5, 0.3, 2.0)
f1(x) = (x[1] - 1.0)^2 + (x[2] + 0.5)^2
f2(y) = (y[1] - 0.3)^2 + (y[2] - 2.0)^2

g = glue(
    f1, [(0.0, 2.0), (-2.0, 2.0)],
    f2, [(-1.0, 1.0), (0.0, 4.0)];
    cps1 = [[1.0, -0.5]], cps2 = [[0.3, 2.0]],
)

tree = adaptive_refine(
    g.F, g.bounds, 4;
    l2_tolerance = 1e-2, tolerance_mode = :relative,
    max_depth = 3, max_leaves = 32, parallel = false,
)

sol = solve_tree_leaves(tree)
# sol.critical_points should contain a CP near g.oracle_cps[1]
```

## Verified recall: globtim recovers the *full* oracle

The payoff of a known CP set is a **decidable** recall test: not "did we find the
global min?" but "did we find *every* critical point?". Using closed-form
polynomial factors, a recall demonstration script builds the analytic
oracle **independently** (multi-start Newton on the analytic gradient, classified by
the analytic Hessian — never by globtim), fits the glued objective at its exact
polynomial degree (`p.nrm ≈ 1e-12`, so the fit is exact and we test the *solver*,
not the approximation), enumerates critical points with the HC pipeline, and matches
per Morse index.

Both cases recover **every** critical point — recall = precision = 1.0 at every index:

| Glue (deg) | oracle CPs | minima | recovered | recall | max match dist |
|---|---|---|---|---|---|
| himmelblau × himmelblau (4) | 81 = 9² | 16 | 81 | **1.00** | 2.0e-14 |
| camel × camel (6) | 225 = 15² | 36 | 225 | **1.00** | 4.8e-13 |

himmelblau's gradient is Bezout-tight (`3⁴ = 81` complex roots, all real), so 81/81 is
a *complete* certificate that no HC paths were lost. The camel case is stronger
evidence still: its mixed volume is **625** while only **225** roots are real, yet
globtim recovers all 225 (36 minima) — path loss would have shown up as a recall gap
and did not. Index breakdown (0=min … 4=max): himmelblau² `16/32/24/8/1`,
camel² `36/84/73/28/4`.

## Choosing factor pairs

The "right" factor pair depends on what you're trying to validate:

| Goal | Suggested pair |
|------|----------------|
| Decidable "did we find ALL CPs?" | quartic × quartic (9 known CPs) |
| 4D ODE-style with tractable runtime | lv2d × lv2d (one ODE solve per factor) |
| Stress-test high CP count | trig_sum × trig_sum (many local minima) |
| Asymmetric difficulty | lv2d × quartic |

Heavy-duty ODE pairs (e.g. wide-domain `goodwin4d × goodwin4d`) will hit
ODE-divergence regions that cost significant wall time before pruning kicks
in. Prefer narrow domains around the known critical points for ODE factors.

## See also

- [Model Catalog](model_catalog.md) — the ODE factors available for gluing
- [ODE Parameter Estimation](ode_parameter_estimation.md) — where these objectives come from
- In the DynamicObjectives repository: `test/test_glued_recovery.jl` (cheap CI
  regression — a 2D double-well² glue where Globtim recovers all 9 oracle CPs, recall =
  precision = 1.0) and `test/test_glued_objectives.jl` (construction, oracle-CP
  gradient-zero check, sub-box counting)
