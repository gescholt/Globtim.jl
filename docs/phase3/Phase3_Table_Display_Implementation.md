# Phase 3 Table Display Implementation Plan

## Overview

This document provides detailed pseudo code, architecture design, and implementation specifications for Phase 3 enhanced statistical table displays in Globtim's Phase 2 Hessian analysis.

**Primary Goal**: Create comprehensive, well-formatted statistical tables that integrate seamlessly with existing Phase 2 visualizations while providing rich statistical insights.

## Design Philosophy

### 1. **Build on Success**
- Leverage the successful ASCII histogram approach from existing implementations
- Extend the proven `analyze_critical_points` architecture
- Maintain backward compatibility with existing workflows

### 2. **Rich Statistical Content**
- Type-specific breakdowns (minimum, maximum, saddle, degenerate)  
- Comprehensive statistics beyond basic mean/std
- Quality assessments and mathematical validation
- Export-ready formatting for publications

### 3. **Flexible Integration**
- Multiple display options: console, alongside plots, separate exports
- Configurable formatting for different use cases
- Seamless integration with existing visualization functions

## Core Architecture

### Statistical Table Types

```julia
# Abstract base for all statistical tables
abstract type StatisticalTable end

# Core table implementations
struct HessianNormTable <: StatisticalTable
    statistics::DataFrame
    point_type::Symbol
    display_format::Symbol  # :compact, :detailed, :publication
    validation_results::Dict{String, Any}
end

struct ConditionNumberTable <: StatisticalTable  
    quality_breakdown::DataFrame
    recommendations::Vector{String}
    display_format::Symbol
end

struct EigenvalueValidationTable <: StatisticalTable
    validation_stats::DataFrame
    mathematical_checks::Dict{Symbol, Bool}
    display_format::Symbol
end

struct ComprehensiveStatsTable <: StatisticalTable
    combined_stats::DataFrame
    comparative_analysis::Dict{String, Any}
    display_format::Symbol
end
```

### Unified Table Rendering System

```julia
"""
    render_table(table::T; output=:console, width=80) where T <: StatisticalTable

Universal table rendering with format-specific output options.

# Arguments
- `table::StatisticalTable`: Table data structure to render
- `output::Symbol`: Output format (:console, :html, :latex, :markdown)
- `width::Int`: Console width for text formatting
- `precision::Int`: Decimal precision for numeric values

# Returns
- `String`: Formatted table string for specified output format
"""
function render_table(table::T; output=:console, width=80, precision=3) where T <: StatisticalTable
    if output == :console
        return render_console_table(table, width, precision)
    elseif output == :html
        return render_html_table(table, precision)
    elseif output == :latex
        return render_latex_table(table, precision)
    elseif output == :markdown
        return render_markdown_table(table, precision)
    else
        error("Unsupported output format: $output")
    end
end
```

## Core Statistical Functions

### 1. Type-Specific Statistics Computation

