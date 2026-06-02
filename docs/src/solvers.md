# Polynomial System Solvers

Globtim uses polynomial system solvers to find critical points by solving ∇p(x) = 0. This guide covers the available solvers and how to choose between them.

## Available Solvers

### HomotopyContinuation.jl (Default)

Numerical algebraic geometry solver (Breiding & Timme, 2018).

**Website:** [https://www.juliahomotopycontinuation.org/](https://www.juliahomotopycontinuation.org/)

```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs,
    solver=:hc  # Default — requires `using HomotopyContinuation` to load the extension
)
```

The `:hc` solver lives in a package extension that activates only when
`HomotopyContinuation` is loaded; add `using HomotopyContinuation` before solving.

### msolve

Symbolic solver based on Gröbner basis computations (Berthomieu, Eder & Safey El Din, 2021).

**Website:** [https://msolve.lip6.fr/](https://msolve.lip6.fr/)

```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs,
    solver=:msolve,
    msolve_threads=4,                 # parallel Gröbner threads
    msolve_timeout_seconds=600.0,     # optional wall-clock cap
)
```

**Note:** Requires the external `msolve` binary on `PATH` (see below). msolve is
practical only in low dimensions (≤2–3); use `:hc` for `n ≥ 4`.

## Installing Msolve

1. Download from: https://msolve.lip6.fr/
2. Build according to platform instructions
3. Add to PATH or specify path in function call

### macOS/Linux
```bash
git clone https://github.com/algebraic-solving/msolve.git
cd msolve
./autogen.sh
./configure
make
sudo make install
```

### Verification
```bash
msolve --help
```

## Solver Selection Guidelines

### Use HomotopyContinuation when:
- Working with smooth, well-conditioned problems
- Need fast solutions for exploration
- Dealing with higher dimensions (>4)
- Numerical accuracy is sufficient

### Use Msolve when:
- Need exact verification of results
- Working with rational coefficients
- Dealing with degenerate or near-singular systems
- Publishing results requiring certainty

## Example Comparison

```julia
using Globtim, DynamicPolynomials

# Setup problem
f = Deuflhard
TR = TestInput(f, dim=2, center=[0,0], sample_range=1.2)
pol = Constructor(TR, 8)

@polyvar x[1:2]

# HomotopyContinuation (numerical)
@time solutions_hc = solve_polynomial_system(
    x, 2, 8, pol.coeffs,
    solver=:hc
)

# msolve (symbolic/exact)
@time solutions_ms = solve_polynomial_system(
    x, 2, 8, pol.coeffs,
    solver=:msolve
)

# Compare results
println("HC found $(length(solutions_hc)) solutions")
println("Msolve found $(length(solutions_ms)) solutions")
```

## Advanced Options

The following keyword arguments are accepted by `solve_polynomial_system` (and are
threaded through `solve_and_transform` and the subdivision solver `solve_tree_leaves`).

### Polyhedral homotopy (`start_system`)

For sparse systems, polyhedral homotopy tracks far fewer paths than the total-degree
(Bézout) start system. `start_system=:auto` (the default) picks **polyhedral for
`n ≥ 3`** and the **total-degree** start system for `n < 3`:

```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs;
    solver=:hc,
    start_system=:auto,   # :auto | :polyhedral | :total_degree
)
```

### Coefficient sparsification before solving (`sparsify_threshold`)

Zeroing out small surrogate coefficients before constructing the polynomial yields a
genuinely sparser Newton polytope, so polyhedral homotopy tracks fewer paths.
`sparsify_threshold` is **relative to the largest coefficient** (`0.0` = off):

```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs;
    solver=:hc,
    sparsify_threshold=1e-6,   # drop |cₖ| < 1e-6 · max|c|
)
```

### Restricting the solve to a box (`search_bounds`)

`search_bounds` filters solutions to a coordinate box given as a vector of
`(lo, hi)` tuples — useful for solving only inside the domain of interest or a
subdivision leaf:

```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs;
    search_bounds=[(-2.0, 2.0), (-1.0, 1.0)],
)
```

The two solvers enforce this differently:

- **`:msolve`** uses its **certified isolating intervals** — a solution is kept only
  when its interval is provably inside the box (certified domain filtering).
- **`:hc`** has no interval data, so it applies a **midpoint filter** (keeps a solution
  if its numeric coordinates fall in the box).

### Tuning each solver

| Keyword | Solver | Purpose |
|---------|--------|---------|
| `start_system` | `:hc` | Start system for path tracking (`:auto`/`:polyhedral`/`:total_degree`) |
| `sparsify_threshold` | both | Relative coefficient cutoff applied before solving |
| `search_bounds` | both | Restrict solutions to a coordinate box (certified for msolve) |
| `msolve_threads` | `:msolve` | Number of Gröbner-basis threads |
| `msolve_timeout_seconds` | `:msolve` | Optional wall-clock cap on the symbolic solve |

## Handling Solver Results

Both solvers return solutions in a common format:

```julia
# Process solutions
df = process_crit_pts(solutions, f, TR, solver=solver_name)

# Check solution quality
for sol in solutions
    grad_norm = norm(gradient(pol.polynomial, sol))
    println("Solution: $sol, |∇p|: $grad_norm")
end
```

## Related Documentation

- [Core Algorithm](core_algorithm.md) - Overall optimization approach
- [Polynomial Approximation](polynomial_approximation.md) - Polynomial construction
- [API Reference](api_reference.md) - Function documentation