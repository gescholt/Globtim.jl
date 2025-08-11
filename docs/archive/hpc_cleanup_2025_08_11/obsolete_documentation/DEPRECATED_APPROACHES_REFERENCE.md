# Deprecated Approaches Reference Guide

**Purpose**: This document provides a comprehensive mapping from deprecated HPC approaches to current best practices.

---

## 🚨 Quick Navigation to Current Documentation

### **Primary Reference (Start Here)**
- **📖 [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md)** - Complete setup and usage guide

### **Status and Monitoring**
- **📊 [HPC_STATUS_SUMMARY.md](HPC_STATUS_SUMMARY.md)** - Current system status
- **📈 [HPC_WORKFLOW_STATUS.md](../HPC_WORKFLOW_STATUS.md)** - Detailed status report

### **Quick Start**
- **⚡ [WORKFLOW_CRITICAL.md](../WORKFLOW_CRITICAL.md)** - Essential workflow steps

---

## ❌ Deprecated Approaches → ✅ Current Solutions

### 1. `/tmp` Directory Usage

#### **❌ DEPRECATED**: Running jobs from `/tmp`
```bash
# DON'T USE - Forbidden on cluster
export JULIA_DEPOT_PATH="/tmp/julia_depot_globtim_persistent:$JULIA_DEPOT_PATH"
cd /tmp/globtim_${JOB_ID}/
```

#### **✅ CURRENT**: Fileserver Integration
```bash
# Use NFS depot and fileserver workflow
export JULIA_DEPOT_PATH="/globtim_hpc/julia_depot"
cd ~/globtim_hpc
```
**Reference**: [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md) Section 3

### 2. Manual Package Installation

#### **❌ DEPRECATED**: Manual depot setup
```bash
# DON'T USE - Manual package management
python working_quota_workaround.py --install-all
```

#### **✅ CURRENT**: Automated NFS Depot
```bash
# Automatic package management via NFS
# No manual installation required
```
**Reference**: [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md) Section 4

### 3. Direct SSH Job Submission

#### **❌ DEPRECATED**: Direct SSH execution
```bash
# DON'T USE - Direct execution without SLURM
ssh scholten@falcon "cd ~/globtim_hpc && julia script.jl"
```

#### **✅ CURRENT**: SLURM-based Submission
```bash
# Use proper SLURM job submission
python3 hpc/jobs/submission/submit_deuflhard_critical_points_fileserver.py --mode quick
```
**Reference**: [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md) Section 5

### 4. Manual File Transfer

#### **❌ DEPRECATED**: Manual scp commands
```bash
# DON'T USE - Manual file management
scp files.tar.gz scholten@falcon:~/
```

#### **✅ CURRENT**: Automated Fileserver Workflow
```bash
# Automated via submission scripts
# Files automatically managed via mack → falcon workflow
```
**Reference**: [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md) Section 2

---

## 📁 Deprecated Documentation Files

### **Archived Files** (Historical Reference Only)
- `hpc/docs/archive/HPC_TECHNICAL_SPECS.md` - Old cluster specifications
- `hpc/docs/archive/HPC_MAINTENANCE_QUICK_REFERENCE.md` - Old maintenance procedures
- `hpc/docs/TMP_FOLDER_PACKAGE_STRATEGY.md` - Forbidden `/tmp` approach

### **Migration Documentation** (Transition Reference)
- `hpc/jobs/submission/FILESERVER_MIGRATION_GUIDE.md` - Migration from old to new approach

### **Current Active Documentation**
- `hpc/docs/FILESERVER_INTEGRATION_GUIDE.md` - **PRIMARY REFERENCE**
- `hpc/docs/HPC_STATUS_SUMMARY.md` - System status
- `hpc/WORKFLOW_CRITICAL.md` - Quick start guide

---

## 🔄 Migration Checklist

If you're updating from deprecated approaches:

### ✅ **Step 1**: Stop Using Deprecated Methods
- [ ] Remove any `/tmp` directory references
- [ ] Stop manual depot path setup
- [ ] Discontinue direct SSH job execution
- [ ] Remove manual file transfer scripts

### ✅ **Step 2**: Adopt Current Workflow
- [ ] Read [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md)
- [ ] Use fileserver-integrated submission scripts
- [ ] Adopt SLURM-based job management
- [ ] Use automated monitoring tools

### ✅ **Step 3**: Update Documentation References
- [ ] Update any personal scripts or documentation
- [ ] Reference current documentation in new work
- [ ] Report any remaining deprecated references

---

## 🚨 Common Migration Issues

### **Issue**: "Package not found" errors
**Cause**: Still using old depot paths  
**Solution**: Follow [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md) Section 4

### **Issue**: "Permission denied" in `/tmp`
**Cause**: Attempting to use deprecated `/tmp` approach  
**Solution**: Switch to fileserver workflow immediately

### **Issue**: Jobs fail with quota errors
**Cause**: Using old home directory approach  
**Solution**: Use NFS depot as described in current documentation

### **Issue**: Can't find current documentation
**Solution**: Always start with [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md)

---

## 📞 Getting Help

### **For Current Workflow Questions**
1. Check [FILESERVER_INTEGRATION_GUIDE.md](FILESERVER_INTEGRATION_GUIDE.md) first
2. Review [HPC_STATUS_SUMMARY.md](HPC_STATUS_SUMMARY.md) for system status
3. Consult [HPC_WORKFLOW_STATUS.md](../HPC_WORKFLOW_STATUS.md) for detailed status

### **For Migration Issues**
1. Follow the migration checklist above
2. Review [FILESERVER_MIGRATION_GUIDE.md](../jobs/submission/FILESERVER_MIGRATION_GUIDE.md)
3. Check that you're not using any deprecated approaches

### **For System Status**
- Current system readiness: **80%** (see [HPC_WORKFLOW_STATUS.md](../HPC_WORKFLOW_STATUS.md))
- Known issues: Coefficient dimension mismatch in solve_polynomial_system
- Working components: Job submission, monitoring, documentation

---

## 📊 Documentation Health Status

### **✅ Current Documentation** (Use These)
- FILESERVER_INTEGRATION_GUIDE.md - **100% Current**
- HPC_STATUS_SUMMARY.md - **100% Current**  
- WORKFLOW_CRITICAL.md - **100% Current**
- HPC_WORKFLOW_STATUS.md - **100% Current**

### **⚠️ Migration Documentation** (Reference Only)
- FILESERVER_MIGRATION_GUIDE.md - **Historical reference**
- DEPRECATED_APPROACHES_REFERENCE.md - **This document**

### **❌ Deprecated Documentation** (Do Not Use)
- TMP_FOLDER_PACKAGE_STRATEGY.md - **Forbidden approach**
- archive/HPC_TECHNICAL_SPECS.md - **Outdated specifications**
- archive/HPC_MAINTENANCE_QUICK_REFERENCE.md - **Outdated procedures**

---

**Last Updated**: August 9, 2025  
**Status**: ✅ Complete cross-reference mapping  
**Next Review**: When new deprecated approaches are identified
