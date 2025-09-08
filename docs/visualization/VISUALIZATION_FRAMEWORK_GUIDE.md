# GlobTim Visualization Framework Guide

**Issue #67 Implementation**: Extensible visualization framework for future plotting capabilities

This guide explains how to use and extend the GlobTim visualization framework, which provides a clean separation between data processing and visualization, with graceful degradation when plotting packages are unavailable.

## Overview

The visualization framework consists of:

1. **Abstract Interface**: `src/VisualizationFramework.jl` - Core types and data preparation
2. **Makie Extension**: `ext/GlobtimVisualizationFrameworkExt.jl` - Concrete plotting implementations  
3. **Plugin Architecture**: Registry system for adding new renderers
4. **Graceful Fallback**: Text-based analysis when plotting unavailable

## Core Components

### Abstract Types

```julia
using Globtim.VisualizationFramework

# Base types for extensibility
AbstractVisualizationConfig    # Configuration base type
AbstractPlotData              # Data container base type  
AbstractPlotRenderer          # Renderer implementation base type
```

### Data Containers

#### L2DegreeAnalysisData
For L2-norm vs polynomial degree analysis plots:

```julia
# Prepare data from experiment results
experiment_results = [result1, result2, ...]  # PostProcessing.ExperimentResults or Dict
data = prepare_l2_degree_plot_data(experiment_results)

# Data contains:
# - degrees, l2_norms, dimensions, condition_numbers
# - Quality thresholds for visualization
# - Metadata with analysis summary
```

#### ParameterSpaceData
For parameter space visualization:

```julia
# From raw points and function values
points = rand(100, 2)  # N x D matrix
function_values = [f(points[i, :]) for i in 1:100]
data = prepare_parameter_space_data(points, function_values)

# Supports 1D, 2D, and high-dimensional parameter spaces
```

#### ConvergenceTrajectoryData
For optimization algorithm convergence visualization:

```julia
# From algorithm trackers (compatible with InteractiveVizCore.AlgorithmTracker)
algorithm_trackers = Dict("SGD" => sgd_tracker, "Adam" => adam_tracker)
data = prepare_convergence_data(algorithm_trackers)

# Shows trajectory paths, function value evolution, step sizes
```

### Configuration

```julia
# Flexible plot configuration
config = PlotConfig(
    figure_size = (1200, 800),
    title = "My Analysis",
    save_path = "analysis_plot.png",
    color_scheme = :viridis,
    show_legend = true,
    grid = true
)
```

## Usage Examples

### Basic L2-Norm vs Degree Analysis

```julia
using Globtim.VisualizationFramework

# Load your experiment results
results = load_your_experiment_results()  # Vector of results

# Prepare visualization data
data = prepare_l2_degree_plot_data(results)

# Configure plot
config = PlotConfig(
    title = "Polynomial Degree Convergence Study",
    save_path = "l2_degree_analysis.png"
)

# Render plot (automatically uses best available renderer)
plot = render_plot(data, config)
```

**Output with Makie available**: Publication-quality plot with quality thresholds, condition number analysis, and quality distribution histogram.

**Output without Makie**: Detailed text analysis with quality distribution, best results, and numerical summaries.

### Parameter Space Visualization

```julia
# 2D parameter space example
X = randn(200, 2)  # 200 points in 2D
f_vals = [rosenbrock(X[i, :]) for i in 1:200]

data = prepare_parameter_space_data(X, f_vals, 
    dimension_labels = ["x₁", "x₂"])

config = PlotConfig(
    title = "Rosenbrock Function Parameter Space",
    color_scheme = :plasma
)

plot = render_plot(data, config)
```

### Multi-Algorithm Convergence Comparison

```julia
# Assuming you have algorithm tracking data
trackers = Dict(
    "Gradient Descent" => gd_tracker,
    "Adam" => adam_tracker, 
    "BFGS" => bfgs_tracker
)

data = prepare_convergence_data(trackers)

config = PlotConfig(
    title = "Algorithm Convergence Comparison",
    save_path = "convergence_comparison.png"
)

plot = render_plot(data, config)
```

## Extensibility Guide

### Adding New Plot Types

1. **Define Data Container**:
```julia
struct MyCustomPlotData <: AbstractPlotData
    # Your data fields
    my_data::Vector{Float64}
    metadata::Dict{String,Any}
end
```

2. **Create Data Preparation Function**:
```julia
function prepare_my_custom_data(raw_data)
    # Process raw data
    processed = process_data(raw_data)
    return MyCustomPlotData(processed, Dict("info" => "value"))
end
```

3. **Implement Renderer** (in extension):
```julia
function VisualizationFramework.render_plot(renderer::CairoMakieRenderer,
                                           data::MyCustomPlotData, 
                                           config::PlotConfig)
    # Your Makie plotting code
    fig = Figure()
    # ... plotting logic ...
    return fig
end
```

