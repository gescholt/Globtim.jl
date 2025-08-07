# HPC Light 2D Testing Files Documentation

**Last Updated**: 2025-08-04
**Status**: ✅ HPC Infrastructure Working, 🔧 Package Dependencies Need Fix
**Next Action**: Resolve Globtim package dependencies for complete workflow

## 📋 Files Created for HPC --light 2D Testing

### 🎯 **Core Testing Files** (Keep Permanently)

#### 1. `Examples/hpc_light_2d_example.jl` ⭐ **CORE**
- **Purpose**: Complete 2D Globtim workflow with --light flag support
- **Features**: 
  - Full pipeline: polynomial fitting → critical points → refinement
  - Light mode (--light flag) for fastest execution
  - Standard mode for thorough testing
  - HPC-compatible (no visualization dependencies)
- **Status**: **KEEP** - This is the main working example
- **Consolidation**: Can become the standard 2D test after validation

#### 2. `hpc/config/Project_HPC.toml` ⭐ **CORE** 
- **Purpose**: Fixed HPC project dependencies
- **Changes Made**:
  - Added `JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"`
  - Added `UUIDs = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"`
- **Status**: **KEEP** - Essential fix for dependency issues
- **Consolidation**: Merge changes into main Project.toml after testing

### 🧪 **Testing & Validation Files** (Temporary)

#### 3. `Examples/hpc_robust_test_runner.jl` 🔧 **DIAGNOSTIC**
- **Purpose**: Comprehensive diagnostics and graceful degradation
- **Features**:
  - Environment diagnostics
  - Package availability checking
  - Safe Globtim loading with fallbacks
  - Basic math tests
- **Status**: **CONSOLIDATE** after success
- **Consolidation Plan**: Merge diagnostic functions into main test file

#### 4. `test_light_2d_example.slurm` 🔧 **SLURM JOB**
- **Purpose**: SLURM job script for running light 2D examples
- **Features**:
  - Tests both --light and standard modes
  - 10-minute time limit, 4GB memory
  - Proper Julia environment setup
- **Status**: **CONSOLIDATE** after success
- **Consolidation Plan**: Merge into standard SLURM template

### 🚀 **Pipeline & Automation Files** (Temporary)

#### 5. `run_hpc_light_pipeline.sh` 🔧 **AUTOMATION**
- **Purpose**: Complete pipeline runner with monitoring
- **Features**:
  - Cluster connection checking
  - Code synchronization
  - Job submission and monitoring
  - Result collection
- **Status**: **CONSOLIDATE** after success
- **Consolidation Plan**: Merge into existing HPC tools

#### 6. `validate_hpc_pipeline.sh` 🔧 **VALIDATION**
- **Purpose**: End-to-end pipeline validation
- **Features**:
  - Local setup validation
  - Cluster environment checking
  - Complete workflow testing
  - Validation report generation
- **Status**: **DISCARD** after successful validation
- **Reason**: One-time validation tool, not needed for production

## 📊 **Consolidation Strategy**

### Phase 1: Initial Testing (Current)
```
Examples/hpc_light_2d_example.jl          ← Test this first
test_light_2d_example.slurm               ← Run on cluster
Examples/hpc_robust_test_runner.jl        ← Fallback diagnostics
```

### Phase 2: After Successful Testing
```
Examples/globtim_2d_standard.jl           ← Consolidated from hpc_light_2d_example.jl
  ├─ Includes light mode (--light flag)
  ├─ Includes diagnostic functions from hpc_robust_test_runner.jl
  └─ Becomes the standard 2D test

globtim_standard.slurm                     ← Consolidated SLURM script
  ├─ Replaces test_light_2d_example.slurm
  └─ Becomes standard job template
```

### Phase 3: Production Ready
```
KEEP:
✅ Examples/globtim_2d_standard.jl         ← Single consolidated test file
✅ globtim_standard.slurm                  ← Single consolidated job script
✅ Updated Project.toml                    ← With JSON3/UUIDs dependencies

DISCARD:
❌ Examples/hpc_robust_test_runner.jl      ← Functions merged into standard
❌ test_light_2d_example.slurm             ← Replaced by standard
❌ run_hpc_light_pipeline.sh               ← Merge into existing tools
❌ validate_hpc_pipeline.sh                ← One-time use only
```

## 🎯 **Immediate Next Steps**

### 1. Test Core Functionality
```bash
# Test the main example locally first
julia --project=. Examples/hpc_light_2d_example.jl --light

# Then test on cluster
./validate_hpc_pipeline.sh quick
```

