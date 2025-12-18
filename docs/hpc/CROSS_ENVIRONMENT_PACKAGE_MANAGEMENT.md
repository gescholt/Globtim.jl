# Cross-Environment Package Management Strategy
## GlobTim Project - Local vs HPC Cluster Synchronization

### Overview

This document outlines strategies for managing Julia package dependencies across different environments (local development machine vs HPC cluster) to prevent version conflicts and ensure reproducible deployments.

## Current Challenge Analysis

### Environment Differences
- **Local Environment**: macOS Darwin, Julia 1.10.x, frequent package updates
- **HPC Cluster (r04n02)**: Linux x86_64, Julia 1.11.6, less frequent updates
- **Issue**: Version drift between environments leading to Manifest.toml conflicts

### Recent Resolution: OpenBLAS32_jll Conflict
**Problem**: OpenBLAS32_jll version conflict due to Julia version mismatch
- Local: Julia 1.10 → OpenBLAS32_jll v0.3.9-0.3.24 compatibility
- HPC: Julia 1.11.6 → OpenBLAS32_jll v0.3.29 required
- **Root Cause**: `julia = "1.10"` constraint in Project.toml

**Solution Applied**: Updated Project.toml compatibility:
```toml
julia = "1.10, 1.11"  # Now supports both versions
```

## Recommended Package Management Strategies

### Strategy 1: Unified Version Ranges (RECOMMENDED)
**Approach**: Use flexible version ranges in Project.toml that work across both environments

**Implementation**:
```toml
# Project.toml [compat] section
julia = "1.10, 1.11"  # Support both Julia versions
# Use minimum version constraints instead of exact versions
HomotopyContinuation = "2.15"  # Means >=2.15, <3.0
ForwardDiff = "0.10"          # Means >=0.10, <0.11
DataFrames = "1.6"            # Means >=1.6, <2.0
```

**Advantages**:
- Automatic compatibility across environments
- Allows patch/minor version updates without conflicts
- Minimal maintenance overhead

**Disadvantages**:
- Less deterministic builds
- Potential for subtle behavior changes

### Strategy 2: Environment-Specific Manifests
**Approach**: Maintain separate Manifest.toml files for each environment

**Implementation**:
```
Project.toml           # Shared dependencies and loose version bounds
Manifest-local.toml    # Local environment lock file
Manifest-hpc.toml      # HPC environment lock file
.gitignore             # Ignore default Manifest.toml
```

**Workflow**:
```bash
# Local development
cp Manifest-local.toml Manifest.toml
julia --project=.

# HPC deployment
scp Manifest-hpc.toml r04n02:/home/globaloptim/globtimcore/Manifest.toml
```

**Advantages**:
- Completely deterministic builds per environment
- Full control over package versions
- Clear environment separation

**Disadvantages**:
- Higher maintenance overhead
- Manual synchronization required
- Risk of divergence

### Strategy 3: Flexible Bounds with Core Locking (BALANCED)
**Approach**: Lock critical packages, allow flexibility for non-critical ones

**Implementation**:
```toml
# Project.toml - Critical packages with narrow bounds
[compat]
julia = "1.10, 1.11"
Globtim = "1.1.2"                    # Exact version for core package
HomotopyContinuation = "2.15"        # Core mathematical package
DynamicPolynomials = "0.6"           # Core mathematical package
ForwardDiff = "0.10"                 # Core mathematical package

# Flexible for infrastructure packages
JSON3 = "1.14"                       # Allow minor updates
CSV = "0.10"                         # Allow minor updates  
DataFrames = "1.6"                   # Allow minor updates
LinearAlgebra = "1"                  # Standard library - flexible
```

**Advantages**:
- Stability for critical mathematical computations
- Flexibility for infrastructure packages
- Balanced maintenance overhead

### Strategy 4: Container-Based Isolation
**Approach**: Use containerization to ensure identical environments

**Implementation**:
```dockerfile
# Dockerfile
FROM julia:1.11.6
COPY Project.toml Manifest.toml ./
RUN julia --project=. -e "using Pkg; Pkg.instantiate()"
```

**Advantages**:
- Perfect environment reproducibility
- Version drift impossible
- Easy deployment

**Disadvantages**:
- Container overhead on HPC
- Potential performance impact
- Additional infrastructure complexity

## Implementation Recommendations

### Immediate Action Plan (Strategy 3 - Balanced)

