# Memory-Safe Usage Guide for Globtim.jl

## 🚨 **Critical Memory Considerations**

Globtim.jl polynomial approximations can quickly exhaust system memory due to exponential growth in polynomial terms with degree and dimension. This guide provides safe usage patterns and memory management strategies.

## 📊 **Memory Usage by Degree and Dimension**

### **Polynomial Terms Growth**
The number of polynomial terms grows as `C(degree + dim, dim)`:

| Degree | 2D | 3D | 4D | 5D |
|--------|----|----|----|----|
| 4      | 15 | 35 | 70 | 126 |
| 6      | 28 | 84 | 210 | 462 |
| 8      | 45 | 165 | 495 | 1287 |
| 10     | 66 | 286 | 1001 | 3003 |
| 12     | 91 | 455 | 1820 | 6188 |

### **Memory Usage Estimates**
With 500 samples, approximate memory usage:

| Degree | 2D | 3D | 4D | 5D |
|--------|----|----|----|----|
| 4      | 0.6MB | 1.3MB | 2.7MB | 4.8MB |
| 6      | 1.1MB | 3.2MB | 8.0MB | 17.6MB |
| 8      | 1.7MB | 6.3MB | 18.9MB | 49.1MB |
| 10     | 2.5MB | 10.9MB | 38.1MB | 114.5MB |
| 12     | 3.5MB | 17.3MB | 69.4MB | 236.0MB |

**⚠️ These are just Vandermonde matrix sizes. Total memory usage is 3-5x higher!**

## 🛡️ **Safe Usage Recommendations**

### **Conservative Limits (Recommended)**
- **2D**: degree ≤ 10, samples ≤ 1000
- **3D**: degree ≤ 6, samples ≤ 500  
- **4D**: degree ≤ 4, samples ≤ 300
- **5D+**: degree ≤ 4, samples ≤ 200

### **Memory-Safe Defaults**
The error handling framework enforces these conservative defaults:
- Maximum degree: 8 (with memory checking)
- Memory limit: 1.5GB total usage
- Automatic degree reduction on memory errors

## 🔧 **Memory Management Strategies**

### **1. Use Safe Wrapper Functions**
```julia
# Automatically handles memory limits and parameter adjustment
results = safe_globtim_workflow(
    f, dim=3, center=zeros(3), sample_range=2.0,
    degree=6,  # Conservative default
    GN=200     # Reasonable sample count
)
```

### **2. Check Complexity Before Running**
```julia
# Estimate memory usage before computation
complexity = estimate_computation_complexity(dim=4, degree=8, sample_count=500)

println("Estimated memory: $(complexity["total_memory_mb"]) MB")
println("Memory feasible: $(complexity["memory_feasible"])")

for warning in complexity["warnings"]
    println("⚠️  $warning")
end
```

### **3. Progressive Degree Increase**
```julia
# Start with low degree and increase gradually
for degree in [4, 6, 8]
    try
        pol = safe_constructor(TR, degree)
        println("Degree $degree successful, L2 error: $(pol.nrm)")
        
        # Check if error is acceptable
        if pol.nrm < 1e-6
            break  # Good enough accuracy achieved
        end
    catch ResourceError
        println("Degree $degree too expensive, stopping at $(degree-2)")
        break
    end
end
```

### **4. Domain Decomposition for Large Problems**
```julia
# For high-dimensional or high-degree problems
function analyze_by_subdomains(f, dim, full_range)
    subdomains = create_subdomains(dim, full_range, n_subdivisions=4)
    results = []
    
    for subdomain in subdomains
        # Analyze each subdomain with safe parameters
        sub_result = safe_globtim_workflow(
            f, dim=dim, 
            center=subdomain.center,
            sample_range=subdomain.range,
            degree=4,  # Conservative for subdomains
            GN=150
        )
        push!(results, sub_result)
    end
    
    return combine_subdomain_results(results)
end
```

## 🚨 **Warning Signs and Recovery**

