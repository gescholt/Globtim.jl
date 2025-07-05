# Cleanup and Archive Plan - ForwardDiff_Certification/by_degree

## Overview

This directory has accumulated 51+ test files and numerous outdated implementations during the development of the enhanced analysis. This plan organizes files into categories for archiving or deletion.

## Current Production Files (KEEP)

### Main Entry Points
- `run_all_examples.jl` - Primary entry point
- `ENHANCED_ANALYSIS_SUMMARY.md` - Current implementation documentation
- `README.md` - Main documentation (updated)

### Core Implementation
- `examples/degree_convergence_analysis_enhanced_v2.jl` - Current production code
- `shared/Common4DDeuflhard.jl` - Core function definitions
- `shared/SubdomainManagement.jl` - Subdomain utilities

### Reference Data
- `points_deufl/4d_min_min_domain.csv` - 9 true minimizers
- `points_deufl/2d_coords.csv` - 2D reference points

### Documentation
- `documentation/README.md` - Documentation index
- `documentation/subdivided_analysis_workflow.md` - Workflow documentation
- `documentation/function_io_reference.md` - Function reference
- Other files in `documentation/` - Keep for reference

## Files to Archive

### Previous Analysis Versions (ARCHIVE to `archived/analysis_v1/`)
- `examples/degree_convergence_analysis_enhanced.jl` - Superseded by v2
- `examples/simplified_subdomain_analysis.jl`
- `examples/simplified_subdomain_analysis_new_distance.jl`
- `examples/02_subdivided_fixed_all_domains.jl`
- `examples/minimizer_convergence_analysis.jl`

### Debug and Test Files (ARCHIVE to `archived/debug_tests/`)
- `debug_*.jl` files (6 files):
  - `debug_distance_issue.jl`
  - `debug_plotting_issue.jl`
  - `debug_recovery_issue.jl`
  - `debug_subdivision_issue.jl`
  - `debug_subdomain_centers.jl`
  - `simple_threshold_test.jl`

### Analysis Scripts (ARCHIVE to `archived/analysis_scripts/`)
- `analyze_*.jl` files (5 files):
  - `analyze_all_tensor_products.jl`
  - `analyze_distance_logic.jl`
  - `analyze_min_min_pairs.jl`
  - `analyze_subdomain_without_theoretical.jl`
  - `analyze_2d_orthant_classification.jl`

### Test Files (ARCHIVE to `archived/tests/`)
- `test_*.jl` files (except those in test/ directory):
  - `test_enhanced_analysis.jl`
  - `test_enhanced_v2.jl`
  - `test_capture_methods_plotting.jl`
  - `test_distance_plot.jl`
  - `test_enhanced_data_structures.jl`
  - `test_enhanced_plotting.jl`
  - `test_enhanced_plotting_standalone.jl`
  - `test_enhanced_standalone.jl`
  - `test_first_plot.jl`
  - `test_fixed_degree_only.jl`
  - `test_histogram_plotting.jl`
  - `test_min_min_plotting.jl`
  - `test_minimizer_distribution.jl`
  - `test_minimizer_distribution_simple.jl`
  - `test_multiple_subdomains.jl`

### Verification Scripts (ARCHIVE to `archived/verification/`)
- `verify_*.jl` files (7 files):
  - `verify_all_theoretical_minimizers.jl`
  - `verify_data_collection.jl`
  - `verify_implementation_strategy.jl`
  - `verify_min_min_distribution.jl`
  - `verify_orthant_points.jl`
  - `verify_proper_theoretical_points.jl`
  - `verify_stretched_domain.jl`
  - `verify_theoretical_points.jl`

### Utility Scripts (ARCHIVE to `archived/utilities/`)
- `check_*.jl` files:
  - `check_all_orthant_minimizers.jl`
  - `check_gaps.jl`
- `fix_*.jl` files:
  - `fix_plotting_duplication.jl`
  - `fix_subdomain_assignment.jl`
- `generate_4d_coords.jl`
- `quick_test_all_subdomains.jl`

### Comparison Scripts (ARCHIVE to `archived/comparisons/`)
- `compare_2d_vs_4d_analysis.jl`
- `run_2d_vs_4d_comparison.jl`
- `run_2d_vs_4d_display_only.jl`

### Old Documentation (ARCHIVE to `archived/old_docs/`)
- `*.md` files that are outdated:
  - `2D_vs_4D_ANALYSIS_SUMMARY.md`
  - `CHANGES_AND_CONFIGURATION.md`
  - `CONVERGENCE_PLOTS.md`
  - `DATA_FLOW.md`
  - `EXAMPLE_PLAN.md`
  - `IMPLEMENTATION_COMPLETE.md`
  - `min_min_distance_tracking.md`
  - `plot_improvements_summary.md`
  - `README_CRITICAL_POINTS.md`
  - `recovery_plot_improvements.md`
  - `REORGANIZATION_SUMMARY.md`
  - `SUBDIVISION_ISSUE_ANALYSIS.md`
  - `tracking_all_critical_points_draft.md`
  - `VERIFICATION_SUMMARY.md`

### Archived Outputs (KEEP but note)
- `archived_outputs/` - Already organized by timestamp, keep for reference

## Implementation Steps

1. **Create archive structure**:
   ```bash
   mkdir -p archived/2025_01_cleanup/{analysis_v1,debug_tests,analysis_scripts,tests,verification,utilities,comparisons,old_docs}
   ```

2. **Move files to archives** (preserving git history):
   ```bash
   git mv [files] archived/2025_01_cleanup/[category]/
   ```

3. **Update .gitignore** to exclude future test outputs:
   ```
   test_*.jl
   debug_*.jl
   verify_*.jl
   ```

4. **Create archive README**:
   Document what each archived directory contains and why it was archived.

5. **Update main README**:
   Add note about archived files and where to find them.

## Files Requiring Decision

These files may have current value:
- `run_enhanced_v2_minimal.jl` - Recent minimal test, could keep or archive
- `examples/README.md` - May need updating or archiving

## Summary Statistics

- **Current files**: 51+ Julia files, 35+ markdown files
- **Files to keep**: ~15 files
- **Files to archive**: ~70+ files
- **Expected reduction**: ~80% fewer files in main directory

## Benefits

1. **Clarity**: Clear separation between production code and development artifacts
2. **Maintainability**: Easier to understand current implementation
3. **History**: Preserves development history in organized archives
4. **Performance**: Faster directory operations with fewer files

## Next Steps

After cleanup:
1. Update CI/CD to only test production files
2. Create development guide for future contributors
3. Document the enhanced v2 architecture thoroughly