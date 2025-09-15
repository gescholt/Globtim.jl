# HPC Monitoring & Result Collection Guide

This guide documents the comprehensive monitoring and result collection system for HPC experiments running on the r04n02 compute node.

## 📋 Overview

The monitoring system provides:
- Real-time tracking of tmux-based experiments
- System resource monitoring with alerts
- Automated result collection and analysis
- Integration with HPC Resource Monitor Hook system
- Dashboard capabilities for comprehensive oversight

## 🔧 Primary Monitoring Tools

### 1. Enhanced Tmux Session Monitor

**Script**: `tools/hpc/monitoring/tmux_monitor.sh`

The primary tool for tracking experiments running in tmux sessions on r04n02.

#### Basic Usage

```bash
# Monitor all GlobTim sessions (default)
tools/hpc/monitoring/tmux_monitor.sh --all

# Monitor specific experiment session
tools/hpc/monitoring/tmux_monitor.sh globtim_4d_20250915_143022

# Start integrated monitoring dashboard
tools/hpc/monitoring/tmux_monitor.sh --dashboard

# List all active sessions
tools/hpc/monitoring/tmux_monitor.sh --list

# Clean up stale sessions
tools/hpc/monitoring/tmux_monitor.sh --cleanup-stale
```

#### Features

- **Real-time Session Health**: Shows session status, age, and activity
- **Resource Integration**: CPU/memory usage with color-coded alerts
- **Live Session Content**: Displays last 10 lines from session output
- **Anomaly Detection**: Flags sessions with warnings or errors
- **Automated Cleanup**: Identifies and removes stale sessions

#### Example Output

```
═══════════════════════════════════════════════════════════════
               Enhanced Tmux Session Monitor
        Integrated HPC Resource Monitoring for r04n02
═══════════════════════════════════════════════════════════════
Timestamp: 2025-09-15 14:30:22

🧪 Active GlobTim Sessions:
────────────────────────────────────────────────
   🟢 globtim_4d_20250915_143022 (healthy, 2.3h)
   🟡 globtim_test_20250915_120000 (stale, 8.1h)

💻 System Overview:
────────────────────────────────────────────────
   System Health: 🟢 HEALTHY
   Active Sessions: 2
   Running Experiments: 1
```

### 2. HPC Resource Monitor Hook

**Script**: `~/.claude/hooks/hpc-resource-monitor.sh`

Automatically integrated with tmux monitoring for system resource tracking.

```bash
# Check resource status
~/.claude/hooks/hpc-resource-monitor.sh status

# Monitor specific experiment
~/.claude/hooks/hpc-resource-monitor.sh monitor experiment_name

# Check for resource alerts
~/.claude/hooks/hpc-resource-monitor.sh check_resources
```

## 📥 Result Collection System

### 1. HPC Result Collector

**Script**: `hpc/monitoring/collect_results.sh`

Legacy SLURM-based collection (now archived) - patterns apply to direct access.

#### Standard Result Locations

Results are typically saved to:
- `/home/scholten/globtim/hpc_results/experiment_name_timestamp/`
- `/home/scholten/globtim/lotka_volterra_4d_timestamp/`
- Local collected results: `./collected_results/experiment_name/`

#### Key Result Files

```
experiment_directory/
├── results.json              # Main computation results
├── critical_points.csv       # Critical points found
├── approximation_data.json   # Polynomial approximation info
├── timing_summary.txt        # Performance metrics
├── l2_norm_analysis.txt      # Quality assessment
├── monitoring_summary.json   # Resource usage
└── experiment_log.txt        # Execution log
```

### 2. Manual Result Collection

#### From HPC Node (r04n02)

```bash
# Connect to compute node
ssh scholten@r04n02

# Navigate to results
cd /home/scholten/globtim/hpc_results

# List recent experiments
ls -lt | head -10

# View specific experiment results
cd experiment_name_timestamp
ls -la
cat results.json
```

#### Download Results Locally

```bash
# Copy specific experiment results
scp -r scholten@r04n02:/home/scholten/globtim/hpc_results/experiment_name_timestamp/ ./local_results/

# Copy all recent results
rsync -av scholten@r04n02:/home/scholten/globtim/hpc_results/ ./hpc_results/
```

