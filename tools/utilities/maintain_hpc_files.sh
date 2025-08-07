#!/bin/bash

# HPC Files Maintenance Script
# Automated file organization and cleanup for HPC testing infrastructure

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🗂️  HPC Files Maintenance Script${NC}"
echo "=" * 60
echo "Started: $(date)"
echo ""

# ============================================================================
# CONFIGURATION
# ============================================================================

DRY_RUN=${1:-"false"}  # Set to "true" to preview actions without executing
ARCHIVE_DAYS=30        # Archive files older than this many days
CLEANUP_DAYS=7         # Clean up temporary files older than this many days

if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE: Previewing actions without executing${NC}"
    echo ""
fi

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

execute_or_preview() {
    local action="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[PREVIEW] $description${NC}"
        echo "   Command: $action"
    else
        echo -e "${GREEN}[EXECUTE] $description${NC}"
        eval "$action"
    fi
}

check_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        execute_or_preview "mkdir -p '$dir'" "Create directory: $dir"
    fi
}

# ============================================================================
# DIRECTORY STRUCTURE SETUP
# ============================================================================

echo -e "${BLUE}📁 Setting up directory structure...${NC}"
echo "-" * 40

# Create recommended directory structure
check_directory "Examples/production"
check_directory "Examples/development"
check_directory "Examples/archive"
check_directory "hpc_results/current"
check_directory "hpc_results/archive"
check_directory "hpc/scripts"
check_directory "archive/obsolete/$(date +%Y%m%d)"
check_directory "docs/hpc"
check_directory "docs/maintenance"

echo ""

# ============================================================================
# IDENTIFY FILE CATEGORIES
# ============================================================================

echo -e "${BLUE}🔍 Analyzing current files...${NC}"
echo "-" * 40

# Find orphaned files
echo "Checking for orphaned files..."
ORPHANED_JL=$(find . -maxdepth 1 -name "*.jl" -not -path "./src/*" -not -path "./Examples/*" -not -path "./test/*" 2>/dev/null || true)
ORPHANED_SLURM=$(find . -maxdepth 1 -name "*.slurm" 2>/dev/null || true)
TEMP_FILES=$(find . -maxdepth 1 -name "custom_*" -mtime +$CLEANUP_DAYS 2>/dev/null || true)

if [ -n "$ORPHANED_JL" ]; then
    echo -e "${YELLOW}⚠️  Orphaned .jl files found:${NC}"
    echo "$ORPHANED_JL" | sed 's/^/   /'
fi

if [ -n "$ORPHANED_SLURM" ]; then
    echo -e "${YELLOW}⚠️  Orphaned .slurm files found:${NC}"
    echo "$ORPHANED_SLURM" | sed 's/^/   /'
fi

if [ -n "$TEMP_FILES" ]; then
    echo -e "${YELLOW}⚠️  Old temporary files found:${NC}"
    echo "$TEMP_FILES" | sed 's/^/   /'
fi

# Check for working files
WORKING_FILES=""
if [ -f "Examples/hpc_standalone_test.jl" ]; then
    WORKING_FILES="$WORKING_FILES Examples/hpc_standalone_test.jl"
fi
if [ -f "run_custom_hpc_test.sh" ]; then
    WORKING_FILES="$WORKING_FILES run_custom_hpc_test.sh"
fi

if [ -n "$WORKING_FILES" ]; then
    echo -e "${GREEN}✅ Working files identified:${NC}"
    echo "$WORKING_FILES" | tr ' ' '\n' | sed 's/^/   /'
fi

echo ""

# ============================================================================
# CLEANUP TEMPORARY FILES
# ============================================================================

echo -e "${BLUE}🧹 Cleaning up temporary files...${NC}"
echo "-" * 40

# Clean up old custom_* files
if [ -n "$TEMP_FILES" ]; then
    for file in $TEMP_FILES; do
        execute_or_preview "rm -f '$file'" "Remove old temporary file: $file"
    done
else
    echo "✅ No old temporary files to clean up"
fi

# Clean up temporary SLURM files
TEMP_SLURM=$(find . -maxdepth 1 -name "*.slurm.tmp" -o -name "slurm-*.out" 2>/dev/null || true)
if [ -n "$TEMP_SLURM" ]; then
    for file in $TEMP_SLURM; do
        execute_or_preview "rm -f '$file'" "Remove temporary SLURM file: $file"
    done
fi

echo ""

# ============================================================================
# ORGANIZE WORKING FILES
# ============================================================================

echo -e "${BLUE}📋 Organizing working files...${NC}"
echo "-" * 40

# Move working files to production
if [ -f "Examples/hpc_standalone_test.jl" ] && [ ! -f "Examples/production/hpc_standalone_test.jl" ]; then
    execute_or_preview "cp Examples/hpc_standalone_test.jl Examples/production/" "Move working test to production"
fi

if [ -f "run_custom_hpc_test.sh" ] && [ ! -f "hpc/scripts/run_custom_hpc_test.sh" ]; then
    execute_or_preview "cp run_custom_hpc_test.sh hpc/scripts/" "Move HPC runner to scripts"