### **Memory Exhaustion Symptoms**
- System becomes unresponsive
- Julia process killed by OS
- "OutOfMemoryError" exceptions
- Very slow polynomial construction

### **Automatic Recovery Actions**
The error handling framework automatically:
1. **Reduces degree** by 2-4 levels on memory errors
2. **Reduces sample count** by 50% on resource errors  
3. **Switches to AdaptivePrecision** for numerical stability
4. **Provides specific suggestions** for parameter adjustment

### **Manual Recovery Strategies**
```julia
# If you encounter memory issues:

# 1. Reduce degree aggressively
degree = max(2, current_degree - 4)

# 2. Reduce sample count
GN = max(50, current_GN ÷ 2)

# 3. Use domain decomposition
# Split problem into smaller subproblems

# 4. Consider alternative approaches
# - Lower-dimensional projections
# - Sparse grid methods (future feature)
# - Iterative refinement
```

## 📈 **Performance vs Memory Trade-offs**

### **Degree Selection Guidelines**
- **Degree 4**: Fast, memory-efficient, good for smooth functions
- **Degree 6**: Balanced choice, handles moderate complexity
- **Degree 8**: High accuracy, significant memory usage
- **Degree 10+**: Expert use only, requires careful memory management

### **Sample Count Guidelines**
- **50-100**: Minimum for basic approximation
- **200-500**: Good balance for most problems
- **1000+**: High accuracy, use only with low degrees

### **Dimension-Specific Recommendations**

#### **2D Problems**
- Safe up to degree 10 with 1000+ samples
- Good for detailed analysis and visualization
- Memory rarely an issue

#### **3D Problems**  
- Degree 6-8 recommended with 200-500 samples
- Watch memory usage above degree 8
- Consider domain decomposition for degree 10+

#### **4D Problems**
- Degree 4-6 recommended with 100-300 samples  
- Degree 8+ requires careful memory management
- High degrees may not be feasible

#### **5D+ Problems**
- Degree 4 maximum recommended
- Use sparse sampling (100-200 samples)
- Consider dimensionality reduction techniques

## 🔍 **Monitoring and Diagnostics**

### **Built-in Memory Monitoring**
```julia
# Check system health
diagnostics = diagnose_globtim_setup()
println("Setup healthy: $(diagnostics["setup_healthy"])")
println("Memory allocated: $(diagnostics["memory_allocated_mb"]) MB")

# Monitor during computation
check_memory_usage("my_operation", memory_limit_gb=4.0)
```

### **Progress Monitoring for Large Problems**
```julia
# Use progress monitoring for long computations
result = with_progress_monitoring(
    progress -> begin
        # Your computation here
        update_progress!(progress, 0.5, "Halfway done")
        return computation_result
    end,
    "Large Polynomial Construction",
    interruptible=true  # Allow Ctrl+C interruption
)
```

## 💡 **Best Practices Summary**

1. **Start Conservative**: Begin with degree 4-6, increase gradually
2. **Use Safe Wrappers**: Let the framework handle memory management
3. **Monitor Complexity**: Check estimates before running expensive computations
4. **Enable Auto-Recovery**: Use `max_retries` for automatic parameter adjustment
5. **Plan for Interruption**: Use progress monitoring for long computations
6. **Consider Alternatives**: Domain decomposition for very large problems

## 🆘 **Emergency Procedures**

### **If System Becomes Unresponsive**
1. **Ctrl+C** to interrupt Julia (if responsive)
2. **Kill Julia process** from system monitor
3. **Restart with lower parameters**
4. **Check available system memory** before retrying

### **If Out of Memory Errors Persist**
1. **Reduce degree to 4 or lower**
2. **Reduce sample count to 100 or lower**  
3. **Close other applications** to free memory
4. **Consider using a machine with more RAM**
5. **Use domain decomposition** for complex problems

Remember: **It's better to get a reasonable approximation than to crash the system!**
