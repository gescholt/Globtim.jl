# Critical Point Accuracy Verification Procedure

**Purpose**: Comprehensive guide for validating critical point computation results from HPC jobs.

---

## 🎯 Overview

This document describes the systematic verification workflow for critical point accuracy validation and lists all expected output artifacts produced by HPC jobs for downstream analysis.

### **Verification Scope**
- ✅ Critical point computation accuracy
- ✅ Polynomial approximation quality
- ✅ Mathematical correctness validation
- ✅ Performance metrics analysis
- ✅ Result reproducibility checks

---

## 📊 Expected Output Artifacts

### **Primary Result Files**

#### 1. **critical_points.csv**
**Purpose**: Tabular data of all computed critical points  
**Format**: CSV with headers  
**Columns**:
```csv
x1,x2,z,converged,distance_to_center
-0.0012,0.0034,-0.0001,true,0.0036
0.5234,-0.3421,0.2145,true,0.6234
```
**Usage**: Primary data for analysis, plotting, and validation

#### 2. **validation_summary.json**
**Purpose**: Structured metadata and validation results  
**Format**: JSON with nested structure  
**Content**:
```json
{
  "test_id": "a1b2c3d4",
  "timestamp": "2025-08-09T15:30:45.123",
  "success": true,
  "parameters": {
    "degree": 8,
    "samples": 50,
    "dimension": 2
  },
  "results": {
    "l2_error": 0.0005438,
    "condition_number": 4.0000000000000018,
    "num_critical_points": 12,
    "num_processed_points": 8,
    "best_point": [-0.0012, 0.0034],
    "best_value": -0.0001,
    "distance_to_origin": 0.0036,
    "accuracy_check": true
  }
}
```

#### 3. **validation_results.txt**
**Purpose**: Human-readable summary report  
**Format**: Plain text with structured sections  
**Content**:
```
Deuflhard Critical Points Validation Results
===========================================
Test ID: a1b2c3d4
Timestamp: 2025-08-09T15:30:45.123

Parameters:
  Degree: 8
  Samples: 50
  Dimension: 2

Results:
  L2 Error: 0.0005438
  Condition Number: 4.0000000000000018
  Critical Points Found: 12
  Processed Points: 8
  Best Point: [-0.0012, 0.0034]
  Best Value: -0.0001
  Distance to Origin: 0.0036
  Accuracy Check (< 0.1): true
```

### **Configuration and Metadata Files**

#### 4. **critical_points_config.json**
**Purpose**: Job configuration and parameters  
**Content**: Test parameters, execution mode, metadata

#### 5. **slurm_*.out** and **slurm_*.err**
**Purpose**: SLURM job execution logs  
**Content**: Console output, error messages, timing information

---

## 🔬 Verification Workflow

### **Phase 1: Automated Validation (Built-in)**

#### **A. Mathematical Correctness**
```julia
# Embedded in job script
# 1. Dimension consistency check
dimensions_correct = all(p -> length(p) == TR.dim, critical_points)

# 2. Domain bounds validation  
in_domain = all(p -> all(abs.(p) .<= 1.0), critical_points)

# 3. Function value computation
function_values = [f(point) for point in critical_points]
```

#### **B. Approximation Quality**
```julia
# Polynomial approximation metrics
l2_error = pol.nrm                    # L2 approximation error
condition_number = pol.cond_vandermonde  # Numerical conditioning
degree_achieved = pol.degree          # Final polynomial degree
```

#### **C. Critical Point Analysis**
```julia
# Distance to known global minimum (for Deuflhard: origin)
distance_to_origin = norm(best_point)
accuracy_check = distance_to_origin < 0.1  # Tolerance threshold
```

### **Phase 2: Post-Job Verification (Manual/Automated)**

#### **A. File Integrity Check**
```bash
# Verify all expected files exist
ls -la results/critical_points_${TEST_ID}/
# Expected files:
# - critical_points.csv
# - validation_summary.json  
# - validation_results.txt
# - critical_points_config.json
# - slurm_*.out, slurm_*.err
```

#### **B. Data Quality Validation**
```julia
using CSV, JSON3, DataFrames

# Load and validate CSV data
df = CSV.read("critical_points.csv", DataFrame)
@assert nrow(df) > 0 "No critical points found"
@assert all(isfinite.(df.z)) "Invalid function values"

# Load and validate JSON metadata
summary = JSON3.read("validation_summary.json")
@assert summary.success == true "Job reported failure"
@assert summary.results.accuracy_check == true "Accuracy check failed"
```

#### **C. Mathematical Validation**
```julia
# Verify critical points are actually critical
using ForwardDiff

function verify_critical_point(f, point, tolerance=1e-6)
    gradient = ForwardDiff.gradient(f, point)
    gradient_norm = norm(gradient)
    return gradient_norm < tolerance
end

# Check each critical point
for i in 1:nrow(df)
    point = [df[i, :x1], df[i, :x2]]
    is_critical = verify_critical_point(Deuflhard, point)
    @info "Point $i critical check" point=point is_critical=is_critical
end
```

### **Phase 3: Performance Analysis**

