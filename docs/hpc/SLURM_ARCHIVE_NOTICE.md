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

**New Documentation**: `COMPUTATION_PROCEDURES.md`  
**Framework**: tmux-based persistent execution  
**Benefits**: Immediate execution, better control, simpler deployment

### Historical SLURM Documentation

The following files contain historical SLURM workflow information:

**Primary SLURM Documentation:**
- `SLURM_WORKFLOW_GUIDE.md` - Main SLURM workflow guide (ARCHIVED)

**Files with SLURM References:**
- `HPC_EXECUTION_GUIDE.md`
- `TMUX_FRAMEWORK_MIGRATION.md`
- `DOCUMENTATION_UPDATE_SUMMARY_20250902.md`
- `ROBUST_WORKFLOW_GUIDE.md`
- `HPC_DIRECT_NODE_MIGRATION_PLAN.md`
- `HOMOTOPY_SOLUTION_SUMMARY.md`
- `HPC_BUNDLE_SOLUTIONS.md`
- `HPC_DEPLOYMENT_GUIDE.md`
- `FALCON_USAGE_GUIDE.md`
- `CLUSTER_WORKFLOW.md`
- `README_HPC_Bundle.md`
- `precision_optimization_guide.md`
- `HPC_LIGHT_2D_FILES_DOCUMENTATION.md`
- `HPC_PACKAGE_BUNDLING_STRATEGY.md`

**Archive Status**: These files are maintained for historical reference but contain superseded workflows.

### Migration Actions Taken

1. ✅ Main SLURM workflow guide marked as ARCHIVED
2. ✅ Migration notices added to key infrastructure documents  
3. ✅ New tmux-based procedures documented in `COMPUTATION_PROCEDURES.md`
4. ✅ GitLab issues updated with current deployment status

### For Current HPC Operations

**Use**: `COMPUTATION_PROCEDURES.md` - Complete guide for tmux-based workflow  
**Ignore**: Historical SLURM references in other documentation files

---

**Note**: SLURM capabilities remain available on the cluster but are not needed for the current GlobTim single-user workflow on r04n02.