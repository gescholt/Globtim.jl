# Migration Guide: From Quota Workaround to Fileserver Integration

> **📖 For Current Workflow**: See [FILESERVER_INTEGRATION_GUIDE.md](../../docs/FILESERVER_INTEGRATION_GUIDE.md)
>
> This document describes the migration from deprecated `/tmp`-based approaches to the current fileserver integration.

## 🎯 Overview

This guide documents the migration from the temporary quota workaround solution (now deprecated) to the production-ready fileserver integration for HPC Globtim workflows.

**Migration Status**: COMPLETE ✅  
**New Architecture**: Three-tier (Local → Fileserver → HPC Cluster)

## 📋 Migration Summary

### **Before: Quota Workaround (Deprecated)**
```bash
# OLD APPROACH - Temporary solution
export JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:$JULIA_DEPOT_PATH"
python working_quota_workaround.py --install-all
python submit_deuflhard_with_quota_workaround.py --mode quick
```

**Issues with Old Approach:**
- ❌ Temporary storage in `/tmp` (lost on reboot)
- ❌ Manual package reinstallation required
- ❌ Direct SSH script creation (bypassed proper SLURM workflow)
- ❌ Manual result collection needed
- ❌ Not scalable for production use

### **After: Fileserver Integration (Production)**
```bash
# NEW APPROACH - Production solution
ssh scholten@mack
cd ~/globtim_hpc
python submit_deuflhard_fileserver.py --mode quick
```

**Benefits of New Approach:**
- ✅ Persistent storage on fileserver
- ✅ Complete Julia ecosystem (302 packages) always available
- ✅ Proper SLURM workflow with standard practices
- ✅ Automatic result persistence
- ✅ Scalable production architecture

## 🔄 File-by-File Migration

### **1. Submission Scripts**

#### **Basic Test Migration**
```bash
# OLD (Deprecated)
python submit_basic_test.py --mode quick

# NEW (Production)
python submit_basic_test_fileserver.py --mode quick
```

#### **Deuflhard Benchmark Migration**
```bash
# OLD (Deprecated)
python submit_deuflhard_with_quota_workaround.py --mode quick

# NEW (Production)
python submit_deuflhard_fileserver.py --mode quick
```

### **2. Package Management**

#### **Old Package Installation**
```bash
# OLD - Manual installation to /tmp
python working_quota_workaround.py --install-all
export JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:$JULIA_DEPOT_PATH"
```

#### **New Package Access**
```bash
# NEW - Packages already available on fileserver
ssh scholten@mack
# Packages automatically available via ~/.julia/ (302 packages)
# No installation needed - persistent storage
```

### **3. Job Submission Workflow**

#### **Old Workflow**
```bash
# OLD - Direct cluster access with workarounds
ssh scholten@falcon
export JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:$JULIA_DEPOT_PATH"
# Create scripts directly on cluster (quota issues)
```

#### **New Workflow**
```bash
# NEW - Proper fileserver-based workflow
ssh scholten@mack
cd ~/globtim_hpc
sbatch your_job_script.slurm
# Or use Python submission scripts
```

## 📊 Architecture Comparison

### **Old Architecture: Direct Cluster Access**
```
Local Machine ──────────────▶ HPC Cluster (falcon)
                              ├── /tmp storage (temporary)
                              ├── Manual script creation
                              └── Quota workarounds
```

### **New Architecture: Three-Tier System**
```
Local Machine ──▶ Fileserver (mack) ──▶ HPC Cluster (falcon)
                  ├── Persistent storage    ├── NFS access to fileserver
                  ├── Complete Julia depot ├── Standard SLURM workflow
                  ├── SLURM script creation └── Automatic result storage
                  └── Result collection
```

## 🛠️ Migration Steps

### **Step 1: Verify Fileserver Access**
```bash
# Test fileserver connection
ssh scholten@mack
cd ~/globtim_hpc
ls -la ~/.julia/packages/ | wc -l  # Should show 302 packages
```

### **Step 2: Update Submission Scripts**
```bash
# Use new fileserver-integrated scripts
python submit_basic_test_fileserver.py --mode quick
python submit_deuflhard_fileserver.py --mode quick
```

### **Step 3: Verify NFS Integration**
```bash
# Test NFS access from cluster
ssh scholten@falcon 'ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia/'
```

### **Step 4: Update Monitoring**
```bash
# Monitor jobs from fileserver or cluster
ssh scholten@mack 'squeue -u scholten'
ssh scholten@falcon 'squeue -u scholten'
```

### **Step 5: Verify Results Storage**
```bash
# Check persistent results on fileserver
ssh scholten@mack 'ls -la ~/globtim_hpc/results/'
```

## 📁 File Organization Changes

