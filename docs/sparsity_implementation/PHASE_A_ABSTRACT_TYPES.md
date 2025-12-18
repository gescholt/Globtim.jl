# Phase A: Abstract Type Refactoring

**Goal**: Introduce abstract type hierarchies for cleaner architecture and better extensibility

**Timeline**: 8-12 hours

**Priority**: 🟡 MEDIUM - Improves long-term maintainability, not critical for immediate functionality

**Prerequisite**: Complete Option 2 (core re-optimization implementation)

---

## Motivation

### Current State (Symbol-based dispatch)

```julia
# Basis type
basis::Symbol = :chebyshev  # or :legendre

# Code is full of conditionals
if basis == :chebyshev
    # Chebyshev-specific code
elseif basis == :legendre
    # Legendre-specific code
end
```

**Problems**:
- No type safety (can pass invalid symbol)
- Runtime string comparison (slower)
- Hard to extend (need to modify all if/else chains)
- No basis-specific parameters
- Verbose and error-prone

### Future State (Type-based dispatch)

```julia
# Basis types
abstract type AbstractBasis end
struct ChebyshevBasis <: AbstractBasis end
struct LegendreBasis <: AbstractBasis end

# Clean dispatch
function evaluate(basis::ChebyshevBasis, x, degree)
    # Chebyshev implementation
end

function evaluate(basis::LegendreBasis, x, degree)
    # Legendre implementation
end
```

**Benefits**:
- Type safety
- Faster dispatch
- Easy to extend (just add new type)
- Basis-specific parameters possible
- Compiler optimizations

---

## Implementation Tasks

### Task 1: Basis Type Hierarchy (3 hours)

**File**: `src/basis_types.jl`

#### 1.1 Define Abstract Type Hierarchy

```julia
"""
Abstract base type for all polynomial bases.
"""
abstract type AbstractBasis end

"""
Abstract type for orthogonal polynomial bases (Chebyshev, Legendre, etc.)
"""
abstract type OrthogonalBasis <: AbstractBasis end

"""
Abstract type for monomial bases.
"""
abstract type MonomialBasis <: AbstractBasis end
```

#### 1.2 Concrete Orthogonal Basis Types

```julia
"""
    ChebyshevBasis

Chebyshev polynomial basis T_n(x) on [-1,1].

# Fields
- `normalized::Bool`: Whether to use normalized basis
- `power_of_two_denom::Bool`: Use power-of-2 denominators for rational arithmetic
"""
struct ChebyshevBasis <: OrthogonalBasis
    normalized::Bool
    power_of_two_denom::Bool
end

# Convenience constructors
ChebyshevBasis() = ChebyshevBasis(true, false)
ChebyshevBasis(normalized::Bool) = ChebyshevBasis(normalized, false)

"""
    LegendreBasis

Legendre polynomial basis P_n(x) on [-1,1].

# Fields
- `normalized::Bool`: Whether to use normalized basis
"""
struct LegendreBasis <: OrthogonalBasis
    normalized::Bool
end

LegendreBasis() = LegendreBasis(true)
```

#### 1.3 Concrete Monomial Basis Types

```julia
"""
    StandardMonomialBasis

Standard monomial basis: 1, x, x², x³, ...
"""
struct StandardMonomialBasis <: MonomialBasis end

"""
    SparseMonomialBasis

Sparse monomial basis where only subset of terms are active.

# Fields
- `active_indices::Vector{Int}`: Indices of non-zero coefficients
- `threshold::Float64`: Sparsity threshold used
"""
struct SparseMonomialBasis <: MonomialBasis
    active_indices::Vector{Int}
    threshold::Float64
end
```

#### 1.4 Conversion Functions

```julia
"""
Convert Symbol to basis type (for backward compatibility).
"""
function symbol_to_basis(basis_sym::Symbol; normalized::Bool=true, power_of_two_denom::Bool=false)
    if basis_sym == :chebyshev
        return ChebyshevBasis(normalized, power_of_two_denom)
    elseif basis_sym == :legendre
        return LegendreBasis(normalized)
    else
        throw(ArgumentError("Unknown basis: $basis_sym"))
    end
end

"""
Convert basis type to Symbol (for backward compatibility).
"""
basis_to_symbol(::ChebyshevBasis) = :chebyshev
basis_to_symbol(::LegendreBasis) = :legendre
basis_to_symbol(::MonomialBasis) = :monomial
```

#### 1.5 Basis Properties

