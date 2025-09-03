# SLURM Workflow Guide for GlobTim HPC Experiments

**Created:** September 2, 2025  
**Status:** ⚠️ ARCHIVED - SLURM workflow superseded by tmux-based execution  
**Migration Date:** September 3, 2025  
**Current Solution:** See `COMPUTATION_PROCEDURES.md` for tmux-based workflow

## ⚠️ MIGRATION NOTICE

**This SLURM workflow has been superseded by a direct tmux-based execution framework.**

**New Documentation:** `COMPUTATION_PROCEDURES.md`  
**Reason for Change:** Single-user compute node access eliminates need for job scheduling  
**Benefits:** Simpler workflow, immediate execution, better monitoring

## Overview (HISTORICAL)

This guide documents the complete workflow for running GlobTim experiments on the HPC cluster using SLURM job submission. The workflow has been validated with both 2D test cases and 4D production experiments.

## Quick Start

### 1. Connect to the Compute Node
```bash
ssh scholten@r04n02
```

### 2. Run a Test Job (2D Deuflhard)
```bash
cd /tmp/globtim
sbatch hpc/jobs/submission/test_2d_deuflhard.slurm
```

### 3. Run a 4D Model Experiment
```bash
# Basic submission with defaults (10 samples per dimension)
sbatch hpc/jobs/submission/run_4d_model.slurm

# Custom parameters
sbatch --export=SAMPLES_PER_DIM=15,DEGREE=16 hpc/jobs/submission/run_4d_model.slurm
```

### 4. Monitor and Collect Results
```bash
# Check job status
./hpc/monitoring/collect_results.sh check <job_id>

# Monitor all running jobs
./hpc/monitoring/collect_results.sh monitor

# Collect results from completed job
./hpc/monitoring/collect_results.sh collect <job_id>
```

## Workflow Components

### Test Scripts

#### 2D Deuflhard Test (`test_2d_deuflhard.slurm`)
- **Purpose:** Validate SLURM submission and GlobTim functionality
- **Runtime:** ~30 minutes
- **Memory:** 8GB
- **Output:** Comparison of Chebyshev and Legendre bases
- **Use Case:** Initial workflow validation before running expensive 4D experiments

#### 4D Model Experiment (`run_4d_model.slurm`)
- **Purpose:** Production polynomial approximation experiments
- **Runtime:** 2 hours (configurable)
- **Memory:** 32GB
- **Features:**
  - Dense vs sparse polynomial comparison
  - Conditioning number tracking
  - Comprehensive timing analysis
  - Configurable parameters via environment variables

### Julia Scripts

#### `hpc/experiments/test_2d_deuflhard.jl`
- Standalone 2D test implementation
- Minimal dependencies for reliability
- Outputs: Critical points, conditioning info, timing reports

#### `hpc/experiments/config_4d_model.jl`
- Configurable 4D experiment framework
- Supports both dense and sparse approximants
- Comprehensive result comparison and analysis

### Monitoring Tools

#### `hpc/monitoring/collect_results.sh`
Commands:
- `check <job_id>`: Check SLURM job status
- `collect <job_id>`: Retrieve and display results
- `monitor`: Show all running GlobTim jobs
- `analyze [dir]`: Compare results across experiments

## Parameter Configuration

### 4D Model Parameters

```bash
# Submit with custom parameters
sbatch --export=SAMPLES_PER_DIM=20,DEGREE=18,BASIS=legendre run_4d_model.slurm
```

Configurable parameters:
- `SAMPLES_PER_DIM`: Samples per dimension (default: 10)
- `DEGREE`: Polynomial degree (default: 12)
- `BASIS`: chebyshev or legendre (default: chebyshev)

### Resource Allocation

```bash
# Modify SLURM resources
sbatch --time=04:00:00 --mem=64G --cpus-per-task=16 run_4d_model.slurm
```

## Output Structure

