# LV4D Domain Sweep Campaign 2025

## Campaign Overview

Extended domain size exploration for 4D Lotka-Volterra parameter recovery with precision mode comparison:

- **Samples per dimension (GN)**: 16
- **Degree range**: 4-12 (9 degrees)
- **Domain ranges**: ±0.4, ±0.8, ±1.2, ±1.6 (larger domains vs previous ±0.05-0.2)
- **Precision modes**: Float64, Adaptive
- **Total experiments**: 8 (4 domains × 2 precisions)
- **Total computations**: 72 (8 experiments × 9 degrees)
- **Campaign objective**: Test robustness and scaling with larger parameter search domains

## Directory Structure

```
experiments/lv4d_campaign_2025/
├── experiment_manifest.json      # Campaign configuration and tracking
├── launch_lv4d_experiment.jl    # Individual experiment launcher
├── launch_campaign.sh            # Batch launcher for all experiments
├── monitor_campaign.sh           # Real-time monitoring dashboard
├── collect_campaign_results.jl  # Results aggregation and analysis
├── tracking/                     # Experiment logs and batch tracking
│   ├── batch_*.json             # Batch launch records
│   └── lv4d_*.log               # Individual experiment logs
└── results/                      # Aggregated campaign results
    ├── all_results.csv          # Detailed computation data
    └── campaign_summary.json    # Campaign statistics

hpc_results/
└── lv4d_{precision}_{domain}_GN16_{timestamp}/
    ├── experiment_params.json    # Experiment configuration
    ├── critical_points_deg_*.csv # Results per degree
    └── results_summary.json      # Experiment summary
```

## Quick Start

### 1. Launch Experiments

```bash
# Launch all experiments (8 total)
./experiments/lv4d_campaign_2025/launch_campaign.sh

# Or launch specific batch
./experiments/lv4d_campaign_2025/launch_campaign.sh float64   # Float64 only (4 experiments)
./experiments/lv4d_campaign_2025/launch_campaign.sh adaptive  # Adaptive only (4 experiments)
```

This will:
- Launch tmux sessions for selected experiments
- Each session runs one experiment configuration
- Sessions are named: `lv4d_float64_04`, `lv4d_adaptive_12`, etc.

### 2. Monitor Progress

```bash
./experiments/lv4d_campaign_2025/monitor_campaign.sh
```

Shows:
- Active tmux sessions
- Progress for each experiment (degrees completed)
- Overall campaign statistics
- Real-time status updates

### 3. Collect Results

After experiments complete:

```bash
julia --project=. experiments/lv4d_campaign_2025/collect_campaign_results.jl
```

Generates:
- Aggregated results CSV
- Campaign summary with statistics
- Performance comparisons by precision/domain/degree

## Experiment Naming Convention

```
lv4d_{precision}_{domain}_GN16_{timestamp}

Examples:
- lv4d_float64_0.4_GN16_20251004_143000
- lv4d_adaptive_1.2_GN16_20251004_143100
```

## Session Management

### View Active Sessions
```bash
tmux ls | grep lv4d_
```

### Attach to Session
```bash
tmux attach -t lv4d_float64_04   # Float64, domain ±0.4
tmux attach -t lv4d_adaptive_16  # Adaptive, domain ±1.6
```

### Kill Session
```bash
tmux kill-session -t lv4d_float64_04
```

### View Logs
```bash
# Real-time log monitoring
tail -f experiments/lv4d_campaign_2025/tracking/lv4d_float64_04_*.log

# All logs
ls experiments/lv4d_campaign_2025/tracking/*.log
```

## Recovery and Resumption

If an experiment fails:

1. Check the log for the error:
```bash
tail -100 experiments/lv4d_campaign_2025/tracking/lv4d_{precision}_{domain}_*.log
```

2. Relaunch individual experiment:
```bash
cd /home/scholten/globtimcore
julia --project=. experiments/lv4d_campaign_2025/launch_lv4d_experiment.jl 0.8 float64
```

## Expected Outcomes

### Per Experiment
- Runtime: ~15-30 minutes (9 degrees × 100-200s each)
- Output size: ~10-50 MB
- Memory usage: ~8-16 GB peak

### Campaign Total
- Total runtime: ~2-4 hours (8 parallel experiments)
- Total output: ~100-400 MB
- Key metrics: Computation time vs precision/domain/degree

## Analysis Insights

The campaign will provide:
1. **Precision comparison**: Float64 vs Adaptive performance/accuracy
2. **Domain sensitivity**: How larger domain sizes affect solution quality and robustness
3. **Degree optimization**: Optimal polynomial degree for 4D problems with extended domains
4. **Scaling analysis**: GN=16 performance characteristics across domain sizes 0.4-1.6

## Comparison to Previous Campaign

This campaign extends the previous campaign (domains 0.05-0.2) to test robustness:
- **Previous domains**: ±0.05, ±0.1, ±0.15, ±0.2 (narrow search regions)
- **Current domains**: ±0.4, ±0.8, ±1.2, ±1.6 (wider search regions)
- **Objective**: Assess how polynomial approximation quality and critical point finding scale with domain size

## Troubleshooting

### Out of Memory
- Reduce heap size hint in launch script
- Run fewer parallel experiments

### Tmux Session Dies
- Check system logs: `dmesg | tail`
- Review experiment log for errors

### Package Loading Issues
- Ensure project activated: `julia --project=.`
- Update packages if needed: `using Pkg; Pkg.instantiate()`

## Post-Campaign Analysis

Use the standard collection pipeline for detailed analysis:

```bash
# Enhanced error categorization and analysis
julia --project=. collect_cluster_experiments.jl
```

This integrates with the existing post-processing infrastructure for:
- L2 norm quality metrics
- Critical point distance analysis
- Error categorization
- Performance benchmarking