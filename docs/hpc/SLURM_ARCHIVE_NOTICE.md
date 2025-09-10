# SLURM Workflow Archive Notice

**Date:** September 3, 2025  
**Status:** ⚠️ ARCHIVED WORKFLOWS

## Migration Summary

The GlobTim HPC execution framework has migrated from SLURM-based job scheduling to a direct tmux-based execution system on the r04n02 compute node.

### Why SLURM Was Superseded

1. **Single-User Compute Node**: r04n02 provides dedicated access without scheduling conflicts
2. **Simplified Workflow**: Direct execution eliminates job queue wait times
3. **Better Monitoring**: tmux provides real-time interaction and monitoring
4. **Resource Efficiency**: No scheduling overhead for single-user scenarios

### Current Solution

**New Documentation**: `README.md` - Quick start guide for r04n02  
**Framework**: tmux-based persistent execution via `robust_experiment_runner.sh`  
**Benefits**: Immediate execution, better control, simpler deployment

### Legacy Documentation Archived

**September 10, 2025 Update**: Major obsolete documentation has been archived to `docs/archive/legacy_hpc_2025_09_10/`:

**Archived Files:**
- `SLURM_WORKFLOW_GUIDE.md` - SLURM job scheduling workflows
- `FALCON_USAGE_GUIDE.md` - Falcon cluster with 267MB bundles  
- `README_HPC_Bundle.md` - Bundle-based deployment procedures
- `HPC_PACKAGE_BUNDLING_STRATEGY.md` - Package bundling approach

**Remaining Legacy References**: Some files still contain historical SLURM/bundle references but are being preserved for transition documentation purposes.

### Migration Actions Taken

1. ✅ Main SLURM workflow guide marked as ARCHIVED
2. ✅ Migration notices added to key infrastructure documents  
3. ✅ New tmux-based procedures documented in `COMPUTATION_PROCEDURES.md`
4. ✅ GitLab issues updated with current deployment status

### For Current HPC Operations

**Use**: `README.md` - Quick start guide with 30-second workflow  
**Also**: `COMPUTATION_PROCEDURES.md` - Detailed tmux execution procedures  
**Ignore**: Historical SLURM/bundle references in transition documentation

---

**Note**: SLURM capabilities remain available on the cluster but are not needed for the current GlobTim single-user workflow on r04n02.