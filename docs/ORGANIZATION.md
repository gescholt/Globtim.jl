# Globtimcore Repository Organization




This document explains the organization and structure of the globtimcore repository.

## Top-Level Directory Structure

```
globtimcore/
├── src/              # Source code (Julia modules)
├── test/             # Test suite (see test/README.md)
├── Examples/         # Usage examples and demos
├── experiments/      # Research experiments and campaigns
├── docs/             # Documentation (156 markdown files)
├── scripts/          # Task automation and workflow scripts
├── tools/            # Reusable utilities and modules
├── data/             # Reference data and test datasets
└── ext/              # Package extensions
```

---

## Key Directory Distinctions

### `tools/` vs `scripts/`

**When to use each:**

#### `tools/` - Reusable Utilities
Reusable code modules and utilities that can be imported and used programmatically.

**Characteristics**:
- Contains importable Julia/Python modules
- Designed for reuse across multiple contexts
- Often has module structure (subdirectories with multiple files)
- Examples: benchmarking frameworks, MCP servers, validation utilities

**Structure**:
```
tools/
├── benchmarking/         # Benchmark frameworks and dashboards
├── launch_helper/        # Launch automation utilities
├── validation/           # Validation frameworks
├── mcp/                  # MCP server implementations
└── git/                  # Git utility modules
```

#### `scripts/` - Task Automation
Executable workflow scripts for specific tasks and automation.

**Characteristics**:
- Executable scripts (`.sh`, `.jl`, `.py`) for specific tasks
- Command-line oriented
- Often ties together multiple tools
- Task-specific, not designed for import/reuse

**Structure**:
```
scripts/
├── experiments/          # Experiment management scripts
├── hpc/                  # HPC cluster automation
├── gitlab/               # GitLab automation scripts
├── analysis/             # Data analysis scripts
├── setup/                # Setup and configuration scripts
└── testing/              # Testing automation scripts
```

**Example Distinction**:
- `tools/benchmarking/benchmark_dashboard.py` - Importable benchmarking framework
- `scripts/experiments/organize_experiments.py` - One-time reorganization task

---

## Source Code (`src/`)

Contains all Julia source modules for the Globtim package.

**Key modules**:
- Core polynomial optimization algorithms
- Grid generation and manipulation
- Critical point solvers
- HPC integration
- Post-processing utilities

---

## Tests (`test/`)

Comprehensive test suite organized by category. See `test/README.md` for details.

**Structure**:
- `unit/` - Unit tests for individual components
- `integration/` - Integration and E2E tests
- `debugging/` - Debug scripts and investigation tools
- `fixtures/` - Test data and utilities

---

## Examples (`examples/`)

Demonstration scripts showing how to use Globtim features.

**Current state**: Cleaned up to ~8 essential examples (October 2025)

**Key examples**:
- `hpc_minimal_2d_example.jl` - Basic 2D workflow
- `sparsification_demo.jl` - Polynomial sparsification
- `anisotropic_grid_demo.jl` - Anisotropic grids
- `validation_integration_test.jl` - End-to-end validation

**Subdirectories**:
- `Notebooks/` - Jupyter notebooks
- `configs/` - Example configurations
- `production/` - Production-ready scripts

---

## Experiments (`experiments/`)

Research experiments and campaigns for development and benchmarking.

**Structure**:
```
experiments/
├── lv4d_2025/              # Active: Lotka-Volterra 4D experiments
├── daisy_ex3_4d_study/     # Active: Daisy Ex3 4D study
├── generated/              # Auto-generated experiment files (gitignored)
└── _archived/              # Archived legacy experiments
```

**Note**: Generated experiment files are auto-created from templates and not tracked in git.

---

## Data (`data/`)

Reference data, test datasets, and benchmark results.

**Structure**:
```
data/
├── reference/              # Reference datasets
├── matlab_critical_points/ # MATLAB-generated reference points
├── processed/              # Processed analysis data
├── raw/                    # Raw experimental data
└── visualizations/         # Generated plots
```

---

## Documentation (`docs/`)

Extensive documentation (156 markdown files).

**Subdirectories**:
- `user_guides/` - User documentation
- `visualization/` - Visualization guides
- `archive/` - Archived/outdated docs

---

## Configuration Directories

### `.claude/`
Claude Code configuration:
- `agents/` - Specialized agent definitions
- `hooks/` - Git hooks and automation
- `skills/` - Task-specific skills
- `archived_hooks_2025_10/` - Archived hooks

### `.gitlab/`
GitLab CI/CD and templates:
- `issue_templates/` - Issue templates
- `merge_request_templates/` - MR templates

### `.globtim/`
Globtim-specific configuration:
- Notebook setup utilities
- HPC strategy documentation

---

## Cleanup and Archival Policy

### Active Archival Directories
- `test/archived_2025_10/` - Tests archived October 2025 (61 files)
- `experiments/_archived/` - Legacy experiment campaigns
- `docs/archive/` - Outdated documentation

### Gitignored Directories
- `.cache/` - Claude Code cache
- `logs/` - Runtime logs
- `hpc_results/` - Local HPC results (use `$GLOBTIM_RESULTS_ROOT` instead)
- `experiments/generated/` - Auto-generated files

---

## Quick Reference

### Adding New Code
- **New feature** → `src/<module>.jl`
- **Unit test** → `test/unit/test_<feature>.jl`
- **Integration test** → `test/integration/test_<feature>_integration.jl`
- **Example** → `Examples/<feature>_demo.jl`

### Adding Scripts/Tools
- **Reusable utility** → `tools/<category>/`
- **Task automation** → `scripts/<category>/`
- **Research experiment** → `experiments/<campaign>/`

### Archiving Old Code
- **Old tests** → `test/archived_YYYY_MM/`
- **Old experiments** → `experiments/_archived/<name>_legacy/`
- **Old docs** → `docs/archive/`

---

## Maintenance Guidelines

1. **Regular Reviews**: Quarterly review of archived directories for potential deletion
2. **Documentation**: Update READMEs when adding new categories
3. **Cleanup**: Move debugging scripts to archive when issues are resolved
4. **Gitignore**: Keep temporary/generated files out of version control

---

**Last Updated**: 2025-10-21
