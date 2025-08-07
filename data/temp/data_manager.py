#!/usr/bin/env python3

"""
Data Management Utility for Globtim HPC Results

Manages the organized data directory structure and provides utilities for
data organization, cleanup, and experiment management.
"""

import argparse
import shutil
import json
from pathlib import Path
from datetime import datetime, timedelta
import pandas as pd

class DataManager:
    def __init__(self, data_root="./data"):
        self.data_root = Path(data_root)
        self.raw_dir = self.data_root / "raw"
        self.processed_dir = self.data_root / "processed"
        self.experiments_dir = self.data_root / "experiments"
        self.reference_dir = self.data_root / "reference"
        self.viz_dir = self.data_root / "visualizations"
        
    def initialize_data_structure(self):
        """Initialize the complete data directory structure"""
        print("🗂️  Initializing data directory structure...")
        
        # Create main directories
        directories = [
            self.raw_dir,
            self.processed_dir,
            self.experiments_dir,
            self.reference_dir,
            self.viz_dir,
            self.processed_dir / "analysis_reports",
            self.viz_dir / "performance_plots",
            self.viz_dir / "comparison_charts",
            self.viz_dir / "interactive_dashboards"
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            print(f"✅ Created: {directory}")
        
        # Create README files
        self.create_readme_files()
        
        print(f"\n✅ Data structure initialized at: {self.data_root}")
        
    def create_readme_files(self):
        """Create README files explaining each directory"""
        readme_content = {
            self.data_root / "README.md": """# Globtim HPC Results Data

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
""",
            
            self.raw_dir / "README.md": """# Raw HPC Results

Raw output files from HPC cluster jobs, organized by collection date.

Each subdirectory contains:
- SLURM output files (.out)
- SLURM error files (.err)
- Job scripts (.slurm)
- Any generated result files

Files are preserved exactly as downloaded from the cluster.
""",
            
            self.processed_dir / "README.md": """# Processed Results

Analyzed and structured data from HPC benchmark runs.

Key files:
- `benchmark_results.csv` - Structured data for all jobs
- `collection_summary.json` - Complete parsed results
- `analysis_report.txt` - Human-readable analysis
- `collection_summary_YYYY-MM-DD.json` - Date-specific summaries
""",
            
            self.experiments_dir / "README.md": """# Experiment Campaigns

Results organized by specific research experiments or campaigns.

Each experiment directory contains:
- Experiment-specific results
- Analysis reports
- Comparison data
- Documentation

Create new experiment directories for focused studies.
""",
            
            self.reference_dir / "README.md": """# Reference Data

Baseline results, known minima, and validation data.

Contains:
- Ground truth data for benchmark functions
- Baseline performance results
- Validation datasets
- Reference implementations
""",
            
            self.viz_dir / "README.md": """# Visualizations

Generated plots, charts, and interactive dashboards.

Subdirectories:
- `performance_plots/` - Performance analysis charts
- `comparison_charts/` - Comparison visualizations
- `interactive_dashboards/` - Web-based dashboards
"""
        }
        
        for file_path, content in readme_content.items():
            with open(file_path, 'w') as f:
                f.write(content)
    
    def get_data_status(self):
        """Get comprehensive status of data directories"""
        status = {
            "data_root": str(self.data_root),
            "total_size_mb": self.get_directory_size(self.data_root),
            "directories": {}
        }
        
        # Check each main directory
        for name, directory in [
            ("raw", self.raw_dir),
            ("processed", self.processed_dir),
            ("experiments", self.experiments_dir),
            ("reference", self.reference_dir),
            ("visualizations", self.viz_dir)
        ]:
            if directory.exists():
                file_count = len(list(directory.rglob("*")))
                size_mb = self.get_directory_size(directory)
                
                status["directories"][name] = {
                    "exists": True,
                    "file_count": file_count,
                    "size_mb": size_mb,
                    "path": str(directory)
                }
            else:
                status["directories"][name] = {
                    "exists": False,
                    "file_count": 0,
                    "size_mb": 0,
                    "path": str(directory)
                }
        
        # Check for key files
        key_files = [
            self.processed_dir / "benchmark_results.csv",
            self.processed_dir / "collection_summary.json",
            self.processed_dir / "analysis_report.txt"
        ]
        
        status["key_files"] = {}
        for file_path in key_files:
            status["key_files"][file_path.name] = {
                "exists": file_path.exists(),
                "size_mb": file_path.stat().st_size / (1024*1024) if file_path.exists() else 0,
                "modified": datetime.fromtimestamp(file_path.stat().st_mtime).isoformat() if file_path.exists() else None
            }
        
        return status
    
    def get_directory_size(self, directory):
        """Get total size of directory in MB"""
        if not directory.exists():
            return 0
        
        total_size = sum(f.stat().st_size for f in directory.rglob('*') if f.is_file())
        return round(total_size / (1024 * 1024), 2)
    
    def cleanup_old_data(self, days_old=30, dry_run=True):
        """Clean up old raw data files"""
        cutoff_date = datetime.now() - timedelta(days=days_old)
        
        print(f"🧹 Cleaning up raw data older than {days_old} days (cutoff: {cutoff_date.date()})")
        
        if not self.raw_dir.exists():
            print("⚠️  Raw data directory doesn't exist")
            return
        
        old_dirs = []
        for date_dir in self.raw_dir.iterdir():
            if date_dir.is_dir():
                try:
                    dir_date = datetime.strptime(date_dir.name, "%Y-%m-%d")
                    if dir_date < cutoff_date:
                        old_dirs.append((date_dir, dir_date))
                except ValueError:
                    continue
        
        if not old_dirs:
            print("✅ No old data to clean up")
            return
        
        total_size = sum(self.get_directory_size(d[0]) for d in old_dirs)
        
        print(f"📊 Found {len(old_dirs)} old directories ({total_size:.1f} MB)")
        
        for date_dir, dir_date in old_dirs:
            size_mb = self.get_directory_size(date_dir)
            if dry_run:
                print(f"🔍 Would delete: {date_dir.name} ({size_mb:.1f} MB)")
            else:
                print(f"🗑️  Deleting: {date_dir.name} ({size_mb:.1f} MB)")
                shutil.rmtree(date_dir)
        
        if dry_run:
            print(f"\n💡 This was a dry run. Use --cleanup --no-dry-run to actually delete files")
        else:
            print(f"\n✅ Cleanup complete. Freed {total_size:.1f} MB")
    
    def create_experiment(self, name, description=""):
        """Create a new experiment directory"""
        exp_dir = self.experiments_dir / name
        
        if exp_dir.exists():
            print(f"⚠️  Experiment '{name}' already exists")
            return
        
        exp_dir.mkdir(parents=True)
        
        # Create experiment structure
        (exp_dir / "results").mkdir()
        (exp_dir / "analysis").mkdir()
        (exp_dir / "plots").mkdir()
        
        # Create experiment metadata
        metadata = {
            "name": name,
            "description": description,
            "created": datetime.now().isoformat(),
            "status": "active"
        }
        
        with open(exp_dir / "experiment.json", 'w') as f:
            json.dump(metadata, f, indent=2)
        
        # Create README
        readme_content = f"""# Experiment: {name}

{description}

Created: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Directory Structure

- `results/` - Experiment-specific results
- `analysis/` - Analysis files and reports
- `plots/` - Visualizations and plots
- `experiment.json` - Experiment metadata

## Usage

Copy relevant results from the main processed directory to organize
experiment-specific data and analysis.
"""
        
        with open(exp_dir / "README.md", 'w') as f:
            f.write(readme_content)
        
        print(f"✅ Created experiment: {name}")
        print(f"📁 Location: {exp_dir}")
    
    def print_status(self):
        """Print comprehensive data status"""
        status = self.get_data_status()
        
        print("🗂️  DATA DIRECTORY STATUS")
        print("=" * 50)
        print(f"Data Root: {status['data_root']}")
        print(f"Total Size: {status['total_size_mb']:.1f} MB")
        print()
        
        print("📁 DIRECTORIES:")
        for name, info in status["directories"].items():
            status_icon = "✅" if info["exists"] else "❌"
            print(f"{status_icon} {name.capitalize()}: {info['file_count']} files, {info['size_mb']:.1f} MB")
        
        print("\n📄 KEY FILES:")
        for name, info in status["key_files"].items():
            status_icon = "✅" if info["exists"] else "❌"
            modified = f" (modified: {info['modified'][:19]})" if info["modified"] else ""
            print(f"{status_icon} {name}: {info['size_mb']:.1f} MB{modified}")
        
        # Show recent raw data
        if self.raw_dir.exists():
            recent_dirs = sorted([d for d in self.raw_dir.iterdir() if d.is_dir()], reverse=True)[:5]
            if recent_dirs:
                print(f"\n📅 RECENT RAW DATA:")
                for date_dir in recent_dirs:
                    file_count = len(list(date_dir.rglob("*")))
                    size_mb = self.get_directory_size(date_dir)
                    print(f"   {date_dir.name}: {file_count} files, {size_mb:.1f} MB")

def main():
    parser = argparse.ArgumentParser(description="Manage Globtim HPC results data")
    parser.add_argument("--init", action="store_true", help="Initialize data directory structure")
    parser.add_argument("--status", action="store_true", help="Show data directory status")
    parser.add_argument("--cleanup", type=int, metavar="DAYS", help="Clean up raw data older than DAYS")
    parser.add_argument("--no-dry-run", action="store_true", help="Actually perform cleanup (not just preview)")
    parser.add_argument("--create-experiment", metavar="NAME", help="Create new experiment directory")
    parser.add_argument("--description", metavar="DESC", help="Description for new experiment")
    
    args = parser.parse_args()
    
    manager = DataManager()
    
    if args.init:
        manager.initialize_data_structure()
    elif args.status:
        manager.print_status()
    elif args.cleanup:
        manager.cleanup_old_data(args.cleanup, dry_run=not args.no_dry_run)
    elif args.create_experiment:
        manager.create_experiment(args.create_experiment, args.description or "")
    else:
        print("🗂️  Globtim Data Manager")
        print("Use --help to see available options")
        print("\nQuick commands:")
        print("  --init                    Initialize data structure")
        print("  --status                  Show current status")
        print("  --cleanup 30              Preview cleanup of 30+ day old data")
        print("  --create-experiment NAME  Create new experiment directory")

if __name__ == "__main__":
    main()
