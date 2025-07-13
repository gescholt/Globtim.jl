# Quick Guide: Using Visualization Features in Globtim

## Installation

```julia
# Install Globtim (if not already installed)
using Pkg
Pkg.add("Globtim")

# Install visualization backend (choose one)
Pkg.add("CairoMakie")  # For static plots
# OR
Pkg.add("GLMakie")     # For interactive plots
```

## Loading (ORDER MATTERS!)

```julia
using Globtim        # Load Globtim FIRST
using CairoMakie     # Then load visualization backend
```

## Available Visualization Functions

Once a Makie backend is loaded, you can use:

- `plot_hessian_norms(TR)` - Hessian norm evolution
- `plot_condition_numbers(TR)` - Condition number analysis
- `plot_critical_eigenvalues(TR)` - Critical eigenvalues
- `plot_all_eigenvalues(TR)` - All eigenvalue evolution
- `plot_raw_vs_refined_eigenvalues(TR)` - Raw vs refined eigenvalues

## Example

```julia
using Globtim
using CairoMakie

# Define test function
f(x) = exp(x[1]) / (1 + 100*(x[1] - x[2])^2)

# Create test input
TR = Globtim.test_input(f, dim=2, center=[0.5, 0.5], sample_range=0.5, test_type=:function)

# Visualize Hessian norms
plot_hessian_norms(TR, title="My Analysis")
```

## Tips

1. **CairoMakie**: Best for saving publication-quality figures
   ```julia
   fig = plot_hessian_norms(TR)
   save("hessian_analysis.pdf", fig)
   ```

2. **GLMakie**: Best for interactive exploration
   ```julia
   plot_all_eigenvalues(TR, interactive=true)  # Can zoom, pan, rotate
   ```

3. **No Visualization Needed?** Just use Globtim without loading any Makie backend - keeps things fast!

## Troubleshooting

**Error: `plot_hessian_norms` not defined**
- Make sure you loaded a Makie backend AFTER loading Globtim

**Want to switch backends?**
- Restart Julia - you can't switch Makie backends in the same session

**Not sure if visualization is loaded?**
```julia
# Check if functions are available
methods(Globtim.plot_hessian_norms)  # Should show 1 method if loaded
```