```julia
"""
    compute_type_specific_statistics(df::DataFrame, point_type::Symbol)

Compute comprehensive statistics for a specific critical point type.

# Enhanced Statistics Computed
- Basic: count, mean, std, median, min, max
- Robust: IQR (Q1, Q3), outlier count, outlier percentage  
- Quality: condition number classification, stability metrics
- Validation: eigenvalue sign consistency, mathematical correctness

# Returns
- `NamedTuple`: Comprehensive statistical summary
"""
function compute_type_specific_statistics(df::DataFrame, point_type::Symbol)
    # Filter data by critical point type
    type_mask = df.critical_point_type .== point_type
    type_data = df[type_mask, :]
    
    if nrow(type_data) == 0
        return create_empty_stats_summary(point_type)
    end
    
    # Extract key numerical columns
    hessian_norms = filter(!isnan, type_data.hessian_norm)
    condition_numbers = filter(x -> isfinite(x) && x > 0, type_data.hessian_condition_number)
    eigenval_mins = filter(!isnan, type_data.hessian_eigenvalue_min)
    eigenval_maxs = filter(!isnan, type_data.hessian_eigenvalue_max)
    
    # Compute comprehensive statistics
    stats = (
        # Basic counts and identification
        point_type = point_type,
        total_count = nrow(type_data),
        valid_hessian_count = length(hessian_norms),
        
        # Hessian norm statistics  
        hessian_norm_stats = compute_robust_statistics(hessian_norms),
        
        # Condition number analysis
        condition_stats = compute_condition_number_analysis(condition_numbers),
        
        # Eigenvalue statistics
        eigenvalue_stats = compute_eigenvalue_statistics(eigenval_mins, eigenval_maxs),
        
        # Mathematical validation
        validation_results = perform_mathematical_validation(type_data, point_type),
        
        # Quality assessment
        quality_metrics = assess_numerical_quality(type_data)
    )
    
    return stats
end

"""
    compute_robust_statistics(values::Vector{Float64})

Compute robust statistical measures including outlier detection.
"""
function compute_robust_statistics(values::Vector{Float64})
    if isempty(values)
        return create_empty_robust_stats()
    end
    
    # Basic statistics
    n = length(values)
    mean_val = mean(values)
    std_val = std(values)
    median_val = median(values)
    min_val = minimum(values)
    max_val = maximum(values)
    
    # Robust statistics
    q1 = quantile(values, 0.25)
    q3 = quantile(values, 0.75)
    iqr = q3 - q1
    
    # Outlier detection (1.5 * IQR rule)
    lower_fence = q1 - 1.5 * iqr
    upper_fence = q3 + 1.5 * iqr
    outliers = values[(values .< lower_fence) .| (values .> upper_fence)]
    outlier_count = length(outliers)
    outlier_percentage = round(100 * outlier_count / n, digits=1)
    
    return (
        count = n,
        mean = mean_val,
        std = std_val,
        median = median_val,
        min = min_val,
        max = max_val,
        q1 = q1,
        q3 = q3,
        iqr = iqr,
        outlier_count = outlier_count,
        outlier_percentage = outlier_percentage,
        range = max_val - min_val
    )
end

"""
    compute_condition_number_analysis(condition_numbers::Vector{Float64})

Classify condition numbers by quality and provide recommendations.
"""
function compute_condition_number_analysis(condition_numbers::Vector{Float64})
    if isempty(condition_numbers)
        return create_empty_condition_analysis()
    end
    
    n = length(condition_numbers)
    
    # Quality classification thresholds
    excellent = sum(condition_numbers .< 1e3)      # Well-conditioned
    good = sum(1e3 .<= condition_numbers .< 1e6)   # Acceptable  
    fair = sum(1e6 .<= condition_numbers .< 1e9)   # Marginal
    poor = sum(1e9 .<= condition_numbers .< 1e12)  # Poor
    critical = sum(condition_numbers .>= 1e12)     # Numerically unstable
    
    # Overall quality assessment
    well_conditioned_percentage = round(100 * (excellent + good) / n, digits=1)
    overall_quality = classify_overall_quality(well_conditioned_percentage)
    
    # Generate recommendations
    recommendations = generate_condition_recommendations(
        excellent, good, fair, poor, critical, n
    )
    
    return (
        total_count = n,
        excellent_count = excellent,
        good_count = good,
        fair_count = fair,
        poor_count = poor,
        critical_count = critical,
        well_conditioned_percentage = well_conditioned_percentage,
        overall_quality = overall_quality,
        recommendations = recommendations,
        quality_breakdown = create_quality_breakdown_dataframe(
            excellent, good, fair, poor, critical, n
        )
    )
end
```

### 2. Mathematical Validation Functions

Not a good name of function. We could compare the eigenvalues of the approximant and those of the objective function (like if the Hessian matrices are somehow close to each other?) 


