# 4D Benchmark Testing Infrastructure

Comprehensive testing framework for evaluating Globtim's performance on 4D benchmark functions with focus on:
- **Sparsification analysis** - Track where and how polynomial coefficients are reduced
- **Convergence monitoring** - Use ForwardDiff to track BFGS convergence to local minimizers  
- **Distance tracking** - Calculate and visualize distances to known global minimizers
- **Standardized plotting** - Generate publication-ready plots with proper labeling
- **Systematic studies** - Automated parameter sweeps and comparative analysis

## 🚀 Quick Start

```bash
# Run quick development test
julia --project=. Examples/4d_benchmark_tests/run_4d_benchmark_study.jl quick

# Try the example usage script
julia --project=. Examples/4d_benchmark_tests/example_usage.jl

# Analyze a specific function in detail
julia --project=. Examples/4d_benchmark_tests/run_4d_benchmark_study.jl custom Sphere
```

## 📁 File Structure

```
Examples/4d_benchmark_tests/
├── README.md                      # This file
├── benchmark_4d_framework.jl      # Core testing framework
├── plotting_4d.jl                 # Visualization infrastructure  
├── run_4d_benchmark_study.jl      # Main execution script
├── example_usage.jl               # Usage examples and demos
└── results/                       # Generated results (created automatically)
    ├── quick_4d_study_YYYY-MM-DD_HH-MM-SS/
    ├── standard_4d_study_YYYY-MM-DD_HH-MM-SS/
    └── custom_Sphere_study_YYYY-MM-DD_HH-MM-SS/
```

## 🎯 Benchmark Functions Available

The framework includes 10 carefully selected 4D benchmark functions:

### Bowl-Shaped (Unimodal)
- **Sphere** - Basic convex function, global min at origin
- **Rosenbrock** - Classic "banana" function with narrow valley
- **Zakharov** - Plate-shaped with increasing ill-conditioning

### Multimodal (Many Local Minima)  
- **Griewank** - Many regularly distributed local minima
- **Rastringin** - Regular grid of local minima
- **Levy** - Steep ridges with many local minima

### Scalable Functions
- **StyblinskiTang** - Separable multimodal, known global minimum
- **Michalewicz** - Steep ridges, parameter-controlled difficulty

### Higher-Dimensional Specific
- **Trid** - Known analytical global minimum
- **RotatedHyperEllipsoid** - Elongated ellipsoidal shape

Each function includes:
- ✅ **Known global minimum location** for distance tracking
- ✅ **Proper domain specification** for sampling
- ✅ **Expected function value** at global minimum

## 🔧 Core Features

### 1. Sparsification Analysis
Track how polynomial coefficients are reduced through sparsification:

```julia
# Analyze sparsification with multiple thresholds
results = analyze_4d_function(:Sphere, 
    sparsification_thresholds=[1e-2, 1e-3, 1e-4, 1e-5])

# Visualize sparsification trade-offs
plot_sparsification_analysis(results, "output_dir")
```

**Outputs:**
- Sparsity gain vs threshold plots
- L2 norm preservation analysis  
- Coefficient count reduction visualization

### 2. Convergence Monitoring with ForwardDiff
Track BFGS convergence using automatic differentiation:

```julia
# Detailed convergence study
convergence_data = convergence_study_4d(:Rosenbrock, track_distance=true)

# Visualize convergence trajectories
plot_distance_to_minimizers(convergence_data, "output_dir")
```

**Metrics tracked:**
- Initial vs final distances to global minimum
- Gradient norms at refined points
- Convergence steps and reasons
- Distance reduction trajectories

### 3. Distance to Minimizers
Calculate and track distances to known global minima:

```julia
# Calculate distances for critical points
distances = calculate_distance_to_global_minimum(df, global_min, 4)

# Track convergence improvement
tracker = track_convergence_to_minimum(initial_df, refined_df, global_min, objective_func)
```

### 4. Standardized Plotting with Proper Labeling
Generate publication-ready plots with consistent styling:

```julia
# All plots include:
# - Function-specific colors (colorblind-friendly palette)
# - Degree-specific markers  
# - Proper axis labels and titles
# - Legends with clear identification
# - Timestamp-based file naming

plot_convergence_comparison(results, output_dir)
```

## 📊 Analysis Modes

### Quick Mode (Development)
Fast testing for development and debugging:
- 2-3 functions (Sphere, Rosenbrock, Griewank)
- Degrees: [4, 6]
- Samples: [50, 100]
- Runtime: ~2-5 minutes

### Standard Mode (Comprehensive)
Balanced analysis for research:
- 6 functions covering different characteristics
- Degrees: [4, 6, 8, 10]  
- Samples: [100, 200, 500]
- Runtime: ~15-30 minutes

### Intensive Mode (Research)
Complete analysis for publication:
- All 10 benchmark functions
- Degrees: [6, 8, 10, 12]
- Samples: [200, 500, 1000]
- Runtime: 1-3 hours

