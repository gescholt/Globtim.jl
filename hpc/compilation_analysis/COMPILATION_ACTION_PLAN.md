# GlobTim HPC Compilation Action Plan
*Date: August 12, 2025*

## Executive Summary

The GlobTim package compilation on HPC is failing due to environment path mismatches and the lack of NFS access on compute nodes. We need a systematic approach to identify and fix the bottlenecks.

## Immediate Actions (Today)

### 1. Run Bundle Verification (⏱ 5 minutes)
```bash
# Already created, just needs execution
scp hpc/jobs/submission/test_bundle_verification.slurm falcon:~/
ssh scholten@falcon 'sbatch test_bundle_verification.slurm'
```
**Expected Output**: Confirms bundle structure and identifies exact paths

### 2. Run Toy Compilation Test (⏱ 15 minutes)
```bash
# Test minimal package compilation
scp hpc/compilation_analysis/toy_compilation_test.slurm falcon:~/
ssh scholten@falcon 'sbatch toy_compilation_test.slurm'
```
**Purpose**: Test if ANY Julia package can compile on compute nodes

### 3. Run Bottleneck Analysis (⏱ 20 minutes)
```bash
# Detailed bottleneck identification
scp hpc/compilation_analysis/bottleneck_analysis.slurm falcon:~/
ssh scholten@falcon 'sbatch bottleneck_analysis.slurm'
```
**Purpose**: Identify exactly WHERE compilation fails

## Key Bottlenecks to Investigate

### Bottleneck 1: Environment Path Mismatch
**Current Issue**:
```bash
# WRONG (what we were doing):
export JULIA_DEPOT_PATH="/tmp/globtim_JOBID/depot"

# CORRECT (what we should do):
export JULIA_DEPOT_PATH="/tmp/globtim_JOBID/globtim_bundle/depot"
```

**Test**: Bundle verification will confirm correct paths

### Bottleneck 2: Package Resolution Failure
**Symptoms**:
- "Package ForwardDiff not found in current path"
- Packages exist in depot but Julia can't find them

**Potential Causes**:
1. Missing registry information
2. Incorrect LOAD_PATH
3. Manifest.toml not matching depot contents

**Test**: Bottleneck analysis TEST 4 will identify which packages fail

### Bottleneck 3: Precompilation Cache Incompatibility
**Issue**: 
- Bundle created on macOS/Linux locally
- Cluster has different architecture/Julia version
- Precompiled `.ji` files may be incompatible

**Test**: Bottleneck analysis TEST 6 checks cache compatibility

### Bottleneck 4: Write Permissions in /tmp
**Question**: Can Julia write compiled cache to /tmp during job?

**Test**: Toy compilation test will verify write capabilities

## Solution Strategies

### Strategy A: Fix Existing Bundle (Quick Fix)
```julia
# In SLURM script
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz -C $WORK_DIR

# CRITICAL: Use correct paths!
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_LOAD_PATH="@:@v#.#:@stdlib"
export JULIA_NO_NETWORK="1"

# Force recompilation if needed
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Strategy B: Two-Stage Compilation (Robust)

#### Stage 1: Compile on Login Node
```bash
ssh scholten@falcon
cd /home/scholten

# Extract bundle
tar -xzf globtim_hpc_bundle.tar.gz

# Set environment
export JULIA_DEPOT_PATH="/home/scholten/globtim_bundle/depot"
export JULIA_PROJECT="/home/scholten/globtim_bundle/globtim_hpc"

# Compile everything
julia --project=. -e '
    using Pkg
    Pkg.instantiate()
    Pkg.precompile()
    
    # Load all GlobTim modules to trigger compilation
    include("src/Globtim.jl")
    using .Globtim
'

# Repackage with compiled cache
tar -czf globtim_compiled_bundle.tar.gz globtim_bundle/
```

#### Stage 2: Use Pre-compiled Bundle
```bash
# In SLURM jobs, use the pre-compiled bundle
tar -xzf /home/scholten/globtim_compiled_bundle.tar.gz -C /tmp/
# No compilation needed, just load and run
```

### Strategy C: Direct NFS Access (Investigation)
**Question**: Can we make NFS accessible to compute nodes?

**Test**:
```bash
# In SLURM job
ls -la /net/fileserver-nfs/ 2>&1
mount | grep nfs
```

If accessible, we could use fileserver depot directly.

## Critical Path Forward

### Step 1: Diagnose (Today)
1. ✅ Create test scripts (DONE)
2. ⏱ Run bundle verification
3. ⏱ Run toy compilation test
4. ⏱ Run bottleneck analysis
5. ⏱ Analyze outputs

### Step 2: Fix (Based on Results)

**If path mismatch**:
- Update all SLURM scripts with correct paths
- Test with simple package first

**If package resolution fails**:
- Rebuild bundle with explicit registry
- Include Manifest.toml verification

**If precompilation incompatible**:
- Compile on falcon login node
- Create architecture-specific bundle

**If write permissions issue**:
- Create writable depot in /tmp
- Set JULIA_DEPOT_PATH to include both read-only and writable

### Step 3: Validate
1. Test with single GlobTim module
2. Test with Deuflhard benchmark
3. Run full test suite

## Success Criteria

✅ **Milestone 1**: Any Julia package loads from bundle
✅ **Milestone 2**: ForwardDiff loads successfully
✅ **Milestone 3**: All GlobTim dependencies load
✅ **Milestone 4**: GlobTim modules compile and load
✅ **Milestone 5**: Deuflhard test runs successfully

## Monitoring Commands

```bash
# Submit test
ssh scholten@falcon 'sbatch test_script.slurm'

# Monitor
ssh scholten@falcon 'squeue -u scholten'

# Check output
ssh scholten@falcon 'tail -f test_*_JOBID.out'

# Collect results
scp falcon:~/test_*_JOBID.out ./hpc/compilation_analysis/results/
```

## Expected Timeline

- **Hour 1**: Run all diagnostic tests
- **Hour 2**: Analyze results, identify root cause
- **Hour 3**: Implement fix based on findings
- **Hour 4**: Test fix with GlobTim
- **Hour 5**: Document solution, update all scripts

## Risk Mitigation

**Risk**: Bundle approach may never work
**Mitigation**: Prepare alternative using Singularity containers

**Risk**: Compilation takes too long
**Mitigation**: Pre-compile on login node during off-peak hours

**Risk**: Architecture incompatibility
**Mitigation**: Build bundle directly on falcon login node

## Next Immediate Step

Run the three test scripts in order:
1. `test_bundle_verification.slurm`
2. `toy_compilation_test.slurm`  
3. `bottleneck_analysis.slurm`

Then analyze outputs to determine root cause.