### 2. After Successful Testing
```bash
# Consolidate into single standard file
cp Examples/hpc_light_2d_example.jl Examples/globtim_2d_standard.jl
# Add diagnostic functions from hpc_robust_test_runner.jl
# Update documentation

# Clean up temporary files
rm Examples/hpc_robust_test_runner.jl
rm test_light_2d_example.slurm  
rm run_hpc_light_pipeline.sh
rm validate_hpc_pipeline.sh
```

### 3. Integration with Existing Infrastructure
```bash
# Merge dependency fixes
# Update existing SLURM templates
# Update documentation
# Add to standard test suite
```

## 📈 **Success Metrics**

### ✅ **Ready for Consolidation When:**
- [ ] `Examples/hpc_light_2d_example.jl` runs successfully locally
- [ ] SLURM job completes without errors on cluster
- [ ] Complete workflow executes: polynomial → critical points → refinement
- [ ] Both --light and standard modes work
- [ ] No dependency errors (JSON3, UUIDs resolved)

### 🎉 **Ready for Production When:**
- [ ] Consolidated file works in all scenarios
- [ ] Integrated with existing monitoring tools
- [ ] Documentation updated
- [ ] Temporary files removed
- [ ] Standard test suite includes 2D --light example

## 🔧 **File Dependencies**

```
hpc/config/Project_HPC.toml (FIXED)
    ↓
Examples/hpc_light_2d_example.jl (CORE)
    ↓
test_light_2d_example.slurm (TEMPORARY)
    ↓
validate_hpc_pipeline.sh (TEMPORARY)
```

**Bottom Line**: After successful testing, we can consolidate 6 files into 2 production files, keeping the core functionality while removing temporary scaffolding.

## 🗂️ **File Organization & Maintenance Workflow**

### **Current File Status (2025-08-04)**

#### ✅ **WORKING FILES** (Keep & Maintain)
```
Examples/hpc_standalone_test.jl               ← ✅ WORKS: Core Julia functionality test
run_custom_hpc_test.sh                        ← ✅ WORKS: Flexible HPC job runner
hpc/config/Project_HPC.toml                   ← ✅ FIXED: JSON3 dependency removed
```

#### 🔧 **NEEDS FIXING** (Priority)
```
Examples/hpc_light_2d_example.jl              ← 🔧 BLOCKED: Package dependency issues
Examples/hpc_no_json3_example.jl              ← 🔧 BLOCKED: Package installation timeout
Examples/hpc_minimal_2d_example.jl            ← 🔧 BLOCKED: Same package issues
```

#### 📊 **TEST RESULTS** (Archive & Track)
```
hpc_results/
├── light_2d_test_20250804_115607/            ← JSON3 dependency error
├── minimal_2d_test_20250804_115758/          ← JSON3 dependency error
├── no_json3_test_20250804_120358/            ← Package installation timeout
└── standalone_test_20250804_142659/          ← ✅ SUCCESS: Core Julia works
```

#### ❌ **TEMPORARY/OBSOLETE** (Clean Up)
```
test_light_2d_example.slurm                   ← Replace with run_custom_hpc_test.sh
run_hpc_light_pipeline.sh                     ← Redundant with run_custom_hpc_test.sh
validate_hpc_pipeline.sh                      ← One-time use, can archive
Examples/hpc_robust_test_runner.jl            ← Merge functions into working files
```

### **📋 Maintenance Workflow**

#### **Weekly File Review**
```bash
# 1. Check for orphaned files
find . -name "*.jl" -not -path "./src/*" -not -path "./Examples/*" -not -path "./test/*"
find . -name "*.slurm" -not -path "./hpc/*"
find . -name "custom_*" -mtime +7  # Files older than 7 days

# 2. Archive old test results
mkdir -p hpc_results/archive/$(date +%Y%m)
mv hpc_results/*_$(date -d '1 month ago' +%Y%m)* hpc_results/archive/$(date +%Y%m)/ 2>/dev/null || true

# 3. Clean up temporary files
rm -f custom_*.out custom_*.err *.slurm.tmp
```

#### **Monthly Consolidation**
```bash
# 1. Review and consolidate working examples
# 2. Update documentation with current status
# 3. Archive old test results (keep last 3 months)
# 4. Remove obsolete files after confirmation
```

### **🎯 File Lifecycle Management**

#### **Phase 1: Development**
- Create in `Examples/` with descriptive names
- Test with `run_custom_hpc_test.sh`
- Document in this file with status

