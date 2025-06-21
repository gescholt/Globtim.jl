# Globtim Development Roadmap

## Current Status (v1.0.4)
- ✅ All tests passing
- ✅ Type-stable ApproxPoly structure implemented
- ✅ TimerOutputs integration for performance profiling
- ✅ Unified orthogonal polynomial interface
- ✅ Both Chebyshev and Legendre basis support
- ✅ HomotopyContinuation.jl and Msolve integration

## Near-term Development

### Algorithm Improvements
- [ ] **Adaptive degree selection**: Automatically choose optimal polynomial degree
- [ ] **Domain decomposition**: Handle high-dimensional problems via subdivision
- [ ] **Adaptive Sampling**: still needs to produce numerically stable set of nodes for computing polynomial least squares.
- [ ] **Per-dimension sampling**: Support different grid densities in each dimension while maintaining Chebyshev/Legendre distribution properties

### Code Checks
- [ ] **Complete test coverage**: Ensure all functions have comprehensive tests
- [ ] **Benchmarking suite**: Standardized performance testing across versions
- [ ] **Documentation**: Complete API documentation with examples
- [ ] **Type stability audit**: Eliminate remaining type instabilities
  - **Critical**: Fix broken `solve_polynomial_system_from_approx` in `src/hom_solve.jl:76` (references non-existent ApproxPoly fields)
  - Replace Union type runtime dispatch in `src/Structures.jl` sample_range handling
  - Optimize bounds checking in `src/refine.jl:129-135` optimization loops
  - Replace global `@polyvar x` variables with parameter passing
  - **Low**: Add `@code_warntype` tests for critical path functions
  
