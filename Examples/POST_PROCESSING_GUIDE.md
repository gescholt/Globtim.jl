# GlobTim Post-Processing Guide

## Overview

This guide explains how to analyze and visualize results from GlobTim experiments run on the HPC node. The post-processing system provides comprehensive statistics, publication-ready plots, and automated reports.

## Quick Start

### 1. Quick Result Summary
For a fast overview of experiment results:

```bash
julia --project=. Examples/quick_result_summary.jl 4d_results.json
```

**Output Example:**
```
📐 Dimension: 4
📊 Polynomial Degree: 8  
📈 L2 Norm: 1.07e-02 (log₁₀: -1.97)
⚠️  Quality: 🔴 POOR
🧮 Condition Number: 1.60e+01
✅ Stability: 🟢 GOOD
⚖️  Sample/Monomial Ratio: 0.024
⚠️  Sampling: 🔴 UNDERDETERMINED (insufficient samples)
```

### 2. Comprehensive Analysis
For detailed analysis with plots and reports:

```bash
julia --project=. Examples/post_process_node_results.jl 4d_results.json
```

This generates:
- Statistical analysis report (markdown)
- Experiment dashboard (PNG)
- Function evaluation plots (PNG)

### 3. Batch Processing
To analyze multiple experiments at once:

```bash
julia --project=. Examples/post_process_node_results.jl collected_results/
```

This processes all experiment directories and creates comparative analysis plots.

## Understanding the Output

### Quality Classifications

| L2 Norm Range | Quality | Icon | Interpretation |
|---------------|---------|------|----------------|
| < 1e-10 | Excellent | 🟢 | Very high precision |
| 1e-10 to 1e-6 | Good | 🟡 | Acceptable precision |
| 1e-6 to 1e-3 | Acceptable | 🟠 | Moderate precision |
| > 1e-3 | Poor | 🔴 | Low precision |

### Stability Assessment

| Condition Number | Stability | Icon | Interpretation |
|------------------|-----------|------|----------------|
| < 1e8 | Good | 🟢 | Numerically stable |
| 1e8 to 1e12 | Moderate | 🟠 | Some numerical issues |
| > 1e12 | Poor | 🔴 | Numerically unstable |

### Sampling Assessment

| Sample/Monomial Ratio | Status | Icon | Interpretation |
|-----------------------|--------|------|----------------|
| > 2.0 | Well-conditioned | 🟢 | Sufficient samples |
| 1.0 to 2.0 | Marginal | 🟠 | Barely sufficient |
| < 1.0 | Underdetermined | 🔴 | Insufficient samples |

## Generated Files

### Reports
- `{experiment}_analysis_report.md` - Comprehensive markdown report
- Console output with key metrics and quality assessment

### Plots (requires CairoMakie/GLMakie)
- `{experiment}_dashboard.png` - Multi-panel experiment overview
- `{experiment}_evaluations.png` - Function evaluation analysis
- `convergence_comparison.png` - Multi-experiment comparison

## Plot Descriptions

### 1. Convergence Analysis
- **L2 Norm vs Degree**: Shows approximation quality scaling
- **Condition Number vs Degree**: Numerical stability trends
- **Multi-dimensional comparison**: Quality across different problem dimensions

### 2. Function Evaluation Analysis
- **Value Distribution**: Histogram of function values
- **Parameter Space**: 2D visualization of sampling points (if applicable)
- **Evaluation Sequence**: Function values over evaluation order

### 3. Experiment Dashboard
- **Key Metrics**: L2 norm, condition number, evaluation count
- **Quality Indicator**: Visual quality classification
- **Distribution Analysis**: Function value statistics
- **Parameter Space**: Sample point visualization

## Troubleshooting

### No Plots Generated
```
⚠️  Makie not available - plots will be skipped
   Install with: using Pkg; Pkg.add(["CairoMakie", "GLMakie"])
```

**Solution**: Install plotting packages
```julia
using Pkg
Pkg.add(["CairoMakie", "GLMakie"])
```

### File Not Found
```
❌ File not found: result_file.json
```

**Solution**: Check file path and ensure experiment completed successfully

### No Experiment Data
```
⚠️  No experiment results found in directory
```

**Solution**: Ensure directory contains valid JSON result files or CSV data

## Advanced Usage

### Custom Analysis
Use the PostProcessing module directly in Julia:

```julia
include("src/PostProcessing.jl")
using .PostProcessing

# Load experiment
results = load_experiment_results("4d_results.json")

# Perform analysis
summary = analyze_experiment(results)

# Create custom plots
dashboard = create_experiment_dashboard(results, summary)
```

### Integration with HPC Workflow

Add post-processing to your experiment scripts:

```julia
# At end of experiment
include("Examples/post_process_node_results.jl")
results, summary = process_single_experiment("experiment_results.json")
```

## File Format Support

### Input Formats
- **JSON**: Experiment metadata and configuration
- **CSV**: Function evaluation data, convergence traces
- **Directory**: Collections of experiment results

### Output Formats
- **Markdown**: Analysis reports
- **PNG**: High-resolution plots
- **Console**: Quick summaries and metrics

## Best Practices

1. **Run quick summary first** to identify issues
2. **Use batch processing** for parameter studies
3. **Check quality indicators** before detailed analysis
4. **Save plots** for documentation and presentations
5. **Include analysis reports** in experiment documentation

## Examples

### Single 4D Experiment
```bash
# Quick check
julia --project=. Examples/quick_result_summary.jl 4d_results.json

# Full analysis
julia --project=. Examples/post_process_node_results.jl 4d_results.json
```

### Parameter Study Analysis
```bash
# Analyze all experiments in collected_results/
julia --project=. Examples/post_process_node_results.jl collected_results/

# Creates convergence_comparison.png with all experiments
```

### Integration Example
```julia
# In your experiment script
function run_experiment()
    # ... run experiment ...
    save_results("my_experiment.json")
    
    # Automatic post-processing
    include("Examples/quick_result_summary.jl") 
    analyze_json_result("my_experiment.json")
end
```

This post-processing system provides everything needed to understand and visualize GlobTim experiment results from the HPC node, enabling better analysis and faster iteration on numerical experiments.