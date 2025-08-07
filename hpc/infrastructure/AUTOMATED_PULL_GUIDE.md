# Automated Results Pull System

## Overview

The automated pull system retrieves JSON-tracked computation results from the HPC cluster to your local machine. It builds on existing HPC infrastructure while being specifically designed for the JSON tracking workflow.

## 🚀 **Quick Start**

### **Pull Recent Results**
```bash
# Pull all results from last 7 days (default)
./hpc/infrastructure/pull_results.sh

# Pull results from last 14 days
./hpc/infrastructure/pull_results.sh --days 14
```

### **Pull Specific Computation**
```bash
# Pull your specific computation (e.g., the one you just ran)
./hpc/infrastructure/pull_results.sh --computation-id 4391dd81
```

### **Force Update**
```bash
# Force overwrite existing local results
./hpc/infrastructure/pull_results.sh --force --days 3
```

## 🔧 **How It Works**

### **Integration with Existing Infrastructure**

The pull system **reuses and extends** existing HPC infrastructure:

1. **Builds on `collect_hpc_results.py`**: Uses existing SSH patterns and result collection logic
2. **Uses `cluster_config.sh`**: Automatically loads your cluster configuration
3. **Integrates with monitoring**: Works alongside `slurm_monitor.py`
4. **Follows JSON tracking structure**: Maintains the organized directory hierarchy

### **What Gets Pulled**

For each JSON-tracked computation, the system pulls:
- `input_config.json` - All input parameters
- `output_results.json` - Computational results and metrics
- `detailed_outputs/` - CSV files with critical points, minima, etc.
- `logs/` - SLURM job logs for debugging

### **Local Organization**

Results are organized locally following the same structure as on the cluster:
```
hpc/results/
├── by_function/Deuflhard/2025-08/single_tests/
│   └── quick_test_20250805_143404_4391dd81/
├── by_date/2025-08-05/
│   └── 4391dd81 -> ../by_function/Deuflhard/.../
└── by_tag/quick/
    └── 4391dd81 -> ../by_function/Deuflhard/.../
```

## 📊 **Usage Examples**

### **Daily Workflow**
```bash
# Morning: Check for overnight results
./hpc/infrastructure/pull_results.sh

# Explore what you got
ls hpc/results/by_date/$(date +%Y-%m-%d)/

# Load into notebook for analysis
```

### **Project Cleanup**
```bash
# Pull all results from a specific campaign
./hpc/infrastructure/pull_results.sh --days 30

# Force update everything (careful!)
./hpc/infrastructure/pull_results.sh --force --days 30
```

### **Specific Result Retrieval**
```bash
# You know the computation ID from job submission
./hpc/infrastructure/pull_results.sh --computation-id abc12345

# Or from monitoring
python hpc/monitoring/python/slurm_monitor.py
# See computation ID, then pull it
./hpc/infrastructure/pull_results.sh --computation-id [ID_FROM_MONITOR]
```

## 🔍 **Finding Your Results**

### **After Pulling**

Results are accessible through multiple paths:

```bash
# By date (most common for recent work)
ls hpc/results/by_date/2025-08-05/

# By function (for systematic analysis)
ls hpc/results/by_function/Deuflhard/2025-08/single_tests/

# By tags (for thematic grouping)
ls hpc/results/by_tag/benchmark/
ls hpc/results/by_tag/quick/
```

### **Loading into Notebooks**

```julia
using JSON3, CSV, DataFrames

# Load a specific computation
computation_id = "4391dd81"
result_dir = "hpc/results/by_date/2025-08-05/$computation_id"

# Load input parameters
input_config = JSON3.read(read("$result_dir/input_config.json", String), Dict)

# Load computational results
output_results = JSON3.read(read("$result_dir/output_results.json", String), Dict)

# Load detailed data
df_critical = CSV.read("$result_dir/detailed_outputs/critical_points.csv", DataFrame)
df_minima = CSV.read("$result_dir/detailed_outputs/minima.csv", DataFrame)

# Now analyze as usual...
```

