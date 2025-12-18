# GlobTim HPC Computation Procedures

## Overview
This document provides step-by-step procedures for launching and monitoring computational experiments on the r04n02 compute node using the tmux-based execution framework.

## Prerequisites
- SSH access to r04n02: `ssh scholten@r04n02`
- GlobTim repository cloned at `/home/globaloptim/globtimcore`
- Julia 1.11.6 available via juliaup (automatically in PATH)

## Launching Computations

### 1. Connection to Compute Node
```bash
# Connect to r04n02 compute node
ssh scholten@r04n02
cd /home/globaloptim/globtimcore
```

### 2. Available Experiment Types

#### Lotka-Volterra 4D Parameter Estimation
```bash
# Launch with default parameters (8 samples per dimension, degree 10)
./node_experiments/runners/experiment_runner.sh lotka-volterra-4d

# Launch with custom parameters
./node_experiments/runners/experiment_runner.sh lotka-volterra-4d 8 12
#                                                                 ^  ^
#                                                       samples/dim  degree
```

**Configuration:**
- **Memory Allocation:** 50GB heap size (automatically set)
- **Expected Runtime:** 2-4 hours for degree 10-12
- **Parameter Space:** 4D (α, β, γ, δ parameters)
- **Sample Points:** samples^4 total combinations

#### 4D Rosenbrock Test Case
```bash
# Launch Rosenbrock optimization test
./node_experiments/runners/experiment_runner.sh rosenbrock-4d 10 12
```

#### 2D Validation Test
```bash
# Quick validation test (30-60 seconds)
./node_experiments/runners/experiment_runner.sh test-2d
```

### 3. Launch Process Details

The experiment runner automatically:
1. **Creates tmux session** with unique timestamp
2. **Sets up environment** (Julia project, paths, logging)
3. **Allocates memory** (50GB for 4D problems, 10GB for 2D)
4. **Starts computation** with proper error handling
5. **Saves session info** for monitoring

**Example Launch Output:**
```
[INFO] Lotka-Volterra 4D Parameter Estimation
[INFO] Samples per parameter: 8, Degree: 10
[INFO] Starting experiment in tmux session: globtim_lv4d_20250903_115955
[INFO] Heap size allocation: 50G
[INFO] Experiment started successfully!
[INFO] To monitor: tmux attach -t globtim_lv4d_20250903_115955
[INFO] Results will be saved to: /home/globaloptim/globtimcore/node_experiments/outputs/globtim_lv4d_20250903_115955
```

## Monitoring Computations

### 1. Check Experiment Status
```bash
# Check if experiments are running
./node_experiments/runners/experiment_runner.sh status

# List all tmux sessions
./node_experiments/runners/experiment_runner.sh list

# View available outputs
./node_experiments/runners/experiment_runner.sh outputs
```

### 2. Attach to Running Experiment
```bash
# Attach to current experiment
./node_experiments/runners/experiment_runner.sh attach

# Or attach to specific session
tmux attach -t globtim_lv4d_20250903_115955

# Detach from session: Ctrl+B then D
```

### 3. Monitor System Resources
```bash
# Check Julia processes
ps aux | grep julia

# Monitor memory usage
htop

# Check disk usage in output directory
du -sh /home/globaloptim/globtimcore/node_experiments/outputs/*
```

### 4. Progress Indicators

#### Phase 1: Parameter Space Sampling
```
Step 1: Sampling parameter space and evaluating objective function...
✓ Generated 4096 parameter samples
  Objective function evaluation range: [0.001234, 156.789]
```

#### Phase 2: Polynomial Approximation (Longest Phase)
```
Step 2: Constructing polynomial approximation of objective function...
  Condition number: 4.52384
  L2 norm (approximation error): 0.00123
✓ Polynomial approximation complete
```

#### Phase 3: Critical Point Detection
```
Step 3: Finding critical points of polynomial approximation...
✓ Polynomial system solved
  Total solutions: 3456
  Real solutions: 127
```

#### Phase 4: Local Optimization
```
Step 4: Local optimization at critical points...
✓ Critical points processed
  Number of critical points: 15
```

