# HPC Infrastructure

This directory contains all HPC-related functionality for Globtim benchmarking and testing on SLURM clusters.

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

### **✅ PRODUCTION SOLUTION:**
```bash
# Access fileserver for job management
ssh scholten@mack

# Submit jobs from fileserver to cluster
cd ~/globtim_hpc
sbatch your_job_script.slurm
```

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
Jobs access fileserver packages automatically via NFS:
```bash
#!/bin/bash
#SBATCH --job-name=globtim_job
#SBATCH --partition=batch

# Fileserver depot accessible via NFS
export JULIA_DEPOT_PATH="/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia:$JULIA_DEPOT_PATH"
cd ~/globtim_hpc
/sw/bin/julia --project=. your_script.jl
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
- **SLURM Scripts**: ✅ Created and submitted from fileserver
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
