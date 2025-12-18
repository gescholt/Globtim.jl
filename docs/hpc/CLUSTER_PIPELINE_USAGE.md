# Cluster Pipeline Usage Guide

## Overview

Complete guide for using the GlobTim cluster experiment collection and analysis pipeline. This unified system consolidates all cluster operations into a single, defensive workflow.

## Prerequisites

1. **HPC Access**: SSH access to r04n02 cluster node
2. **Local Environment**: Julia 1.10+ with GlobTim project activated
3. **GitLab Integration**: Enhanced GitLab API tools configured (optional)

## Quick Start

### 1. Collect and Analyze Cluster Experiments

```bash
# Single command to collect all available experiments
julia --project=. collect_cluster_experiments.jl
```

**What this does**:
- Discovers all experiment directories on HPC cluster
- Downloads results, CSV files, and metadata
- Performs comprehensive analysis with error categorization
- Generates detailed reports and summaries
- Handles missing files gracefully with defensive boundaries

### 2. Expected Output

```
🚀 Starting cluster experiment collection and analysis...
📂 Found 4 experiment directories
📥 Downloading experiment results...
   ✅ Downloaded results_summary.json for minimal_4d_lv_test_0.1_20250925_103908
   ✅ Downloaded CSV files for minimal_4d_lv_test_0.1_20250925_103908
📊 Successfully downloaded 4 experiment results

📈 Analyzing cluster experiment results...
   📊 minimal_4d_lv_test_0.1_20250925_103908: 2/2 successful (100.0%)

📋 Generating statistics report...
================================================================================
CLUSTER EXPERIMENT ANALYSIS REPORT
Generated: 2025-09-27T11:30:21.787
================================================================================

📊 OVERALL STATISTICS
   Total computations: 8
   Successful computations: 8
   Overall success rate: 100.0%

💾 Exporting analysis results...
✅ Cluster experiment analysis complete!
```

## Detailed Usage

### Collection Process

The pipeline automatically handles:

1. **Discovery**: Finds experiments in `/home/scholten/globtimcore/hpc_results/`
2. **Download**: Uses secure SCP to transfer results locally
3. **Validation**: Applies defensive error boundaries and interface checking
4. **Analysis**: Comprehensive statistical analysis with error categorization
5. **Reporting**: Generates CSV exports and JSON summaries

### Storage Management

#### Automatic Organization
```bash
# Results saved to timestamped directory
cluster_results_YYYYMMDD_HHMMSS/
├── experiment_1/
│   ├── critical_points_deg_4.csv
│   ├── critical_points_deg_5.csv
│   └── results_summary.json
├── detailed_analysis.csv
└── analysis_summary.json
```

#### Manual Archive Management
```bash
# Archive older collections
mkdir -p docs/archive/cluster_results_archive_$(date +%Y_%m_%d)
mv cluster_results_old_* docs/archive/cluster_results_archive_$(date +%Y_%m_%d)/

# Keep only recent representative collection
ls cluster_results_*/
```

### Advanced Usage

#### Environment-Aware Path Resolution
The pipeline automatically detects and adapts to different environments:
- **Local development**: Connects via SSH to cluster
- **HPC deployment**: Direct local file access
- **Cross-platform**: Handles path differences automatically

#### Error Categorization Integration
Automatic classification of experiment failures:
- **Interface Bugs** (LOW): Column naming issues (val vs z)
- **Mathematical Failures** (MEDIUM): Convergence problems
- **Infrastructure Issues** (HIGH): Memory, package problems
- **Configuration Errors** (MEDIUM): Invalid parameters

#### Defensive Boundaries
Built-in error handling:
- Missing configuration files handled gracefully
- JSON parsing errors detected and reported
- Network connection failures with retry logic
- Incomplete downloads logged but don't stop processing

## Monitoring Active Experiments

### Check Running Experiments
```bash
# List active tmux sessions
ssh scholten@r04n02 "tmux list-sessions"

# Monitor specific session
ssh scholten@r04n02 "tmux attach -t lotka_volterra_4d"

# Check recent output without attaching
ssh scholten@r04n02 "tmux capture-pane -t lotka_volterra_4d -p | tail -20"
```

### Launch New Experiments
```bash
# Start new experiment on cluster
ssh scholten@r04n02 "cd /home/scholten/globtimcore && tmux new-session -d -s my_experiment 'julia --project=. Examples/minimal_4d_lv_test.jl 0.1'"
```

## Integration with Existing Workflows

### GitLab Project Management
```bash
# Update issues with results (if configured)
./tools/gitlab/enhanced-gitlab-api.sh update-issue 81 "" "Analysis complete" "status::completed"
```

### Post-Processing Pipeline
```bash
# Use collected data with post-processing tools
julia --project=. Examples/post_processing_example.jl cluster_results_latest/
```

### Interactive Analysis
```bash
# Launch interactive comparison workflow
julia --project=. interactive_comparison_demo.jl
```

## Troubleshooting

### Common Issues

#### "No experiment directories found"
```bash
# Check HPC connectivity
ssh scholten@r04n02 "cd /home/scholten/globtimcore && ls hpc_results/"

# Verify path resolution
julia --project=. -e "include(\"test/specialized_tests/environment/environment_utils.jl\"); using .EnvironmentUtils; println(get_project_directory(:hpc))"
```

#### JSON parsing errors
```bash
# Check experiment result format
ssh scholten@r04n02 "cat /home/scholten/globtimcore/hpc_results/experiment_name/results_summary.json | head -20"
```

#### SCP transfer failures
```bash
# Test SSH connection
ssh scholten@r04n02 "echo 'Connection successful'"

# Check file permissions
ssh scholten@r04n02 "ls -la /home/scholten/globtimcore/hpc_results/experiment_name/"
```

### Performance Optimization

#### Large Collections
For >20 experiments, consider:
```bash
# Selective collection by date
ssh scholten@r04n02 "find /home/scholten/globtimcore/hpc_results -name '*20250927*'"

# Archive old results on cluster first
ssh scholten@r04n02 "cd /home/scholten/globtimcore && mkdir -p archive_old && mv hpc_results/old_* archive_old/"
```

#### Network Issues
```bash
# Use compression for large transfers
export SCP_OPTIONS="-C"
julia --project=. collect_cluster_experiments.jl
```

## Success Metrics

Expected performance for properly configured pipeline:
- **Collection Time**: <30 seconds for 4 experiments
- **Success Rate**: 95%+ for experiment processing
- **Error Detection**: <5 seconds for failure location identification
- **Data Quality**: Automatic validation of CSV structure and ranges

## Next Steps

After successful collection:
1. **Analysis**: Use collected data with visualization tools
2. **Archival**: Move older collections to archive directories
3. **Reporting**: Generate publication-ready analysis reports
4. **Integration**: Feed results into parameter optimization workflows

For advanced features and customization, see:
- `docs/hpc/CLUSTER_PIPELINE_TESTING_GUIDE.md` - Testing procedures
- `src/ErrorCategorization.jl` - Error classification system
- `collect_cluster_experiments.jl` - Main pipeline script