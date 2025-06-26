# Phase 2 Visualization Improvement Plan

## Overview
Enhance Phase 2 Hessian analysis visualization by creating dedicated statistical graphs for local minima and maxima with optimized scaling and domain-specific analysis.

## Current State Analysis

### Existing Visualization Functions
- `plot_hessian_norms(df_enhanced)` - General scatter plot of Frobenius norms
- `plot_condition_numbers(df_enhanced)` - Log-scale condition numbers for all points
- `plot_critical_eigenvalues(df_enhanced)` - Combined minima/maxima eigenvalue plot

### Current Limitations
- Mixed scales make it difficult to analyze minima vs maxima separately
- Condition numbers spanning many orders of magnitude obscure patterns
- Single plots combine different critical point types with incompatible value ranges
- No domain-specific statistical analysis for different critical point types

## Proposed Improvements

### 1. Separate Minima/Maxima Statistical Graphs

This section provides detailed pseudo code, documentation, and integration specifications for creating type-specific statistical visualizations with enhanced table displays.

#### 1.1 Split Hessian Norm Analysis

**Current State**: Single scatter plot combining all critical point types with mixed scaling issues.

**Proposed Enhancement**: Type-specific analysis with adaptive scaling and statistical tables.

##### 1.1.1 Function Specification

```julia
"""
    plot_hessian_norms_by_type(df::DataFrame, point_type::Symbol; 
                              show_table=true, table_position=:right, kwargs...)

Create focused Hessian norm analysis for specific critical point types with integrated statistical tables.

# Arguments
- `df::DataFrame`: Enhanced DataFrame with Phase 2 Hessian analysis
- `point_type::Symbol`: Critical point type (:minimum, :maximum, :saddle, :degenerate)
- `show_table::Bool=true`: Display statistical summary table alongside plot
- `table_position::Symbol=:right`: Table position (:right, :bottom, :separate)
- `adaptive_scaling::Bool=true`: Use type-specific axis scaling
- `highlight_outliers::Bool=true`: Mark statistical outliers
- `color_scheme::Symbol=:viridis`: Color scheme for the plot

# Returns
- `Figure`: Makie figure with plot and optional integrated table
- `Dict`: Statistical summary data for programmatic access

# Statistical Table Contents
- Count: Number of points of specified type
- Mean ± Std: Average Hessian norm with standard deviation  
- Median (IQR): Median with interquartile range
- Min/Max: Extreme values
- Outliers: Count of statistical outliers (>3σ)
- Stability: Percentage of well-conditioned points
"""
function plot_hessian_norms_by_type(df::DataFrame, point_type::Symbol; 
                                   show_table=true, table_position=:right, kwargs...)
    # Filter data by critical point type
    type_mask = df.critical_point_type .== point_type
    filtered_df = df[type_mask, :]
    
    # Handle empty data case
    if nrow(filtered_df) == 0
        return create_empty_plot_with_message("No $(point_type) points found")
    end
    
    # Extract Hessian norms for analysis
    hessian_norms = filtered_df.hessian_norm
    valid_norms = filter(!isnan, hessian_norms)
    
    # Compute comprehensive statistics
    stats = compute_comprehensive_statistics(valid_norms, point_type)
    
    # Create adaptive scaling
    axis_config = create_adaptive_axis_config(valid_norms, point_type)
    
    # Generate main plot
    fig = Figure(resolution=(show_table ? (1000, 600) : (600, 600)))
    
    if show_table && table_position == :right
        ax_plot = Axis(fig[1, 1], title="$(title_case(point_type)) Hessian Norms")
        ax_table = fig[1, 2]  # Table area
    elseif show_table && table_position == :bottom
        ax_plot = Axis(fig[1, 1], title="$(title_case(point_type)) Hessian Norms")
        ax_table = fig[2, 1]  # Table area
    else
        ax_plot = Axis(fig[1, 1], title="$(title_case(point_type)) Hessian Norms")
    end
    
    # Create scatter plot with outlier highlighting
    create_enhanced_scatter_plot!(ax_plot, filtered_df, stats, axis_config)
    
    # Add statistical overlays
    add_statistical_overlays!(ax_plot, stats)
    
    # Create and position statistical table
    if show_table
        table_data = create_statistical_table(stats, point_type)
        render_statistical_table!(ax_table, table_data)
    end
    
    return fig, stats
end
```

