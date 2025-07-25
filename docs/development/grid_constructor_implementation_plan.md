# Grid-Based MainGenerate Implementation Plan

## Problem Summary

The current `MainGenerate` function only accepts degree specifications and generates its own grids internally. This prevents users from leveraging pre-generated anisotropic grids with polynomial approximation.

## Current Architecture Analysis

### Constructor Function
- **Location**: `src/Main_Gen.jl:186-248`
- **Signature**: `Constructor(T::test_input, degree; kwargs...)`
- **Limitation**: Expects `degree` to be Int or Tuple, not a grid

### MainGenerate Function
- **Location**: `src/Main_Gen.jl:42-135`
- **Signature**: `MainGenerate(f, n::Int, d, delta, alpha, scale_factor, scl; kwargs...)`
- **Issue**: Line 58-66 assumes `d` is degree-related, causing type errors when passed a grid

### Key Integration Points
1. `SupportGen(n, d)` - generates polynomial support based on degree
2. Grid generation happens inside MainGenerate (lines 79-83)
3. Lambda support structure is tightly coupled with degree specification

## Implementation Strategy

### Primary Approach: Extend MainGenerate to Accept Grid Input

**Advantages**: 
- Minimal API changes
- Backward compatible
- Leverages existing infrastructure

**Implementation Steps**:

1. **Type Union for `d` parameter**:
```julia
function MainGenerate(
    f, n::Int, 
    d::Union{Tuple{Symbol,Int}, Tuple{Symbol,Vector{Int}}, Matrix{Float64}},
    ...
)
```

2. **Grid detection and handling** (after line 57):
```julia
# Check if d is a grid (Matrix format)
if isa(d, Matrix)
    # Validate grid dimensions
    @assert size(d, 2) == n "Grid dimension mismatch: expected $n, got $(size(d, 2))"
    @assert size(d, 1) > 0 "Empty grid provided"
    
    # Store grid information
    grid_provided = true
    matrix_from_grid = d
    actual_GN = size(d, 1)
    
    # Infer polynomial degree from grid size
    # For tensor product grids: n_points ≈ (degree + 1)^dim
    n_per_dim = round(Int, actual_GN^(1/n))
    degree_est = n_per_dim - 1
    
    # Generate Lambda support based on inferred degree
    Lambda = SupportGen(n, (:one_d_for_all, degree_est))
    
    # Skip D calculation and K sampling since we have a grid
    D = degree_est
    K = actual_GN  # Use grid size as sample count
else
    # Existing degree-based logic
    grid_provided = false
    
    # Current D calculation (lines 58-66)
    D = if d[1] == :one_d_for_all
        maximum(d[2])  
    elseif d[1] == :one_d_per_dim
        maximum(d[2])  
    elseif d[1] == :fully_custom
        0
    else
        throw(ArgumentError("Invalid degree format. Use :one_d_for_all or :one_d_per_dim or :fully_custom."))
    end
    
    m = binomial(n + D, D)  # Dimension of vector space
    K = calculate_samples(m, delta, alpha)
    
    # Use provided GN if given, otherwise compute it
    actual_GN = if isnothing(GN)
        Int(round(K^(1 / n) * scl) + 1)
    else
        GN
    end
    
    Lambda = SupportGen(n, d)
end
```

3. **Conditional Grid Generation** (replace lines 79-84):
```julia
# Only generate grid if not provided
if !grid_provided
    if n <= 0
        grid = generate_grid_small_n(n, actual_GN, basis=basis)
    else
        grid = generate_grid(n, actual_GN, basis=basis)
    end
    matrix_from_grid = reduce(vcat, map(x -> x', reshape(grid, :)))
end
```

