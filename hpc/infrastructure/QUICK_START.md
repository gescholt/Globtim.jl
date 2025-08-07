# 🚀 Quick Start Guide - JSON Tracking System

## 5-Minute Setup

### 1. **Verify Setup** (30 seconds)
```bash
cd /path/to/globtim
julia hpc/infrastructure/test_package_activation.jl
```
✅ Should see: "🎉 ALL TESTS PASSED!"

### 2. **Create Your First Job** (1 minute)
```bash
cd hpc/jobs/creation
julia create_json_tracked_job.jl deuflhard quick
```
✅ Creates: Job script + Input config + Output directory

### 3. **Submit to Cluster** (30 seconds)
```bash
# Copy to cluster
scp deg8_cheb_*.slurm scholten@falcon:~/globtim_hpc/

# Submit
ssh scholten@falcon 'cd ~/globtim_hpc && sbatch deg8_cheb_*.slurm'
```

### 4. **Monitor Job** (ongoing)
```bash
# Monitor all jobs
python hpc/monitoring/python/slurm_monitor.py

# Analyze specific job
python hpc/monitoring/python/slurm_monitor.py --analyze [JOB_ID]

# Continuous monitoring
python hpc/monitoring/python/slurm_monitor.py --continuous
```

### 5. **Pull Results** (1 minute)
```bash
# Automatically pull your results from cluster
./hpc/infrastructure/pull_results.sh

# Or pull specific computation
./hpc/infrastructure/pull_results.sh --computation-id 4391dd81
```

### 6. **Access Results** (1 minute)
```bash
# Find your results locally
ls hpc/results/by_date/$(date +%Y-%m-%d)/

# View summary
cat path/to/computation/output_results.json
```

## 🎯 **Your First Real Workflow**

### **Scenario: Reproduce Your Deuflhard Notebook Results**

**What you had in notebook:**
```julia
d = 8 # degree
SMPL = 100 # samples  
center = [0.0, 0.0]
sample_range = 1.5
basis = :chebyshev
tol_dist = 0.001
```

**Convert to JSON-tracked job:**
```bash
julia create_json_tracked_job.jl deuflhard standard \
    --degree 8 --samples 100 --sample_range 1.5 \
    --basis chebyshev --description "notebook_reproduction"
```

**What you get:**
- ✅ All parameters automatically captured
- ✅ Results systematically organized  
- ✅ Perfect reproducibility
- ✅ Easy to find and share

## 📊 **Common Job Types**

### **Quick Testing**
```bash
julia create_json_tracked_job.jl deuflhard quick
# → 30min, 16G RAM, degree 4-6, minimal samples
```

### **Standard Analysis** 
```bash
julia create_json_tracked_job.jl deuflhard standard --degree 8
# → 2hr, 32G RAM, comprehensive analysis
```

### **Production Runs**
```bash
julia create_json_tracked_job.jl deuflhard thorough --degree 10
# → 4hr, 64G RAM, full analysis with all features
```

## 🔍 **Finding Your Results**

### **By Date** (most common)
```bash
ls hpc/results/by_date/2025-01-08/
# Shows all computations from today
```

### **By Function**
```bash
ls hpc/results/by_function/Deuflhard/2025-01/single_tests/
# Shows all Deuflhard runs this month
```

### **By Tags**
```bash
ls hpc/results/by_tag/benchmark/
# Shows all benchmark runs
```

## 📁 **What's in Each Result Directory**

```
your_computation_abc12345/
├── input_config.json          # Every parameter you used
├── output_results.json        # All results and timing
├── detailed_outputs/
│   ├── critical_points.csv    # All critical points found
│   ├── minima.csv             # Local minima details  
│   └── polynomial_coeffs.json # Polynomial coefficients
└── logs/
    └── slurm_12345.out        # Execution log
```

## 🔧 **Customizing Jobs**

### **Different Parameters**
```bash
# Higher degree
julia create_json_tracked_job.jl deuflhard standard --degree 12

# Different basis
julia create_json_tracked_job.jl deuflhard standard --basis legendre

# More samples
julia create_json_tracked_job.jl deuflhard standard --samples 200

# Custom description and tags
julia create_json_tracked_job.jl deuflhard standard \
    --description "paper_figure_3" --tags "publication,comparison"
```

### **Parameter Sweeps**
```bash
# Compare different degrees
for deg in 4 6 8 10; do
    julia create_json_tracked_job.jl deuflhard standard \
        --degree $deg --description "degree_sweep_$deg"
done

# Compare bases
for basis in chebyshev legendre; do
    julia create_json_tracked_job.jl deuflhard standard \
        --basis $basis --description "basis_comparison_$basis"  
done
```

## 📈 **Using Results in Notebooks**

### **Load Results for Analysis**
```julia
using JSON3, CSV, DataFrames

# Load computational results
computation_id = "abc12345"  # From your job output
results_path = "hpc/results/by_function/Deuflhard/.../output_results.json"
results = JSON3.read(read(results_path, String), Dict)

# Access key metrics
l2_error = results["polynomial_results"]["l2_error"]
n_minima = results["critical_point_results"]["n_local_minima"]
runtime = results["metadata"]["total_runtime"]

println("L2 Error: $l2_error")
println("Local Minima Found: $n_minima") 
println("Runtime: $runtime seconds")
```

### **Load Detailed Data**
```julia
# Load critical points for plotting
df_critical = CSV.read("path/to/detailed_outputs/critical_points.csv", DataFrame)
df_minima = CSV.read("path/to/detailed_outputs/minima.csv", DataFrame)

# Use in your existing plotting code
fig = cairo_plot_polyapprox_levelset(pol, TR, df_critical, df_minima)
```

## 🚨 **Troubleshooting**

### **"Package not found" errors**
```bash
julia --project=. -e 'using Pkg; Pkg.add(["JSON3", "CSV", "SHA"])'
```

### **"Job creation failed"**
```bash
# Check you're in the right directory
cd hpc/jobs/creation
pwd  # Should end with /globtim/hpc/jobs/creation
```

### **"Can't find results"**
```bash
# Check by date first
ls hpc/results/by_date/$(date +%Y-%m-%d)/
# Then follow symlinks to actual directories
```

### **"Results directory empty"**
```bash
# Check job status
squeue -u $USER
# Check job logs
cat path/to/computation/logs/slurm_*.out
```

## 🎯 **Next Steps**

### **After Your First Successful Job:**
1. **Explore the results** - Look at all the JSON files and CSV data
2. **Try different parameters** - Create jobs with different degrees/bases
3. **Compare results** - Use the organized structure to compare runs
4. **Integrate with notebooks** - Load results into your analysis workflow

### **For Regular Use:**
1. **Develop naming conventions** - Use consistent descriptions and tags
2. **Create parameter sweep scripts** - Automate multiple job creation
3. **Set up result analysis pipelines** - Scripts to process multiple results
4. **Archive old results** - Keep your results directory organized

### **For Advanced Users:**
1. **Customize job templates** - Modify for your specific needs
2. **Create analysis dashboards** - Visualize results across multiple runs
3. **Integrate with databases** - For large-scale result management
4. **Develop automated workflows** - From job creation to result analysis

---

## 💡 **Pro Tips**

- **Start small:** Use `quick` jobs for testing, `standard` for real work
- **Use tags:** They make finding related results much easier
- **Check logs:** Always look at SLURM logs if something goes wrong
- **Keep descriptions:** Future you will thank present you for good descriptions
- **Regular cleanup:** Archive or delete old test runs to keep things organized

**You're now ready to transform your computational workflow! 🚀**
