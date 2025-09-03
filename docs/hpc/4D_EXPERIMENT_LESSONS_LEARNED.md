# HPC Node Experiments: Lessons Learned & Implementation Guide

## Status Overview (September 3, 2025)

This document provides a complete guide for running parameter estimation experiments on the r04n02 HPC node, organized by implementation status and actionable next steps.

## 🎯 Current Status Summary

| Component | Status | Ready for Use | Next Action |
|-----------|--------|---------------|-------------|
| **Node Infrastructure** | ✅ COMPLETED | Yes | Deploy experiments |
| **Lotka-Volterra 4D Script** | ✅ COMPLETED | Yes | Test on node |
| **Dependency Management** | ⚠️ NEEDS ATTENTION | Partial | Install JSON package |
| **Path Management** | ✅ FIXED | Yes | Use new structure |
| **Memory Management** | ✅ FIXED | Yes | Use heap hints |
| **Workflow Documentation** | ✅ COMPLETED | Yes | Follow checklist |

## 📋 READY TO RUN: Quick Start Checklist

**Immediate next steps to run Lotka-Volterra parameter estimation:**

- [ ] **SSH to node**: `ssh scholten@r04n02`
- [ ] **Navigate and sync**: `cd /home/scholten/globtim && git pull origin main`
- [ ] **Install JSON** (one-time): `julia --project=. -e 'using Pkg; Pkg.add("JSON")'`
- [ ] **Run experiment**: `./node_experiments/runners/experiment_runner.sh lotka-volterra-4d 8 10`
- [ ] **Monitor**: `tmux attach -t globtim_*` (Ctrl+B then D to detach)
- [ ] **Check results**: `ls -la node_experiments/outputs/`

## Critical Issues Encountered and Fixed

### 1. ❌ Package Activation Path Issue
**Problem**: Script used `Pkg.activate(dirname(@__DIR__))` which activated `/home/scholten/globtim/hpc/` instead of `/home/scholten/globtim/`

**Symptom**: Packages not found, wrong Project.toml activated

**Solution**: 
```julia
# Correct path - go up TWO directories from script location
Pkg.activate(dirname(dirname(@__DIR__)))
```

**Georgy** Reorganize the folder structure with a dedicated folder for experiments we run on the node. make a documentation specific to that folder and accessible to the hpc agent. 
Specify the path for all the Julia scripts stored in that folder. That `node_experiments` folder should be also have a sub-folder for the outputs of experiments. 

**Location**: Line 6 of `run_4d_experiment.jl`

### 2. ❌ Missing Package Dependencies
**Problem**: CSV and JSON packages were not included in Project.toml

**Symptom**: 
```
ERROR: LoadError: ArgumentError: Package CSV not found in current path
```

**Solution**: Install packages on the node:
```bash
julia --project=. -e 'using Pkg; Pkg.add(["CSV", "JSON"])'
```

**Georgy** Are those packages weak dependencies of the project? If so, make sure they are also installed on the node. 

### 3. ❌ Field Access Error in test_input
**Problem**: Script tried to access `TR.sample_pts` which doesn't exist

**Symptom**: 
```
ERROR: LoadError: type test_input has no field sample_pts
```

**Solution**: Use `TR.GN` instead:
```julia
# Wrong
println("✓ Generated $(length(TR.sample_pts)) sample points")

# Correct
println("✓ Generated $(TR.GN) sample points")
```

**Available fields in test_input**: `:dim, :center, :GN, :prec, :tolerance, :noise, :sample_range, :reduce_samples, :degree_max, :objective`

### 4. ⚠️ Memory Exhaustion with Large Polynomials
**Problem**: OutOfMemoryError when creating Vandermonde matrix for degree 12 in 4D

**Symptom**: 
```
ERROR: LoadError: OutOfMemoryError()
Stacktrace:
  [9] generate_grid(n::Int64, GN::Int64; basis::Symbol)
```

**Analysis**: 
- Degree 12 in 4D → (12+1)^4 = 28,561 basis functions
- With 10,000 sample points → Vandermonde matrix is 10,000 × 28,561
- Memory required: ~2.3 GB just for the matrix in Float64

**Solution**: Add heap size hint to Julia execution:
```bash
julia --project=. --heap-size-hint=50G script.jl
```

**Implementation in robust_experiment_runner.sh**:
```bash
# Run the actual experiment with increased heap size
julia --project=. --heap-size-hint=50G $experiment_script \$LOG_DIR
```

### 5. ❌ Git Synchronization Issues
**Problem**: Local changes not reflected on node, wrong script executed

**Symptom**: Output showed "Ackley, Sphere, Rastrigin" functions instead of our Rosenbrock-like function

