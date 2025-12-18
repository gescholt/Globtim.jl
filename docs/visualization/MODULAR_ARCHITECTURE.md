# Visualization Infrastructure - Modular Architecture

## Overview

The visualization infrastructure for cluster experiment results has been refactored into a modular architecture, separating concerns for better maintainability and reusability.

**Date**: September 30, 2025
**Version**: 2.0
**Related Issues**: GitLab #108 (Distance Visualization), #110 (Schema v1.1.0)

## Architecture

### Core Modules

The visualization system consists of three core modules and one orchestrator script:

#### 1. ExperimentDataLoader.jl
**Location**: `globtimcore/src/ExperimentDataLoader.jl`
**Purpose**: Centralized data loading and parsing for experiment results

**Key Functions**:
- `load_experiment_data(experiment_dir)` - Load results_summary.json with true_params from experiment_params.json
- `get_system_info(data)` - Extract system information (type, parameters, domain)
- `get_true_params(data)` - Extract ground truth parameters for parameter recovery experiments
- `load_critical_points(experiment_dir, degree)` - Load CSV files with critical points for specific degrees
- `collect_experiment_directories(base_dir)` - Discover and list available experiments

**Schema Support**: Handles both v1.0.0 and v1.1.0 experiment schemas with graceful fallbacks

#### 2. ParameterRecoveryAnalysis.jl
**Location**: `globtimcore/src/ParameterRecoveryAnalysis.jl`
**Purpose**: Analysis logic for parameter recovery experiments

**Key Functions**:
- `compute_distances_to_true(experiment_dir, degree, true_params)` - Compute distances from critical points to ground truth
- `extract_metrics(experiment_dir, data, true_params)` - Extract all metrics (L2 norms, condition numbers, distances)
- `get_convergence_summary(metrics, true_params)` - Generate summary statistics

**Metrics Computed**:
- L2 approximation error (polynomial quality)
- Condition numbers (numerical stability)
- Minimum distance to true parameters (parameter recovery success)
- Mean distance to true parameters (overall convergence)

#### 3. TextVisualization.jl
**Location**: `globtimcore/src/TextVisualization.jl`
**Purpose**: ASCII-based terminal visualization (no graphics dependencies)

**Key Functions**:
- `plot_text(degrees, values, title, ylabel)` - ASCII plots with tables
- `display_experiment_info(data, system_info, true_params)` - Show experiment metadata
- `display_convergence_summary(metrics, true_params)` - Show summary statistics

**Features**:
- Publication-quality ASCII tables
- Simple bar-chart style visualizations
- No external plotting dependencies (terminal-only)
- Suitable for HPC environments without X11

#### 4. visualize_cluster_results.jl (Orchestrator)
**Location**: `globtimcore/visualize_cluster_results.jl`
**Purpose**: Main script that coordinates the modules

**Reduced from**: 690 lines → 380 lines
**Functions**:
- `visualize_text(experiment_dir)` - Text-based visualization using all modules
- `visualize_plots(experiment_dir)` - Graphical visualization (optional, requires @globtimplots)
- Interactive experiment selection
- Batch processing mode

## Usage

### Single Experiment Visualization

```bash
# Text-based (no graphics dependencies)
julia --project=. visualize_cluster_results.jl text hpc_results/minimal_4d_lv_test_GN=5_domain_size_param=0.1_max_time=45.0_20250930_103317

# Graphical (requires @globtimplots package)
julia --project=. visualize_cluster_results.jl plots hpc_results/minimal_4d_lv_test_GN=5_domain_size_param=0.1_max_time=45.0_20250930_103317
```

### Interactive Mode

```bash
julia --project=. visualize_cluster_results.jl
# Shows numbered list of experiments, select one to visualize
```

### Batch Processing

```bash
julia --project=. visualize_cluster_results.jl collect
# Process all experiments in hpc_results/ and generate reports
```

## Module Dependencies

```
visualize_cluster_results.jl (orchestrator)
├── ExperimentDataLoader.jl
│   └── (no internal dependencies)
├── ParameterRecoveryAnalysis.jl
│   └── ExperimentDataLoader.jl
├── TextVisualization.jl
│   └── (no internal dependencies)
└── ComparisonAnalysis.jl (experiment discovery)
```

## Extending the System

### Adding New Metrics

To add new analysis metrics:

1. Add metric computation to `ParameterRecoveryAnalysis.jl`:
```julia
function compute_new_metric(experiment_dir, degree, ...)
    # Computation logic
    return metric_value
end
```

2. Update `extract_metrics()` to include new metric:
```julia
function extract_metrics(experiment_dir, data, true_params)
    # ... existing metrics ...
    new_metric_values = Float64[]

    for degree in degrees
        new_val = compute_new_metric(experiment_dir, degree, ...)
        push!(new_metric_values, new_val)
    end

    return (
        degrees=degrees,
        # ... existing fields ...
        new_metric=new_metric_values
    )
end
```

