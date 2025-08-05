# Globtim Notebook Workflow Documentation

## Overview

This document describes the standardized notebook workflow for Globtim projects, ensuring consistent setup across local development and HPC cluster environments.

## Quick Start

### For Any New Notebook

1. **Create your notebook** in any subdirectory of the Globtim project
2. **Add this as the first cell** (copy-paste, no editing needed):

```julia
# Globtim Notebook Setup - Universal Header Cell
# This cell automatically detects your environment and sets up the appropriate configuration
# No editing required - works from any location in the project

include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))
```

3. **Run the cell** - it will automatically:
   - Detect if you're on local machine or HPC cluster
   - Activate the appropriate environment
   - Load Globtim and core packages
   - Configure plotting backends
   - Provide clear status feedback

4. **Start your analysis** - all Globtim functionality is now available

## File Structure

```
globtim/
├── .globtim/
│   ├── notebook_setup.jl          # Universal setup script
│   ├── NOTEBOOK_TEMPLATE.md       # Copy-paste templates
│   └── HPC_NOTEBOOK_STRATEGY.md   # HPC-specific guidance
├── environments/
│   ├── local/                     # Full development environment
│   └── hpc/                       # Minimal HPC environment
├── Examples/
│   └── Notebooks/
│       └── Deuflhard.ipynb        # Reference example
└── NOTEBOOK_WORKFLOW.md           # This documentation
```

## Environment Detection

The setup automatically detects your environment:

### Local Environment Indicators
- Standard desktop/laptop environment
- No HPC scheduler variables present
- Full plotting and development tools available

### HPC Environment Indicators
- SLURM job variables (`SLURM_JOB_ID`)
- PBS scheduler variables (`PBS_JOBID`)
- Hostname patterns (`cluster`, `node`, `furiosa`)
- Other common HPC indicators

## What Gets Loaded

### Local Environment
- **Full Makie ecosystem**: CairoMakie (activated), GLMakie available
- **Development tools**: Revise, ProfileView, BenchmarkTools
- **All computational packages**: Globtim, DynamicPolynomials, DataFrames, etc.
- **Interactive features**: Full plotting, debugging, profiling

### HPC Environment
- **Core computational packages**: Globtim, DynamicPolynomials, DataFrames, etc.
- **Minimal dependencies**: Optimized for performance and memory
- **Plotting on demand**: Available via extensions when needed
- **Batch processing optimized**: Fast startup, efficient computation

## Plotting Strategies

### Local Development
```julia
# Plotting is automatically available
fig = plot_results(data)
display(fig)

# Switch backends if needed
GLMakie.activate!()  # For interactive plots
CairoMakie.activate!()  # For high-quality static plots
```

### HPC Cluster

#### Option 1: No Plotting (Fastest)
```julia
# Default HPC setup - no plotting loaded
# Fastest startup, minimal memory usage
results = run_analysis()
save("results.csv", results)
```

#### Option 2: Add Plotting When Needed
```julia
# After setup, load plotting on demand
using CairoMakie
CairoMakie.activate!()
fig = plot_results(data)
save("plot.png", fig)
```

#### Option 3: Force Plotting in Setup
```julia
# Set before running setup cell
ENV["GLOBTIM_FORCE_PLOTTING"] = "true"
# Then run setup cell - CairoMakie will be loaded automatically
```

## Best Practices

### 1. Universal Setup Cell
- **Always use the same setup cell** - works everywhere
- **No path editing required** - automatically finds project root
- **Copy-paste friendly** - share notebooks without modification

### 2. Environment-Aware Development
- **Test locally first** - debug with full tools available
- **Optimize for HPC** - minimize plotting on cluster
- **Save results frequently** - don't lose work to job limits

### 3. Plotting Guidelines
- **Local**: Use full plotting capabilities for exploration
- **HPC**: Generate plots only when needed, save to files
- **Sharing**: PNG for quick viewing, PDF for publications

### 4. Resource Management
```julia
# Check available memory
using Sys
println("Available memory: ", Sys.free_memory() / 1024^3, " GB")

# Clean up after heavy computations
GC.gc()
```

## Troubleshooting

### Setup Cell Fails
1. **Check project structure**: Ensure you're in a Globtim project directory
2. **Verify environments exist**: `environments/local/` and `environments/hpc/` folders
3. **Use fallback setup**: See `.globtim/NOTEBOOK_TEMPLATE.md` for alternative

### Plotting Issues on HPC
```julia
# Check display settings
println("DISPLAY: ", get(ENV, "DISPLAY", "not set"))

# Force headless mode if needed
ENV["GKSwstype"] = "100"
```

### Package Loading Errors
```julia
# Reinstall environment if needed
using Pkg
Pkg.instantiate()
```

## Migration from Old Notebooks

### Updating Existing Notebooks
1. **Replace old setup code** with the universal setup cell
2. **Remove hardcoded paths** - no longer needed
3. **Test in both environments** - local and HPC if applicable

### Common Old Patterns to Replace
```julia
# OLD - Don't use these anymore
using Pkg; Pkg.activate(".")
include("../some/relative/path/setup.jl")
using CairoMakie, Globtim  # Manual loading

# NEW - Use this instead
include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))
```

## Advanced Usage

### Custom Environment Variables
```julia
# Force specific behavior
ENV["GLOBTIM_FORCE_PLOTTING"] = "true"    # Force plotting on HPC
ENV["GLOBTIM_ENV"] = "local"              # Override environment detection
```

### Validation and Debugging
```julia
# Check what was loaded
println("Globtim loaded: ", isdefined(Main, :Globtim))
println("CairoMakie loaded: ", isdefined(Main, :CairoMakie))
println("Current environment: ", Base.active_project())
```

## Integration with Development Workflow

### Local Development Cycle
1. Create notebook with universal setup
2. Develop and test with full plotting capabilities
3. Iterate with Revise.jl for fast development
4. Profile performance with ProfileView if needed

### HPC Deployment Cycle
1. Test notebook locally first
2. Transfer to HPC cluster (setup cell unchanged)
3. Run with optimized HPC environment
4. Collect results and transfer back for analysis

### Collaboration
- Notebooks work identically for all team members
- No environment-specific modifications needed
- Easy sharing and version control

This workflow ensures consistent, reliable notebook execution across all Globtim development scenarios.