```julia
"""
    perform_mathematical_validation(type_data::DataFrame, point_type::Symbol)

Perform mathematical validation of critical point classifications.
"""
function perform_mathematical_validation(type_data::DataFrame, point_type::Symbol)
    validation_results = Dict{String, Any}()
    
    if point_type == :minimum
        # For minima: all eigenvalues should be positive
        pos_eigenvals = filter(!isnan, type_data.smallest_positive_eigenval)
        if !isempty(pos_eigenvals)
            all_positive = all(λ -> λ > 1e-12, pos_eigenvals)
            validation_results["eigenvalue_signs_correct"] = all_positive
            validation_results["positive_eigenvalue_count"] = length(pos_eigenvals)
            validation_results["negative_eigenvalue_count"] = sum(pos_eigenvals .<= 1e-12)
        end
        
    elseif point_type == :maximum
        # For maxima: all eigenvalues should be negative
        neg_eigenvals = filter(!isnan, type_data.largest_negative_eigenval)
        if !isempty(neg_eigenvals)
            all_negative = all(λ -> λ < -1e-12, neg_eigenvals)
            validation_results["eigenvalue_signs_correct"] = all_negative
            validation_results["negative_eigenvalue_count"] = length(neg_eigenvals)
            validation_results["positive_eigenvalue_count"] = sum(neg_eigenvals .>= -1e-12)
        end
        
    elseif point_type == :saddle
        # For saddles: mixed eigenvalue signs expected
        min_eigenvals = filter(!isnan, type_data.hessian_eigenvalue_min)
        max_eigenvals = filter(!isnan, type_data.hessian_eigenvalue_max)
        
        if !isempty(min_eigenvals) && !isempty(max_eigenvals)
            has_negative = any(λ -> λ < -1e-12, min_eigenvals)
            has_positive = any(λ -> λ > 1e-12, max_eigenvals)
            validation_results["mixed_eigenvalue_signs"] = has_negative && has_positive
        end
    end
    
    # Determinant consistency check
    determinants = filter(!isnan, type_data.hessian_determinant)
    if !isempty(determinants)
        if point_type == :minimum
            validation_results["determinant_positive"] = all(det -> det > 1e-12, determinants)
        elseif point_type == :maximum && nrow(type_data) > 0
            # For maxima in even dimensions, determinant should be positive
            # For maxima in odd dimensions, determinant should be negative
            dim = length(type_data.coordinates[1]) # Assume coordinates available
            expected_det_sign = iseven(dim) ? 1 : -1
            validation_results["determinant_sign_consistent"] = all(
                det -> sign(det) == expected_det_sign, determinants
            )
        end
    end
    
    return validation_results
end
```

## Table Display Implementation

### 1. ASCII Console Tables

