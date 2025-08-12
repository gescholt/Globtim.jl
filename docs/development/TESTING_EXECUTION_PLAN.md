# Julia HPC Migration - Comprehensive Testing Execution Plan

**Date**: August 11, 2025  
**Objective**: Systematically validate Julia HPC migration with core Globtim functionality and workflow testing

## 🎯 Testing Strategy Overview

### **Primary Objective**
Verify that the migrated Julia HPC infrastructure works correctly with both existing submission scripts and the core Globtim test suite.

### **Testing Priorities**
1. **Core Validation**: Run Globtim test suite (`test/runtests.jl`) on HPC cluster
2. **Workflow Validation**: Test updated submission scripts end-to-end
3. **Performance Validation**: Measure and compare performance metrics
4. **Output Analysis**: Systematic analysis of all test results

## 📋 Step-by-Step Execution Plan

### **Phase 1: Pre-flight Preparation**

#### Step 1.1: Update Remaining Scripts
```bash
# Update scripts that still use old depot configuration
cd /Users/ghscholt/globtim
python3 hpc/testing/update_remaining_scripts.py --dry-run
python3 hpc/testing/update_remaining_scripts.py  # Apply updates
```

**Expected Outcome**: All submission scripts use NFS configuration
**Success Criteria**: 
- ✅ `submit_globtim_compilation_test.py` uses `source ./setup_nfs_julia.sh`
- ✅ `submit_basic_test.py` uses `source ./setup_nfs_julia.sh`
- ❌ No scripts use old depot paths (`/tmp/julia_depot_globtim_persistent`, `$HOME/globtim_hpc/.julia`)

#### Step 1.2: Infrastructure Status Check
```bash
# Verify basic infrastructure is operational
python3 hpc/testing/comprehensive_hpc_test.py --test-type infrastructure
```

**Expected Outcome**: All infrastructure components operational
**Success Criteria**:
- ✅ SSH connectivity to HPC cluster working
- ✅ NFS depot accessible with packages
- ✅ Julia available and functional
- ✅ `setup_nfs_julia.sh` script working correctly

### **Phase 2: Core Validation Testing**

#### Step 2.1: Globtim Test Suite Execution
```bash
# Run Globtim test suite on HPC cluster (PRIMARY TEST)
python3 hpc/testing/globtim_test_suite_hpc.py --monitor --timeout 45
```

**Expected Outcome**: Globtim test suite passes completely on HPC cluster
**Success Criteria**:
- ✅ Job submits successfully to SLURM
- ✅ Julia environment configures correctly with NFS depot
- ✅ All Globtim tests pass (`test/runtests.jl` exits with code 0)
- ✅ No package loading errors or missing dependencies
- ✅ Computation and optimization functions work correctly

**Critical Analysis Points**:
- **Package Loading**: Verify all required packages load from NFS depot
- **Test Execution**: Check that all individual tests within the suite pass
- **Performance**: Ensure reasonable execution times (< 30 minutes)
- **Error Patterns**: Look for any Julia-specific errors or warnings

#### Step 2.2: Alternative Test Approach (if Step 2.1 fails)
```bash
# If full test suite fails, run targeted component tests
python3 hpc/testing/globtim_test_suite_hpc.py --submit-only
# Then manually check specific components
```

### **Phase 3: Workflow Validation Testing**

#### Step 3.1: Updated Submission Scripts Testing
```bash
# Test all updated submission scripts
python3 hpc/testing/comprehensive_hpc_test.py --test-type scripts
```

**Expected Outcome**: All submission scripts work with NFS configuration
**Success Criteria**:
- ✅ `submit_simple_julia_test.py` submits and completes successfully
- ✅ `submit_deuflhard_hpc.py --mode quick` submits and completes successfully
- ✅ All scripts use NFS depot configuration correctly
- ✅ Job outputs show successful Julia environment setup

#### Step 3.2: Individual Script Validation
```bash
# Test each critical script individually
cd hpc/jobs/submission

# Test 1: Simple Julia test
python3 submit_simple_julia_test.py

# Test 2: Deuflhard benchmark (quick mode)
python3 submit_deuflhard_hpc.py --mode quick

# Test 3: Updated compilation test
python3 submit_globtim_compilation_test.py --mode quick --function deuflhard
```

**Expected Outcome**: Each script completes successfully
**Success Criteria**:
- ✅ Jobs submit without errors
- ✅ SLURM job IDs returned
- ✅ Jobs complete within expected timeframes
- ✅ Output files contain expected success messages

### **Phase 4: Performance and Output Analysis**

#### Step 4.1: Performance Metrics Collection
```bash
# Run performance monitoring
cd /Users/ghscholt/globtim
./monitoring/performance_monitor.sh monitor
```