##### 1.1.2 Statistical Table Structure

```julia
# Statistical summary table data structure
struct HessianStatistics
    point_type::Symbol
    count::Int
    mean::Float64
    std::Float64
    median::Float64
    q25::Float64
    q75::Float64
    minimum::Float64
    maximum::Float64
    outlier_count::Int
    stability_percentage::Float64
    distribution_type::String  # "normal", "log-normal", "bimodal", etc.
end
```

**Table Display Format**:
```
┌─────────────────────────────────────┐
│         MINIMA STATISTICS           │
├─────────────────┬───────────────────┤
│ Metric          │ Value             │
├─────────────────┼───────────────────┤
│ Count           │ 25                │
│ Mean ± Std      │ 12.34 ± 3.45      │
│ Median (IQR)    │ 11.20 (8.9-14.1)  │
│ Range           │ [2.1, 24.7]       │
│ Outliers        │ 2 (8.0%)          │
│ Well-Conditioned│ 23 (92.0%)        │
│ Distribution    │ Log-normal        │
└─────────────────┴───────────────────┘
```

#### 1.2 Domain-Specific Condition Number Analysis

##### 1.2.1 Enhanced Condition Number Function

```julia
"""
    plot_condition_numbers_by_type(df::DataFrame, point_type::Symbol;
                                  log_scale=true, show_breakdown=true, kwargs...)

Analyze condition numbers with type-specific scaling and detailed breakdown tables.

# Enhanced Features
- Automatic log/linear scale detection based on data range
- Condition number quality classification (excellent, good, fair, poor, singular)
- Stability risk assessment and recommendations
- Comparative analysis with other critical point types

# Table Integration
- Quality breakdown table showing condition number ranges
- Risk assessment matrix
- Recommendations for numerical stability improvement
"""
function plot_condition_numbers_by_type(df::DataFrame, point_type::Symbol; kwargs...)
    # Filter and validate data
    filtered_df = filter_by_type_with_validation(df, point_type)
    condition_numbers = filtered_df.hessian_condition_number
    
    # Classify condition numbers by quality
    quality_classification = classify_condition_quality(condition_numbers)
    
    # Create enhanced visualization with quality regions
    fig = create_condition_number_plot_with_regions(filtered_df, quality_classification)
    
    # Generate breakdown table
    breakdown_table = create_condition_breakdown_table(quality_classification, point_type)
    
    return fig, breakdown_table
end
```

**Condition Number Quality Classification**:
```julia
function classify_condition_quality(cond_nums::Vector{Float64})
    return map(cond_nums) do κ
        if isnan(κ) || isinf(κ)
            :singular
        elseif κ < 1e3
            :excellent  # Well-conditioned
        elseif κ < 1e6
            :good      # Acceptable
        elseif κ < 1e9
            :fair      # Marginal
        elseif κ < 1e12
            :poor      # Poorly conditioned
        else
            :critical  # Numerically unstable
        end
    end
end
```

**Condition Number Breakdown Table**:
```
┌─────────────────────────────────────────────────────────┐
│              CONDITION NUMBER ANALYSIS                  │
├─────────────┬───────┬─────────┬────────────────────────┤
│ Quality     │ Count │ Percent │ Range                  │
├─────────────┼───────┼─────────┼────────────────────────┤
│ Excellent   │  15   │  60.0%  │ [1.2, 856]            │
│ Good        │   7   │  28.0%  │ [1.1e3, 4.2e5]        │
│ Fair        │   2   │   8.0%  │ [2.3e6, 1.1e8]        │
│ Poor        │   1   │   4.0%  │ [3.4e9]                │
│ Critical    │   0   │   0.0%  │ -                      │
│ Singular    │   0   │   0.0%  │ -                      │
├─────────────┴───────┴─────────┴────────────────────────┤
│ Recommendations:                                        │
│ • 88% of points are numerically stable                  │
│ • Consider higher precision for 1 poorly conditioned   │
│ • Overall numerical quality: GOOD                       │
└─────────────────────────────────────────────────────────┘
```

