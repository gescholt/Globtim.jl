# Scripts Directory

Utility scripts for globtimcore development, testing, deployment, and analysis.

## Directory Structure

```
scripts/
├── setup/              # One-time repository setup and configuration
├── dev/                # Development and release tools
├── hpc/                # HPC cluster tools and reporting
├── gitlab/             # GitLab integration and project management
├── testing/            # Testing and quality assurance scripts
├── experiments/        # Experiment launch scripts
└── analysis/           # Data analysis and visualization
```

## Setup Scripts (`setup/`)

**Run once after cloning the repository.**

### `setup_repository.sh`
Initial repository setup with git hooks for remote URL protection.

```bash
./scripts/setup/setup_repository.sh
```

What it does:
- Installs git hooks to protect remote URL
- Verifies and fixes remote URL if needed
- Removes glab-resolved cache
- Sets default branch to 'main'
- Runs validation

### `validate_git_config.sh`
Validate and fix git/GitLab configuration issues.

```bash
./scripts/setup/validate_git_config.sh
```

What it checks:
1. Git remote URL is correct
2. No glab-resolved cache (causes 404s)
3. Git hooks are installed and executable
4. glab authentication is configured
5. glab can access the project
6. Default branch is 'main'

**Run this when:**
- `glab` commands return 404 errors
- Remote URL seems incorrect
- After git operations that might change config
- Monthly as preventive maintenance

---

## Development Tools (`dev/`)

### `format-julia.sh`
Format Julia code using JuliaFormatter.

```bash
# Format all Julia files
./scripts/dev/format-julia.sh

# Check formatting without modifying
./scripts/dev/format-julia.sh --check

# Format specific file
./scripts/dev/format-julia.sh src/MyFile.jl
```

### `auto-release.jl`
Automated release management: version bumping, changelog generation, and release creation.

```bash
# Bump patch version (default)
julia scripts/dev/auto-release.jl patch

# Bump minor version
julia scripts/dev/auto-release.jl minor

# Bump major version
julia scripts/dev/auto-release.jl major
```

### `activate_local.jl`
Activate local development environment with full dependencies (including plotting).

```julia
include("scripts/dev/activate_local.jl")
```

### `hpc-mode.sh`, `julia-project.sh`, `setup-npm-docs.sh`
Additional development utilities for specific tasks.

---

## HPC Tools (`hpc/`)

### `activate_hpc.jl`
Activate HPC environment with minimal dependencies (no plotting).

```julia
include("scripts/hpc/activate_hpc.jl")
```

Optimized for:
- Large-scale computations
- Minimal memory footprint
- Text-based output only

### `generate_cluster_report.jl`
Generate comprehensive reports from cluster computation outputs.

```bash
# Process specific result
julia scripts/hpc/generate_cluster_report.jl 4d_results.json

# Process job directory
julia scripts/hpc/generate_cluster_report.jl collected_results/job_59780287/

# Process all results
julia scripts/hpc/generate_cluster_report.jl --all
```

Features:
- Automated report generation
- Quality classification
- Summary statistics
- Markdown output

---

## GitLab Integration (`gitlab/`)

**⚠️ Migration to MCP in progress** - See issue #176

Scripts for GitLab API interaction, project management, and sprint planning.

### Project Management
- `epic-progress.sh` - Epic progress tracking with visual indicators
- `project-dashboard.sh` - Overall project status dashboard
- `project-status-report.sh` - Detailed project status report

### Sprint Management
- `sprint-dashboard.sh` - Sprint progress visualization
- `sprint-planning.sh` - Sprint planning automation
- `sprint-status.sh` - Current sprint status
- `sprint-transition.sh` - Sprint transition automation
- `create-sprint-issues.sh` - Create sprint issues from templates
- `create-sprint-milestone.sh` - Create sprint milestones

### CI/CD
- `pipeline-status.sh` - Check GitLab CI/CD pipeline status
- `quick_summary.sh` - Quick project summary

### Setup
- `setup-gitlab-env.sh` - Configure GitLab environment
- `setup-gitlab-labels.sh` - Setup GitLab labels
- `setup-gpg-gitlab.sh` - Configure GPG for GitLab
- `get-gitlab-project-id.sh` - Retrieve project ID

### Utilities
- `gitlab-explore.sh` - Explore GitLab project structure
- `test-milestone.sh` - Test milestone functionality

