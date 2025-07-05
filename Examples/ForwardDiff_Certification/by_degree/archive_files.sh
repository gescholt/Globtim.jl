#!/bin/bash
# Archive script for cleaning up by_degree directory
# Run with: bash archive_files.sh

# Create archive structure
echo "Creating archive directories..."
mkdir -p archived/2025_01_cleanup/{analysis_v1,debug_tests,analysis_scripts,tests,verification,utilities,comparisons,old_docs}

# Archive previous analysis versions
echo "Archiving previous analysis versions..."
for file in examples/degree_convergence_analysis_enhanced.jl \
            examples/simplified_subdomain_analysis.jl \
            examples/simplified_subdomain_analysis_new_distance.jl \
            examples/02_subdivided_fixed_all_domains.jl \
            examples/minimizer_convergence_analysis.jl; do
    if [ -f "$file" ]; then
        git mv "$file" archived/2025_01_cleanup/analysis_v1/ 2>/dev/null || mv "$file" archived/2025_01_cleanup/analysis_v1/
    fi
done

# Archive debug files
echo "Archiving debug files..."
for file in debug_*.jl simple_threshold_test.jl; do
    if [ -f "$file" ]; then
        git mv "$file" archived/2025_01_cleanup/debug_tests/ 2>/dev/null || mv "$file" archived/2025_01_cleanup/debug_tests/
    fi
done

# Archive analysis scripts
echo "Archiving analysis scripts..."
for file in analyze_*.jl; do
    if [ -f "$file" ]; then
        git mv "$file" archived/2025_01_cleanup/analysis_scripts/ 2>/dev/null || mv "$file" archived/2025_01_cleanup/analysis_scripts/
    fi
done

# Archive test files
echo "Archiving test files..."
for file in test_*.jl; do
    if [ -f "$file" ] && [ "$file" != "test/test_shared_utilities.jl" ]; then
        git mv "$file" archived/2025_01_cleanup/tests/ 2>/dev/null || mv "$file" archived/2025_01_cleanup/tests/
    fi
done

# Archive verification scripts
echo "Archiving verification scripts..."
for file in verify_*.jl; do
    if [ -f "$file" ]; then
        git mv "$file" archived/2025_01_cleanup/verification/ 2>/dev/null || mv "$file" archived/2025_01_cleanup/verification/
    fi
done

# Archive utility scripts
echo "Archiving utility scripts..."
for file in check_*.jl fix_*.jl generate_4d_coords.jl quick_test_all_subdomains.jl; do
    if [ -f "$file" ]; then
        git mv "$file" archived/2025_01_cleanup/utilities/ 2>/dev/null || mv "$file" archived/2025_01_cleanup/utilities/
    fi
done

# Archive comparison scripts
echo "Archiving comparison scripts..."
for file in compare_*.jl run_2d_vs_4d*.jl; do
    if [ -f "$file" ]; then
        git mv "$file" archived/2025_01_cleanup/comparisons/ 2>/dev/null || mv "$file" archived/2025_01_cleanup/comparisons/
    fi
done

# Archive old documentation
echo "Archiving old documentation..."
for file in 2D_vs_4D_ANALYSIS_SUMMARY.md CHANGES_AND_CONFIGURATION.md CONVERGENCE_PLOTS.md \
            DATA_FLOW.md EXAMPLE_PLAN.md IMPLEMENTATION_COMPLETE.md min_min_distance_tracking.md \
            plot_improvements_summary.md README_CRITICAL_POINTS.md recovery_plot_improvements.md \
            REORGANIZATION_SUMMARY.md SUBDIVISION_ISSUE_ANALYSIS.md tracking_all_critical_points_draft.md \
            VERIFICATION_SUMMARY.md; do
    if [ -f "$file" ]; then
        git mv "$file" archived/2025_01_cleanup/old_docs/ 2>/dev/null || mv "$file" archived/2025_01_cleanup/old_docs/
    fi
done

# Create archive README
cat > archived/2025_01_cleanup/README.md << 'EOF'
# Archived Files - January 2025 Cleanup

This directory contains files archived during the cleanup of the by_degree analysis framework.
These files were moved here to preserve development history while keeping the main directory focused on the current implementation.

## Archive Structure

- **analysis_v1/**: Previous versions of the analysis implementation
- **debug_tests/**: Debug scripts used during development
- **analysis_scripts/**: Various analysis utilities
- **tests/**: Test files for different components
- **verification/**: Verification scripts for validating implementations
- **utilities/**: Helper scripts and utilities
- **comparisons/**: 2D vs 4D comparison scripts
- **old_docs/**: Outdated documentation files

## Current Implementation

The current production implementation is:
- `examples/degree_convergence_analysis_enhanced_v2.jl`
- Documentation in `ENHANCED_ANALYSIS_SUMMARY.md`

## Accessing Archived Files

These files are preserved for reference and can be accessed if needed for:
- Understanding development history
- Recovering specific functionality
- Debugging historical issues
EOF

echo "Archive complete! Please review the changes and commit if satisfied."
echo "You may want to run: git add -A && git commit -m 'Archive outdated files from by_degree directory'"