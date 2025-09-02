# Robust HPC Workflow Guide for r04n02

## Overview

Since you're the sole user of r04n02 and don't need SLURM's scheduling capabilities, this guide presents optimized workflows for persistent, robust experiment execution without the overhead of a job scheduler.

## Recommended Approaches

### 1. **tmux (BEST FOR YOUR USE CASE)** ⭐

tmux provides persistent terminal sessions that survive disconnections.

#### Basic Usage:

```bash
# SSH to r04n02
ssh scholten@r04n02
cd /home/scholten/globtim

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

#### Using the Robust Experiment Runner:

```bash
# Start 2D test
./hpc/experiments/robust_experiment_runner.sh 2d-test

# Start 4D model with parameters
./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12

# Check status
./hpc/experiments/robust_experiment_runner.sh status

# Attach to running experiment
./hpc/experiments/robust_experiment_runner.sh attach
```

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

### Complete Example Workflow:

```bash
# 1. SSH to r04n02
ssh scholten@r04n02

# 2. Navigate to repository
cd /home/scholten/globtim

# 3. Start experiment in tmux with logging
tmux new -s exp_4d_$(date +%Y%m%d)
julia --project=. << 'EOF'
    include("hpc/experiments/experiment_manager.jl")
    
    # Your 4D experiment with checkpointing
    manager = ExperimentManager("4d_model", "hpc_results/exp_$(now())")
    
    function run_4d_iteration(i, prev)
        # Your computation
        include("hpc/experiments/config_4d_model.jl")
        return compute_4d_step(i)
    end
    
    run_with_checkpointing(manager, run_4d_iteration, 1000)
EOF

# 4. Detach (Ctrl+B, D) and let it run

# 5. Check progress anytime
tmux attach -t exp_4d_*
# or check logs
tail -f hpc_results/exp_*/checkpoint_summary.txt
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

## Best Practices

1. **Always use tmux/screen** for long-running experiments
2. **Implement checkpointing** for experiments > 1 hour
3. **Log everything** with timestamps
4. **Name sessions descriptively** (e.g., `4d_degree12_$(date +%Y%m%d)`)
5. **Clean up old tmux sessions** regularly: `tmux ls | grep -v attached | cut -d: -f1 | xargs -I {} tmux kill-session -t {}`
6. **Monitor resource usage**: `htop` or `top` in a separate tmux window
7. **Set up email notifications** for completion (optional):

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