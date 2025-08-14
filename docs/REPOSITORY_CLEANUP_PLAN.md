# Globtim Repository Cleanup Plan

## 🎯 Executive Summary

The globtim repository has accumulated significant file proliferation with 50+ files in the root directory and scattered documentation. This plan provides systematic cleanup while preserving recent HPC bundling work and maintaining core functionality.

## 📊 Current State Analysis

### Root Directory Issues
- **50+ files** in root directory (should be ~10-15)
- **Multiple SLURM job files** scattered throughout
- **Redundant documentation** across multiple locations
- **Mixed file types** (configs, scripts, docs, logs) in same directory

### Key Areas Needing Cleanup
1. **Root Directory**: 50+ files → target 15 files
2. **SLURM Jobs**: 20+ scattered .slurm files
3. **Documentation**: Fragmented across 5+ locations
4. **HPC Scripts**: Deployment scripts in multiple places
5. **Collected Results**: Large result directories
6. **Experimental Files**: Week-based experiment folders

## 🛡️ Protected Assets (DO NOT TOUCH)

### Recent HPC Bundling Work
- `create_hpc_bundle.sh` - **PRESERVE**
- `create_optimal_hpc_bundle.sh` - **PRESERVE**
- `HPC_PACKAGE_BUNDLING_STRATEGY.md` - **PRESERVE**
- `README_HPC_Bundle.md` - **PRESERVE**
- `deploy_to_hpc.sh` - **PRESERVE**
- `deploy_to_hpc_robust.sh` - **PRESERVE**
- `hpc/infrastructure/` - **PRESERVE ALL**
- `instructions/bundle_hpc.md` - **PRESERVE**

### Core Functionality
- `src/` directory - **PRESERVE ALL**
- `test/` directory - **PRESERVE ALL**
- `Project.toml` - **PRESERVE**
- `Manifest.toml` - **PRESERVE**
- `README.md` - **PRESERVE**

## 📋 Cleanup Categories

### Category 1: COMPACTIFY (Consolidate)
**Target**: Combine related files into fewer, better-organized files

#### Root Directory Documentation
- `4D_HPC_BENCHMARK_DESIGN.md` → Merge into `docs/benchmarking/`
- `4D_RESULTS_STRUCTURE_PLAN.md` → Merge into `docs/benchmarking/`
- `4D_TEST_PARAMETERS.toml` → Move to `Examples/4d_benchmark_tests/`
- `4D_TEST_VALIDATION_REPORT.md` → Move to `docs/benchmarking/`
- `TESTING_EXECUTION_PLAN.md` → Merge into `docs/development/`
- `TEST_STRUCTURE_ANALYSIS.md` → Merge into `docs/development/`

#### HPC Documentation Consolidation
- `HPC_COMPILATION_LESSONS_LEARNED.md` → Merge into `hpc/docs/`
- `HPC_STANDALONE_DOCUMENTATION.md` → Merge into `hpc/docs/`
- `HPC_WORKFLOW_STATUS.md` → Merge into `hpc/docs/`
- `hpc_infrastructure_analysis_report.md` → Move to `hpc/docs/`

#### Development Documentation
- `DEVELOPMENT_GUIDE.md` - **KEEP** (already consolidated)
- `DEPENDENCIES.md` → Merge into `DEVELOPMENT_GUIDE.md`
- `CONDITIONAL_LOADING_NO_FALLBACKS.md` → Move to `docs/development/`

### Category 2: ARCHIVE (Move to docs/archive/)
**Target**: Move to timestamped archive subdirectories

#### Create Archive: `docs/archive/repository_cleanup_2025_08_12/`

##### Obsolete Documentation
- `AUGMENT_REPOSITORY_RECOMMENDATIONS.md` → Archive
- `CLAUDE.md` → Archive
- `COMMIT_MESSAGE.md` → Archive
- `DOCUMENTATION_CLEANUP_SUMMARY.md` → Archive (superseded by this plan)
- `DOCUMENTATION_ORGANIZATION_PLAN.md` → Archive
- `MIGRATION_COMPLETE.md` → Archive
- `OPTIMIZATION_COMPLETE.md` → Archive
- `PUBLIC_GITHUB_FILES_ANALYSIS.md` → Archive

