# 4D Experiment Lessons Learned - Critical Issues and Solutions

## Date: September 3, 2025

This document captures all issues encountered while setting up and running 4D polynomial optimization experiments on the r04n02 HPC node, along with their solutions.

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
  - [ ] Correct `Pkg.activate` path (usually `dirname(dirname(@__DIR__))`)
  - [ ] No references to non-existent fields (e.g., `sample_pts`)
  - [ ] Proper error handling for large memory allocations

- [ ] **Execution Environment**
  - [ ] Script has execute permissions: `chmod +x script.sh`
  - [ ] Sufficient heap size for problem dimension
  - [ ] tmux session for persistent execution
  - [ ] Output/error logs redirected to persistent location

## Common Pitfalls to Avoid

1. **Don't assume field names** - Always check with `fieldnames(typeof(object))`
2. **Don't use /tmp for anything** - Use `$GLOBTIM_DIR/hpc/experiments/temp/` or similar
3. **Don't forget heap size** - Large polynomial problems need explicit memory allocation
4. **Don't skip git pull** - Always synchronize before running
5. **Don't ignore permissions** - Shell scripts need execute permissions after git operations

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

## Implementation Plan Based on Lessons Learned

### PRIORITY 1: Lotka-Volterra 4D Parameter Estimation (TODAY'S MAIN GOAL)
**Target**: Parameter estimation problem for Lotka-Volterra system in 4D running properly on node

**Tasks**:
- [ ] **Create Lotka-Volterra 4D experiment script** (`node_experiments/lotka_volterra_4d.jl`)
- [ ] **Implement parameter estimation objective function** (minimize residual between ODE solution and synthetic data)  
- [ ] **Configure proper 4D parameter space** (e.g., α, β, γ, δ parameters)
- [ ] **Test and validate on node** with proper memory allocation and output collection
- [ ] **Generate parameter estimation results** with uncertainty bounds and timing analysis

### PRIORITY 2: Node Experiments Infrastructure Reorganization

#### 2.1 Folder Structure Reorganization
**Problem**: Current experiments scattered in `hpc/experiments/`, path issues, poor organization

**Solution**: Create dedicated `node_experiments/` structure:
```
node_experiments/
├── README.md                    # Documentation specific to node experiments
├── scripts/                     # All Julia experiment scripts
│   ├── lotka_volterra_4d.jl    # Priority: Parameter estimation
│   ├── rosenbrock_4d.jl        # Test case from previous session
│   └── test_2d_template.jl     # Template based on working 2D case
├── runners/                     # Bash execution scripts
│   └── experiment_runner.sh    # Updated with proper paths
├── outputs/                     # All experiment outputs
│   ├── lotka_volterra_*/       # LV parameter estimation results
│   └── test_*/                 # Test experiment results
└── utils/                      # Helper scripts and utilities
    ├── package_setup.jl        # Dependency installation helper
    └── path_setup.jl           # Path configuration helper
```

#### 2.2 Weak Dependencies Investigation
**Action**: Verify CSV, JSON, Statistics status in GlobTim Project.toml
- [ ] **Check Project.toml** for weak dependencies vs standard dependencies
- [ ] **Ensure proper installation on node** via `Pkg.add()` or weak dependency activation
- [ ] **Create package setup script** for consistent node environment preparation
- [ ] **Document dependency requirements** in node_experiments/README.md

#### 2.3 Workflow Standardization  
**Problem**: Ad-hoc deployment process, inconsistent procedures

**Solution**: Create standardized GitLab-based workflow:
- [ ] **Document step-by-step deployment checklist** based on 2D working template
- [ ] **Create pre-flight verification script** (check packages, paths, permissions)  
- [ ] **Establish GitLab issue workflow** for experiment tracking
- [ ] **Create experiment validation protocol** (verify setup before heavy computation)

### PRIORITY 3: Testing and Validation Framework

#### 3.1 Progressive Testing Strategy
- [ ] **Start with 2D Lotka-Volterra** (fast validation of parameter estimation approach)
- [ ] **Scale to 3D version** (intermediate complexity)  
- [ ] **Full 4D implementation** (production target)
- [ ] **Performance benchmarking** across different parameter estimation problems

#### 3.2 Robustness Testing
- [ ] **Memory requirement validation** for different problem sizes
- [ ] **Error recovery testing** (interrupted experiments, package failures)
- [ ] **Git synchronization testing** (ensure deployment consistency)
- [ ] **Long-running experiment monitoring** (overnight execution validation)

### PRIORITY 4: GitLab Issues Creation Plan

Based on this analysis, create these GitLab issues:

1. **HIGH PRIORITY**: "Lotka-Volterra 4D Parameter Estimation Implementation" 
   - Main goal for today
   - All infrastructure needed for LV parameter estimation
   
2. **MEDIUM PRIORITY**: "Node Experiments Infrastructure Reorganization"
   - Folder structure, documentation, path fixes
   - Addresses Issues 1, 2, 5 feedback
   
3. **MEDIUM PRIORITY**: "Standardized HPC Workflow and Validation Framework"  
   - Testing protocols, deployment checklists
   - Based on 2D template approach

4. **LOW PRIORITY**: "Weak Dependencies and Package Management Optimization"
   - CSV/JSON dependency investigation and optimization

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