#### **A. Timing Analysis**
```bash
# Extract timing information from SLURM output
grep "time" slurm_*.out
# Look for:
# - Construction time
# - Solving time  
# - Processing time
# - Total job time
```

#### **B. Scaling Analysis**
```julia
# Compare results across different parameters
results_comparison = Dict(
    "degree_8_samples_50" => load_results("test_id_1"),
    "degree_10_samples_80" => load_results("test_id_2"),
    "degree_12_samples_100" => load_results("test_id_3")
)

# Analyze scaling trends
for (config, result) in results_comparison
    @info config l2_error=result.l2_error num_points=result.num_critical_points
end
```

---

## ✅ Validation Criteria

### **Pass Criteria**
1. **File Completeness**: All expected output files present
2. **Data Integrity**: CSV readable, JSON parseable, no NaN/Inf values
3. **Mathematical Accuracy**: Distance to known minimum < 0.1
4. **Approximation Quality**: L2 error < 0.01 (problem-dependent)
5. **Critical Point Validity**: Gradient norm < 1e-6 at each point
6. **Job Success**: validation_summary.json shows success=true

### **Warning Criteria** (Investigate but may be acceptable)
1. **High L2 Error**: 0.01 < L2 error < 0.1
2. **Few Critical Points**: < 5 points found (may indicate high degree needed)
3. **High Condition Number**: > 1e12 (numerical instability warning)
4. **Long Computation Time**: > expected time for given parameters

### **Fail Criteria** (Requires investigation/rerun)
1. **Missing Files**: Any expected output file missing
2. **Job Failure**: validation_summary.json shows success=false
3. **Mathematical Error**: Distance to known minimum > 0.1
4. **Data Corruption**: NaN/Inf values in results
5. **Critical Point Invalid**: Gradient norm > 1e-3 at supposed critical point

---

## 🔧 Troubleshooting Common Issues

### **Issue**: No critical points found
**Diagnosis**: Check polynomial degree, sample count, domain size  
**Solution**: Increase degree or samples, verify function implementation

### **Issue**: High L2 approximation error
**Diagnosis**: Insufficient polynomial degree or samples  
**Solution**: Increase degree, increase samples, check function smoothness

### **Issue**: Critical points outside expected region
**Diagnosis**: Domain too large, or function has unexpected structure  
**Solution**: Reduce domain size, verify function implementation

### **Issue**: Numerical instability (high condition number)
**Diagnosis**: Ill-conditioned polynomial basis  
**Solution**: Use normalized basis, reduce degree, increase precision

---

## 📈 Quality Metrics Dashboard

### **Automated Quality Assessment**
```julia
function assess_job_quality(test_id)
    summary = load_validation_summary(test_id)
    
    quality_score = 0
    max_score = 100
    
    # File completeness (20 points)
    if all_files_present(test_id)
        quality_score += 20
    end
    
    # Mathematical accuracy (30 points)  
    if summary.results.accuracy_check
        quality_score += 30
    end
    
    # Approximation quality (25 points)
    l2_error = summary.results.l2_error
    if l2_error < 0.001
        quality_score += 25
    elseif l2_error < 0.01
        quality_score += 15
    elseif l2_error < 0.1
        quality_score += 5
    end
    
    # Critical point count (15 points)
    num_points = summary.results.num_critical_points
    if num_points >= 5
        quality_score += 15
    elseif num_points >= 2
        quality_score += 10
    elseif num_points >= 1
        quality_score += 5
    end
    
    # Numerical stability (10 points)
    condition_num = summary.results.condition_number
    if condition_num < 1e6
        quality_score += 10
    elseif condition_num < 1e12
        quality_score += 5
    end
    
    return quality_score, max_score
end
```

### **Quality Thresholds**
- **Excellent**: 90-100 points
- **Good**: 70-89 points  
- **Acceptable**: 50-69 points
- **Poor**: 30-49 points
- **Failed**: < 30 points

---

## 📊 Downstream Analysis Integration

### **Data Pipeline Integration**
```julia
# Standard analysis pipeline
function analyze_critical_points_batch(test_ids)
    results = []
    
    for test_id in test_ids
        # Load results
        df = CSV.read("results/critical_points_$test_id/critical_points.csv", DataFrame)
        summary = JSON3.read("results/critical_points_$test_id/validation_summary.json")
        
        # Quality assessment
        quality_score, max_score = assess_job_quality(test_id)
        
        # Store for batch analysis
        push!(results, Dict(
            "test_id" => test_id,
            "critical_points" => df,
            "summary" => summary,
            "quality_score" => quality_score
        ))
    end
    
    return results
end
```

### **Visualization Integration**
```julia
# Plot critical points with quality indicators
function plot_critical_points_with_quality(results)
    for result in results
        df = result["critical_points"]
        quality = result["quality_score"]
        
        # Color code by quality
        color = quality > 80 ? :green : quality > 50 ? :orange : :red
        
        scatter!(df.x1, df.x2, 
                color=color, 
                label="Test $(result["test_id"]) (Q: $quality)")
    end
end
```

---

**Last Updated**: August 9, 2025  
**Status**: ✅ Complete verification procedure  
**Integration**: Ready for HPC workflow integration
