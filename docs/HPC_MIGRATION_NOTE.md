# HPC Infrastructure Migration Notice

**Date:** 2025-10-10
**Status:** Complete

## Summary

The HPC deployment infrastructure (`tools/hpc/`) has been **separated into a standalone repository**: [GlobtimHPC](https://git.mpi-cbg.de/globaloptim/globtimhpc)

## What Changed

- **Archived:** `tools/hpc/` directory (205 files) → `archives/tools_hpc_archived_2025_10_10/`
- **New location:** All HPC functionality now in GlobtimHPC repository
- **Core package:** Now independent of HPC deployment infrastructure

## For Users

### If you need HPC deployment functionality:

1. **Clone GlobtimHPC repository:**
   ```bash
   git clone https://git.mpi-cbg.de/globaloptim/globtimhpc.git
   ```

2. **Or install as Julia package:**
   ```julia
   using Pkg
   Pkg.add(url="https://git.mpi-cbg.de/globaloptim/globtimhpc.git")
   ```

3. **See GlobtimHPC documentation:** [GlobtimHPC/README.md](../../GlobtimHPC/README.md)

### If you have scripts referencing `tools/hpc/`:

- Update paths to use GlobtimHPC repository
- See archived files in `archives/tools_hpc_archived_2025_10_10/` for reference
- Consult GlobtimHPC documentation for migration guide

## Benefits

1. **Single source of truth** - HPC code maintained in one place
2. **No duplication** - Bug fixes and improvements in one location
3. **Cleaner core** - Core package focused on optimization algorithms
4. **Independent evolution** - HPC infrastructure can evolve independently
5. **Reusable** - HPC infrastructure can be used by other projects

## Related Documents

- [HPC_CLEANUP_PLAN.md](../../HPC_CLEANUP_PLAN.md) - Original cleanup plan
- [REPOSITORY_SEPARATION_ANALYSIS.md](../../REPOSITORY_SEPARATION_ANALYSIS.md) - Separation analysis
- [GlobtimHPC Repository](https://git.mpi-cbg.de/globaloptim/globtimhpc) - New HPC infrastructure location

## Archive Location

Original HPC tools archived at: `archives/tools_hpc_archived_2025_10_10/`

To restore (if needed):
```bash
mv archives/tools_hpc_archived_2025_10_10/hpc tools/
```

## Support

For questions about:
- **HPC deployment:** See GlobtimHPC repository
- **Core optimization:** See globtimcore documentation
- **Migration issues:** Contact project maintainers
