# Phase 2: Hessian-Based Critical Point Classification

## Overview

Phase 2 extends Globtim's critical point analysis by computing Hessian matrices at each critical point using automatic differentiation and classifying points based on eigenvalue structure.

## Key Features

- **Automatic Hessian Computation**: Uses ForwardDiff.jl for robust automatic differentiation
- **Complete Eigenvalue Analysis**: Stores all eigenvalues for detailed mathematical analysis
- **Critical Point Classification**: Distinguishes minima, maxima, saddle points, and degenerate cases
- **Numerical Diagnostics**: Condition numbers, norms, and stability metrics
- **Comprehensive Visualization**: Plots for eigenvalue distributions, condition numbers, and classification results

## Mathematical Foundation

### Critical Point Classification via Second Derivatives

For a function f: ℝⁿ → ℝ at critical point x* where ∇f(x*) = 0:

| Hessian Property | Classification | Eigenvalue Pattern |
|------------------|----------------|-------------------|
| Positive definite | Local minimum | All λᵢ > 0 |
| Negative definite | Local maximum | All λᵢ < 0 |
| Indefinite | Saddle point | Mixed signs |
| Singular | Degenerate | At least one λᵢ = 0 |

### Key Metrics

- **Condition Number**: κ(H) = λₘₐₓ/λₘᵢₙ (numerical stability)
- **Frobenius Norm**: ||H||_F (matrix magnitude)
- **Critical Eigenvalues**: Smallest positive (minima), largest negative (maxima)

## Documentation Structure

```
docs/phase2/
├── README.md                    # This overview
├── API.md                      # Function documentation
├── INTEGRATION.md              # Integration with existing code
├── VISUALIZATION.md            # Plotting and visualization
├── EXAMPLES.md                 # Usage examples
└── PERFORMANCE.md              # Performance considerations
```

## Quick Start

```julia
using Globtim

# Setup problem
f = Rastringin
TR = test_input(f, dim=3, center=[0.0, 0.0, 0.0])
pol = Constructor(TR, 10)

# Phase 1 + Phase 2 analysis
@polyvar x[1:3]
real_pts = solve_polynomial_system(x, 3, 10, pol.coeffs)
df = process_crit_pts(real_pts, f, TR)
df_enhanced, df_min = analyze_critical_points(f, df, TR, verbose=true)

# Phase 2 results available in df_enhanced:
# - critical_point_type
# - hessian_* columns
# - smallest_positive_eigenval
# - largest_negative_eigenval
```

## Implementation Status

- ✅ Core Hessian computation functions
- ✅ Complete eigenvalue analysis
- ✅ Critical point classification
- ✅ Visualization functions
- ✅ Integration test
- 🔄 Integration with analyze_critical_points
- ⏳ Unit tests
- ⏳ Performance optimization

## Dependencies

- ForwardDiff.jl (automatic differentiation)
- LinearAlgebra (eigenvalue computation)
- CairoMakie/GLMakie (visualization)

## See Also

- [API Documentation](API.md)
- [Integration Guide](INTEGRATION.md)
- [Visualization Guide](VISUALIZATION.md)
- [Examples](EXAMPLES.md)