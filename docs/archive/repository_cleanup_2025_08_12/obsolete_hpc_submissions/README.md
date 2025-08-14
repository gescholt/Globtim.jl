# Obsolete HPC Submission Scripts Archive

**Archive Date**: 2025-08-12  
**Reason**: Repository cleanup - consolidation of HPC job submission approaches  

## 🗂️ Archived Files

### Historical Scripts (Reference Value)
- `monitor_d3eaa769.sh` - Job monitoring script for specific test job
- `setup_nfs_julia.sh` - NFS Julia environment setup (superseded by hpc/infrastructure/)
- `setup_offline_depot.jl` - Offline depot creation (superseded by bundling strategy)
- `verify_depot.jl` - Depot verification script (superseded by automated validation)

## 📋 Deletion Summary

### Obsolete SLURM Files (20 files deleted)
These files were testing artifacts from HPC development and are no longer needed:

- `bypass_pkg_ef44418b.slurm` - Package bypass test
- `critical_points_527c4abf.slurm` - Critical points test (old format)
- `critical_points_54b099bc.slurm` - Critical points test (old format)
- `fix_json3_749aeea1.slurm` - JSON3 fix attempt
- `globtim_compile_d3eaa769.slurm` - Compilation test
- `globtim_deps_6a74a311.slurm` - Dependencies test
- `globtim_final_compile.slurm` - Final compilation test
- `globtim_final_working.slurm` - Final working test (empty file)
- `globtim_minimal_42BE239E.slurm` - Minimal test
- `globtim_production.slurm` - Production test (old format)
- `globtim_simple_5cb3f677.slurm` - Simple test
- `julia_nfs_production.slurm` - NFS production test
- `julia_nfs_template.slurm` - NFS template
- `julia_nfs_test.slurm` - NFS test
- `julia_simple_test.slurm` - Simple Julia test
- `minimal_test.slurm` - Minimal test
- `simple_test.slurm` - Simple test
- `test_basic_julia.slurm` - Basic Julia test
- `test_hpc_bundle.slurm` - Bundle test
- `test_slurm_simple.slurm` - Simple SLURM test

## ✅ Preserved Infrastructure

### Current HPC Job Submission (Canonical Approach)
- `create_optimal_hpc_bundle.sh` - **PRESERVED** (bundle creation)
- `deploy_to_hpc_robust.sh` - **PRESERVED** (deployment)
- `hpc/jobs/templates/` - **PRESERVED** (current SLURM templates)
- `hpc/jobs/creation/` - **PRESERVED** (job creation infrastructure)
- `hpc/jobs/submission/` - **PRESERVED** (Python submission system)

## 🎯 Rationale

### Why These Files Were Obsolete
1. **Old SLURM Format**: Used problematic `--account`/`--partition` parameters
2. **Testing Artifacts**: Created during development, not production code
3. **Superseded Approaches**: Replaced by more robust infrastructure
4. **Quota Issues**: Many caused quota problems on HPC cluster
5. **Validation Status**: Failed testing or never reached production

### Current Best Practice
The canonical HPC workflow is now:
1. **Bundle Creation**: `create_optimal_hpc_bundle.sh`
2. **Deployment**: `deploy_to_hpc_robust.sh`
3. **Job Submission**: Python infrastructure in `hpc/jobs/submission/`
4. **Templates**: Organized templates in `hpc/jobs/templates/`

This approach has been validated and is working on the HPC cluster.

## 📚 References
- `HPC_JOB_SUBMISSION_ANALYSIS.md` - Complete analysis of submission approaches
- `hpc/WORKFLOW_CRITICAL.md` - Current workflow documentation
- `hpc/docs/HPC_STATUS_SUMMARY.md` - System status and validation results
