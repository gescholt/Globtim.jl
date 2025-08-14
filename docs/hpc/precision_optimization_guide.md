# HPC Precision Optimization Guide

This guide provides specific recommendations for using Globtim's precision parameters on HPC clusters, focusing on performance optimization, memory management, and resource allocation.

## Overview

HPC environments present unique challenges for precision parameter selection due to:
- Limited memory per node
- Batch job time constraints  
- Parallel processing considerations
- Network storage limitations
- Queue system resource allocation

## Precision Recommendations by Problem Size

### Small Problems (< 1,000 coefficients)
**Typical cases**: 2D-3D problems, degree ≤ 8

```julia
# Recommended configuration
pol = Constructor(TR, degree, 
    precision=Float64Precision,  # Fast execution
    basis=:chebyshev,           # Numerically stable
    verbose=0                   # Minimal output for batch jobs
)
```

**Resource requirements:**
- Memory: < 100 MB
- Time multiplier: 1.0× (baseline)
- Recommended partition: `batch` (standard queue)

### Medium Problems (1,000-10,000 coefficients)  
**Typical cases**: 4D-6D problems, degree 6-10

```julia
# Recommended configuration
pol = Constructor(TR, degree,
    precision=AdaptivePrecision,  # Good accuracy/performance balance
    basis=:chebyshev,
    verbose=0
)
```

**Resource requirements:**
- Memory: 100 MB - 2 GB
- Time multiplier: 1.5× 
- Recommended partition: `batch` with increased memory allocation

### Large Problems (> 10,000 coefficients)
**Typical cases**: 6D+ problems, high degrees

```julia
# Recommended configuration with sparsification
function hpc_large_problem_workflow(TR, degree)
    # Step 1: Create with AdaptivePrecision
    pol = Constructor(TR, degree, precision=AdaptivePrecision, verbose=0)
    
    # Step 2: Apply aggressive sparsification
    @polyvar x[1:length(TR.center)]
    mono_poly = to_exact_monomial_basis(pol, variables=x)
    analysis = analyze_coefficient_distribution(mono_poly)
    
    # Step 3: Use aggressive threshold for HPC
    threshold = analysis.suggested_thresholds[3]  # More aggressive
    truncated_poly, stats = truncate_polynomial_adaptive(mono_poly, threshold)
    
    println("HPC sparsification: $(round(stats.sparsity_ratio*100))% sparse")
    return truncated_poly
end
```

**Resource requirements:**
- Memory: 2-32 GB
- Time multiplier: 2-4×
- Recommended partition: `bigmem` or `long`

## SLURM Job Configuration

### Memory Allocation by Precision Type

```bash
# Float64Precision jobs
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --partition=batch

# AdaptivePrecision jobs  
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --partition=batch

# RationalPrecision jobs (avoid for large problems)
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --partition=bigmem
```

### Resource Estimation Function

```julia
function estimate_hpc_resources(dim, degree, precision_type)
    coeff_count = binomial(dim + degree, degree)
    
    # Memory requirements (MB)
    base_memory = if precision_type == Float64Precision
        coeff_count * 8 / 1024^2
    elseif precision_type == AdaptivePrecision
        coeff_count * 16 / 1024^2
    elseif precision_type == RationalPrecision
        coeff_count * 64 / 1024^2
    elseif precision_type == BigFloatPrecision
        coeff_count * 32 / 1024^2
    end
    
    # Add 5x overhead for computation
    total_memory_mb = base_memory * 5
    
    # Time estimates (relative to Float64)
    time_multiplier = Dict(
        Float64Precision => 1.0,
        AdaptivePrecision => 1.5,
        RationalPrecision => 8.0,
        BigFloatPrecision => 4.0
    )[precision_type]
    
    # SLURM recommendations
    slurm_memory = max(4096, ceil(Int, total_memory_mb * 1.5))  # 50% safety margin
    slurm_time = if time_multiplier <= 1.5
        "01:00:00"
    elseif time_multiplier <= 3.0
        "02:00:00"
    else
        "04:00:00"
    end
    
    slurm_partition = if slurm_memory <= 32768
        "batch"
    else
        "bigmem"
    end
    
    return (
        memory_mb = slurm_memory,
        time_estimate = slurm_time,
        partition = slurm_partition,
        coefficient_count = coeff_count,
        time_multiplier = time_multiplier
    )
end
```

## Performance Optimization Strategies

