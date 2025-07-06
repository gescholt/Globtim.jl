# Degree Convergence Analysis for 4D Deuflhard Function

This folder contains a comprehensive analysis framework for studying polynomial approximation convergence and local minimizer recovery for the 4D Deuflhard composite function.

## Overview

The analysis focuses on tracking how polynomial approximations improve with degree, specifically monitoring:
- L²-norm convergence across 16 spatial subdomains
- Recovery of 9 true local minimizers from the stretched (+,-,+,-) orthant
- Comparison between subdivided and global approximation strategies

**Latest Implementation**: Enhanced Analysis V3 with per-subdomain distance tracking and improved visualizations.

## Enhanced Visualization Suite (V3)

The latest implementation provides enhanced visualizations with per-subdomain tracking:

1. **Enhanced Distance Convergence Plot with Subdomain Traces**
   - Individual subdomain traces showing convergence (similar to L²-norm plot style)
   - Average distance with min-max range bands
   - Side-by-side comparison of subdivided vs global approximation
   - Log scale visualization with recovery threshold reference

2. **L²-Norm Convergence Analysis**
   - Average L²-norm across 16 subdomains
   - Individual subdomain traces showing variation
   - Global domain comparison when available

3. **Minimizer Recovery Overview**
   - Recovery rate percentage by degree
   - Point classification (near minimizers vs spurious)
   - Clean single-axis visualization (histogram removed)

See `ENHANCED_ANALYSIS_SUMMARY.md` for implementation details.

## Visualization Types Implemented

### From Trefethen Notebook
- **2D Contour plots**: Function level sets with critical points overlaid
- **3D Surface plots**: Function visualization with critical point markers
- **Critical point classification**: Color-coded by type (min/max/saddle)

### From Triple Graph Notebook
- **Discrete L²-norm convergence**: Approximation error vs polynomial degree
- **Critical point recovery rates**: Histogram of points found vs degree
- **Distance convergence analysis**: How close computed points get to theoretical locations

## File Structure

```
by_degree/
├── README.md                           # This documentation
├── run_all_examples.jl                 # Main entry point
├── src/                                # Core source modules
│   ├── Common4DDeuflhard.jl           # Core function and constants
│   ├── SubdomainManagement.jl         # Subdomain structures
│   ├── MinimizerTracking.jl          # Per-subdomain minimizer tracking
│   └── EnhancedVisualization.jl      # Enhanced plotting with subdomain traces
├── examples/                           # Main analysis scripts
│   ├── degree_convergence_analysis_enhanced_v3.jl  # Current implementation (V3)
│   └── README.md                      # Examples documentation
├── data/                               # Reference data
│   ├── 4d_min_min_domain.csv         # 9 true minimizers
│   └── 2d_coords.csv                  # 2D reference points
├── docs/                               # Comprehensive documentation
│   ├── README.md                      # Documentation index
│   ├── implementation/                # Implementation details
│   │   ├── V3_IMPLEMENTATION_SUMMARY.md
│   │   ├── implementation_summary.md
│   │   ├── critical_code_decisions.md
│   │   └── data_flow_diagram.md
│   └── reference/                     # Reference documentation
│       ├── function_io_reference.md
│       ├── orthant_restriction.md
│       └── output_structure.md
├── outputs/                            # Generated results
│   └── enhanced_v3_*/                 # Timestamped output directories
└── archive/                            # Historical development
    ├── 2025_01_cleanup/               # Previous cleanup effort
    ├── legacy_examples/               # Old example versions
    ├── legacy_v2/                     # V2 implementation
    └── archived_outputs/              # Historical results
```

## Implementation Strategy

### Key Differences from Systematic Analysis

1. **Degree Loop**: Test multiple polynomial degrees (2,4,6,8) instead of fixed degree
2. **Convergence Focus**: Track how metrics improve with degree rather than comprehensive validation
3. **Lightweight**: Faster execution for iterative analysis rather than exhaustive validation

### 4D Adaptations

#### Replacing 2D Exact Locations
- **Original**: 2D notebooks use exact critical point locations from ChebFun
- **4D Version**: Use tensor products of 2D Deuflhard critical points as theoretical reference
- **Benefit**: Known ground truth for validation in 4D space

