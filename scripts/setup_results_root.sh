#!/usr/bin/env bash
#
# setup_results_root.sh - Configure GLOBTIM_RESULTS_ROOT for experiment outputs
#
# This script sets up the standardized results directory and configures
# your environment to use it automatically.
#
# Usage:
#   ./scripts/setup_results_root.sh [path]
#
# If no path is provided, uses:
#   - Local: ~/globtim_results
#   - HPC: /scratch/$USER/globtim_results (if /scratch exists)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect environment
detect_environment() {
    if [[ -n "${SLURM_JOB_ID:-}" ]] || [[ -n "${SLURM_CLUSTER_NAME:-}" ]]; then
        echo "hpc"
        return
    fi

    local hostname=$(hostname)
    if [[ "$hostname" =~ ^(r[0-9]+n[0-9]+|gpu[0-9]+|login[0-9]+|compute[0-9]+) ]]; then
        echo "hpc"
        return
    fi

    echo "local"
}

# Get default path based on environment
get_default_path() {
    local env=$(detect_environment)

    if [[ "$env" == "hpc" ]]; then
        if [[ -d "/scratch" ]]; then
            echo "/scratch/${USER}/globtim_results"
        else
            echo "${HOME}/globtim_results"
        fi
    else
        echo "${HOME}/globtim_results"
    fi
}

# Get shell config file
get_shell_config() {
    local shell_name=$(basename "$SHELL")

    case "$shell_name" in
        bash)
            if [[ -f "$HOME/.bash_profile" ]]; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        zsh)
            echo "$HOME/.zshrc"
            ;;
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        *)
            echo "$HOME/.profile"
            ;;
    esac
}

# Main setup function
setup_results_root() {
    local target_path="${1:-$(get_default_path)}"
    local env=$(detect_environment)

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  GlobTim Results Root Setup${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Environment detected: ${GREEN}$env${NC}"
    echo -e "Target directory: ${GREEN}$target_path${NC}"
    echo ""

    # Expand path
    target_path=$(eval echo "$target_path")

    # Create directory if it doesn't exist
    if [[ ! -d "$target_path" ]]; then
        echo -e "${YELLOW}Directory does not exist. Creating...${NC}"
        mkdir -p "$target_path"
        echo -e "${GREEN}✓ Created directory${NC}"
    else
        echo -e "${GREEN}✓ Directory already exists${NC}"
    fi

    # Test write permissions
    local test_file="${target_path}/.write_test_$$"
    if touch "$test_file" 2>/dev/null; then
        rm "$test_file"
        echo -e "${GREEN}✓ Write permissions verified${NC}"
    else
        echo -e "${RED}✗ ERROR: Cannot write to directory${NC}"
        echo -e "${RED}  Please check permissions on: $target_path${NC}"
        exit 1
    fi

    # Create standard subdirectories
    echo ""
    echo -e "${YELLOW}Creating standard subdirectory structure...${NC}"
    mkdir -p "$target_path/batches"
    mkdir -p "$target_path/indices"
    echo -e "${GREEN}✓ Created batches/ and indices/${NC}"

    # Get absolute path
    local abs_path=$(cd "$target_path" && pwd)

    # Configure environment variable
    echo ""
    echo -e "${YELLOW}Configuring environment variable...${NC}"

    local shell_config=$(get_shell_config)
    local export_line="export GLOBTIM_RESULTS_ROOT=\"$abs_path\""

    # Check if already configured
    if [[ -f "$shell_config" ]] && grep -q "GLOBTIM_RESULTS_ROOT" "$shell_config" 2>/dev/null; then
        echo -e "${YELLOW}GLOBTIM_RESULTS_ROOT already configured in $shell_config${NC}"
        echo -e "${YELLOW}Current value:${NC}"
        grep "GLOBTIM_RESULTS_ROOT" "$shell_config"
        echo ""
        read -p "Update to new path? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove old lines
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/GLOBTIM_RESULTS_ROOT/d' "$shell_config"
            else
                sed -i '/GLOBTIM_RESULTS_ROOT/d' "$shell_config"
            fi
            echo "$export_line" >> "$shell_config"
            echo -e "${GREEN}✓ Updated $shell_config${NC}"
        fi
    else
        echo "$export_line" >> "$shell_config"
        echo -e "${GREEN}✓ Added to $shell_config${NC}"
    fi

    # Set for current session
    export GLOBTIM_RESULTS_ROOT="$abs_path"

    # Create README
    cat > "$abs_path/README.md" << 'EOF'
# GlobTim Results Directory

This directory stores all experiment outputs from `globtimcore`.

## Structure

```
globtim_results/
├── {objective_name_1}/          # Organized by objective function
│   ├── exp_20251016_143022/     # Individual experiments
│   ├── exp_20251016_151234/
│   └── exp_20251017_093045/
├── {objective_name_2}/
│   └── ...
├── batches/                     # Batch experiment manifests
└── indices/                     # Experiment indices for searching
```

## Standard Files in Each Experiment

- `results_summary.json` - Main results (schema v1.1.0)
- `critical_points_deg_*.csv` - Critical points per degree
- `experiment_config.json` - Configuration snapshot
- `timing_report.txt` - Performance metrics

## Usage

This directory is automatically used when `GLOBTIM_RESULTS_ROOT` is set.

See `globtimcore/docs/OUTPUT_STANDARDIZATION.md` for details.
EOF

    echo -e "${GREEN}✓ Created README.md${NC}"

    # Summary
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Results root: ${GREEN}$abs_path${NC}"
    echo -e "Configuration: ${GREEN}$shell_config${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Restart your shell or run: ${BLUE}source $shell_config${NC}"
    echo -e "  2. Verify with: ${BLUE}echo \$GLOBTIM_RESULTS_ROOT${NC}"
    echo -e "  3. Run experiments - they will automatically use this location"
    echo ""

    # Show current status
    echo -e "${YELLOW}Current session status:${NC}"
    echo -e "  GLOBTIM_RESULTS_ROOT=${GREEN}${GLOBTIM_RESULTS_ROOT:-not set}${NC}"
    echo ""
}

# Parse arguments
if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [path]"
    echo ""
    echo "If no path provided, uses default based on environment:"
    echo "  Local: ~/globtim_results"
    echo "  HPC:   /scratch/\$USER/globtim_results"
    exit 1
fi

setup_results_root "$@"
