# GlobTim HPC Deployment Guide

## Quick Start

### Option 1: Standalone Version (Recommended) ✅

The standalone version works immediately without any package dependencies:

```bash
# On HPC cluster
cd ~/globtim_hpc
/sw/bin/julia -e 'include("src/GlobtimProduction.jl"); using .GlobtimProduction'
```

### Option 2: Pre-bundled Packages

Create a bundle locally with all dependencies pre-installed:

```bash
# On local machine
./create_hpc_bundle.sh

# Transfer to HPC
scp globtim_bundle_*.tar.gz scholten@falcon:~/

# On HPC
tar -xzf globtim_bundle_*.tar.gz
cd globtim_hpc_bundle
sbatch run_globtim.slurm
```

## Available Versions

### 1. GlobtimProduction (Standalone)

**Status**: ✅ Fully operational on HPC

**Features**:
- All benchmark functions (Sphere, Rosenbrock, Deuflhard, Rastrigin, Ackley)
- Multiple sampling methods (random, grid, quasi-random)
- Polynomial approximation
- Parallel execution (16 threads tested)
- No external dependencies

**Limitations**:
- No CSV I/O (use Julia's built-in I/O)
- Simplified polynomial bases
- No automatic differentiation

**Usage**:
```julia
include("src/GlobtimProduction.jl")
using .GlobtimProduction

# Function evaluation
result = GlobtimProduction.Sphere([1.0, 1.0])

# Generate samples
samples = GlobtimProduction.generate_samples(1000, 2, [0.0, 0.0], 2.0)

# Full workflow
result = GlobtimProduction.globtim(
    GlobtimProduction.Rosenbrock,
    dim=2,
    GN=1000,
    degree=4
)
```

### 2. GlobtimBundled (Full Features)

**Status**: ⚠️ Requires local bundling

**Features**:
- All original GlobTim features
- CSV and DataFrame support
- Advanced polynomial bases
- Automatic differentiation with ForwardDiff
- Full test suite

**Setup Required**:
1. Run `create_hpc_bundle.sh` locally
2. Transfer bundle to HPC
3. Use bundled depot path

## SLURM Job Examples

### Basic Test (5 minutes)
```bash
#!/bin/bash
#SBATCH --job-name=globtim_test
#SBATCH --time=00:05:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G

cd $HOME/globtim_hpc
/sw/bin/julia -e '
include("src/GlobtimProduction.jl")
using .GlobtimProduction
println(GlobtimProduction.Sphere([1,1]))
'
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

/sw/bin/julia -e '
include("src/GlobtimProduction.jl")
using .GlobtimProduction

# Large-scale optimization
for n_samples in [1000, 5000, 10000]
    result = GlobtimProduction.globtim(
        GlobtimProduction.Rosenbrock,
        dim=10,
        GN=n_samples,
        degree=6
    )
    println("Samples: ", n_samples, " Error: ", result.error)
end
'
```

## Performance Benchmarks

Based on actual HPC testing (Node: c01n02, 16 CPUs, 32GB RAM):

| Function | Evaluation Time | Throughput |
|----------|----------------|------------|
| Sphere | 0.044 μs | 22.7M/sec |
| Rosenbrock | 0.047 μs | 21.3M/sec |
| Deuflhard | 0.049 μs | 20.4M/sec |
| Rastrigin | 0.172 μs | 5.8M/sec |
| Ackley | 0.378 μs | 2.6M/sec |

Parallel sampling performance:
- 1,000 samples: 0.23 ms (4.4M samples/sec)
- 5,000 samples: 80.78 ms (62K samples/sec)
- 10,000 samples: 1.68 ms (6M samples/sec)

## Troubleshooting

### Issue: JSON3 Package Error

**Symptom**: 
```
ERROR: KeyError: key Base.PkgId(..., "JSON3") not found
```

**Solution**: Use the standalone version (GlobtimProduction.jl) which doesn't require packages.

### Issue: Package Installation Fails

**Symptom**: Cannot run `Pkg.instantiate()` or `Pkg.add()`

**Solution**: 
1. Use pre-bundled packages (create locally, transfer to HPC)
2. Or use standalone version

### Issue: No Module Found

**Symptom**: `ERROR: LoadError: Module not found`

**Solution**: Ensure correct path:
```julia
cd("/home/scholten/globtim_hpc")
include("src/GlobtimProduction.jl")
```

### Issue: Low Performance

**Solution**: Set thread count before running:
```bash
export JULIA_NUM_THREADS=16
```

## File Structure

```
globtim_hpc/
├── src/
│   ├── GlobtimProduction.jl  # Standalone version (working)
│   ├── Globtim.jl            # Original (requires packages)
│   ├── BenchmarkFunctions.jl
│   ├── Structures.jl
│   └── ...
├── hpc/
│   └── jobs/
│       └── submission/
│           ├── globtim_production_standalone.slurm
│           ├── submit_globtim_with_deps.sh
│           └── create_hpc_bundle.sh
└── outputs/
    └── [job results]
```

## Best Practices

1. **Always test locally first** before submitting to HPC
2. **Use the standalone version** for production runs (most reliable)
3. **Request appropriate resources** (memory scales with problem size)
4. **Monitor job progress**: 
   ```bash
   squeue -u $USER
   tail -f globtim_production_*.out
   ```
5. **Save results immediately** after job completion

## Support

For HPC-specific issues:
- Check SLURM output: `globtim_*.out` and `globtim_*.err`
- Verify Julia installation: `/sw/bin/julia --version`
- Test standalone module: `include("src/GlobtimProduction.jl")`

## Next Steps

1. **For immediate use**: Deploy GlobtimProduction.jl
2. **For full features**: Create and deploy package bundle
3. **For long-term**: Consider containerization with Singularity