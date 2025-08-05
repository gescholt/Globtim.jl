# HPC Cluster Notebook Setup Strategy

## Overview

The same universal notebook setup works on HPC clusters with automatic environment detection. However, there are specific considerations for cluster usage.

## Universal Setup (Works on HPC)

The same setup cell works on both local and HPC environments:

```julia
# Globtim Notebook Setup - Universal Header Cell
include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))
```

## HPC-Specific Considerations

### 1. Environment Detection
The setup automatically detects HPC environment based on:
- SLURM job environment variables (`SLURM_JOB_ID`)
- PBS scheduler variables (`PBS_JOBID`)
- Hostname patterns (`cluster`, `node`, `furiosa`)
- Other common HPC indicators

### 2. Optimized Package Loading
On HPC, the setup:
- Uses minimal dependencies for faster startup
- Loads plotting via extensions only when needed
- Optimizes for computational performance over interactivity
- Reduces memory footprint

### 3. Plotting Strategy on HPC

#### Option A: No Plotting (Default)
```julia
# HPC setup loads Globtim without plotting by default
# Fastest startup, minimal memory usage
```

#### Option B: Add Plotting When Needed
```julia
# After running setup cell, add plotting if needed:
using CairoMakie
CairoMakie.activate!()
# Now plotting functions work
```

#### Option C: Force Plotting in Setup
```julia
# Set environment variable before setup to force plotting
ENV["GLOBTIM_FORCE_PLOTTING"] = "true"
include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))
```

## Recommended HPC Workflow

### For Computational Notebooks (No Plotting)
1. Use standard setup cell
2. Run computations with Globtim
3. Save results to files
4. Transfer results to local machine for visualization

### For Analysis Notebooks (With Plotting)
1. Use standard setup cell
2. Add `using CairoMakie; CairoMakie.activate!()` when plotting needed
3. Generate plots and save to files
4. Use PNG/PDF output for cluster-generated plots

### For Interactive Development
1. Use standard setup cell
2. Consider using `GLMakie` for interactive plots if X11 forwarding available
3. Fallback to `CairoMakie` for static plots

## File Transfer Considerations

### Results Export
```julia
# Save computational results
using CSV, DataFrames
CSV.write("results.csv", results_df)

# Save plots
using CairoMakie
save("plot.png", fig)
save("plot.pdf", fig)  # For publications
```

### Notebook Synchronization
- Notebooks with universal setup work identically on local and HPC
- No need to modify setup when transferring between environments
- Results and plots can be generated on cluster, analyzed locally

## Performance Optimization

### Memory Management
```julia
# After heavy computations, clean up if needed
GC.gc()  # Force garbage collection
```

### Batch Processing
```julia
# For large parameter sweeps, consider batch processing
# Save intermediate results frequently
for i in 1:n_batches
    results = run_batch(i)
    save("batch_$i.jld2", results)
end
```

## Troubleshooting HPC Issues

### Module Loading
Some clusters require loading modules:
```bash
# Before starting Julia
module load julia
module load gcc  # If needed for compilation
```

### Display Issues
If plotting fails on cluster:
```julia
# Check display availability
println("DISPLAY: ", get(ENV, "DISPLAY", "not set"))

# Force headless mode
ENV["GKSwstype"] = "100"  # For GR backend
```

### Memory Limits
For large computations:
```julia
# Check memory usage
using Sys
println("Available memory: ", Sys.free_memory() / 1024^3, " GB")
```

## Integration with SLURM

### Job Scripts
```bash
#!/bin/bash
#SBATCH --job-name=globtim_analysis
#SBATCH --time=02:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4

module load julia
julia notebook_script.jl
```

### Notebook Execution
```julia
# notebook_script.jl
include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))

# Your analysis code here
results = run_analysis()
save_results(results)
```

## Best Practices

1. **Use Universal Setup**: Same setup cell works everywhere
2. **Minimize Plotting on HPC**: Add plotting only when needed
3. **Save Results Frequently**: Don't lose work due to job limits
4. **Test Locally First**: Debug on local machine, run on cluster
5. **Monitor Resources**: Check memory and time usage
6. **Clean Output**: Remove large intermediate files

## Example HPC Notebook Structure

```julia
# Cell 1: Universal Setup
include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))

# Cell 2: Load additional packages if needed
# (plotting packages loaded on demand)

# Cell 3: Define parameters
params = setup_parameters()

# Cell 4: Run computations
results = run_globtim_analysis(params)

# Cell 5: Save results
save_results("hpc_results.csv", results)

# Cell 6: Generate plots (if needed)
using CairoMakie
fig = plot_results(results)
save("hpc_plot.png", fig)
```

This strategy ensures notebooks work seamlessly across local and HPC environments while optimizing for each platform's strengths.
