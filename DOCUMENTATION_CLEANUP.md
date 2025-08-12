# Documentation Cleanup Plan
*Date: August 12, 2025*

## Summary
Consolidated all HPC documentation into a single comprehensive guide: **HPC_GUIDE.md**

## Files to Keep
1. **HPC_GUIDE.md** - Main consolidated documentation (NEW)
2. **CLAUDE.md** - Project memory and lessons learned
3. **instructions/bundle_hpc.md** - Detailed bundle creation instructions
4. **julia_offline_prep_hpc/BUNDLE_SUCCESS_AND_CLEANUP.md** - Technical implementation details

## Files to Remove (Obsolete/Redundant)

### Root Directory
```bash
# These are now consolidated in HPC_GUIDE.md
rm HPC_BUNDLE_COMPLETE.md          # Merged into HPC_GUIDE.md
rm HPC_README.md                   # Merged into HPC_GUIDE.md
rm README_HPC_Bundle.md            # Merged into HPC_GUIDE.md
rm HPC_PACKAGE_BUNDLING_STRATEGY.md # Outdated approach
rm COMMIT_SUMMARY.md               # Old commit info
rm GIT_WORKFLOW_UPDATE_COMPLETE.md # Workflow documented elsewhere
rm PUSH_TO_GITLAB_COMPLETE.md      # One-time status update
rm GIT_WORKFLOW_ANALYSIS.md        # Analysis complete
rm REPOSITORY_CLEANUP_COMPLETE.md  # Cleanup already done
```

### HPC Directory Documentation
```bash
# Redundant with HPC_GUIDE.md
rm hpc/README.md                                    # Merged into HPC_GUIDE.md
rm hpc/WORKFLOW_CRITICAL.md                         # Merged into HPC_GUIDE.md
rm hpc/docs/HPC_STANDALONE_DOCUMENTATION.md         # Obsolete approach
rm hpc/docs/HPC_COMPILATION_LESSONS_LEARNED.md      # Merged into HPC_GUIDE.md
rm hpc/docs/WORKING_SLURM_CONFIGURATION.md          # Merged into HPC_GUIDE.md
rm hpc/docs/SLURM_DIAGNOSTIC_GUIDE.md               # Merged into HPC_GUIDE.md
rm hpc/docs/hpc_infrastructure_analysis_report.md   # Old analysis
rm hpc/docs/FILESERVER_INTEGRATION_GUIDE.md         # Outdated
rm hpc/docs/VERIFICATION_PROCEDURE_GUIDE.md         # Merged into HPC_GUIDE.md
rm hpc/docs/HPC_WORKFLOW_STATUS.md                  # Status outdated
rm hpc/docs/HPC_PRIVATE_USAGE_GUIDE.md              # Merged into HPC_GUIDE.md
rm hpc/docs/HPC_STATUS_SUMMARY.md                   # Outdated status
rm hpc/docs/DOCUMENTATION_CONSISTENCY_AUDIT.md      # Audit complete
rm hpc/docs/INFRASTRUCTURE_SEPARATION.md            # Outdated design
rm hpc/infrastructure/WORKFLOW_GUIDE.md             # Merged into HPC_GUIDE.md
rm hpc/infrastructure/COMPLETE_SYSTEM_OVERVIEW.md   # Merged into HPC_GUIDE.md
rm hpc/infrastructure/QUICK_START.md                # Merged into HPC_GUIDE.md
rm hpc/infrastructure/AUTOMATED_PULL_GUIDE.md       # Specific workflow not needed
rm hpc/infrastructure/FAQ.md                        # Merged into HPC_GUIDE.md
rm hpc/jobs/submission/FILESERVER_MIGRATION_GUIDE.md # Migration complete
rm hpc/jobs/submission/DEUFLHARD_BENCHMARK_RESULTS.md # Old results
rm hpc/jobs/submission/README.md                    # Outdated
```