### **Old File Locations**
```
/tmp/julia_depot_globtim_persistent/    # Temporary packages
/tmp/basic_test_results_*/              # Temporary results
~/globtim_hpc/*.slurm                   # Scripts in home directory (quota issues)
```

### **New File Locations**
```
~/.julia/                               # Persistent packages (fileserver)
~/globtim_hpc/results/                  # Persistent results (fileserver)
~/globtim_hpc/slurm_scripts/           # SLURM scripts (fileserver)
```

## 🔧 Updated Environment Variables

### **❌ Old Environment Setup (DEPRECATED)**
```bash
# ❌ DEPRECATED - Manual depot path setup (no longer allowed)
export JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:$JULIA_DEPOT_PATH"
```

> **⚠️ WARNING**: This approach is deprecated and forbidden on the cluster.
> Use the fileserver integration approach instead.

### **New Environment Setup**
```bash
# NEW - Automatic via NFS in SLURM scripts
export JULIA_DEPOT_PATH="/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia:$JULIA_DEPOT_PATH"
```

## 📋 Deprecated Files and Scripts

### **Files to Stop Using**
- ❌ `working_quota_workaround.py` - Package installer (deprecated)
- ❌ `submit_deuflhard_with_quota_workaround.py` - Old Deuflhard script
- ❌ `submit_basic_test.py` - Old basic test (if using direct execution)
- ❌ `test_quota_workaround.py` - Testing script for old approach

### **Files to Use Instead**
- ✅ `submit_deuflhard_fileserver.py` - New Deuflhard benchmark
- ✅ `submit_basic_test_fileserver.py` - New basic test
- ✅ Standard SLURM scripts with NFS paths
- ✅ `FILESERVER_INTEGRATION_GUIDE.md` - New documentation

## 🧪 Testing Migration

### **Verification Checklist**
```bash
# 1. Test fileserver access
ssh scholten@mack 'pwd && ls -la'

# 2. Verify Julia packages
ssh scholten@mack 'ls ~/.julia/packages/ | wc -l'  # Should be 302

# 3. Test basic submission
python submit_basic_test_fileserver.py --mode quick

# 4. Test Deuflhard submission
python submit_deuflhard_fileserver.py --mode quick

# 5. Verify NFS access from cluster
ssh scholten@falcon 'ls /net/fileserver-nfs/stornext/snfs6/projects/scholten/'

# 6. Check job monitoring
ssh scholten@mack 'squeue -u scholten'
```

### **Expected Results**
- ✅ All commands execute without errors
- ✅ Jobs submit successfully with proper SLURM job IDs
- ✅ Results stored persistently on fileserver
- ✅ No quota-related errors
- ✅ Standard SLURM workflow functioning

## 🚀 Benefits Realized

### **Performance Improvements**
- **Package Loading**: Instant (no installation needed)
- **Job Submission**: Standard SLURM workflow
- **Result Persistence**: Permanent storage
- **Scalability**: Production-ready architecture

### **Operational Benefits**
- **Reliability**: No temporary storage dependencies
- **Maintainability**: Standard HPC practices
- **Monitoring**: Integrated with cluster monitoring
- **Backup**: Fileserver data is backed up

### **Development Benefits**
- **Consistency**: Same environment across all jobs
- **Debugging**: Persistent logs and results
- **Collaboration**: Shared fileserver access
- **Documentation**: Standard SLURM practices

## 📞 Support and Troubleshooting

### **Common Migration Issues**

**Issue**: Cannot access fileserver
```bash
# Solution: Verify SSH access
ssh scholten@mack
```

**Issue**: Old scripts still being used
```bash
# Solution: Update to new fileserver scripts
python submit_*_fileserver.py --mode quick
```

**Issue**: Jobs not finding packages
```bash
# Solution: Verify NFS depot path in SLURM script
export JULIA_DEPOT_PATH="/net/fileserver-nfs/stornext/snfs6/projects/scholten/.julia:$JULIA_DEPOT_PATH"
```

### **Migration Support**
- **Documentation**: `hpc/docs/FILESERVER_INTEGRATION_GUIDE.md`
- **Scripts**: Use `*_fileserver.py` versions
- **Testing**: Run verification checklist above
- **Monitoring**: Standard `squeue` commands work from anywhere

## 🎯 Next Steps

### **Immediate Actions**
1. ✅ **Stop using deprecated scripts** - Switch to fileserver versions
2. ✅ **Update documentation references** - Point to new guides
3. ✅ **Test new workflow** - Verify all functionality
4. ✅ **Archive old files** - Keep for reference but don't use

### **Long-term Improvements**
1. **Automated sync** between local development and fileserver
2. **Enhanced monitoring** for fileserver-based jobs
3. **Result analysis tools** for persistent storage
4. **Backup and archival** procedures

The migration to fileserver integration provides a **robust, scalable, production-ready** foundation for all future HPC Globtim workflows.
