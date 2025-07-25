# Lambda Vandermonde Analysis - Current Implementation

## Overview
The `lambda_vandermonde` function creates a Vandermonde matrix for polynomial evaluation on a given set of points. Currently located in `src/ApproxConstruct.jl` (lines 112-200).

## Current Implementation Details

### Function Signature
```julia
function lambda_vandermonde(Lambda::NamedTuple, S; basis=:chebyshev)
```

### Key Assumptions (Tensor Product)

1. **Uniform Nodes Assumption** (Line 119):
   ```julia
   unique_points = unique(S[:, 1])
   ```
   - Assumes all dimensions have the same unique points
   - Only looks at first column to get node locations
   - This is the PRIMARY limitation for anisotropic grids

2. **Single Point Lookup** (Line 125):
   ```julia
   point_indices = Dict(point => i for (i, point) in enumerate(unique_points))
   ```
   - Creates a single lookup table for all dimensions
   - Assumes point indices are consistent across dimensions

3. **Tensor Product Evaluation** (Lines 142-150, 180-189):
   ```julia
   for k = 1:N
       degree = Int(Lambda.data[j, k])
       point = S[i, k]
       point_idx = point_indices[point]
       P *= eval_cache[degree][point_idx]
   end
   ```
   - Uses same point_indices for all dimensions
   - Cannot handle different nodes per dimension

## Algorithm Flow

1. **Extract unique points** - Only from first dimension
2. **Precompute polynomial evaluations** - For all degrees at unique points
3. **Build Vandermonde matrix** - Using tensor product of 1D evaluations

## Dependent Functions

### Direct Callers
1. **MainGenerate** (src/Main_Gen.jl:118)
   ```julia
   VL = lambda_vandermonde(Lambda, matrix_from_grid, basis=basis)
   ```

2. **compute_norm** (src/scaling_utils.jl)
   - Used in norm computation for polynomial approximation

3. **l2_norm functions** (src/l2_norm.jl)
   - May use for polynomial evaluation

### Indirect Dependencies
- **SupportGen**: Generates Lambda structure
- **Constructor**: Through MainGenerate
- **Polynomial evaluation**: Various analysis functions

## Performance Optimizations

1. **Caching Strategy**:
   - Precomputes all polynomial evaluations
   - Uses dictionary lookup for fast access
   - Avoids redundant calculations

2. **Type Stability**:
   - Infers type from input matrix S
   - Maintains type consistency throughout

3. **Specialized Paths**:
   - Exact computation for Rational/Integer types
   - Cosine formula for floating point Chebyshev

## Required Changes for Anisotropic Support

### 1. Node Storage
Instead of:
```julia
unique_points = unique(S[:, 1])
```

Need:
```julia
unique_points_per_dim = [unique(S[:, d]) for d in 1:N]
```

### 2. Point Indices
Instead of:
```julia
point_indices = Dict(point => i for (i, point) in enumerate(unique_points))
```

Need:
```julia
point_indices_per_dim = [
    Dict(point => i for (i, point) in enumerate(unique_points_per_dim[d]))
    for d in 1:N
]
```

### 3. Evaluation Cache
Instead of:
```julia
eval_cache = Dict{Int,Vector{T}}()
```

Need:
```julia
eval_cache_per_dim = [Dict{Int,Vector{T}}() for d in 1:N]
```

### 4. Matrix Construction
Instead of:
```julia
point_idx = point_indices[point]
P *= eval_cache[degree][point_idx]
```

Need:
```julia
point_idx = point_indices_per_dim[k][point]
P *= eval_cache_per_dim[k][degree][point_idx]
```

## Backward Compatibility Strategy

### Option 1: Detect Grid Type
```julia
function lambda_vandermonde(Lambda::NamedTuple, S; basis=:chebyshev)
    if is_tensor_product_grid(S)
        # Use current fast implementation
        return lambda_vandermonde_tensor(Lambda, S, basis=basis)
    else
        # Use new anisotropic implementation
        return lambda_vandermonde_anisotropic(Lambda, S, basis=basis)
    end
end
```

### Option 2: Add Parameter
```julia
function lambda_vandermonde(Lambda::NamedTuple, S; basis=:chebyshev, anisotropic=false)
    if !anisotropic
        # Current implementation
    else
        # New implementation
    end
end
```

## Numerical Considerations

1. **Conditioning**: Anisotropic grids may have different conditioning
2. **Ordering**: Need consistent ordering of multi-indices
3. **Precision**: Maintain type flexibility for exact arithmetic

## Test Coverage Gaps

1. No tests for mixed node types
2. No tests for non-tensor product structures
3. Limited tests for high dimensions
4. No performance benchmarks for large grids

## Next Steps

1. Implement `is_tensor_product_grid` detection function
2. Create `lambda_vandermonde_anisotropic` as separate function
3. Update MainGenerate to pass anisotropic flag
4. Comprehensive testing of both paths
5. Performance optimization of anisotropic path