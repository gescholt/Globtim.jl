# Phase 2: Type-Parametric Grid Generation Implementation Plan

## Overview
The current bottleneck preventing full arbitrary precision support in Globtim is that all grid generation functions return Float64 arrays. Even though `lambda_vandermonde` now supports arbitrary precision, it still receives Float64 grids as input, limiting the benefits of exact arithmetic.

## Current State Analysis

### Hardcoded Float64 Locations
1. **Grid Generation Functions** (`src/Samples.jl`):
   - `generate_grid` → Returns `Array{SVector{n,Float64},n}`
   - `generate_grid_small_n` → Returns `Array{SVector{N,Float64},N}`
   
2. **Anisotropic Grids** (`src/anisotropic_grids.jl`):
   - `generate_anisotropic_grid` → Uses `Vector{Vector{Float64}}()` and `SVector{n_dims,Float64}`
   
3. **Data Structures**:
   - `ApproxPoly` struct → `grid::Matrix{Float64}`, `z::Vector{Float64}`
   - `test_input` struct → `center::Vector{Float64}`, `sample_range::Float64`
   
4. **Main Generation** (`src/Constructor.jl`):
   - `MainGenerate` → `delta::Float64`, `alpha::Float64`, `center::Vector{Float64}`

## Implementation Tasks

### Phase 2.1: Analyze Current Grid Generation (DONE)
- ✓ Identified all grid generation functions
- ✓ Mapped Float64 usage throughout the codebase
- ✓ Understood data flow from grid creation to polynomial approximation

### Phase 2.2: Exact Node Computation Functions
**Goal**: Implement exact computation of Chebyshev and Legendre nodes for rational arithmetic

```julia
# New functions to implement:
- chebyshev_nodes_exact(n::Int, ::Type{T}) where T
- legendre_nodes_exact(n::Int, ::Type{T}) where T
- tensor_grid_exact(nodes::Vector{Vector{T}}) where T
```

**Key considerations**:
- Chebyshev nodes: cos(π(2k-1)/(2n)) for k=1:n
- Need exact rational approximations of cos(π·rational)
- May need lookup tables for common cases (n ≤ 20)

### Phase 2.3: Type-Parametric Grid Generation API
**Goal**: Design backward-compatible API that accepts type parameter

```julia
# Current API:
generate_grid(n::Int, GN::Int; basis=:chebyshev)

# New API options:
# Option 1: Add type parameter with default
generate_grid(n::Int, GN::Int; basis=:chebyshev, T=Float64)

# Option 2: Separate function for typed grids
generate_grid_typed(::Type{T}, n::Int, GN::Int; basis=:chebyshev) where T

# Option 3: Infer from precision parameter
generate_grid(n::Int, GN::Int; basis=:chebyshev, precision=Float64Precision)
```

### Phase 2.4: Implement Core Functions
1. **Exact Chebyshev nodes**:
   - For rational types, use precomputed exact values where possible
   - For n ≤ 20, use lookup tables with exact rational values
   - For larger n, use high-precision approximation and rationalize

2. **Type-parametric generate_grid**:
   - Replace `Array{SVector{n,Float64},n}` with `Array{SVector{n,T},n}`
   - Update node computation to use type T
   - Maintain backward compatibility

3. **Update anisotropic grid generation**:
   - Replace hardcoded Float64 with type parameter
   - Ensure consistency with isotropic case

### Phase 2.5: Update Data Structures
Make key structs type-parametric:

```julia
# Current:
struct ApproxPoly
    grid::Matrix{Float64}
    z::Vector{Float64}
    # ...
end

# New:
struct ApproxPoly{T<:Real}
    grid::Matrix{T}
    z::Vector{T}
    # ...
end
```

### Phase 2.6: Update Call Sites
1. **MainGenerate**:
   - Add precision parameter to control grid type
   - Pass type through to generate_grid
   - Update parameter types (delta, alpha, center)

2. **Constructor**:
   - Infer grid type from precision parameter
   - Pass through to all grid generation calls

3. **Test functions**:
   - Update to specify grid type where needed
   - Ensure tests cover multiple precision types

### Phase 2.7: Testing Strategy
1. **Unit tests**:
   - Test exact node computation for small n
   - Verify type preservation through pipeline
   - Check backward compatibility

2. **Integration tests**:
   - Full pipeline with rational grids
   - Compare accuracy: Float64 vs Rational
   - Verify exact polynomial recovery

3. **Performance tests**:
   - Benchmark grid generation overhead
   - Memory usage comparison
   - Full approximation timing

### Phase 2.8: Incremental Implementation Order
To minimize risk and ensure each step works:

1. **Step 1**: Implement exact node computation functions (standalone)
2. **Step 2**: Create type-parametric generate_grid_typed (new function)
3. **Step 3**: Test with manual grid creation in benchmarks
4. **Step 4**: Update generate_grid to use type parameter
5. **Step 5**: Make ApproxPoly type-parametric
6. **Step 6**: Update MainGenerate to pass type through
7. **Step 7**: Full integration testing

## Expected Outcomes
1. **Exact grids**: Chebyshev nodes as exact rationals where possible
2. **Type consistency**: Grid type flows through entire pipeline
3. **Improved accuracy**: Full benefits of rational arithmetic realized
4. **Backward compatibility**: Existing code continues to work with Float64

## Risk Mitigation
1. **Performance**: Cache exact node computations
2. **Compatibility**: Default to Float64 for all existing APIs
3. **Testing**: Extensive tests before replacing core functions
4. **Rollback**: Keep original functions available as fallback

## Success Metrics
- [ ] Grid generation returns requested type T
- [ ] lambda_vandermonde receives and preserves grid type
- [ ] Full pipeline works with Rational{BigInt} grids
- [ ] Accuracy improvement > 10x for suitable test functions
- [ ] No performance regression for Float64 case
- [ ] All existing tests pass without modification