# GlobTim HPC Guide - Complete Documentation
*Last Updated: August 12, 2025*

---

## ⚠️ CURRENT STATUS

### What Works ✅
- **Bundle Creation**: Successfully created 284MB offline bundle
- **Bundle Transfer**: Bundle deployed to `/home/scholten/globtim_hpc_bundle.tar.gz`
- **Bundle Extraction**: Bundle extracts correctly in SLURM jobs
- **Basic Julia**: Julia runs and basic packages load

### What DOESN'T Work ❌
- **GlobTim Compilation**: Package loading fails with "Package not found" errors
- **Module Loading**: GlobTim modules fail to load even with correct paths
- **Deuflhard Tests**: Test suite hangs during package loading
- **Critical Issue**: Environment variables not properly connecting bundle to Julia

### Latest Test Results (Aug 12, 2025)
- Job 59788972: ❌ Failed - ForwardDiff package not found
- Job 59788975: ❌ Failed - Same package loading issue  
- Job 59788968: ❌ Cancelled - Hung during package loading (>4 minutes)
- Job 59788803: ⚠️ Partial - Bundle extracted but no compilation tested

**CRITICAL**: The bundle system is NOT yet working for actual GlobTim compilation

---

## 📋 Table of Contents
1. [Overview](#overview)
2. [Bundle System](#bundle-system)
3. [Job Submission](#job-submission)
4. [Known Issues](#known-issues)
5. [Monitoring & Automation](#monitoring--automation)
6. [Troubleshooting](#troubleshooting)

---

## Overview

This guide consolidates all HPC-related documentation for running GlobTim on the MPI-CBG cluster (falcon/mack).

### System Architecture
- **mack**: Fileserver with NFS storage (unlimited space, package management)
- **falcon**: Compute cluster for job submission (1GB home quota limit)
- **NFS Mount**: `/net/fileserver-nfs/` accessible from login nodes only
- **Julia**: Version 1.11.2 at `/sw/bin/julia`

### Key Constraints
1. ❌ **No internet access** on compute nodes
2. ❌ **1GB home directory quota** on falcon
3. ❌ **NFS not accessible** from compute nodes
4. ⚠️ **Current Issue**: Bundle not properly loading packages

---

## Bundle System

### Current Bundle Status
- **Location**: `/home/scholten/globtim_hpc_bundle.tar.gz`
- **Size**: 284MB compressed (771MB uncompressed)
- **Contents**: Complete Julia depot with all dependencies except plotting packages
- **Status**: ⚠️ **NOT WORKING** - Packages fail to load

### Why Bundle System?
GlobTim requires many external packages that cannot be installed on air-gapped compute nodes:
- `ForwardDiff` - Automatic differentiation
- `HomotopyContinuation` - Polynomial system solving
- `DynamicPolynomials` - Polynomial manipulation
- `StaticArrays` - Performance-critical arrays
- `TimerOutputs` - Performance monitoring
- `Optim` - Optimization algorithms

### Creating/Updating the Bundle

**On local machine with internet:**
```bash
# 1. Create isolated depot
cd ~/globtim/julia_offline_prep_hpc
export JULIA_DEPOT_PATH="$PWD/depot"
export JULIA_PROJECT="$PWD/globtim_hpc"

# 2. Update dependencies
julia --project=. -e '
    using Pkg
    Pkg.Registry.update()
    Pkg.instantiate()
    Pkg.precompile()
'

# 3. Create bundle
tar -czf globtim_hpc_bundle.tar.gz depot/ globtim_hpc/

# 4. Transfer to HPC
rsync -avz globtim_hpc_bundle.tar.gz scholten@falcon:/home/scholten/
```

---

## Job Submission

### Basic SLURM Template

```bash
#!/bin/bash
#SBATCH --job-name=globtim_job
#SBATCH --account=mpi           # REQUIRED
#SBATCH --partition=batch       # REQUIRED
#SBATCH --time=01:00:00
#SBATCH --mem=16G
#SBATCH --output=job_%j.out
#SBATCH --error=job_%j.err

# Extract bundle (REQUIRED for every job)
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR && cd $WORK_DIR
tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz

# Set environment (REQUIRED)
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_NO_NETWORK="1"

# Run Julia code
cd $JULIA_PROJECT
/sw/bin/julia --project=. -e '
    # Load packages
    using ForwardDiff, StaticArrays, DynamicPolynomials
    
    # Load GlobTim modules
    include("src/BenchmarkFunctions.jl")
    include("src/LibFunctions.jl")
    include("src/Samples.jl")
    include("src/Structures.jl")
    include("src/Constructor.jl")
    
    # Your computation here
    println("GlobTim loaded successfully")
'

# Cleanup (IMPORTANT)
cd /tmp && rm -rf $WORK_DIR
```

### Submit and Monitor

```bash
# Submit job
ssh scholten@falcon "sbatch your_job.slurm"

# Check status
ssh scholten@falcon "squeue -u scholten"

# View output
ssh scholten@falcon "tail -f job_12345.out"

# Cancel job
ssh scholten@falcon "scancel 12345"
```

---

## 🔧 NEXT STEPS TO FIX

The bundle exists but Julia cannot find the packages. Potential fixes to try:

1. **Fix Environment Path Issue**:
   ```bash
   # The bundle extracts to globtim_bundle/ but we're setting paths wrong
   # Current (WRONG):
   export JULIA_DEPOT_PATH="$WORK_DIR/depot"
   export JULIA_PROJECT="$WORK_DIR/globtim_hpc"
   
   # Should be (CORRECT):
   export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
   export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
   ```

2. **Verify Bundle Structure**:
   - Need to run test_bundle_verification.slurm to check structure
   - Confirm packages are actually in depot/packages/

3. **Test Direct Package Loading**:
   ```julia
   # Explicitly add depot to LOAD_PATH
   push!(LOAD_PATH, ENV["JULIA_DEPOT_PATH"])
   push!(DEPOT_PATH, ENV["JULIA_DEPOT_PATH"])
   ```

4. **Consider Alternative Approaches**:
   - Use Pkg.activate() instead of --project flag
   - Try using full paths in Julia code
   - Test with simpler package first (just ForwardDiff)

---

## Known Issues

### 1. Package Loading Hangs
**Symptom**: Jobs hang during `using PackageName`  
**Cause**: Initial precompilation can take 5-10 minutes  
**Solution**: Increase job time limit, wait for precompilation

### 2. Package Not Found Errors
**Symptom**: `ERROR: ArgumentError: Package X not found`  
**Cause**: Bundle extraction failed or environment not set correctly  
**Solution**: Verify bundle extraction and environment variables:
```bash
# Check in SLURM script
ls -la $WORK_DIR/globtim_bundle/depot/packages/
echo "JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"
echo "JULIA_PROJECT=$JULIA_PROJECT"
```

### 3. Exit Code 53
**Symptom**: Jobs fail with exit code 53  
**Cause**: SLURM parameter formatting issues  
**Solution**: Use simple parameter format, avoid complex strings

### 4. Disk Quota Exceeded
**Symptom**: `Cannot mkdir: Disk quota exceeded`  
**Cause**: Falcon home directory has 1GB limit  
**Solution**: 
- Use `/tmp` for temporary files
- Keep only essential files in home
- Clean up after jobs

### 5. NFS Not Accessible
**Symptom**: `/net/fileserver-nfs/: No such file or directory`  
**Cause**: NFS mount not available on compute nodes  
**Solution**: Use bundle in home directory, not NFS

---

## Monitoring & Automation

### Automated Job Monitor
Located at `hpc/monitoring/job_monitor.py`:

```bash
# Submit and monitor compilation test
python hpc/monitoring/job_monitor.py --submit

# Monitor specific job
python hpc/monitoring/job_monitor.py --monitor 12345

# Check compilation success
python hpc/monitoring/job_monitor.py --check 12345

# Generate report for multiple jobs
python hpc/monitoring/job_monitor.py --report 12345 12346 12347
```

### Quick Monitor Script
Use `hpc/monitoring/monitor.sh`:

```bash
# Submit test job
./monitor.sh test

# Monitor job
./monitor.sh monitor 12345

# Check all recent jobs
./monitor.sh status

# Generate report
./monitor.sh report 12345 12346
```

---

## Troubleshooting

### Debugging Checklist

1. **Verify bundle exists**:
   ```bash
   ssh scholten@falcon "ls -lh /home/scholten/globtim_hpc_bundle.tar.gz"
   ```

2. **Test bundle extraction**:
   ```bash
   ssh scholten@falcon "tar -tzf /home/scholten/globtim_hpc_bundle.tar.gz | head"
   ```

3. **Check Julia version**:
   ```bash
   ssh scholten@falcon "/sw/bin/julia --version"
   ```

4. **Test simple Julia job**:
   ```bash
   ssh scholten@falcon 'sbatch --wrap="/sw/bin/julia -e \"println(\\\"Hello\\\")\""'
   ```

5. **Check job errors**:
   ```bash
   ssh scholten@falcon "cat job_12345.err"
   ```

### Common Fixes

**Julia not loading packages**:
```julia
# In SLURM script, explicitly set paths
ENV["JULIA_DEPOT_PATH"] = "/tmp/globtim_12345/globtim_bundle/depot"
ENV["JULIA_PROJECT"] = "/tmp/globtim_12345/globtim_bundle/globtim_hpc"
ENV["JULIA_LOAD_PATH"] = "@:@v#.#:@stdlib"
```

**Module not found**:
```julia
# Use absolute paths for includes
base_dir = ENV["JULIA_PROJECT"]
include(joinpath(base_dir, "src", "BenchmarkFunctions.jl"))
```

**Memory issues**:
```bash
# Increase memory allocation
#SBATCH --mem=32G
```

---

## Quick Reference

### Essential Commands
```bash
# Submit job
ssh scholten@falcon "cd /home/scholten && sbatch job.slurm"

# Check queue
ssh scholten@falcon "squeue -u scholten"

# Job info
ssh scholten@falcon "sacct -j 12345 --format=JobID,State,ExitCode,Elapsed"

# Cancel all jobs
ssh scholten@falcon "scancel -u scholten"

# Disk usage
ssh scholten@falcon "du -sh ~/*"
```

### File Locations
- Bundle: `/home/scholten/globtim_hpc_bundle.tar.gz`
- Job outputs: `/home/scholten/*_[JOBID].out`
- Job errors: `/home/scholten/*_[JOBID].err`
- Temp work: `/tmp/globtim_[JOBID]/`

### Environment Variables
```bash
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_NO_NETWORK="1"
export JULIA_NUM_THREADS="4"  # Optional: for parallel execution
```

---

## Support

For issues or questions:
1. Check this guide first
2. Review error logs carefully
3. Test with minimal example
4. Document error messages and job IDs

---

*This document consolidates and replaces all previous HPC documentation.*