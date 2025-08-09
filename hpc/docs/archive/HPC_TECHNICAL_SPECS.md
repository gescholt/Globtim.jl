# ⚠️ ARCHIVED: Globtim HPC Technical Specifications

> **🚨 THIS DOCUMENT IS ARCHIVED AND MAY CONTAIN OUTDATED INFORMATION** 🚨
>
> **USE CURRENT DOCUMENTATION INSTEAD**:
> - **📖 [FILESERVER_INTEGRATION_GUIDE.md](../FILESERVER_INTEGRATION_GUIDE.md)** - **PRIMARY REFERENCE** for current workflow
> - **📊 [HPC_STATUS_SUMMARY.md](../HPC_STATUS_SUMMARY.md)** - Current system status
> - **📈 [HPC_WORKFLOW_STATUS.md](../../HPC_WORKFLOW_STATUS.md)** - Detailed status report
> - **⚡ [WORKFLOW_CRITICAL.md](../../WORKFLOW_CRITICAL.md)** - Quick start guide
>
> This document is preserved for historical reference only.

## Cluster Configuration

### Hardware Specifications
- **Cluster Name**: furiosa
- **Login Node**: falcon1 (24-core)
- **Export Node**: furiosa-mack (large data transfers)
- **Total Compute Resources**: 3120+ cores across multiple partitions

### Software Environment
- **OS**: CentOS/RHEL 7
- **Job Scheduler**: SLURM
- **Julia Version**: 1.11.2 (located at `/sw/bin/julia`)
- **Package Manager**: No module system (direct binary access)

## Verified Performance Metrics

### Successful Test Run (Job ID: 59769879)
```
Node: c02n10
CPUs: 4 cores
Memory: 8GB allocated
Runtime: 27 seconds
Julia Version: 1.11.2
Threading: 4 threads active
Exit Code: 0 (success)
Temp Storage: 390GB available
```

### Julia Threading Performance
```julia
# Verified working with 4 threads
Threads.@threads for i in 1:Threads.nthreads()
    results[i] = sum(rand(1000))
end
# Results: [499.63, 499.14, 487.32, 496.61]
```

## Storage Architecture

### File System Layout
```
/home/scholten/          # 1GB quota limit
├── *.slurm             # Job scripts only
├── *.out, *.err        # Job outputs (clean regularly)
└── config files        # Small configuration files

# ⚠️ DEPRECATED: /tmp approach is no longer allowed
/tmp/globtim_${JOB_ID}/  # ❌ FORBIDDEN - Job working directory
├── src/                # ❌ DEPRECATED - Globtim source code
├── Project.toml        # ❌ DEPRECATED - Lightweight dependencies
└── temporary files     # ❌ DEPRECATED - Auto-cleaned after job

/tmp/julia_depot_${USER}_${JOB_ID}/  # ❌ FORBIDDEN - Julia packages
├── packages/           # ❌ DEPRECATED - Temporary package installation
├── compiled/           # ❌ DEPRECATED - Compiled modules
└── registries/         # ❌ DEPRECATED - Package registries

# ✅ CURRENT APPROACH: Use fileserver integration instead
# See: hpc/docs/FILESERVER_INTEGRATION_GUIDE.md
```

### Disk Usage Patterns
- **Home directory**: <20MB (scripts + outputs)
- **Temporary storage**: 2-10GB per job (auto-cleaned)
- **Available temp space**: 390GB+ per node

## Network Configuration

### SSH Connection Chain
```
Local Machine → Fileserver → HPC Cluster
     ↓              ↓            ↓
   Development    Backup    Computation
```

### Connection Details
- **Fileserver**: `scholten@fileserver-ssh` (backup storage)
- **HPC Login**: `scholten@falcon` (job submission)
- **Compute Nodes**: `c02n10`, etc. (job execution)

## SLURM Resource Allocation

