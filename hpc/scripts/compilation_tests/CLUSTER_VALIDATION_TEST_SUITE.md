# Globtim Cluster Validation Test Suite

## 🎯 **Current Status Summary**

### ✅ **Successfully Completed**
- **Package Installation**: All critical packages installed on fileserver
  - CSV ✅, DataFrames ✅, Parameters ✅, ForwardDiff ✅, TOML ✅, StaticArrays ✅, Distributions ✅
- **Memory-Efficient Installation**: Used staged approach to avoid cluster memory overload
- **Source Code Access**: All Globtim source files accessible on cluster
- **Basic Infrastructure**: Compilation test framework deployed and functional

### ❌ **Critical Issues Identified**

1. **Package Access from Compute Nodes**
   - Packages installed in fileserver depot: `/net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot`
   - Compute nodes cannot access fileserver depot via NFS
   - Packages not available during job execution

2. **PrecisionType Loading Error**
   - `Structures.jl` fails with `UndefVarError(:PrecisionType, Main)`
   - Indicates missing `PrecisionTypes.jl` loading or module order issue

3. **Julia Environment Isolation**
   - Compute nodes use temporary depot instead of shared depot
   - No package persistence between jobs

## 🧪 **Validation Test Suite Design**

### **Test Categories**

#### **Level 1: Infrastructure Tests**
- [x] Cluster SSH access
- [x] Julia availability (1.11.2)
- [x] Source file access
- [x] Job submission system
- [ ] **NFS depot access from compute nodes**
- [ ] **Package depot synchronization**

#### **Level 2: Package Availability Tests**
- [x] Package installation on fileserver
- [ ] **Package access from compute nodes**
- [ ] **Package loading verification**
- [ ] **Dependency resolution**

#### **Level 3: Globtim Functionality Tests**
- [ ] **PrecisionTypes.jl loading**
- [ ] **Structures.jl compilation**
- [ ] **Core module loading**
- [ ] **Benchmark function access**
- [ ] **End-to-end workflow execution**

#### **Level 4: Performance and Integration Tests**
- [ ] **Multi-threading functionality**
- [ ] **Memory usage validation**
- [ ] **Computational performance**
- [ ] **Result output and collection**

### **Automated Test Scripts**

#### **1. Package Access Validation**
```bash
# Location: hpc/scripts/compilation_tests/validate_package_access.sh
./validate_package_access.sh --mode [quick|standard|thorough]
```

#### **2. Globtim Module Loading Test**
```bash
# Location: hpc/scripts/compilation_tests/validate_globtim_modules.sh
./validate_globtim_modules.sh --test-precision-types
```

#### **3. End-to-End Workflow Test**
```bash
# Location: hpc/scripts/compilation_tests/validate_full_workflow.sh
./validate_full_workflow.sh --function trefethen_3_8 --samples 50
```

## 🔧 **Required Actions from User**

### **Priority 1: CRITICAL - Package Access**

**Issue**: Compute nodes cannot access fileserver Julia depot

**Possible Solutions** (choose one):

#### **Option A: Fix NFS Mount Access**
```bash
# Test NFS access from compute node
ssh scholten@falcon 'srun --partition=batch --time=5:00 --pty bash -c "
  ls -la /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot
"'
```

#### **Option B: Copy Packages to Cluster Storage**
```bash
# Copy depot to cluster-accessible location
ssh scholten@falcon '
  mkdir -p ~/julia_cluster_depot
  rsync -av /net/fileserver-nfs/stornext/snfs6/projects/scholten/globtim/julia_hpc_depot/ ~/julia_cluster_depot/
'
```

#### **Option C: Install Packages Directly on Cluster**
```bash
# Install packages in cluster-accessible location
ssh scholten@falcon 'cd ~/globtim_hpc && julia --project=. -e "
  using Pkg
  Pkg.add([\"CSV\", \"DataFrames\", \"Parameters\", \"ForwardDiff\", \"StaticArrays\", \"Distributions\"])
"'
```

### **Priority 2: HIGH - PrecisionType Issue**

**Issue**: `UndefVarError(:PrecisionType, Main)` in Structures.jl

**Required Investigation**:
1. Check if `PrecisionTypes.jl` exists and is properly loaded
2. Verify module loading order in main Globtim module
3. Test loading sequence manually

**Test Command**:
```bash
ssh scholten@falcon 'cd ~/globtim_hpc && julia -e "
  include(\"src/PrecisionTypes.jl\")
  include(\"src/Structures.jl\")
"'
```

### **Priority 3: MEDIUM - Environment Standardization**

**Issue**: Inconsistent Julia depot paths between login and compute nodes

**Required Setup**:
1. Establish standard JULIA_DEPOT_PATH for all cluster jobs
2. Create shared package installation accessible to all nodes
3. Update job templates with correct environment variables

## 📋 **Validation Checklist**

### **Before Running Production Workflows**

- [ ] **Package Access**: All critical packages load on compute nodes
- [ ] **PrecisionType**: Structures.jl loads without errors
- [ ] **Core Modules**: All Globtim modules compile successfully
- [ ] **Benchmark Functions**: Test functions accessible and executable
- [ ] **Performance**: Multi-threading and memory usage acceptable
- [ ] **Results**: Output collection and storage working

### **Validation Commands**

#### **Quick Validation** (5 minutes)
```bash
cd hpc/scripts/compilation_tests
./submit_compilation_test.sh --mode quick --monitor
```

#### **Standard Validation** (30 minutes)
```bash
./submit_compilation_test.sh --mode standard --monitor
```

#### **Thorough Validation** (1 hour)
```bash
./submit_compilation_test.sh --mode thorough --monitor
```

## 🚀 **Next Steps**

1. **Choose package access solution** (Option A, B, or C above)
2. **Implement chosen solution**
3. **Run validation tests**
4. **Address PrecisionType issue**
5. **Verify end-to-end functionality**
6. **Document final configuration**

## 📞 **Support Information**

**Test Infrastructure Location**: `hpc/scripts/compilation_tests/`
**Results Location**: `hpc_results/compilation_test_*/`
**Monitoring**: Use existing job monitoring scripts in `hpc/monitoring/`

**Contact**: All test scripts include detailed error reporting and troubleshooting information.
