# PathUtils Guide for Experiment Scripts

**Date:** 2025-10-05
**Related Issue:** #135
**Status:** Production Ready

## Overview

PathUtils provides robust path resolution utilities for experiment scripts, preventing common path-related bugs that cause deployment failures on HPC clusters.

## Quick Start

### Basic Experiment Script Template

```julia
#!/usr/bin/env julia
"""
Experiment Description
"""

using Pkg

# Load PathUtils for robust path resolution (Issue #135)
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathUtils.jl"))
using .PathUtils

# Get project root and activate environment
project_root = get_project_root()
Pkg.activate(project_root)
Pkg.instantiate()

# Validate project structure
validate_project_structure(project_root)

# Now load project packages
using Globtim
using DynamicPolynomials
# ... other imports

# Create safe output directory
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
output_dir = create_output_dir(@__DIR__, "results_$(timestamp)")

println("Experiment starting...")
println("Project root: $(project_root)")
println("Output directory: $(output_dir)")

# Your experiment code here...
```

## Key Functions

### `get_project_root()` - Find Project Root

Walks up the directory tree to find `Project.toml`, ensuring package activation works from any location.

**Features:**
- Works from any subdirectory
- Supports `GLOBTIM_ROOT` environment variable for HPC
- Provides clear error messages if project not found

**Example:**
```julia
root = get_project_root()
# Returns: /home/scholten/globtimcore (on HPC)
#     or: /Users/user/globtimcore (on local)
```

### `create_output_dir(base, subdir)` - Safe Directory Creation

Creates output directories with security validation and absolute path resolution.

**Features:**
- Prevents directory traversal attacks (`../../../etc`)
- Converts all paths to absolute
- Creates nested directories automatically
- Returns absolute path

**Example:**
```julia
# Create timestamped results directory
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
output = create_output_dir(@__DIR__, "results_$(timestamp)")

# Create nested structure
output = create_output_dir(@__DIR__, "results/batch_1/run_$(timestamp)")
```

### `validate_project_structure(root)` - Verify Project

Checks that required files exist before running experiments.

**Example:**
```julia
root = get_project_root()
validate_project_structure(root)  # Throws error if invalid

# Strict mode (warnings become errors)
validate_project_structure(root, strict=true)
```

### `make_portable_script(template, root)` - Generate HPC Scripts

Replaces hardcoded paths with environment variable fallbacks for portability.

**Example:**
```julia
root = get_project_root()

template = """
using Pkg
Pkg.activate(dirname(dirname(dirname(@__DIR__))))
include(joinpath(dirname(dirname(dirname(@__DIR__))), "src", "Main.jl"))
"""

# Make portable with GLOBTIM_ROOT fallback
portable = make_portable_script(template, root)

# Save to file
write("generated_script.jl", portable)
```

### Helper Functions

```julia
# Get src/ directory
src_dir = get_src_dir()
include(joinpath(src_dir, "ExperimentCLI.jl"))

# Get Examples/ directory
examples_dir = get_examples_dir()
include(joinpath(examples_dir, "systems", "DynamicalSystems.jl"))
```

## HPC Deployment with Environment Variables

### Setting GLOBTIM_ROOT on HPC

```bash
# In ~/.bashrc or job script
export GLOBTIM_ROOT=/home/scholten/globtimcore

# Verify
echo $GLOBTIM_ROOT
```

### Scripts Automatically Use GLOBTIM_ROOT

```julia
# In experiment script
root = get_project_root()
# Automatically uses $GLOBTIM_ROOT if set
# Falls back to searching if not set
```

### Generated Scripts with Portable Paths

When using `make_portable_script()`, generated scripts contain:

```julia
# Before (hardcoded)
Pkg.activate("/home/scholten/globtimcore")

# After (portable with fallback)
Pkg.activate(get(ENV, "GLOBTIM_ROOT", "/home/scholten/globtimcore"))
```

## Migration Guide

### Updating Existing Experiments

**Old Pattern:**
```julia
using Pkg
Pkg.activate(dirname(dirname(dirname(@__DIR__))))

output_dir = joinpath(@__DIR__, "results_$(timestamp)")
mkpath(output_dir)
```

**New Pattern (PathUtils):**
```julia
using Pkg

# Load PathUtils
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathUtils.jl"))
using .PathUtils

# Use PathUtils functions
Pkg.activate(get_project_root())

output_dir = create_output_dir(@__DIR__, "results_$(timestamp)")
```

### Updating Experiment Generators

**Old Pattern:**
```julia
script_content = """
using Pkg
Pkg.activate(dirname(dirname(dirname(@__DIR__))))
"""

open("experiment.jl", "w") do io
    write(io, script_content)
end
```

**New Pattern (PathUtils):**
```julia
# Include PathUtils in generator
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathUtils.jl"))
using .PathUtils

project_root = get_project_root()

script_template = """
using Pkg
Pkg.activate(dirname(dirname(dirname(@__DIR__))))
"""

# Make portable
portable_script = make_portable_script(script_template, project_root)

open("experiment.jl", "w") do io
    write(io, portable_script)
end
```