### Custom Mode (Single Function)
Detailed analysis of specific function:
- User-selected function
- Extended degree range [4, 6, 8, 10, 12]
- Multiple sample counts [100, 200, 500]
- Comprehensive sparsification analysis

## 🎨 Generated Outputs

Each analysis run creates a timestamped directory with:

### Plots
- `distance_vs_degree.png` - Distance to global minimum vs polynomial degree
- `convergence_trajectories.png` - Initial vs final distance scatter plots
- `gradient_vs_distance.png` - Gradient norm vs distance relationship
- `sparsity_vs_threshold.png` - Sparsification threshold analysis
- `l2_vs_sparsity.png` - L2 norm preservation vs sparsity gain
- `convergence_rate_vs_degree.png` - BFGS convergence rate analysis
- `performance_vs_accuracy.png` - Time vs accuracy trade-offs

### Reports
- `benchmark_summary_report.txt` - Comprehensive text summary
- `convergence_study_summary.txt` - Detailed convergence metrics
- `experiment_metadata.json` - Reproducibility information

### Data
- All results stored in structured format
- Critical points and minimizers data
- Sparsification analysis results
- Performance timing information

## 🔬 Usage Examples

### Basic Function Analysis
```julia
include("benchmark_4d_framework.jl")

# Analyze single function
results = analyze_4d_function(:Sphere, 
    degrees=[4,6,8], 
    track_convergence=true)

# Print summary
for r in results
    println("Degree $(r.degree): L2=$(r.l2_error), Conv=$(r.convergence_metrics.convergence_rate)")
end
```

### Convergence Study
```julia
# Track convergence to global minimum
conv_data = convergence_study_4d(:Rosenbrock, degrees=[4,6,8,10])

# Analyze convergence quality
for data in conv_data
    mean_distance = mean(data.tracker.distances_to_global)
    mean_grad_norm = mean(data.tracker.gradient_norms)
    println("Degree $(data.degree): dist=$(mean_distance), grad=$(mean_grad_norm)")
end
```

### Comparative Analysis
```julia
# Compare multiple functions
functions_to_test = [:Sphere, :Rosenbrock, :Griewank, :Rastringin]
all_results = []

for func in functions_to_test
    results = analyze_4d_function(func, degrees=[6,8])
    append!(all_results, results)
end

# Generate comparative plots
plot_convergence_comparison(all_results, "comparison_output")
```

## 🛠️ Customization

### Adding New Functions
```julia
# Add to BENCHMARK_4D_FUNCTIONS dictionary
const BENCHMARK_4D_FUNCTIONS = Dict(
    :MyFunction => (
        func=my_function,
        domain=[-1.0, 1.0], 
        global_min=[0.0, 0.0, 0.0, 0.0],
        f_min=0.0
    )
)
```

### Custom Configurations
```julia
# Create custom testing configuration
const MY_CONFIG = (
    degrees = [4, 8, 12],
    sample_counts = [200, 1000],
    sparsification_thresholds = [1e-2, 1e-4, 1e-6],
    functions = [:Sphere, :MyFunction]
)

# Run with custom config
results = run_4d_benchmark_suite(MY_CONFIG)
```

### Plot Customization
```julia
# Modify PLOT_CONFIG for custom styling
const PLOT_CONFIG = (
    figure_size = (1000, 800),  # Larger figures
    function_colors = Dict(
        :MyFunction => colorant"#ff0000"  # Custom color
    ),
    title_font_size = 18  # Larger titles
)
```

## 📈 Performance Considerations

- **Memory usage**: ~1-2GB for standard mode, ~4-8GB for intensive mode
- **Disk space**: ~50-200MB per analysis run (plots + data)
- **Parallelization**: Framework is single-threaded but can be extended
- **Caching**: Results are saved for later analysis and comparison

## 🔍 Troubleshooting

### Common Issues
1. **CairoMakie not found**: Install with `Pkg.add("CairoMakie")`
2. **Memory errors**: Reduce sample counts or use fewer functions
3. **Convergence failures**: Some functions may have numerical challenges at high degrees

### Debug Mode
```julia
# Enable verbose output
results = analyze_4d_function(:Sphere, track_convergence=true, verbose=true)

# Check individual components
pol = Constructor(TR, degree)  # Check polynomial construction
df = process_crit_pts(solutions, f, TR)  # Check critical point finding
```

## 🤝 Contributing

To extend the framework:
1. Add new benchmark functions to `BENCHMARK_4D_FUNCTIONS`
2. Implement custom analysis metrics in `analyze_4d_function`
3. Add new plot types in `plotting_4d.jl`
4. Create specialized configurations for your use case

## 📚 References

- Jamil, M. & Yang, X.-S. A Literature Survey of Benchmark Functions For Global Optimization Problems. Int. J. Math. Model. Numer. Optim. 4, 150–194 (2013).
- Globtim.jl documentation for polynomial approximation methods
- ForwardDiff.jl for automatic differentiation capabilities
