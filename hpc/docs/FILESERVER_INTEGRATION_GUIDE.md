# HPC Fileserver Integration Guide

## 🎯 Overview

This guide documents the **production-ready fileserver integration** for HPC Globtim workflows, replacing the temporary quota workaround approach.

**Status**: PRODUCTION READY ✅  
**Architecture**: Three-tier (Local → Fileserver → HPC Cluster)

## 🏗️ Architecture

### **Three-Tier System**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Local Development│    │ Fileserver (mack)│    │ HPC Cluster     │
│                 │    │                 │    │ (falcon nodes)  │
│ • Development   │───▶│ • Storage       │───▶│ • Computation   │
│ • Testing       │    │ • Job Scripts   │    │ • Execution     │
│ • Code Changes  │    │ • Results       │    │ • Monitoring    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Data Flow**
1. **Development**: Code changes made locally
2. **Sync**: Code pushed to fileserver (mack)
3. **Job Creation**: SLURM scripts created on fileserver
4. **Submission**: Jobs submitted from fileserver to cluster
5. **Execution**: Cluster nodes access fileserver via NFS
6. **Results**: Output saved to fileserver storage

## 🔧 Fileserver Configuration

### **Access Information**
- **Hostname**: `mack`
- **Access**: `ssh scholten@mack`
- **Working Directory**: `~/globtim_hpc/`
- **Julia Depot**: `~/.julia/` (302 packages installed)

### **Storage Locations**
```
~/globtim_hpc/                    # Main project directory
├── src/                          # Globtim source code
├── Examples/                     # Benchmark examples
├── hpc/                          # HPC infrastructure
├── results/                      # Job results (persistent)
└── slurm_scripts/               # Generated SLURM scripts

~/.julia/                         # Julia package depot
├── packages/                     # 302 installed packages
├── compiled/                     # Precompiled modules
├── artifacts/                    # Package artifacts
└── registries/                   # Package registries
```

### **NFS Mount Points (on cluster)**
```
/net/fileserver-nfs/stornext/snfs6/projects/scholten/
├── globtim_hpc/                  # Project files
└── .julia/                       # Julia packages
```

## 📦 Package Management

### **Available Packages**
The fileserver has a **complete Julia ecosystem** with 302 packages:

**Core Dependencies:**
- ✅ **StaticArrays** v1.9.14 - High-performance static arrays
- ✅ **JSON3** v1.14.3 - JSON parsing and generation
- ✅ **TimerOutputs** v0.5.29 - Performance profiling
- ✅ **TOML** v1.0.3 - Configuration file parsing
- ✅ **LinearAlgebra** - Matrix operations
- ✅ **DataFrames** - Data manipulation

**Extended Ecosystem:**
- Mathematical libraries (SpecialFunctions, Distributions, etc.)
- Plotting libraries (if needed for local development)
- Optimization packages
- File I/O and data processing tools

### **Package Installation**
```bash
# Connect to fileserver
ssh scholten@mack
cd ~/globtim_hpc

# Install additional packages (if needed)
julia --project=. -e 'using Pkg; Pkg.add("PackageName")'

# Packages are automatically available to cluster jobs via NFS
```

## 🚀 Job Submission Workflow

### **1. Connect to Fileserver**
```bash
ssh scholten@mack
cd ~/globtim_hpc
```

### **2. Create SLURM Script**
```bash
#!/bin/bash
#SBATCH --job-name=globtim_benchmark
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=results/job_%j.out
#SBATCH --error=results/job_%j.err

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Julia depot path (NFS mount)
export JULIA_DEPOT_PATH="/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia:$JULIA_DEPOT_PATH"

# Change to project directory (NFS mount)
cd /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim_hpc

# Run Julia script
/sw/bin/julia --project=. your_script.jl
```

### **3. Submit Job**
```bash
# Submit from fileserver
sbatch your_job_script.slurm

# Monitor job
squeue -u scholten

# View results
tail -f results/job_12345.out
```