## Best Practices

### 1. Always Use PathUtils for New Experiments

```julia
# ✅ Good
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathUtils.jl"))
using .PathUtils
root = get_project_root()

# ❌ Avoid
root = dirname(dirname(dirname(@__DIR__)))  # Brittle, CWD-dependent
```

### 2. Create Directories with create_output_dir()

```julia
# ✅ Good - secure, validated, absolute paths
output = create_output_dir(@__DIR__, "results")

# ❌ Avoid - relative paths, no validation
output = joinpath(@__DIR__, "results")
mkpath(output)
```

### 3. Validate Before Long Experiments

```julia
# ✅ Good - fail fast if structure invalid
root = get_project_root()
validate_project_structure(root)

# Now run expensive computation...
```

### 4. Use Environment Variables for HPC

```bash
# Set in job script or .bashrc
export GLOBTIM_ROOT=/home/scholten/globtimcore

# Scripts automatically pick it up
julia experiment.jl  # Uses $GLOBTIM_ROOT
```

## Common Patterns

### Experiment Setup Script

```julia
#!/usr/bin/env julia
"""Setup experiments for campaign"""

using Pkg
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathUtils.jl"))
using .PathUtils

project_root = get_project_root()
Pkg.activate(project_root)

using Dates

# Create campaign directory
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
campaign_dir = create_output_dir(@__DIR__, "campaign_$(timestamp)")

# Generate experiment scripts
for i in 1:10
    script_template = """
    #!/usr/bin/env julia
    using Pkg
    Pkg.activate(dirname(dirname(dirname(@__DIR__))))

    # Experiment $i code...
    """

    # Make portable
    portable = make_portable_script(script_template, project_root)

    # Save
    script_path = joinpath(campaign_dir, "experiment_$(i).jl")
    write(script_path, portable)
    chmod(script_path, 0o755)  # Make executable
end

println("Generated 10 experiments in: $(campaign_dir)")
```

### Multi-Environment Experiment

```julia
#!/usr/bin/env julia
"""Experiment that works on local and HPC"""

using Pkg
include(joinpath(dirname(dirname(dirname(@__FILE__))), "src", "PathUtils.jl"))
using .PathUtils

# Automatically adapts to environment
root = get_project_root()  # Uses GLOBTIM_ROOT on HPC
Pkg.activate(root)

# Detect environment
if haskey(ENV, "GLOBTIM_ROOT")
    println("Running on HPC")
    println("Project root from GLOBTIM_ROOT: $(root)")
else
    println("Running locally")
    println("Project root from search: $(root)")
end

# Rest of experiment...
```

## Troubleshooting

### "Could not find project root"

**Cause:** Script running outside project directory without GLOBTIM_ROOT set

**Solution:**
```bash
# Set environment variable
export GLOBTIM_ROOT=/path/to/globtimcore

# Or cd to project directory
cd /path/to/globtimcore
julia experiment.jl
```

### "Project structure validation failed"

**Cause:** Missing required files (Project.toml, src/, Examples/)

**Solution:**
```julia
# Check what's missing
validate_project_structure(get_project_root())

# Ensure you're in correct directory
cd /path/to/globtimcore
```

### "Invalid subdirectory name (contains '..')"

**Cause:** Attempting directory traversal in create_output_dir()

**Solution:**
```julia
# ❌ Avoid traversal
create_output_dir(@__DIR__, "../../../etc/passwd")

# ✅ Use safe subdirectory names
create_output_dir(@__DIR__, "results")
create_output_dir(@__DIR__, "nested/results")
```

## Testing Your Scripts

### Verify PathUtils Integration

```julia
# Test script loads PathUtils correctly
julia -e 'include("experiment.jl")'  # Should print project root

# Test from different directories
cd /tmp
julia /path/to/experiment.jl  # Should still work

# Test with GLOBTIM_ROOT
export GLOBTIM_ROOT=/path/to/globtimcore
julia experiment.jl  # Should use GLOBTIM_ROOT
```

### Run PathUtils Test Suite

```bash
# Full test suite
julia --project=. test/test_pathutils.jl

# Should show: 66 tests passing
```

## References

- [PathUtils.jl](../../src/PathUtils.jl) - Main module (388 lines)
- [PathUtils Test Suite](../../test/test_pathutils.jl) - Comprehensive tests (66 tests)
- [PathUtils Implementation Summary](../issues/issue_135_pathutils_implementation_summary.md) - Complete documentation
- [Pre-Flight Validation System](PRE_FLIGHT_VALIDATION_SYSTEM.md) - Integration with validation
- [setup_experiments.jl](../../experiments/lotka_volterra_4d_study/setup_experiments.jl) - Example usage

---

**Last Updated:** 2025-10-05
**Maintainer:** GlobTim Infrastructure Team
**Status:** Production Ready
