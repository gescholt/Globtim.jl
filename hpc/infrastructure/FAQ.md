# Frequently Asked Questions - JSON Tracking System

## 🤔 **General Questions**

### **Q: Why do I need this system? My notebooks work fine.**
**A:** Notebooks are great for exploration, but they have limitations:
- Parameters get scattered across cells and are easy to lose track of
- Results are hard to organize and find later
- Reproducibility requires remembering exact parameter combinations
- Collaboration means sharing messy notebooks with unclear execution order
- Scaling to parameter sweeps or HPC clusters is difficult

The JSON system gives you the best of both worlds: systematic, reproducible computation with the flexibility to use results in notebooks for visualization and analysis.

### **Q: Is this going to slow down my research?**
**A:** Actually, it speeds it up:
- **Initial setup**: 5 minutes one-time cost
- **Job creation**: 30 seconds vs 10+ minutes of manual parameter tracking
- **Finding old results**: Instant vs 20+ minutes of searching through files
- **Reproducing work**: 1 minute vs 30+ minutes of recreating from memory
- **Collaboration**: 2 minutes to share vs hours of explanation

### **Q: What if I just want to do a quick test?**
**A:** Perfect! Use the `quick` job type:
```bash
julia create_json_tracked_job.jl deuflhard quick
```
This creates a 30-minute job with minimal resources, but still captures all parameters for reproducibility.

## 🔧 **Technical Questions**

### **Q: What packages do I need to install?**
**A:** Just three additional packages in your main Globtim environment:
```bash
julia --project=. -e 'using Pkg; Pkg.add(["JSON3", "CSV", "SHA"])'
```
The system handles package activation automatically.

### **Q: Where do all these files go? Won't this bloat my project?**
**A:** The system is designed to prevent bloat:
- Results go in `hpc/results/` (separate from your main code)
- Hierarchical organization by function, date, and tags
- Automatic cleanup and archiving features
- Symlinks provide multiple access patterns without duplicating files
- You control what gets kept vs deleted

### **Q: What if I'm not using the HPC cluster?**
**A:** The system works locally too! The SLURM job scripts can be adapted to run locally, or you can use the JSON I/O utilities directly in your notebooks:
```julia
include("hpc/infrastructure/json_io.jl")
config = create_input_config(TR, degree, basis, precision_type)
save_input_config(config, "my_local_run/input_config.json")
```

### **Q: Can I modify parameters after creating a job?**
**A:** Yes! You can:
1. Edit the `input_config.json` file directly
2. Create a new job based on an existing configuration
3. Use the job creation script with different parameters

The system will detect if you're using identical parameters and ask if you want to overwrite or create a new version.

## 📊 **Workflow Questions**

### **Q: How do I convert my existing notebook workflow?**
**A:** Start gradually:
1. **Identify key parameters** from your notebook (degree, samples, tolerances, etc.)
2. **Create equivalent JSON-tracked job** with those parameters
3. **Run the job** and examine the results
4. **Load results back into notebook** for visualization and further analysis
5. **Compare** with your original notebook results to verify equivalence

### **Q: Can I still use notebooks for analysis and plotting?**
**A:** Absolutely! The system is designed to complement notebooks:
```julia
# Load results from JSON-tracked computation
using CSV, JSON3
df_critical = CSV.read("path/to/detailed_outputs/critical_points.csv", DataFrame)
results = JSON3.read(read("path/to/output_results.json", String), Dict)

# Use in your existing plotting code
fig = cairo_plot_polyapprox_levelset(pol, TR, df_critical, df_min)
```

### **Q: How do I do parameter sweeps?**
**A:** Very easily:
```bash
# Automated sweep
for degree in 4 6 8 10; do
    for basis in chebyshev legendre; do
        julia create_json_tracked_job.jl deuflhard standard \
            --degree $degree --basis $basis \
            --description "sweep_deg${degree}_${basis}"
    done
done
```

### **Q: What if I want to use a different function (not Deuflhard)?**
**A:** Currently, the job creator is set up for Deuflhard, but you can:
1. **Modify the job creation script** to support your function
2. **Use the JSON I/O utilities directly** in your own scripts
3. **Adapt the SLURM template** for custom functions

Future versions will support more functions out of the box.

## 🔍 **Results and Organization**

