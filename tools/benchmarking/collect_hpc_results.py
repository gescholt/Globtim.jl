#!/usr/bin/env python3

"""
HPC Results Collection System

Collects, parses, and organizes results from HPC benchmark runs.
"""

import os
import re
import json
import csv
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

class HPCResultCollector:
    def __init__(self, cluster_host="scholten@falcon", data_root="./data"):
        self.cluster_host = cluster_host
        self.data_root = Path(data_root)

        # Create organized directory structure
        self.raw_dir = self.data_root / "raw"
        self.processed_dir = self.data_root / "processed"
        self.experiments_dir = self.data_root / "experiments"
        self.reference_dir = self.data_root / "reference"
        self.viz_dir = self.data_root / "visualizations"

        # Create all directories
        for dir_path in [self.raw_dir, self.processed_dir, self.experiments_dir,
                        self.reference_dir, self.viz_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)

        # Create date-based subdirectory for today's raw data
        from datetime import datetime
        today = datetime.now().strftime("%Y-%m-%d")
        self.today_raw_dir = self.raw_dir / today
        self.today_raw_dir.mkdir(exist_ok=True)
        
    def run_ssh_command(self, command: str) -> Optional[str]:
        """Execute command on HPC cluster via SSH"""
        try:
            result = subprocess.run(
                ["ssh", self.cluster_host, command],
                capture_output=True, text=True, timeout=30
            )
            return result.stdout.strip() if result.returncode == 0 else None
        except subprocess.TimeoutExpired:
            return None
    
    def find_result_files(self) -> List[Dict]:
        """Find all result files on the cluster"""
        print("🔍 Scanning HPC cluster for result files...")
        
        # Find all result files
        patterns = [
            "~/globtim_hpc/test_*.out",
            "~/globtim_hpc/results/experiments/*/jobs/*/",
            "~/globtim_hpc/*results*.txt",
            "~/globtim_hpc/*success*.txt",
            "~/globtim_hpc/*.csv"
        ]
        
        all_files = []
        for pattern in patterns:
            command = f"find {pattern} -type f 2>/dev/null || true"
            output = self.run_ssh_command(command)
            if output:
                all_files.extend(output.split('\n'))
        
        # Organize by type
        result_files = []
        for file_path in all_files:
            if not file_path.strip():
                continue
                
            file_info = {
                'path': file_path,
                'type': self.classify_file(file_path),
                'job_id': self.extract_job_id(file_path),
                'timestamp': self.get_file_timestamp(file_path)
            }
            result_files.append(file_info)
        
        print(f"✅ Found {len(result_files)} result files")
        return result_files
    
    def classify_file(self, file_path: str) -> str:
        """Classify file type based on path and name"""
        if '.out' in file_path:
            return 'slurm_output'
        elif '.err' in file_path:
            return 'slurm_error'
        elif 'results' in file_path.lower():
            return 'results'
        elif 'success' in file_path.lower():
            return 'success'
        elif 'error' in file_path.lower():
            return 'error'
        elif '.csv' in file_path:
            return 'data'
        else:
            return 'other'
    
    def extract_job_id(self, file_path: str) -> Optional[str]:
        """Extract SLURM job ID from file path"""
        # Look for patterns like test_focused_59771290.out
        match = re.search(r'_(\d{8,})\.', file_path)
        if match:
            return match.group(1)
        
        # Look for job directories
        match = re.search(r'/jobs/([^/]+)/', file_path)
        if match:
            return match.group(1)
        
        return None
    
    def get_file_timestamp(self, file_path: str) -> Optional[str]:
        """Get file modification timestamp"""
        command = f"stat -c %Y {file_path} 2>/dev/null"
        timestamp = self.run_ssh_command(command)
        if timestamp:
            return datetime.fromtimestamp(int(timestamp)).isoformat()
        return None
    
    def download_file(self, remote_path: str, local_path: Path) -> bool:
        """Download file from cluster to local storage"""
        try:
            local_path.parent.mkdir(parents=True, exist_ok=True)
            result = subprocess.run([
                "scp", f"{self.cluster_host}:{remote_path}", str(local_path)
            ], capture_output=True, timeout=60)
            return result.returncode == 0
        except subprocess.TimeoutExpired:
            return False
    
    def parse_result_file(self, content: str) -> Dict:
        """Parse structured result file content"""
        results = {}

        # Parse key-value pairs (traditional format)
        for line in content.split('\n'):
            if ':' in line and not line.strip().startswith('📊') and not line.strip().startswith('✅'):
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip()

                # Try to convert to appropriate type
                try:
                    if '.' in value and value.replace('.', '').replace('e-', '').replace('e+', '').isdigit():
                        results[key] = float(value)
                    elif value.isdigit():
                        results[key] = int(value)
                    elif value.lower() in ['true', 'false']:
                        results[key] = value.lower() == 'true'
                    else:
                        results[key] = value
                except ValueError:
                    results[key] = value

        # Parse test output format (our new format)
        self.parse_test_output(content, results)

        return results

    def parse_test_output(self, content: str, results: Dict):
        """Parse test output format from our focused tests"""
        lines = content.split('\n')

        # Look for test completion indicators
        if '✅ All focused tests completed' in content:
            results['test_suite_completed'] = True
            results['test_type'] = 'focused_examples'

        # Parse Globtim loading success
        if '✅ Globtim loaded successfully' in content:
            results['globtim_working'] = True

        # Parse 4D results
        for i, line in enumerate(lines):
            if '📊 4D Results:' in line:
                # Extract 4D metrics from following lines
                for j in range(i+1, min(i+10, len(lines))):
                    result_line = lines[j].strip()
                    if 'Min value:' in result_line:
                        results['4d_min_value'] = float(result_line.split(':')[1].strip())
                    elif 'Max value:' in result_line:
                        results['4d_max_value'] = float(result_line.split(':')[1].strip())
                    elif 'Mean value:' in result_line:
                        results['4d_mean_value'] = float(result_line.split(':')[1].strip())
                    elif 'Best value:' in result_line:
                        results['4d_best_value'] = float(result_line.split(':')[1].strip())
                    elif 'Distance to origin:' in result_line:
                        results['4d_distance_to_origin'] = float(result_line.split(':')[1].strip())

            # Parse simple benchmark results
            elif '📊 Results:' in line and '4D' not in line:
                for j in range(i+1, min(i+10, len(lines))):
                    result_line = lines[j].strip()
                    if 'Min value:' in result_line:
                        results['simple_min_value'] = float(result_line.split(':')[1].strip())
                    elif 'Max value:' in result_line:
                        results['simple_max_value'] = float(result_line.split(':')[1].strip())
                    elif 'Mean value:' in result_line:
                        results['simple_mean_value'] = float(result_line.split(':')[1].strip())

        # Determine overall success
        if results.get('globtim_working', False) and results.get('test_suite_completed', False):
            results['success'] = True
            results['function_name'] = 'Sphere4D' if '4d_min_value' in results else 'Simple2D'
    
    def collect_all_results(self) -> Dict:
        """Collect and organize all results"""
        print("🚀 Starting HPC results collection...")
        
        # Find all result files
        result_files = self.find_result_files()
        
        # Group by job ID
        jobs = {}
        for file_info in result_files:
            job_id = file_info['job_id'] or 'unknown'
            if job_id not in jobs:
                jobs[job_id] = {
                    'job_id': job_id,
                    'files': [],
                    'results': {},
                    'status': 'unknown'
                }
            jobs[job_id]['files'].append(file_info)
        
        print(f"📊 Found {len(jobs)} jobs with results")
        
        # Download and parse results
        collected_results = {}
        for job_id, job_info in jobs.items():
            print(f"\n📥 Collecting results for job {job_id}...")
            
            job_dir = self.today_raw_dir / job_id
            job_dir.mkdir(exist_ok=True)
            
            job_results = {
                'job_id': job_id,
                'files': {},
                'parsed_results': {},
                'collection_time': datetime.now().isoformat()
            }
            
            # Download each file
            for file_info in job_info['files']:
                local_filename = Path(file_info['path']).name
                local_path = job_dir / local_filename
                
                if self.download_file(file_info['path'], local_path):
                    print(f"  ✅ Downloaded {local_filename}")
                    job_results['files'][file_info['type']] = str(local_path)
                    
                    # Parse if it's a result file (including SLURM output)
                    if file_info['type'] in ['results', 'success', 'slurm_output']:
                        try:
                            with open(local_path, 'r') as f:
                                content = f.read()
                                parsed = self.parse_result_file(content)
                                job_results['parsed_results'].update(parsed)
                        except Exception as e:
                            print(f"  ⚠️  Error parsing {local_filename}: {e}")
                else:
                    print(f"  ❌ Failed to download {local_filename}")
            
            collected_results[job_id] = job_results
        
        # Save summary to processed directory
        summary_file = self.processed_dir / "collection_summary.json"
        with open(summary_file, 'w') as f:
            json.dump(collected_results, f, indent=2)

        # Also save a date-specific summary
        date_summary_file = self.processed_dir / f"collection_summary_{datetime.now().strftime('%Y-%m-%d')}.json"
        with open(date_summary_file, 'w') as f:
            json.dump(collected_results, f, indent=2)

        print(f"\n✅ Results collection complete!")
        print(f"📁 Raw data saved to: {self.today_raw_dir}")
        print(f"📋 Summary saved to: {summary_file}")
        print(f"📅 Date-specific summary: {date_summary_file}")
        print(f"🗂️  Data root: {self.data_root}")
        
        return collected_results

if __name__ == "__main__":
    collector = HPCResultCollector()
    results = collector.collect_all_results()
    
    # Print summary
    print(f"\n📊 COLLECTION SUMMARY:")
    print(f"Total jobs: {len(results)}")
    
    successful_jobs = sum(1 for r in results.values() if r['parsed_results'].get('success', False))
    print(f"Successful jobs: {successful_jobs}")
    
    if successful_jobs > 0:
        print(f"\n🎯 Key Metrics from Successful Jobs:")
        for job_id, result in results.items():
            if result['parsed_results'].get('success', False):
                parsed = result['parsed_results']
                print(f"  Job {job_id}:")
                for key in ['function_name', 'l2_error', 'minimizers_count', 'min_distance_to_global']:
                    if key in parsed:
                        print(f"    {key}: {parsed[key]}")
