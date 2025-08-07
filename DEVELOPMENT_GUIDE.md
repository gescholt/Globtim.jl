# Globtim.jl Development Guide

## Repository Structure

This project uses a dual-repository approach:
- **GitLab**: Private development repository (main branch)
- **GitHub**: Public release repository (github-release branch)

## Environment Setup

Globtim supports two distinct environments optimized for different use cases:

### Local Environment
- **Purpose**: Full plotting capabilities, development tools, interactive features
- **Use Cases**: Development, testing, visualization, notebook work
- **Dependencies**: Complete package set including plotting libraries

### HPC Environment
- **Purpose**: Minimal dependencies, optimized for large-scale computations
- **Use Cases**: Cluster computing, batch processing, production runs
- **Dependencies**: Core computational packages only

### Quick Environment Setup

#### For Local Development
```bash
# Option 1: Use shell script
./scripts/local-dev.sh

# Option 2: Manual activation
julia --project=environments/local
```

#### For HPC Deployment
```bash
# Option 1: Use shell script
./scripts/hpc-mode.sh

# Option 2: Manual activation
julia --project=environments/hpc
```

## Julia Integration with Conda

### Conda Environment Integration
If using the `internlm` conda environment, Julia integration is automatically configured:

- **Activation**: Julia is added to PATH when conda environment activates
- **Configuration**: `JULIA_NUM_THREADS="auto"` set for optimal performance
- **Deactivation**: PATH restored when conda environment deactivates

### Manual Julia Setup
```bash
# Add Julia to PATH (if not using conda integration)
export PATH="/opt/homebrew/bin:$PATH"
export JULIA_NUM_THREADS="auto"

# Verify installation
julia --version
```

## Notebook Development

### Universal Notebook Setup
All Globtim notebooks use a standardized setup system that automatically detects your environment and configures appropriate packages.

#### Standard Header Cell
Copy this cell to the top of any Globtim notebook:

```julia
# Globtim Notebook Setup - Universal Header Cell
# This cell automatically detects your environment and sets up the appropriate configuration
# No editing required - works from any location in the project

include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))
```

#### Features
- **Automatic Environment Detection**: Local vs HPC environments
- **Intelligent Package Loading**: Only loads packages available in current environment
- **Plotting Backend Configuration**: CairoMakie for local, minimal plotting for HPC
- **Universal Compatibility**: Works from any directory in the project

#### Supported Environments
- **Local Development**: Full plotting (CairoMakie, GLMakie), development tools
- **HPC Cluster**: Minimal dependencies, plotting on demand
- **Compatible Versions**: CairoMakie 0.11.x, GLMakie 0.9.x, Makie 0.20.x

## Branch Management

### Main Branch (GitLab - Private)
- Contains all development work, experimental features, and work-in-progress
- Includes files not ready for public release (e.g., AnisotropicGridComparison.ipynb)
- This is where all development happens

### GitHub-Release Branch (GitHub - Public)
- Clean version for public consumption and Julia package registry
- Excludes experimental/development files
- Should be the default branch on GitHub

## Daily Development Workflow

### Using the Push Script

A helper script `push.sh` is provided to ensure correct pushing:

```bash
# For daily development (push to GitLab)
./push.sh gitlab

# For public releases (push to GitHub)
./push.sh github
```

The script includes safety checks:
- Warns if you're not on the correct branch
- Prevents pushing main to GitHub
- Checks for private files in github-release branch

### Manual Push Commands

If not using the script:

```bash
# Push to GitLab (private)
git push origin main

# Push to GitHub (public) - ONLY from github-release branch!
git checkout github-release
git push github github-release
```

## Workflow for Public Releases

1. Develop features on `main` branch
2. When ready for public release:
   ```bash
   git checkout github-release
   git merge main --no-ff
   # Remove any files that should stay private
   git rm Examples/Notebooks/AnisotropicGridComparison.ipynb  # if it was accidentally merged
   git commit -m "Prepare for public release"
   ./push.sh github  # or: git push github github-release
   ```

## Files Excluded from Public Release

The following files/directories exist only in the private `main` branch:
- `Examples/Notebooks/AnisotropicGridComparison.ipynb` - Experimental anisotropic grid functionality

## Adding New Private Content

When adding content that should remain private:
1. Add it only to the `main` branch
2. Document it in this file under "Files Excluded from Public Release"
3. Ensure it's not present in `github-release` branch

## Checking Branch Differences

To see what files differ between branches:
```bash
git diff --name-only main github-release
```

To verify a file doesn't exist in github-release:
```bash
git checkout github-release
ls path/to/file  # Should show "No such file or directory"
```