#### **Phase 2: Testing**
- Results go to `hpc_results/test_name_YYYYMMDD_HHMMSS/`
- Track success/failure in this documentation
- Keep detailed logs for debugging

#### **Phase 3: Production**
- Move working files to appropriate directories
- Update main documentation
- Remove temporary/development files

#### **Phase 4: Archive**
- Old test results → `hpc_results/archive/YYYYMM/`
- Obsolete files → `archive/obsolete/YYYYMMDD/`
- Keep documentation trail

### **🚨 Cleanup Rules**

#### **NEVER DELETE**
- `src/` directory contents
- Working production files
- Current month's test results
- Files referenced in active documentation

#### **SAFE TO DELETE** (After 30 days)
- `custom_*.out`, `custom_*.err` files
- Temporary `.slurm` files
- Failed test results older than 30 days
- Development files marked as obsolete

#### **ASK BEFORE DELETING**
- Any `.jl` file in `Examples/`
- Configuration files
- Scripts with `chmod +x`
- Files larger than 1MB

### **📁 Recommended Directory Structure**

```
globtim/
├── Examples/
│   ├── production/              ← Working, tested examples
│   ├── development/             ← In-progress examples
│   └── archive/                 ← Old/obsolete examples
├── hpc_results/
│   ├── current/                 ← Last 30 days
│   └── archive/                 ← Older results by month
├── hpc/
│   ├── config/                  ← Configuration files
│   ├── scripts/                 ← Production HPC scripts
│   └── monitoring/              ← Monitoring tools
└── docs/
    ├── hpc/                     ← HPC-specific documentation
    └── maintenance/             ← Maintenance procedures
```

## 🎯 **Current Status & Next Actions**

### **✅ CONFIRMED WORKING (2025-08-04)**
1. **HPC Infrastructure**: ✅ SLURM, Julia 1.11.2, 405GB memory
2. **Core Julia**: ✅ All mathematical operations working perfectly
3. **Job Submission**: ✅ `run_custom_hpc_test.sh` works reliably
4. **Result Collection**: ✅ Automatic download and organization
5. **Performance**: ✅ Matrix operations, eigenvalues, file I/O

### **🔧 BLOCKING ISSUES**
1. **Package Dependencies**: Globtim package installation fails/times out
2. **JSON3 Dependency**: Removed from config but still referenced somewhere
3. **Installation Timeout**: `Pkg.instantiate()` takes >10 minutes

### **📋 IMMEDIATE NEXT STEPS**

#### **Priority 1: Fix Package Dependencies**
```bash
# Option A: Create minimal Globtim environment
# Option B: Use system-wide Julia packages
# Option C: Pre-compile packages in shared location
```

#### **Priority 2: Clean Up Current Files**
```bash
# Move working files to production
mv Examples/hpc_standalone_test.jl Examples/production/
mv run_custom_hpc_test.sh hpc/scripts/

# Archive obsolete files
mkdir -p archive/obsolete/20250804
mv test_light_2d_example.slurm archive/obsolete/20250804/
mv run_hpc_light_pipeline.sh archive/obsolete/20250804/
mv validate_hpc_pipeline.sh archive/obsolete/20250804/
```

#### **Priority 3: Create Production Workflow**
```bash
# Test package dependency fixes
./run_custom_hpc_test.sh Examples/production/globtim_2d_test.jl --light

# Document successful workflow
# Update main project documentation
```

### **🎯 SUCCESS CRITERIA**

#### **Short Term (This Week)**
- [ ] Resolve Globtim package dependencies
- [ ] Complete --light 2D example runs successfully
- [ ] Clean file organization implemented
- [ ] Documentation updated

#### **Medium Term (This Month)**
- [ ] Production 2D workflow established
- [ ] Automated maintenance scripts
- [ ] Integration with existing HPC tools
- [ ] Benchmark infrastructure working

#### **Long Term (Next Quarter)**
- [ ] Full 4D benchmark suite on HPC
- [ ] Automated result analysis
- [ ] Production deployment procedures
- [ ] Comprehensive monitoring

### **📞 CONTACT FOR ISSUES**
- **Package Dependencies**: Check with cluster admin about Julia package cache
- **File Organization**: Follow maintenance workflow above
- **HPC Issues**: Use existing monitoring tools in `hpc/monitoring/`

---
**Last Updated**: 2025-08-04
**Next Review**: 2025-08-11
**Maintainer**: Update this documentation when making changes