**Expected Outcome**: Performance metrics within acceptable ranges
**Success Criteria**:
- ✅ Julia startup time < 2 seconds
- ✅ Package loading time < 5 seconds
- ✅ NFS depot accessible and responsive
- ✅ No quota-related issues

#### Step 4.2: Output Analysis Framework

**For Each Test, Analyze**:

1. **Infrastructure Success Indicators**:
   - ✅ `"✅ NFS Julia depot configured"` in output
   - ✅ `"✅ Pkg loaded successfully"` in output
   - ✅ No `"❌"` error indicators
   - ✅ Exit code 0 for Julia processes

2. **Globtim-Specific Success Indicators**:
   - ✅ `"Test Summary:"` section shows all tests passed
   - ✅ No `"ERROR: LoadError:"` messages
   - ✅ No package loading failures
   - ✅ Optimization functions execute correctly

3. **Performance Success Indicators**:
   - ✅ Job completion time < 30 minutes for test suite
   - ✅ Job completion time < 5 minutes for simple tests
   - ✅ Memory usage within allocated limits
   - ✅ No timeout errors

4. **Error Pattern Detection**:
   - ❌ `"Package not found"` → Package installation issue
   - ❌ `"BoundsError"` → Computation error
   - ❌ `"MethodError"` → API compatibility issue
   - ❌ `"quota exceeded"` → Storage configuration issue

## 🔍 Detailed Success/Failure Criteria

### **OVERALL SUCCESS** (Migration Validated)
- ✅ Globtim test suite passes completely on HPC cluster
- ✅ All updated submission scripts work correctly
- ✅ Performance metrics within acceptable ranges
- ✅ No quota-related errors
- ✅ NFS depot fully functional

### **PARTIAL SUCCESS** (Issues to Address)
- ⚠️ Globtim test suite passes with minor warnings
- ⚠️ Some submission scripts work, others need fixes
- ⚠️ Performance acceptable but not optimal
- ⚠️ Minor configuration issues detected

### **FAILURE** (Migration Issues)
- ❌ Globtim test suite fails to run or complete
- ❌ Multiple submission scripts fail
- ❌ NFS depot inaccessible or corrupted
- ❌ Quota issues persist
- ❌ Julia environment not working correctly

## 📊 Results Documentation

### **For Each Test Phase**:
1. **Capture Complete Output**: Save all SLURM job outputs and error files
2. **Document Timing**: Record start/end times and duration
3. **Analyze Exit Codes**: Document all return codes and their meanings
4. **Screenshot Key Results**: Capture terminal output for critical tests
5. **Create Summary Report**: Generate structured analysis of results

### **Final Validation Report Structure**:
```
JULIA HPC MIGRATION - VALIDATION RESULTS
========================================
Date: [timestamp]
Test ID: [unique_id]

PHASE 1 - PRE-FLIGHT: [PASS/FAIL]
- Script Updates: [status]
- Infrastructure Check: [status]

PHASE 2 - CORE VALIDATION: [PASS/FAIL]  
- Globtim Test Suite: [status]
- Error Analysis: [details]

PHASE 3 - WORKFLOW VALIDATION: [PASS/FAIL]
- Submission Scripts: [status]
- Individual Tests: [status]

PHASE 4 - PERFORMANCE: [PASS/FAIL]
- Metrics Collection: [status]
- Analysis Results: [details]

OVERALL ASSESSMENT: [SUCCESS/PARTIAL/FAILURE]
RECOMMENDATIONS: [action items]
```

## 🚀 Execution Commands Summary

```bash
# Complete testing sequence
cd /Users/ghscholt/globtim

# Phase 1: Preparation
python3 hpc/testing/update_remaining_scripts.py
python3 hpc/testing/comprehensive_hpc_test.py --test-type infrastructure

# Phase 2: Core validation (CRITICAL)
python3 hpc/testing/globtim_test_suite_hpc.py --monitor --timeout 45

# Phase 3: Workflow validation
python3 hpc/testing/comprehensive_hpc_test.py --test-type scripts

# Phase 4: Performance analysis
./monitoring/performance_monitor.sh monitor
```

## 📋 Next Steps After Testing

### **If All Tests Pass**:
1. Document successful migration completion
2. Update team on validated infrastructure
3. Create user guides for new workflow
4. Schedule regular monitoring

### **If Issues Found**:
1. Document specific failures and error patterns
2. Prioritize issues by severity and impact
3. Create targeted fixes for identified problems
4. Re-run affected tests after fixes
5. Update migration documentation with lessons learned

---

**This testing plan provides systematic validation of the Julia HPC migration with clear success criteria and comprehensive output analysis.**
