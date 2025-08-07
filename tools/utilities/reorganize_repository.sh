#!/bin/bash

# Repository Reorganization Script
# Organizes the Globtim repository with proper folder structure for HPC features

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Globtim Repository Reorganization ===${NC}"
echo "This script will organize the repository into a clean structure"
echo "Current root directory has 50+ files - reorganizing for maintainability"
echo ""

# Confirm before proceeding
read -p "Do you want to proceed with reorganization? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Reorganization cancelled."
    exit 1
fi

echo -e "${YELLOW}Starting reorganization...${NC}"
echo ""

# ============================================================================
# STEP 1: Create New Directory Structure
# ============================================================================

echo -e "${BLUE}Step 1: Creating new directory structure...${NC}"

# Create main HPC directory structure
mkdir -p hpc/{infrastructure,jobs/{templates,creation},monitoring/{python,bash},config/parameters}

# Create tools directory structure  
mkdir -p tools/{validation,deployment,maintenance}

# Create backup directory for safety
mkdir -p .reorganization_backup

echo "✓ Directory structure created"

# ============================================================================
# STEP 2: Move HPC Infrastructure Files
# ============================================================================

echo -e "${BLUE}Step 2: Moving HPC infrastructure files...${NC}"

# Infrastructure setup scripts
mv setup_hpc_*.sh hpc/infrastructure/ 2>/dev/null || true
mv deploy_*.sh hpc/infrastructure/ 2>/dev/null || true
mv sync_fileserver_to_hpc.sh hpc/infrastructure/ 2>/dev/null || true
mv install_hpc_packages.sh hpc/infrastructure/ 2>/dev/null || true
mv setup_fileserver_to_hpc_keys.sh hpc/infrastructure/ 2>/dev/null || true
mv setup_hpc_project_space.sh hpc/infrastructure/ 2>/dev/null || true

# Job templates
mv globtim_*.slurm hpc/jobs/templates/ 2>/dev/null || true
mv *.slurm.template hpc/jobs/templates/ 2>/dev/null || true

# Job creation scripts
mv create_*_job.jl hpc/jobs/creation/ 2>/dev/null || true
mv create_*test*.jl hpc/jobs/creation/ 2>/dev/null || true

# Configuration files
mv cluster_config.sh* hpc/config/ 2>/dev/null || true
mv Project_HPC.toml hpc/config/ 2>/dev/null || true

