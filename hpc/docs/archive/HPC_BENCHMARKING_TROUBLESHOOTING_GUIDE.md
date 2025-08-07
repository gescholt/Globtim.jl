# 🎯 HPC Cluster Benchmarking Troubleshooting Guide

**Complete documentation for resolving Julia package dependency issues, disk quota problems, and benchmarking failures on HPC clusters.**

---

## 🚨 **COMMON ISSUE: "Advanced Benchmark Suite Gets Stuck"**

### **Symptoms:**
- Level 1-2 benchmarks work perfectly
- Level 3-4 benchmarks fail or get stuck
- Package installation errors
- `rsync` upload failures with exit status 12
- "Disk quota exceeded" errors

### **Root Causes Identified:**

#### **1. DISK QUOTA EXCEEDED (Primary Issue)**
```bash
# Symptoms:
rsync: write failed on "/home/user/path": Disk quota exceeded (122)
ERROR: failed to emit output file Disk quota exceeded

# Diagnosis:
ssh user@cluster 'quota -u user'
# Shows: 1048576* 1048576 1048576 (asterisk = quota exceeded)

# Root cause: Julia packages in ~/.julia/ can consume 1GB+
du -sh ~/.julia  # Often shows 1020M+ on 1GB quota systems
```

#### **2. PACKAGE DEPENDENCY FAILURES (Secondary Issue)**
```bash
# Symptoms:
ERROR: LoadError: ArgumentError: Package DataFrames not found
ERROR: LoadError: ParseError: not a unary operator (\\)

# Root causes:
- Packages install in temporary depot but don't persist
- Syntax errors in Julia code (double backslash \\)
- Missing transitive dependencies
- Package compilation failures in temporary space
```

#### **3. COMPLEX PACKAGE CHAIN FAILURES (Tertiary Issue)**
```bash
# Symptoms:
DynamicPolynomials, HomotopyContinuation packages fail
Makie plotting dependencies cause conflicts
Binary artifact download failures

# Root cause: Advanced mathematical packages require:
- Large binary dependencies
- Complex compilation chains
- Graphics libraries (on headless clusters)
```

---

## 🔧 **SYSTEMATIC SOLUTION FRAMEWORK**

### **PHASE 1: DISK QUOTA RESOLUTION**

#### **Step 1: Diagnose Quota Status**
```bash
# Check user quota
ssh user@cluster 'quota -u user 2>/dev/null || echo "Quota command unavailable"'

# Check disk usage
ssh user@cluster 'du -sh ~ ~/.julia ~/.cache 2>/dev/null'

# Check filesystem space vs quota
ssh user@cluster 'df -h ~ && du -sh ~'
```

#### **Step 2: Clean Disk Space**
```bash
# Clean Julia package cache (SAFE - packages can be reinstalled)
ssh user@cluster 'rm -rf ~/.julia/compiled/* ~/.julia/logs/* ~/.julia/scratchspaces/*'

# More aggressive cleanup if needed
ssh user@cluster 'rm -rf ~/.julia/packages/* ~/.julia/artifacts/*'

# Verify cleanup
ssh user@cluster 'quota -u user && du -sh ~/.julia'
```

#### **Step 3: Implement Quota Workaround**
```bash
# In SLURM job scripts, use temporary depot:
export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
mkdir -p "$JULIA_DEPOT_PATH"

# This redirects ALL Julia package operations to temporary space
# which doesn't count against user quota
```

### **PHASE 2: PACKAGE DEPENDENCY MANAGEMENT**

#### **Step 1: Fix Syntax Errors**
```julia
# WRONG (causes ParseError):
coeffs = A \\ Y

# CORRECT:
coeffs = A \ Y

# Common syntax issues in HPC environments:
# - Double backslash operators
# - Unicode characters in variable names
# - Platform-specific path separators
```

#### **Step 2: Implement Graceful Degradation**
```julia
# Create capability-aware functions:
function robust_function_execution(required_packages::Vector{String})
    available_packages = String[]
    
    for pkg in required_packages
        try
            eval(Meta.parse("using $pkg"))
            push!(available_packages, pkg)
        catch
            println("⚠️  Package $pkg not available, using fallback")
        end
    end
    
    # Execute based on available capabilities
    if "ForwardDiff" in available_packages
        # Use advanced gradient-based methods
    elseif "LinearAlgebra" in available_packages  
        # Use basic linear algebra methods
    else
        # Use pure Julia standard library methods
    end
end
```

#### **Step 3: Package Installation Strategy**
```julia
# Robust package installation with retries:
function install_with_fallback(packages::Vector{String})
    installed = String[]
    failed = String[]
    
    for pkg in packages
        for attempt in 1:3
            try
                Pkg.add(pkg)
                eval(Meta.parse("using $pkg"))
                push!(installed, pkg)
                break
            catch e
                if attempt == 3
                    push!(failed, pkg)
                    println("❌ $pkg failed after 3 attempts")
                end
            end
        end
    end
    
    return installed, failed
end
```

### **PHASE 3: BENCHMARKING FRAMEWORK ADAPTATION**

#### **Step 1: Tiered Capability System**
```julia
# Define capability levels:
CAPABILITY_LEVELS = Dict(
    :minimal => ["LinearAlgebra", "Statistics", "Random"],
    :basic => ["DataFrames", "CSV", "Printf"],  
    :advanced => ["ForwardDiff", "Optim"],
    :expert => ["DynamicPolynomials", "HomotopyContinuation"]
)

# Adapt benchmarks to available capabilities:
function run_benchmark_at_level(capability_level::Symbol)
    if capability_level == :expert
        # Full Globtim workflow with polynomial systems
    elseif capability_level == :advanced  
        # BFGS optimization with gradients
    elseif capability_level == :basic
        # Simple optimization with DataFrames output
    else
        # Pure Julia standard library methods
    end
end
```

