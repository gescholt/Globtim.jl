# Revised Global Domain Integration Plan for V4 Analysis

## Overview
After reviewing the actual V4 implementation, this revised plan corrects inconsistencies and provides an accurate approach for adding global domain analysis alongside the existing 16-subdomain analysis.

## Current V4 Implementation Facts

### Domain Specification
- **Actual domain**: Stretched (+,-,+,-) orthant 
- **Coordinates**: `[-0.1, 1.1] × [-1.1, 0.1] × [-0.1, 1.1] × [-1.1, 0.1]`
- **Stretching**: 0.1 on each side to ensure all theoretical minimizers are included
- **Function**: `deuflhard_4d_composite(x) = Deuflhard([x₁,x₂]) + Deuflhard([x₃,x₄])`

### Subdomain Structure
- **16 subdomains** already implemented (2^4 binary subdivision)
- Each subdomain has binary label: "0000", "0001", ..., "1111"
- Subdomain centers are computed with 0.3 range (half of 0.6)

### Existing Analysis Pipeline
```julia
run_v4_enhanced()
  ↓
run_enhanced_analysis_with_refinement(analyze_global=false)  # hardcoded!
  ↓
For each subdomain:
  - Constructor with tolerance=0.0007
  - solve_polynomial_system
  - analyze_critical_points (BFGS refinement)
  - Collect df_cheb and df_min_refined
```

## Revised Integration Plan

### Phase 1: Enable Global Analysis in Existing Function

The key change is to make the existing `analyze_global` parameter functional:

#### 1.1 Modify `run_enhanced_analysis_with_refinement`
```julia
# In src/run_analysis_with_refinement.jl
function run_enhanced_analysis_with_refinement(
    degrees::Vector{Int}, 
    GN::Int;
    analyze_global::Bool = false,  # Make this parameter functional
    threshold::Float64 = 0.1,
    tol_dist::Float64 = 0.05
)
    # ... existing imports ...
    
    # Define both domains
    subdomain_list = SubdomainManagement.generate_16_subdivisions_orthant()
    
    # Global domain definition (full stretched orthant)
    global_domain = (
        center = [0.5, -0.5, 0.5, -0.5],
        sample_range = 0.6  # covers [-0.1,1.1] × [-1.1,0.1] × ...
    )
    
    # Storage for both analyses
    all_results = Dict()
    
    # Existing subdomain analysis
    if !analyze_global || analyze_global  # Always do subdomain analysis
        # ... existing subdomain code ...
        all_results[:subdomain] = (existing results)
    end
    
    # NEW: Global domain analysis
    if analyze_global
        println("\n" * "="^80)
        println("🌍 ANALYZING GLOBAL DOMAIN")
        println("="^80)
        
        global_l2_data = Dict{Int, Float64}()
        global_critical_points = Dict{Int, DataFrame}()
        global_min_refined = Dict{Int, DataFrame}()
        
        for degree in degrees
            println("\n📊 Processing global domain - Degree $degree")
            
            # Create polynomial approximation for full domain
            TR = test_input(deuflhard_4d_composite, 
                          dim=4,
                          center=global_domain.center, 
                          sample_range=global_domain.sample_range,
                          tolerance=0.0007)
            
            pol = Constructor(TR, degree, GN=GN, verbose=false)
            
            # Get L2 norm
            global_l2_data[degree] = pol.L2_norm
            
            # Solve polynomial system
            @polyvar x[1:4]
            crit_pts = solve_polynomial_system(x, 4, pol.degree, pol.coeffs, verbose=false)
            
            # Process critical points
            df_global = process_crit_pts(crit_pts, deuflhard_4d_composite, TR)
            
            # Classify and refine
            df_classified = classify_critical_points(df_global, deuflhard_4d_composite)
            df_analyzed = analyze_critical_points(df_classified, deuflhard_4d_composite)
            
            # Filter minima
            df_min_refined_global = df_analyzed[df_analyzed.point_type .== "min", :]
            
            # Add global label
            df_global[!, :subdomain] .= "GLOBAL"
            df_min_refined_global[!, :subdomain] .= "GLOBAL"
            
            # Store results
            global_critical_points[degree] = df_global
            global_min_refined[degree] = df_min_refined_global
        end
        
        all_results[:global] = (
            l2_data = global_l2_data,
            critical_points = global_critical_points,
            min_refined_points = global_min_refined
        )
    end
    
    # Return comprehensive results
    if analyze_global
        return (
            # Subdomain results
            l2_data = l2_data_by_degree_by_subdomain,
            distance_data = distance_data_by_degree,
            subdomain_distance_data = subdomain_distance_data_by_degree,
            all_critical_points = all_critical_points_with_labels,
            all_min_refined_points = all_min_refined_points,
            # Global results
            global_l2_data = all_results[:global].l2_data,
            global_critical_points = all_results[:global].critical_points,
            global_min_refined_points = all_results[:global].min_refined_points
        )
    else
        # Original return (backward compatible)
        return (
            l2_data = l2_data_by_degree_by_subdomain,
            distance_data = distance_data_by_degree,
            subdomain_distance_data = subdomain_distance_data_by_degree,
            all_critical_points = all_critical_points_with_labels,
            all_min_refined_points = all_min_refined_points
        )
    end
end
```

