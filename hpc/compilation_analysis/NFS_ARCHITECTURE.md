# NFS Architecture and Compilation Strategy
*Date: August 12, 2025*

## Current Architecture Understanding

### File System Layout

```
┌──────────────────────────────────────────────────────┐
│                   MACK (Fileserver)                   │
│  - NFS Storage: /net/fileserver-nfs/                 │
│  - User Home: /home/scholten/                        │
│  - Julia Depot: ~/.julia/ (302 packages)             │
│  - Can SSH but NOT submit SLURM jobs                 │
└──────────────────────────────────────────────────────┘
                           │
                    NFS Mount (Read/Write)
                           │
                           ↓
┌──────────────────────────────────────────────────────┐
│                  FALCON (Login Node)                  │
│  - Home: /home/scholten/ (1GB quota limit!)          │
│  - NFS Access: YES (from login node)                 │
│  - Can submit SLURM jobs                             │
│  - Bundle: /home/scholten/globtim_hpc_bundle.tar.gz  │
└──────────────────────────────────────────────────────┘
                           │
                    SLURM Job Submission
                           │
                           ↓
┌──────────────────────────────────────────────────────┐
│                COMPUTE NODES (Batch)                  │
│  - NFS Access: NO! (critical limitation)             │
│  - /tmp available for temporary files                │
│  - No internet access                                │
│  - Must extract bundle to /tmp for each job          │
└──────────────────────────────────────────────────────┘
```

## Key Constraints

1. **NFS Not Available on Compute Nodes**: This is the critical bottleneck
   - Cannot access fileserver Julia depot from compute nodes
   - Cannot write directly to NFS from SLURM jobs
   - Must use bundle approach

2. **Falcon Home Quota**: Only 1GB available
   - Bundle must fit in this space (currently 284MB compressed)
   - Cannot store large compiled caches here

3. **Job Output Location**:
   - SLURM output/error files written to submission directory
   - On falcon: `/home/scholten/*.out` and `*.err`
   - These ARE accessible after job completion

## Julia Package Compilation Process

### What Happens During Compilation?

1. **Package Loading** (`using PackageName`):
   ```
   depot/
   ├── packages/          # Source code
   │   └── PackageName/   # Read during loading
   ├── compiled/          # Precompiled cache
   │   └── v1.11/         # Written during first load
   │       └── PackageName/
   │           └── XXXXX.ji  # Compiled cache file
   ├── artifacts/         # Binary dependencies
   └── registries/        # Package registry
   ```

2. **Files Generated During Compilation**:
   - `.ji` files in `compiled/` directory
   - Preference files in `prefs/`
   - Logs in `logs/`

3. **Where Files Must Be**:
   - **Read**: Package source from `depot/packages/`
   - **Write**: Compiled cache to `depot/compiled/`
   - **Both must be on same filesystem** for Julia to work properly

## Current Bundle Approach Issues

### Why It's Failing

1. **Environment Path Mismatch**:
   ```bash
   # Bundle extracts to:
   /tmp/globtim_JOBID/globtim_bundle/depot/
   /tmp/globtim_JOBID/globtim_bundle/globtim_hpc/
   
   # But we were setting:
   JULIA_DEPOT_PATH="/tmp/globtim_JOBID/depot"  # WRONG!
   ```

2. **Precompilation Cache**:
   - Bundle includes precompiled files from local machine
   - These may not be compatible with cluster architecture
   - Julia tries to recompile but fails to find packages

3. **Package Resolution**:
   - Julia cannot find packages even though they exist
   - Likely due to incorrect DEPOT_PATH or LOAD_PATH

## Toy Example Plan

### Step 1: Minimal Package Test

Create a simple package with no external dependencies:

```julia
# ToyPackage.jl
module ToyPackage
    export greet
    greet(name) = "Hello, $name from ToyPackage!"
end
```

### Step 2: Test Compilation Locations

1. **Test A**: Compile on login node (has NFS)
2. **Test B**: Compile on compute node (no NFS)
3. **Test C**: Use pre-compiled bundle

### Step 3: Identify Bottlenecks

- Where does compilation fail?
- What error messages appear?
- Which files are missing?
- Can we write compiled cache to /tmp?

## Proposed Solutions

### Option 1: Fix Bundle Paths (Immediate)

```bash
# Correct environment setup
export JULIA_DEPOT_PATH="/tmp/globtim_${SLURM_JOB_ID}/globtim_bundle/depot"
export JULIA_PROJECT="/tmp/globtim_${SLURM_JOB_ID}/globtim_bundle/globtim_hpc"
export JULIA_LOAD_PATH="@:@v#.#:@stdlib"
```

### Option 2: Two-Stage Compilation (Robust)

1. **Stage 1**: Compile on login node with NFS access
   ```bash
   ssh falcon
   cd /home/scholten
   julia --project=globtim_hpc -e 'using Pkg; Pkg.instantiate()'
   ```

2. **Stage 2**: Create bundle with compiled cache
   ```bash
   tar -czf compiled_bundle.tar.gz depot/ globtim_hpc/
   ```

### Option 3: Direct /tmp Compilation (Experimental)

```bash
# Extract and compile in single job
tar -xzf bundle.tar.gz -C /tmp/
cd /tmp/globtim_bundle
export JULIA_DEPOT_PATH="/tmp/globtim_bundle/depot"
julia --project=globtim_hpc -e '
    using Pkg
    Pkg.instantiate()  # This will compile everything
    # Then run actual work
'
```

## Next Steps

1. Create toy package for testing
2. Run bundle verification to confirm structure
3. Test compilation with corrected paths
4. Monitor where files are written during compilation
5. Document exact error messages and missing components