### Partition Specifications
```yaml
batch:
  nodes: 105 thin + 15 GPU nodes
  cores_per_node: 24 (thin) / 40 (GPU)
  total_cores: 3120
  max_memory_per_node: 256GB
  max_runtime: 24h
  default_runtime: 2h
  default_memory_per_core: 5GB

long:
  nodes: 32 thin nodes
  cores_per_node: 24
  total_cores: 768
  max_memory_per_node: 256GB
  max_runtime: unlimited
  max_concurrent_jobs: 300

bigmem:
  nodes: 4 fat nodes
  cores_per_node: 48
  total_cores: 192
  max_memory_per_node: 1TB
  max_runtime: unlimited

gpu:
  nodes: 22 GPU nodes
  cores_per_node: 40
  gpus_per_node: 2
  total_cores: 880
  total_gpus: 44
  max_memory_per_node: 512GB
  max_runtime: unlimited
```

### Resource Request Examples
```bash
# Quick test
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:10:00

# Standard computation
#SBATCH --cpus-per-task=24
#SBATCH --mem=64G
#SBATCH --time=02:00:00

# Memory-intensive
#SBATCH --partition=bigmem
#SBATCH --cpus-per-task=48
#SBATCH --mem=512G
#SBATCH --time=08:00:00
```

## Julia Environment Specifications

### Package Configuration
```toml
# Project_HPC.toml (lightweight version)
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Optim = "429524aa-4258-5aef-a3af-852621145aeb"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
# Visualization packages excluded for HPC
```

### Environment Variables
```bash
JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"
TMPDIR="/tmp/globtim_${SLURM_JOB_ID}"
```

## Security Implementation

### SSH Key Management
- **Key Type**: ed25519
- **Key Location**: `~/.ssh/id_ed25519`
- **Permissions**: 600 (private key), 644 (public key)
- **Multiplexing**: Enabled for efficiency

### File Exclusions
```gitignore
# Automatically excluded from HPC sync
*.key
*.pem
*password*
*secret*
cluster_config.sh
*_server_connect.sh
docs/
experiments/
.git/
Manifest.toml
```

## Performance Benchmarks

### Matrix Operations (Verified)
```julia
# 100x100 matrix multiplication
A = rand(100, 100)
B = A * A
# Execution: <1 second on 4 cores
```

### Threading Efficiency
- **4 threads**: 100% utilization verified
- **24 threads**: Available on full nodes
- **Scaling**: Linear for embarrassingly parallel tasks

## Monitoring and Logging

### Job Output Structure
```
globtim_<jobtype>_<jobid>.out    # Standard output
globtim_<jobtype>_<jobid>.err    # Error output

Example content:
=== Globtim Quick Test ===
Job ID: 59769879
Node: c02n10
CPUs: 4
Start time: Sun Aug  3 15:04:52 CEST 2025
...
✓ Quick test completed successfully!
Duration: 27 seconds
```

### SLURM Accounting
```bash
# Job states tracked
PENDING    # Waiting for resources
RUNNING    # Currently executing
COMPLETED  # Finished successfully
FAILED     # Terminated with error
CANCELLED  # User or system cancelled
```

## Deployment Architecture

### Sync Exclusions (Optimized for HPC)
- **Excluded**: 400+ files (docs, examples, visualizations)
- **Included**: ~220 files (core source, tests, data)
- **Size Reduction**: 100MB → 2.3MB (98% reduction)
- **Transfer Time**: <30 seconds

### Automation Scripts
```bash
sync_fileserver_to_hpc.sh     # 6.9KB - Main deployment
submit_minimal_job.sh         # 2.6KB - Job submission
monitor_jobs.sh               # 3.4KB - Job monitoring
globtim_quick.slurm          # 1.9KB - Quick test template
globtim_minimal.slurm        # 3.2KB - Full test template
```

## Validated Globtim Functions

### Benchmark Functions (Tested)
```julia
# 2D functions
trefethen_3_8([0.5, 0.5])     # ✅ Working
camel_3_4d([0.5, 0.5])        # ✅ Working

# 4D functions  
trefethen_5_12([0.5, 0.5, 0.5, 0.5])  # ✅ Working
```

### Core Modules (Verified)
- `src/Structures.jl` ✅
- `src/BenchmarkFunctions.jl` ✅
- `src/LibFunctions.jl` ✅

This technical specification documents the complete, tested HPC integration for Globtim as of August 3, 2025.
