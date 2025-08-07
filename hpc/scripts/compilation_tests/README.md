# Globtim Compilation Tests for HPC Cluster

This directory contains comprehensive compilation and functionality tests for verifying that Globtim can be built and executed successfully on the HPC cluster.

## Directory Structure

```
compilation_tests/
├── README.md                           # This file
├── comprehensive_compilation_test.jl   # Main compilation test suite
├── submit_compilation_test.sh          # SLURM job submission script
├── compilation_test.slurm             # SLURM job template
└── results/                           # Test results and logs
```

## Test Components

### 1. Comprehensive Compilation Test (`comprehensive_compilation_test.jl`)
- **Purpose**: Complete end-to-end compilation and functionality verification
- **Coverage**: 
  - Julia environment validation
  - All Globtim dependencies loading
  - Core module compilation
  - Basic workflow execution
  - Performance benchmarking
  - Error handling and recovery

### 2. SLURM Job Template (`compilation_test.slurm`)
- **Purpose**: Standardized cluster job for compilation testing
- **Configuration**: Optimized for compilation testing workload
- **Resources**: Balanced CPU/memory allocation for build processes

### 3. Submission Script (`submit_compilation_test.sh`)
- **Purpose**: Easy job submission with parameter customization
- **Features**: 
  - Automatic result collection
  - Job monitoring integration
  - Failure notification

## Usage

### Quick Test
```bash
# From repository root
cd hpc/scripts/compilation_tests
./submit_compilation_test.sh --mode quick
```

### Full Compilation Test
```bash
./submit_compilation_test.sh --mode full
```

### Custom Test
```bash
./submit_compilation_test.sh --mode custom --time 60 --cpus 12
```

## Test Modes

- **`quick`**: Fast compilation check (10 min, 4 CPUs)
- **`full`**: Complete compilation and functionality test (30 min, 24 CPUs)
- **`custom`**: User-defined parameters

## Integration with Existing Infrastructure

This compilation test suite integrates with:
- `hpc/monitoring/` - Real-time job monitoring
- `hpc/infrastructure/` - Package management and deployment
- `Examples/` - Existing test examples and benchmarks
- `tools/validation/` - Validation utilities

## Success Criteria

A successful compilation test should demonstrate:
1. ✅ All dependencies load without errors
2. ✅ Core Globtim modules compile successfully  
3. ✅ Basic polynomial workflow executes
4. ✅ Critical point finding works
5. ✅ Performance meets baseline requirements
6. ✅ Error handling functions properly

## Troubleshooting

Common issues and solutions:
- **Dependency missing**: Check `hpc/infrastructure/install_hpc_packages.sh`
- **Compilation timeout**: Increase time limit or reduce test scope
- **Memory issues**: Check SLURM memory allocation
- **NFS access**: Verify fileserver connectivity

## Related Documentation

- `docs/HPC_CLUSTER_GUIDE.md` - General HPC setup
- `HPC_BENCHMARKING_TROUBLESHOOTING_GUIDE.md` - Troubleshooting
- `hpc/README.md` - HPC infrastructure overview
