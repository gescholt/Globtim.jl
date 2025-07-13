# Weak Dependencies in Globtim

## Overview

Globtim uses Julia's weak dependency system (introduced in Julia 1.9) to provide optional visualization functionality without requiring all users to load heavy plotting packages. This keeps the core package lightweight while allowing rich visualization features when needed.

## Weak Dependencies

Globtim has three weak dependencies for visualization:

1. **CairoMakie** - For static, publication-quality plots
2. **GLMakie** - For interactive, GPU-accelerated plots  
3. **Makie** - The base Makie package (automatically loaded with either backend)

## How to Load Weak Dependencies

### Installation

First, install the visualization package you want to use:

```julia
using Pkg
Pkg.add("CairoMakie")  # For static plots
# OR
Pkg.add("GLMakie")     # For interactive plots
```

### Loading Order

The order of loading is important. Always load the visualization package **after** loading Globtim:

```julia
using Globtim
using CairoMakie  # or GLMakie

# Now visualization functions are available
```

### Available Functions

Once a Makie backend is loaded, the following visualization functions become available:

- `plot_hessian_norms(TR::TestInput; kwargs...)` - Plot Hessian norm evolution
- `plot_condition_numbers(TR::TestInput; kwargs...)` - Plot condition number analysis
- `plot_critical_eigenvalues(TR::TestInput; kwargs...)` - Plot critical eigenvalues
- `plot_all_eigenvalues(TR::TestInput; kwargs...)` - Plot all eigenvalue evolution
- `plot_raw_vs_refined_eigenvalues(TR::TestInput; kwargs...)` - Compare raw vs refined eigenvalues

Additional backend-specific functions are also loaded from:
- `graphs_cairo.jl` (for CairoMakie)
- `graphs_makie.jl` (for GLMakie)

## Usage Examples

### Example 1: Basic Visualization with CairoMakie

```julia
using Globtim
using CairoMakie

# Create test input
f(x) = exp(x[1]) / (1 + 100*(x[1] - x[2])^2)
TR = Globtim.test_input(f, dim=2, center=[0.5, 0.5], sample_range=0.5, test_type=:function)

# Create polynomial approximation
pol = Globtim.Constructor(TR, 10, basis=:chebyshev)

# Plot Hessian norms
plot_hessian_norms(TR, title="Hessian Norm Analysis")
```

### Example 2: Interactive Visualization with GLMakie

```julia
using Globtim
using GLMakie

# Same setup as above
f(x) = exp(x[1]) / (1 + 100*(x[1] - x[2])^2)
TR = Globtim.test_input(f, dim=2, center=[0.5, 0.5], sample_range=0.5, test_type=:function)

# Plot with interactive features
plot_all_eigenvalues(TR, interactive=true)
```

### Example 3: Switching Between Backends

If you need to switch between backends in the same session:

```julia
# Start with CairoMakie for static plots
using Globtim
using CairoMakie

# Create static plots...
plot_hessian_norms(TR, save_path="hessian_analysis.png")

# Note: You cannot unload CairoMakie and load GLMakie in the same session
# To use a different backend, restart Julia and load the desired backend
```

## Implementation Details

### How It Works

1. **Function Stubs**: The main Globtim package defines empty function signatures in `src/hessian_analysis.jl`:
   ```julia
   function plot_hessian_norms end
   function plot_condition_numbers end
   # etc.
   ```

2. **Extension Modules**: Actual implementations are in `ext/` directory:
   - `ext/GlobtimCairoMakieExt.jl`
   - `ext/GlobtimGLMakieExt.jl`

3. **Automatic Loading**: When you do `using CairoMakie` or `using GLMakie`, Julia automatically loads the corresponding extension module.

### Benefits

- **Lightweight Core**: Users who don't need visualization don't pay for Makie's compilation time
- **Backend Flexibility**: Choose between static (Cairo) or interactive (GL) backends
- **Clean Separation**: Visualization code is separated from core algorithms
- **Type Stability**: No runtime overhead from conditional loading

## Troubleshooting

### Common Issues

1. **Function not defined error**:
   ```julia
   julia> plot_hessian_norms(TR)
   ERROR: UndefVarError: plot_hessian_norms not defined
   ```
   **Solution**: Make sure to load a Makie backend after loading Globtim.

2. **Wrong loading order**:
   ```julia
   using CairoMakie  # Wrong!
   using Globtim
   ```
   **Solution**: Always load Globtim first, then the Makie backend.

3. **Multiple backends**:
   - You cannot use multiple Makie backends in the same Julia session
   - Restart Julia to switch between CairoMakie and GLMakie

### Checking if Extensions are Loaded

You can check which extensions are loaded:

```julia
using Globtim

# Check available methods before loading Makie
methods(Globtim.plot_hessian_norms)  # Should show 0 methods

using CairoMakie

# Check again after loading
methods(Globtim.plot_hessian_norms)  # Should show 1 method
```

## Best Practices

1. **Choose the Right Backend**:
   - Use CairoMakie for publication-quality static plots
   - Use GLMakie for interactive exploration and 3D visualization

2. **Load Only What You Need**:
   - If you only need core functionality, don't load any Makie backend
   - Load visualization packages only when needed

3. **Script Organization**:
   ```julia
   # At the top of your script
   using Globtim
   
   # Load visualization only if needed
   if get(ENV, "PLOT_RESULTS", "false") == "true"
       using CairoMakie
   end
   ```

4. **Package Development**:
   - If developing a package that depends on Globtim, don't force Makie dependencies
   - Let users choose their preferred backend

## Version Compatibility

- Requires Julia ≥ 1.9 (when weak dependencies were introduced)
- Compatible with Makie.jl ≥ 0.19
- No special version requirements for CairoMakie or GLMakie beyond Makie compatibility