### 5. Results Interpretation

#### Successful Completion Indicators
```
Parameter Estimation Results:
  Best objective value: 0.0023
  
Best parameter estimate:
  Estimated: α=1.4923, β=0.9887, γ=0.7456, δ=1.2534
  True:      α=1.5, β=1.0, γ=0.75, δ=1.25
  Distance from true: 0.0234
  
Parameter estimation errors:
  α error: 0.51%
  β error: 1.13%
  γ error: 0.59%
  δ error: 0.27%
```

#### Target Performance Metrics
- **Parameter Recovery:** <5% relative error per parameter
- **Distance from True:** <0.1 for well-conditioned problems
- **Critical Points:** 10-50 points typical for 4D problems
- **Condition Number:** <100 for stable approximation

### 6. Output Files Structure
```
/home/globaloptim/globtimcore/node_experiments/outputs/globtim_lv4d_YYYYMMDD_HHMMSS/
├── output.log              # Computation progress log
├── error.log               # Error messages (should be minimal)
├── approximation_info.json # Polynomial approximation details
├── parameter_estimates.csv # All critical points found
├── parameter_estimates.json # JSON format results
├── synthetic_data.csv      # Generated observation data
├── summary.txt             # Human-readable summary
└── timing_report.txt       # Performance breakdown
```

## Error Handling and Troubleshooting

### Common Issues and Solutions

#### 1. OutOfMemoryError
```
# Symptom: "OutOfMemoryError: Java heap space" or similar
# Solution: Already handled with 50GB heap allocation
# Verification: Check heap size in session startup logs
```

#### 2. Package Loading Errors
```bash
# Verify dependencies
./node_experiments/runners/experiment_runner.sh verify

# If JSON package missing:
julia --project=. -e 'using Pkg; Pkg.add("JSON")'
```

#### 3. Session Terminated Unexpectedly
```bash
# Check for completed sessions
./node_experiments/runners/experiment_runner.sh status

# Check system logs
journalctl --user -u julia
```

#### 4. Path Activation Issues
```
# Error: "Package not found in current path"
# Solution: Ensure Pkg.activate(dirname(dirname(@__DIR__))) in scripts
```

### Recovery Procedures

#### Restart Failed Computation
```bash
# Note the failed session name and parameters
# Relaunch with same configuration
./node_experiments/runners/experiment_runner.sh lotka-volterra-4d 8 10
```

#### Collect Partial Results
```bash
# Even failed computations may have partial results
ls /home/globaloptim/globtimcore/node_experiments/outputs/failed_session_name/
```

## Computation Phases and Timing

### Expected Timeline (4D Lotka-Volterra, Degree 10)

| Phase | Duration | CPU Usage | Description |
|-------|----------|-----------|-------------|
| 1. Sampling | 2-5 minutes | 100% | Generate parameter combinations and evaluate objective |
| 2. Polynomial | 60-120 minutes | 100% | Construct Chebyshev approximation (main bottleneck) |
| 3. Critical Points | 10-30 minutes | 100% | Solve polynomial system with HomotopyContinuation |
| 4. Optimization | 5-10 minutes | 100% | Local refinement of critical points |

**Total Runtime:** 2-4 hours for typical 4D problems

### Performance Scaling
- **Samples:** Linear scaling with sample count
- **Degree:** Exponential scaling with polynomial degree
- **Dimension:** Exponential scaling with parameter space dimension

## Best Practices

### 1. Resource Management
- Use tmux for all long-running computations
- Monitor system resources during execution
- Clean up old output directories periodically

### 2. Validation Workflow
1. **Always start with 2D test** to verify infrastructure
2. **Run low-degree 4D tests** before production runs
3. **Monitor initial phases** to catch issues early

### 3. Result Validation
- Check parameter recovery accuracy against known true values
- Verify condition numbers for approximation quality
- Compare results across different polynomial degrees

### 4. Documentation
- Document experiment parameters and results
- Save configuration for reproducible runs
- Update GitLab issues with progress and outcomes