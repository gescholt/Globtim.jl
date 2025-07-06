# Function Input/Output Reference

## Core Analysis Functions

### `analyze_single_degree`
**Purpose**: Analyzes polynomial approximation at a specific degree for a given domain.

**Location**: `shared/AnalysisUtilities.jl`

**Inputs**:
```julia
f::Function                    # Target function to approximate
degree::Int                    # Polynomial degree
center::Vector{Float64}        # Center point of approximation domain
range::Float64                 # Half-width of cubic domain
theoretical_points::Vector{Vector{Float64}}  # Expected critical points
theoretical_types::Vector{String}            # Classifications ("min+min", etc.)
gn::Int = 16                   # Grid points per dimension for L²-norm
tolerance_target::Float64 = 0.01  # Target L²-norm for convergence check
```

**Outputs**:
```julia
DegreeAnalysisResult(
    degree::Int                    # Input degree
    l2_norm::Float64              # L² approximation error
    n_computed_points::Int        # Number of critical points found
    n_theoretical_points::Int     # Number expected in domain
    success_rate::Float64         # Fraction of theoretical points recovered
    min_min_success_rate::Float64 # Fraction of min+min points recovered
    runtime_seconds::Float64      # Computation time
    converged::Bool               # Whether l2_norm < tolerance_target
)
```

**Critical Logic**:
- Constructs polynomial using `Constructor` from Globtim
- Solves polynomial system using HomotopyContinuation
- Classifies points using Hessian eigenvalues
- Matches computed points to theoretical using Hungarian algorithm

---

### `generate_16_subdivisions_orthant`
**Purpose**: Creates 16 spatial subdomains by bisecting each dimension.

**Location**: `shared/SubdomainManagement.jl`

**Inputs**: None

**Outputs**:
```julia
Vector{Subdomain} where Subdomain contains:
    label::String              # 4-bit string, e.g., "0101"
    center::Vector{Float64}    # Center of subdomain
    range::Float64            # Half-width (always 0.25)
    bounds::Vector{Tuple{Float64,Float64}}  # Min/max per dimension
```

**Example Output**:
```julia
Subdomain("1010", 
    center = [0.75, -0.75, 0.75, -0.75],
    range = 0.25,
    bounds = [(0.5, 1.0), (-1.0, -0.5), (0.5, 1.0), (-1.0, -0.5)]
)
```

---

### `load_theoretical_points_for_subdomain_orthant`
**Purpose**: Filters theoretical critical points to those within a subdomain.

**Location**: `shared/TheoreticalPoints.jl`

**Inputs**:
```julia
subdomain::Subdomain  # Subdomain to filter for
```

**Outputs**:
```julia
(
    points::Vector{Vector{Float64}},   # 4D coordinates
    values::Vector{Float64},           # Function values
    types::Vector{String}              # Point classifications
)
```

**Implementation**:
```julia
# Check if point falls within subdomain bounds
for (i, point) in enumerate(all_points)
    if is_point_in_subdomain(point, subdomain, tolerance=0.0)
        push!(filtered_points, point)
        push!(filtered_values, all_values[i])
        push!(filtered_types, all_types[i])
    end
end
```

---

### `convert_to_enhanced`
**Purpose**: Enriches analysis results with additional metrics for plotting.

**Location**: `shared/EnhancedAnalysisUtilities.jl`

**Inputs**:
```julia
result::DegreeAnalysisResult           # Basic analysis result
theoretical_points::Vector{Vector{Float64}}  # Expected points
min_min_indices::Vector{Int}           # Indices of min+min points
subdomain_label::String                # Subdomain identifier
```

**Outputs**:
```julia
EnhancedDegreeAnalysisResult(
    # All fields from DegreeAnalysisResult plus:
    subdomain_label::String
    min_min_distances::Vector{Float64}    # Distance to nearest min+min
    min_min_capture_method::Vector{String} # "BFGS", "tolerance", "not_captured"
    average_min_min_distance::Float64
    median_min_min_distance::Float64
    theoretical_count::Int
    other_critical_count::Int             # Non-min+min points found
)
```

---

## Plotting Functions

### `plot_l2_convergence_dual_scale`
**Purpose**: Creates dual-axis plot showing subdomain and full domain L²-norms.

**Location**: `shared/EnhancedPlottingUtilities.jl`

**Inputs**:
```julia
results::Dict{String,Vector{EnhancedDegreeAnalysisResult}}
title::String = ""
tolerance_line::Union{Nothing,Float64} = nothing  # Reference line
save_plots::Bool = false
plots_directory::String = "plots"
```

**Outputs**:
- Makie Figure object
- Saved PNG file if `save_plots=true`

**Visual Elements**:
- Left axis: Individual subdomain L²-norms (blue, semi-transparent)
- Right axis: Aggregated full domain error (red, dashed)
- Horizontal line: Tolerance reference if provided

---

### `plot_critical_point_recovery_histogram`
**Purpose**: Shows 3-layer bar chart of critical point recovery.

**Inputs**:
```julia
results::Dict{String,Vector{EnhancedDegreeAnalysisResult}}
# Same additional parameters as above
```

**Visual Layers**:
1. **Bottom (dark blue)**: Min+min points captured
2. **Middle (dodger blue)**: Other critical points found
3. **Top (light blue, transparent)**: Theoretical points not found

---

### `aggregate_full_domain_errors`
**Purpose**: Combines subdomain L²-norms into full domain estimate.

**Location**: `shared/EnhancedPlottingUtilities.jl`

**Inputs**:
```julia
results::Dict{String,Vector{EnhancedDegreeAnalysisResult}}
```

**Outputs**:
```julia
DataFrame(
    degree::Vector{Int},
    l2_error::Vector{Float64}    # sqrt(sum of squared subdomain errors)
)
```

**Mathematical Formula**:
```julia
# For each degree:
l2_full = sqrt(sum(result.l2_norm^2 for result in subdomain_results))
```

---

## Data Pipeline Summary

```
1. Generate Subdomains
   ↓
2. For each degree:
   For each subdomain:
     a. Load theoretical points for subdomain
     b. Run analyze_single_degree
     c. Store DegreeAnalysisResult
   ↓
3. Reorganize data by subdomain (not degree)
   ↓
4. Convert to EnhancedDegreeAnalysisResult
   ↓
5. Generate plots and tables
   ↓
6. Export CSV and display summaries
```

## Critical Implementation Details

### Grid Resolution Impact
```julia
gn = 16  # Grid points per dimension
# Total evaluation points: 16^4 = 65,536
# Memory per evaluation: ~8 bytes
# Total memory for L²-norm: ~524 KB per subdomain
```

### Tolerance Matching
```julia
# Two types of tolerance:
1. tolerance_target (0.01): For convergence checking
2. point matching tolerance (1e-3): For Hungarian algorithm
```

### Performance Bottlenecks
1. **Polynomial system solving**: Can timeout on high degrees
2. **L²-norm computation**: 65,536 function evaluations
3. **Point matching**: O(n³) Hungarian algorithm

### Error Handling
- Timeouts: Returns partial results if available
- Numerical failures: Logged but analysis continues
- Missing data: Handled gracefully in plotting functions