4. **Register Renderer**:
```julia
register_plot_renderer!(MyCustomPlotData, CairoMakieRenderer(), set_default=true)
```

### Adding New Renderers

```julia
struct MyCustomRenderer <: AbstractPlotRenderer
    backend_name::String
    # Additional configuration
end

# Implement render_plot method for your renderer
function VisualizationFramework.render_plot(renderer::MyCustomRenderer, 
                                           data::AbstractPlotData, 
                                           config::PlotConfig)
    # Your rendering implementation
end

# Register for specific data types
register_plot_renderer!(L2DegreeAnalysisData, MyCustomRenderer("MyBackend"))
```

## Integration with Existing Code

### PostProcessing Module Integration

The framework seamlessly integrates with the existing `PostProcessing.jl`:

```julia
using Globtim.PostProcessing
using Globtim.VisualizationFramework

# Load experiments using existing infrastructure
results = load_experiment_results("path/to/results/")
summary = analyze_experiment(results)

# Use new visualization framework
plot_data = prepare_l2_degree_plot_data([results])
plot = render_plot(plot_data, PlotConfig())
```

### Interactive Visualization Core Integration

Compatible with `InteractiveVizCore.jl` algorithm trackers:

```julia
using Globtim.InteractiveVizCore
using Globtim.VisualizationFramework

# Create algorithm tracker
tracker = AlgorithmTracker("My Algorithm")

# ... run algorithm and update tracker ...

# Visualize convergence
trackers = Dict("My Algorithm" => tracker)
data = prepare_convergence_data(trackers)
plot = render_plot(data, PlotConfig())
```

## Error Handling and Fallbacks

The framework provides robust error handling:

1. **Missing Plotting Packages**: Automatic fallback to text-based analysis
2. **Invalid Data**: Clear error messages with suggestions
3. **Renderer Failures**: Graceful degradation to fallback renderer
4. **File I/O Issues**: Proper error reporting for save operations

Example fallback output when Makie unavailable:

```
📊 Plot Visualization (Text Mode - Plotting packages unavailable)
============================================================
Plot Type: L2DegreeAnalysisData

📈 L2-Norm vs Polynomial Degree Analysis
Experiments: 25
Degree Range: 2 - 8
L2-Norm Range: 1.23e-12 - 4.56e-04

Quality Distribution:
  🟢 Excellent: 15 experiments
  🟡 Good: 8 experiments
  🟠 Acceptable: 2 experiments
  🔴 Poor: 0 experiments

Best Result:
  Degree: 6
  L2-Norm: 1.23e-12
  Condition Number: 2.45e+08
```

## Performance Considerations

- **Data Preparation**: Separated from rendering for efficiency
- **Memory Usage**: Lazy evaluation where possible
- **Large Datasets**: Automatic downsampling options in renderers
- **Parallel Processing**: Extension points for parallel data processing

## Future Extensions

The framework is designed to easily accommodate:

- **New Plot Types**: Critical point analysis, Hessian eigenvalue plots
- **Interactive Features**: Real-time updates, parameter sweeps  
- **Export Formats**: PDF, SVG, interactive HTML
- **Statistical Analysis**: Automated trend detection, regression analysis
- **3D Visualization**: Surface plots, volume rendering

## Testing

Test your extensions:

```julia
using Test

# Test data preparation
@testset "Custom Plot Data" begin
    data = prepare_my_custom_data(test_input)
    @test isa(data, MyCustomPlotData)
    @test !isempty(data.my_data)
end

# Test rendering with and without Makie
@testset "Rendering" begin
    plot = render_plot(data, PlotConfig())
    # Should work regardless of Makie availability
end
```

## Complete Example

Here's a complete example showing the framework's flexibility:

```julia
using Globtim.VisualizationFramework

# Example: Analyze multiple 4D experiments
experiment_files = ["4d_deg3.json", "4d_deg4.json", "4d_deg5.json"]
results = [JSON.parsefile(f) for f in experiment_files]

# Prepare L2-degree analysis
l2_data = prepare_l2_degree_plot_data(results)

# Create comprehensive plot
config = PlotConfig(
    title = "4D Polynomial Approximation Quality Study",
    figure_size = (1400, 1000),
    save_path = "4d_quality_analysis.png",
    color_scheme = :plasma
)

# This works with or without plotting packages installed
analysis_plot = render_plot(l2_data, config)

println("✅ Visualization complete - check output for plots or text analysis")
```

---

**Implementation Status**: ✅ **Issue #67 Complete**  
**Framework Features**: Abstract interfaces ✅ | Data preparation ✅ | Plugin architecture ✅ | Graceful fallbacks ✅ | Makie integration ✅ | Documentation ✅