**Root Cause**: Changes not pulled on node before execution

**Solution Process**:
1. Commit and push locally: `git add -f hpc/experiments/run_4d_experiment.jl && git commit && git push`
2. SSH to node and pull: `ssh scholten@r04n02 "cd /home/scholten/globtim && git pull origin main"`
3. Handle local modifications: `git stash && git pull origin main`

**Georgy** A carefull re-organization with a specific folder to run on the node should help. 
I think the workflow going through pushing to gitlab should be the way to go? 
We need to make a list of specific actions that need to be taken to properly run the examples on the cluster. 
Use the 2d test example as a template and build from there --> the 4d example is heavier to run. 
Verify that all the files with the setup of the 4d example are properly specified. 

### 6. ❌ File Permission Issues
**Problem**: Script not executable after git pull

**Symptom**: 
```
bash: ./hpc/experiments/robust_experiment_runner.sh: Permission denied
```

**Solution**: 
```bash
chmod +x ./hpc/experiments/robust_experiment_runner.sh
```

### 7. ❌ Wrong Script Execution Path
**Problem**: Using `/tmp` for temporary files (against user requirements)

**Original Issue**: Script created temporary files in `/tmp/4d_model_*.jl`

**Solution**: Use project-relative path:
```bash
SCRIPT_DIR="$GLOBTIM_DIR/hpc/experiments/temp"
mkdir -p "$SCRIPT_DIR"
SCRIPT_FILE="$SCRIPT_DIR/4d_model_${SESSION_NAME}.jl"
```

## Memory Management Best Practices

### Understanding Memory Requirements

For tensor product polynomial bases in d dimensions with degree n:
- Number of basis functions = (n+1)^d
- Vandermonde matrix size = (samples) × (basis_functions)
- Memory in GB ≈ (samples × basis_functions × 8) / 10^9

### Examples:
| Dimension | Degree | Basis Functions | 10K Samples Memory |
|-----------|--------|-----------------|-------------------|
| 2         | 12     | 169            | 13.5 MB          |
| 3         | 12     | 2,197          | 175.8 MB         |
| 4         | 12     | 28,561         | 2.3 GB           |
| 5         | 12     | 371,293        | 29.7 GB          |

### Memory Allocation Strategy

1. **Always use heap size hints for large problems**:
   ```bash
   julia --heap-size-hint=50G script.jl
   ```

2. **Check available memory first**:
   ```bash
   free -h
   ```

3. **Monitor memory usage during execution**:
   ```bash
   htop -u $USER
   ```

## Deployment Checklist

Before running any HPC experiment:

- [ ] **Git Synchronization**
  - [ ] All changes committed locally
  - [ ] Changes pushed to remote: `git push origin main`
  - [ ] Changes pulled on node: `git pull origin main`
  - [ ] Handle any local modifications: `git stash` if needed

- [ ] **Package Dependencies**
  - [ ] Verify all packages in script are in Project.toml
  - [ ] Run `Pkg.instantiate()` on node if new packages added
  - [ ] Common missing packages: CSV, JSON, Statistics

- [ ] **Script Configuration**
  - [ ] **FIXED Sept 3**: Use `get(ENV, "JULIA_PROJECT", "/home/scholten/globtim")` NOT `dirname(@__DIR__)`
  - [ ] **FIXED Sept 3**: Never access `TR.objective` as data - it's a Function type
  - [ ] No references to non-existent fields (e.g., `sample_pts`)
  - [ ] Proper error handling for large memory allocations

- [ ] **Execution Environment**
  - [ ] Script has execute permissions: `chmod +x script.sh`
  - [ ] Sufficient heap size for problem dimension
  - [ ] tmux session for persistent execution
  - [ ] Output/error logs redirected to persistent location

## Common Pitfalls to Avoid

1. **CRITICAL (Sept 3)**: Never access `TR.objective` as data - it's a Function, let Constructor handle sampling
2. **CRITICAL (Sept 3)**: Never use `dirname(@__DIR__)` in temp scripts - use environment variables
3. **Don't assume field names** - Always check with `fieldnames(typeof(object))`
4. **Don't use /tmp for anything** - Use `$GLOBTIM_DIR/hpc/experiments/temp/` or similar
5. **Don't forget heap size** - Large polynomial problems need explicit memory allocation
6. **Don't skip git pull** - Always synchronize before running
7. **Don't ignore permissions** - Shell scripts need execute permissions after git operations

## Debugging Commands

```bash
# Check if tmux session is running
tmux ls | grep globtim

# View output log
tail -f /home/scholten/globtim/hpc_results/globtim_*/output.log

# View error log
cat /home/scholten/globtim/hpc_results/globtim_*/error.log

# Check Julia package status
julia --project=/home/scholten/globtim -e 'using Pkg; Pkg.status()'

# Test memory allocation
julia --heap-size-hint=50G -e 'println("Allocated")'
```