```julia
"""
    render_console_table(stats::NamedTuple, point_type::Symbol; width=80)

Create publication-quality ASCII tables for console display.
"""
function render_console_table(stats::NamedTuple, point_type::Symbol; width=80)
    title = "$(uppercase(string(point_type))) STATISTICS"
    table_width = min(width, 80)
    
    # Create table structure
    lines = String[]
    
    # Header
    push!(lines, "┌" * "─"^(table_width-2) * "┐")
    push!(lines, center_text("│", title, table_width-2) * "│")
    push!(lines, "├" * "─"^(table_width-2) * "┤")
    
    # Basic statistics section
    if stats.valid_hessian_count > 0
        push!(lines, format_table_row("Count", string(stats.total_count), table_width))
        push!(lines, format_table_row("Valid Hessians", string(stats.valid_hessian_count), table_width))
        
        hs = stats.hessian_norm_stats
        push!(lines, format_table_row("Mean ± Std", 
            "$(round(hs.mean, digits=3)) ± $(round(hs.std, digits=3))", table_width))
        push!(lines, format_table_row("Median (IQR)", 
            "$(round(hs.median, digits=3)) ($(round(hs.q1, digits=3))-$(round(hs.q3, digits=3)))", table_width))
        push!(lines, format_table_row("Range", 
            "[$(round(hs.min, digits=3)), $(round(hs.max, digits=3))]", table_width))
        push!(lines, format_table_row("Outliers", 
            "$(hs.outlier_count) ($(hs.outlier_percentage)%)", table_width))
    end
    
    # Condition number quality section
    if haskey(stats, :condition_stats) && !isempty(stats.condition_stats)
        push!(lines, "├" * "─"^(table_width-2) * "┤")
        push!(lines, center_text("│", "CONDITION NUMBER QUALITY", table_width-2) * "│")
        push!(lines, "├" * "─"^(table_width-2) * "┤")
        
        cs = stats.condition_stats
        push!(lines, format_table_row("Excellent (< 1e3)", 
            "$(cs.excellent_count) ($(round(100*cs.excellent_count/cs.total_count, digits=1))%)", table_width))
        push!(lines, format_table_row("Good (1e3-1e6)", 
            "$(cs.good_count) ($(round(100*cs.good_count/cs.total_count, digits=1))%)", table_width))
        push!(lines, format_table_row("Fair (1e6-1e9)", 
            "$(cs.fair_count) ($(round(100*cs.fair_count/cs.total_count, digits=1))%)", table_width))
        push!(lines, format_table_row("Poor (1e9-1e12)", 
            "$(cs.poor_count) ($(round(100*cs.poor_count/cs.total_count, digits=1))%)", table_width))
        push!(lines, format_table_row("Critical (≥ 1e12)", 
            "$(cs.critical_count) ($(round(100*cs.critical_count/cs.total_count, digits=1))%)", table_width))
        push!(lines, format_table_row("Overall Quality", cs.overall_quality, table_width))
    end
    
    # Mathematical validation section
    if haskey(stats, :validation_results) && !isempty(stats.validation_results)
        push!(lines, "├" * "─"^(table_width-2) * "┤")
        push!(lines, center_text("│", "MATHEMATICAL VALIDATION", table_width-2) * "│")
        push!(lines, "├" * "─"^(table_width-2) * "┤")
        
        vr = stats.validation_results
        for (key, value) in vr
            status_symbol = value === true ? "✓" : value === false ? "✗" : "~"
            display_key = format_validation_key(key)
            push!(lines, format_table_row(display_key, "$status_symbol $value", table_width))
        end
    end
    
    # Footer
    push!(lines, "└" * "─"^(table_width-2) * "┘")
    
    return join(lines, "\n")
end

"""
    format_table_row(label::String, value::String, width::Int)

Format a single table row with proper alignment and padding.
"""
function format_table_row(label::String, value::String, width::Int)
    max_label_width = div(width * 3, 5)  # 60% for label
    max_value_width = width - max_label_width - 4  # remaining for value
    
    # Truncate if necessary
    display_label = length(label) > max_label_width ? label[1:max_label_width-3] * "..." : label
    display_value = length(value) > max_value_width ? value[1:max_value_width-3] * "..." : value
    
    # Pad to alignment
    padded_label = rpad(display_label, max_label_width)
    padded_value = lpad(display_value, max_value_width)
    
    return "│ $padded_label │ $padded_value │"
end
```

### 2. Enhanced Integration Functions

