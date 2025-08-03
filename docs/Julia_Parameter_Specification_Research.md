# Julia Best Practices for Parameter Specification

## Executive Summary

Based on comprehensive research of Julia ecosystem best practices, this document provides recommendations for parameter specification and configuration management, particularly for HPC cluster computing environments.

## 🎯 Key Findings

### **Recommended Approach: Hybrid Strategy**
1. **Parameters.jl** for struct-based parameter management
2. **TOML.jl** for human-readable configuration files
3. **Minimal dependencies** for HPC cluster deployment

## 📊 Package Comparison Matrix

| Package | Use Case | Pros | Cons | HPC Suitability |
|---------|----------|------|------|-----------------|
| **Parameters.jl** | Struct-based config | Type safety, @with_kw macro, unpacking | Requires compilation | ⭐⭐⭐⭐⭐ |
| **Configurations.jl** | Complex hierarchical config | Powerful, flexible, TOML integration | Heavy dependencies | ⭐⭐⭐ |
| **TOML.jl** | File-based config | Human-readable, standard format | Manual parsing needed | ⭐⭐⭐⭐⭐ |
| **JSON3.jl** | API/data exchange | Fast, lightweight | Less human-readable | ⭐⭐⭐⭐ |
| **Native Structs** | Simple cases | No dependencies, fast | Manual implementation | ⭐⭐⭐⭐⭐ |

## 🏆 Recommended Architecture

### **1. Core Parameter Structures (Parameters.jl)**

```julia
using Parameters

@with_kw struct GlobtimParameters
    degree::Int = 4
    sample_count::Int = 100
    center::Vector{Float64} = zeros(4)
    sample_range::Float64 = 1.0
    basis::Symbol = :chebyshev
    precision::Type = Float64
    enable_hessian::Bool = true
    sparsification_threshold::Float64 = 1e-4
    max_retries::Int = 3
end

@with_kw struct HPCParameters  
    partition::String = "batch"
    cpus::Int = 24
    memory_gb::Int = 32
    time_limit::String = "02:00:00"
    julia_threads::Int = cpus
end

@with_kw struct BenchmarkConfig
    globtim::GlobtimParameters = GlobtimParameters()
    hpc::HPCParameters = HPCParameters()
    experiment_name::String = "default"
    output_dir::String = "results"
end
```

### **2. Configuration File Format (TOML)**

```toml
# benchmark_config.toml
experiment_name = "4d_sphere_study"
output_dir = "results/sphere_study"

[globtim]
degree = 6
sample_count = 200
center = [0.0, 0.0, 0.0, 0.0]
sample_range = 2.0
basis = "chebyshev"
precision = "Float64"
enable_hessian = true
sparsification_threshold = 1e-5
max_retries = 3

[hpc]
partition = "batch"
cpus = 24
memory_gb = 48
time_limit = "04:00:00"
julia_threads = 24
```

### **3. Configuration Loading System**

```julia
using TOML, Parameters

function load_config(config_file::String)
    toml_data = TOML.parsefile(config_file)
    
    # Parse Globtim parameters
    globtim_params = GlobtimParameters(;
        degree = toml_data["globtim"]["degree"],
        sample_count = toml_data["globtim"]["sample_count"],
        center = toml_data["globtim"]["center"],
        sample_range = toml_data["globtim"]["sample_range"],
        basis = Symbol(toml_data["globtim"]["basis"]),
        sparsification_threshold = toml_data["globtim"]["sparsification_threshold"],
        max_retries = toml_data["globtim"]["max_retries"]
    )
    
    # Parse HPC parameters
    hpc_params = HPCParameters(;
        partition = toml_data["hpc"]["partition"],
        cpus = toml_data["hpc"]["cpus"],
        memory_gb = toml_data["hpc"]["memory_gb"],
        time_limit = toml_data["hpc"]["time_limit"],
        julia_threads = toml_data["hpc"]["julia_threads"]
    )
    
    return BenchmarkConfig(
        globtim = globtim_params,
        hpc = hpc_params,
        experiment_name = toml_data["experiment_name"],
        output_dir = toml_data["output_dir"]
    )
end
```

## 🖥️ HPC-Specific Best Practices

### **Minimal Dependency Strategy**
Based on HPC research, minimize external dependencies:

**Essential Only:**
- `Parameters.jl` - Lightweight, essential for struct management
- `TOML.jl` - Standard library, minimal overhead
- `StaticArrays.jl` - Performance-critical for small arrays

**Avoid on HPC:**
- Heavy visualization packages (Makie.jl, Plots.jl)
- Complex configuration frameworks (Configurations.jl)
- Progress bars and interactive elements

