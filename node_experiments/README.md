# Node Experiments - HPC r04n02 Execution Framework

This directory contains all experiments designed to run on the r04n02 compute node with proper organization and documentation.

## Directory Structure

```
node_experiments/
├── README.md                    # This documentation
├── scripts/                     # Julia experiment scripts
│   ├── lotka_volterra_4d.jl    # 🎯 PRIORITY: Parameter estimation
│   ├── rosenbrock_4d.jl        # Test case (previous session)
│   └── test_2d_template.jl     # Template based on working 2D case
├── runners/                     # Bash execution scripts
│   └── experiment_runner.sh    # Updated with proper paths
├── outputs/                     # All experiment outputs
│   ├── lotka_volterra_*/       # LV parameter estimation results
│   └── test_*/                 # Test experiment results
└── utils/                      # Helper scripts and utilities
    ├── package_setup.jl        # Dependency installation helper
    └── path_setup.jl           # Path configuration helper
```

## Package Dependencies

### Regular Dependencies (always available)
- Statistics ✅ (in Project.toml)
- DataFrames ✅ (in Project.toml)
- All core GlobTim dependencies ✅

### Weak Dependencies (require explicit activation)
- **CSV** ⚠️ (weak dependency, needs `using CSV` to activate extension)

### Missing Dependencies (need manual installation)
- **JSON** ❌ (not in Project.toml, requires `Pkg.add("JSON")` on node)

## Quick Start on r04n02

### 1. Connect and Navigate
```bash
ssh scholten@r04n02
cd /home/scholten/globtim
git pull origin main
```

### 2. Install Missing Packages (one-time setup)
```bash
julia --project=. -e 'using Pkg; Pkg.add("JSON")'
```

### 3. Run Experiments
```bash
# Lotka-Volterra 4D parameter estimation (PRIORITY)
./node_experiments/runners/experiment_runner.sh lotka-volterra-4d 8 10

# Test cases
./node_experiments/runners/experiment_runner.sh rosenbrock-4d 10 12
```

### 4. Monitor Progress
```bash
# Attach to running experiment
tmux attach -t globtim_*

# Check outputs
ls -la node_experiments/outputs/
```

## Experiment Specifications

### Lotka-Volterra 4D Parameter Estimation
**Objective**: Estimate parameters (α, β, γ, δ) of Lotka-Volterra system from synthetic data
**Method**: GlobTim polynomial approximation of parameter-to-residual mapping
**Expected Runtime**: 2-4 hours (overnight execution recommended)
**Memory Requirements**: `--heap-size-hint=50G` for 4D polynomial approximation

### Memory Requirements by Problem Size
| Dimension | Degree | Basis Functions | Memory Needed | Heap Hint |
|-----------|--------|-----------------|---------------|------------|
| 2         | 10     | 121            | 9.7 MB        | Default    |
| 3         | 8      | 729            | 58.3 MB       | Default    |
| 4         | 8      | 4,096          | 327.7 MB      | 10G        |
| 4         | 10     | 14,641         | 1.2 GB        | 50G        |
| 4         | 12     | 28,561         | 2.3 GB        | 50G        |

## Troubleshooting

### Common Issues
1. **Package not found**: Ensure JSON is installed and CSV extension is activated
2. **Wrong project activated**: All scripts use `Pkg.activate(dirname(@__DIR__))` to activate main project
3. **Memory errors**: Increase heap hint based on problem size table above
4. **Permission denied**: Run `chmod +x` on runner scripts after git pull

### Debug Commands
```bash
# Check package status
julia --project=. -e 'using Pkg; Pkg.status()'

# Test CSV extension
julia --project=. -e 'using CSV; println("CSV loaded successfully")'

# Check tmux sessions
tmux ls | grep globtim

# View experiment logs  
tail -f node_experiments/outputs/*/output.log
```

## Development Workflow

1. **Local Development**: Create/test scripts locally
2. **Git Sync**: `git add`, `git commit`, `git push`
3. **Node Deployment**: SSH to node, `git pull`  
4. **Execution**: Use experiment_runner.sh with proper parameters
5. **Monitoring**: tmux attach for progress, outputs/ for results
6. **Collection**: Download results or analyze on node

## File Naming Conventions

- **Scripts**: `{problem}_{dimension}d.jl` (e.g., `lotka_volterra_4d.jl`)
- **Outputs**: `{problem}_{dimension}d_{timestamp}` (e.g., `lotka_volterra_4d_20250903_143022`)
- **Results**: Standard GlobTim format (CSV, JSON, timing reports, summaries)