#### **Step 2: Error Handling and Reporting**
```julia
# Comprehensive error handling:
function safe_benchmark_execution(func_name, params)
    try
        result = execute_benchmark(func_name, params)
        return Dict("status" => "success", "result" => result)
    catch e
        error_info = Dict(
            "status" => "failed",
            "error_type" => string(typeof(e)),
            "error_message" => string(e),
            "fallback_attempted" => false
        )
        
        # Attempt fallback execution
        try
            fallback_result = execute_fallback_benchmark(func_name, params)
            error_info["fallback_attempted"] = true
            error_info["fallback_result"] = fallback_result
            error_info["status"] = "partial_success"
        catch fallback_error
            error_info["fallback_error"] = string(fallback_error)
        end
        
        return error_info
    end
end
```

---

## 🎯 **SPECIFIC SOLUTIONS BY BENCHMARK LEVEL**

### **Level 1: Basic Benchmarks (Always Work)**
```bash
# Uses only Julia standard library
# Success rate: ~100%
# No package dependencies
python3 submit_simple_test.py Sphere4D quick_test
```

### **Level 2: Core Functionality (Usually Works)**
```bash
# Uses basic packages: DataFrames, ForwardDiff, Optim
# Success rate: ~80% with quota workaround
# Fallback to simple methods if packages fail
python3 submit_core_globtim_test.py Sphere4D quick_test
```

### **Level 3: Parameter Sweeps (Problematic)**
```bash
# Issue: Complex package chains fail
# Solution: Use simplified parameter sweeps with Level 1-2 methods
python3 submit_simplified_parameter_sweep.py basic_sweep
```

### **Level 4: Advanced Suite (Most Problematic)**
```bash
# Issue: Expert packages (DynamicPolynomials, HomotopyContinuation) fail
# Solution: Create Level 4 using only working components
python3 submit_robust_advanced_suite.py
```

---

## 📊 **DIAGNOSTIC COMMANDS REFERENCE**

### **Quota and Disk Space**
```bash
# Check quota status
quota -u username

# Check disk usage by directory
du -sh ~/.julia ~/.cache ~/.local

# Check filesystem vs quota
df -h ~ && du -sh ~

# Find large files
find ~ -size +100M -type f 2>/dev/null | head -10
```

### **Package Status**
```bash
# Check Julia depot path
julia -e 'println(DEPOT_PATH)'

# List installed packages
julia -e 'using Pkg; Pkg.status()'

# Check package loading
julia -e 'using DataFrames; println("DataFrames OK")'

# Check compilation status
ls ~/.julia/compiled/v*/
```

### **Job Status and Errors**
```bash
# Check SLURM job status
squeue -u username

# Check recent job outputs
ls -lt *.out *.err | head -10

# Search for specific errors
grep -r "LoadError\|ArgumentError\|Disk quota" *.err
```

---

## 🚀 **PREVENTION STRATEGIES**

### **1. Proactive Quota Management**
```bash
# Regular cleanup script:
#!/bin/bash
echo "Cleaning Julia cache..."
rm -rf ~/.julia/compiled/* ~/.julia/logs/*
echo "Current usage: $(du -sh ~ | cut -f1)"
quota -u $(whoami)
```

### **2. Robust Job Script Template**
```bash
#!/bin/bash
#SBATCH --job-name=robust_benchmark
#SBATCH --time=00:30:00
#SBATCH --mem=2G

# Set up quota-safe environment
export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"
mkdir -p "$JULIA_DEPOT_PATH"

# Test environment before running benchmark
julia -e 'println("Julia OK: ", VERSION)'

# Run with error handling
julia robust_benchmark.jl || echo "Benchmark failed, check errors"

# Cleanup
rm -rf "$JULIA_DEPOT_PATH"
```

### **3. Capability-Aware Benchmarking**
```julia
# Always check capabilities first:
function main()
    capabilities = check_system_capabilities()
    
    if capabilities[:level] >= :advanced
        run_full_benchmark()
    elseif capabilities[:level] >= :basic
        run_simplified_benchmark()
    else
        run_minimal_benchmark()
    end
end
```

---

## 🏆 **SUCCESS METRICS**

### **Expected Success Rates After Fixes:**
- **Level 1 (Basic)**: 95-100% success rate
- **Level 2 (Core)**: 80-90% success rate  
- **Level 3 (Parameter Sweeps)**: 70-80% success rate
- **Level 4 (Advanced)**: 60-70% success rate

### **Key Performance Indicators:**
- Upload success rate > 95%
- Package installation success rate > 80%
- Job completion rate > 90%
- Result collection success rate > 95%

---

## 📝 **QUICK REFERENCE CHECKLIST**

When encountering HPC benchmarking issues:

- [ ] **Check disk quota**: `quota -u username`
- [ ] **Clean Julia cache**: `rm -rf ~/.julia/compiled/*`
- [ ] **Use temporary depot**: `export JULIA_DEPOT_PATH="/tmp/julia_depot_$SLURM_JOB_ID"`
- [ ] **Fix syntax errors**: Replace `\\` with `\`
- [ ] **Implement graceful degradation**: Check package availability
- [ ] **Use tiered capabilities**: Adapt to available packages
- [ ] **Add comprehensive error handling**: Catch and report all failures
- [ ] **Test incrementally**: Start with Level 1, progress upward

**This guide provides a complete framework for diagnosing and resolving HPC cluster benchmarking issues systematically.** 🎯