## 📊 Result Analysis Tools

### 1. Collection Summary Analysis

**Script**: `analyze_collection_summary.jl`

```julia
# Analyze collected experiment results
julia --project=. analyze_collection_summary.jl

# Or programmatically
using Globtim
include("analyze_collection_summary.jl")
```

### 2. Comprehensive Analysis

**Script**: `docs/hpc/analysis/scripts/comprehensive_collection_analysis.jl`

```julia
# Multi-experiment analysis with optimization recommendations
include("docs/hpc/analysis/scripts/comprehensive_collection_analysis.jl")
generate_optimization_report("hpc_results/collection_summary.json")
```

## 🚀 Workflow Examples

### Complete Experiment Monitoring Workflow

```bash
# 1. Deploy and start experiment (using robust runner)
ssh scholten@r04n02
cd /home/scholten/globtim
./hpc/scripts/robust_experiment_runner.sh tests/validation/lotka_volterra_4d_minimal.jl

# 2. Monitor experiment progress (from local machine)
tools/hpc/monitoring/tmux_monitor.sh globtim_4d_$(date +%Y%m%d)

# 3. Check for completion
tools/hpc/monitoring/tmux_monitor.sh --list

# 4. Collect results
scp -r scholten@r04n02:/home/scholten/globtim/hpc_results/latest_experiment/ ./results/

# 5. Analyze results locally
julia --project=. analyze_collection_summary.jl
```

### Dashboard Monitoring

```bash
# Start comprehensive monitoring dashboard
tools/hpc/monitoring/tmux_monitor.sh --dashboard

# This provides:
# - Real-time session health monitoring
# - Resource usage tracking
# - Experiment progress analysis
# - Automated anomaly detection
```

## ⚙️ Configuration

### Environment Variables

```bash
# Set monitoring refresh interval (seconds)
export HPC_MONITOR_INTERVAL=30

# Set stale session threshold (hours)
export STALE_THRESHOLD_HOURS=24

# Enable verbose logging
export VERBOSE=true

# Set GlobTim directory path
export GLOBTIM_DIR=/home/scholten/globtim
```

### Log Files

Monitoring logs are stored in:
- `hpc/logs/tmux_monitoring/tmux_monitor.log` - Session monitoring events
- `tools/hpc/monitoring/logs/resource_monitor.log` - Resource monitoring data
- `tools/hpc/hooks/logs/hook_resource_monitor_*.log` - Hook execution logs

## 🔍 Troubleshooting

### Common Issues

1. **Session Not Found**
   ```bash
   # Check if tmux is running on r04n02
   ssh scholten@r04n02 'tmux ls'

   # Verify session naming pattern
   tools/hpc/monitoring/tmux_monitor.sh --list
   ```

2. **Resource Hook Unavailable**
   ```bash
   # Check hook installation
   ls -la ~/.claude/hooks/hpc-resource-monitor.sh

   # Test hook functionality
   ~/.claude/hooks/hpc-resource-monitor.sh status
   ```

3. **No Results Found**
   ```bash
   # Check standard result directories
   ssh scholten@r04n02 'find /home/scholten/globtim -name "*results*" -type d -mtime -1'

   # Check experiment logs
   ssh scholten@r04n02 'ls -lt /home/scholten/globtim/hpc_results/'
   ```

### Performance Optimization

- Use `--dashboard` mode for minimal resource usage during monitoring
- Set longer refresh intervals for background monitoring
- Clean up stale sessions regularly with `--cleanup-stale`
- Use resource alerts to detect performance issues early

## 🔗 Integration Points

The monitoring system integrates with:
- **GitLab Issues**: Automated updates via project-task-updater agent
- **Post-Processing Pipeline**: Automatic analysis of completed experiments
- **Hook Orchestrator**: Strategic integration with experiment lifecycle
- **Security Framework**: SSH security validation for all HPC connections

This comprehensive system ensures reliable tracking and collection of HPC computational results while providing real-time insight into experiment progress and system health.