```julia
"""Test if basis is orthogonal."""
is_orthogonal(::OrthogonalBasis) = true
is_orthogonal(::MonomialBasis) = false

"""Test if basis is normalized."""
is_normalized(b::ChebyshevBasis) = b.normalized
is_normalized(b::LegendreBasis) = b.normalized
is_normalized(::MonomialBasis) = false

"""Get basis name as string."""
basis_name(::ChebyshevBasis) = "Chebyshev"
basis_name(::LegendreBasis) = "Legendre"
basis_name(::StandardMonomialBasis) = "Standard Monomial"
basis_name(::SparseMonomialBasis) = "Sparse Monomial"
```

**Deliverables**:
- [ ] `src/basis_types.jl` created
- [ ] All types defined
- [ ] Conversion functions
- [ ] Property query functions
- [ ] Unit tests in `test/test_basis_types.jl`

---

### Task 2: Update ApproxPoly Structure (2 hours)

**File**: `src/Structures.jl`

#### 2.1 Update Type Definition

```julia
struct ApproxPoly{T <: Number, S <: Union{Float64, Vector{Float64}}, B <: AbstractBasis}
    coeffs::Vector{T}
    support::Any
    degree::Any
    nrm::Float64
    N::Int
    scale_factor::S
    grid::Matrix{Float64}
    z::Vector{Float64}
    basis::B  # Changed from Symbol to AbstractBasis
    precision::PrecisionType
    normalized::Bool  # DEPRECATED: now in basis
    power_of_two_denom::Bool  # DEPRECATED: now in basis
    cond_vandermonde::Float64
end
```

#### 2.2 Update Constructors

```julia
# Constructor with backward compatibility
function ApproxPoly{T}(
    coeffs::Vector{T},
    support,
    degree,
    nrm::Float64,
    N::Int,
    scale_factor::S,
    grid::Matrix{Float64},
    z::Vector{Float64},
    basis::Union{Symbol, AbstractBasis},  # Accept both!
    precision::PrecisionType,
    normalized::Bool,
    power_of_two_denom::Bool,
    cond_vandermonde::Float64
) where {T <: Number, S <: Union{Float64, Vector{Float64}}}
    # Convert Symbol to basis type if needed
    basis_typed = if isa(basis, Symbol)
        symbol_to_basis(basis, normalized=normalized, power_of_two_denom=power_of_two_denom)
    else
        basis
    end

    B = typeof(basis_typed)
    new{T, S, B}(coeffs, support, degree, nrm, N, scale_factor, grid, z,
                 basis_typed, precision, normalized, power_of_two_denom, cond_vandermonde)
end
```

#### 2.3 Update Accessor Functions

```julia
get_basis(p::ApproxPoly) = p.basis
get_basis_symbol(p::ApproxPoly) = basis_to_symbol(p.basis)  # For backward compat
is_normalized(p::ApproxPoly) = is_normalized(p.basis)
has_power_of_two_denom(p::ApproxPoly{T,S,ChebyshevBasis}) where {T,S} = p.basis.power_of_two_denom
has_power_of_two_denom(p::ApproxPoly) = false
```

**Deliverables**:
- [ ] `ApproxPoly` updated with type parameter
- [ ] Backward compatibility maintained
- [ ] Accessor functions updated
- [ ] Constructors handle both Symbol and types

---

### Task 3: Linear Solver Abstraction (2 hours)

**File**: `src/solver_types.jl`

#### 3.1 Define Solver Hierarchy

```julia
"""
Abstract base type for linear solvers.
"""
abstract type AbstractLinearSolver end

"""
LU factorization solver (fast, moderate stability).
"""
struct LUSolver <: AbstractLinearSolver end

"""
QR factorization solver (stable, recommended for most cases).
"""
struct QRSolver <: AbstractLinearSolver end

"""
SVD solver (most stable, slowest, best for ill-conditioned problems).
"""
struct SVDSolver <: AbstractLinearSolver end

"""
High-precision solver wrapping another solver.

# Fields
- `precision_type::Type{<:AbstractFloat}`: Arithmetic precision (BigFloat, etc.)
- `inner_solver::AbstractLinearSolver`: Wrapped solver
"""
struct HighPrecisionSolver{P <: AbstractFloat} <: AbstractLinearSolver
    precision_type::Type{P}
    inner_solver::AbstractLinearSolver
end

HighPrecisionSolver(P::Type{<:AbstractFloat}) = HighPrecisionSolver(P, QRSolver())

"""
Sparse-constrained solver for sparsity-enforcing re-optimization.

# Fields
- `sparsity_pattern::BitVector`: Which coefficients are active
- `precision_type::Type{<:AbstractFloat}`: Arithmetic precision
- `inner_solver::AbstractLinearSolver`: Wrapped solver
"""
struct SparseConstrainedSolver{P <: AbstractFloat} <: AbstractLinearSolver
    sparsity_pattern::BitVector
    precision_type::Type{P}
    inner_solver::AbstractLinearSolver
end
```