### Phase 2: Update Main Function

#### 2.1 Modify `run_v4_enhanced` in `run_v4_analysis_function.jl`
```julia
function run_v4_enhanced(; 
    degrees=[3,4], 
    GN=20, 
    output_dir=nothing,
    include_global=false  # NEW parameter
)
    # ... existing setup code ...
    
    # Pass through the global analysis flag
    analysis_results = run_enhanced_analysis_with_refinement(
        degrees, GN,
        analyze_global=include_global,  # Now actually used!
        threshold=0.1,
        tol_dist=0.05
    )
    
    # Handle global results if present
    global_l2_data = nothing
    global_tables_v4 = nothing
    
    if include_global && haskey(analysis_results, :global_l2_data)
        # Process global L2 data
        global_l2_data = analysis_results.global_l2_data
        
        # Generate V4 tables for global domain
        if haskey(analysis_results, :global_critical_points)
            # Create a single "GLOBAL" theoretical point table
            global_tables_v4 = generate_theoretical_point_tables(
                theoretical_points,
                theoretical_types,
                analysis_results.global_critical_points,
                degrees,
                [(label="GLOBAL", center=global_domain.center, range=0.6)],
                (pt, domain) -> true  # All points belong to global domain
            )
        end
    end
    
    # Update plotting data to include global results
    plot_data = Dict(
        "subdomain_tables" => subdomain_tables_v4,
        "degrees" => degrees,
        "l2_data" => l2_data,
        "distance_data" => distance_data,
        "subdomain_distance_data" => subdomain_distance_data,
        "all_min_refined_points" => all_min_refined_points,
        "refinement_metrics" => refinement_summary,
        "refined_to_cheb_distances" => refined_to_cheb_distances,
        # NEW: Global data
        "global_l2_data" => global_l2_data,
        "global_tables" => global_tables_v4
    )
    
    # ... rest of function ...
end
```

### Phase 3: Update Plotting Functions

Most plotting functions already have infrastructure for global data:

1. **`plot_v4_l2_convergence`** - Already accepts `global_l2_by_degree` ✓
2. **`plot_v4_distance_convergence`** - Need to add global distance traces
3. **`plot_critical_point_distance_evolution`** - Can include global table

### Phase 4: Expected Output Structure

```
outputs/enhanced_HH-MM/
├── subdomain_0000_v4.csv     # Existing subdomain tables
├── subdomain_0001_v4.csv
├── ...
├── subdomain_1111_v4.csv
├── global_v4.csv             # NEW: Global domain table
├── refinement_summary.csv     # Existing
├── refinement_summary_global.csv  # NEW: Global refinement metrics
├── v4_l2_convergence.png     # Updated to show global line
├── v4_distance_convergence.png  # Updated to show global data
└── v4_comparison_metrics.csv  # NEW: Subdomain vs global comparison
```

## Key Differences from Original Plan

1. **Domain is correctly specified** as stretched orthant, not `([0,1]×[-1,0])²`
2. **Leverages existing infrastructure** - just needs to enable `analyze_global`
3. **Maintains exact same analysis pipeline** for both subdomain and global
4. **Global domain uses same tolerance** (0.0007) for consistency
5. **No new analysis functions needed** - reuse existing pipeline

## Implementation Priority

1. **First**: Enable `analyze_global` parameter in `run_enhanced_analysis_with_refinement`
2. **Second**: Handle global results in `run_v4_enhanced`
3. **Third**: Update plotting to show global data where supported
4. **Fourth**: Test with small degrees (3,4) before scaling up

## Computational Considerations

- Global domain analysis will be **more expensive** than individual subdomains
- May need **higher polynomial degrees** to capture all features
- Consider **increasing GN** for global analysis (e.g., GN=30 or 40)
- Monitor **memory usage** when storing both subdomain and global results

## Usage Examples

```julia
# Standard subdomain analysis (current behavior)
results = run_v4_enhanced()

# With global domain analysis
results = run_v4_enhanced(include_global=true)

# Higher accuracy global analysis
results = run_v4_enhanced(
    degrees=[3,4,5,6],
    GN=40,  # Higher resolution for global
    include_global=true,
    output_dir="outputs/global_comparison"
)
```