### Result Files
```
/tmp/globtim_results/4d_exp_<timestamp>_job<id>/
├── job_config.txt          # Job configuration and parameters
├── conditioning_info.txt   # Matrix conditioning numbers
├── comparison_4d.txt       # Dense vs sparse comparison
├── timing_4d.txt          # Detailed timing breakdown
├── chebyshev_results.txt  # Basis-specific results (2D test)
└── summary.json           # Machine-readable summary
```

### Key Metrics Tracked
- Number of critical points (dense vs sparse)
- Vandermonde matrix condition number
- L2 approximation error norm
- Sparsity percentage
- Computation time per phase
- Memory usage

## Troubleshooting

### Common Issues

#### 1. Job Fails Immediately
```bash
# Check error log
cat /tmp/globtim_<job_id>/slurm_<job_id>.err

# Common causes:
# - Julia module not loaded
# - Git repository access issues
# - Missing dependencies
```

#### 2. Out of Memory
```bash
# Reduce samples or increase memory
sbatch --mem=64G --export=SAMPLES_PER_DIM=8 run_4d_model.slurm
```

#### 3. Results Not Found
```bash
# Check multiple locations
ls /tmp/globtim_results/
ls /tmp/globtim_<job_id>/
ls /home/scholten/globtim_results/
```

### Debug Mode

To keep working directory for debugging:
1. Comment out cleanup in SLURM script:
   ```bash
   # rm -rf $WORKDIR  # Comment this line
   ```
2. Access working directory:
   ```bash
   cd /tmp/globtim_<job_id>
   ```

## Best Practices

### 1. Start Small
- Begin with 2D test case
- Use small sample sizes (5-10 per dimension) initially
- Gradually increase complexity

### 2. Monitor Resources
```bash
# Check job efficiency after completion
sacct -j <job_id> --format=JobID,Elapsed,MaxRSS,CPUTime,CPUEfficiency
```

### 3. Batch Experiments
```bash
# Submit multiple parameter sweeps
for samples in 5 10 15 20; do
    sbatch --export=SAMPLES_PER_DIM=$samples run_4d_model.slurm
    sleep 5  # Avoid overwhelming scheduler
done
```

### 4. Archive Important Results
```bash
# Results in /tmp are temporary
# Copy important results to home or project directory
cp -r /tmp/globtim_results/important_exp/ ~/globtim_archive/
```

## Validation Checklist

### Phase 1: Infrastructure Validation ✅
- [x] SLURM job submission working
- [x] Julia environment loading correctly
- [x] GlobTim package accessible
- [x] Output collection functional

### Phase 2: 2D Test Validation ✅
- [x] Deuflhard function computed correctly
- [x] Critical points identified
- [x] Conditioning numbers tracked
- [x] Results saved and retrievable

### Phase 3: 4D Model Setup ✅
- [x] Parameter configuration system
- [x] Dense polynomial computation
- [x] Sparse approximant generation
- [x] Comparison framework operational

### Phase 4: Production Ready ✅
- [x] Monitoring tools functional
- [x] Result analysis automated
- [x] Documentation complete
- [x] Workflow validated end-to-end

## Next Steps

1. **Parameter Sweep Studies**
   - Systematic exploration of sample density impact
   - Degree optimization for different problem sizes
   - Sparsification threshold analysis

2. **Performance Optimization**
   - Profile memory usage patterns
   - Optimize parallel computation
   - Investigate GPU acceleration options

3. **Advanced Experiments**
   - Multi-parameter model comparisons
   - Adaptive sampling strategies
   - Error-driven refinement methods

## References

- Main Issue: `docs/project-management/issues/HPC_4D_MODEL_WORKFLOW_ISSUE.md`
- HPC Infrastructure: `docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md`
- 4D Model Source: `experiments/week7/4D_model.jl`
- Deuflhard Notebook: `Examples/Notebooks/Deuflhard.ipynb`

---

**Status:** The SLURM workflow is fully operational and validated for both test cases and production 4D experiments. All components have been tested and documented for reliable HPC deployment.