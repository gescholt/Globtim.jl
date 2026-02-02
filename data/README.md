# Globtim HPC Results Data

This directory contains all data from HPC benchmark runs, organized for easy access and analysis.

## Directory Structure

- `raw/` - Raw output files from HPC cluster, organized by date
- `processed/` - Processed and analyzed data (CSV, JSON, reports)
- `experiments/` - Results organized by experiment campaigns
- `reference/` - Reference data and baseline results
- `visualizations/` - Generated plots, charts, and dashboards

## Usage

### Collection (Current)
Use the Julia-based collection workflow from `globtimpostprocessing`:
```julia
using ClusterCollection
collect_batch("tracking/batch_ID.json", "output_dir")
```

### Analysis (Current)
- Run `python3 ../tools/benchmarking/benchmark_dashboard.py` for comprehensive analysis
- Interactive dashboards saved to `visualizations/`

### Legacy Tools (Archived)
- `analyze_hpc_results.py` - Archived (see `../tools/benchmarking/archived/README.md`)
- Use `benchmark_dashboard.py` instead for modern analysis
