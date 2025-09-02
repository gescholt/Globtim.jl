# Tmux-Based HPC Execution Framework Migration

## Overview
**Date Implemented:** September 2, 2025  
**Status:** ✅ PRODUCTION READY

This document summarizes the migration from SLURM-based job scheduling to a tmux-based persistent execution framework, optimized for single-user access to the r04n02 compute node.

## Key Changes

### Before: SLURM-Based Execution
- Required job submission through falcon head node
- Added scheduling overhead for single-user node
- Complex SBATCH directives and resource allocation
- Bundle extraction and environment setup complexity
- Job ID tracking and status monitoring via sacct/squeue

### After: Tmux-Based Execution
- Direct execution on r04n02 compute node
- No scheduling overhead - immediate execution
- Persistent sessions survive SSH disconnection
- Simple session management with tmux commands
- Integrated checkpointing for recovery
- Real-time monitoring and attachment

## Implementation Components

### 1. Core Infrastructure
- **Location:** `/home/scholten/globtim` (permanent storage, NOT /tmp)
- **Julia:** `julia` (v1.11.6 via juliaup, no module system)
- **Framework:** tmux for session persistence
- **Automation:** `robust_experiment_runner.sh` for session management

### 2. Key Scripts Created

#### `hpc/experiments/robust_experiment_runner.sh`
- Automated tmux session creation and management
- Handles experiment naming and timestamps
- Provides status checking and attachment commands
- Supports both 2D test and 4D model configurations

#### `hpc/experiments/experiment_manager.jl`
- Julia-based checkpointing system
- Automatic state saving at configurable intervals
- Recovery from last checkpoint on restart
- Progress tracking and logging

#### `hpc/monitoring/tmux_monitor.sh`
- Real-time monitoring dashboard
- Tracks active tmux sessions
- Shows Julia process status
- Monitors resource usage and output files

## Usage Workflow

### Quick Start
```bash
# Connect to r04n02
ssh scholten@r04n02
cd /home/scholten/globtim

# Julia is in PATH (via juliaup, no module needed)

# Start 4D model experiment
./hpc/experiments/robust_experiment_runner.sh 4d-model 10 12

# Monitor progress
./hpc/monitoring/tmux_monitor.sh

# Attach to session
tmux attach -t globtim_*
```

### Manual Tmux Usage
```bash
# Start new session
tmux new -s my_experiment

# Run Julia experiment
julia --project=. hpc/experiments/run_4d_experiment.jl

# Detach (Ctrl+B, then D)
# Reattach later
tmux attach -t my_experiment
```

## Advantages

1. **Immediate Execution**: No waiting for job scheduling
2. **Interactive Access**: Attach/detach for live monitoring
3. **Simplified Configuration**: No SBATCH directives needed
4. **Better Debugging**: Direct access to running experiments
5. **Resource Efficiency**: No scheduler overhead
6. **Persistence**: Survives network disconnections

## Migration Impact

### Documentation Updated
- ✅ `CLAUDE.md` - Updated with Screen framework details
- ✅ `docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md` - Reflects current infrastructure
- ✅ `docs/hpc/ROBUST_WORKFLOW_GUIDE.md` - Complete Screen workflow guide
- ✅ `docs/project-management/issues/HPC_4D_MODEL_WORKFLOW_ISSUE.md` - Updated for Screen approach
- ✅ `.claude/agents/hpc-cluster-operator.md` - Agent updated for Screen operations
- ✅ `docs/project-management/PHASE1_IMPLEMENTATION_SUMMARY.md` - References updated

### Deprecated Components
- SLURM job submission scripts (kept for reference only)
- Bundle-based deployment workflows
- Complex environment variable configurations
- Job ID tracking mechanisms

## Best Practices

1. **Julia is in PATH**: No module loading needed (using juliaup)
2. **Use descriptive session names**: Include experiment type and date
3. **Implement checkpointing**: For experiments longer than 1 hour
4. **Monitor resources**: Use `htop` in separate tmux window
5. **Clean up old sessions**: `tmux kill-server` removes all sessions
6. **Log everything**: Redirect output to timestamped log files

## Fallback Options

While tmux is the primary method, alternatives remain available:
- **Screen**: Similar concept (but not installed on r04n02)
- **Nohup**: Simple background execution (no interactivity)
- **SLURM**: Still available via falcon if multi-user scheduling needed

## Conclusion

The tmux-based framework provides an optimal solution for single-user HPC operations on r04n02, eliminating unnecessary complexity while maintaining all required functionality for persistent, monitored experiment execution.

## References
- [Tmux Manual](https://man.openbsd.org/tmux)
- `docs/hpc/ROBUST_WORKFLOW_GUIDE.md` - Detailed usage guide
- `hpc/experiments/README.md` - Script documentation