### 1. Precision Selection Strategy

```julia
function select_hpc_precision(dim, degree, time_budget_hours=2)
    coeff_count = binomial(dim + degree, degree)
    
    if coeff_count < 500
        return Float64Precision  # Fast for small problems
    elseif coeff_count < 5000 && time_budget_hours >= 1
        return AdaptivePrecision  # Balanced approach
    elseif coeff_count < 20000 && time_budget_hours >= 3
        return AdaptivePrecision  # With sparsification
    else
        @warn "Problem may be too large for HPC time limits"
        return Float64Precision  # Fallback to fastest
    end
end
```

### 2. Batch Processing Optimization

```julia
# Optimized batch processing for HPC
function hpc_batch_workflow(functions, degrees, precision=AdaptivePrecision)
    results = []
    
    for (i, (f, deg)) in enumerate(zip(functions, degrees))
        println("Processing $(i)/$(length(functions)): degree $deg")
        
        TR = test_input(f, dim=2, center=[0.0, 0.0], sample_range=1.0)
        
        # Use consistent precision for batch
        pol = Constructor(TR, deg, precision=precision, verbose=0)
        
        # Store minimal results to save memory
        push!(results, (
            function_name = string(f),
            degree = deg,
            l2_norm = pol.nrm,
            coefficient_count = length(pol.coeffs)
        ))
        
        # Force garbage collection for large batches
        if i % 10 == 0
            GC.gc()
        end
    end
    
    return results
end
```

### 3. Memory-Aware Sparsification

```julia
function hpc_memory_aware_sparsification(pol, target_memory_mb=1000)
    @polyvar x[1:length(pol.test_input.center)]
    mono_poly = to_exact_monomial_basis(pol, variables=x)
    
    # Estimate current memory usage
    current_terms = length(terms(mono_poly))
    bytes_per_term = 32  # Approximate for BigFloat coefficients
    current_memory_mb = current_terms * bytes_per_term / 1024^2
    
    if current_memory_mb <= target_memory_mb
        return mono_poly  # No sparsification needed
    end
    
    # Calculate required sparsity ratio
    target_terms = floor(Int, target_memory_mb * 1024^2 / bytes_per_term)
    target_sparsity = 1.0 - target_terms / current_terms
    
    # Find threshold that achieves target sparsity
    analysis = analyze_coefficient_distribution(mono_poly)
    
    # Binary search for appropriate threshold
    thresholds = analysis.suggested_thresholds
    best_threshold = thresholds[1]
    
    for threshold in thresholds
        _, stats = truncate_polynomial_adaptive(mono_poly, threshold)
        if stats.sparsity_ratio >= target_sparsity
            best_threshold = threshold
            break
        end
    end
    
    truncated_poly, final_stats = truncate_polynomial_adaptive(mono_poly, best_threshold)
    println("Memory optimization: $(round(final_stats.sparsity_ratio*100))% sparse")
    
    return truncated_poly
end
```

## HPC-Specific Examples

### Example 1: 4D Benchmark with Resource Constraints

```julia
#!/usr/bin/env julia
# HPC job script for 4D optimization

using Globtim, DynamicPolynomials

function main()
    # Problem setup
    f = Deuflhard_4d
    TR = test_input(f, dim=4, center=zeros(4), sample_range=1.2)
    degree = 6
    
    # Estimate resources
    resources = estimate_hpc_resources(4, degree, AdaptivePrecision)
    println("Estimated resources: $(resources.memory_mb) MB, $(resources.time_estimate)")
    
    # Create polynomial with AdaptivePrecision
    println("Creating 4D polynomial...")
    @time pol = Constructor(TR, degree, precision=AdaptivePrecision, verbose=1)
    
    # Apply memory-aware sparsification
    println("Applying sparsification...")
    sparse_poly = hpc_memory_aware_sparsification(pol, 2000)  # 2GB limit
    
    # Find critical points (if time permits)
    @polyvar x[1:4]
    println("Finding critical points...")
    @time solutions = solve_polynomial_system(x, sparse_poly)
    
    # Process and save results
    df = process_crit_pts(solutions, f, TR)
    println("Found $(nrow(df)) critical points")
    
    # Save results to fileserver
    CSV.write("results_4d_$(degree)_$(Dates.now()).csv", df)
    
    return df
end

# Run main function
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
```

### Example 2: High-Dimensional Batch Processing