```julia
"""
    analyze_critical_points_with_tables(f, df, TR; 
                                       enable_hessian=true,
                                       show_tables=true,
                                       table_format=:console,
                                       table_detail=:comprehensive,
                                       kwargs...)

Enhanced analyze_critical_points with integrated statistical table display.

# Table Options
- `show_tables::Bool`: Enable/disable table display  
- `table_format::Symbol`: :console, :html, :latex, :markdown
- `table_detail::Symbol`: :basic, :comprehensive, :publication
- `table_types::Vector{Symbol}`: Which point types to show tables for
- `table_width::Int`: Console table width
- `export_tables::Bool`: Save tables to files

# Returns  
- `DataFrame`: Enhanced DataFrame (same as original function)
- `DataFrame`: Minima DataFrame (same as original function)
- `Dict{Symbol, String}`: Rendered tables by critical point type (if show_tables=true)
"""
function analyze_critical_points_with_tables(f, df, TR; 
                                           enable_hessian=true,
                                           show_tables=true,
                                           table_format=:console,
                                           table_detail=:comprehensive,
                                           table_types=[:minimum, :maximum, :saddle],
                                           table_width=80,
                                           export_tables=false,
                                           export_prefix="critical_point_analysis",
                                           kwargs...)
    
    # Perform standard Phase 2 analysis
    df_enhanced, df_minima = analyze_critical_points(
        f, df, TR, enable_hessian=enable_hessian, kwargs...
    )
    
    # Generate tables if requested
    rendered_tables = Dict{Symbol, String}()
    
    if show_tables && enable_hessian
        for point_type in table_types
            # Compute type-specific statistics
            stats = compute_type_specific_statistics(df_enhanced, point_type)
            
            # Skip if no points of this type
            if stats.total_count == 0
                continue
            end
            
            # Render table in requested format
            table_string = render_statistical_table(
                stats, point_type, 
                format=table_format,
                detail=table_detail,
                width=table_width
            )
            
            rendered_tables[point_type] = table_string
            
            # Display immediately
            println("\n" * "="^table_width)
            println(table_string)
            println("="^table_width)
            
            # Export if requested
            if export_tables
                export_filename = "$(export_prefix)_$(point_type)_table.$(string(table_format))"
                write(export_filename, table_string)
                @info "Table exported: $export_filename"
            end
        end
        
        # Generate comparative summary if multiple types
        if length(rendered_tables) > 1
            comparative_table = create_comparative_summary_table(
                df_enhanced, collect(keys(rendered_tables)),
                format=table_format, width=table_width
            )
            rendered_tables[:comparative] = comparative_table
            
            println("\n" * "="^table_width)
            println("COMPARATIVE ANALYSIS")
            println("="^table_width) 
            println(comparative_table)
            println("="^table_width)
        end
    end
    
    return df_enhanced, df_minima, rendered_tables
end
```

### 3. Export and Integration Functions

```julia
"""
    export_analysis_tables(rendered_tables::Dict{Symbol, String}, 
                          base_filename::String;
                          formats=[:console, :markdown, :latex],
                          include_timestamp=true)

Export statistical tables in multiple formats for different use cases.
"""
function export_analysis_tables(rendered_tables::Dict{Symbol, String}, 
                               base_filename::String;
                               formats=[:console, :markdown, :latex],
                               include_timestamp=true)
    
    timestamp = include_timestamp ? "_$(Dates.format(now(), "yyyymmdd_HHMMSS"))" : ""
    
    for (point_type, table_content) in rendered_tables
        for format in formats
            extension = format == :console ? "txt" : string(format)
            filename = "$(base_filename)_$(point_type)$(timestamp).$(extension)"
            
            # Convert format if necessary
            if format != :console
                # Re-render in target format (assuming original was console)
                # This would require storing the original stats data
                @warn "Format conversion not yet implemented: $format"
                continue
            end
            
            write(filename, table_content)
            @info "Table exported: $filename"
        end
    end
end

"""
    create_comparative_summary_table(df::DataFrame, point_types::Vector{Symbol};
                                    format=:console, width=80)

Create a comparative analysis table showing statistics across critical point types.
"""
function create_comparative_summary_table(df::DataFrame, point_types::Vector{Symbol};
                                        format=:console, width=80)
    # Compute statistics for each type
    comparative_stats = DataFrame()
    
    for point_type in point_types
        stats = compute_type_specific_statistics(df, point_type)
        
        if stats.total_count > 0
            row = DataFrame(
                Type = [string(point_type)],
                Count = [stats.total_count],
                Hessian_Mean = [round(stats.hessian_norm_stats.mean, digits=3)],
                Hessian_Std = [round(stats.hessian_norm_stats.std, digits=3)],
                Well_Conditioned_Pct = [round(stats.condition_stats.well_conditioned_percentage, digits=1)],
                Validation_Pass = [get(stats.validation_results, "eigenvalue_signs_correct", "N/A")]
            )
            comparative_stats = vcat(comparative_stats, row)
        end
    end
    
    # Render as formatted table
    if format == :console
        return render_comparative_console_table(comparative_stats, width)
    else
        return render_comparative_table_other_formats(comparative_stats, format)
    end
end
```

