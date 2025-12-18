# HPC Execution Guide for GlobTim on r04n02

## Quick Start - Running 4D Experiments

### Prerequisites Checklist
- [ ] SSH access to r04n02: `ssh scholten@r04n02`
- [ ] Repository at `/home/globaloptim/globtimcore` is up to date
- [ ] CSV and JSON packages installed: `julia --project=. -e 'using Pkg; Pkg.add(["CSV", "JSON"])'`
- [ ] Scripts have execute permissions: `chmod +x hpc/experiments/*.sh`

### Running a 4D Experiment

```bash
# 1. Connect to r04n02
ssh scholten@r04n02

# 2. Navigate to repository
cd /home/globaloptim/globtimcore

# 3. Pull latest changes
git pull origin main

# 4. Run 4D experiment (samples_per_dim=10, degree=12)
./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12

# 5. Monitor execution
tmux attach -t globtim_4d-model_*
# Detach with Ctrl+B then D
```

## Critical Memory Management

### ⚠️ ALWAYS Use Heap Size Hints for Large Problems

For polynomial approximations with high degree or dimension:

```bash
# Manual execution with heap size
julia --project=. --heap-size-hint=50G your_script.jl

# Automatically handled in robust_experiment_runner.sh
```

### Memory Requirements Table

| Dimensions | Degree | Basis Functions | Memory (10K samples) | Heap Hint |
|------------|--------|-----------------|---------------------|-----------|
| 2          | 12     | 169            | 13.5 MB            | Default   |
| 3          | 12     | 2,197          | 175.8 MB           | Default   |
| 4          | 12     | 28,561         | 2.3 GB             | 50G       |
| 4          | 15     | 65,536         | 5.2 GB             | 100G      |
| 5          | 10     | 161,051        | 12.9 GB            | 100G      |
| 5          | 12     | 371,293        | 29.7 GB            | 200G      |

Formula: `basis_functions = (degree + 1)^dimension`

## tmux-Based Execution Framework

### Why tmux Instead of SLURM
- **Direct execution**: No scheduling delays on single-user r04n02
- **Persistent sessions**: Survives SSH disconnection
- **Interactive monitoring**: Can attach/detach at will
- **Simpler workflow**: No job scripts or queue management

### tmux Commands Reference

```bash
# List all sessions
tmux ls

# Attach to specific session
tmux attach -t globtim_4d-model_20250903_014638

# Detach from session (inside tmux)
Ctrl+B then D

# Kill a session
tmux kill-session -t session_name

# Check current experiment status
./hpc/experiments/robust_experiment_runner.sh status
```

### Session Tracking (New in October 2025)

**Modern Pattern**: Experiments launched with session tracking create `.session_info.json` files that enable:
- **Session-directory linkage**: Session name matches directory name
- **Real-time progress**: Monitor completion percentage
- **Status tracking**: launching → running → completed/failed

```bash
# Check experiment status
jq .status hpc_results/YOUR_EXPERIMENT/.session_info.json

# Monitor progress
jq .progress hpc_results/YOUR_EXPERIMENT/.session_info.json

# Find session from directory name
tmux attach -t "$(jq -r .session_name hpc_results/YOUR_EXPERIMENT/.session_info.json)"
```

**For detailed session tracking usage**, see [CLUSTER_EXPERIMENT_QUICK_START.md](CLUSTER_EXPERIMENT_QUICK_START.md)

## Common Issues and Solutions

### Issue 1: OutOfMemoryError
```
ERROR: LoadError: OutOfMemoryError()
```
**Solution**: Increase heap size in `robust_experiment_runner.sh` or run manually with:
```bash
julia --project=. --heap-size-hint=100G script.jl
```

### Issue 2: Package Not Found
```
ERROR: LoadError: ArgumentError: Package CSV not found
```
**Solution**: Install missing packages:
```bash
julia --project=. -e 'using Pkg; Pkg.add("CSV")'
```

### Issue 3: Wrong Project Activated
```
ERROR: LoadError: Package Globtim not found
```
**Solution**: Fix `Pkg.activate` path in script:
```julia
Pkg.activate(dirname(dirname(@__DIR__)))  # Go up TWO directories
```

### Issue 4: Permission Denied
```
bash: ./script.sh: Permission denied
```
**Solution**: Make script executable:
```bash
chmod +x ./script.sh
```

### Issue 5: Git Sync Issues
Symptoms: Old code running, changes not reflected
**Solution**: Always pull before running:
```bash
git stash  # If local changes exist
git pull origin main
```

## Directory Structure

```
/home/globaloptim/globtimcore/
├── hpc/
│   ├── experiments/
│   │   ├── run_4d_experiment.jl        # Main 4D experiment script
│   │   ├── robust_experiment_runner.sh # tmux wrapper (with heap size)
│   │   └── temp/                       # Temporary scripts (NOT /tmp)
│   ├── monitoring/
│   │   └── tmux_monitor.sh            # Monitor running experiments
│   └── results/
│       └── globtim_4d-model_*/        # Results directories
└── hpc_results/                        # Alternative results location
```

## Results Collection

After experiment completion:

```bash
# Navigate to results directory
cd /home/globaloptim/globtimcore/hpc_results/globtim_4d-model_*

# Check available files
ls -la
# Expected files:
# - critical_points.csv    # DataFrame of critical points
# - critical_points.json   # JSON format for parsing
# - timing_report.txt      # Performance breakdown
# - summary.txt           # Human-readable summary
# - output.log            # Full stdout
# - error.log             # Any errors

# Quick view of results
head critical_points.csv
cat summary.txt
```

## Best Practices

1. **Always check memory requirements** before running high-dimensional problems
2. **Use git stash** to handle local modifications when pulling
3. **Monitor initial output** to ensure correct function is running
4. **Keep experiments in tmux** for persistence
5. **Document parameters** in experiment names
6. **Check error logs** even if experiment appears successful
7. **Never use /tmp** - use project-relative paths

## Monitoring Tools

```bash
# Real-time memory usage
htop -u scholten

# Check available memory
free -h

# Monitor specific tmux session output
tail -f /home/globaloptim/globtimcore/hpc_results/*/output.log

# Watch for completion
watch -n 5 'ls -la /home/globaloptim/globtimcore/hpc_results/*/critical_points.csv'
```

## Advanced Configuration

### Custom Heap Sizes

Edit `robust_experiment_runner.sh` line 62:
```bash
# For very large problems
julia --project=. --heap-size-hint=200G $experiment_script \$LOG_DIR
```

### Multi-threaded Execution

Add to experiment script:
```bash
export JULIA_NUM_THREADS=16
julia --project=. --threads=16 --heap-size-hint=50G script.jl
```

### Debug Mode

For verbose output:
```julia
pol = Constructor(TR, degree, basis=:chebyshev, verbose=true)
```

## Contact and Support

- Repository: https://git.mpi-cbg.de/globaloptim/globtimcore
- Issues: See `docs/hpc/4D_EXPERIMENT_LESSONS_LEARNED.md` for common problems
- Memory calculator: Use formula `(degree+1)^dim * samples * 8 / 10^9` GB