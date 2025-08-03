# HPC Infrastructure

This directory contains all HPC-related functionality for Globtim benchmarking.

## Structure

- `infrastructure/` - Setup, deployment, and sync scripts
- `jobs/` - Job templates and creation scripts  
- `monitoring/` - Real-time monitoring tools (Python & Bash)
- `config/` - Configuration files and Parameters.jl system

## Quick Start

```bash
# From repository root:
./hpc_tools.sh monitor --continuous    # Start monitoring
./hpc_tools.sh create-job             # Create new benchmark job
./hpc_tools.sh sync                   # Sync to cluster
```