**Note:** These scripts currently use direct GitLab API calls via `curl`. Migration to MCP GitLab tools is planned (issue #176) for better maintainability and type safety.

---

## Testing Scripts (`testing/`)

### `run-aqua-tests.jl`
Run comprehensive Aqua.jl quality tests.

```bash
julia --project=. scripts/testing/run-aqua-tests.jl
```

### `quick-aqua-check.jl`
Quick Aqua.jl quality check for development.

```bash
julia scripts/testing/quick-aqua-check.jl
```

### `setup-aqua-env.jl`
Setup Aqua.jl testing environment.

### `performance-regression-check.jl`
Check for performance regressions in core algorithms.

---

## Experiment Launch Scripts (`experiments/`)

Scripts for launching cluster experiments and campaigns.

### `launch_4d_lv_campaign.sh`
Launch 4D Lotka-Volterra parameter sweep campaigns.

### `launch_4dlv_param_recovery.sh`
Launch 4D Lotka-Volterra parameter recovery experiments.

### `test_session_tracking_launcher.sh`
Test session tracking for experiment monitoring.

---

## Analysis Scripts (`analysis/`)

Data analysis and visualization tools for experiment results.

### `visualize_cluster_results.jl`
**Unified visualization interface** with multiple modes:

```bash
# Interactive mode - select experiment and visualization type
julia --project=. scripts/analysis/visualize_cluster_results.jl

# Text-based ASCII visualization (fast, no dependencies)
julia --project=. scripts/analysis/visualize_cluster_results.jl hpc_results/experiment_dir

# Interactive GLMakie display (opens window, requires GLMakie)
julia --project=. scripts/analysis/visualize_cluster_results.jl -i hpc_results/experiment_dir

# Cairo plot generation (saves PNG files, requires CairoMakie)
julia --project=. scripts/analysis/visualize_cluster_results.jl --plots hpc_results/experiment_dir
```

### `collect_cluster_experiments.jl`
Collect experiment data from HPC cluster via SSH.

### `lotka_volterra_convergence_analysis.jl`
Analyze convergence for Lotka-Volterra experiments.

### `critical_point_refinement_analyzer.jl`
Analyze critical point refinement across degrees.

### `compare_experiments_demo.jl`
Compare multiple experiments side-by-side.

### `plot_convergence_simple.jl`
Simple convergence plotting for quick analysis.

### `visualize_with_globtimplots.jl`
Visualization using GlobtimPlots package integration.

---

## Best Practices

### Environment Activation
- **Local development**: `julia --project=.`
- **HPC cluster**: Use `scripts/hpc/activate_hpc.jl`
- **Testing**: `julia --project=. test/runtests.jl`

### Git/GitLab
- Run `scripts/setup/validate_git_config.sh` monthly
- Use MCP GitLab tools (not direct API calls) - see CLAUDE.md
- GitLab scripts migration to MCP: issue #176

### Code Quality
- Format code: `./scripts/dev/format-julia.sh`
- Run Aqua tests: `julia scripts/testing/run-aqua-tests.jl`
- Check performance: `julia scripts/testing/performance-regression-check.jl`

### Releases
- Use `scripts/dev/auto-release.jl` for version bumping
- Follows semantic versioning
- Generates changelog automatically

---

## Removed Scripts

The following scripts have been removed during cleanup:

- `cluster_report_generator.jl` - Duplicate (replaced by `hpc/generate_cluster_report.jl`)
- `cluster-report` - Redundant shell wrapper
- `create_issue_90.sh` - One-off script for completed task
- `fix-gpg-email.sh`, `add-email-to-gpg.sh` - Specific one-time setup
- `fix_julia_environments.jl` - Legacy cleanup (no longer needed)
- `fix_test_manifest.jl`, `fix_test_manifest.sh` - Obsolete test fixes

---

## Contributing

When adding new scripts:
1. Place in appropriate subdirectory by function
2. Add executable permissions: `chmod +x script.sh`
3. Update this README with usage documentation
4. Follow CLAUDE.md guidelines (no fallbacks, no static prints)
5. Use MCP GitLab tools instead of direct API calls

---

**Documentation:** See [docs/GIT_GITLAB_CONFIGURATION.md](../docs/GIT_GITLAB_CONFIGURATION.md) for complete GitLab configuration documentation.
