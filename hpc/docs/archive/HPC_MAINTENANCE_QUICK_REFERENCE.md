# HPC Maintenance Quick Reference

**Last Updated**: 2025-08-04  
**Purpose**: Quick commands for maintaining HPC file organization

## 🚀 **Quick Commands**

### **Preview File Organization** (Safe)
```bash
./maintain_hpc_files.sh true
```

### **Execute File Organization**
```bash
./maintain_hpc_files.sh
```

### **Run HPC Test**
```bash
./run_custom_hpc_test.sh Examples/production/hpc_standalone_test.jl --light
```

### **Check File Status**
```bash
# Find orphaned files
find . -maxdepth 1 -name "*.jl" -not -path "./Examples/*"
find . -maxdepth 1 -name "custom_*" -mtime +7

# Check directory sizes
du -sh Examples/ hpc_results/ archive/
```

## 📁 **Directory Structure**

```
globtim/
├── Examples/
│   ├── production/              ← ✅ Working examples
│   ├── development/             ← 🔧 In-progress
│   └── archive/                 ← 📦 Old examples
├── hpc_results/
│   ├── current/                 ← 📊 Recent results
│   └── archive/                 ← 📦 Old results
├── hpc/scripts/                 ← 🛠️  Production scripts
├── docs/hpc/                    ← 📚 Documentation
└── archive/obsolete/            ← 🗑️  Obsolete files
```

## 🎯 **File Lifecycle**

### **New Development File**
1. Create in `Examples/development/`
2. Test with `run_custom_hpc_test.sh`
3. Results go to `hpc_results/current/`

### **Working File**
1. Move to `Examples/production/`
2. Update documentation
3. Use in production workflows

### **Obsolete File**
1. Move to `archive/obsolete/YYYYMMDD/`
2. Update documentation
3. Clean up after 90 days

## ⚠️ **Safety Rules**

### **NEVER DELETE**
- `src/` directory contents
- Files in `Examples/production/`
- Current month's test results
- Configuration files

### **SAFE TO DELETE** (After confirmation)
- `custom_*.out`, `custom_*.err` files older than 7 days
- Temporary `.slurm` files
- Files in `archive/obsolete/` older than 90 days

## 🔧 **Common Tasks**

### **Clean Up After Testing**
```bash
# Remove temporary files
rm -f custom_*.out custom_*.err *.slurm.tmp

# Archive test results
./maintain_hpc_files.sh
```

### **Prepare for New Development**
```bash
# Check current organization
./maintain_hpc_files.sh true

# Clean up if needed
./maintain_hpc_files.sh

# Create new development file
cp Examples/production/template.jl Examples/development/new_test.jl
```

### **Weekly Maintenance**
```bash
# 1. Preview changes
./maintain_hpc_files.sh true

# 2. Execute if looks good
./maintain_hpc_files.sh

# 3. Check maintenance log
cat docs/maintenance/maintenance_log.txt | tail -20
```

## 📊 **Status Indicators**

- ✅ **Working**: File is tested and ready for production
- 🔧 **Development**: File is being developed/tested
- 📦 **Archived**: File is old but kept for reference
- 🗑️ **Obsolete**: File is no longer needed
- ❌ **Broken**: File has known issues

## 🆘 **Emergency Recovery**

### **If Files Get Mixed Up**
```bash
# 1. Stop and assess
./maintain_hpc_files.sh true

# 2. Manual recovery
git status  # Check what changed
git checkout -- filename  # Restore if needed

# 3. Reorganize carefully
./maintain_hpc_files.sh
```

### **If Test Results Are Lost**
```bash
# Check cluster for recent results
ssh scholten@falcon "ls -la ~/globtim_hpc/custom_*"

# Download missing results
scp scholten@falcon:~/globtim_hpc/custom_*.out ./
```

## 📞 **Quick Help**

- **File Organization**: `./maintain_hpc_files.sh true` (preview first)
- **Run HPC Test**: `./run_custom_hpc_test.sh filename.jl --light`
- **Check Status**: Look at `docs/hpc/HPC_LIGHT_2D_FILES_DOCUMENTATION.md`
- **Maintenance Log**: `docs/maintenance/maintenance_log.txt`

---
**Remember**: Always preview with `true` argument before executing maintenance!
