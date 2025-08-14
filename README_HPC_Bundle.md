# Globtim HPC Bundle - Deployment Guide

## Overview

This bundle contains a complete, offline Julia environment for running Globtim on HPC clusters without internet access. The bundle excludes plotting packages to minimize size and dependencies while retaining all computational capabilities.

## Bundle Contents

- **Depot**: Complete Julia package depot (718MB, 12,564 files)
- **Project**: HPC-optimized Globtim project configuration
- **Scripts**: Installation and testing utilities
- **Documentation**: This guide and manifest files

## Package Configuration

### Included Packages (387 total)
- **Standard Library**: 11 packages (LinearAlgebra, Statistics, Random, etc.)
- **Regular Packages**: 276 packages (computational and utility packages)
- **Binary Dependencies**: 100 packages (compiled libraries and JLL packages)

### Key Computational Packages
- `ForwardDiff` - Automatic differentiation
- `HomotopyContinuation` - Polynomial system solving
- `DynamicPolynomials` - Polynomial manipulation
- `Optim` - Optimization algorithms
- `BenchmarkTools` - Performance testing
- `LinearSolve` - Linear algebra solvers
- `SpecialFunctions` - Mathematical functions
- `Distributions` - Probability distributions
- `CSV`, `DataFrames` - Data handling
- `JSON3`, `YAML` - Serialization

### Excluded Packages
- `Makie` - Main plotting library
- `Colors` - Color handling for visualizations
- `CairoMakie` - Static plot backend
- `GLMakie` - Interactive plot backend

*Note: Some plotting packages may appear as transitive dependencies but are not directly accessible.*

## Installation Instructions

### Option A: Automated Deployment (Recommended)

Use the provided deployment script that handles SSH key authentication:

```bash
# Deploy bundle and install automatically
./deploy_to_hpc.sh julia_depot_bundle_hpc_20250812.tar.gz
```

This script will:
1. Transfer the bundle to the fileserver using SSH keys
2. Transfer all installation scripts and documentation
3. Install the bundle automatically
4. Run basic functionality tests
5. Provide next steps for SLURM testing

### Option B: Manual Deployment

### 1. Transfer Bundle to Cluster

```bash
# From local machine to fileserver using rsync (recommended)
rsync -avz --progress -e "ssh -i ~/.ssh/id_ed25519" \
    julia_depot_bundle_hpc_20250812.tar.gz scholten@fileserver-ssh:~/globtim_hpc/

# Alternative: using scp
scp -i ~/.ssh/id_ed25519 julia_depot_bundle_hpc_20250812.tar.gz scholten@fileserver-ssh:~/globtim_hpc/

# From fileserver to cluster (if needed)
ssh -i ~/.ssh/id_ed25519 scholten@fileserver-ssh
scp julia_depot_bundle_hpc_20250812.tar.gz falcon:~/globtim_hpc/
```

### 2. Install on Cluster

```bash
# On fileserver - following HPC workflow pattern
ssh -i ~/.ssh/id_ed25519 scholten@fileserver-ssh
cd ~/globtim_hpc
./install_bundle_hpc.sh julia_depot_bundle_hpc_20250812.tar.gz
```

### 3. Set Up Environment

```bash
# Source the environment (do this in each session)
source ~/globtim_hpc/setup_offline_julia_hpc.sh

# Verify installation
julia --project=$JULIA_PROJECT --compiled-modules=no test_hpc_bundle.jl
```

## Usage

### Interactive Use

```bash
# Start Julia with HPC environment
source /globtim_hpc/setup_offline_julia_hpc.sh
julia --project=$JULIA_PROJECT --compiled-modules=no

# Check package status
julia --project=$JULIA_PROJECT -e 'using Pkg; Pkg.status()'
```

### SLURM Jobs

Add these lines to your SLURM job scripts:

```bash
#!/bin/bash
#SBATCH --job-name=globtim_job
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=01:00:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000

# Source HPC environment
source /globtim_hpc/setup_offline_julia_hpc.sh

# Run your Julia script
julia --project=$JULIA_PROJECT --compiled-modules=no your_script.jl
```

### Test the Installation

```bash
# Submit test job
sbatch test_hpc_bundle.slurm

# Check results
cat test_globtim_hpc_*.out
```

## Environment Variables

The bundle sets these environment variables:

- `JULIA_DEPOT_PATH=/globtim_hpc/depot` - Package depot location
- `JULIA_PROJECT=/globtim_hpc/globtim_hpc` - Project configuration
- `JULIA_PKG_SERVER=""` - Disable package server (offline mode)
- `JULIA_NO_NETWORK="1"` - Disable network access
- `TMPDIR=$HOME/.julia_tmp` - Temporary directory
- `JULIA_PKG_PRECOMPILE_AUTO=0` - Disable auto-precompilation

## Troubleshooting

### Common Issues

1. **Package not found errors**
   - Ensure environment is sourced: `source /globtim_hpc/setup_offline_julia_hpc.sh`
   - Check depot path: `echo $JULIA_DEPOT_PATH`

2. **Precompilation issues**
   - Use `--compiled-modules=no` flag
   - Clear temp directory: `rm -rf $TMPDIR/*`

3. **Memory issues**
   - Increase `--mem-per-cpu` in SLURM jobs
   - Monitor memory usage with `htop` or `free -h`

### Verification Commands

```bash
# Check environment
env | grep JULIA

# Test package loading
julia --project=$JULIA_PROJECT --compiled-modules=no -e 'using ForwardDiff; println("✅ ForwardDiff works")'

# Check depot contents
ls -la $JULIA_DEPOT_PATH
```

## Bundle Information

- **Created**: August 12, 2025
- **Julia Version**: 1.11.6
- **Bundle Size**: 270MB (compressed), 718MB (uncompressed)
- **Package Count**: 387 packages
- **Verification**: All key packages tested and working

## Files Included

- `julia_depot_bundle_hpc_20250812.tar.gz` - Main bundle archive
- `deploy_to_hpc.sh` - Automated deployment script (uses SSH keys)
- `install_bundle_hpc.sh` - Manual installation script
- `test_hpc_bundle.slurm` - SLURM test script
- `bundle_manifest_hpc.txt` - Detailed manifest
- `README_HPC_Bundle.md` - This documentation

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the original bundle creation instructions in `instructions/bundle_hpc.md`
3. Verify your HPC environment matches the expected configuration

---

**Important**: This bundle is specifically configured for the Furiosa HPC cluster environment. Modifications may be needed for other cluster configurations.