### **Q: How do I find my results?**
**A:** Multiple ways:
```bash
# By date (most common)
ls hpc/results/by_date/2025-01-08/

# By function
ls hpc/results/by_function/Deuflhard/2025-01/

# By tags
ls hpc/results/by_tag/benchmark/

# By computation ID
find hpc/results -name "*abc12345*"
```

### **Q: What's in each result directory?**
**A:** Complete documentation:
- `input_config.json` - Every parameter used
- `output_results.json` - All computational results and timing
- `detailed_outputs/` - CSV files with raw data
- `logs/` - Execution logs for debugging

### **Q: How do I compare results from different runs?**
**A:** The structured JSON format makes comparison easy:
```julia
# Load multiple results
results1 = JSON3.read(read("path1/output_results.json", String), Dict)
results2 = JSON3.read(read("path2/output_results.json", String), Dict)

# Compare key metrics
println("Run 1 L2 error: ", results1["polynomial_results"]["l2_error"])
println("Run 2 L2 error: ", results2["polynomial_results"]["l2_error"])
```

### **Q: Can I delete old results?**
**A:** Yes, and you should! The system is designed for easy cleanup:
- Delete test runs after verification
- Archive old results you want to keep but don't need immediate access to
- Use tags to identify results that can be safely deleted
- Keep important results with good descriptions for future reference

## 🚨 **Troubleshooting**

### **Q: I get "Package not found" errors**
**A:** Make sure you've installed the required packages:
```bash
julia --project=. -e 'using Pkg; Pkg.add(["JSON3", "CSV", "SHA"])'
```
And run the test script to verify:
```bash
julia hpc/infrastructure/test_package_activation.jl
```

### **Q: Job creation fails with path errors**
**A:** Make sure you're in the right directory:
```bash
cd hpc/jobs/creation
julia create_json_tracked_job.jl deuflhard quick
```

### **Q: My job runs but produces no results**
**A:** Check the SLURM logs:
```bash
cat path/to/computation/logs/slurm_*.out
```
Common issues:
- Julia environment not properly activated
- Missing dependencies on the cluster
- Insufficient memory or time limits

### **Q: I can't find my results**
**A:** Try multiple search approaches:
```bash
# Check by date first
ls hpc/results/by_date/$(date +%Y-%m-%d)/

# Look for your computation ID
find hpc/results -name "*your_computation_id*"

# Check if job completed successfully
python hpc/monitoring/python/slurm_monitor.py --analyze [JOB_ID]
```

## 🎯 **Best Practices**

### **Q: What naming conventions should I use?**
**A:** 
- **Descriptions**: Be specific - "degree_comparison_for_paper_fig3" not "test"
- **Tags**: Use consistent categories - ["benchmark", "comparison", "publication"]
- **Job types**: Start with "quick" for testing, use "standard" for real work

### **Q: How often should I clean up results?**
**A:**
- **Daily**: Delete obvious test runs and failures
- **Weekly**: Review and organize recent results
- **Monthly**: Archive old results you want to keep
- **Quarterly**: Major cleanup and organization review

### **Q: How do I share results with collaborators?**
**A:** Share the computation directory or computation ID:
```bash
# Share entire directory
tar -czf computation_abc12345.tar.gz path/to/computation_directory/

# Or just share the computation ID and let them access it directly
echo "Results are in computation abc12345"
```

## 🔮 **Future Development**

### **Q: What features are planned?**
**A:**
- Web dashboard for browsing results
- Support for more objective functions
- Automated analysis and reporting
- Database backend for large-scale studies
- Direct notebook integration

### **Q: Can I contribute to the system?**
**A:** Absolutely! Areas where contributions are welcome:
- Additional objective function support
- Analysis and visualization tools
- Documentation improvements
- Bug fixes and performance improvements

### **Q: Will this system be maintained?**
**A:** Yes! This is designed to be a core part of the Globtim workflow. The system is built with maintainability in mind and will evolve with user needs.

---

## 💡 **Still Have Questions?**

1. **Check the documentation**: `README_JSON_Tracking.md`, `WORKFLOW_GUIDE.md`, `QUICK_START.md`
2. **Run the test suite**: `julia test_package_activation.jl`
3. **Try a simple example**: Start with a `quick` job and explore the results
4. **Look at the code**: The system is designed to be readable and modifiable

**Remember**: Start simple, experiment, and gradually adopt more features as you become comfortable with the system! 🚀
