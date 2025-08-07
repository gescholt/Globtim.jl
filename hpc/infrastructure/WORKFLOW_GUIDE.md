# Globtim HPC JSON Tracking System - Complete Workflow Guide

## Overview

This guide explains the complete workflow for using the JSON-based HPC tracking system with Globtim. The system transforms your computational experiments from ad-hoc runs into systematic, reproducible, and well-organized studies.

## 🎯 **What Problem Does This Solve?**

**Before:** 
- Parameters scattered across notebook cells
- Results lost or hard to find
- No systematic way to compare runs
- Difficulty reproducing exact computations
- File organization becomes chaotic over time

**After:**
- All parameters automatically captured in JSON
- Results systematically organized and searchable
- Easy comparison between different parameter sets
- Perfect reproducibility from JSON input files
- Clean, hierarchical file organization

## 🚀 **Complete Workflow**

### **Phase 1: Setup and Validation**

#### Step 1: Verify System Setup
```bash
# Navigate to your Globtim project
cd /path/to/globtim

# Test the JSON tracking system
julia hpc/infrastructure/test_package_activation.jl
```

**Expected Output:**
```
🎉 ALL TESTS PASSED!
✅ JSON tracking system packages are properly configured
```

If tests fail, ensure you have the required packages:
```bash
julia --project=. -e 'using Pkg; Pkg.add(["JSON3", "CSV", "SHA"])'
```

#### Step 2: Understand the File Organization
Your results will be organized in this structure:
```
hpc/results/
├── by_function/Deuflhard/2025-01/single_tests/
│   └── deg8_cheb_20250108_103000_abc12345/
│       ├── input_config.json      # All input parameters
│       ├── output_results.json    # All computational results
│       ├── detailed_outputs/      # CSV files, coefficients, etc.
│       └── logs/                  # Execution logs
├── by_date/2025-01-08/            # Chronological access
├── by_tag/benchmark/              # Categorical access
└── indices/                       # Search indices (future)
```

### **Phase 2: Creating and Running Jobs**

#### Step 3: Create Your First JSON-Tracked Job

**For Quick Testing:**
```bash
cd hpc/jobs/creation
julia create_json_tracked_job.jl deuflhard quick
```

**For Standard Analysis:**
```bash
julia create_json_tracked_job.jl deuflhard standard --degree 10 --basis legendre
```

**For Thorough Studies:**
```bash
julia create_json_tracked_job.jl deuflhard thorough
```

**What This Creates:**
- Complete input configuration JSON file
- SLURM job script with JSON tracking enabled
- Organized output directory structure
- Automatic symlinks for easy access

#### Step 4: Submit to HPC Cluster

```bash
# Copy job script to cluster
scp path/to/job_script.slurm scholten@falcon:~/globtim_hpc/

# Submit job
ssh scholten@falcon 'cd ~/globtim_hpc && sbatch job_script.slurm'

# Monitor job
python hpc/monitoring/python/slurm_monitor.py --analyze [JOB_ID]
```

### **Phase 3: Results Analysis and Management**

#### Step 5: Access and Analyze Results

**Find Your Results:**
```bash
# By function and date
ls hpc/results/by_function/Deuflhard/2025-01/single_tests/

# By computation date
ls hpc/results/by_date/2025-01-08/

# By tags
ls hpc/results/by_tag/benchmark/
```

**Examine Results:**
```bash
# View input parameters
cat path/to/computation/input_config.json

# View computational results
cat path/to/computation/output_results.json

# Access detailed data
ls path/to/computation/detailed_outputs/
```

## 📊 **Typical Use Cases and Workflows**

### **Use Case 1: Single Function Analysis (Like Your Deuflhard Notebook)**

**Traditional Approach:**
```julia
# In notebook cell 1
d = 8
SMPL = 100
center = [0.0, 0.0]
TR = test_input(f, dim=n, center=[0.0, 0.0], GN=SMPL, sample_range=[1.2, 1.5])

# In notebook cell 2
pol_cheb = Constructor(TR, d, basis=:chebyshev)
pol_lege = Constructor(TR, d, basis=:legendre)

# In notebook cell 3
df_cheb, df_min_cheb = analyze_critical_points(f, df_cheb, TR, tol_dist=0.001)
```

**JSON-Tracked Approach:**
```bash
# Create job with exact same parameters
julia create_json_tracked_job.jl deuflhard standard \
    --degree 8 --samples 100 --sample_range 1.5 --basis chebyshev

# Submit to cluster
sbatch job_script.slurm

# Results automatically organized and documented
```

**Benefits:**
- All parameters automatically captured
- Results permanently stored and organized
- Can easily repeat with different parameters
- Perfect documentation for papers/reports

### **Use Case 2: Parameter Sweep Studies**

**Goal:** Compare different degrees and bases systematically

**Workflow:**
```bash
# Create multiple jobs with different parameters
julia create_json_tracked_job.jl deuflhard standard --degree 4 --basis chebyshev
julia create_json_tracked_job.jl deuflhard standard --degree 6 --basis chebyshev  
julia create_json_tracked_job.jl deuflhard standard --degree 8 --basis chebyshev
julia create_json_tracked_job.jl deuflhard standard --degree 4 --basis legendre
julia create_json_tracked_job.jl deuflhard standard --degree 6 --basis legendre
julia create_json_tracked_job.jl deuflhard standard --degree 8 --basis legendre

# Submit all jobs
for script in *.slurm; do sbatch $script; done

# Analyze results systematically
python analyze_parameter_sweep.py --function Deuflhard --tag standard
```