## 📊 Implementation Status & Next Steps

### ✅ COMPLETED IMPLEMENTATIONS

#### 1. **Lotka-Volterra 4D Parameter Estimation** (TODAY'S GOAL)
**Status**: ✅ SCRIPT READY, NEEDS NODE TESTING

- ✅ **Created**: Complete script at `node_experiments/scripts/lotka_volterra_4d.jl`
- ✅ **Implemented**: Parameter estimation objective (minimize ODE residual vs synthetic data)
- ✅ **Configured**: 4D parameter space (α, β, γ, δ) with biological constraints
- ✅ **Integrated**: Memory management, timing analysis, comprehensive output
- ⏳ **NEXT**: Test on node with `./node_experiments/runners/experiment_runner.sh lotka-volterra-4d 8 10`

#### 2. **Node Infrastructure Reorganization** 
**Status**: ✅ COMPLETED, READY FOR USE

- ✅ **Created**: Complete `node_experiments/` structure
- ✅ **Implemented**: Unified experiment runner with proper path management  
- ✅ **Documented**: Comprehensive README with troubleshooting guide
- ✅ **Built**: Package setup and path validation utilities

#### 3. **Dependency Management Analysis**
**Status**: ✅ ANALYZED, ONE ACTION NEEDED

- ✅ **Found**: CSV is weak dependency (activates GlobtimDataExt extension)
- ✅ **Found**: JSON missing from Project.toml 
- ✅ **Created**: Automated package setup script
- ⏳ **NEXT**: Run `julia --project=. -e 'using Pkg; Pkg.add("JSON")'` on node (one-time)

#### 4. **GitLab Issues Created**
**Status**: ✅ CREATED, TRACKING ACTIVE

- ✅ **Issue #19**: Lotka-Volterra 4D Parameter Estimation (HIGH PRIORITY)
- ✅ **Issue #20**: Node Experiments Infrastructure (MEDIUM PRIORITY)  
- ✅ **Issue #21**: Standardized Workflow Framework (MEDIUM PRIORITY)

### 🔄 IN PROGRESS: Additional Analysis Needed

#### 5. **Template Comparison with Existing Experiments**
**Status**: 🔄 ANALYZING `experiments/week5/` and `experiments/week7/` patterns

**Key Findings from Existing Code**:
- **Configuration Pattern**: Well-structured config objects for experiment parameters
- **Path Inconsistency**: Mixed `Pkg.activate(@__DIR__)` vs project root activation  
- **Output Management**: Systematic `id{number}_{description}` naming but manual ID assignment
- **Comprehensive Reporting**: Excellent text output with config, timing, results

**Implementation Difficulty Assessment** (Easy/Medium/Hard):

| Best Practice Category | Difficulty | Status in Our Implementation |
|------------------------|------------|------------------------------|
| **Config-based experiments** | Easy | ✅ Implemented in Lotka-Volterra script |
| **Automated output naming** | Easy | ✅ Timestamp-based naming implemented |
| **Package dependency validation** | Easy | ✅ Built into experiment runner |
| **Systematic path management** | Medium | ✅ Fixed with node_experiments/ structure |
| **Memory requirement prediction** | Medium | ✅ Formula-based estimation documented |
| **Experiment state recovery** | Medium | ⏳ Could enhance with checkpointing |
| **Multi-parameter space exploration** | Hard | ⏳ Future enhancement opportunity |
| **Distributed computation** | Hard | ⏳ Not needed for current scope |

### 🎯 IMMEDIATE PRIORITIES (Before Running Experiments)

1. **TODAY**: Test Lotka-Volterra 4D on node (ready to execute)
2. **Validate**: Compare our approach with week5/week7 templates  
3. **Enhance**: Add any missing best practices from existing experiments
4. **Document**: Lessons learned from first successful 4D parameter estimation run

## Successful 4D Experiment Configuration (Previous Session)

After all fixes, the working configuration was:
- **Dimension**: 4
- **Degree**: 12 (requires 50GB heap hint)
- **Samples per dimension**: 10 (10,000 total)
- **Function**: Rosenbrock-like with oscillations
- **Memory**: `--heap-size-hint=50G`
- **Output**: DataFrame with critical points in CSV and JSON formats

## Next Immediate Actions

1. **TODAY**: Focus on Lotka-Volterra 4D parameter estimation implementation
2. **Create node_experiments/ structure** with proper documentation
3. **Generate GitLab issues** for systematic tracking
4. **Validate complete workflow** from development to node execution