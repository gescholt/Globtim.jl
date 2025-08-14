#!/bin/bash
# Cleanup script to remove clutter from failed HPC bundle attempts
# Created: August 12, 2025

echo "🧹 Cleaning up failed HPC bundle attempts..."
echo ""

# Change to repository root
cd /Users/ghscholt/globtim

# Files already deleted in git (marked with D) - these are already gone
echo "✅ Already removed (deleted in git):"
echo "  - All 4D_*.md files"
echo "  - Test files (test_*.jl)"
echo "  - Old documentation files"
echo "  - Backup scripts"
echo "  - NFS SLURM scripts"
echo ""

# Remove untracked files from failed attempts
echo "🗑️  Removing untracked files from failed attempts..."

# Failed submission scripts and tests
rm -f hpc/jobs/submission/bypass_pkg_system.sh
rm -f hpc/jobs/submission/fix_json3_dependency.sh
rm -f hpc/jobs/submission/quick_compile_test.sh
rm -f hpc/jobs/submission/submit_globtim_with_deps.sh

# Failed SLURM jobs
rm -f hpc/jobs/submission/globtim_deps_*.slurm
rm -f hpc/jobs/submission/globtim_minimal_*.slurm
rm -f hpc/jobs/submission/globtim_pkg_install_*.slurm
rm -f hpc/jobs/submission/globtim_production_standalone.slurm
rm -f hpc/jobs/submission/globtim_working_compile.slurm
rm -f hpc/jobs/submission/test_full_globtim_compilation.slurm

# Debug attempts for exit code 53
rm -f hpc/jobs/submission/debug_exit53_*.slurm
rm -f hpc/jobs/submission/slurm_exit53_investigation_*.json

# Old Python submission script backups
rm -f hpc/jobs/submission/submit_basic_test.backup_*.py
rm -f hpc/jobs/submission/submit_globtim_compilation_test.backup_*.py
rm -f hpc/jobs/submission/submit_comprehensive_test_suite.py
rm -f hpc/jobs/submission/submit_conditional_loading_test.py
rm -f hpc/jobs/submission/submit_globtim_compilation_with_monitoring.py
rm -f hpc/jobs/submission/submit_globtim_simple_compile.py

# Test result JSONs from failed attempts
rm -f hpc/jobs/submission/comprehensive_test_results_*.json

# Old bundle test that didn't work with NFS
rm -f hpc/jobs/submission/test_nfs_bundle.slurm
rm -f hpc/jobs/submission/test_globtim_hpc_bundle.slurm

# Remove obsolete files in root
rm -f install_bundle_hpc.sh
rm -f test/runtests_hpc.jl
rm -f src/ConditionalLoading.jl

# Remove empty testing directory
rmdir hpc/testing/ 2>/dev/null

echo ""
echo "📁 Files to KEEP:"
echo "  ✅ instructions/bundle_hpc.md (main instructions)"
echo "  ✅ julia_offline_prep_hpc/ (working bundle directory)"
echo "  ✅ GIT_WORKFLOW_UPDATE_COMPLETE.md"
echo "  ✅ PUSH_TO_GITLAB_COMPLETE.md"
echo "  ✅ CLAUDE.md (documents why standalone fails)"
echo "  ✅ DEVELOPMENT_GUIDE.md"
echo ""

echo "📊 Checking remaining untracked files..."
cd /Users/ghscholt/globtim
echo ""
echo "Remaining untracked files after cleanup:"
git status --short | grep "^??"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Next steps:"
echo "1. Review remaining files with: git status"
echo "2. Add important files: git add <file>"
echo "3. Update .gitignore for generated files"
echo "4. Commit the cleanup"