## Usage Examples

### Basic Usage
```julia
# Standard Phase 2 analysis with enhanced tables
f = Deuflhard
TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.2)
pol = Constructor(TR, 8)
@polyvar x[1:2]
solutions = solve_polynomial_system(x, 2, 8, pol.coeffs)
df = process_crit_pts(solutions, f, TR)

# Enhanced analysis with integrated tables
df_enhanced, df_min, tables = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true,
    table_format=:console,
    table_detail=:comprehensive
)
```

### Advanced Usage
```julia
# Publication-ready analysis with multiple export formats
df_enhanced, df_min, tables = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true,
    table_format=:console,        # Display format
    table_detail=:publication,    # Detail level
    table_types=[:minimum, :maximum, :saddle],
    export_tables=true,
    export_prefix="publication_analysis"
)

# Export in multiple formats
export_analysis_tables(tables, "critical_point_analysis", 
                      formats=[:console, :markdown, :latex])
```

## Implementation Timeline

### Phase 3.1: Core Table Infrastructure (Days 1-2)
- [ ] Implement `StatisticalTable` type hierarchy  
- [ ] Create `compute_type_specific_statistics` function
- [ ] Build `render_console_table` with ASCII formatting
- [ ] Add basic integration to `analyze_critical_points`

### Phase 3.2: Enhanced Features (Days 3-4)  
- [ ] Implement mathematical validation functions
- [ ] Add condition number quality analysis
- [ ] Create comparative summary tables
- [ ] Build export functionality

### Phase 3.3: Integration and Testing (Day 5)
- [ ] Update existing examples to showcase tables
- [ ] Add comprehensive unit tests
- [ ] Update documentation and CLAUDE.md
- [ ] Performance optimization

## Testing Strategy

### Unit Tests
```julia
@testset "Statistical Table Generation" begin
    # Test basic statistics computation
    test_df = create_test_dataframe_with_hessian_data()
    stats = compute_type_specific_statistics(test_df, :minimum)
    @test stats.total_count > 0
    @test haskey(stats, :hessian_norm_stats)
    
    # Test table rendering
    table_str = render_console_table(stats, :minimum)
    @test contains(table_str, "MINIMUM STATISTICS")
    @test contains(table_str, "Mean ± Std")
end
```

### Integration Tests  
```julia
@testset "Enhanced Analysis Integration" begin
    f = simple_quadratic_2d
    TR = test_input(f, dim=2)
    pol = Constructor(TR, 6)
    @polyvar x[1:2]
    solutions = solve_polynomial_system(x, 2, 6, pol.coeffs)
    df = process_crit_pts(solutions, f, TR)
    
    # Test enhanced analysis
    df_enhanced, df_min, tables = analyze_critical_points_with_tables(
        f, df, TR, enable_hessian=true, show_tables=true
    )
    
    @test !isempty(tables)
    @test haskey(tables, :minimum)
end
```

## File Structure

### New Files
- `src/statistical_tables.jl` - Core table implementation
- `src/table_rendering.jl` - Display and formatting functions  
- `Examples/phase3_table_demos.jl` - Usage demonstrations
- `test/test_statistical_tables.jl` - Comprehensive test suite

### Modified Files
- `src/hessian_analysis.jl` - Add table integration hooks
- `src/Globtim.jl` - Export new table functions
- `CLAUDE.md` - Update with table usage examples

This implementation plan provides a solid foundation for implementing comprehensive statistical tables that enhance Phase 2 Hessian analysis with rich, well-formatted statistical insights.