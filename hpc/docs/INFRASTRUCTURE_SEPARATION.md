# HPC Infrastructure Separation Guide

## 🎯 Overview

This document describes the clean separation between technical SLURM infrastructure code and actual test/benchmark code in the Globtim HPC system.

**Status**: COMPLETE ✅  
**Architecture**: Modular, reusable infrastructure with clean interfaces

## 🏗️ Architecture Separation

### **Layer 1: Technical Infrastructure**
```
hpc/jobs/submission/
├── slurm_infrastructure.py     # Core SLURM management
├── run_tests.py               # Clean test runner interface
└── cleanup_globtim_hpc.py     # Maintenance and organization
```

### **Layer 2: Test Implementation**
```
hpc/jobs/submission/
├── test_deuflhard_simple.py   # Deuflhard benchmark (working)
├── submit_basic_test.py       # Basic functionality tests
└── [other specific tests]     # Additional benchmark tests
```

### **Layer 3: User Interface**
```
# Simple command-line interface
python run_tests.py deuflhard --config quick
python run_tests.py basic --config standard
python run_tests.py custom --julia-code "..." --name my_test
```

## 🔧 Technical Infrastructure Components

### **SLURMJobManager Class**
**Purpose**: Handles all SLURM-specific functionality
**Responsibilities**:
- Job submission and management
- Standard configuration templates
- Output directory creation
- Job monitoring and status checking

**Key Features**:
- Standardized SLURM headers and footers
- Quota-aware file handling (uses `/tmp` for scripts)
- Configurable resource templates (quick, standard, extended, bigmem)
- Automatic environment setup (Julia depot, threads, etc.)

### **TestJobBuilder Class**
**Purpose**: Builds specific types of test jobs
**Responsibilities**:
- Julia test job creation
- Package and module loading
- Test-specific job content generation

**Key Features**:
- Automatic package loading with error handling
- Module inclusion support
- Standardized test structure
- Reusable job templates

## 📋 Standard Configurations

### **Resource Templates**
```python
"quick": {
    "time_limit": "00:30:00",
    "memory": "8G", 
    "cpus": 4,
    "partition": "batch"
}

"standard": {
    "time_limit": "02:00:00",
    "memory": "16G",
    "cpus": 8, 
    "partition": "batch"
}

"extended": {
    "time_limit": "04:00:00",
    "memory": "32G",
    "cpus": 16,
    "partition": "batch"
}

"bigmem": {
    "time_limit": "08:00:00",
    "memory": "64G",
    "cpus": 8,
    "partition": "bigmem"
}
```

## 🚀 Usage Examples

### **1. Using the Infrastructure Directly**
```python
from slurm_infrastructure import SLURMJobManager, TestJobBuilder

# Create manager and builder
manager = SLURMJobManager()
builder = TestJobBuilder(manager)

# Submit Deuflhard test
job_id, test_id = builder.submit_deuflhard_test("quick")
```

### **2. Using the Clean Interface**
```bash
# Run Deuflhard benchmark
python run_tests.py deuflhard --config quick

# Run basic functionality test
python run_tests.py basic --config standard

# Run custom Julia code
python run_tests.py custom --julia-code "println('Hello HPC')" --name my_test

# Monitor a job
python run_tests.py monitor 12345

# List available configurations
python run_tests.py configs
```

### **3. Using Convenience Functions**
```python
from slurm_infrastructure import submit_deuflhard_test, submit_basic_test

# Quick submission
job_id, test_id = submit_deuflhard_test("quick")
job_id, test_id = submit_basic_test("standard")
```

## 🔄 Working vs. Development Approaches

### **Production Approach (Working)**
```python
# Use the proven simple approach for reliable results
python test_deuflhard_simple.py --mode quick
```
- ✅ **Proven reliability** - tested and working
- ✅ **Direct SSH execution** - no complex SLURM script generation
- ✅ **Quota workaround** - uses `/tmp` for all file operations
- ✅ **Immediate results** - fast execution and feedback

### **Infrastructure Approach (Development)**
```python
# Use the modular infrastructure for development and scaling
python run_tests.py deuflhard --config quick
```
- 🔄 **Under development** - shell escaping issues being resolved
- 🔄 **SLURM integration** - proper job submission workflow
- 🔄 **Modular design** - reusable components
- 🔄 **Scalable architecture** - supports complex workflows

## 📊 Benefits of Separation

### **For Developers**
- **Clean interfaces** - easy to use without SLURM knowledge
- **Reusable components** - write once, use everywhere
- **Standardized configurations** - consistent resource allocation
- **Error handling** - built-in error checking and reporting

### **For System Administrators**
- **Centralized SLURM logic** - easier to maintain and update
- **Quota management** - built-in workarounds for storage limitations
- **Resource templates** - standardized resource allocation
- **Monitoring integration** - consistent job tracking

### **For Researchers**
- **Focus on science** - write Julia code, not SLURM scripts
- **Consistent environments** - same setup across all tests
- **Easy scaling** - change configuration, not code
- **Reliable execution** - proven infrastructure patterns

## 🛠️ Maintenance and Extension

### **Adding New Test Types**
1. **Create test-specific function** in `TestJobBuilder`
2. **Add command-line option** in `run_tests.py`
3. **Document usage** in this guide

### **Adding New Configurations**
1. **Add to `standard_configs`** in `SLURMJobManager`
2. **Update command-line choices** in `run_tests.py`
3. **Test with existing jobs**

### **Troubleshooting**
- **Shell escaping issues**: Use the proven simple approach for complex Julia code
- **Quota problems**: Infrastructure automatically uses `/tmp` for temporary files
- **Job failures**: Check SLURM logs in the results directory

## 📋 Current Status

### **Working Components** ✅
- ✅ **Core infrastructure classes** - `SLURMJobManager`, `TestJobBuilder`
- ✅ **Simple test approach** - `test_deuflhard_simple.py` working perfectly
- ✅ **Quota workarounds** - `/tmp` usage for file operations
- ✅ **Clean interfaces** - command-line and programmatic access

### **In Development** 🔄
- 🔄 **Complex SLURM script generation** - shell escaping issues
- 🔄 **Full infrastructure integration** - combining modular components
- 🔄 **Advanced job monitoring** - automated result collection

### **Recommended Usage**
For **immediate needs**: Use `test_deuflhard_simple.py` (proven, reliable)
For **development**: Use the infrastructure components (modular, scalable)
For **production**: Combine both approaches as needed

## 🎯 Future Improvements

1. **Resolve shell escaping** in complex SLURM script generation
2. **Add automated monitoring** with result collection
3. **Integrate with fileserver** for persistent storage
4. **Create web dashboard** for job management
5. **Add performance profiling** and optimization tools

This separation provides a solid foundation for scalable, maintainable HPC workflows while maintaining the reliability of proven approaches.
