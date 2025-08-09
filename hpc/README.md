# HPC Infrastructure

This directory contains all HPC-related functionality for Globtim benchmarking and testing on SLURM clusters.

> 🚨 **CRITICAL: HPC Workflow - MUST READ BEFORE USING** 🚨
>
> **GOLDEN RULE**: Code management via mack (fileserver), job submission via falcon (cluster)
>
> **Step 1: Code Management (ONLY via fileserver mack)**
> - Upload/modify code: `ssh scholten@mack`, work in `~/globtim_hpc`
> - Install packages: Use fileserver's Julia depot `~/.julia` (302 packages)
> - Prepare data: ALL file operations through mack (falcon has 1GB quota limit!)
> - Never install packages or modify code on falcon
>
> **Step 2: Job Submission (ONLY via cluster falcon)**
> - Submit SLURM jobs: `ssh scholten@falcon`, submit from `~/globtim_hpc`
> - Required: `--account=mpi --partition=batch`
> - Jobs access fileserver code/data via NFS automatically
> - Results written to `~/globtim_hpc/results/`
>
> **Step 3: Monitor and Collect**
> - Monitor: `ssh scholten@falcon 'squeue -u scholten'`
> - Collect: Results accessible from both mack and falcon (same NFS filesystem)
>
> **⚠️ QUOTA WARNING**: falcon home has 1GB limit. Keep only globtim_hpc directory there!


## 🚀 Current Working Examples (Tested & Verified)

### ✅ Basic Julia Testing
```bash
cd hpc/jobs/submission
python submit_basic_test.py --mode quick --auto-collect
```

### ✅ Globtim Compilation Testing
```bash
cd hpc/jobs/submission
python submit_globtim_compilation_test.py --mode quick --function sphere
```

### ✅ Automated Monitoring & Collection
```bash
cd hpc/jobs/submission
python automated_job_monitor.py --job-id 12345 --test-id abc123
python test_automated_monitoring.py  # Run test suite
```

## 📁 Directory Structure

- `infrastructure/` - Setup, deployment, and sync scripts
- `jobs/` - Job templates and creation scripts
  - `submission/` - **Working Python submission scripts** ✅
  - `creation/` - Job creation utilities
  - `templates/` - SLURM job templates
- `monitoring/` - Real-time monitoring tools (Python & Bash)
  - `python/` - **Working Python monitoring tools** ✅
- `config/` - Configuration files and Parameters.jl system
- `results/` - Organized result collection
- `scripts/` - Various testing and utility scripts

## 🎯 Recommended Workflow

1. **Test Basic Functionality**:
   ```bash
   cd hpc/jobs/submission
   python submit_basic_test.py --mode quick
   ```

2. **Test Globtim Compilation**:
   ```bash
   python submit_globtim_compilation_test.py --mode quick --function sphere
   ```

3. **Monitor Jobs Automatically**:
   ```bash
   python automated_job_monitor.py --job-id [JOB_ID] --test-id [TEST_ID]
   ```

4. **Collect Results**:
   - Results are automatically collected in `collected_results/` directory
   - Each job gets a timestamped folder with all outputs

## 🔧 Available Tools

### Working Python Scripts ✅
- `submit_basic_test.py` - Basic Julia functionality testing
- `submit_globtim_compilation_test.py` - Globtim module compilation testing
- `automated_job_monitor.py` - Job monitoring and output collection
- `test_automated_monitoring.py` - Test suite for monitoring system

### Legacy Tools (May Need Updates)
- `hpc_tools.sh` - Convenience wrapper script
- Various infrastructure scripts in `infrastructure/`

## 📊 Current Status & Known Issues

### ✅ Working Features
- **Job Submission**: Python scripts successfully submit jobs to SLURM
- **Basic Testing**: Julia environment validation works
- **Compilation Testing**: Identifies missing dependencies (StaticArraysCore, JSON3)
- **Automated Monitoring**: Real-time job status checking and output collection
- **Result Organization**: Timestamped local directories with JSON summaries

### ⚠️ Known Issues
- **Missing Dependencies**: `StaticArraysCore`, `JSON3`, and other packages not available on cluster
- **Filesystem I/O Errors**: Occasional disk space or permission issues during package installation
- **SSH Connection**: Some monitoring commands may timeout or fail intermittently