#### 1.3 Enhanced Eigenvalue Visualization

##### 1.3.1 Comprehensive Eigenvalue Analysis

```julia
"""
    plot_eigenvalue_analysis_by_type(df::DataFrame, point_type::Symbol;
                                    show_distribution=true, show_correlations=true, kwargs...)

Comprehensive eigenvalue analysis with distribution plots and correlation tables.

# Multi-Panel Layout
- Main scatter plot: eigenvalues vs function values
- Distribution histogram: eigenvalue frequency analysis  
- Correlation matrix: relationships between eigenvalue properties
- Statistical summary table: comprehensive eigenvalue statistics

# Table Integration Features
- Eigenvalue range analysis by critical point type
- Stability indicators based on eigenvalue magnitudes
- Correlation strength table between different Hessian properties
- Mathematical validation results (positive definiteness for minima, etc.)
"""
function plot_eigenvalue_analysis_by_type(df::DataFrame, point_type::Symbol; kwargs...)
    # Comprehensive data preparation
    filtered_df, eigenvalue_data = prepare_eigenvalue_analysis_data(df, point_type)
    
    # Create multi-panel layout
    fig = Figure(resolution=(1200, 800))
    
    # Main eigenvalue plot
    ax_main = Axis(fig[1, 1:2], title="$(title_case(point_type)) Eigenvalue Analysis")
    create_eigenvalue_scatter_plot!(ax_main, eigenvalue_data)
    
    # Distribution histogram
    ax_hist = Axis(fig[1, 3], title="Distribution")
    create_eigenvalue_histogram!(ax_hist, eigenvalue_data)
    
    # Statistical table
    ax_table = fig[2, 1:2]
    eigenvalue_stats = compute_eigenvalue_statistics(eigenvalue_data, point_type)
    render_eigenvalue_table!(ax_table, eigenvalue_stats)
    
    # Correlation matrix
    ax_corr = fig[2, 3]
    correlation_data = compute_hessian_correlations(filtered_df)
    render_correlation_matrix!(ax_corr, correlation_data)
    
    return fig, eigenvalue_stats, correlation_data
end
```

**Eigenvalue Statistics Table**:
```
┌─────────────────────────────────────────────────────────────────────┐
│                    EIGENVALUE ANALYSIS - MINIMA                     │
├─────────────────────┬─────────────┬─────────────┬──────────────────┤
│ Property            │ Min         │ Max         │ Mean ± Std       │
├─────────────────────┼─────────────┼─────────────┼──────────────────┤
│ Smallest Eigenvalue │ 0.0234      │ 4.567       │ 1.23 ± 0.89      │
│ Largest Eigenvalue  │ 2.145       │ 23.45       │ 8.91 ± 4.56      │
│ Condition Number    │ 12.3        │ 1.2e4       │ 486 ± 2.1e3     │
│ Determinant         │ 0.0456      │ 124.5       │ 12.4 ± 23.1     │
│ Trace               │ 4.567       │ 45.67       │ 18.2 ± 8.9      │
├─────────────────────┴─────────────┴─────────────┴──────────────────┤
│ Validation Results:                                                 │
│ • Positive Definite: 23/25 (92%) ✓                                │
│ • Mathematical Minima: 23/25 (92%) ✓                              │
│ • Numerical Stability: 21/25 (84%) ✓                              │
│ • Eigenvalue Confidence: HIGH                                       │
└─────────────────────────────────────────────────────────────────────┘
```

#### 1.4 Integration Strategy for Table Displays

