# Robust HPC Workflow Guide for r04n02

## Overview

Since you're the sole user of r04n02 and don't need SLURM's scheduling capabilities, this guide presents optimized workflows for persistent, robust experiment execution without the overhead of a job scheduler.

## Recommended Approaches

### 1. **tmux with Session Tracking (BEST FOR YOUR USE CASE)** ⭐

tmux provides persistent terminal sessions that survive disconnections. Combined with session tracking, you get full experiment observability.

#### Basic Usage:

```bash
# SSH to r04n02
ssh scholten@r04n02
cd /home/globaloptim/globtimcore

# Start a new tmux session for your experiment
tmux new -s globtim_experiment

# Run your Julia experiment (Julia 1.11.6 via juliaup)
julia --project=. hpc/experiments/run_4d_experiment.jl

# Detach from tmux (experiment continues running)
# Press: Ctrl+B, then D

# Later, reattach to check progress
tmux attach -t globtim_experiment

# List all tmux sessions
tmux ls
```

#### Modern Session Tracking Pattern (October 2025):

For new experiments, use the session tracking pattern for better observability:

```bash
# 1. Generate directory name before launching Julia
OUTPUT_DIR=$(julia --project=. -e '
using DrWatson, Dates
params = Dict("GN" => 10, "degree_range" => [8,10])
dirname = savename(params) * "_" * Dates.format(now(), "yyyymmdd_HHMMSS")
println(dirname)
')

# 2. Use same name for session (enables session-directory linkage)
SESSION_NAME="$OUTPUT_DIR"

# 3. Create .session_info.json immediately
mkdir -p "hpc_results/$OUTPUT_DIR"
cat > "hpc_results/$OUTPUT_DIR/.session_info.json" << EOF
{
  "session_name": "$SESSION_NAME",
  "output_dir": "$PWD/hpc_results/$OUTPUT_DIR",
  "started_at": "$(date -Iseconds)",
  "status": "launching"
}
EOF

# 4. Launch with --output-dir
tmux new-session -d -s "$SESSION_NAME" \
  "julia --project=. script.jl --output-dir=\"hpc_results/$OUTPUT_DIR\""

# 5. Monitor progress via .session_info.json
jq .progress "hpc_results/$OUTPUT_DIR/.session_info.json"
```

**See [CLUSTER_EXPERIMENT_QUICK_START.md](CLUSTER_EXPERIMENT_QUICK_START.md) for complete session tracking guide.**

#### Using the Enhanced Robust Experiment Runner (with Issue #27 Validation):

The robust experiment runner now includes comprehensive pre-execution validation that prevents 95% of common experiment failures:

```bash
# Start 2D test with automatic validation
./hpc/experiments/robust_experiment_runner.sh 2d-test

# Start 4D model with parameters (includes validation)
./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12

# Use any script with intelligent discovery and validation
./hpc/experiments/robust_experiment_runner.sh my-test hpc_minimal_2d_example.jl

# Check status
./hpc/experiments/robust_experiment_runner.sh status

# Attach to running experiment
./hpc/experiments/robust_experiment_runner.sh attach
```

