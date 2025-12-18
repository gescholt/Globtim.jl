#!/usr/bin/env bash
#
# cleanup_legacy_results.sh - Remove ALL legacy experiment data
#
# This script removes experiment data stored in the old non-standardized locations:
#   - hpc_results/
#   - local_results/
#   - test_results/
#
# This forces immediate adoption of the standardized output system.
# All data can be regenerated using the new standardized paths.
#
# Usage:
#   ./scripts/cleanup_legacy_results.sh [--dry-run]
#
# Options:
#   --dry-run    Show what would be deleted without actually deleting

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory (globtimcore root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GLOBTIMCORE_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Parse arguments
DRY_RUN=false
if [[ $# -gt 0 ]] && [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# Legacy directories to clean
LEGACY_DIRS=(
    "hpc_results"
    "local_results"
    "test_results"
)

echo -e "${BOLD}${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║  Legacy Experiment Data Cleanup                                ║${NC}"
echo -e "${BOLD}${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}${BOLD}DRY RUN MODE${NC} - No files will be deleted"
else
    echo -e "${RED}${BOLD}WARNING: THIS WILL PERMANENTLY DELETE DATA!${NC}"
fi

echo ""
echo -e "${BOLD}This script will remove all legacy experiment data from:${NC}"
echo ""

cd "$GLOBTIMCORE_ROOT"

# Check what exists and calculate total size
total_size=0
total_files=0
total_dirs=0
declare -A dir_info

for dir in "${LEGACY_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        # Count files and directories
        num_files=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
        num_dirs=$(find "$dir" -type d 2>/dev/null | wc -l | tr -d ' ')

        # Calculate size (in KB for portability)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            dir_size=$(du -sk "$dir" 2>/dev/null | cut -f1)
        else
            # Linux
            dir_size=$(du -sk "$dir" 2>/dev/null | cut -f1)
        fi

        dir_info["$dir"]="$num_files:$num_dirs:$dir_size"
        total_files=$((total_files + num_files))
        total_dirs=$((total_dirs + num_dirs))
        total_size=$((total_size + dir_size))

        # Convert size to human readable
        if [[ $dir_size -gt 1048576 ]]; then
            size_str="$(awk "BEGIN {printf \"%.2f\", $dir_size/1048576}")GB"
        elif [[ $dir_size -gt 1024 ]]; then
            size_str="$(awk "BEGIN {printf \"%.2f\", $dir_size/1024}")MB"
        else
            size_str="${dir_size}KB"
        fi

        echo -e "  ${RED}✗${NC} ${BOLD}$dir/${NC}"
        echo -e "    Files: $num_files, Directories: $num_dirs, Size: $size_str"

        # Show sample of contents
        sample_dirs=$(find "$dir" -maxdepth 2 -type d 2>/dev/null | tail -5 | sed 's/^/      /')
        if [[ -n "$sample_dirs" ]]; then
            echo -e "${BLUE}    Sample directories:${NC}"
            echo "$sample_dirs"
        fi
        echo ""
    else
        echo -e "  ${GREEN}✓${NC} $dir/ (does not exist)"
        echo ""
    fi
done

# Summary
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Summary:${NC}"
echo -e "  Total files to delete: ${RED}$total_files${NC}"
echo -e "  Total directories: ${RED}$total_dirs${NC}"

if [[ $total_size -gt 1048576 ]]; then
    total_size_str="$(awk "BEGIN {printf \"%.2f\", $total_size/1048576}")GB"
elif [[ $total_size -gt 1024 ]]; then
    total_size_str="$(awk "BEGIN {printf \"%.2f\", $total_size/1024}")MB"
else
    total_size_str="${total_size}KB"
fi
echo -e "  Total size: ${RED}$total_size_str${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if there's anything to delete
if [[ $total_files -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ No legacy experiment data found - already clean!${NC}"
    exit 0
fi

# Confirmation
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}${BOLD}DRY RUN COMPLETE${NC}"
    echo ""
    echo "To actually delete these files, run:"
    echo -e "  ${BLUE}./scripts/cleanup_legacy_results.sh${NC}"
    echo ""
    exit 0
fi

echo -e "${RED}${BOLD}This will PERMANENTLY delete all legacy experiment data!${NC}"
echo ""
echo "The data CAN be regenerated later using the standardized output system."
echo ""
echo -e "After cleanup, all experiments MUST use ${BOLD}GLOBTIM_RESULTS_ROOT${NC}:"
echo -e "  ${BLUE}export GLOBTIM_RESULTS_ROOT=~/globtim_results${NC}"
echo -e "  ${BLUE}./scripts/setup_results_root.sh${NC}"
echo ""

read -p "$(echo -e ${BOLD}${RED}Are you ABSOLUTELY sure you want to delete all legacy data? ${NC}[yes/NO]: )" -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${GREEN}Cleanup cancelled - no files deleted${NC}"
    exit 0
fi

echo ""
echo -e "${RED}${BOLD}Final confirmation required!${NC}"
read -p "Type 'DELETE ALL LEGACY DATA' to confirm: " -r
echo

if [[ $REPLY != "DELETE ALL LEGACY DATA" ]]; then
    echo -e "${GREEN}Cleanup cancelled - no files deleted${NC}"
    exit 0
fi

# Perform cleanup
echo ""
echo -e "${RED}${BOLD}Deleting legacy experiment data...${NC}"
echo ""

for dir in "${LEGACY_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo -e "  ${RED}Removing $dir/${NC}"
        rm -rf "$dir"
        echo -e "  ${GREEN}✓ Deleted${NC}"
    fi
done

echo ""
echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Cleanup Complete!                                             ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ All legacy experiment data has been removed${NC}"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "1. Set up standardized output system:"
echo -e "   ${BLUE}./scripts/setup_results_root.sh${NC}"
echo ""
echo "2. Verify configuration:"
echo -e "   ${BLUE}echo \$GLOBTIM_RESULTS_ROOT${NC}"
echo ""
echo "3. All future experiments will use the standardized paths:"
echo -e "   ${BLUE}\$GLOBTIM_RESULTS_ROOT/{objective_name}/{experiment_id}_{timestamp}/${NC}"
echo ""
echo "4. Regenerate any needed experiments using:"
echo -e "   ${BLUE}julia --project=. examples/standardized_experiment_template.jl${NC}"
echo ""

# Create a marker file to indicate cleanup was performed
cleanup_marker="$GLOBTIMCORE_ROOT/.legacy_cleanup_performed"
echo "Legacy experiment data cleanup performed on $(date)" > "$cleanup_marker"
echo "Deleted $total_files files ($total_size_str) from legacy directories" >> "$cleanup_marker"

echo -e "${YELLOW}A marker file has been created: .legacy_cleanup_performed${NC}"
echo ""