##### 1.4.1 Unified Table Display System

```julia
# Central table rendering system
abstract type StatisticalTable end

struct HessianNormTable <: StatisticalTable
    data::HessianStatistics
    format::Symbol  # :compact, :detailed, :publication
end

struct ConditionTable <: StatisticalTable
    quality_breakdown::Dict{Symbol, Int}
    recommendations::Vector{String}
    format::Symbol
end

struct EigenvalueTable <: StatisticalTable
    statistics::DataFrame
    validation_results::Dict{String, Any}
    format::Symbol
end

# Unified rendering interface
function render_table!(ax, table::T) where T <: StatisticalTable
    dispatch_table_render(ax, table)
end
```

##### 1.4.2 Table Integration Options

**Option 1: Side-by-Side Layout**
```julia
# Plot on left, table on right
fig = Figure(resolution=(1200, 600))
ax_plot = Axis(fig[1, 1])
ax_table = fig[1, 2]  # Table gets 30% of width
```

**Option 2: Stacked Layout**
```julia
# Plot on top, table on bottom
fig = Figure(resolution=(800, 800))
ax_plot = Axis(fig[1, 1])
ax_table = fig[2, 1]  # Table gets 25% of height
```

**Option 3: Tabbed Interface**
```julia
# Interactive tabs for plot vs table view
function create_tabbed_analysis(df, point_type)
    return create_interactive_tabs([
        ("Plot", create_plot_panel),
        ("Statistics", create_table_panel),
        ("Export", create_export_panel)
    ])
end
```

**Option 4: Overlay Tables**
```julia
# Semi-transparent table overlay on plot
function add_overlay_table!(ax, stats, position=:topright)
    table_box = create_translucent_table_box(stats, position)
    add_to_axis!(ax, table_box)
end
```

#### 1.5 Enhanced User Interface Functions

##### 1.5.1 Master Analysis Function

```julia
"""
    analyze_critical_points_enhanced(df::DataFrame, point_types=[:minimum, :maximum];
                                   table_layout=:side_by_side, export_format=:png, kwargs...)

Create comprehensive analysis dashboard for multiple critical point types with integrated tables.

# Features
- Multi-type comparative analysis
- Flexible table positioning and formatting
- Export capabilities for publications
- Interactive exploration options
- Statistical significance testing between types

# Table Layout Options
- `:side_by_side`: Tables alongside plots
- `:stacked`: Tables below plots  
- `:tabbed`: Interactive tab interface
- `:overlay`: Semi-transparent overlays
- `:separate`: Separate table-only figures
"""
function analyze_critical_points_enhanced(df::DataFrame, point_types=[:minimum, :maximum]; 
                                        table_layout=:side_by_side, kwargs...)
    results = Dict{Symbol, Any}()
    
    for point_type in point_types
        # Generate all analysis types for this point type
        hessian_result = plot_hessian_norms_by_type(df, point_type; show_table=true, kwargs...)
        condition_result = plot_condition_numbers_by_type(df, point_type; show_table=true, kwargs...)
        eigenvalue_result = plot_eigenvalue_analysis_by_type(df, point_type; show_table=true, kwargs...)
        
        results[point_type] = Dict(
            :hessian_analysis => hessian_result,
            :condition_analysis => condition_result,
            :eigenvalue_analysis => eigenvalue_result
        )
    end
    
    # Create comparative summary
    comparative_summary = create_comparative_analysis(results, point_types)
    
    return results, comparative_summary
end
```

##### 1.5.2 Export and Publication Support

```julia
"""
    export_analysis_with_tables(analysis_results, filename_base::String;
                               format=:publication, resolution=(1200, 800))

Export analysis results with properly formatted tables for publication.

# Export Formats
- `:publication`: High-resolution, publication-ready formatting
- `:presentation`: Optimized for slides and presentations  
- `:interactive`: HTML export with interactive tables
- `:data`: Raw data export in CSV/JSON format
"""
function export_analysis_with_tables(results, filename_base; format=:publication, kwargs...)
    for (point_type, analyses) in results
        export_individual_analysis(analyses, "$(filename_base)_$(point_type)", format)
    end
    
    # Export comparative summary
    export_comparative_summary(results, "$(filename_base)_comparative", format)
end
```