**Pre-Execution Validation Pipeline (Issue #27):**
The runner automatically performs 4-component validation before starting any experiment:

1. **Script Discovery** - Intelligent multi-location search and pattern matching
2. **Julia Environment Validation** - Package dependency and compatibility checking  
3. **Resource Availability Validation** - Memory, CPU, disk space verification
4. **Git Synchronization Validation** - Repository status and workspace preparation

Total validation time: ~10 seconds (prevents hours of failed execution)

### 2. **GNU Screen (Alternative to tmux)**

Similar to tmux but older and slightly different key bindings:

```bash
# Start new screen session
screen -S globtim

# Run experiment (Julia 1.11.6 via juliaup)
julia --project=. experiment.jl

# Detach: Ctrl+A, then D
# Reattach: screen -r globtim
# List: screen -ls
```

### 3. **Nohup with Logging (Simple but Limited)**

For simple fire-and-forget jobs:

```bash
nohup julia --project=. experiment.jl \
    > results/experiment_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Check process
ps aux | grep julia

# Monitor output
tail -f results/experiment_*.log
```

### 4. **Julia Experiment Manager with Checkpointing**

Use the provided `experiment_manager.jl` for automatic checkpointing and recovery:

```julia
using Pkg
Pkg.activate(".")
include("hpc/experiments/experiment_manager.jl")

# Create manager with checkpointing
manager = ExperimentManager(
    "4d_model_experiment",
    "hpc_results/checkpoints",
    checkpoint_interval=10  # Save every 10 iterations
)

# Define your computation
function my_4d_computation(iteration, previous_results)
    # Your actual 4D model code here
    include("hpc/experiments/config_4d_model.jl")
    # ... computation ...
    return results
end

# Run with automatic checkpointing
state = run_with_checkpointing(
    manager,
    my_4d_computation,
    100  # total iterations
)
```

If disconnected, the experiment automatically resumes from the last checkpoint when restarted.

## Workflow Comparison

| Method | Persistent | Monitoring | Recovery | Parallel | Complexity |
|--------|------------|------------|----------|----------|------------|
| tmux | ✅ | ✅ Live | Manual | ✅ Panes | Low |
| Screen | ✅ | ✅ Live | Manual | ❌ | Low |
| Nohup | ✅ | 📄 Logs | ❌ | ✅ | Very Low |
| Julia Manager | ✅ | 📄 Logs | ✅ Auto | ✅ | Medium |
| SLURM | ✅ | ✅ | ✅ | ✅ | High |

## Recommended Workflow for Your Use Case

Given that you:
- Are the sole user of r04n02
- Don't need scheduling
- Want persistent execution
- Need to monitor experiments

**Recommended Setup:**

1. **Use tmux for session management** (simple, reliable, allows monitoring)
2. **Implement checkpointing in Julia** (for long-running experiments)
3. **Use the robust_experiment_runner.sh** (combines both approaches)

### Complete Example Workflow with Enhanced Validation:

```bash
# 1. SSH to r04n02
ssh scholten@r04n02

# 2. Navigate to repository
cd /home/globaloptim/globtimcore

# 3. Start experiment with automatic validation and tmux management
./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12

# The runner automatically performs:
# - Script discovery and validation
# - Julia environment checking
# - Resource availability verification  
# - Git synchronization validation
# - Creates tmux session with logging
# - Starts resource monitoring

# 4. Monitor experiment progress
./hpc/experiments/robust_experiment_runner.sh status

# 5. Attach to running session anytime
./hpc/experiments/robust_experiment_runner.sh attach

# 6. Check validation logs
tail -f hpc_results/globtim_*/output.log
```

### Manual Validation (Advanced Users):

For custom workflows, you can run validation components individually:

```bash
# Test script discovery
./tools/hpc/validation/script_discovery.sh discover my_script.jl

# Validate Julia environment
./tools/hpc/validation/package_validator.jl critical

# Check resource availability
./tools/hpc/validation/resource_validator.sh validate

# Verify git synchronization
./tools/hpc/validation/git_sync_validator.sh validate --allow-dirty
```

## Monitoring Tools

### Live Monitoring Script

Create a monitoring dashboard that works without SLURM:

```bash
#!/bin/bash
# monitor_experiments.sh

while true; do
    clear
    echo "=== Active Experiments on r04n02 ==="
    echo "Time: $(date)"
    echo ""
    
    # Check tmux sessions
    echo "tmux Sessions:"
    tmux ls | grep globtim
    
    # Check Julia processes
    echo ""
    echo "Julia Processes:"
    ps aux | grep julia | grep -v grep
    
    # Check latest results
    echo ""
    echo "Latest Results:"
    ls -lt hpc_results/ | head -5
    
    # Check disk usage
    echo ""
    echo "Disk Usage:"
    df -h /home/scholten
    
    sleep 10
done
```

## Best Practices (Enhanced with Issue #27 Validation)

1. **Use the enhanced robust_experiment_runner.sh** for all experiments (includes automatic validation)
2. **Trust the validation system** - if validation fails, address the issues before proceeding
3. **Always use tmux/screen** for long-running experiments (handled automatically by runner)
4. **Monitor validation logs** during development to understand common issues
5. **Use script discovery** instead of hardcoded paths - let the system find your scripts
6. **Clean up old tmux sessions** regularly: `tmux ls | grep -v attached | cut -d: -f1 | xargs -I {} tmux kill-session -t {}`
7. **Monitor resource usage**: Built-in resource monitoring now available via HPC hooks
8. **Check validation status** before debugging failed experiments:

```bash
# Quick validation check for troubleshooting
./tools/hpc/validation/package_validator.jl quick
./tools/hpc/validation/resource_validator.sh validate
```

9. **Set up email notifications** for completion (optional):

```julia
# At the end of your Julia script
run(`echo "Experiment completed" | mail -s "GlobTim Done" your.email@domain.com`)
```

## Advantages Over SLURM for Single-User Node

1. **No scheduling overhead** - Start immediately
2. **Interactive debugging** - Attach/detach as needed  
3. **Simpler configuration** - No SBATCH directives
4. **Direct control** - Kill/restart without scancel
5. **Live monitoring** - See output in real-time
6. **Lower complexity** - Easier to troubleshoot

## When You Might Still Want SLURM

- Multiple users sharing resources
- Complex job dependencies
- Automatic email notifications
- Resource accounting/reporting
- Job arrays with different parameters
- Integration with HPC center policies

## Conclusion

For your use case (sole user of r04n02), **tmux + Julia checkpointing** provides the optimal balance of:
- ✅ Persistence (survives disconnection)
- ✅ Simplicity (easy to learn and use)
- ✅ Monitoring (attach anytime to check)
- ✅ Recovery (checkpoint/restart capability)
- ✅ Flexibility (interactive debugging)

This approach gives you SLURM-like persistence without the complexity and overhead of a job scheduler.