# Conditional Loading for HPC - NO FALLBACKS POLICY

**Date**: August 11, 2025  
**Policy**: **FALLBACK PROCEDURES ARE FORBIDDEN**  
**Approach**: Detection, Reporting, and Graceful Failure Only

## 🚫 CRITICAL POLICY: NO FALLBACKS ALLOWED

**Fallback procedures are strictly forbidden.** The conditional loading system must:

- ✅ **Detect** package availability accurately
- ✅ **Report** missing dependencies clearly  
- ✅ **Fail gracefully** with actionable error messages
- ❌ **NO fallback implementations**
- ❌ **NO alternative code paths**
- ❌ **NO workarounds for missing packages**

## 🎯 Conditional Loading Purpose

The conditional loading system serves **detection and reporting only**:

### **Primary Functions:**
1. **Environment Detection**: Identify login vs compute nodes
2. **Package Availability Assessment**: Check which packages are installed
3. **Dependency Validation**: Verify all required packages are present
4. **Clear Error Reporting**: Provide specific instructions for fixing issues
5. **Graceful Failure**: Exit cleanly with helpful error messages

### **Explicitly Forbidden:**
1. **Fallback Implementations**: No alternative algorithms or methods
2. **Workaround Code**: No "Plan B" when packages are missing
3. **Degraded Functionality**: No reduced-feature modes
4. **Silent Failures**: No continuing with missing critical dependencies

## 🏗️ Implementation Architecture

### **ConditionalLoading.jl Module**

**Core Functions:**
- `has_package(package_name)` → Boolean detection only
- `conditional_load(packages...)` → Load or fail, no alternatives
- `check_globtim_dependencies()` → Comprehensive status report
- `get_environment_info()` → Environment detection and reporting

**Key Principles:**
- **Fail Fast**: Exit immediately when critical packages missing
- **Clear Messages**: Specific instructions for resolving issues
- **No Workarounds**: Never provide alternative implementations

### **Test Suite: runtests_hpc.jl**

**Testing Strategy:**
- **Environment Reporting**: Show exactly what's available
- **Package Detection**: List all missing dependencies
- **Clear Status**: Report ready/not-ready status definitively
- **Installation Instructions**: Provide exact commands to fix issues

## 📊 Expected Behavior

### **When All Packages Available:**
```
🎉 OVERALL STATUS: READY FOR GLOBTIM WORKLOADS
   All core dependencies available, full functionality expected.
```

### **When Packages Missing:**
```
❌ OVERALL STATUS: CRITICAL DEPENDENCIES MISSING
   Core dependencies missing - NO FALLBACKS AVAILABLE
   REQUIRED ACTION: Install missing packages with:
   julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
   System cannot operate without proper package installation.
```

## 🔧 Usage Examples

### **Correct Usage - Detection Only:**
```julia
using .ConditionalLoading

# Check if package is available
if ConditionalLoading.has_package("StaticArrays")
    using StaticArrays
    # Use StaticArrays normally
else
    error("StaticArrays required - install with Pkg.add(\"StaticArrays\")")
end
```

### **Forbidden Usage - Fallbacks:**
```julia
# ❌ FORBIDDEN - DO NOT DO THIS
if ConditionalLoading.has_package("StaticArrays")
    using StaticArrays
    result = SVector(1, 2, 3)
else
    # ❌ NO FALLBACKS ALLOWED
    result = [1, 2, 3]  # This is forbidden!
end
```

## 🎯 HPC Cluster Integration

### **Environment-Specific Behavior:**

**Login Nodes:**
- Use NFS depot with full package availability
- Report comprehensive package status
- Provide installation instructions if needed

**Compute Nodes:**
- Use local depot (may have limited packages)
- Detect missing packages immediately
- Fail fast with clear error messages
- NO fallback computations allowed

### **SLURM Job Integration:**
- Detect SLURM environment automatically
- Report job ID, node, and resource allocation
- Validate package availability before computation
- Exit with appropriate error codes

## 📋 Implementation Status

### **✅ Completed:**
- ConditionalLoading.jl module (no fallbacks)
- HPC test suite (detection only)
- Environment detection (login/compute nodes)
- Package availability assessment
- Clear error reporting
- SLURM integration

### **🔧 Integration Points:**
- Main Globtim modules should use conditional loading for detection
- All computational code should require proper packages
- No alternative algorithms or fallback methods
- Clear error messages when dependencies missing

## 🚀 Production Deployment

### **Deployment Strategy:**
1. **Install conditional loading module** on HPC cluster
2. **Update main Globtim code** to use detection functions
3. **Remove any existing fallback code** from codebase
4. **Test package installation procedures** on compute nodes
5. **Document exact installation commands** for users

### **User Instructions:**
When packages are missing, users must:
1. **Install missing packages** using provided commands
2. **Verify installation** with test suite
3. **Re-run computations** with full package availability
4. **NO workarounds or fallbacks** are available

## ⚠️ Critical Reminders

### **For Developers:**
- **Never implement fallbacks** - this is strictly forbidden
- **Always fail fast** when packages are missing
- **Provide clear error messages** with exact fix instructions
- **Test both success and failure paths** thoroughly

### **For Users:**
- **Install all required packages** before running computations
- **No reduced functionality modes** are available
- **Follow exact installation instructions** when packages missing
- **Contact support** if package installation fails

## 🎉 Benefits of No-Fallback Policy

### **Reliability:**
- **Consistent behavior** across all environments
- **No hidden failures** or degraded performance
- **Clear success/failure states** with no ambiguity

### **Maintainability:**
- **Single code path** - no complex fallback logic
- **Easier debugging** - failures are explicit
- **Simpler testing** - only one behavior to validate

### **User Experience:**
- **Clear error messages** with actionable instructions
- **No mysterious performance degradation** from fallbacks
- **Predictable behavior** - works fully or fails clearly

---

**SUMMARY: Conditional loading provides detection and reporting only. NO FALLBACKS ARE ALLOWED. System must work fully with proper packages or fail clearly with installation instructions.**
