# Strategy to Fix lambda_vandermonde Type Parametrization

## Current State

The Globtim package has comprehensive exact arithmetic infrastructure:
- **PrecisionType enum**: Float64Precision, RationalPrecision, BigFloatPrecision, BigIntPrecision
- **Type conversion**: `_convert_value` function handles all conversions
- **Exact polynomials**: `symbolic_chebyshev`, `symbolic_legendre` with exact coefficients
- **Exact conversion**: `construct_orthopoly_polynomial` converts to monomial basis exactly

## The Blocking Issue

In `src/ApproxConstruct.jl`, lines 112-188, `lambda_vandermonde` is hardcoded to Float64:

```julia
# Line 115
V = zeros(Float64, n, m)  # HARDCODED!

# Line 128
eval_cache = Dict{Int,Vector{Float64}}()  # HARDCODED!

# Lines throughout use Float64 explicitly
```

This prevents the entire pipeline from using arbitrary precision types.

## Minimal Fix Required

### Step 1: Make lambda_vandermonde Type-Parametric

```julia
function lambda_vandermonde(Lambda::NamedTuple, S::Matrix{T}; 
                          basis=:chebyshev, normalize=true) where T<:Real
    n = size(S, 1)
    m = Lambda.size[1]
    
    # Initialize with input type
    V = zeros(T, n, m)
    
    # Type-stable polynomial evaluation
    if basis == :chebyshev
        eval_func = normalize ? (deg, x) -> eval_chebyshev_normalized(deg, x, T) : 
                               (deg, x) -> eval_chebyshev(deg, x, T)
    else  # :legendre
        eval_func = normalize ? (deg, x) -> eval_legendre_normalized(deg, x, T) :
                               (deg, x) -> eval_legendre(deg, x, T)
    end
    
    # Evaluate basis polynomials
    lambda_exp = lambda_expansion_alt(Lambda)
    
    for i in 1:n
        for j in 1:m
            V[i,j] = one(T)
            for k in 1:size(S, 2)
                degree = lambda_exp[j,k]
                V[i,j] *= eval_func(degree, S[i,k])
            end
        end
    end
    
    return V
end
```

### Step 2: Add Type-Stable Evaluation Functions

```julia
# Chebyshev evaluation with type parameter
function eval_chebyshev(n::Int, x::T, ::Type{T}) where T<:Real
    if n == 0
        return one(T)
    elseif n == 1
        return x
    else
        # Stable recurrence relation
        T_prev2 = one(T)
        T_prev1 = x
        two = convert(T, 2)
        for k in 2:n
            T_curr = two * x * T_prev1 - T_prev2
            T_prev2, T_prev1 = T_prev1, T_curr
        end
        return T_prev1
    end
end

function eval_chebyshev_normalized(n::Int, x::T, ::Type{T}) where T<:Real
    # Use existing _chebyshev_normalization_factor
    if n == 0
        norm_factor = one(T) / sqrt(_convert_value(π, T))
    else
        norm_factor = sqrt(_convert_value(2/π, T))
    end
    return norm_factor * eval_chebyshev(n, x, T)
end
```

### Step 3: Update MainGenerate to Pass Correct Types

In `MainGenerate`, ensure the grid is converted to the desired precision before calling `lambda_vandermonde`:

```julia
# In MainGenerate, after grid creation
if precision != Float64Precision
    # Convert grid to desired precision
    grid_matrix = Matrix{T}(undef, size(grid_matrix)...)
    for i in eachindex(grid_matrix)
        grid_matrix[i] = _convert_value(grid_matrix[i], precision)
    end
end

# Now lambda_vandermonde will use the correct type
V = lambda_vandermonde(Lambda, grid_matrix; basis=basis, normalize=true)
```

## Benefits of This Approach

1. **Minimal Changes**: Only touches the blocking function and its callers
2. **Leverages Existing Infrastructure**: Uses the already-implemented exact arithmetic system
3. **Type Safety**: Maintains type stability throughout the computation
4. **Backward Compatible**: Float64 remains the default, other types opt-in

## Testing Strategy

```julia
@testset "Type-Parametric Vandermonde" begin
    # Test with different precision types
    Lambda = (data = [1 0; 0 1; 1 1], size = (3,))
    
    # Float64 (default behavior)
    S_f64 = [0.5 0.5; -0.5 0.5; 0.0 0.0]
    V_f64 = lambda_vandermonde(Lambda, S_f64)
    @test eltype(V_f64) == Float64
    
    # Rational
    S_rat = convert(Matrix{Rational{BigInt}}, S_f64)
    V_rat = lambda_vandermonde(Lambda, S_rat)
    @test eltype(V_rat) == Rational{BigInt}
    
    # BigFloat
    S_big = convert(Matrix{BigFloat}, S_f64)
    V_big = lambda_vandermonde(Lambda, S_big)
    @test eltype(V_big) == BigFloat
    
    # Verify results are consistent
    @test Float64.(V_rat) ≈ V_f64
    @test Float64.(V_big) ≈ V_f64
end
```

## Implementation Priority

1. **Critical (Day 1)**: Fix lambda_vandermonde type parametrization
2. **High (Day 2)**: Update MainGenerate to pass correct types
3. **Medium (Day 3)**: Add comprehensive tests
4. **Low (Week 2)**: Optimize performance for special cases

## Key Insight

The infrastructure for exact arithmetic already exists in Globtim. The only blocker is the hardcoded Float64 in lambda_vandermonde. Once fixed, the entire pipeline can leverage:
- Exact rational arithmetic for algebraic functions
- Arbitrary precision for ill-conditioned problems
- Symbolic computation where beneficial

This unblocks the ability to "push symbolic exactness as far as possible" before numerical computation.