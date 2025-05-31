# Scale Factor Refactoring Plan

## ✅ COMPLETED - 2024-12-31

## Overview
Eliminate runtime dispatch caused by `scale_factor::Union{Float64,Vector{Float64}}` in ApproxPoly struct.

## Current Problem
```julia
# Runtime dispatch in every polynomial evaluation
if isa(scale_factor, Number)
    scaled_x = SVector{n,Float64}([scale_factor * x[i] for i in 1:n])
else
    scaled_x = SVector{n,Float64}([scale_factor[i] * x[i] for i in 1:n])
end
```

## Solution Strategy: Parametric Type Approach

### Phase 1: Define New Type Structure
```julia
# Add type parameter S for scale factor type
struct ApproxPoly{T<:Number, S<:Union{Float64,Vector{Float64}}}
    coeffs::Vector{T}
    degree::Int
    nrm::Float64
    N::Int
    scale_factor::S  # Now type-stable!
    grid::Matrix{Float64}
    z::Vector{Float64}
    basis::Symbol
    precision::PrecisionType
    normalized::Bool
    power_of_two_denom::Bool
end
```

### Phase 2: Create Type-Stable Scaling Functions
```julia
# Multiple dispatch instead of runtime checks
scale_point(s::Float64, x::AbstractVector) = s .* x
scale_point(s::Vector{Float64}, x::AbstractVector) = s .* x

# For SVector optimization
scale_point(s::Float64, x::SVector{N}) where N = s * x
scale_point(s::SVector{N}, x::SVector{N}) where N = s .* x
```

### Phase 3: Update Constructor Logic
```julia
# Smart constructor that returns correct type
function ApproxPoly(coeffs::Vector{T}, degree, nrm, N, scale_factor::S, grid, z, args...) where {T,S}
    ApproxPoly{T,S}(coeffs, degree, nrm, N, scale_factor, grid, z, args...)
end
```

### Phase 4: Refactor All Usage Sites
1. **Main_Gen.jl**: Remove `isa()` checks, use `scale_point` function
2. **hom_solve.jl**: Update polynomial evaluation
3. **graphs_*.jl**: Update visualization code
4. **Tests**: Update test constructors

## Implementation Steps

### Step 1: Add New Struct Definition (Non-Breaking)
- Keep old struct as `ApproxPolyLegacy`
- Add new parametric struct
- Add conversion methods

### Step 2: Create Compatibility Layer
```julia
# Automatic conversion for old code
ApproxPoly(args...) = construct_approx_poly(args...)

function construct_approx_poly(coeffs, degree, nrm, N, scale_factor, grid, z, args...)
    S = typeof(scale_factor)
    T = eltype(coeffs)
    ApproxPoly{T,S}(coeffs, degree, nrm, N, scale_factor, grid, z, args...)
end
```

### Step 3: Update Core Functions
```julia
# Before
function evaluate_at_point(ap::ApproxPoly, x)
    if isa(ap.scale_factor, Number)
        # scalar scaling
    else
        # vector scaling
    end
end

# After
function evaluate_at_point(ap::ApproxPoly{T,S}, x) where {T,S}
    scaled_x = scale_point(ap.scale_factor, x)
    # No runtime dispatch!
end
```

### Step 4: Performance Testing
- Benchmark before/after for polynomial evaluation
- Test memory allocations
- Verify type stability with `@code_warntype`

### Step 5: Update Documentation
- Add migration guide
- Update examples
- Document performance improvements

## Benefits
1. **Zero runtime dispatch** in polynomial evaluation
2. **Type-stable** field access
3. **Better compiler optimization** opportunities
4. **Cleaner code** without `isa()` checks

## Risks and Mitigation
- **Risk**: Breaking existing code
  - **Mitigation**: Compatibility layer with deprecation warnings
- **Risk**: Increased compilation time
  - **Mitigation**: Limit type parameters, use `@nospecialize` where appropriate

## Testing Plan
```julia
# Type stability tests
@testset "Scale Factor Type Stability" begin
    # Scalar scale factor
    ap_scalar = ApproxPoly{Float64,Float64}(...)
    @test isa(ap_scalar.scale_factor, Float64)
    @inferred evaluate_at_point(ap_scalar, x)
    
    # Vector scale factor
    ap_vector = ApproxPoly{Float64,Vector{Float64}}(...)
    @test isa(ap_vector.scale_factor, Vector{Float64})
    @inferred evaluate_at_point(ap_vector, x)
end
```

## Timeline
- Week 1: Implement new struct and compatibility layer
- Week 2: Update core functions and tests
- Week 3: Performance testing and optimization
- Week 4: Documentation and migration guide

## Implementation Summary (Completed)

### What Was Done
1. **Added type parameter `S` to ApproxPoly struct** - The struct now has two type parameters: `ApproxPoly{T<:Number, S<:Union{Float64,Vector{Float64}}}`

2. **Created `scaling_utils.jl`** with type-stable functions:
   - `scale_point()` - Multiple dispatch for scalar/vector scaling
   - `compute_norm()` - Type-stable norm computation
   - `transform_coordinates()` - For visualization code

3. **Updated all usage sites**:
   - Removed all `isa(scale_factor, Number)` runtime checks
   - Updated Main_Gen.jl to use type-stable scaling
   - Updated visualization code (graphs_cairo.jl, graphs_makie.jl)

4. **Maintained backward compatibility**:
   - All existing constructors continue to work
   - Smart constructor automatically infers types
   - No breaking changes to the API

### Results
- ✅ **Zero runtime dispatch** in polynomial evaluation
- ✅ **Type-stable** field access and operations
- ✅ **All tests passing** - no regressions
- ✅ **Backward compatible** - existing code continues to work

### Performance Impact
- Type inference now works correctly (verified with `@code_warntype`)
- Scale operations are fully inlined by the compiler
- Expected 5-20x performance improvement in hot loops (based on elimination of runtime dispatch)