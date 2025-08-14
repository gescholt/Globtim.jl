# HPC Job Submission Scripts Analysis

## 🎯 Executive Summary

**Analysis Date**: 2025-08-12  
**Purpose**: Identify canonical HPC job submission approach from recent bundling work  
**Status**: Analysis complete - Clear canonical approach identified  

## 📊 Inventory Results

### 1. Bundle Creation Scripts (PRESERVE - Core Infrastructure)
- `create_hpc_bundle.sh` - **CANONICAL** bundle creation approach
- `create_optimal_hpc_bundle.sh` - **ENHANCED** version with sysimage support
- **Status**: Both actively used, represent current best practice

### 2. Deployment Scripts (PRESERVE - Core Infrastructure)
- `deploy_to_hpc.sh` - **CANONICAL** deployment approach
- `deploy_to_hpc_robust.sh` - **ENHANCED** version with diagnostics and fallback
- **Status**: Both actively used, robust version preferred for production

### 3. SLURM Job Templates (MIXED - Needs Consolidation)

#### ✅ CANONICAL Templates (PRESERVE)
- `hpc/jobs/templates/globtim_quick.slurm` - **CURRENT STANDARD**
- `hpc/jobs/templates/globtim_minimal.slurm` - **CURRENT STANDARD**
- `hpc/jobs/templates/globtim_test.slurm` - **CURRENT STANDARD**
- `hpc/jobs/templates/globtim_custom.slurm.template` - **CURRENT STANDARD**
- `hpc/jobs/templates/globtim_json_tracking.slurm.template` - **CURRENT STANDARD**

#### ❌ OBSOLETE Templates (ARCHIVE/DELETE)
- Root directory SLURM files (20+ files) - **OBSOLETE**
- `bypass_pkg_ef44418b.slurm` - **DELETE**
- `critical_points_527c4abf.slurm` - **DELETE**
- `globtim_compile_d3eaa769.slurm` - **DELETE**
- `julia_nfs_production.slurm` - **DELETE**
- All other root-level .slurm files - **DELETE**

### 4. Job Creation Infrastructure (PRESERVE - Advanced)
- `hpc/jobs/creation/create_working_globtim_job.jl` - **CANONICAL**
- `hpc/jobs/creation/create_json_tracked_job.jl` - **CANONICAL**
- `hpc/config/parameters/SlurmJobGenerator.jl` - **CANONICAL**
- **Status**: Represents most advanced job creation system

### 5. Submission Infrastructure (PRESERVE - Production Ready)
- `hpc/jobs/submission/slurm_infrastructure.py` - **CANONICAL**
- `hpc/jobs/submission/submit_deuflhard_critical_points_fileserver.py` - **CANONICAL**
- **Status**: Production-ready Python infrastructure

## 🔍 Analysis Results

### Canonical Approach Identified: **Fileserver-Based Workflow**

Based on testing results and documentation analysis:

#### ✅ **CURRENT BEST PRACTICE** (Validated & Working)
1. **Bundle Creation**: `create_optimal_hpc_bundle.sh`
2. **Deployment**: `deploy_to_hpc_robust.sh`
3. **Job Templates**: `hpc/jobs/templates/` directory
4. **Submission**: Python infrastructure in `hpc/jobs/submission/`
5. **Workflow**: Three-tier architecture (Local → Fileserver → HPC)

#### 📋 **Key Success Factors**
- **NFS Integration**: Uses fileserver depot via NFS
- **Simplified SLURM**: Uses `-J`, `-t`, `-n`, `-c` format (no `--account`/`--partition`)
- **Robust Error Handling**: Comprehensive diagnostics and fallbacks
- **JSON Tracking**: Full parameter and result tracking
- **Automated Monitoring**: Python-based job monitoring

### Validation Status

