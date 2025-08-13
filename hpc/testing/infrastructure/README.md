# GlobTim HPC Testing Infrastructure

## 📊 **Current Status**

**✅ Python Infrastructure**: Complete and operational
**⚠️ Julia Workflow**: Implementation needed

## Overview

A comprehensive Python-based testing framework for automated submission, monitoring, and analysis of GlobTim HPC jobs. The Python foundation is complete and working; Julia computational workflow implementation is the next priority.

## 🏗️ **Implementation Status**

### **✅ Working Foundation**
- **Python 3.10.7**: Operational on HPC cluster
- **SSH Authentication**: Integrated with three-tier architecture
- **SLURM Integration**: Job submission and monitoring tested
- **Dependency Management**: PyYAML and required packages working

### **⚠️ Needs Implementation**
- **Julia Deployment**: Adapt Python scripts for Julia codebase
- **Job Submission**: Create Julia-specific job submission system
- **Results Collection**: Implement structured results management

**See**: `../IMPLEMENTATION_STATUS.md` for detailed roadmap

## Architecture

```
hpc/testing/
├── QUICKSTART.md               # Updated usage guide
├── IMPLEMENTATION_STATUS.md    # Current status and roadmap
├── python_dependency_tests/    # ✅ Working Python infrastructure
├── infrastructure/             # Core framework (this directory)
│   ├── core/
│   │   ├── job_manager.py     # Job submission and tracking
│   │   ├── monitor.py         # Real-time monitoring
│   │   ├── analyzer.py        # Result analysis
│   │   └── reporter.py        # Report generation
│   ├── templates/
│   │   ├── base_job.slurm     # Base SLURM template
│   │   └── [job templates]    # Various job templates
│   └── config/
│       ├── settings.yaml      # Configuration
│       └── test_suites.yaml   # Test suite definitions
├── results/                   # Test results storage
├── logs/                       # Execution logs
└── reports/                    # Generated reports

```

## Features

### 1. **Job Management**
- Automated SLURM job submission
- Template-based job generation
- Dependency management
- Job queuing and scheduling

### 2. **Monitoring**
- Real-time job status tracking
- Resource usage monitoring
- Error detection and alerting
- Progress visualization

### 3. **Analysis**
- Automated result collection
- Performance metrics extraction
- Regression detection
- Statistical analysis

### 4. **Reporting**
- HTML/Markdown report generation
- Performance dashboards
- Trend analysis
- Email notifications

## Usage

### Quick Start
```python
from hpc_testing import TestSuite, JobManager

# Initialize test suite
suite = TestSuite("globtim_daily")
suite.add_benchmark("deuflhard", iterations=10)
suite.add_test("package_loading")

# Run suite
manager = JobManager()
results = manager.run_suite(suite)

# Generate report
results.generate_report("html")
```

### Command Line Interface
```bash
# Run specific test
python -m hpc_testing run --test deuflhard_benchmark

# Run test suite
python -m hpc_testing suite --name regression_tests

# Monitor running jobs
python -m hpc_testing monitor --watch

# Generate report
python -m hpc_testing report --format html --output results.html
```

## Test Types

### 1. **Unit Tests**
- Package loading
- Function correctness
- Module imports

### 2. **Integration Tests**
- Multi-component workflows
- End-to-end scenarios
- Data pipeline validation

### 3. **Performance Benchmarks**
- Execution time
- Memory usage
- Scaling tests
- Regression detection

### 4. **Stress Tests**
- Large problem sizes
- Long-running jobs
- Resource limits

## Configuration

### settings.yaml
```yaml
cluster:
  name: falcon
  user: scholten
  account: mpi
  partition: batch

paths:
  bundle: /home/scholten/globtim_hpc_bundle.tar.gz
  work_dir: /tmp/globtim_test
  results: /home/scholten/test_results

monitoring:
  interval: 10  # seconds
  timeout: 7200  # 2 hours max
  
notifications:
  email: user@example.com
  slack_webhook: https://...
```

## Metrics Tracked

- **Performance**: Runtime, speedup, efficiency
- **Resources**: CPU usage, memory, disk I/O
- **Reliability**: Success rate, error frequency
- **Scalability**: Weak/strong scaling
- **Regression**: Performance changes over time