# Legacy HPC Documentation Archive

**Archive Date**: September 10, 2025  
**Status**: ⚠️ ARCHIVED - Superseded by Modern Infrastructure

## Archive Contents

This directory contains historical HPC documentation that has been superseded by the current direct r04n02 access infrastructure.

### Archived Files

1. **`FALCON_USAGE_GUIDE.md`** - Falcon cluster workflow with 267MB bundles
   - **Status**: Obsolete (replaced by r04n02 direct access)
   - **Superseded by**: Native Julia package management

2. **`README_HPC_Bundle.md`** - Bundle-based deployment guide
   - **Status**: Obsolete (replaced by Pkg.add() workflow)
   - **Superseded by**: Direct package installation

3. **`HPC_PACKAGE_BUNDLING_STRATEGY.md`** - Package bundling approach
   - **Status**: Obsolete (replaced by native packages)
   - **Superseded by**: Julia 1.11.6 + native package management

4. **`SLURM_WORKFLOW_GUIDE.md`** - SLURM job scheduling workflows
   - **Status**: Obsolete (replaced by tmux-based execution)
   - **Superseded by**: `robust_experiment_runner.sh` with tmux

5. **`HPC_BUNDLE_SOLUTIONS.md`** - Bundle creation and deployment solutions
   - **Status**: Obsolete (replaced by native package installation)
   - **Superseded by**: Direct Julia Pkg operations on r04n02

6. **`HPC_DEPLOYMENT_GUIDE.md`** - NFS-based bundle deployment
   - **Status**: Obsolete (replaced by direct node access)
   - **Superseded by**: Native Julia environment on r04n02

## Migration Summary

### Old Architecture (Archived)
```
Local → mack (NFS) → falcon (login) → Bundled Julia → SLURM scheduling
```

### Current Architecture (Active)
```
Local → r04n02 (direct SSH) → Native Julia packages → tmux execution
```

## Current Documentation

For active HPC operations, use:
- **`docs/hpc/README.md`** - Quick start guide for r04n02
- **`docs/hpc/COMPUTATION_PROCEDURES.md`** - Detailed tmux workflows
- **`docs/hpc/ROBUST_WORKFLOW_GUIDE.md`** - Production execution patterns

## Why These Were Superseded

1. **Bundle Complexity**: 267MB bundles replaced by simple `Pkg.add()`
2. **NFS Constraints**: 1GB quota limitations eliminated  
3. **SLURM Overhead**: Job scheduling unnecessary for single-user node
4. **Deployment Complexity**: Multi-step transfers replaced by direct Git clone

## Historical Context

These files document the infrastructure migration from constrained NFS-based workflows to the current production-ready r04n02 direct access system that achieves 100% experiment success rates.

---

**Current Status**: Production infrastructure operational with simplified workflows ✅