#### 3.2 Solver Interface Functions

```julia
"""
Solve linear system using specified solver.
"""
function solve_linear_system(
    solver::LUSolver,
    A::AbstractMatrix,
    b::AbstractVector
)
    return A \ b  # Uses LU
end

function solve_linear_system(
    solver::QRSolver,
    A::AbstractMatrix,
    b::AbstractVector
)
    Q, R = qr(A)
    return R \ (Q' * b)
end

function solve_linear_system(
    solver::SVDSolver,
    A::AbstractMatrix,
    b::AbstractVector
)
    U, S, V = svd(A)
    return V * Diagonal(1 ./ S) * U' * b
end

function solve_linear_system(
    solver::HighPrecisionSolver{P},
    A::AbstractMatrix{T},
    b::AbstractVector{T}
) where {P <: AbstractFloat, T}
    # Convert to high precision
    A_hp = convert.(solver.precision_type, A)
    b_hp = convert.(solver.precision_type, b)

    # Solve in high precision
    x_hp = solve_linear_system(solver.inner_solver, A_hp, b_hp)

    # Convert back to original type
    return convert.(T, x_hp)
end
```

#### 3.3 Integration with Main_Gen.jl

```julia
# Replace hardcoded LU solver with configurable solver
function Constructor(
    TR::test_input,
    degree_in::Int;
    basis::Union{Symbol, AbstractBasis} = :chebyshev,
    solver::AbstractLinearSolver = LUSolver(),  # NEW parameter
    # ... other parameters
)
    # ... existing code ...

    # Solve linear system
    sol = solve_linear_system(solver, G_original, RHS)

    # ... rest of code ...
end
```

**Deliverables**:
- [ ] `src/solver_types.jl` created
- [ ] Solver hierarchy defined
- [ ] Interface functions implemented
- [ ] Integration with Constructor
- [ ] Tests for each solver type

---

### Task 4: Precision Strategy Enhancement (2 hours)

**File**: `src/precision_strategies.jl`

#### 4.1 Abstract Precision Hierarchy

```julia
"""
Abstract base type for precision strategies.
"""
abstract type AbstractPrecisionStrategy end

"""
Float64 precision strategy.
"""
struct Float64Strategy <: AbstractPrecisionStrategy end

"""
Rational number precision strategy.

# Fields
- `power_of_two_denom::Bool`: Use power-of-2 denominators
"""
struct RationalStrategy <: AbstractPrecisionStrategy
    power_of_two_denom::Bool
end

RationalStrategy() = RationalStrategy(false)

"""
BigFloat precision strategy.

# Fields
- `bits::Int`: Precision in bits (default 256)
"""
struct BigFloatStrategy <: AbstractPrecisionStrategy
    bits::Int
end

BigFloatStrategy() = BigFloatStrategy(256)

"""
Adaptive precision: high precision for expansion, standard for evaluation.

# Fields
- `expansion_precision::Type{<:AbstractFloat}`: For basis expansion
- `evaluation_precision::Type{<:AbstractFloat}`: For polynomial evaluation
"""
struct AdaptiveStrategy <: AbstractPrecisionStrategy
    expansion_precision::Type{<:AbstractFloat}
    evaluation_precision::Type{<:AbstractFloat}
end

AdaptiveStrategy() = AdaptiveStrategy(BigFloat, Float64)

"""
Monomial sparse strategy: high precision for ill-conditioned monomial basis.

# Fields
- `gram_matrix_precision::Type{<:AbstractFloat}`: For G = V'V
- `rhs_precision::Type{<:AbstractFloat}`: For b = V'F
- `output_precision::Type{<:AbstractFloat}`: For final coefficients
"""
struct MonomialSparseStrategy <: AbstractPrecisionStrategy
    gram_matrix_precision::Type{<:AbstractFloat}
    rhs_precision::Type{<:AbstractFloat}
    output_precision::Type{<:AbstractFloat}
end

MonomialSparseStrategy() = MonomialSparseStrategy(BigFloat, BigFloat, Float64)
```

#### 4.2 Conversion Between Enum and Types

