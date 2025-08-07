# HPC Job Submission Scripts

This directory contains **working, tested** Python scripts for submitting and monitoring jobs on the HPC cluster.

## 🚀 Quick Start

```bash
# Navigate to submission directory
cd hpc/jobs/submission

# Submit basic test with automatic monitoring
python submit_basic_test.py --mode quick --auto-collect

# Test Globtim compilation
python submit_globtim_compilation_test.py --mode quick --function sphere

# Monitor existing job
python automated_job_monitor.py --job-id 12345 --test-id abc123
```

## 📋 Available Scripts

### 1. `submit_basic_test.py` ✅
**Purpose**: Test basic Julia functionality on the cluster
**Status**: Working perfectly
**Usage**:
```bash
python submit_basic_test.py [OPTIONS]

Options:
  --mode {quick,standard,extended}  Test mode (default: quick)
  --auto-collect                    Automatically monitor and collect outputs
  --no-monitor                      Don't show monitoring commands
```

**What it tests**:
- Julia environment setup
- Basic mathematical computations
- File I/O operations
- System information collection

### 2. `submit_globtim_compilation_test.py` ✅
**Purpose**: Test Globtim module loading and compilation
**Status**: Working (identifies dependency issues)
**Usage**:
```bash
python submit_globtim_compilation_test.py [OPTIONS]

Options:
  --mode {quick,standard,extended}  Test mode (default: quick)
  --function {sphere,rosenbrock,deuflhard}  Test function (default: sphere)
  --list-functions                  Show available test functions
```

**What it tests**:
- Globtim module loading
- Function evaluation
- Basic test_input creation
- Dependency identification

### 3. `automated_job_monitor.py` ✅
**Purpose**: Monitor jobs and automatically collect outputs
**Status**: Working perfectly
**Usage**:
```bash
python automated_job_monitor.py [OPTIONS]

Options:
  --job-id JOB_ID                   SLURM job ID to monitor (required)
  --test-id TEST_ID                 Test ID for better file identification
  --interval SECONDS                Check interval (default: 15)
  --max-wait SECONDS                Maximum wait time (default: 3600)
  --quick                           Quick collection without monitoring
```

**Features**:
- Real-time job status monitoring
- Automatic output collection when jobs complete
- Organized local result directories
- JSON summaries for automation

### 4. `test_automated_monitoring.py` ✅
**Purpose**: Test suite for the monitoring system
**Status**: Working perfectly
**Usage**:
```bash
python test_automated_monitoring.py
```

**What it does**:
- Tests quick collection on completed jobs
- Demonstrates monitoring workflow
- Validates system functionality

## 📊 Test Results & Examples

### Recent Successful Tests (August 7, 2025)

| Job ID | Test ID | Script | Status | Description |
|--------|---------|--------|--------|-------------|
| 59774392 | cd943d4b | submit_basic_test.py | ✅ Success | Basic Julia test completed |
| 59774394 | 587f142d | submit_globtim_compilation_test.py | ⚠️ Partial | Identified missing StaticArraysCore |
| 59774401 | 99ecbfe7 | install_hpc_dependencies_simple.py | ❌ Failed | Filesystem I/O errors |

### Example Output Structure
```
collected_results/
├── job_59774392_20250807_114937/
│   ├── basic_test_results_cd943d4b/
│   │   ├── basic_math_results.txt
│   │   ├── system_info.txt
│   │   └── job_summary.txt
│   ├── basic_test_cd943d4b_59774392.out
│   ├── basic_test_cd943d4b_59774392.err
│   └── collection_summary.json
```

## 🔧 Configuration

### Cluster Settings
- **Host**: `scholten@falcon`
- **Remote directory**: `~/globtim_hpc`
- **SLURM partition**: `batch`
- **Default resources**: 2-8 CPUs, 4-32GB RAM, 5-30 min time limit

### Local Settings
- **Results directory**: `collected_results/`
- **Monitoring interval**: 15 seconds
- **SSH timeout**: 30 seconds

## ⚠️ Known Issues & Limitations

### Dependency Issues
- **StaticArraysCore**: Missing on cluster, prevents LibFunctions.jl loading
- **JSON3**: Not available, limits structured output formatting
- **Package installation**: Filesystem I/O errors during Pkg.add()

### Workarounds
- Use text files instead of JSON for output
- Embed Julia code in SLURM scripts to avoid file dependencies
- Focus on basic functionality testing until dependencies are resolved

## 🚀 Integration Examples

### With Existing Scripts
```bash
# Use with shell scripts
./hpc/scripts/benchmark_tests/submit_deuflhard_test.sh --mode quick
python automated_job_monitor.py --job-id [RETURNED_JOB_ID]

# Chain multiple tests
python submit_basic_test.py --mode quick
python submit_globtim_compilation_test.py --mode quick --function rosenbrock
```

### With VS Code Tasks
Add to `.vscode/tasks.json`:
```json
{
    "label": "Submit HPC Basic Test",
    "type": "shell",
    "command": "python",
    "args": ["hpc/jobs/submission/submit_basic_test.py", "--mode", "quick", "--auto-collect"],
    "group": "test"
}
```

## 📞 Troubleshooting

### Common Issues
1. **SSH connection failed**: Check network and credentials
2. **Job submission failed**: Verify cluster availability with `squeue`
3. **No files collected**: Job may have failed early, check SLURM logs
4. **Permission denied**: Check file permissions on cluster

### Debug Commands
```bash
# Check cluster status
ssh scholten@falcon 'squeue -u scholten'

# Check disk space
ssh scholten@falcon 'df -h ~/globtim_hpc'

# View recent job logs
ssh scholten@falcon 'ls -lat ~/globtim_hpc/*.out | head -5'
```

## 🎯 Best Practices

1. **Always use test IDs** for better file organization
2. **Start with basic tests** before complex benchmarks
3. **Use auto-collect** for hands-off monitoring
4. **Check collected results** in local directories
5. **Monitor cluster resources** before submitting large jobs

## 📈 Future Enhancements

- [ ] Automatic dependency installation
- [ ] Integration with Deufhard benchmark suite
- [ ] Batch job submission for parameter sweeps
- [ ] Real-time result visualization
- [ ] Email notifications for job completion