#### Visualization Adaptations
- **2D Contours → 4D Projections**: Show 2D slices through 4D space
- **Critical Point Types**: Color-code by tensor product structure (min+min, min+saddle, etc.)
- **Tensor Product Structure**: Visualize how 2D+2D composition affects convergence

## Usage Pattern

```julia
# First, test that shared utilities are working
julia> include("test/test_shared_utilities.jl")

# Example A: Full domain analysis
julia> include("examples/01_full_domain.jl")

# Example B: Fixed degree subdivision (test multiple degrees)
julia> include("examples/02_subdivided_fixed.jl")

# Example C: Adaptive subdivision analysis
julia> include("examples/03_subdivided_adaptive.jl")

# Results are saved in timestamped directories under outputs/
```

## Quick Start

```julia
# Run the enhanced analysis
julia> include("run_all_examples.jl")

# Or run with custom parameters:
julia> include("examples/degree_convergence_analysis_enhanced_v3.jl")
julia> summary_df, distance_data = run_enhanced_analysis_v2(
    [2, 3, 4, 5, 6],  # Polynomial degrees
    16,               # Grid points per dimension
    analyze_global = true,  # Include global comparison
    threshold = 0.1    # Distance threshold for minimizer recovery
)
```

## Example Descriptions

### Example A: Full Domain Analysis (`01_full_domain.jl`)

**Objective**: Systematic degree sweep on entire 4D domain to replicate notebook convergence patterns

**Parameters**:
- **Domain**: `[-1, 1]^4` (full hypercube, no orthant subdivision)
- **Degree Range**: `2:12` (test polynomial degrees 2 through 12)
- **L²-norm Tolerance**: `5e-5` (tight approximation requirement)
- **Reference Points**: All 225 tensor product critical points from 2D Deuflhard

**Expected Analysis**:
1. **L²-norm vs Degree Plot**: Shows approximation quality improvement (replicates Triple Graph notebook)
2. **Local Minimizer Capture Rate**: Percentage of min+min points found vs degree
3. **Critical Point Recovery**: Success rate for all point types by degree
4. **Computational Scaling**: Runtime and sample count vs degree

**Key Insights Expected**:
- **Degree Threshold**: Minimum degree where L²-norm consistently meets 5e-5 tolerance
- **Capture Saturation**: Degree where local minimizer recovery plateaus
- **Numerical Limits**: Highest practical degree before conditioning issues
- **Efficiency Sweet Spot**: Optimal degree/accuracy/speed tradeoff for 4D problems

## Integration with Existing Examples

- **Complements**: `deuflhard_4d_systematic.jl` (comprehensive single-degree validation)
- **Extends**: Notebook patterns to 4D tensor product functions
- **Enables**: Quick convergence assessment before running full systematic analysis

## Key Functions (V2)

### Core Analysis
- `run_enhanced_analysis_v2()`: Main analysis function with global comparison
- `compute_enhanced_distance_stats()`: Calculate quartile-based distance statistics
- `compute_minimizer_recovery()`: Track recovery with improved per-subdomain metrics
- `analyze_global_domain()`: Compare with single global approximation

### Visualization
- `create_enhanced_distance_plot()`: Quartile bands with global comparison
- `create_enhanced_l2_plot()`: L²-norm convergence with individual traces
- `create_recovery_overview()`: Clean recovery rate visualization

## Key Insights from Analysis

1. **Minimizer Recovery**: All 9 true minimizers are recovered by degree 3 with threshold 0.2
2. **Distance Persistence**: Maximum distances remain high (~1.4) due to spurious critical points in the stretched domain
3. **Subdivision Benefits**: Subdivided approach shows lower median distances and tighter quartile bands compared to global approximation
4. **L²-norm Convergence**: Exponential decrease from ~7.2 (degree 2) to ~0.05 (degree 6)

## Performance Expectations

- **Execution Time**: 2-5 minutes (vs 15+ for systematic analysis)
- **Memory Usage**: Moderate (degree loop with cleanup between iterations)
- **Output Size**: Focused plots and summary statistics
- **Convergence**: Expected improvement up to degree 6-8 for Deuflhard 4D

## Outlier Analysis

The degree analysis helps understand outlier sources:
- **Low Degrees**: Expected high error due to insufficient approximation power
- **High Degrees**: Numerical conditioning issues may emerge
- **Sweet Spot**: Typically degrees 4-6 for Deuflhard-type functions
- **Comparison**: Track outlier rates across degrees to identify optimal settings