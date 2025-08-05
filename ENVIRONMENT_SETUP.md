# Globtim Dual Environment Setup

This document explains how to use Globtim's dual environment configuration for local development vs HPC deployment.

## Overview

Globtim now supports two distinct environments:

- **Local Environment**: Full plotting capabilities, development tools, interactive features
- **HPC Environment**: Minimal dependencies, optimized for large-scale computations

## Quick Start

### For Local Development

```bash
# Option 1: Use shell script
./scripts/local-dev.sh

# Option 2: Manual activation
julia --project=environments/local
```

### For HPC Deployment

```bash
# Option 1: Use shell script  
./scripts/hpc-mode.sh

# Option 2: Manual activation
julia --project=environments/hpc
```

### For Notebooks (Smart Detection)

```julia
# Add this to the first cell of your notebook
include("Examples/smart_notebook_setup.jl")
```

## Environment Details

### Local Environment (`environments/local/`)

**Includes:**
- Full Makie ecosystem (CairoMakie, GLMakie)
- Interactive plotting (Plots.jl, PlotlyJS)
- Development tools (Revise, ProfileView, BenchmarkTools)
- All computational dependencies

**Use for:**
- Interactive development
- Notebook work
- Creating publication-quality plots
- Debugging and profiling

### HPC Environment (`environments/hpc/`)

**Includes:**
- Core computational packages only
- Plotting via extensions (loaded on demand)
- Minimal memory footprint
- Optimized for batch processing

**Use for:**
- Large-scale computations
- Cluster deployments
- Batch processing
- Memory-constrained environments

## Usage Patterns

### Switching Between Environments

```julia
# In Julia REPL
using Pkg

# Switch to local development
Pkg.activate("environments/local")

# Switch to HPC mode
Pkg.activate("environments/hpc")
```

### Adding Plotting to HPC Environment

```julia
# In HPC environment, load plotting on demand
using CairoMakie
CairoMakie.activate!()

# Now plotting functions work
using Globtim
# ... your plotting code
```

### Notebook Best Practices

```julia
# Cell 1: Smart setup
include("Examples/smart_notebook_setup.jl")

# Cell 2: Your analysis
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], GN=100, sample_range=[1.2, 1.5])
# ... rest of your code
```

## Maintenance

### Updating Dependencies

```bash
# Update local environment
julia --project=environments/local -e "using Pkg; Pkg.update()"

# Update HPC environment  
julia --project=environments/hpc -e "using Pkg; Pkg.update()"
```

### Adding New Dependencies

```bash
# Add to local environment
julia --project=environments/local -e "using Pkg; Pkg.add(\"NewPackage\")"

# Add to HPC environment (if needed for computation)
julia --project=environments/hpc -e "using Pkg; Pkg.add(\"NewPackage\")"
```

## Troubleshooting

### CairoMakie Precompilation Issues

The environments use compatible versions:
- CairoMakie 0.11.x
- GLMakie 0.9.x
- Makie 0.20.x

If you encounter CairoMakie precompilation errors:

```julia
# Clear precompilation cache
using Pkg
Pkg.precompile()

# Or force rebuild
Pkg.build("CairoMakie")
```

### Environment Not Found

```bash
# Recreate environments
julia scripts/activate_local.jl
julia scripts/activate_hpc.jl
```

### Package Version Conflicts

```julia
# Reset environment
using Pkg
Pkg.activate("environments/local")  # or "environments/hpc"
rm("Manifest.toml")  # Remove manifest
Pkg.instantiate()    # Reinstall
```

## Advanced Usage

### Custom Environment Variables

```bash
# Set environment preference
export GLOBTIM_ENV=local    # or "hpc"
julia -e "include(\"Examples/smart_notebook_setup.jl\")"
```

### CI/CD Integration

```yaml
# .github/workflows/test.yml
- name: Test Local Environment
  run: julia --project=environments/local -e "using Pkg; Pkg.test()"
  
- name: Test HPC Environment  
  run: julia --project=environments/hpc -e "using Pkg; Pkg.test()"
```

## Migration Guide

### From Old Setup

If you were using the previous single-environment setup:

1. Your existing notebooks should work with `smart_notebook_setup.jl`
2. For manual control, use the environment-specific activation scripts
3. HPC deployments now use `environments/hpc/` instead of main `Project.toml`

### Updating Existing Code

```julia
# Old way
using Pkg
Pkg.activate(".")
using CairoMakie, Globtim

# New way (automatic)
include("Examples/smart_notebook_setup.jl")

# New way (manual)
using Pkg
Pkg.activate("environments/local")  # or "environments/hpc"
using CairoMakie, Globtim
```
