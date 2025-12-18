# GlobTim Cluster Workflow - Current Working Process

## ✅ Status: FULLY OPERATIONAL
**Last Updated:** August 21, 2025  
**Verified On:** Falcon cluster (Job ID: 59808907)  
**Bundle:** `globtim_optimal_bundle_20250821_152938.tar.gz`

## Overview

This document provides the **current working workflow** for using GlobTim on the HPC cluster. The installation is complete and ready to use.

## Quick Reference

### Available Resources
- **Cluster:** falcon.hpc.uni-oldenburg.de
- **Bundle Location:** `/home/globaloptim/globtimcore_optimal_bundle_20250821_152938.tar.gz`
- **Julia Version:** 1.11.2 at `/sw/bin/julia`
- **Account:** `mpi`
- **Partition:** `batch`

### Working Environment Variables
```bash
export JULIA_DEPOT_PATH="/tmp/globtim_${SLURM_JOB_ID}/build_temp/depot"
export JULIA_PROJECT="/tmp/globtim_${SLURM_JOB_ID}/build_temp"
export JULIA_NO_NETWORK="1"
```

## Standard Workflow

### 1. Connect to Cluster
```bash
ssh scholten@falcon
```

### 2. Create SLURM Job Script
```bash
cat > my_globtim_job.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=globtim_work
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --output=globtim_%j.out
#SBATCH --error=globtim_%j.err

echo "=== GlobTim Job Started ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Date: $(date)"

# Setup work directory in /tmp (avoids home quota)
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
echo "Work directory: $WORK_DIR"
mkdir -p $WORK_DIR && cd $WORK_DIR

# Extract the working bundle
echo "Extracting bundle..."
tar -xzf /home/globaloptim/globtimcore_optimal_bundle_20250821_152938.tar.gz

# Configure Julia environment
export JULIA_DEPOT_PATH="$WORK_DIR/build_temp/depot"
export JULIA_PROJECT="$WORK_DIR/build_temp"
export JULIA_NO_NETWORK="1"
export JULIA_PKG_OFFLINE="true"

echo "Environment configured:"
echo "  JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"
echo "  JULIA_PROJECT=$JULIA_PROJECT"

# Verify setup
if [ -f "$JULIA_PROJECT/Manifest.toml" ]; then
    echo "✅ Manifest.toml found: $(ls -lh $JULIA_PROJECT/Manifest.toml)"
else
    echo "❌ Manifest.toml not found!"
    exit 1
fi

# Run your Julia code here
echo "Running Julia code..."
/sw/bin/julia --project=$JULIA_PROJECT --compiled-modules=no -e "
    # Your GlobTim code goes here
    using ForwardDiff
    println(\"✅ ForwardDiff loaded successfully\")
    
    # Example computation
    f(x) = sum(x.^2)
    x = [1.0, 2.0, 3.0]
    grad = ForwardDiff.gradient(f, x)
    println(\"Example gradient: \$grad\")
"

# Or run a Julia script
# /sw/bin/julia --project=$JULIA_PROJECT --compiled-modules=no your_script.jl

echo "Job completed at $(date)"

# Cleanup work directory
echo "Cleaning up..."
cd /tmp && rm -rf $WORK_DIR

echo "✅ Job finished successfully"
EOF
```

### 3. Submit Job
```bash
sbatch my_globtim_job.slurm
```

### 4. Monitor Job
```bash
# Check job status
squeue -u scholten

# View output (replace JOBID with actual job ID)
cat globtim_JOBID.out
cat globtim_JOBID.err
```

## Available Packages

The bundle includes all necessary packages for GlobTim:

### Core Computational Packages
- **ForwardDiff** - Automatic differentiation
- **StaticArrays** - High-performance arrays
- **HomotopyContinuation** - Polynomial system solving
- **DynamicPolynomials** - Polynomial manipulation
- **LinearAlgebra** - Linear algebra operations
- **Optim** - Optimization algorithms

### Utility Packages
- **Parameters** - Parameter handling
- **TimerOutputs** - Performance monitoring
- **DataFrames** - Data manipulation
- **CSV** - File I/O
- **JSON3** - JSON serialization
- **YAML** - Configuration files

### Usage Example
```julia
using ForwardDiff, StaticArrays, HomotopyContinuation

# Automatic differentiation
f(x) = sum(x.^4) + sum(x.^2)
x = [1.0, 2.0, 3.0]
gradient = ForwardDiff.gradient(f, x)

# Static arrays for performance
sv = SVector(1.0, 2.0, 3.0)
result = norm(sv)

# Polynomial system solving
@var x y
system = [x^2 + y^2 - 1, x + y]
solutions = solve(system)
```

## Troubleshooting

### Common Issues

1. **Job fails immediately**
   - Check that `--account=mpi` is specified
   - Verify bundle path is correct
   - Ensure sufficient memory allocation

2. **Julia hangs on package loading**
   - Always use `--compiled-modules=no` flag
   - Verify `JULIA_NO_NETWORK="1"` is set
   - Check that Manifest.toml exists

3. **Out of disk space**
   - Always use `/tmp/globtim_${SLURM_JOB_ID}` for work directory
   - Clean up work directory at job end
   - Home directory has 1GB quota limit

### Getting Help

1. Check job output files: `globtim_JOBID.out` and `globtim_JOBID.err`
2. Verify bundle integrity: `tar -tzf /home/globaloptim/globtimcore_optimal_bundle_20250821_152938.tar.gz | head`
3. Test basic Julia: `/sw/bin/julia --version`

## Performance Tips

1. **Memory Allocation**: Request appropriate memory (4-16GB typical)
2. **CPU Cores**: Use `--cpus-per-task=4` for parallel computations
3. **Time Limits**: Start with 30 minutes, increase as needed
4. **Work Directory**: Always use `/tmp` to avoid quota issues
5. **Cleanup**: Always remove work directory to free space

## Next Steps

The GlobTim installation is ready for production use. You can now:

1. Run your existing GlobTim scripts
2. Develop new computational workflows
3. Scale up to larger problems
4. Integrate with other HPC tools

For advanced usage and development, see the full `HPC_DEPLOYMENT_GUIDE.md`.