```julia
"""Convert PrecisionType enum to strategy type."""
function enum_to_strategy(prec::PrecisionType)
    if prec == Float64Precision
        return Float64Strategy()
    elseif prec == RationalPrecision
        return RationalStrategy()
    elseif prec == BigFloatPrecision
        return BigFloatStrategy()
    elseif prec == AdaptivePrecision
        return AdaptiveStrategy()
    else
        throw(ArgumentError("Unknown precision type: $prec"))
    end
end

"""Convert strategy type to PrecisionType enum."""
strategy_to_enum(::Float64Strategy) = Float64Precision
strategy_to_enum(::RationalStrategy) = RationalPrecision
strategy_to_enum(::BigFloatStrategy) = BigFloatPrecision
strategy_to_enum(::AdaptiveStrategy) = AdaptivePrecision
strategy_to_enum(::MonomialSparseStrategy) = AdaptivePrecision  # Closest match
```

**Deliverables**:
- [ ] `src/precision_strategies.jl` created
- [ ] All strategy types defined
- [ ] Conversion functions
- [ ] Backward compatibility with enum

---

### Task 5: Migration & Testing (3-4 hours)

#### 5.1 Create Migration Guide

**File**: `docs/sparsity_implementation/MIGRATION_TO_ABSTRACT_TYPES.md`

Content:
- What changed
- How to update code
- Backward compatibility notes
- Performance benefits

#### 5.2 Update Existing Code

Files to update:
- [ ] `src/Main_Gen.jl` - Constructor function
- [ ] `src/ApproxConstruct.jl` - lambda_vandermonde calls
- [ ] `src/cheb_pol.jl` - Chebyshev functions
- [ ] `src/lege_pol.jl` - Legendre functions
- [ ] `src/OrthogonalInterface.jl` - Basis conversions
- [ ] All test files using `basis=:chebyshev`

#### 5.3 Regression Testing

Ensure all existing tests pass:
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

#### 5.4 Performance Benchmarking

Compare before/after:
- Constructor performance
- Type stability (use @code_warntype)
- Memory allocations

**Deliverables**:
- [ ] Migration guide written
- [ ] All code migrated
- [ ] All tests pass
- [ ] Performance validated

---

## Migration Strategy

### Phase 1: Add New Types (Non-breaking)

1. Create new files with type definitions
2. Add conversion functions
3. Update ApproxPoly to accept both Symbol and types
4. Export new types

**Result**: New code can use types, old code still works

### Phase 2: Update Internal Code

1. Change Constructor internals to use types
2. Update lambda_vandermonde dispatch
3. Update basis-specific functions

**Result**: Internal code uses types, external API unchanged

### Phase 3: Deprecate Symbol Usage

1. Add deprecation warnings for Symbol usage
2. Update documentation to recommend types
3. Update examples to use types

**Result**: Users warned to migrate

### Phase 4: Remove Symbol Support (Breaking)

1. Remove Symbol constructors
2. Remove conversion functions
3. Update major version number

**Result**: Clean type-based API

**Recommendation**: Stop after Phase 2 for now. Full migration can wait.

---

## Benefits Summary

### Type Safety
```julia
# Before: runtime error
pol = Constructor(TR, 10, basis=:chebyshef)  # Typo!

# After: compile-time error
pol = Constructor(TR, 10, basis=ChebyshevBsis())  # Typo caught!
```

### Performance
```julia
# Before: runtime dispatch
if basis == :chebyshev
    chebyshev_code()
end

# After: compile-time dispatch
chebyshev_code(basis::ChebyshevBasis) = ...
```

### Extensibility
```julia
# Before: modify all if/else chains
# After: just add new type
struct HermiteBasis <: OrthogonalBasis end
```

### Clarity
```julia
# Before
pol = Constructor(TR, 10, basis=:chebyshev, normalized=true, power_of_two_denom=true)

# After
basis = ChebyshevBasis(normalized=true, power_of_two_denom=true)
pol = Constructor(TR, 10, basis=basis)
```

---

## Testing Requirements

### Unit Tests
- [ ] Basis type creation
- [ ] Symbol ↔ Type conversion
- [ ] Solver type dispatch
- [ ] Precision strategy selection
- [ ] ApproxPoly with typed basis

### Integration Tests
- [ ] Constructor with each basis type
- [ ] Constructor with each solver type
- [ ] Backward compatibility with Symbols
- [ ] Performance benchmarks

### Regression Tests
- [ ] All existing tests pass
- [ ] Examples still work
- [ ] No performance degradation

---

## Success Criteria

1. ✅ All new types defined and documented
2. ✅ Backward compatibility maintained (Symbols still work)
3. ✅ All existing tests pass
4. ✅ Performance same or better
5. ✅ Type stability verified with @code_warntype
6. ✅ Examples updated to show new API
7. ✅ Migration guide written

---

## Next Steps After Phase A

1. Apply abstract types to Option 2 implementation
2. Create strongly-typed sparse polynomial types
3. Use type system for automatic solver selection
4. Extend to new basis types (Hermite, Laguerre, etc.)