## ⚙️ **Configuration**

### **Automatic Configuration**

The system automatically uses your existing cluster configuration:

```bash
# If you have hpc/config/cluster_config.sh, it's used automatically
# No additional setup needed!
```

### **Manual Configuration**

You can override settings:

```bash
# Custom cluster host
./hpc/infrastructure/pull_results.sh --cluster-host myuser@mycluster

# Custom paths (advanced)
python3 hpc/infrastructure/pull_json_results.py \
    --cluster-host myuser@mycluster \
    --cluster-path ~/my_globtim \
    --local-path my_results/
```

## 🚨 **Troubleshooting**

### **SSH Connection Issues**
```bash
# Test SSH connection manually
ssh scholten@falcon "echo 'Connection works'"

# Check if your keys are loaded
ssh-add -l

# Check cluster configuration
cat hpc/config/cluster_config.sh
```

### **No Results Found**
```bash
# Check if results exist on cluster
ssh scholten@falcon "find ~/globtim_hpc/hpc/results -name 'input_config.json' | head -5"

# Check if your job completed
python hpc/monitoring/python/slurm_monitor.py --analyze [JOB_ID]

# Try broader search
./hpc/infrastructure/pull_results.sh --days 30
```

### **Permission Issues**
```bash
# Make sure scripts are executable
chmod +x hpc/infrastructure/pull_results.sh
chmod +x hpc/infrastructure/pull_json_results.py

# Check local directory permissions
ls -la hpc/results/
```

## 🔄 **Integration with Workflow**

### **Complete JSON-Tracked Workflow**

1. **Create Job**: `julia create_json_tracked_job.jl deuflhard quick`
2. **Submit**: `sbatch job_script.slurm`
3. **Monitor**: `python hpc/monitoring/python/slurm_monitor.py`
4. **Pull Results**: `./hpc/infrastructure/pull_results.sh`
5. **Analyze**: Load JSON/CSV files into notebooks

### **Automated Workflows**

```bash
# Daily cron job to pull results
0 9 * * * cd /path/to/globtim && ./hpc/infrastructure/pull_results.sh

# Weekly comprehensive pull
0 9 * * 1 cd /path/to/globtim && ./hpc/infrastructure/pull_results.sh --days 7 --force
```

## 📈 **Advanced Features**

### **Selective Pulling**

The system is smart about what to pull:
- Only pulls JSON-tracked computations (ignores old-style results)
- Skips already-downloaded results (unless `--force`)
- Maintains symlink structure for multiple access patterns
- Preserves file timestamps and metadata

### **Integration with Existing Tools**

```python
# Use with existing result collector
from tools.benchmarking.collect_hpc_results import HPCResultCollector

# The JSON puller can work alongside existing tools
collector = HPCResultCollector()
# ... existing workflow ...

# Then use JSON puller for JSON-tracked results
# ./hpc/infrastructure/pull_results.sh
```

## 💡 **Best Practices**

1. **Regular Pulls**: Pull results daily to avoid accumulation
2. **Specific Pulls**: Use computation IDs for important results
3. **Force Sparingly**: Only use `--force` when you know you need it
4. **Check First**: Use monitoring tools to verify job completion
5. **Clean Up**: Periodically clean old local results

## 🔮 **Future Enhancements**

- **Incremental sync**: Only pull changed files
- **Compression**: Automatic compression of old results
- **Web interface**: Browser-based result exploration
- **Database integration**: Store metadata in searchable database
- **Notification system**: Alert when new results are available

---

The automated pull system completes the JSON tracking workflow by seamlessly bringing your HPC results back to your local environment for analysis and visualization. It builds on proven infrastructure while adding JSON-tracking awareness for a smooth, integrated experience.

**Your complete workflow is now: Create → Submit → Monitor → Pull → Analyze** 🚀
