#!/bin/bash
# migrate.sh - Safe migration script for by_degree reorganization

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting by_degree folder reorganization...${NC}"

# Create backup first
BACKUP_DIR="../by_degree_backup_$(date +%Y%m%d_%H%M%S)"
echo -e "${YELLOW}Creating backup at: $BACKUP_DIR${NC}"
cp -r . "$BACKUP_DIR"

# Create new directory structure
echo -e "${GREEN}Creating new directory structure...${NC}"
mkdir -p src data docs/implementation docs/reference archive/legacy_v2

# Move shared to src
if [ -d "shared" ]; then
    echo "Moving shared/* to src/"
    mv shared/* src/
    rmdir shared
fi

# Move points_deufl to data
if [ -d "points_deufl" ]; then
    echo "Moving points_deufl/* to data/"
    mv points_deufl/* data/
    rmdir points_deufl
fi

# Move and organize documentation
if [ -d "documentation" ]; then
    echo "Reorganizing documentation..."
    # Main README
    [ -f "documentation/README.md" ] && mv documentation/README.md docs/
    
    # Implementation docs
    for file in V3_IMPLEMENTATION_SUMMARY.md implementation_summary.md critical_code_decisions.md data_flow_diagram.md; do
        [ -f "documentation/$file" ] && mv "documentation/$file" docs/implementation/
    done
    
    # Reference docs
    for file in function_io_reference.md orthant_restriction.md output_structure.md; do
        [ -f "documentation/$file" ] && mv "documentation/$file" docs/reference/
    done
    
    # Move remaining docs to reference
    find documentation -name "*.md" -exec mv {} docs/reference/ \;
    
    rmdir documentation
fi

# Archive v2 implementation if it exists
if [ -f "examples/degree_convergence_analysis_enhanced_v2.jl" ]; then
    echo "Archiving v2 implementation..."
    mv examples/degree_convergence_analysis_enhanced_v2.jl archive/legacy_v2/
fi

# Move archived to archive (rename)
if [ -d "archived" ]; then
    echo "Renaming archived/ to archive/"
    mv archived/* archive/
    rmdir archived
fi

# Remove old shell script
[ -f "archive_files.sh" ] && rm archive_files.sh

echo -e "${GREEN}Migration complete!${NC}"
echo -e "${YELLOW}Don't forget to update the code paths:${NC}"
echo "  1. In examples/degree_convergence_analysis_enhanced_v3.jl:"
echo "     - Lines 16-19: Update include paths from ../shared/ to ../src/"
echo "     - Line 269: Update data path from ../points_deufl/ to ../data/"
echo ""
echo -e "${GREEN}Backup created at: $BACKUP_DIR${NC}"