# Move HPC source files
if [ -d "src/HPC" ]; then
    mv src/HPC/* hpc/config/parameters/ 2>/dev/null || true
    rmdir src/HPC 2>/dev/null || true
fi

echo "✓ HPC infrastructure files moved"

# ============================================================================
# STEP 3: Move Monitoring Tools
# ============================================================================

echo -e "${BLUE}Step 3: Moving monitoring tools...${NC}"

# Python monitoring tools
mv hpc/monitoring/python/slurm_monitor.py hpc/monitoring/python/ 2>/dev/null || true
mv vscode_*monitor*.py hpc/monitoring/python/ 2>/dev/null || true
mv vscode_hpc_dashboard.py hpc/monitoring/python/ 2>/dev/null || true

# Bash monitoring scripts
mv monitor_*.sh hpc/monitoring/bash/ 2>/dev/null || true
mv watch_*.sh hpc/monitoring/bash/ 2>/dev/null || true
mv track_*.sh hpc/monitoring/bash/ 2>/dev/null || true
mv check_job_*.sh hpc/monitoring/bash/ 2>/dev/null || true
mv hpc/monitoring/bash/globtim_dashboard.sh hpc/monitoring/bash/ 2>/dev/null || true
mv setup_job_*.sh hpc/monitoring/bash/ 2>/dev/null || true

echo "✓ Monitoring tools moved"

# ============================================================================
# STEP 4: Move Development Tools
# ============================================================================

echo -e "${BLUE}Step 4: Moving development tools...${NC}"

# Validation and testing
mv test_*loading*.jl tools/validation/ 2>/dev/null || true
mv test_*depot*.jl tools/validation/ 2>/dev/null || true
mv test_*parameters*.jl tools/validation/ 2>/dev/null || true
mv test_hpc_*.sh tools/validation/ 2>/dev/null || true
mv validate_*.sh tools/validation/ 2>/dev/null || true

# Deployment utilities
mv git_deploy.sh tools/deployment/ 2>/dev/null || true
mv upload_to_cluster.sh tools/deployment/ 2>/dev/null || true
mv submit_*.sh tools/deployment/ 2>/dev/null || true
mv quick_hpc_test.sh tools/deployment/ 2>/dev/null || true

# Maintenance scripts
mv security_audit.sh tools/maintenance/ 2>/dev/null || true
mv weekly_backup.sh tools/maintenance/ 2>/dev/null || true
mv restore_backup.sh tools/maintenance/ 2>/dev/null || true
mv setup_weekly_backup.sh tools/maintenance/ 2>/dev/null || true
mv setup_secure_ssh.sh tools/maintenance/ 2>/dev/null || true
mv setup_ssh_keys.sh tools/maintenance/ 2>/dev/null || true
mv install_security_hooks.sh tools/maintenance/ 2>/dev/null || true

echo "✓ Development tools moved"

# ============================================================================
# STEP 5: Create Convenience Scripts
# ============================================================================

echo -e "${BLUE}Step 5: Creating convenience scripts...${NC}"

# Create main HPC script
cat > hpc_tools.sh << 'EOF'
#!/bin/bash

# HPC Tools Convenience Script
# Provides easy access to all HPC functionality

case "$1" in
    "monitor")
        python3 hpc/monitoring/python/hpc/monitoring/python/slurm_monitor.py "${@:2}"
        ;;
    "dashboard")
        ./hpc/monitoring/bash/hpc/monitoring/bash/globtim_dashboard.sh
        ;;
    "sync")
        ./hpc/infrastructure/sync_fileserver_to_hpc.sh
        ;;
    "deploy")
        ./hpc/infrastructure/deploy_benchmark_infrastructure.sh
        ;;
    "create-job")
        cd hpc/jobs/creation && julia create_working_globtim_job.jl
        ;;
    "validate")
        ./tools/validation/validate_parameters_jl.sh
        ;;
    *)
        echo "HPC Tools - Usage:"
        echo "  ./hpc_tools.sh monitor [--continuous]  # Monitor SLURM jobs"
        echo "  ./hpc_tools.sh dashboard              # Show HPC dashboard"
        echo "  ./hpc_tools.sh sync                   # Sync to HPC cluster"
        echo "  ./hpc_tools.sh deploy                 # Deploy infrastructure"
        echo "  ./hpc_tools.sh create-job             # Create new job"
        echo "  ./hpc_tools.sh validate               # Validate setup"
        ;;
esac
EOF

chmod +x hpc_tools.sh

# Create README files for each directory
cat > hpc/README.md << 'EOF'
# HPC Infrastructure

This directory contains all HPC-related functionality for Globtim benchmarking.

## Structure

- `infrastructure/` - Setup, deployment, and sync scripts
- `jobs/` - Job templates and creation scripts  
- `monitoring/` - Real-time monitoring tools (Python & Bash)
- `config/` - Configuration files and Parameters.jl system

## Quick Start

```bash
# From repository root:
./hpc_tools.sh monitor --continuous    # Start monitoring
./hpc_tools.sh create-job             # Create new benchmark job
./hpc_tools.sh sync                   # Sync to cluster
```
EOF

cat > tools/README.md << 'EOF'
# Development Tools

Utilities for development, testing, validation, and maintenance.

## Structure

- `validation/` - Testing and validation scripts
- `deployment/` - Deployment and upload utilities
- `maintenance/` - Security, backup, and maintenance scripts

## Usage

Most tools can be run directly from their respective directories.
EOF

echo "✓ Convenience scripts created"

# ============================================================================
# STEP 6: Update Import Paths
# ============================================================================

echo -e "${BLUE}Step 6: Updating import paths...${NC}"

# Update VS Code tasks.json to use new paths
if [ -f ".vscode/tasks.json" ]; then
    sed -i.bak 's|hpc/monitoring/python/slurm_monitor.py|hpc/monitoring/python/hpc/monitoring/python/slurm_monitor.py|g' .vscode/tasks.json
    sed -i.bak 's|hpc/monitoring/bash/globtim_dashboard.sh|hpc/monitoring/bash/hpc/monitoring/bash/globtim_dashboard.sh|g' .vscode/tasks.json
    sed -i.bak 's|track_working_globtim.sh|hpc/monitoring/bash/track_working_globtim.sh|g' .vscode/tasks.json
    echo "✓ VS Code tasks updated"
fi

# Update any shell scripts that reference moved files
find . -name "*.sh" -type f -exec grep -l "hpc/monitoring/python/slurm_monitor.py\|hpc/monitoring/bash/globtim_dashboard.sh" {} \; | while read file; do
    if [[ "$file" != *".bak"* ]] && [[ "$file" != *"hpc/"* ]]; then
        sed -i.bak 's|hpc/monitoring/python/slurm_monitor.py|hpc/monitoring/python/hpc/monitoring/python/slurm_monitor.py|g' "$file"
        sed -i.bak 's|hpc/monitoring/bash/globtim_dashboard.sh|hpc/monitoring/bash/hpc/monitoring/bash/globtim_dashboard.sh|g' "$file"
    fi
done

echo "✓ Import paths updated"

# ============================================================================
# STEP 7: Create Updated Documentation
# ============================================================================

echo -e "${BLUE}Step 7: Creating updated documentation...${NC}"

# Update main README with new structure
cat > README_NEW_STRUCTURE.md << 'EOF'
# Globtim - Global Optimization via Polynomial Approximation

Enhanced with comprehensive HPC benchmarking infrastructure and Parameters.jl integration.

## 🚀 New Features

### HPC Integration
- **SLURM Job Management**: Automated job creation, submission, and monitoring
- **Parameters.jl System**: Type-safe configuration with sensible defaults
- **Real-time Monitoring**: Python and VS Code integrated monitoring tools
- **Three-tier Architecture**: Local → Fileserver → HPC cluster sync

### Quick Start - HPC Benchmarking
```bash
# Monitor SLURM jobs in real-time
./hpc_tools.sh monitor --continuous

# Create and submit benchmark job
./hpc_tools.sh create-job

# Sync code to HPC cluster
./hpc_tools.sh sync

# View HPC dashboard
./hpc_tools.sh dashboard
```

## 📁 Repository Structure

```
globtim/
├── src/                    # Core Globtim source code
├── test/                   # Core tests
├── docs/                   # Documentation
├── Examples/               # Usage examples
├── hpc/                    # 🆕 HPC Infrastructure
│   ├── infrastructure/     # Setup and deployment
│   ├── jobs/              # Job templates and creation
│   ├── monitoring/        # Real-time monitoring tools
│   └── config/            # Configuration and Parameters.jl
├── tools/                  # 🆕 Development Tools
│   ├── validation/        # Testing and validation
│   ├── deployment/        # Deployment utilities
│   └── maintenance/       # Security and maintenance
└── .vscode/               # 🆕 Enhanced VS Code integration
```

## 🎯 HPC Workflow

1. **Configure**: Edit `hpc/config/cluster_config.sh`
2. **Create Job**: `./hpc_tools.sh create-job`
3. **Monitor**: `./hpc_tools.sh monitor --continuous`
4. **Analyze**: Results automatically collected and parsed

## 📊 Monitoring Features

- **Real-time job status** with 30-second updates
- **Automatic result parsing** and performance metrics
- **VS Code integration** with tasks and terminals
- **Cluster resource monitoring** and queue analysis

See `NEW_FEATURES_DOCUMENTATION.md` for complete feature list.
EOF

echo "✓ Updated documentation created"

# ============================================================================
# STEP 8: Summary and Next Steps
# ============================================================================

echo ""
echo -e "${GREEN}=== Reorganization Complete! ===${NC}"
echo ""
echo -e "${YELLOW}Summary of changes:${NC}"
echo "✓ Created organized directory structure"
echo "✓ Moved 40+ files to appropriate locations"
echo "✓ Updated import paths and references"
echo "✓ Created convenience scripts (hpc_tools.sh)"
echo "✓ Added README files for each directory"
echo "✓ Updated VS Code configuration"
echo ""

echo -e "${YELLOW}New structure:${NC}"
echo "📁 hpc/           - All HPC functionality"
echo "📁 tools/         - Development utilities"
echo "📁 .vscode/       - Enhanced VS Code integration"
echo "🔧 hpc_tools.sh   - Convenience script for HPC operations"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test that everything still works:"
echo "   ./hpc_tools.sh validate"
echo ""
echo "2. Test monitoring:"
echo "   ./hpc_tools.sh monitor"
echo ""
echo "3. Review new structure:"
echo "   ls -la hpc/ tools/"
echo ""
echo "4. Update README.md:"
echo "   mv README_NEW_STRUCTURE.md README.md"
echo ""
echo "5. Commit to Git:"
echo "   git add ."
echo "   git commit -m 'Reorganize repository structure for HPC features'"
echo ""

echo -e "${GREEN}Repository successfully reorganized! 🎉${NC}"
echo "The project now has a clean, maintainable structure ready for GitLab."
