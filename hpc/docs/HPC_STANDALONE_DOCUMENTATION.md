# GlobTim HPC Standalone Version Documentation

## Overview

Due to Julia package management issues on the HPC cluster (specifically JSON3 dependency conflicts), we've developed a **standalone version** of GlobTim that bypasses the package system entirely. This version is fully functional and production-ready.

## Architecture

### Standalone Module Structure

```
GlobtimProduction.jl (Standalone, no external dependencies)
├── Core Types
│   ├── PrecisionType (Float64)
│   ├── TestInput
│   └── ApproximationResult
├── Benchmark Functions
│   ├── Sphere
│   ├── Rosenbrock
│   ├── Deuflhard
│   ├── Rastrigin
│   └── Ackley
├── Sampling Methods
│   ├── Random sampling
│   ├── Grid sampling
│   └── Quasi-random (Sobol-like)
├── Core Functionality
│   ├── test_input()
│   ├── polynomial_approximate()
│   └── globtim()
└── Performance Tools
    └── benchmark_function()
```

## Key Differences from Original GlobTim

| Feature | Original GlobTim | Standalone Version |
|---------|-----------------|-------------------|
| Package Dependencies | CSV, DataFrames, StaticArrays, ForwardDiff, etc. | None (only Julia stdlib) |
| Module Loading | `using Globtim` | `include("src/GlobtimProduction.jl"); using .GlobtimProduction` |
| Polynomial Methods | Multiple advanced methods | Simplified least-squares |
| I/O Operations | CSV file support | In-memory only |
| Visualization | Plotting support | Data export only |
| Package Management | Required | Not needed |

## Performance Characteristics

Based on HPC testing (Job 59786288):

- **Environment**: 16 CPUs, 32GB RAM, Julia 1.11.2
- **Function Evaluation Speed**:
  - Sphere: 0.044 μs
  - Rosenbrock: 0.047 μs
  - Deuflhard: 0.049 μs
  - Rastrigin: 0.172 μs
  - Ackley: 0.378 μs
- **Parallel Performance**: ~6 million samples/second
- **Memory Usage**: Efficient, scales linearly with sample size

## Usage Examples

### Basic Function Evaluation

```julia
include("src/GlobtimProduction.jl")
using .GlobtimProduction

# Evaluate benchmark functions
result = GlobtimProduction.Sphere([1.0, 1.0])  # Returns 2.0
result = GlobtimProduction.Rosenbrock([1.0, 1.0])  # Returns 0.0
```

### Generate Test Samples

```julia
# Random sampling
samples = GlobtimProduction.generate_samples(
    1000,           # number of samples
    2,              # dimension
    [0.0, 0.0],     # center
    2.0,            # range
    method=:random
)

# Grid sampling (2D only)
samples = GlobtimProduction.generate_samples(
    100, 2, [0.0, 0.0], 2.0, 
    method=:grid
)
```

### Create Test Input

```julia
TR = GlobtimProduction.test_input(
    GlobtimProduction.Sphere,
    dim=2,
    center=[0.0, 0.0],
    sample_range=2.0,
    GN=1000,
    method=:random
)

println("Samples: ", length(TR.sample_points))
println("Min value: ", minimum(TR.function_values))
println("Max value: ", maximum(TR.function_values))
```

### Polynomial Approximation

```julia
result = GlobtimProduction.globtim(
    GlobtimProduction.Rosenbrock,
    dim=2,
    center=[1.0, 1.0],
    sample_range=1.0,
    GN=500,
    degree=4,
    method=:grid
)

println("Approximation error: ", result.error)
println("Condition number: ", result.condition_number)
println("Coefficients: ", result.coefficients)
```

### Performance Benchmarking

```julia
bench = GlobtimProduction.benchmark_function(
    GlobtimProduction.Sphere, 
    "Sphere",
    n_trials=10000,
    dim=2
)

println("Mean time: ", bench.mean_time, " μs")
println("Std dev: ", bench.std_time, " μs")
```

## SLURM Job Submission

### Quick Test (15 minutes)
```bash
#!/bin/bash
#SBATCH --job-name=globtim_test
#SBATCH --time=00:15:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G

cd $HOME/globtim_hpc
/sw/bin/julia -e 'include("src/GlobtimProduction.jl"); using .GlobtimProduction; println(GlobtimProduction.Sphere([1,1]))'
```

### Production Run (1 hour)
```bash
#!/bin/bash
#SBATCH --job-name=globtim_prod
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G

export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
cd $HOME/globtim_hpc

/sw/bin/julia << 'EOF'
include("src/GlobtimProduction.jl")
using .GlobtimProduction

# Your production code here
result = GlobtimProduction.globtim(
    GlobtimProduction.Rosenbrock,
    dim=10,
    GN=10000,
    degree=6
)
println("Error: ", result.error)
EOF
```

## Limitations

The standalone version has some limitations compared to the full GlobTim package:

1. **No External Package Support**: Cannot use packages like CSV, DataFrames, Plots
2. **Simplified Algorithms**: Polynomial approximation is simplified
3. **No File I/O**: Results must be printed or saved manually
4. **Limited Polynomial Bases**: Only standard polynomial basis (no Chebyshev, Legendre)
5. **No Automatic Differentiation**: ForwardDiff not available

## Migration Path

To migrate existing GlobTim code to the standalone version:

1. **Replace imports**:
   ```julia
   # Old
   using Globtim
   
   # New
   include("src/GlobtimProduction.jl")
   using .GlobtimProduction
   ```

2. **Adjust function calls**:
   ```julia
   # Most function signatures are identical
   # Just add module prefix if needed
   GlobtimProduction.Sphere(x)
   ```

3. **Handle I/O differently**:
   ```julia
   # Instead of CSV export, use Julia's built-in I/O
   open("results.txt", "w") do f
       println(f, "Results: ", result)
   end
   ```

## Troubleshooting

### Issue: Module not loading
**Solution**: Ensure you're in the correct directory and the path is correct:
```julia
cd("/home/scholten/globtim_hpc")
include("src/GlobtimProduction.jl")
```

### Issue: Parallel performance not working
**Solution**: Set Julia threads before starting:
```bash
export JULIA_NUM_THREADS=16
```

### Issue: Memory errors with large problems
**Solution**: Request more memory in SLURM:
```bash
#SBATCH --mem=64G
```

## Future Enhancements

Potential improvements while maintaining standalone nature:

1. **Add more sampling methods**: Latin hypercube, Halton sequences
2. **Implement more polynomial bases**: Using only stdlib
3. **Add simple data export functions**: JSON-like format using Base
4. **Optimize matrix operations**: Better use of LinearAlgebra
5. **Add gradient computation**: Finite differences

## Contact

For issues or questions about the HPC standalone version:
- Check the error logs in `~/globtim_hpc/`
- Review job output files: `globtim_production_*.out`
- Verify Julia environment: `/sw/bin/julia --version`