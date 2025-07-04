# Degree Convergence Analysis for 4D Deuflhard Function

This folder contains a structured suite of examples analyzing polynomial approximation performance across different degrees and spatial decompositions for the 4D Deuflhard composite function.

## Overview

The analysis suite provides three main examples demonstrating different approximation strategies:
1. **Full Domain**: Single polynomial on entire (+,-,+,-) orthant of [-1,1]⁴
2. **Subdivided Fixed**: Same degree applied to all 16 spatial subdomains
3. **Subdivided Adaptive**: Degree increased per subdomain until L²-tolerance achieved

All examples use fixed sample count (GN=10) and CairoMakie for stable file-based plotting.

## Enhanced Plotting Suite

The analysis now includes four specialized plot types with enhanced data structures:

1. **L²-Norm Convergence with Dual Scale** - Shows convergence patterns with optional dual-axis for multi-domain
2. **Min+Min Distance Analysis** - Tracks both minimal and average distances to theoretical min+min points
3. **Critical Point Recovery Histogram** - 3-layer stacked visualization of recovery success
4. **Min+Min Capture Methods** - Distinguishes between direct tolerance capture vs BFGS refinement

See `CONVERGENCE_PLOTS.md` for detailed documentation of plotting functions.

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
├── CONVERGENCE_PLOTS.md                # Detailed plotting documentation
├── shared/                             # Reusable utility modules
│   ├── Common4DDeuflhard.jl           # Core function and constants
│   ├── SubdomainManagement.jl         # Subdomain structures
│   ├── TheoreticalPoints.jl           # Reference point loading
│   ├── AnalysisUtilities.jl           # Analysis patterns
│   ├── EnhancedAnalysisUtilities.jl   # Enhanced data structures
│   ├── PlottingUtilities.jl           # Legacy plotting functions
│   ├── EnhancedPlottingUtilities.jl   # Enhanced plotting suite
│   └── TableGeneration.jl             # Summary tables
├── examples/                           # Main example scripts
│   ├── 01_full_domain.jl              # Full domain analysis
│   ├── 02_subdivided_fixed.jl         # Fixed degree subdivision
│   └── 03_subdivided_adaptive.jl      # Adaptive subdivision
├── test/                               # Validation scripts
│   └── test_shared_utilities.jl       # Module testing
└── outputs/                            # Generated results
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
# Run all three examples in sequence
julia> include("run_all_examples.jl")

# Or run examples individually:
julia> include("examples/01_full_domain.jl")
julia> include("examples/02_subdivided_fixed.jl")  
julia> include("examples/03_subdivided_adaptive.jl")
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

## Key Functions

### Core Analysis
- `analyze_degrees_4d()`: Multi-degree polynomial analysis
- `compute_tensor_critical_points()`: Generate 4D theoretical reference points
- `track_convergence_metrics()`: Monitor approximation improvement

### Visualization
- `plot_degree_convergence()`: L²-norm and distance convergence
- `plot_critical_point_recovery()`: Success rates by degree and point type
- `plot_4d_projections()`: 2D slices through 4D critical point space

## Expected Insights

1. **Degree Requirements**: Minimum degree needed for reliable 4D critical point recovery
2. **Convergence Rates**: How quickly approximation error decreases with degree
3. **Point Type Sensitivity**: Which critical point types (min+min vs saddle+saddle) are harder to capture
4. **Computational Efficiency**: Optimal degree/accuracy tradeoff for 4D problems

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