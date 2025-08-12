# GlobTim Project Memory

## HPC Compilation Approaches

### ❌ UNSUITABLE: Standalone/Inline Code Approach
**Date Tested:** August 12, 2025  
**Status:** REJECTED - Do not use

The standalone approach that includes all code inline in a single SLURM script without proper package management is **not suitable** for GlobTim because:

1. **Missing Critical Dependencies**: GlobTim requires external packages to function properly:
   - `ForwardDiff` for automatic differentiation
   - `HomotopyContinuation` for solving polynomial systems
   - `DynamicPolynomials` for polynomial manipulation
   - `Optim` for optimization algorithms
   - `StaticArrays` for performance-critical array operations
   - `TimerOutputs` for performance monitoring

2. **Incomplete Functionality**: Without these dependencies, core GlobTim features cannot work:
   - Cannot perform gradient computations
   - Cannot solve polynomial systems
   - Cannot run optimization algorithms
   - Performance is severely degraded without StaticArrays

3. **False Positives**: While standalone scripts may appear to "work" by defining simple test functions, they don't provide the full GlobTim functionality needed for real computations.

### ✅ CORRECT APPROACH: Proper Package Management

GlobTim must be compiled with its full dependency chain using one of these methods:

1. **Offline Bundle Creation** (for air-gapped clusters):
   - Create a complete Julia depot locally with all dependencies
   - Transfer the depot bundle to the HPC cluster
   - Use the offline depot for compilation

2. **Direct Package Installation** (if cluster has internet):
   - Use `Pkg.instantiate()` to install all dependencies
   - Ensure proper JULIA_DEPOT_PATH configuration
   - Handle precompilation appropriately

3. **Container-Based Deployment**:
   - Use Singularity/Apptainer containers with pre-installed dependencies
   - Ensures reproducible environment across different HPC systems

## Key Lessons Learned

- Always verify that external dependencies are available and loadable
- Test actual GlobTim functionality, not just basic Julia operations
- Document dependency requirements clearly in Project.toml
- Use proper package management even if it's more complex to set up initially