##### Historical Analysis Files
- `documentation_analysis.json` → Archive
- `slurm_exit53_investigation_complete_report.md` → Archive
- `slurm_exit53_root_cause_analysis.md` → Archive

### Category 3: DELETE (Obsolete Content)
**Target**: Remove truly obsolete files

#### Temporary/Log Files
- `backup_maintenance.log` → DELETE
- `hpc_test_results_9666922b_20250811_113752_results.json` → DELETE
- `investigate_slurm_exit_53.py` → DELETE (issue resolved)

#### Obsolete SLURM Jobs (Root Directory)
- `bypass_pkg_ef44418b.slurm` → DELETE
- `critical_points_527c4abf.slurm` → DELETE
- `critical_points_54b099bc.slurm` → DELETE
- `fix_json3_749aeea1.slurm` → DELETE
- `globtim_compile_d3eaa769.slurm` → DELETE
- `globtim_deps_6a74a311.slurm` → DELETE
- `globtim_final_compile.slurm` → DELETE
- `globtim_final_working.slurm` → DELETE
- `globtim_minimal_42BE239E.slurm` → DELETE
- `globtim_production.slurm` → DELETE
- `globtim_simple_5cb3f677.slurm` → DELETE
- `julia_nfs_production.slurm` → DELETE
- `julia_nfs_template.slurm` → DELETE
- `julia_nfs_test.slurm` → DELETE
- `julia_simple_test.slurm` → DELETE
- `minimal_test.slurm` → DELETE
- `simple_test.slurm` → DELETE
- `test_basic_julia.slurm` → DELETE
- `test_hpc_bundle.slurm` → DELETE
- `test_slurm_simple.slurm` → DELETE

#### Obsolete Scripts
- `monitor_d3eaa769.sh` → DELETE
- `setup_nfs_julia.sh` → DELETE (superseded by hpc/infrastructure/)
- `setup_offline_depot.jl` → DELETE (superseded by bundling)
- `verify_depot.jl` → DELETE

### Category 4: PRESERVE (Keep as-is)
**Target**: Maintain current location and structure

#### Essential Project Files
- `README.md` - **KEEP**
- `LICENSE` - **KEEP**
- `CHANGELOG.md` - **KEEP**
- `Project.toml` - **KEEP**
- `Manifest.toml` - **KEEP**

#### HPC Bundling Infrastructure (Recent Work)
- All files listed in "Protected Assets" section above

#### Core Directories
- `src/` - **KEEP ALL**
- `test/` - **KEEP ALL**
- `Examples/` - **KEEP** (separate cleanup needed)
- `docs/` - **KEEP** (organize within)
- `hpc/` - **KEEP** (recent infrastructure)

## 🔧 Execution Strategy

### Phase 1: Preparation
1. Create backup: `git branch cleanup-backup-$(date +%Y%m%d)`
2. Create archive directory: `docs/archive/repository_cleanup_2025_08_12/`
3. Verify all HPC bundling work is protected

### Phase 2: Root Directory Cleanup
1. Move SLURM files to archive or delete
2. Consolidate documentation files
3. Move configuration files to appropriate directories
4. Clean up temporary and log files

### Phase 3: Documentation Consolidation
1. Merge related documentation files
2. Update cross-references and links
3. Create consolidated guides

### Phase 4: Validation
1. Test core functionality
2. Verify HPC deployment still works
3. Check that all important information is preserved

## 📈 Expected Results

### Quantitative Improvements
- **Root Directory**: 50+ files → ~15 files (70% reduction)
- **Documentation**: 20+ scattered files → 5-8 organized files
- **SLURM Jobs**: 20+ scattered → Organized in hpc/jobs/
- **Overall**: ~30% reduction in total file count

### Qualitative Improvements
- **Easier Navigation**: Clear directory structure
- **Reduced Duplication**: Single source of truth for information
- **Better Organization**: Related files grouped logically
- **Preserved Functionality**: All core features maintained
- **Protected Recent Work**: HPC bundling infrastructure intact

## 🚀 Next Steps

1. **Review and Approve** this cleanup plan
2. **Execute Phase 1** (preparation and backup)
3. **Execute Phase 2** (root directory cleanup)
4. **Execute Phase 3** (documentation consolidation)
5. **Execute Phase 4** (validation and testing)

This cleanup will significantly improve repository maintainability while preserving all critical functionality and recent HPC development work.
