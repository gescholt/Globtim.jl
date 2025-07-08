# Critical Code Sections and Design Decisions

## 1. Analyzing Empty Subdomains

### Location
`examples/02_subdivided_fixed.jl`, lines 58-67

### Code
```julia
if isempty(theoretical_points)
    @info "No theoretical points in subdomain $(subdomain.label), analyzing anyway"
    # Create empty arrays for analysis
    theoretical_points = Vector{Vector{Float64}}()
    theoretical_types = String[]
else
    @info "Analyzing subdomain $(subdomain.label)"
end
```

### Why This Matters
- **Original behavior**: Skip subdomains without theoretical points
- **Current behavior**: Analyze ALL 16 subdomains
- **Reason**: L²-norm convergence is meaningful even without theoretical points
- **Impact**: Provides complete spatial coverage of approximation quality

---

## 2. Point Matching with Hungarian Algorithm

### Location
`shared/AnalysisUtilities.jl`, within `analyze_single_degree`

### Code Pattern
```julia
# Match computed points to theoretical using Hungarian algorithm
distances = distance_matrix(computed_points, theoretical_points)
assignment = hungarian(distances)
matched_indices = findall(x -> x > 0 && distances[x[1], x[2]] < tolerance, 
                         enumerate(assignment))
```

### Why This Matters
- **Challenge**: Multiple computed points may be near one theoretical point
- **Solution**: Optimal 1-to-1 assignment minimizing total distance
- **Tolerance**: 1e-3 for point matching (different from L²-norm tolerance)
- **Impact**: Accurate success rate calculation

---

## 3. Dual-Scale Plotting Strategy

### Location
`shared/EnhancedPlottingUtilities.jl`, lines 66-97

### Code Structure
```julia
# Left axis: Subdomain scale
ax_left = Axis(fig[1, 1],
    ylabel="L² Error (Subdomain Scale)",
    yscale=log10,
    yticklabelcolor=:blue
)

# Right axis: Full domain scale  
ax_right = Axis(fig[1, 1],
    ylabel="L² Error (Full Domain Scale)",
    yscale=log10,
    yaxisposition=:right,
    yticklabelcolor=:red
)
```

### Why This Matters
- **Problem**: Individual subdomain errors vs combined domain error
- **Solution**: Dual y-axes showing both scales simultaneously
- **Left axis**: Individual subdomain L²-norms
- **Right axis**: Aggregated full domain error (sqrt of sum of squares)
- **Impact**: Shows both local and global convergence behavior

---

## 4. Enhanced Data Structure Design

### Location
`shared/EnhancedAnalysisUtilities.jl`

### Structure
```julia
struct EnhancedDegreeAnalysisResult
    # Basic fields from DegreeAnalysisResult
    degree::Int
    l2_norm::Float64
    # ... other basic fields ...
    
    # Enhanced fields for richer analysis
    subdomain_label::String
    min_min_distances::Vector{Float64}
    min_min_capture_method::Vector{String}
    average_min_min_distance::Float64
    theoretical_count::Int
    other_critical_count::Int
end
```

### Why This Matters
- **Evolution**: Started with basic metrics, added detailed tracking
- **Min+min distances**: Track how close we get to important points
- **Capture methods**: Distinguish BFGS refinement vs tolerance-based
- **Impact**: Enables sophisticated multi-panel visualizations

---

## 5. Handling Subdomains with No Min+Min Points

### Location
`shared/EnhancedPlottingUtilities.jl`, plot generation

### Decision Logic
```julia
# Check if subdomain has min+min points
if isempty(min_min_indices)
    # Skip min+min distance calculations
    # Still compute L²-norm and other metrics
end
```

### Why This Matters
- **Observation**: Only subdomain "1010" contains min+min points
- **Challenge**: Other 15 subdomains have no min+min distances to plot
- **Solution**: Gracefully handle empty data in plotting functions
- **Impact**: Explains why min+min plot shows single curve

---

## 6. Color Scheme Philosophy

### Location
`shared/EnhancedPlottingUtilities.jl`, L²-norm plotting

### Original vs Current
```julia
# Original: Different colors per subdomain
colors = [:blue, :cyan, :teal, :navy, ...]

# Current: Single color with transparency
color = (:blue, 0.3)  # All curves same color
```

### Why This Matters
- **Principle**: Same measurement type = same color
- **Transparency**: Shows density and overlap patterns
- **Pattern focus**: Emphasizes collective behavior over individuals
- **Impact**: Clearer visualization of convergence spread

---

## 7. Timeout and Error Handling

### Location
`examples/02_subdivided_fixed.jl`, lines 122-126

### Code
```julia
if result.runtime_seconds > MAX_RUNTIME_PER_SUBDOMAIN
    @warn "Subdomain $(subdomain.label) exceeded timeout" 
          runtime=result.runtime_seconds
end
```

### Why This Matters
- **Timeout**: 60 seconds per subdomain prevents hanging
- **Continuation**: Analysis continues even if some subdomains fail
- **Logging**: Warnings help identify problematic regions
- **Impact**: Robust analysis that completes even with failures

---

## 8. Data Reorganization for Plotting

### Location
`examples/02_subdivided_fixed.jl`, lines 142-166

### Transformation
```julia
# Input structure: all_results[degree][subdomain] = result
# Output structure: combined_results[subdomain] = [results...]

# Why: Plotting needs all degrees for one subdomain together
for (degree, degree_results) in all_results
    for (label, result) in degree_results
        push!(combined_results[label], result)
    end
end
```

### Why This Matters
- **Storage**: Results organized by degree during computation
- **Plotting**: Needs results organized by subdomain
- **Transformation**: Critical data restructuring step
- **Impact**: Enables convergence curve plotting

---

## 9. Grid Resolution Choice

### Location
`shared/Common4DDeuflhard.jl` and analysis functions

### Parameters
```julia
const GN_FIXED = 16  # Grid points per dimension
# Total points: 16^4 = 65,536
```

### Why This Matters
- **Trade-off**: Accuracy vs computation time
- **Memory**: ~0.5 MB per L²-norm computation
- **Accuracy**: Sufficient for 1e-2 tolerance target
- **Scaling**: Could reduce for initial exploration

---

## 10. Theoretical Point Loading Strategy

### Location
`shared/TheoreticalPoints.jl`

### Two-Stage Process
```julia
# Stage 1: Load 2D points from CSV
points_2d, types_2d = load_2d_critical_points_orthant()

# Stage 2: Generate 4D via tensor product
points_4d = generate_4d_tensor_products_orthant(points_2d, types_2d)
```

### Why This Matters
- **Source**: 2D points from validated MATLAB computation
- **4D construction**: Tensor product preserves critical point structure
- **Orthant filtering**: Ensures points match analysis domain
- **Validation**: Point types verified via Hessian analysis

---

## Key Design Principles

1. **Robustness**: Continue analysis even with failures
2. **Completeness**: Analyze all subdomains for full picture
3. **Flexibility**: Handle subdomains with/without theoretical points
4. **Clarity**: Visualization focuses on patterns, not individuals
5. **Efficiency**: Independent subdomain analysis enables parallelization
6. **Traceability**: Comprehensive logging and progress reporting