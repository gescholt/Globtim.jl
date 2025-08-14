# HPC Package Bundling Strategy for GlobTim

## Problem Statement

The HPC cluster has a corrupted Julia package registry that prevents downloading and installing packages directly. We need to pre-bundle all dependencies locally and deploy them to the cluster.

## Solution: Offline Package Deployment

### Strategy Overview

1. **Local Preparation**: Install and compile all packages locally
2. **Bundle Creation**: Package the compiled artifacts
3. **Transfer**: Upload the bundle to HPC
4. **Deployment**: Extract and use on HPC without network access

## Implementation Steps

### Step 1: Create Local Julia Depot

```bash
# On your local machine
mkdir -p ~/globtim_bundle
cd ~/globtim_bundle

# Create a clean depot
export JULIA_DEPOT_PATH="$(pwd)/depot"
mkdir -p depot
```

### Step 2: Install All Dependencies Locally

Create a script `prepare_bundle.jl`:

```julia
# prepare_bundle.jl
using Pkg

# Create a new environment
Pkg.activate("globtim_env")

# Add all required packages
packages = [
    "CSV",
    "DataFrames", 
    "StaticArrays",
    "ForwardDiff",
    "Parameters",
    "DynamicPolynomials",
    "LinearAlgebra",
    "Statistics",
    "Random",
    "Test"
]

for pkg in packages
    println("Adding $pkg...")
    Pkg.add(pkg)
end

# Precompile everything
Pkg.precompile()

# Test that packages work
using CSV
using DataFrames
using StaticArrays
using ForwardDiff

println("✅ All packages installed and working!")
```

### Step 3: Create Bundled Archive

```bash
# Bundle the depot and environment
tar -czf globtim_bundle.tar.gz depot/ globtim_env/

# Include the source code
cp -r ~/globtim/src ./
tar -czf globtim_complete.tar.gz depot/ globtim_env/ src/
```

### Step 4: Transfer to HPC

```bash
# Upload the bundle
scp globtim_complete.tar.gz scholten@falcon:~/

# On the cluster, extract it
ssh scholten@falcon
tar -xzf globtim_complete.tar.gz -C ~/globtim_hpc/
```

### Step 5: Use Bundled Packages on HPC

Create `use_bundle.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=globtim_bundled
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G

# Use the bundled depot
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/depot"
export JULIA_LOAD_PATH="@:$HOME/globtim_hpc/globtim_env:@stdlib"

cd $HOME/globtim_hpc

/sw/bin/julia --project=globtim_env << 'EOF'
# All packages are pre-installed in the bundle
using CSV
using DataFrames
using StaticArrays
using ForwardDiff

# Load GlobTim
include("src/Globtim.jl")
using .Globtim

# Run tests
println("Testing Globtim with bundled packages...")
result = Globtim.Sphere([1.0, 1.0])
println("Sphere([1,1]) = ", result)

println("✅ Bundled version working!")
EOF
```

## Alternative: Vendoring Approach

### Create Self-Contained Package

Instead of relying on Julia's package system, vendor all dependencies:

```julia
# vendor_globtim.jl
module VendoredGlobtim

# Include vendored dependencies directly
include("vendor/StaticArrays.jl")
include("vendor/ForwardDiff.jl")
include("vendor/Parameters.jl")

# Now include GlobTim code
include("src/Structures.jl")
include("src/BenchmarkFunctions.jl")
include("src/LibFunctions.jl")
include("src/Samples.jl")

# Export everything
export Sphere, Rosenbrock, Deuflhard
export test_input, globtim

end # module
```

## Hybrid Approach: Progressive Enhancement

Use a fallback system that works with available packages:

```julia
module GlobtimAdaptive

# Core functionality (always available)
using LinearAlgebra, Statistics, Random

# Try to load optional packages
const HAS_CSV = try
    using CSV
    true
catch
    false
end

const HAS_DATAFRAMES = try
    using DataFrames
    true
catch
    false
end

const HAS_FORWARDDIFF = try
    using ForwardDiff
    true
catch
    false
end

# Conditional features
if HAS_CSV
    include("io/csv_functions.jl")
else
    # Fallback I/O
    include("io/text_functions.jl")
end

if HAS_FORWARDDIFF
    include("optimization/autodiff.jl")
else
    # Finite differences fallback
    include("optimization/finite_diff.jl")
end

# Core functions always available
include("core/benchmark_functions.jl")
include("core/sampling.jl")

end # module
```

## Recommended Workflow

### For Development

1. Use local machine with full Julia environment
2. Test with all packages
3. Create standalone version for HPC

### For HPC Deployment

1. **Option A**: Use `GlobtimProduction.jl` (no dependencies) ✅
2. **Option B**: Pre-bundle packages and transfer
3. **Option C**: Use containerization (Singularity/Apptainer)

### Container Approach

Create a Singularity definition file:

```singularity
Bootstrap: docker
From: julia:1.11

%files
    ./src /opt/globtim/src
    ./Project.toml /opt/globtim/
    ./Manifest.toml /opt/globtim/

%post
    cd /opt/globtim
    julia --project=. -e 'using Pkg; Pkg.instantiate()'

%runscript
    cd /opt/globtim
    julia --project=. "$@"
```

Build and use:
```bash
# Build locally
singularity build globtim.sif globtim.def

# Transfer to HPC
scp globtim.sif scholten@falcon:~/

# Run on HPC
singularity exec globtim.sif julia -e 'using Globtim'
```

## Implementation Priority

1. **Immediate**: Continue using `GlobtimProduction.jl` ✅
2. **Short-term**: Implement package bundling for full features
3. **Long-term**: Container-based deployment for reproducibility

## Next Steps

1. Create bundling script for local preparation
2. Test bundle deployment on HPC
3. Document the process for team members
4. Automate with CI/CD pipeline