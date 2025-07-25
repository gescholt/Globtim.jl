# Polynomial System Solvers

Globtim uses polynomial system solvers to find critical points by solving ∇p(x) = 0. This guide covers the available solvers and how to choose between them.

## Available Solvers

### HomotopyContinuation.jl (Default)

Numerical polynomial system solver using homotopy continuation methods.

```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs,
    solver="HC"  # Default
)
```

**Advantages:**
- Finds all complex solutions reliably
- Handles high-degree systems well
- Good performance for moderate dimensions
- No external dependencies

**Limitations:**
- Numerical accuracy limited by floating point
- May miss solutions in degenerate cases
- Performance degrades in high dimensions

### Msolve (Optional)

Exact arithmetic solver for polynomial systems.

```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs,
    solver="msolve",
    msolve_path="/path/to/msolve"
)
```

**Advantages:**
- Exact rational arithmetic
- Guaranteed to find all solutions
- Handles degenerate cases perfectly
- Useful for verification

**Limitations:**
- Requires external installation
- Slower than numerical methods
- Memory intensive for large systems
- Limited to moderate polynomial degrees

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
TR = test_input(f, dim=2, center=[0,0], sample_range=1.2)
pol = Constructor(TR, 8)

@polyvar x[1:2]

# HomotopyContinuation (fast)
@time solutions_hc = solve_polynomial_system(
    x, 2, 8, pol.coeffs,
    solver="HC"
)

# Msolve (exact)
@time solutions_ms = solve_polynomial_system(
    x, 2, 8, pol.coeffs,
    solver="msolve"
)

# Compare results
println("HC found $(length(solutions_hc)) solutions")
println("Msolve found $(length(solutions_ms)) solutions")
```

## Advanced Options

### HomotopyContinuation Parameters

Control solver behavior:
```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs,
    solver="HC",
    hc_options=Dict(
        :compile => false,      # Disable compilation for small problems
        :threading => true,     # Enable parallel tracking
        :tracker_options => TrackerOptions(
            automatic_differentiation=2,  # AD order
            refinement_accuracy=1e-12    # Target accuracy
        )
    )
)
```

### Msolve Parameters

Fine-tune exact solving:
```julia
solutions = solve_polynomial_system(
    x, n_dims, degree, coeffs,
    solver="msolve",
    msolve_options=Dict(
        :precision => 128,      # Bit precision for intermediate computations
        :threads => 4,          # Number of threads
        :output_format => "qq"  # Rational output format
    )
)
```

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

## Performance Tips

1. **Problem Scaling**
   - Normalize domain to [-1,1]ⁿ for better conditioning
   - Use appropriate polynomial degree (8-12 typical)

2. **Memory Management**
   - HomotopyContinuation: Enable compilation for repeated solves
   - Msolve: Monitor RAM usage, may need 10-100x problem size

3. **Parallel Execution**
   - Both solvers support multithreading
   - Set environment variable: `export JULIA_NUM_THREADS=8`

## Troubleshooting

### HomotopyContinuation Issues

**Missing solutions:**
- Increase tracker accuracy
- Check for solutions at infinity
- Try different random seed

**Slow performance:**
- Reduce polynomial degree
- Enable compilation
- Use fewer tracker steps

### Msolve Issues

**Installation problems:**
- Check GMP/MPFR dependencies
- Verify compiler support (C99)
- Try pre-built binaries

**Memory errors:**
- Reduce polynomial degree
- Increase system RAM/swap
- Use HomotopyContinuation instead

## Related Documentation

- [Core Algorithm](core_algorithm.md) - Overall optimization approach
- [Polynomial Approximation](polynomial_approximation.md) - Polynomial construction
- [API Reference](api_reference.md) - Function documentation