### Instructions Directory
```bash
# Keep only bundle_hpc.md, remove obsolete migration docs
rm instructions/HPC_migration.md    # Migration complete
rm instructions/NFS_fix.md          # Issue resolved
rm instructions/part2.md            # Partial instructions
rm instructions/part3.md            # Partial instructions
```

### Docs Directory
```bash
# Remove obsolete HPC-related docs scattered in subdirectories
rm docs/HPC_JOB_SUBMISSION_ANALYSIS.md              # Old analysis
rm docs/REPOSITORY_CLEANUP_PLAN.md                  # Cleanup done
rm docs/HPC_MIGRATION_SUMMARY.md                    # Migration complete
rm docs/hpc/HPC_LIGHT_2D_FILES_DOCUMENTATION.md     # Specific test docs
rm docs/BENCHMARKING_INFRASTRUCTURE_PLAN.md         # Plan implemented
rm docs/benchmarking/4D_TEST_VALIDATION_REPORT.md   # Old test report
rm docs/benchmarking/4D_RESULTS_STRUCTURE_PLAN.md   # Old plan
rm docs/benchmarking/4D_HPC_BENCHMARK_DESIGN.md     # Old design
rm docs/development/CONDITIONAL_LOADING_NO_FALLBACKS.md # Obsolete approach
rm docs/development/TESTING_EXECUTION_PLAN.md       # Plan executed
rm docs/development/TEST_STRUCTURE_ANALYSIS.md      # Analysis complete
rm docs/DOCUMENTATION_ENHANCEMENT_PHASE1_SUMMARY.md # Phase complete
```

### Archive Directory (Already archived, can stay)
```bash
# These are already in archive, no action needed
# docs/archive/...  # Keep all archived files as historical reference
```

### HPC Scripts Documentation
```bash
# Keep only current working documentation
rm hpc/scripts/compilation_tests/CLUSTER_VALIDATION_TEST_SUITE.md # Old tests
rm hpc/scripts/compilation_tests/COMPILATION_TEST_REPORT.md       # Old report
rm hpc/scripts/compilation_tests/README.md                       # Outdated
rm hpc/scripts/benchmark_tests/README.md                          # Basic readme
```

## Cleanup Script

```bash
#!/bin/bash
# cleanup_obsolete_docs.sh

echo "Cleaning up obsolete HPC documentation..."
echo "Keeping: HPC_GUIDE.md (main), CLAUDE.md (memory), bundle_hpc.md (instructions)"

# Create backup first
mkdir -p docs/archive/doc_cleanup_2025_08_12
cp HPC_*.md docs/archive/doc_cleanup_2025_08_12/ 2>/dev/null
cp hpc/docs/*.md docs/archive/doc_cleanup_2025_08_12/ 2>/dev/null

# Remove obsolete files
files_to_remove=(
    "HPC_BUNDLE_COMPLETE.md"
    "HPC_README.md"
    "README_HPC_Bundle.md"
    "HPC_PACKAGE_BUNDLING_STRATEGY.md"
    "COMMIT_SUMMARY.md"
    "GIT_WORKFLOW_UPDATE_COMPLETE.md"
    "PUSH_TO_GITLAB_COMPLETE.md"
    "GIT_WORKFLOW_ANALYSIS.md"
    "REPOSITORY_CLEANUP_COMPLETE.md"
    "hpc/README.md"
    "hpc/WORKFLOW_CRITICAL.md"
    # ... add all files listed above
)

for file in "${files_to_remove[@]}"; do
    if [ -f "$file" ]; then
        echo "Removing: $file"
        rm "$file"
    fi
done

echo "Documentation cleanup complete!"
echo "Main HPC documentation is now in: HPC_GUIDE.md"
```

## Result

After cleanup, HPC documentation will be in just 4 files:
1. **HPC_GUIDE.md** - Complete user guide (main reference)
2. **CLAUDE.md** - Project memory and lessons learned
3. **instructions/bundle_hpc.md** - Detailed bundle creation process
4. **julia_offline_prep_hpc/BUNDLE_SUCCESS_AND_CLEANUP.md** - Technical details

This reduces ~50+ scattered documentation files to 4 comprehensive, maintainable documents.