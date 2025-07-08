# Issues to Fix - ForwardDiff Certification by_degree

## 🔴 Critical Issues

### 1. **Inconsistent Tolerance Usage**
- **Problem**: `TRESH = 0.1` defined in 3 different files
- **Files**: 
  - run_all_examples.jl (line 32)
  - degree_convergence_analysis_enhanced_v3.jl (line 36)
  - EnhancedVisualization.jl (line 12)
- **Fix**: Create a single configuration module

### 2. **Missing Documentation**
- **Problem**: Key functions lack docstrings
- **Functions**:
  - `create_enhanced_l2_plot` (line 470)
  - `create_enhanced_plots_v3` (line 513)
  - Several utility functions in modules

## 🟡 Moderate Issues

### 3. **Subdomain Distance Evolution Plot Issue**
- **Problem**: Plot shows only 3 curves but legend shows 9 subdomains
- **Root Cause Identified**: 
  - Only 3 subdomains have successfully recovered critical points across polynomial degrees
  - Other 6 subdomains have all infinite distances (no computed points near theoretical points)
  - Plotting logic correctly filters out subdomains with all NaN/Inf values
- **This is a legitimate finding, not a bug** - indicates difficulty in recovering critical points in certain subdomains

### 4. **Subdomain Assignment Verification**
- **Problem**: Inconsistent tolerance usage
- **Details**:
  - Theoretical points: `tolerance=0.0` (line 376 in analyze_critical_point_distance_matrix.jl)
  - Computed points: `tolerance=0.1` (line 345 in degree_convergence_analysis_enhanced_v3.jl)

### 5. **Data Loading Path Assumptions**
- **Problem**: Hardcoded paths assume specific directory structure
- **Example**: `"../data/4d_all_critical_points_orthant.csv"`

### 6. **Type Safety**
- **Problem**: Complex data structures lack proper type annotations
- **Example**: `all_critical_points_with_labels` parameter

## 🟢 Minor Issues

### 7. **Code Duplication**
- **Problem**: Dimension detection code repeated
- **Code**:
  ```julia
  dim_cols = [col for col in names(df) if startswith(String(col), "x")]
  n_dims = length(dim_cols)
  ```

### 8. **Unused Imports**
- **Problem**: `PrettyTables` imported globally but used in one function

### 9. **Magic Numbers**
- **Problems**:
  - 16 hardcoded colors in plot_subdomain_distance_evolution
  - `GN = 20` not explained

---

## Debugging Strategy for Subdomain Plot Issue

### Create a debug script: `debug_subdomain_plot_issue.jl`

```julia
# Debug script to investigate why only 3 of 9 subdomains show in the plot

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

include("src/SubdomainManagement.jl")
include("src/TheoreticalPoints.jl")
using .SubdomainManagement: generate_16_subdivisions_orthant, is_point_in_subdomain
using .TheoreticalPoints: load_theoretical_4d_points_orthant

using DataFrames, CSV
using LinearAlgebra

# Load theoretical points and assign to subdomains
theoretical_points, _, _, theoretical_types = load_theoretical_4d_points_orthant()
subdomains = generate_16_subdivisions_orthant()

# Track assignments
subdomain_theory_count = Dict{String, Int}()
subdomain_theory_types = Dict{String, Vector{String}}()

for subdomain in subdomains
    subdomain_theory_count[subdomain.label] = 0
    subdomain_theory_types[subdomain.label] = String[]
end

for (idx, point) in enumerate(theoretical_points)
    for subdomain in subdomains
        if is_point_in_subdomain(point, subdomain, tolerance=0.0)
            subdomain_theory_count[subdomain.label] += 1
            push!(subdomain_theory_types[subdomain.label], theoretical_types[idx])
            break
        end
    end
end

# Collect results
active_subdomains = [(k,v) for (k,v) in subdomain_theory_count if v > 0]
sort!(active_subdomains, by=x->x[1])

# Create summary dataframe
theory_summary = DataFrame(
    subdomain = String[],
    n_points = Int[],
    n_min = Int[],
    n_saddle = Int[]
)

for (label, count) in active_subdomains
    types = subdomain_theory_types[label]
    push!(theory_summary, (
        subdomain = label,
        n_points = count,
        n_min = count(t -> t == "min", types),
        n_saddle = count(t -> t == "saddle", types)
    ))
end

# Export results
CSV.write("debug_theory_assignments.csv", theory_summary)

# Function to analyze distance matrix
function analyze_distance_matrix(distance_matrix::Matrix{Float64}, 
                               theory_indices_by_subdomain::Dict{String, Vector{Int}},
                               degrees::Vector{Int})
    
    results = DataFrame(
        subdomain = String[],
        degree = Int[],
        n_theory = Int[],
        n_finite = Int[],
        n_inf = Int[],
        avg_finite_dist = Float64[]
    )
    
    for (subdomain, indices) in theory_indices_by_subdomain
        for (j, degree) in enumerate(degrees)
            subdomain_dists = distance_matrix[indices, j]
            finite_dists = filter(!isinf, subdomain_dists)
            
            push!(results, (
                subdomain = subdomain,
                degree = degree,
                n_theory = length(indices),
                n_finite = length(finite_dists),
                n_inf = sum(isinf.(subdomain_dists)),
                avg_finite_dist = isempty(finite_dists) ? NaN : mean(finite_dists)
            ))
        end
    end
    
    return results
end

# Function to check computed point assignments
function analyze_computed_assignments(all_critical_points_with_labels::Dict{Int, DataFrame})
    results = DataFrame(
        degree = Int[],
        subdomain = String[],
        n_computed = Int[]
    )
    
    for (degree, df) in all_critical_points_with_labels
        if !isempty(df)
            counts = combine(groupby(df, :subdomain), nrow => :count)
            for row in eachrow(counts)
                push!(results, (
                    degree = degree,
                    subdomain = row.subdomain,
                    n_computed = row.count
                ))
            end
        end
    end
    
    return results
end
```

### Additional Debugging Steps

1. **Add verbose logging to `plot_subdomain_distance_evolution`**:
```julia
# After line 384 in analyze_critical_point_distance_matrix.jl
println("\nDEBUG: Active subdomains: $(length(active_subdomains))")
for (label, indices) in active_subdomains
    println("  $label: $(length(indices)) theoretical points")
end

# After line 410 in same file
println("\nDEBUG: Subdomain $subdomain_label distances by degree:")
for (j, degree) in enumerate(degrees)
    finite_dists = filter(!isinf, distance_matrix[theory_indices, j])
    println("  Degree $degree: $(length(finite_dists)) finite distances out of $(length(theory_indices))")
end

# After line 450
println("DEBUG: Plotting subdomain $subdomain_label with $(length(valid_degrees)) valid degrees")
```

2. **Add logging to `degree_convergence_analysis_enhanced_v3`**:
```julia
# After line 361
println("DEBUG: Degree $degree, Subdomain $(subdomain.label): $(length(subdomain_points)) computed points")
```

3. **Create a verification script to check the actual data flow**:
```julia
# verification_script.jl
# This would load the saved CSVs and trace through the exact computation
# to identify where the disconnect happens
```

This debugging strategy will help identify whether the issue is:
- Assignment mismatch (tolerance difference)
- No computed points in certain subdomains
- All infinite distances for some subdomains
- Plotting logic filtering issue