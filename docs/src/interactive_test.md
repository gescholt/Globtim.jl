# Interactive Visualizations

This page demonstrates the full Globtim pipeline — from objective function to discovered critical points — rendered as interactive 3D WebGL visualizations. Rotate and zoom the plots with your mouse.

## Six-Hump Camel: Finding All Critical Points

The [Six-Hump Camel](https://www.sfu.ca/~ssurjano/camel6.html) is a classic 2D benchmark with **six local minima** (two of which are global). Globtim approximates it with a Chebyshev polynomial and finds *every* critical point via homotopy continuation.

```@setup wglmakie_test
using WGLMakie, Bonito
Page(exportable=true, offline=true)
WGLMakie.activate!()
Makie.inline!(true)
```

### Step 1 — Polynomial Approximation & Critical Point Solve

```@example wglmakie_test
using Globtim
using DynamicPolynomials
using DataFrames
using GlobtimPlots: adapt_polynomial_data, adapt_problem_input

# Define the problem: Six-Hump Camel on [-2.5, 2.5]²
TR = TestInput(camel, dim=2, center=[0.0, 0.0], sample_range=2.5)

# Build degree-10 Chebyshev polynomial approximation
pol = Constructor(TR, 10)

# Find all critical points (gradient = 0) via homotopy continuation
@polyvar x[1:2]
solutions = solve_polynomial_system(x, pol)
df = process_crit_pts(solutions, camel, TR)

# Refine with BFGS and classify via Hessian eigenvalues
df_enhanced, df_min = analyze_critical_points(
    camel, df, TR,
    enable_hessian=true,
    verbose=false
)

println("Polynomial L²-norm error: ", round(pol.nrm, sigdigits=3))
println("Critical points found:    ", nrow(df_enhanced))
println("Local minima found:       ", nrow(df_min))
nothing # hide
```

### Step 2 — Interactive 3D Landscape

The surface shows the polynomial approximation evaluated on the Chebyshev grid.
**Critical points** are overlaid:
- 🟢 Green = refined points near a local minimum
- ⚪ White = saddle points or maxima
- 🔵 Blue diamonds = captured local minima
- 🔴 Red diamonds = uncaptured local minima (if any)

```@example wglmakie_test
pol_adapted = adapt_polynomial_data(pol)
tr_adapted  = adapt_problem_input(TR)

fig = GlobtimPlots.plot_polyapprox_3d(
    pol_adapted, tr_adapted,
    df_enhanced, df_min;
    figure_size = (800, 600),
    alpha_surface = 0.8,
    fade = true,
    z_cut = 0.3
)
fig
```

### Step 3 — Critical Point Summary

```@example wglmakie_test
# Show the discovered minima
for i in 1:nrow(df_min)
    x1 = round(df_min[i, :x1], digits=4)
    x2 = round(df_min[i, :x2], digits=4)
    val = round(df_min[i, :value], digits=6)
    cap = df_min[i, :captured] ? "captured" : "uncaptured"
    println("  Minimum $i: ($x1, $x2) → f = $val  [$cap]")
end
nothing # hide
```

## What's Next

- **[Pipeline Walkthrough]**: Interactive animation of the full Globtim algorithm
- **[Degree Convergence Explorer]**: Watch polynomial approximation quality improve with degree
- **[Benchmark Gallery]**: Interactive 3D views of all standard test functions with critical points