This expanded design provides:

1. **Detailed pseudo code** for each visualization function
2. **Comprehensive table structures** with statistical breakdowns
3. **Multiple integration options** for table display
4. **Unified rendering system** for consistent table formatting
5. **Enhanced user interface** with flexible layout options
6. **Export capabilities** for different use cases

The table displays integrate seamlessly with the plots while providing rich statistical insights that complement the visual analysis.

### 2. Statistical Enhancement Features

#### 2.1 Adaptive Scaling System
```julia
# Automatic scale detection for different critical point types
function detect_optimal_scale(values::Vector{Float64}, point_type::Symbol)
    # Returns optimal axis limits and tick spacing
end
```

#### 2.2 Statistical Overlays
- Box plots showing quartile distributions
- Regression lines for correlation analysis
- Confidence intervals for eigenvalue ranges
- Outlier detection and highlighting

#### 2.3 Comparative Analysis
- Side-by-side minima vs maxima comparisons
- Statistical significance testing between groups
- Correlation matrices for Hessian properties

### 3. Implementation Plan

#### Phase 3.1: Core Separation Functions
**Priority**: High
**Timeline**: 1-2 days

1. **Create separated plotting functions**
   - `plot_hessian_norms_by_type(df, point_type::Symbol)`
   - `plot_condition_numbers_by_type(df, point_type::Symbol)`
   - `plot_eigenvalues_by_type(df, point_type::Symbol)`

2. **Implement adaptive scaling**
   - Automatic axis limit detection per critical point type
   - Intelligent tick spacing based on data distribution
   - Outlier-robust scaling options

3. **Add statistical overlays**
   - Median lines and quartile boxes
   - Distribution histograms as marginal plots
   - Basic correlation trend lines

#### Phase 3.2: Enhanced Statistical Analysis
**Priority**: Medium
**Timeline**: 2-3 days

1. **Advanced statistical features**
   - Eigenvalue distribution analysis
   - Correlation matrices between Hessian properties
   - Statistical significance testing

2. **Comparative visualization**
   - Side-by-side comparison plots
   - Difference visualization (minima - maxima properties)
   - Ratio analysis where appropriate

3. **Interactive features**
   - Zoom functionality for detailed analysis
   - Point selection and highlighting
   - Linked plots for multi-view analysis

#### Phase 3.3: Documentation and Examples
**Priority**: Medium
**Timeline**: 1 day

1. **Update visualization documentation**
   - Add new functions to CLAUDE.md
   - Update DataFrame column reference
   - Create comprehensive examples

2. **Add example notebooks**
   - Demonstrate separated analysis workflow
   - Show before/after visualization improvements
   - Statistical interpretation guides

### 4. Technical Specifications

#### 4.1 Function Signatures
```julia
# Separated analysis functions
plot_hessian_norms_minima(df::DataFrame; kwargs...)
plot_hessian_norms_maxima(df::DataFrame; kwargs...)
plot_condition_numbers_minima(df::DataFrame; kwargs...)
plot_condition_numbers_maxima(df::DataFrame; kwargs...)
plot_eigenvalue_analysis_minima(df::DataFrame; kwargs...)
plot_eigenvalue_analysis_maxima(df::DataFrame; kwargs...)

# Comparative analysis functions
plot_comparative_hessian_analysis(df::DataFrame; kwargs...)
plot_minima_vs_maxima_statistics(df::DataFrame; kwargs...)
```

#### 4.2 Scaling Algorithm
```julia
function adaptive_scale(values::Vector{Float64}, point_type::Symbol)
    # Remove outliers beyond 3 standard deviations
    # Compute robust statistics (median, IQR)
    # Set axis limits based on data distribution
    # Return optimized axis configuration
end
```

