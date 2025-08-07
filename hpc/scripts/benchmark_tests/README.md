# Deuflhard Benchmark Test Suite

Comprehensive testing infrastructure for polynomial construction and critical point finding using the Deuflhard function as a benchmark case.

## 🎯 **Overview**

This test suite provides systematic evaluation of Globtim's core functionality:

- **Polynomial Construction**: Tests `Constructor` function with various degrees and sample sizes
- **Critical Point Finding**: Uses `solve_polynomial_system` and `process_crit_pts` for complete analysis
- **Parameter Tracking**: Records all input parameters for reproducibility
- **Performance Measurement**: Integrates BenchmarkTools for detailed timing analysis
- **Structured Output**: Generates CSV files and detailed reports for analysis

## 📁 **Files**

- `deuflhard_test_suite.jl` - Main test suite with comprehensive parameter testing
- `deuflhard_benchmark.slurm` - SLURM job template for cluster execution
- `submit_deuflhard_test.sh` - Easy submission script with monitoring
- `README.md` - This documentation

## 🚀 **Quick Start**

### **Basic Usage**
```bash
# Standard test suite (2 hours, comprehensive)
cd hpc/scripts/benchmark_tests
./submit_deuflhard_test.sh --monitor

# Quick test (30 minutes, basic parameters)
./submit_deuflhard_test.sh --mode quick --monitor

# Thorough test (4+ hours, all combinations)
./submit_deuflhard_test.sh --mode thorough
```

### **Custom Testing**
```bash
# Test specific degree and sample size
./submit_deuflhard_test.sh --degree 8 --samples 200

# Custom resources
./submit_deuflhard_test.sh --mode standard --time 03:00:00 --memory 128G
```

## 📊 **Test Modes**

### **Quick Mode** (`--mode quick`)
- **Duration**: ~30 minutes
- **Degrees**: [4, 6]
- **Sample sizes**: [50, 100]
- **Sample ranges**: [1.2]
- **Centers**: [[0.0, 0.0]]
- **Precision types**: [Float64Precision]
- **Benchmarks**: Disabled (for speed)

### **Standard Mode** (`--mode standard`) - Default
- **Duration**: ~2 hours
- **Degrees**: [4, 6, 8, 10]
- **Sample sizes**: [100, 200]
- **Sample ranges**: [1.2]
- **Centers**: [[0.0, 0.0]]
- **Precision types**: [Float64Precision, AdaptivePrecision]
- **Benchmarks**: Enabled

### **Thorough Mode** (`--mode thorough`)
- **Duration**: ~4+ hours
- **Degrees**: [4, 6, 8, 10, 12]
- **Sample sizes**: [50, 100, 200, 400]
- **Sample ranges**: [1.0, 1.2, 1.5]
- **Centers**: [[0.0, 0.0], [0.1, 0.1], [-0.1, 0.1]]
- **Precision types**: [Float64Precision, AdaptivePrecision]
- **Benchmarks**: Enabled

## 📈 **What Gets Tested**

### **For Each Parameter Combination:**

1. **test_input Creation**
   - Function: `Deuflhard(x)` where `x ∈ ℝ²`
   - Domain: `[-sample_range, sample_range]²` centered at specified point
   - Sample generation with specified count

2. **Polynomial Construction**
   - `Constructor(TR, degree, precision=precision_type)`
   - Timing measurement (with/without BenchmarkTools)
   - L2 approximation error recording
   - Condition number analysis

3. **Critical Point Finding**
   - `solve_polynomial_system(x, 2, degree, pol.coeffs)`
   - `process_crit_pts(solutions, Deuflhard, TR)`
   - `analyze_critical_points` for classification
   - Count of total critical points and local minima

4. **Performance Metrics**
   - Construction time (seconds)
   - Critical point finding time (seconds)
   - Memory usage (if benchmarks enabled)
   - Allocation counts (if benchmarks enabled)

## 📋 **Output Structure**

### **Results Directory**: `~/globtim_hpc/benchmark_results_[JOB_ID]/`

#### **Main Files:**
- **`test_results.csv`** - Complete results table with all parameters and metrics
- **`test_config.txt`** - Test configuration and system metadata
- **`benchmark_data.txt`** - Detailed BenchmarkTools results (if enabled)
- **`job_summary.txt`** - SLURM job information and environment details

#### **CSV Columns:**
```
test_id, timestamp, function_name, dimension, degree, samples, sample_range,
center_x, center_y, precision_type, construction_time, l2_error, 
condition_number, n_coefficients, n_critical_points, n_local_minima,
critical_point_time, julia_version, threads, hostname
```

## 🔧 **Advanced Usage**

### **Custom Parameter Testing**
```bash
# Test multiple specific degrees
for degree in 6 8 10 12; do
    ./submit_deuflhard_test.sh --degree $degree --samples 200 --mode quick
done

# Test scaling with sample size
for samples in 100 200 400 800; do
    ./submit_deuflhard_test.sh --degree 8 --samples $samples --mode quick
done
```

### **Resource Optimization**
```bash
# High-memory configuration for large polynomials
./submit_deuflhard_test.sh --mode thorough --memory 256G --time 08:00:00

# Multi-node testing (if needed)
./submit_deuflhard_test.sh --cpus 48 --memory 128G
```

### **Monitoring and Analysis**
```bash
# Monitor job progress
squeue -j [JOB_ID]

# View real-time output
tail -f deuflhard_benchmark_[JOB_ID].out

# Analyze results
cd ~/globtim_hpc/benchmark_results_[JOB_ID]/
head -20 test_results.csv
```

## 📊 **Expected Results**

### **Typical Performance (Standard Mode)**
- **Construction times**: 0.1s - 10s (depending on degree/samples)
- **L2 errors**: 1e-12 to 1e-6 (higher degree = lower error)
- **Critical points**: 10-50 points (varies with degree)
- **Local minima**: 2-8 minima (Deuflhard has multiple local minima)

### **Scaling Behavior**
- **Degree scaling**: Construction time ~ O(degree³)
- **Sample scaling**: Construction time ~ O(samples)
- **Critical point scaling**: Count ~ O(degree²)

## 🔍 **Troubleshooting**

### **Common Issues**
1. **Package loading errors**: Check that all packages were installed successfully
2. **Memory issues**: Increase `--memory` for high-degree polynomials
3. **Time limits**: Increase `--time` for thorough testing
4. **Critical point failures**: May indicate numerical issues with high degrees

### **Debugging**
```bash
# Check job status
squeue -j [JOB_ID]

# View error log
cat deuflhard_benchmark_[JOB_ID].err

# Test locally first
ssh [CLUSTER_HOST]
cd ~/globtim_hpc
julia deuflhard_test_suite.jl --quick
```

## 🎯 **Integration with Existing Infrastructure**

This test suite integrates with:
- **Compilation tests**: `hpc/scripts/compilation_tests/`
- **Package installation**: `hpc/scripts/package_installation/`
- **Job monitoring**: `hpc/monitoring/`
- **Existing examples**: `Examples/hpc_minimal_2d_example.jl`

## 📚 **Next Steps**

After successful Deuflhard testing:
1. **Extend to other benchmark functions** (Rastringin, HolderTable, etc.)
2. **Add higher dimensions** (3D, 4D testing)
3. **Performance optimization** based on results
4. **Integration with production workflows**

## 🤝 **Contributing**

To add new test functions or extend the framework:
1. Add function to `src/BenchmarkFunctions.jl`
2. Create new test suite following `deuflhard_test_suite.jl` pattern
3. Update SLURM templates and submission scripts
4. Document expected results and scaling behavior