#### ✅ **TESTED & WORKING**
- **Fileserver Integration**: ✅ Validated (Jobs 59780290-59780295)
- **Bundle Deployment**: ✅ Working with robust scripts
- **SLURM Execution**: ✅ Simplified parameter format works
- **NFS Access**: ✅ Compute nodes access fileserver seamlessly
- **Python Infrastructure**: ✅ Automated submission and monitoring

#### ❌ **DEPRECATED & FAILING**
- **Root Directory SLURM Files**: ❌ Old format, quota issues
- **Direct SSH Execution**: ❌ Bypasses SLURM scheduler
- **Manual File Transfer**: ❌ Superseded by automated workflow
- **`/tmp` Directory Approach**: ❌ Quota and persistence issues

## 📋 Consolidation Plan

### Phase 1: Archive Obsolete Scripts
**Target**: `docs/archive/repository_cleanup_2025_08_12/obsolete_hpc_submissions/`

#### DELETE (Truly Obsolete)
```bash
# Root directory SLURM files (20+ files)
bypass_pkg_ef44418b.slurm
critical_points_527c4abf.slurm
critical_points_54b099bc.slurm
fix_json3_749aeea1.slurm
globtim_compile_d3eaa769.slurm
globtim_deps_6a74a311.slurm
globtim_final_compile.slurm
globtim_final_working.slurm
globtim_minimal_42BE239E.slurm
globtim_production.slurm
globtim_simple_5cb3f677.slurm
julia_nfs_production.slurm
julia_nfs_template.slurm
julia_nfs_test.slurm
julia_simple_test.slurm
minimal_test.slurm
simple_test.slurm
test_basic_julia.slurm
test_hpc_bundle.slurm
test_slurm_simple.slurm
```

#### ARCHIVE (Historical Reference)
```bash
# Obsolete scripts with historical value
monitor_d3eaa769.sh
setup_nfs_julia.sh
setup_offline_depot.jl
verify_depot.jl
```

### Phase 2: Preserve Canonical Infrastructure
**Keep in current locations**:
- `create_optimal_hpc_bundle.sh` - **PRESERVE**
- `deploy_to_hpc_robust.sh` - **PRESERVE**
- `hpc/jobs/templates/` - **PRESERVE ALL**
- `hpc/jobs/creation/` - **PRESERVE ALL**
- `hpc/jobs/submission/` - **PRESERVE ALL**
- `hpc/config/parameters/` - **PRESERVE ALL**

### Phase 3: Update Documentation
**Actions**:
1. Update `HPC_README.md` to reference only canonical approaches
2. Create migration guide from obsolete to canonical methods
3. Update `hpc/WORKFLOW_CRITICAL.md` with consolidated guidance
4. Document deprecation reasons for archived scripts

## 🎯 Canonical Workflow Summary

### **RECOMMENDED APPROACH** (Production Ready)
```bash
# 1. Create bundle locally
./create_optimal_hpc_bundle.sh

# 2. Deploy to HPC
./deploy_to_hpc_robust.sh globtim_bundle_*.tar.gz

# 3. Submit jobs using Python infrastructure
python3 hpc/jobs/submission/submit_deuflhard_critical_points_fileserver.py --mode quick

# 4. Monitor with automated tools
python3 hpc/monitoring/python/slurm_monitor.py --continuous
```

### **Key Advantages**
- ✅ **Validated**: Tested and working on HPC cluster
- ✅ **Robust**: Comprehensive error handling and diagnostics
- ✅ **Automated**: Minimal manual intervention required
- ✅ **Scalable**: Supports parameter sweeps and batch jobs
- ✅ **Monitored**: Automated result collection and analysis

## 🚀 Next Steps

1. **Execute Consolidation**: Remove obsolete SLURM files from root directory
2. **Archive Historical Scripts**: Move to timestamped archive directory
3. **Update Documentation**: Reflect canonical approach in all guides
4. **Validate Preservation**: Ensure all canonical infrastructure is protected
5. **Test Workflow**: Verify canonical approach still works after cleanup

This analysis provides clear guidance for preserving the correct HPC submission infrastructure while safely removing obsolete approaches.
