# Globtim HPC Results Data

This directory contains all data from HPC benchmark runs, organized for easy access and analysis.

## Directory Structure

- `raw/` - Raw output files from HPC cluster, organized by date
- `processed/` - Processed and analyzed data (CSV, JSON, reports)
- `experiments/` - Results organized by experiment campaigns
- `reference/` - Reference data and baseline results
- `visualizations/` - Generated plots, charts, and dashboards

## Usage

- Run `python3 collect_hpc_results.py` to collect new results
- Run `python3 analyze_hpc_results.py` to generate analysis
- Run `python3 quick_visualize.py` for quick visualization
- Run `python3 data_manager.py --status` to check data status