## 🔄 Migration from Quota Workaround

### **Old Approach (Deprecated)**
```bash
# OLD: Temporary quota workaround
export JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:$JULIA_DEPOT_PATH"
python working_quota_workaround.py --install-all
```

### **New Approach (Production)**
```bash
# NEW: Fileserver integration
ssh scholten@mack
cd ~/globtim_hpc
sbatch your_job_script.slurm
```

### **Migration Steps**
1. **Stop using `/tmp` depot** - packages are now on fileserver
2. **Update SLURM scripts** - use NFS paths for depot and working directory
3. **Submit from fileserver** - use `mack` instead of direct cluster access
4. **Update monitoring** - results stored persistently on fileserver

## 📊 Performance Benefits

### **Fileserver vs Quota Workaround**
| Aspect | Quota Workaround | Fileserver Integration |
|--------|------------------|----------------------|
| **Storage** | Temporary (`/tmp`) | Persistent (NFS) |
| **Packages** | Reinstall each reboot | Always available |
| **Job Scripts** | Direct SSH creation | Proper SLURM workflow |
| **Results** | Manual collection | Automatic persistence |
| **Scalability** | Limited | Production-ready |
| **Reliability** | Temporary solution | Robust architecture |

### **Storage Capacity**
- **Fileserver**: Large capacity, persistent storage
- **NFS Performance**: High-speed access from cluster nodes
- **Backup**: Fileserver data is backed up (unlike `/tmp`)

## 🛠️ Troubleshooting

### **Common Issues**

**Issue**: Cannot access fileserver
```bash
# Solution: Check SSH connection
ssh scholten@mack
```

**Issue**: Packages not found on cluster
```bash
# Solution: Verify NFS mount and depot path
export JULIA_DEPOT_PATH="/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia:$JULIA_DEPOT_PATH"
```

**Issue**: Job submission fails
```bash
# Solution: Submit from fileserver, not cluster
ssh scholten@mack
cd ~/globtim_hpc
sbatch your_script.slurm
```

### **Verification Commands**
```bash
# Check fileserver access
ssh scholten@mack 'pwd && ls -la'

# Check Julia packages
ssh scholten@mack 'ls -la ~/.julia/packages/ | wc -l'

# Check NFS mount from cluster
ssh scholten@falcon 'ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/'

# Test package loading
ssh scholten@falcon 'export JULIA_DEPOT_PATH="/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia:$JULIA_DEPOT_PATH" && /sw/bin/julia -e "using StaticArrays; println(\"✅ Packages work!\")"'
```

## 📋 Best Practices

### **Development Workflow**
1. **Develop locally** with full environment
2. **Test on fileserver** before cluster submission
3. **Submit jobs from fileserver** using proper SLURM scripts
4. **Monitor from either location** (mack or falcon)
5. **Collect results from fileserver** (persistent storage)

### **File Organization**
```
~/globtim_hpc/
├── jobs/                         # Active job scripts
├── results/                      # Job outputs (organized by date/test)
├── archive/                      # Completed job archives
└── scripts/                      # Reusable job templates
```

### **Resource Management**
- **Use appropriate partitions**: batch, long, bigmem, gpu
- **Request realistic resources**: Don't over-allocate
- **Monitor job efficiency**: Check CPU and memory usage
- **Clean up old results**: Archive completed jobs

## 🎯 Next Steps

### **Immediate Actions**
1. **Update all Python submission scripts** to use fileserver
2. **Test Deuflhard benchmark** with fileserver integration
3. **Migrate existing workflows** from quota workaround
4. **Update documentation** to reflect fileserver approach

### **Long-term Improvements**
1. **Automated sync** between local and fileserver
2. **Result analysis tools** for fileserver-stored data
3. **Monitoring dashboard** for fileserver-based jobs
4. **Backup and archival** procedures for long-term storage

This fileserver integration provides a **robust, scalable, production-ready** foundation for all HPC Globtim workflows.