fi

# Archive obsolete files
OBSOLETE_FILES="test_light_2d_example.slurm run_hpc_light_pipeline.sh validate_hpc_pipeline.sh"
for file in $OBSOLETE_FILES; do
    if [ -f "$file" ]; then
        execute_or_preview "mv '$file' archive/obsolete/$(date +%Y%m%d)/" "Archive obsolete file: $file"
    fi
done

echo ""

# ============================================================================
# ORGANIZE TEST RESULTS
# ============================================================================

echo -e "${BLUE}📊 Organizing test results...${NC}"
echo "-" * 40

# Move recent results to current
if [ -d "hpc_results" ]; then
    RECENT_RESULTS=$(find hpc_results -maxdepth 1 -type d -name "*_$(date +%Y%m%d)*" 2>/dev/null || true)
    if [ -n "$RECENT_RESULTS" ]; then
        for result_dir in $RECENT_RESULTS; do
            if [ ! -d "hpc_results/current/$(basename "$result_dir")" ]; then
                execute_or_preview "mv '$result_dir' hpc_results/current/" "Move recent results: $(basename "$result_dir")"
            fi
        done
    fi
    
    # Archive old results
    OLD_RESULTS=$(find hpc_results -maxdepth 1 -type d -mtime +$ARCHIVE_DAYS -not -name "current" -not -name "archive" 2>/dev/null || true)
    if [ -n "$OLD_RESULTS" ]; then
        check_directory "hpc_results/archive/$(date +%Y%m)"
        for result_dir in $OLD_RESULTS; do
            execute_or_preview "mv '$result_dir' hpc_results/archive/$(date +%Y%m)/" "Archive old results: $(basename "$result_dir")"
        done
    fi
fi

echo ""

# ============================================================================
# UPDATE DOCUMENTATION
# ============================================================================

echo -e "${BLUE}📝 Updating documentation...${NC}"
echo "-" * 40

# Move documentation to proper location
if [ -f "HPC_LIGHT_2D_FILES_DOCUMENTATION.md" ] && [ ! -f "docs/hpc/HPC_LIGHT_2D_FILES_DOCUMENTATION.md" ]; then
    execute_or_preview "mv HPC_LIGHT_2D_FILES_DOCUMENTATION.md docs/hpc/" "Move HPC documentation"
fi

# Create maintenance log
MAINTENANCE_LOG="docs/maintenance/maintenance_log.txt"
if [ "$DRY_RUN" = "false" ]; then
    echo "$(date): Maintenance script executed" >> "$MAINTENANCE_LOG"
    echo "  - Cleaned temporary files older than $CLEANUP_DAYS days" >> "$MAINTENANCE_LOG"
    echo "  - Archived results older than $ARCHIVE_DAYS days" >> "$MAINTENANCE_LOG"
    echo "  - Organized working files" >> "$MAINTENANCE_LOG"
    echo "" >> "$MAINTENANCE_LOG"
fi

echo ""

# ============================================================================
# SUMMARY REPORT
# ============================================================================

echo -e "${BLUE}📋 Maintenance Summary${NC}"
echo "=" * 60

# Count files in each category
PRODUCTION_COUNT=$(find Examples/production -name "*.jl" 2>/dev/null | wc -l || echo "0")
DEVELOPMENT_COUNT=$(find Examples/development -name "*.jl" 2>/dev/null | wc -l || echo "0")
CURRENT_RESULTS=$(find hpc_results/current -type d 2>/dev/null | wc -l || echo "0")
ARCHIVED_RESULTS=$(find hpc_results/archive -type d 2>/dev/null | wc -l || echo "0")

echo "📊 File Organization:"
echo "   Production examples: $PRODUCTION_COUNT"
echo "   Development examples: $DEVELOPMENT_COUNT"
echo "   Current test results: $CURRENT_RESULTS"
echo "   Archived test results: $ARCHIVED_RESULTS"

echo ""
echo "📁 Directory Structure:"
echo "   ✅ Examples/production/     - Working, tested examples"
echo "   ✅ Examples/development/    - In-progress examples"
echo "   ✅ hpc_results/current/     - Recent test results"
echo "   ✅ hpc_results/archive/     - Archived results"
echo "   ✅ hpc/scripts/             - Production HPC scripts"
echo "   ✅ docs/hpc/                - HPC documentation"

echo ""
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}🔍 DRY RUN COMPLETED${NC}"
    echo "   Run without 'true' argument to execute changes"
else
    echo -e "${GREEN}✅ MAINTENANCE COMPLETED${NC}"
    echo "   All files organized and cleaned up"
fi

echo ""
echo "📋 Next Steps:"
echo "   1. Review organized files in their new locations"
echo "   2. Update any scripts that reference moved files"
echo "   3. Run maintenance weekly: ./maintain_hpc_files.sh"
echo "   4. Check docs/maintenance/maintenance_log.txt for history"

echo ""
echo "Completed: $(date)"
