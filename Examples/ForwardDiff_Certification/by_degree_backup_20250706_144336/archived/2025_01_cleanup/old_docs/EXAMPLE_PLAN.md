# 4D Deuflhard Example Organization Plan

## Folder Reorganization Strategy

### Current Issues
- Code duplication across multiple example files
- Mixed test files and main examples
- No clear separation of utilities vs examples
- Interactive plot issues causing GLMakie errors

### Proposed Structure
```
by_degree/
├── README.md                            # Overview and quick usage guide
├── EXAMPLE_PLAN.md                      # This planning document
├── shared/                              # Shared utilities (new)
│   ├── Common4DDeuflhard.jl            # Core function and constants
│   ├── SubdomainManagement.jl          # Subdomain struct and generation
│   ├── TheoreticalPoints.jl            # Point loading and classification
│   ├── AnalysisUtilities.jl            # Common analysis patterns
│   ├── PlottingUtilities.jl            # Non-interactive plotting functions
│   └── TableGeneration.jl              # Summary table utilities
├── examples/                            # Main examples (new)
│   ├── 01_full_domain.jl               # Example A: Full domain analysis
│   ├── 02_subdivided_fixed.jl          # Example B: Fixed degree subdivision
│   └── 03_subdivided_adaptive.jl       # Example C: Adaptive subdivision
├── test/                                # Test scripts (move existing)
│   └── test_*.jl                        # Quick validation scripts
└── outputs/                             # Keep existing output structure
```

## Shared Functions to Extract

### 1. `Common4DDeuflhard.jl`
```julia
# Constants
const ORIGINAL_DOMAIN_RANGE = 1.0
const SUBDOMAIN_RANGE = 0.5
const DISTANCE_TOLERANCE = 0.05
const GN_FIXED = 10  # Fixed sample count as requested

# Core function
function deuflhard_4d_composite(x::AbstractVector)::Float64
    return Deuflhard([x[1], x[2]]) + Deuflhard([x[3], x[4]])
end

# Degree handling utility
function get_actual_degree(pol)
    return pol.degree isa Tuple ? pol.degree[2] : pol.degree
end
```

### 2. `SubdomainManagement.jl`
```julia
struct Subdomain
    label::String
    center::Vector{Float64}
    range::Float64
    bounds::Vector{Tuple{Float64,Float64}}
end

function generate_16_subdivisions()
    # Existing implementation
end

function is_point_in_subdomain(point, subdomain)
    # Extract bound checking logic
end
```

### 3. `TheoreticalPoints.jl`
```julia
function load_2d_critical_points()
    # Load and classify 2D points
end

function generate_4d_tensor_products(critical_2d, critical_2d_types)
    # Generate all 225 4D points
end

function load_theoretical_4d_points()
    # Full domain version
end

function load_theoretical_points_for_subdomain(subdomain)
    # Filtered version
end
```

### 4. `AnalysisUtilities.jl`
```julia
struct DegreeAnalysisResult
    degree::Int
    l2_norm::Float64
    n_theoretical_points::Int
    n_computed_points::Int
    n_successful_recoveries::Int
    success_rate::Float64
    runtime_seconds::Float64
    converged::Bool
end

function analyze_single_degree(f, degree, center, range; gn=GN_FIXED)
    # Common analysis pattern
end

function compute_recovery_metrics(computed_points, theoretical_points)
    # Distance calculations and success rates
end
```

### 5. `PlottingUtilities.jl`
```julia
# All plots use CairoMakie for file output, no interactive features

function plot_l2_convergence(results; save_path=nothing, show_legend=false)
    # L²-norm vs degree plot
end

function plot_recovery_rates(results; save_path=nothing)
    # Success rate plots
end

function plot_subdivision_convergence(all_results; save_path=nothing)
    # 16 curves on one plot
end
```

## Three Main Examples

### Example A: Full Domain Analysis (`01_full_domain.jl`)
```julia
# Objective: Single polynomial approximant on full [-1,1]^4 domain
# Key features:
# - Degree sweep from 2 to 12 (or until convergence)
# - Track L²-norm convergence
# - Monitor critical point recovery rates
# - Fixed GN = 10

# Parameters:
const DEGREE_MIN = 2
const DEGREE_MAX = 12
const L2_TOLERANCE = 1e-3  # Start with achievable tolerance

# Expected outputs:
# 1. L²-norm convergence plot
# 2. Recovery rate plot (all points vs min+min)
# 3. Summary table with degree/L²-norm/recovery metrics
# 4. CSV export of results
```