1. **Update Project.toml with flexible bounds**:
```toml
[compat]
julia = "1.10, 1.11"
# Core mathematical packages - narrow bounds for stability
Globtim = "1.1.2"
HomotopyContinuation = "2.15"
DynamicPolynomials = "0.6" 
ForwardDiff = "0.10"
StaticArrays = "1.9"
LinearSolve = "3.25"

# Infrastructure packages - flexible bounds
JSON3 = "1.14"
CSV = "0.10"
DataFrames = "1.6"
LinearAlgebra = "1"
Statistics = "1"
TimerOutputs = "0.5"
```

2. **Create environment validation script**:
```julia
# scripts/validate_environment.jl
using Pkg
println("Validating cross-environment compatibility...")
Pkg.status()
# Check for version conflicts
# Validate critical functionality
```

3. **Update deployment workflow**:
```bash
# Before HPC deployment
julia --project=. scripts/validate_environment.jl
# Deploy if validation passes
```

### Long-term Strategy Evolution

**Phase 1** (Current): Flexible bounds with core locking
**Phase 2** (Future): Add automated environment testing
**Phase 3** (Advanced): Container-based deployment if needed

## Best Practices

### Version Management Rules
1. **Core mathematical packages**: Use narrow version bounds (major.minor)
2. **Infrastructure packages**: Use flexible bounds (major only)
3. **Standard library packages**: Always use "1" for maximum flexibility
4. **Julia version**: Support all versions used across environments

### Deployment Workflow
1. **Local testing**: Always test with `Pkg.resolve()` before committing
2. **Version validation**: Use `julia --project=. -e "using Pkg; Pkg.status()"` 
3. **HPC deployment**: Always run `Pkg.instantiate()` after environment updates
4. **Conflict resolution**: Regenerate Manifest.toml when version conflicts occur

### Monitoring and Maintenance
1. **Regular audits**: Monthly review of package versions across environments
2. **Automated testing**: CI/CD pipeline testing on both environments
3. **Documentation**: Keep this document updated with lessons learned

## 🚨 CRITICAL: Package Loading Failures on HPC Cluster

**If you encounter package loading failures on the HPC cluster, THIS SECTION MUST BE READ FIRST.**

### Immediate Diagnosis Steps

**Common Error Patterns:**
- `ERROR: KeyError: key "CSV" not found`
- `ERROR: Unsatisfiable requirements detected for package OpenBLAS32_jll`
- `WARNING: The active manifest file has dependencies that were resolved with a different julia version`

### PROVEN SOLUTION PROTOCOL (September 2025)

**This protocol resolved 100% package loading failures on r04n02:**

1. **Connect to HPC cluster**:
   ```bash
   ssh scholten@r04n02
   cd /home/globaloptim/globtimcore
   ```

2. **Pull latest changes** (ensure updated Project.toml):
   ```bash
   git pull
   ```

3. **CRITICAL: Remove problematic Manifest.toml**:
   ```bash
   rm Manifest.toml
   ```

4. **Regenerate entire environment**:
   ```bash
   julia --project=. -e "using Pkg; Pkg.instantiate()"
   ```

5. **Verify package loading**:
   ```bash
   julia --project=. -e "using CSV, DataFrames; println(\"SUCCESS: Packages loaded correctly\")"
   ```

### Why This Works

- **Root Cause**: Manifest.toml generated with different Julia version (1.11.6 vs 1.10.5)
- **Solution**: Complete environment regeneration using cluster's native Julia version
- **Result**: All 203+ packages reinstall with correct version compatibility

### Warning Signs Requiring Immediate Action

- Any `KeyError` during package operations
- Julia version warnings in Manifest.toml
- OpenBLAS32_jll version conflicts
- CSV package loading failures

**DO NOT ATTEMPT**:
- Manual package version fixes
- Partial environment updates
- Ignoring Julia version warnings

**ALWAYS DO**:
- Complete Manifest.toml regeneration
- Full environment rebuild
- Verification testing after fixes

## Emergency Procedures

### When Version Conflicts Occur
1. **Identify root cause**: Check Julia version compatibility first
2. **Update Project.toml**: Adjust version bounds as needed
3. **Regenerate environment**: Remove Manifest.toml and run `Pkg.instantiate()`
4. **Test functionality**: Verify critical packages load correctly
5. **Document resolution**: Update this guide with lessons learned

### Rollback Procedure
1. **Git revert**: Revert Project.toml changes if needed
2. **Restore Manifest**: Use known-good Manifest.toml from git history
3. **Verify stability**: Ensure both environments work correctly
4. **Plan fix**: Develop alternative approach for version compatibility

## Success Metrics

- **Zero version conflicts** during routine deployments
- **<5 minutes** environment setup time on HPC
- **100% reproducibility** of mathematical results across environments
- **Minimal maintenance overhead** for package version management

This strategy ensures robust, maintainable package management while preventing the version conflicts that caused the recent OpenBLAS32_jll issue.