#### 4.3 Statistical Overlay System
```julia
function add_statistical_overlays!(plt, values::Vector{Float64})
    # Add median line
    # Add quartile boxes
    # Add distribution histogram as marginal
    # Add trend line if correlation exists
end
```

### 5. File Structure

#### New Files
- `src/hessian_visualization_enhanced.jl` - Enhanced visualization functions
- `Examples/phase2_visualization_demo.jl` - Demonstration examples
- `test/test_enhanced_visualization.jl` - Test suite for new functions

#### Modified Files
- `src/hessian_visualization.jl` - Keep existing functions, add new ones
- `src/Globtim.jl` - Export new visualization functions
- `CLAUDE.md` - Update visualization documentation
- `docs/DATAFRAME_COLUMNS.md` - Add visualization function references

### 6. Testing Strategy

#### 6.1 Unit Tests
- Test adaptive scaling with various data distributions
- Verify statistical overlay accuracy
- Check edge cases (all minima, all maxima, mixed types)

#### 6.2 Integration Tests
- Test with real optimization problems
- Verify performance with large datasets
- Test visual consistency across different backends

#### 6.3 Visual Validation
- Generate before/after comparison plots
- Validate statistical accuracy of overlays
- Ensure color schemes work for accessibility

### 7. Success Metrics

#### 7.1 Functionality Metrics
- [ ] Separate minima/maxima plots with appropriate scaling
- [ ] Statistical overlays show correct quartiles and medians
- [ ] Adaptive scaling works for different data ranges
- [ ] Comparative analysis functions provide meaningful insights

#### 7.2 Usability Metrics
- [ ] Plots are more readable than current combined versions
- [ ] Statistical patterns are easier to identify
- [ ] Documentation enables users to choose appropriate plot types
- [ ] Examples demonstrate clear workflow improvements

#### 7.3 Performance Metrics
- [ ] Plotting functions handle large datasets efficiently
- [ ] Memory usage remains reasonable for enhanced plots
- [ ] Rendering time is acceptable for interactive use

### 8. Dependencies

#### 8.1 Required Packages
- CairoMakie.jl / GLMakie.jl (existing)
- Statistics.jl (existing)
- StatsBase.jl (for robust statistics)

#### 8.2 Optional Enhancements
- PlotlyJS.jl (for interactive features)
- StatsPlots.jl (for statistical overlays)
- Colors.jl (for enhanced color schemes)

### 9. Backward Compatibility

#### 9.1 Maintaining Existing Functions
- Keep all current visualization functions unchanged
- Mark as "basic" versions in documentation
- Provide migration guide to enhanced versions

#### 9.2 Deprecation Strategy
- No immediate deprecation of existing functions
- Add "enhanced" versions alongside existing ones
- Update examples to use enhanced versions
- Provide clear upgrade path in documentation

### 10. Future Extensions

#### 10.1 Advanced Statistical Analysis
- Principal component analysis of Hessian properties
- Clustering analysis of critical point characteristics
- Machine learning classification of critical point quality

#### 10.2 Interactive Dashboards
- Web-based interactive visualization
- Real-time parameter adjustment
- Collaborative analysis features

#### 10.3 Export and Reporting
- Publication-ready figure export
- Automated statistical report generation
- Integration with scientific notebook formats

---

## Implementation Priority Order

1. **Phase 3.1**: Core separation functions (High Priority)
2. **Phase 3.2**: Enhanced statistical analysis (Medium Priority)  
3. **Phase 3.3**: Documentation and examples (Medium Priority)

## Estimated Timeline
- **Total Duration**: 4-6 days
- **Core Functionality**: 2-3 days
- **Enhancement Features**: 2-3 days
- **Documentation**: 1 day

## Next Steps
1. Review and approve this plan
2. Begin implementation with Phase 3.1 core functions
3. Create test framework for new visualization functions
4. Implement adaptive scaling system
5. Add statistical overlay capabilities