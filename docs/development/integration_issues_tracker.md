# Integration Issues Tracker

This document tracks poorly integrated functions and components that need investigation.

## Anisotropic Grid Integration (2025-07-25)

### Issue: Constructor doesn't accept pre-generated grids

**Functions involved:**
- `Constructor(T::test_input, degree; ...)` in `src/Main_Gen.jl:186`
- `MainGenerate(f, n::Int, d, ...)` in `src/Main_Gen.jl:42`
- `generate_anisotropic_grid(grid_points_per_dim, ...)` in `src/grids.jl`

**Problem:**
- Constructor expects integer degree, not grids
- Type mismatch when passing grid: `MethodError: no method matching +(::Int64, ::SVector{2, Float64})`
- No clear path to use anisotropic grids with polynomial approximation

**Impact:**
- Cannot create polynomial approximations on anisotropic grids
- Forces workarounds in tests and examples
- Limits the utility of anisotropic grid feature

**Workaround:**
Use L2 norm functions directly without creating polynomial objects.

---

## Lambda Vandermonde Type Issues (Previously documented)

**Functions involved:**
- `lambda_vandermonde` and variants in `src/`
- Multiple type-specific implementations created but not fully integrated

**Problem:**
- Type instability with different precision types
- Multiple versions of the function exist (original, fix, minimal, typefix)
- Unclear which version should be used when

---

## Grid Format Conversions

**Functions involved:**
- `convert_grid_format` in `src/grids.jl`
- Various functions expecting different grid representations

**Problem:**
- Inconsistent grid representations (Array{SVector} vs Matrix)
- Not all functions handle both formats
- Conversion overhead in performance-critical paths

---

## API Inconsistencies

### compute_l2_norm_quadrature signature

**Issue:** The function uses positional arguments but users might expect keyword arguments.

**Current signature:**
```julia
compute_l2_norm_quadrature(f::Function, n_points::Vector{Int}, basis::Symbol=:chebyshev)
```

**Common mistake:**
```julia
# Wrong - basis as keyword argument
compute_l2_norm_quadrature(f, [nx, ny], basis=:chebyshev)

# Correct - basis as positional argument  
compute_l2_norm_quadrature(f, [nx, ny], :chebyshev)
```

---

## To Investigate

1. **MainGenerate parameter `d`**: Overloaded meaning (degree vs grid) causes confusion
2. **Grid type parameters**: Some functions assume Float64, others are generic
3. **Basis function integration**: How do different bases interact with anisotropic grids?
4. **Function signature errors**: Functions expecting vectors/scalars but receiving SVectors