### 🔧 HPC Infrastructure - FILESERVER INTEGRATION ✅

### **Architecture Overview**
The HPC system uses a **three-tier architecture** for optimal performance and storage management:

```
Local Development → Fileserver (mack) → HPC Cluster (falcon)
     ↓                    ↓                    ↓
  Development         Storage & Jobs       Computation
```

### **✅ VERIFIED PRODUCTION SOLUTION:**
```bash
# Step 1: Upload/manage code on fileserver
ssh scholten@mack
cd ~/globtim_hpc
# (Upload code, install packages, prepare data here)

# Step 2: Submit jobs from cluster (VERIFIED WORKING!)
ssh scholten@falcon
cd ~/globtim_hpc
sbatch --account=mpi --partition=batch your_job_script.slurm

# Step 3: Automated monitoring and collection (VERIFIED!)
python3 hpc/jobs/submission/automated_job_monitor.py --job-id <job_id> --test-id <test_id>
```

**PROOF**: Job 59780294 successfully evaluated 10 function points, generated CSV/summary files, and collected all outputs to local machine.

### **Storage Strategy:**
1. **Fileserver (mack)**: `~/globtim_hpc/` - Source code, SLURM scripts, results
2. **Julia Depot**: `~/.julia/` on mack - Complete package ecosystem (302 packages)
3. **HPC Cluster**: Computation nodes access fileserver via NFS
4. **Output Storage**: Results saved to fileserver, accessible from both mack and falcon

### **Available Packages on Fileserver:**
- ✅ **Complete Julia ecosystem** (302 packages in `~/.julia/packages/`)
- ✅ **StaticArrays, JSON3, TimerOutputs, TOML** - All core dependencies
- ✅ **Compiled modules** in `~/.julia/compiled/`
- ✅ **Artifacts and registries** - Full package infrastructure

### **SLURM Job Integration:**
Jobs submitted from falcon access fileserver packages automatically via NFS:
```bash
#!/bin/bash
#SBATCH --job-name=globtim_job
#SBATCH --partition=batch
#SBATCH --account=mpi

# Fileserver depot accessible via NFS (automatic)
export JULIA_DEPOT_PATH="/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia:$JULIA_DEPOT_PATH"
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

cd ~/globtim_hpc
/sw/bin/julia --project=. your_script.jl
```

**CRITICAL**: Submit this script from falcon, not mack:
```bash
ssh scholten@falcon 'cd ~/globtim_hpc && sbatch job_script.slurm'
```

## 🎯 HPC Workflow - FILESERVER INTEGRATION ✅

### Step 1: Access Fileserver
```bash
# Connect to fileserver (mack) for job management
ssh scholten@mack
cd ~/globtim_hpc
```

### Step 2: Submit Jobs via Fileserver
```bash
# Direct SLURM submission from fileserver
sbatch your_job_script.slurm

# Or use Python submission scripts (updated for fileserver)
python submit_deuflhard_fileserver.py --mode quick
python submit_basic_test_fileserver.py --mode quick
```

### Step 3: Monitor Jobs
```bash
# Monitor from either fileserver or cluster
ssh scholten@falcon 'squeue -u scholten'

# Or from fileserver
squeue -u scholten

# View results (stored on fileserver)
ls -la ~/globtim_hpc/results/
```

## 📈 Production Status - FILESERVER READY ✅

Current status with fileserver integration:
- **Fileserver Access**: ✅ `ssh scholten@mack` working
- **Julia Packages**: ✅ Complete ecosystem (302 packages) on mack
- **SLURM Scripts**: ✅ Created on fileserver, submitted from cluster (falcon)
- **NFS Integration**: ✅ Cluster nodes access fileserver packages
- **Storage**: ✅ Persistent results on fileserver

## 🚀 Migration from Quota Workaround

**Old Approach (Deprecated):**
- Used `/tmp` storage to bypass quota limits
- Temporary package installations
- Manual result collection

**New Approach (Production):**
- Use fileserver (mack) for all storage
- Persistent Julia packages and results
- Proper SLURM job management
- NFS integration for cluster access

## 📞 Support

For issues with:
- **Fileserver Access**: `ssh scholten@mack`
- **Job Submission**: Submit from mack using `sbatch`
- **Package Issues**: Check `~/.julia/` on mack
- **Results**: Stored persistently on fileserver