4. **Update function evaluation** (lines 93-105):
```julia
# Handle grid format differences
if grid_provided
    # Grid is already in matrix format, create SVectors for evaluation
    grid_points = [SVector{n,Float64}(matrix_from_grid[i,:]) for i in 1:size(matrix_from_grid, 1)]
else
    # Use existing grid (Vector of SVectors)
    grid_points = reshape(grid, :)
end

# Evaluate function on grid points
if isa(scale_factor, Number)
    F = map(x -> f(scale_factor * x + scaled_center), grid_points)
else
    function apply_scale(x)
        scaled_x = SVector{n,Float64}([scale_factor[i] * x[i] for i in 1:n])
        return f(scaled_x + scaled_center)
    end
    F = map(apply_scale, grid_points)
end
```

### Additional Considerations

1. **Grid Format Conversion**:
   - Support both `Matrix{Float64}` (from user) and `Vector{SVector}` (from generate_anisotropic_grid)
   - Provide utility function for conversion:
   ```julia
   function convert_to_matrix_grid(grid::Vector{<:AbstractVector})
       n = length(first(grid))
       matrix = Matrix{Float64}(undef, length(grid), n)
       for (i, point) in enumerate(grid)
           matrix[i, :] = point
       end
       return matrix
   end
   ```

2. **Degree Inference for Anisotropic Grids**:
   - For non-tensor product grids, use maximum points per dimension
   - Store grid structure information for better polynomial construction

3. **Validation Enhancements**:
   - Check for duplicate points in grid
   - Verify grid points are within [-1, 1] for basis functions
   - Warn if grid size doesn't match typical polynomial degree patterns

## Implementation Phases

### Phase 1: Core MainGenerate Extension
1. Add type union for `d` parameter
2. Implement grid detection logic
3. Add conditional grid generation
4. Update function evaluation for grid format
5. Ensure backward compatibility

### Phase 2: Integration and Testing
1. Create comprehensive test suite
2. Test with anisotropic grids from generate_anisotropic_grid
3. Verify polynomial approximation quality
4. Performance benchmarks

### Phase 3: User-Facing API
1. Add Constructor wrapper for grid input
2. Create helper functions for common use cases
3. Update documentation with examples
4. Add validation and error messages

## Testing Strategy

### Unit Tests
```julia
@testset "Grid-based MainGenerate" begin
    # Test 1: Simple 2D grid input
    f = x -> x[1]^2 + x[2]^2
    n = 2
    
    # Create manual grid
    grid = [0.0 0.0; 0.5 0.5; -0.5 -0.5; 1.0 1.0]
    
    # Call with grid
    pol = MainGenerate(f, n, grid, 0.1, 0.99, 1.0, 1.0)
    
    @test pol.grid == grid
    @test pol.N == 4
    @test pol.nrm < 1e-10
    
    # Test 2: Anisotropic grid from generator
    grid_aniso = generate_anisotropic_grid([10, 5], basis=:chebyshev)
    grid_matrix = convert_to_matrix_grid(grid_aniso)
    
    pol_aniso = MainGenerate(f, n, grid_matrix, 0.1, 0.99, 1.0, 1.0)
    
    @test size(pol_aniso.grid, 1) == 50  # 10 * 5
    @test size(pol_aniso.grid, 2) == 2
end
```

### Integration Tests
- Compare polynomial coefficients between degree-based and grid-based construction
- Verify approximation quality on test functions
- Check performance characteristics

### Edge Cases
- Empty grids
- Mismatched dimensions
- Non-tensor product grids (future)
- Very large/small grids

## Migration Path

1. **Documentation**: Update user guide with examples
2. **Deprecation**: Mark current limitations in docs
3. **Examples**: Create notebook showing usage
4. **Performance**: Benchmark against current approach

## Risk Mitigation

1. **Backward Compatibility**: All changes must not break existing code
2. **Type Stability**: Maintain performance characteristics
3. **Error Messages**: Clear guidance when users hit limitations
4. **Fallback**: Graceful degradation to degree-based approach

## Timeline Estimate

- **Week 1**: Implement AnisotropicConstructor
- **Week 2**: Testing and documentation
- **Week 3**: MainGenerate extension design
- **Week 4**: Full implementation and integration

## Success Criteria

1. Users can create polynomials on anisotropic grids
2. No performance regression for existing code
3. Clear documentation and examples
4. All tests pass with new functionality