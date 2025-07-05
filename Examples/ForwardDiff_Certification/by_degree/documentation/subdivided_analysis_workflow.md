# Subdivided Analysis Workflow Documentation

## Overview

The subdivided analysis example (`02_subdivided_fixed.jl`) analyzes the 4D Deuflhard function over the (+,-,+,-) orthant by:
1. Dividing the domain into 16 spatial subdomains
2. Running polynomial approximation independently on each subdomain
3. Aggregating results to understand spatial patterns in approximation difficulty

## Domain and Subdivision Strategy

### Main Domain
- **Orthant**: (+,-,+,-) pattern
- **Bounds**: [0,1] × [-1,0] × [0,1] × [-1,0]
- **Function**: `deuflhard_4d_composite` (tensor product of 2D Deuflhard)

### Subdivision Method
```julia
# Each dimension split at midpoint
# 2^4 = 16 subdomains total
# Label: 4-bit string (0=lower half, 1=upper half)
# Example: "1010" means upper,lower,upper,lower in dims 1,2,3,4
```

## Key Functions and Data Flow

### 1. Subdomain Generation
```julia
subdivisions = generate_16_subdivisions_orthant()
# Returns: Vector{Subdomain} with 16 elements
# Each Subdomain contains:
#   - label: String (e.g., "0000", "0001", ..., "1111")
#   - center: Vector{Float64} of length 4
#   - range: Float64 (0.25 for all subdomains)
#   - bounds: Vector{Tuple{Float64,Float64}} defining box boundaries
```

### 2. Theoretical Point Loading
```julia
# Load 2D critical points from CSV
points_2d, types_2d = load_2d_critical_points_orthant()
# Input: CSV file with 2D Deuflhard critical points
# Output: 
#   - points_2d: Vector{Vector{Float64}} - 2D coordinates
#   - types_2d: Vector{String} - "min", "max", or "saddle"

# Generate 4D points via tensor product
points_4d, values_4d, types_4d = generate_4d_tensor_products_orthant(points_2d, types_2d)
# Output:
#   - points_4d: Vector{Vector{Float64}} - 4D coordinates
#   - values_4d: Vector{Float64} - function values
#   - types_4d: Vector{String} - "min+min", "min+saddle", etc.
```

### 3. Point Assignment to Subdomains
```julia
theoretical_points, theoretical_values, theoretical_types = 
    load_theoretical_points_for_subdomain_orthant(subdomain)
# Input: Subdomain object
# Output: Filtered points/values/types that fall within subdomain bounds
# Note: Currently all 9 points fall in subdomain "1010"
```

### 4. Single Degree Analysis (Critical Function)
```julia
result = analyze_single_degree(
    f,                    # Function to approximate
    degree,               # Polynomial degree
    subdomain.center,     # Center of approximation domain
    subdomain.range,      # Half-width of domain
    theoretical_points,   # Known critical points (can be empty)
    theoretical_types,    # Types of critical points
    gn = 16,             # Grid points per dimension
    tolerance_target = 0.01  # L²-norm target
)
# Returns: DegreeAnalysisResult containing:
#   - degree: Int
#   - l2_norm: Float64 (approximation error)
#   - n_computed_points: Int (critical points found)
#   - n_theoretical_points: Int (expected in subdomain)
#   - success_rate: Float64 (recovery rate)
#   - min_min_success_rate: Float64
#   - runtime_seconds: Float64
#   - converged: Bool (l2_norm < tolerance_target)
```

## Critical Code Sections

### 1. Handling Subdomains Without Theoretical Points
```julia
# In analyze_subdomain_at_degree (lines 58-67)
if isempty(theoretical_points)
    @info "No theoretical points in subdomain $(subdomain.label), analyzing anyway"
    # Create empty arrays for analysis
    theoretical_points = Vector{Vector{Float64}}()
    theoretical_types = String[]
else
    @info "Analyzing subdomain $(subdomain.label)" 
end
```
**Why Critical**: This ensures ALL 16 subdomains are analyzed for L²-norm convergence, even though only subdomain "1010" contains theoretical critical points.

### 2. Data Aggregation for Plotting
```julia
# Convert results to enhanced format (lines 143-166)
combined_results = Dict{String, Vector{DegreeAnalysisResult}}()
enhanced_combined_results = Dict{String, Vector{EnhancedDegreeAnalysisResult}}()

for (degree, degree_results) in all_results
    for (label, result) in degree_results
        if !haskey(combined_results, label)
            combined_results[label] = DegreeAnalysisResult[]
            enhanced_combined_results[label] = EnhancedDegreeAnalysisResult[]
        end
        push!(combined_results[label], result)
        
        # Convert to enhanced format with additional metrics
        enhanced = convert_to_enhanced(result, theoretical_points, 
                                     min_min_indices, label)
        push!(enhanced_combined_results[label], enhanced)
    end
end
```
**Why Critical**: Transforms degree-first organization to subdomain-first organization needed for plotting convergence curves.

### 3. Polynomial Construction Parameters
```julia
TR = test_input(
    f,                          # Function
    dim = 4,                    # Dimension
    center = subdomain.center,  # Approximation center
    sample_range = subdomain.range,  # Domain half-width
    tolerance = tolerance_target # Automatic degree adaptation
)
pol = Constructor(TR, degree, basis=:chebyshev)
```
**Why Critical**: Each subdomain gets its own polynomial approximation centered at the subdomain center with range matching the subdomain size.

## Outputs

### 1. Console Output
- Progress updates per subdomain/degree
- L²-norm statistics (min, max, median)
- Easiest/hardest subdomains per degree
- Convergence summary

### 2. Plots (saved to `outputs/HH-MM/`)
- **L²-norm convergence**: Shows pattern across all 16 subdomains
- **Critical point recovery histogram**: Shows found vs theoretical points
- **Min+min distances**: Distance to nearest min+min point (only for subdomain 1010)
- **Capture methods**: How min+min points were found

### 3. CSV Export
```csv
degree,subdomain,l2_norm,n_computed_points,n_theoretical_points,success_rate,min_min_success_rate,runtime_seconds,converged
2,0000,4.7577935129890214,41,0,0.0,0.0,4.653704166412354,false
2,0001,8.005493606153208,49,0,0.0,0.0,4.764871120452881,false
...
```

### 4. Summary Tables
- Per-degree statistics
- Spatial difficulty analysis (grouping by number of positive dimensions)

## Key Insights from Current Implementation

1. **Spatial Concentration**: All 9 theoretical critical points fall in subdomain "1010"
2. **Convergence Variability**: Different subdomains require different polynomial degrees
3. **L²-norm Pattern**: The collective behavior shows spread in approximation difficulty
4. **Gaps in Data**: Some degree/subdomain combinations fail (timeout or numerical issues)

## Performance Considerations

- **Timeout**: 60 seconds per subdomain analysis
- **Memory**: Each subdomain analysis is independent
- **Parallelization**: Currently sequential, could be parallelized
- **Grid Resolution**: 16 points per dimension (16^4 = 65,536 evaluation points)