```julia
# Batch processing script for high-dimensional problems
function hpc_high_dim_batch()
    # Define problem suite
    functions = [Deuflhard, HolderTable, Ackley, Rastringin]
    dimensions = [4, 6, 8]
    degrees = [4, 6]
    
    results = []
    
    for dim in dimensions
        for deg in degrees
            for f in functions
                println("Processing: $(f), dim=$(dim), degree=$(deg)")
                
                # Check if problem is feasible
                resources = estimate_hpc_resources(dim, deg, AdaptivePrecision)
                if resources.memory_mb > 32000  # 32GB limit
                    println("Skipping: memory requirement too high")
                    continue
                end
                
                try
                    # Create problem
                    TR = test_input(f, dim=dim, center=zeros(dim), sample_range=1.0)
                    
                    # Use Float64 for very large problems
                    precision = resources.memory_mb > 16000 ? Float64Precision : AdaptivePrecision
                    
                    # Time the construction
                    @time pol = Constructor(TR, deg, precision=precision, verbose=0)
                    
                    push!(results, (
                        function_name = string(f),
                        dimension = dim,
                        degree = deg,
                        precision = string(precision),
                        l2_norm = pol.nrm,
                        memory_estimate = resources.memory_mb,
                        coefficient_count = length(pol.coeffs)
                    ))
                    
                catch e
                    println("Error: $e")
                    push!(results, (
                        function_name = string(f),
                        dimension = dim,
                        degree = deg,
                        precision = "FAILED",
                        l2_norm = NaN,
                        memory_estimate = resources.memory_mb,
                        coefficient_count = 0
                    ))
                end
                
                # Cleanup
                GC.gc()
            end
        end
    end
    
    # Save batch results
    df_results = DataFrame(results)
    CSV.write("hpc_batch_results_$(Dates.now()).csv", df_results)
    
    return df_results
end
```

## Best Practices for HPC Usage

### 1. Always Estimate Resources First
```julia
# Before submitting jobs
resources = estimate_hpc_resources(dim, degree, precision_type)
println("Job will need: $(resources.memory_mb) MB, $(resources.time_estimate)")
```

### 2. Use Appropriate Precision for Problem Size
- **Small problems**: `Float64Precision` for speed
- **Medium problems**: `AdaptivePrecision` for balance  
- **Large problems**: `AdaptivePrecision` + aggressive sparsification
- **Avoid**: `RationalPrecision` for problems > 1000 coefficients

### 3. Implement Checkpointing for Long Jobs
```julia
function checkpoint_workflow(TR, degree, checkpoint_file="checkpoint.jld2")
    if isfile(checkpoint_file)
        println("Loading from checkpoint...")
        pol = load(checkpoint_file, "polynomial")
    else
        println("Creating polynomial...")
        pol = Constructor(TR, degree, precision=AdaptivePrecision)
        save(checkpoint_file, "polynomial", pol)
    end
    
    return pol
end
```

### 4. Monitor Memory Usage
```julia
function memory_monitored_constructor(TR, degree, precision_type)
    initial_memory = Sys.free_memory()
    
    pol = Constructor(TR, degree, precision=precision_type, verbose=0)
    
    final_memory = Sys.free_memory()
    memory_used = (initial_memory - final_memory) / 1024^2  # MB
    
    println("Memory used: $(round(memory_used, digits=1)) MB")
    
    return pol
end
```

## Troubleshooting HPC Issues

### Memory Errors
```bash
# If job fails with memory error, reduce precision or apply sparsification
# Original job
pol = Constructor(TR, 10, precision=AdaptivePrecision)

# Memory-optimized version
pol = Constructor(TR, 8, precision=Float64Precision)  # Lower degree + faster precision
sparse_poly = hpc_memory_aware_sparsification(pol, 1000)  # Aggressive sparsification
```

### Time Limit Exceeded
```bash
# Use faster precision for time-constrained jobs
pol = Constructor(TR, degree, precision=Float64Precision, verbose=0)
```

### Queue System Optimization
```bash
# Request appropriate resources based on estimates
resources = estimate_hpc_resources(dim, degree, precision_type)

# SLURM script template
#SBATCH --mem=$(resources.memory_mb)M
#SBATCH --time=$(resources.time_estimate)
#SBATCH --partition=$(resources.partition)
```

This guide provides the foundation for efficient HPC usage of Globtim's precision parameters, ensuring optimal resource utilization while maintaining solution quality.