### Example B: Subdivided Fixed Degree (`02_subdivided_fixed.jl`)
```julia
# Objective: Apply same degree to all 16 subdomains
# Key features:
# - Fix degree (e.g., 4, 6, 8) for all subdomains
# - Compare L²-norms across spatial regions
# - Identify "easy" vs "hard" subdomains
# - Fixed GN = 10

# Parameters:
const FIXED_DEGREES = [4, 6, 8]  # Test multiple fixed degrees
const MAX_RUNTIME_PER_SUBDOMAIN = 60  # 1 minute timeout

# Expected outputs:
# 1. Combined plot showing all 16 L²-norm curves
# 2. Spatial difficulty heatmap (which subdomains are hardest)
# 3. Summary table by subdomain
# 4. CSV export with subdomain/degree/metrics
```

### Example C: Subdivided Adaptive (`03_subdivided_adaptive.jl`)
```julia
# Objective: Increase degree per subdomain until L²-tolerance met
# Key features:
# - Start at degree 2 for each subdomain
# - Increase until L²-norm < tolerance or max degree
# - Track computational cost per subdomain
# - Fixed GN = 10 (initially)

# Parameters:
const DEGREE_MIN = 2
const DEGREE_MAX = 10
const L2_TOLERANCE_TARGET = 1e-2  # Achievable target
const ADAPTIVE_GN = false  # Could enable GN adaptation later

# Expected outputs:
# 1. Convergence progression plot (degree required vs subdomain)
# 2. Computational cost analysis
# 3. Success/failure summary
# 4. CSV with adaptive history
```

## Implementation Timeline

### Phase 1: Setup Shared Utilities (Priority 1)
1. Create `shared/` directory
2. Extract common functions from existing files
3. Add proper module structure and exports
4. Test utilities work correctly

### Phase 2: Implement Main Examples (Priority 2)
1. **Example A (Full Domain)**:
   - Simplest case, good for validation
   - Expected runtime: 2-5 minutes
   - Key metric: degree where L²-norm < 1e-3

2. **Example B (Fixed Degree)**:
   - Test with degrees 4, 6, 8
   - Expected runtime: 5-10 minutes per degree
   - Key insight: spatial variation in approximation difficulty

3. **Example C (Adaptive)**:
   - Most complex but most practical
   - Expected runtime: 10-20 minutes
   - Key output: degree requirements map

### Phase 3: Documentation and Cleanup (Priority 3)
1. Update README.md with new structure
2. Create example output gallery
3. Move test files to `test/` directory
4. Archive old implementations

## Key Design Decisions

### 1. Fixed GN = 10
- Simplifies comparison across examples
- Reduces variability in results
- Can revisit adaptive GN later if needed

### 2. CairoMakie Only
- Avoids GLMakie text rendering issues
- All plots saved to files
- No interactive features (zoom/pan sacrificed for stability)

### 3. Small Initial Degrees
- Start with degree 2-6 for testing
- Expand to 8-12 once validated
- Prevents long runtimes during development

### 4. Consistent Output Format
- All examples produce: plots + tables + CSV
- Standardized naming: `{example_name}_{timestamp}/`
- Self-contained results for paper inclusion

## Success Criteria

1. **Code Quality**:
   - Zero code duplication across examples
   - Clear separation of concerns
   - Easy to modify parameters

2. **Scientific Validity**:
   - Reproducible results
   - Clear convergence patterns
   - Meaningful spatial analysis

3. **Practical Usability**:
   - Each example runs in < 20 minutes
   - No crashes or GLMakie errors
   - Publication-ready outputs

## Next Steps

1. Review and approve this plan
2. Create shared utilities modules
3. Implement Example A as proof of concept
4. Iterate based on results
5. Complete Examples B and C
6. Generate final plots for paper

---

**Note**: This plan prioritizes stability and reproducibility over interactive features. All plots will be static files suitable for LaTeX inclusion.