### **Use Case 3: Reproducible Research**

**Scenario:** You need to reproduce results from 6 months ago

**Traditional Problem:** 
- "What parameters did I use?"
- "Which version of the code?"
- "What was the exact tolerance?"

**JSON-Tracked Solution:**
```bash
# Find the computation
ls hpc/results/by_date/2024-08-05/

# Examine exact parameters
cat hpc/results/by_function/Deuflhard/.../input_config.json

# Reproduce exactly
julia reproduce_computation.jl abc12345
```

### **Use Case 4: Collaborative Research**

**Scenario:** Share results with collaborators

**What You Share:**
```
computation_directory/
├── input_config.json      # Exact parameters used
├── output_results.json    # All results and metrics
├── detailed_outputs/      # Raw data for further analysis
└── README_computation.md  # Auto-generated summary
```

**Collaborator Can:**
- See exactly what you did
- Reproduce your results
- Build on your work with confidence
- Compare with their own results

## 🔧 **Advanced Workflows**

### **Custom Function Integration**

For functions other than Deuflhard:

```julia
# 1. Add your function to the job creator (future enhancement)
# 2. Or modify the template for custom functions

# Example for HolderTable function
julia create_json_tracked_job.jl holdertable standard --degree 6
```

### **Batch Processing**

```bash
# Create a batch of jobs
for degree in 4 6 8 10; do
    for basis in chebyshev legendre; do
        julia create_json_tracked_job.jl deuflhard standard \
            --degree $degree --basis $basis \
            --description "sweep_deg${degree}_${basis}"
    done
done
```

### **Result Analysis Pipeline**

```julia
# Load and analyze multiple results
using JSON3, DataFrames

# Collect all results from a parameter sweep
results = []
for comp_dir in readdir("hpc/results/by_tag/parameter_sweep/")
    output_file = joinpath(comp_dir, "output_results.json")
    if isfile(output_file)
        data = JSON3.read(read(output_file, String), Dict)
        push!(results, data)
    end
end

# Create comparison DataFrame
df_comparison = DataFrame(results)

# Analyze trends
plot_convergence_analysis(df_comparison)
```

## 📈 **Integration with Existing Notebooks**

### **Migrating from Notebook-Based Workflow**

**Step 1:** Identify your key parameters
```julia
# From your notebook
d = 8                    # degree
SMPL = 100              # samples  
sample_range = [1.2, 1.5]  # range
basis = :chebyshev      # basis
tol_dist = 0.001        # tolerance
```

**Step 2:** Create equivalent JSON-tracked job
```bash
julia create_json_tracked_job.jl deuflhard standard \
    --degree 8 --samples 100 --sample_range 1.5 \
    --basis chebyshev --tolerance 0.001
```

**Step 3:** Use results in notebooks
```julia
# Load results into notebook for visualization
computation_id = "abc12345"
results_dir = "hpc/results/by_function/Deuflhard/.../deg8_cheb_..._$computation_id"

# Load critical points
df_critical = CSV.read(joinpath(results_dir, "detailed_outputs/critical_points.csv"), DataFrame)

# Load minima
df_min = CSV.read(joinpath(results_dir, "detailed_outputs/minima.csv"), DataFrame)

# Create your plots as usual
fig = cairo_plot_polyapprox_levelset(pol, TR, df_critical, df_min)
```

## 🎯 **Best Practices**

### **Naming and Organization**
- Use descriptive tags: `["benchmark", "high_precision", "comparison"]`
- Include purpose in description: `"Degree comparison for paper Figure 3"`
- Use consistent parameter ranges for comparability

### **Parameter Management**
- Start with `quick` jobs for testing
- Use `standard` for regular analysis  
- Reserve `thorough` for final production runs
- Document parameter choices in job descriptions

### **Result Management**
- Review results regularly and archive old ones
- Use tags to group related computations
- Keep detailed outputs for important results
- Delete failed/test runs periodically

### **Collaboration**
- Share computation IDs for specific results
- Use consistent tagging across team members
- Document parameter choices and rationale
- Archive important results with clear descriptions

## 🚨 **Common Pitfalls and Solutions**

**Problem:** "I can't find my results"
**Solution:** Use multiple access patterns - by date, by tag, by function

**Problem:** "I don't remember what parameters I used"
**Solution:** Everything is in `input_config.json` - no guessing needed

**Problem:** "My results directory is getting too large"
**Solution:** Use the built-in archiving and cleanup features

**Problem:** "I want to modify parameters slightly"
**Solution:** Load existing `input_config.json`, modify, and create new job

## 🔮 **Future Enhancements**

- **Web Dashboard:** Browser interface for exploring results
- **Automated Analysis:** Scripts to generate summary reports
- **Parameter Optimization:** Use historical results to suggest parameters
- **Database Backend:** Optional database for large-scale result management
- **Integration Tools:** Direct notebook integration for seamless workflow

---

This system transforms your computational workflow from chaotic to systematic, from irreproducible to perfectly documented, and from isolated to collaborative. Start with simple jobs and gradually adopt more advanced features as you become comfortable with the system.
