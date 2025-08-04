# Globtim - Global Optimization via Polynomial Approximation

Enhanced with comprehensive HPC benchmarking infrastructure and Parameters.jl integration.

## 🚀 New Features

### HPC Integration
- **SLURM Job Management**: Automated job creation, submission, and monitoring
- **Parameters.jl System**: Type-safe configuration with sensible defaults
- **Real-time Monitoring**: Python and VS Code integrated monitoring tools
- **Three-tier Architecture**: Local → Fileserver → HPC cluster sync

### Quick Start - HPC Benchmarking
```bash
# Monitor SLURM jobs in real-time
./hpc_tools.sh monitor --continuous

# Create and submit benchmark job
./hpc_tools.sh create-job

# Sync code to HPC cluster
./hpc_tools.sh sync

# View HPC dashboard
./hpc_tools.sh dashboard
```

## 📁 Repository Structure

```
globtim/
├── src/                    # Core Globtim source code
├── test/                   # Core tests
├── docs/                   # Documentation
├── Examples/               # Usage examples
├── hpc/                    # 🆕 HPC Infrastructure
│   ├── infrastructure/     # Setup and deployment
│   ├── jobs/              # Job templates and creation
│   ├── monitoring/        # Real-time monitoring tools
│   └── config/            # Configuration and Parameters.jl
├── tools/                  # 🆕 Development Tools
│   ├── validation/        # Testing and validation
│   ├── deployment/        # Deployment utilities
│   └── maintenance/       # Security and maintenance
└── .vscode/               # 🆕 Enhanced VS Code integration
```

## 🎯 HPC Workflow

1. **Configure**: Edit `hpc/config/cluster_config.sh`
2. **Create Job**: `./hpc_tools.sh create-job`
3. **Monitor**: `./hpc_tools.sh monitor --continuous`
4. **Analyze**: Results automatically collected and parsed

## 📊 Monitoring Features

- **Real-time job status** with 30-second updates
- **Automatic result parsing** and performance metrics
- **VS Code integration** with tasks and terminals
- **Cluster resource monitoring** and queue analysis

See `NEW_FEATURES_DOCUMENTATION.md` for complete feature list.
