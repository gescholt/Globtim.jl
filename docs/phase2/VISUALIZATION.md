# Phase 2 Visualization Guide

## Overview

Phase 2 provides comprehensive visualization functions for Hessian analysis, enabling users to understand the numerical properties and classification of critical points.

## Visualization Functions

### 1. Hessian Norm Visualization

```julia
plot_hessian_norms(df::DataFrame; backend=:cairo)
```

**Purpose**: Visualize the magnitude of Hessian matrices across critical points.

**Features**:
- Scatter plot of Frobenius norms
- Color-coded by critical point classification
- Automatic legend generation
- Support for both CairoMakie and GLMakie backends

**Example**:
```julia
using CairoMakie
fig = plot_hessian_norms(df_enhanced)
display(fig)
save("hessian_norms.png", fig)
```

**Interpretation**:
- **High norms**: Steep curvature at critical point
- **Low norms**: Flat curvature at critical point
- **Clustering**: Similar norms may indicate similar local behavior

### 2. Condition Number Analysis

```julia
plot_condition_numbers(df::DataFrame; backend=:cairo)
```

**Purpose**: Assess numerical stability of Hessian matrices.

**Features**:
- Log-scale y-axis for condition numbers
- Filters out NaN and infinite values
- Color-coded by classification
- Reference lines for numerical thresholds

**Example**:
```julia
fig = plot_condition_numbers(df_enhanced)
display(fig)
```

**Interpretation**:
- **κ(H) < 1e12**: Well-conditioned (numerically stable)
- **κ(H) > 1e12**: Ill-conditioned (numerical instability)
- **κ(H) → ∞**: Nearly singular matrix (degenerate critical point)

### 3. Critical Eigenvalue Plots

```julia
plot_critical_eigenvalues(df::DataFrame; backend=:cairo)
```

**Purpose**: Analyze the critical eigenvalues that determine point classification.

**Features**:
- Dual subplot layout
- Left plot: Smallest positive eigenvalues (minima)
- Right plot: Largest negative eigenvalues (maxima)
- Reference lines at numerical zero (±1e-12)

**Example**:
```julia
fig = plot_critical_eigenvalues(df_enhanced)
display(fig)
```

**Interpretation**:
- **Minima validation**: Smallest positive eigenvalue > 0 confirms minimum
- **Maxima validation**: Largest negative eigenvalue < 0 confirms maximum
- **Near-zero values**: Indicate potential degeneracy or numerical issues

## Comprehensive Visualization Workflow

### Complete Analysis Visualization

```julia
function create_phase2_report(df_enhanced::DataFrame, save_plots=true)
    println("Creating Phase 2 visualization report...")
    
    # 1. Hessian norms
    fig_norms = plot_hessian_norms(df_enhanced)
    display(fig_norms)
    save_plots && save("phase2_hessian_norms.png", fig_norms)
    
    # 2. Condition numbers
    fig_condition = plot_condition_numbers(df_enhanced)
    display(fig_condition)
    save_plots && save("phase2_condition_numbers.png", fig_condition)
    
    # 3. Critical eigenvalues
    fig_eigenvals = plot_critical_eigenvalues(df_enhanced)
    display(fig_eigenvals)
    save_plots && save("phase2_critical_eigenvalues.png", fig_eigenvals)
    
    return (fig_norms, fig_condition, fig_eigenvals)
end
```

### Statistical Summary Plots

```julia
function plot_classification_summary(df_enhanced::DataFrame)
    using CairoMakie
    
    # Count classifications
    counts = combine(groupby(df_enhanced, :critical_point_type), nrow => :count)
    
    fig = Figure(resolution=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel="Critical Point Type", 
              ylabel="Count",
              title="Critical Point Classification Summary")
    
    barplot!(ax, 1:nrow(counts), counts.count, 
             color=:steelblue,
             bar_labels=string.(counts.critical_point_type))
    
    return fig
end
```

### Eigenvalue Distribution Analysis

```julia
function plot_eigenvalue_distributions(all_eigenvalues::Vector{Vector{Float64}})
    using CairoMakie
    
    # Flatten all eigenvalues
    all_eigs = vcat(all_eigenvalues...)
    
    fig = Figure(resolution=(1200, 400))
    
    # Histogram of all eigenvalues
    ax1 = Axis(fig[1, 1], 
               xlabel="Eigenvalue", 
               ylabel="Frequency",
               title="Distribution of All Eigenvalues")
    hist!(ax1, all_eigs, bins=50, color=:lightblue)
    
    # Log-scale histogram (positive eigenvalues only)
    positive_eigs = filter(x -> x > 1e-12, all_eigs)
    ax2 = Axis(fig[1, 2], 
               xlabel="Eigenvalue (log scale)", 
               ylabel="Frequency",
               title="Positive Eigenvalues (Log Scale)",
               xscale=log10)
    hist!(ax2, positive_eigs, bins=50, color=:lightgreen)
    
    # Negative eigenvalues
    negative_eigs = filter(x -> x < -1e-12, all_eigs)
    ax3 = Axis(fig[1, 3], 
               xlabel="Eigenvalue", 
               ylabel="Frequency",
               title="Negative Eigenvalues")
    hist!(ax3, negative_eigs, bins=50, color=:lightcoral)
    
    return fig
end
```