3. Add visualization to `TextVisualization.jl`:
```julia
if any(!isnan, metrics.new_metric)
    TextVisualization.plot_text(
        metrics.degrees,
        metrics.new_metric,
        "Graph N: New Metric Description",
        "Metric Unit"
    )
end
```

### Adding New Data Sources

To load additional data files:

1. Add loader function to `ExperimentDataLoader.jl`:
```julia
function load_new_data_type(experiment_dir::String)
    data_file = joinpath(experiment_dir, "new_data.json")
    if !isfile(data_file)
        @warn "No new data found in $experiment_dir"
        return nothing
    end
    return JSON.parsefile(data_file)
end
```

2. Export the function:
```julia
export load_new_data_type
```

3. Use in analysis scripts:
```julia
using .ExperimentDataLoader
new_data = ExperimentDataLoader.load_new_data_type(experiment_dir)
```

### Creating Custom Visualizations

To create custom visualization scripts:

```julia
#!/usr/bin/env julia

# Import modules
include("src/ExperimentDataLoader.jl")
using .ExperimentDataLoader

include("src/ParameterRecoveryAnalysis.jl")
using .ParameterRecoveryAnalysis

# Load data
experiment_dir = ARGS[1]
data = ExperimentDataLoader.load_experiment_data(experiment_dir)
true_params = ExperimentDataLoader.get_true_params(data)

# Extract metrics
metrics = ParameterRecoveryAnalysis.extract_metrics(experiment_dir, data, true_params)

# Custom analysis
println("Custom Analysis Results:")
for (deg, l2) in zip(metrics.degrees, metrics.l2_norms)
    println("  Degree $deg: L2 = $l2")
end
```

## Schema Compatibility

### Version 1.0.0 Support
- Experiments without `true_params` → distance metrics show "N/A"
- Experiments without `refinement_stats` → graceful fallback
- Legacy experiments → automatic detection and compatibility mode

### Version 1.1.0 Support
- Full support for refinement data (raw vs refined critical points)
- Precision type information per degree
- Enhanced convergence statistics

### Forward Compatibility
The modular design ensures:
- New schema versions can be added without breaking existing code
- Each module can be updated independently
- Backward compatibility maintained through graceful degradation

## Testing

### Module Import Test
```julia
include("src/ExperimentDataLoader.jl")
using .ExperimentDataLoader
println("✓ ExperimentDataLoader loaded")

include("src/ParameterRecoveryAnalysis.jl")
using .ParameterRecoveryAnalysis
println("✓ ParameterRecoveryAnalysis loaded")

include("src/TextVisualization.jl")
using .TextVisualization
println("✓ TextVisualization loaded")
```

### End-to-End Test
```bash
# Test with actual experiment data
julia --project=. visualize_cluster_results.jl text hpc_results/minimal_4d_lv_test_GN=5_domain_size_param=0.1_max_time=45.0_20250930_103317
```

## Migration from Legacy Code

### Before (Monolithic)
```julia
# visualize_cluster_results.jl (690 lines)
# - All data loading inline
# - All analysis inline
# - All visualization inline
# - Hard to test individual components
# - Hard to reuse in other scripts
```

### After (Modular)
```julia
# visualize_cluster_results.jl (380 lines)
using .ExperimentDataLoader
using .ParameterRecoveryAnalysis
using .TextVisualization

# Clean orchestration of modular components
# Each module independently testable and reusable
```

**Benefits**:
- **Maintainability**: 310 lines removed from main script, organized into focused modules
- **Reusability**: Modules can be imported by other analysis scripts
- **Testability**: Each module can be tested independently
- **Clarity**: Clear separation of concerns (data, analysis, visualization)

## Related Documentation

- **Experiment Schema**: See [EXPERIMENT_SCHEMA.md](../EXPERIMENT_SCHEMA.md) for data format specifications
- **Parameter Recovery**: See experiment scripts in `Examples/` for parameter recovery setup
- **Visualization Standards**: See [VISUALIZATION_FRAMEWORK_GUIDE.md](VISUALIZATION_FRAMEWORK_GUIDE.md) for plotting standards

## Future Enhancements

Potential additions (not yet implemented):

1. **Comparison Module** (Issue #111)
   - Multi-experiment comparison
   - Side-by-side metric tables
   - Convergence rate analysis

2. **Dashboard Generation**
   - HTML dashboard output
   - Interactive plots with Plotly
   - Export to PDF reports

3. **Statistical Analysis**
   - Confidence intervals
   - Convergence rate fitting
   - Parameter sensitivity analysis

4. **Refinement Quality Analysis** (requires Schema v1.1.0 data)
   - Raw vs refined critical point comparison
   - Refinement convergence statistics
   - Per-point refinement quality metrics

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>