### **HPC Environment Configuration**

```julia
# Project_HPC.toml - Minimal HPC dependencies
[deps]
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Parameters = "d96e819e-fc66-5662-9728-84c9c7592b0a"
TOML = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
```

### **JULIA_DEPOT_PATH Management**
```bash
# On HPC cluster
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}:$JULIA_DEPOT_PATH"
```

## 🔧 Implementation Patterns

### **1. Parameter Validation**
```julia
function validate_parameters(params::GlobtimParameters)
    @assert params.degree > 0 "Degree must be positive"
    @assert params.sample_count > 0 "Sample count must be positive"
    @assert params.sparsification_threshold > 0 "Threshold must be positive"
    @assert length(params.center) > 0 "Center must be non-empty"
end
```

### **2. Parameter Unpacking (Parameters.jl)**
```julia
function run_globtim_workflow(config::BenchmarkConfig)
    @unpack degree, sample_count, center, sample_range = config.globtim
    @unpack partition, cpus, memory_gb = config.hpc
    
    # Use unpacked parameters directly
    results = safe_globtim_workflow(
        test_function,
        dim = length(center),
        degree = degree,
        GN = sample_count,
        # ... other parameters
    )
end
```

### **3. Configuration Serialization**
```julia
function save_config(config::BenchmarkConfig, filepath::String)
    config_dict = Dict(
        "experiment_name" => config.experiment_name,
        "output_dir" => config.output_dir,
        "globtim" => Dict(
            "degree" => config.globtim.degree,
            "sample_count" => config.globtim.sample_count,
            "center" => config.globtim.center,
            # ... other parameters
        ),
        "hpc" => Dict(
            "partition" => config.hpc.partition,
            "cpus" => config.hpc.cpus,
            # ... other parameters
        )
    )
    
    open(filepath, "w") do io
        TOML.print(io, config_dict)
    end
end
```

## 🚀 HPC Cluster Computing Packages

### **Recommended for Cluster Computing:**
1. **ClusterManagers.jl** - SLURM integration, job management
2. **Distributed.jl** - Built-in distributed computing (standard library)
3. **MPI.jl** - Message passing for large-scale parallelism
4. **SharedArrays.jl** - Shared memory arrays (standard library)

### **Configuration for Cluster Deployment:**
```julia
# For SLURM integration
using ClusterManagers
addprocs(SlurmManager(parse(Int, ENV["SLURM_NTASKS"])))

# For MPI
using MPI
MPI.Init()
comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
size = MPI.Comm_size(comm)
```

## 📋 Implementation Recommendations

### **For Globtim HPC Benchmarking:**

1. **Use Parameters.jl** for all parameter structures
2. **Use TOML files** for configuration persistence
3. **Minimize dependencies** in HPC environment
4. **Implement validation** for all parameter structures
5. **Use @unpack macro** for clean parameter access
6. **Create configuration presets** for different scenarios
7. **Implement serialization** for reproducibility

### **Dependency Management Strategy:**
- **Local Development**: Full feature set with visualization
- **HPC Deployment**: Minimal dependencies, no interactive elements
- **Separate Project.toml files**: `Project.toml` (full) vs `Project_HPC.toml` (minimal)

## ✅ Conclusion

The **Parameters.jl + TOML.jl** combination provides the optimal balance of:
- **Type safety** and **performance** (Parameters.jl)
- **Human readability** and **standardization** (TOML.jl)  
- **Minimal dependencies** for HPC deployment
- **Flexibility** for complex parameter hierarchies
- **Reproducibility** through configuration serialization

This approach aligns with Julia community best practices while being specifically optimized for HPC cluster computing environments.

## 🔄 Migration Path for Existing Globtim Infrastructure

### **Current Implementation Assessment:**
Our existing `src/HPC/BenchmarkConfig.jl` already follows many best practices:
- ✅ Uses native structs with proper typing
- ✅ Implements parameter validation
- ✅ Provides configuration presets
- ✅ Includes serialization capabilities

### **Recommended Improvements:**
1. **Add Parameters.jl** for @with_kw macro and @unpack functionality
2. **Enhance TOML integration** for better human-readable configs
3. **Create HPC-optimized dependency list**
4. **Implement parameter validation functions**

### **Implementation Priority:**
1. **High Priority**: Add Parameters.jl to existing structs
2. **Medium Priority**: Enhance TOML configuration loading
3. **Low Priority**: Add advanced validation and presets

This research validates our current approach while providing clear paths for enhancement.