## Advanced Visualization

### 3D Hessian Property Space

```julia
function plot_hessian_3d_analysis(df_enhanced::DataFrame)
    using GLMakie  # Interactive 3D plotting
    
    # Filter valid data
    valid_mask = .!isnan.(df_enhanced.hessian_norm) .& 
                 .!isnan.(df_enhanced.hessian_condition_number) .&
                 .!isnan.(df_enhanced.hessian_determinant)
    
    df_valid = df_enhanced[valid_mask, :]
    
    fig = Figure(resolution=(1000, 800))
    ax = Axis3(fig[1, 1], 
               xlabel="Hessian Norm", 
               ylabel="Condition Number (log)", 
               zlabel="Determinant",
               title="3D Hessian Property Space")
    
    # Color by classification
    classifications = unique(df_valid.critical_point_type)
    colors = [:red, :blue, :green, :orange, :purple]
    
    for (i, class) in enumerate(classifications)
        mask = df_valid.critical_point_type .== class
        scatter!(ax, 
                df_valid.hessian_norm[mask],
                log10.(df_valid.hessian_condition_number[mask]),
                df_valid.hessian_determinant[mask],
                color=colors[i], 
                label=string(class),
                markersize=8)
    end
    
    axislegend(ax)
    return fig
end
```

### Heatmap Visualization

```julia
function plot_eigenvalue_heatmap(all_eigenvalues::Vector{Vector{Float64}})
    using CairoMakie
    
    # Create matrix of eigenvalues (pad with NaN if needed)
    max_dims = maximum(length.(all_eigenvalues))
    n_points = length(all_eigenvalues)
    
    eig_matrix = fill(NaN, n_points, max_dims)
    for (i, eigs) in enumerate(all_eigenvalues)
        eig_matrix[i, 1:length(eigs)] = sort(eigs)
    end
    
    fig = Figure(resolution=(800, 600))
    ax = Axis(fig[1, 1], 
              xlabel="Eigenvalue Index", 
              ylabel="Critical Point Index",
              title="Eigenvalue Heatmap (Sorted)")
    
    hm = heatmap!(ax, eig_matrix, colormap=:RdBu, nan_color=:gray)
    Colorbar(fig[1, 2], hm, label="Eigenvalue")
    
    return fig
end
```

## Visualization Best Practices

### 1. Backend Selection

```julia
# Static plots (publication quality)
using CairoMakie
plot_hessian_norms(df, backend=:cairo)

# Interactive plots (exploration)
using GLMakie
plot_hessian_norms(df, backend=:gl)
```

### 2. Color Schemes

Recommended color schemes for critical point classifications:
- **Minima**: Blue (#1f77b4)
- **Maxima**: Red (#d62728)
- **Saddle**: Green (#2ca02c)
- **Degenerate**: Orange (#ff7f0e)
- **Error**: Gray (#7f7f7f)

### 3. Scale Considerations

- Use log scale for condition numbers (often span many orders of magnitude)
- Consider log scale for positive eigenvalues
- Use linear scale for norms and determinants unless range is extreme

### 4. Data Filtering

Always filter out invalid data:
```julia
# Remove NaN and infinite values
valid_mask = isfinite.(df.hessian_condition_number) .& (df.hessian_condition_number .> 0)
df_valid = df[valid_mask, :]
```

## Integration with Existing Workflows

### Notebook Integration

```julia
# In Jupyter notebooks
using CairoMakie
CairoMakie.activate!()

# Create all plots
figs = create_phase2_report(df_enhanced, save_plots=false)

# Display inline
for fig in figs
    display(fig)
end
```

### Batch Processing

```julia
function batch_phase2_analysis(functions::Vector, output_dir="phase2_results")
    mkpath(output_dir)
    
    for (i, f) in enumerate(functions)
        println("Processing function $i...")
        
        # Run analysis
        TR = test_input(f, dim=2)
        pol = Constructor(TR, 10)
        @polyvar x[1:2]
        real_pts = solve_polynomial_system(x, 2, 10, pol.coeffs)
        df = process_crit_pts(real_pts, f, TR)
        df_enhanced, _ = analyze_critical_points(f, df, TR)
        
        # Create visualizations
        figs = create_phase2_report(df_enhanced, save_plots=false)
        
        # Save plots
        save(joinpath(output_dir, "function_$(i)_norms.png"), figs[1])
        save(joinpath(output_dir, "function_$(i)_condition.png"), figs[2])
        save(joinpath(output_dir, "function_$(i)_eigenvals.png"), figs[3])
    end
end
```

## Troubleshooting

### Common Issues

1. **Empty plots**: Check that DataFrame has required columns
2. **Log scale errors**: Ensure positive values for log-scale axes
3. **Memory issues**: Consider subsampling for large datasets
4. **Backend conflicts**: Ensure only one Makie backend is active

### Performance Tips

- Use CairoMakie for static plots (faster rendering)
- Use GLMakie for interactive exploration
- Consider data decimation for very large datasets
- Cache computed plots for repeated analysis