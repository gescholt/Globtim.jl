#!/usr/bin/env python3
"""
JSON-Tracked Results Automated Pull System

Builds on existing HPC infrastructure to automatically pull JSON-tracked
computation results from the cluster. Integrates with the existing monitoring
and collection systems while being specifically designed for the JSON tracking
workflow.
"""

import os
import sys
import json
import subprocess
import argparse
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import re

# Add the existing tools to path for reuse
sys.path.append(str(Path(__file__).parent.parent.parent / "tools" / "benchmarking"))

try:
    from collect_hpc_results import HPCResultCollector
    HAS_EXISTING_COLLECTOR = True
except ImportError:
    HAS_EXISTING_COLLECTOR = False
    print("⚠️  Existing HPC result collector not found, using standalone mode")

class JSONTrackedResultsPuller:
    """
    Automated puller for JSON-tracked computation results.
    Builds on existing HPC infrastructure while being JSON-tracking aware.
    """
    
    def __init__(self, cluster_host="scholten@falcon", 
                 cluster_path="~/globtim_hpc", 
                 local_results_path="hpc/results"):
        self.cluster_host = cluster_host
        self.cluster_path = cluster_path
        self.local_results_path = Path(local_results_path)
        
        # Ensure local results directory exists
        self.local_results_path.mkdir(parents=True, exist_ok=True)
        
        # Integration with existing collector if available
        if HAS_EXISTING_COLLECTOR:
            self.existing_collector = HPCResultCollector(cluster_host=cluster_host)
        else:
            self.existing_collector = None
    
    def run_ssh_command(self, command: str, timeout: int = 30) -> Optional[str]:
        """Execute command on HPC cluster via SSH (reuses existing pattern)"""
        try:
            full_command = f'ssh -o ConnectTimeout=10 -o BatchMode=yes {self.cluster_host} "cd {self.cluster_path} && {command}"'
            result = subprocess.run(
                full_command, 
                shell=True, 
                capture_output=True, 
                text=True, 
                timeout=timeout
            )
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                print(f"SSH Error: {result.stderr.strip()}")
                return None
        except subprocess.TimeoutExpired:
            print(f"Command timed out: {command}")
            return None
        except Exception as e:
            print(f"Error executing command: {e}")
            return None
    
    def find_json_tracked_results(self, days_back: int = 7) -> List[Dict]:
        """Find JSON-tracked computation results on the cluster"""
        print(f"🔍 Scanning for JSON-tracked results from last {days_back} days...")
        
        # Look for our JSON tracking directory structure
        find_command = f"""
        find hpc/results -name "input_config.json" -mtime -{days_back} 2>/dev/null | 
        head -50 | 
        while read config_file; do
            dir=$(dirname "$config_file")
            if [ -f "$dir/output_results.json" ]; then
                echo "$dir"
            fi
        done
        """
        
        output = self.run_ssh_command(find_command)
        if not output:
            print("No JSON-tracked results found")
            return []
        
        result_dirs = output.strip().split('\n')
        results = []
        
        for result_dir in result_dirs:
            if not result_dir.strip():
                continue
                
            # Get basic info about this computation
            info = self.get_computation_info(result_dir)
            if info:
                results.append(info)
        
        print(f"📊 Found {len(results)} JSON-tracked computations")
        return results
    
    def get_computation_info(self, result_dir: str) -> Optional[Dict]:
        """Get information about a specific computation"""
        # Read input config to get metadata
        config_command = f"cat {result_dir}/input_config.json 2>/dev/null"
        config_output = self.run_ssh_command(config_command)
        
        if not config_output:
            return None
        
        try:
            input_config = json.loads(config_output)
            metadata = input_config.get('metadata', {})
            
            # Check if output results exist
            results_command = f"test -f {result_dir}/output_results.json && echo 'exists' || echo 'missing'"
            results_exist = self.run_ssh_command(results_command) == 'exists'
            
            # Get file timestamps
            timestamp_command = f"stat -c %Y {result_dir}/input_config.json 2>/dev/null"
            timestamp_output = self.run_ssh_command(timestamp_command)
            
            file_timestamp = None
            if timestamp_output:
                file_timestamp = datetime.fromtimestamp(int(timestamp_output))
            
            return {
                'computation_id': metadata.get('computation_id', 'unknown'),
                'function_name': metadata.get('function_name', 'unknown'),
                'description': metadata.get('description', ''),
                'tags': metadata.get('tags', []),
                'remote_path': result_dir,
                'has_results': results_exist,
                'file_timestamp': file_timestamp,
                'input_config': input_config
            }
            
        except json.JSONDecodeError as e:
            print(f"⚠️  Invalid JSON in {result_dir}/input_config.json: {e}")
            return None
    
    def determine_local_path(self, computation_info: Dict) -> Path:
        """Determine where to store results locally (follows JSON tracking structure)"""
        function_name = computation_info['function_name']
        computation_id = computation_info['computation_id']
        
        # Try to extract timestamp and description from remote path
        remote_path = computation_info['remote_path']
        path_parts = remote_path.split('/')
        
        # Find the computation directory name (should contain timestamp and ID)
        comp_dir_name = None
        for part in reversed(path_parts):
            if computation_id in part:
                comp_dir_name = part
                break
        
        if not comp_dir_name:
            # Fallback naming
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            comp_dir_name = f"{function_name.lower()}_{timestamp}_{computation_id}"
        
        # Determine the appropriate local path following JSON tracking structure
        if 'by_function' in remote_path:
            # Extract the year-month from the remote path
            year_month_match = re.search(r'/(\d{4}-\d{2})/', remote_path)
            if year_month_match:
                year_month = year_month_match.group(1)
            else:
                year_month = datetime.now().strftime("%Y-%m")
            
            local_path = (self.local_results_path / "by_function" / 
                         function_name / year_month / "single_tests" / comp_dir_name)
        else:
            # Fallback structure
            local_path = (self.local_results_path / "pulled_results" / 
                         function_name / comp_dir_name)
        
        return local_path
    
    def pull_computation_results(self, computation_info: Dict, 
                               force_overwrite: bool = False) -> bool:
        """Pull a single computation's results"""
        local_path = self.determine_local_path(computation_info)
        remote_path = computation_info['remote_path']
        computation_id = computation_info['computation_id']
        
        print(f"📥 Pulling computation {computation_id}...")
        print(f"   From: {self.cluster_host}:{remote_path}")
        print(f"   To: {local_path}")
        
        # Check if already exists locally
        if local_path.exists() and not force_overwrite:
            print(f"   ⚠️  Already exists locally, skipping (use --force to overwrite)")
            return True
        
        # Create local directory
        local_path.mkdir(parents=True, exist_ok=True)
        
        # Use rsync to pull the entire computation directory
        rsync_command = [
            "rsync", "-avz", "--progress",
            f"{self.cluster_host}:{remote_path}/",
            str(local_path) + "/"
        ]
        
        try:
            result = subprocess.run(rsync_command, capture_output=True, text=True, timeout=300)
            if result.returncode == 0:
                print(f"   ✅ Successfully pulled computation {computation_id}")
                
                # Create symlinks for alternative access patterns
                self.create_local_symlinks(local_path, computation_info)
                
                return True
            else:
                print(f"   ❌ Failed to pull computation {computation_id}")
                print(f"   Error: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print(f"   ❌ Timeout pulling computation {computation_id}")
            return False
        except Exception as e:
            print(f"   ❌ Error pulling computation {computation_id}: {e}")
            return False
    
    def create_local_symlinks(self, local_path: Path, computation_info: Dict):
        """Create symlinks for alternative access patterns (mirrors JSON tracking system)"""
        computation_id = computation_info['computation_id']
        tags = computation_info.get('tags', [])
        
        # Create by_date symlink
        if computation_info.get('file_timestamp'):
            date_str = computation_info['file_timestamp'].strftime("%Y-%m-%d")
            date_dir = self.local_results_path / "by_date" / date_str
            date_dir.mkdir(parents=True, exist_ok=True)
            
            date_link = date_dir / computation_id
            if not date_link.exists():
                try:
                    date_link.symlink_to(local_path.resolve())
                except OSError:
                    pass  # Symlink creation failed, continue
        
        # Create by_tag symlinks
        for tag in tags:
            if tag:  # Skip empty tags
                tag_dir = self.local_results_path / "by_tag" / tag
                tag_dir.mkdir(parents=True, exist_ok=True)
                
                tag_link = tag_dir / computation_id
                if not tag_link.exists():
                    try:
                        tag_link.symlink_to(local_path.resolve())
                    except OSError:
                        pass  # Symlink creation failed, continue
    
    def pull_recent_results(self, days_back: int = 7, 
                          force_overwrite: bool = False) -> Dict:
        """Pull all recent JSON-tracked results"""
        print(f"🚀 Starting automated pull of JSON-tracked results")
        print(f"📅 Looking for results from last {days_back} days")
        print("=" * 60)
        
        # Find results
        computations = self.find_json_tracked_results(days_back)
        
        if not computations:
            print("✅ No new results to pull")
            return {'total': 0, 'successful': 0, 'failed': 0}
        
        # Pull each computation
        successful = 0
        failed = 0
        
        for computation in computations:
            success = self.pull_computation_results(computation, force_overwrite)
            if success:
                successful += 1
            else:
                failed += 1
            print()  # Empty line between computations
        
        # Summary
        print("=" * 60)
        print(f"📊 PULL SUMMARY:")
        print(f"   Total computations found: {len(computations)}")
        print(f"   Successfully pulled: {successful}")
        print(f"   Failed: {failed}")
        
        if successful > 0:
            print(f"\n📁 Results available in: {self.local_results_path}")
            print("   Access patterns:")
            print(f"   • By function: {self.local_results_path}/by_function/")
            print(f"   • By date: {self.local_results_path}/by_date/")
            print(f"   • By tags: {self.local_results_path}/by_tag/")
        
        return {
            'total': len(computations),
            'successful': successful,
            'failed': failed,
            'computations': computations
        }
    
    def pull_specific_computation(self, computation_id: str, 
                                force_overwrite: bool = False) -> bool:
        """Pull a specific computation by ID"""
        print(f"🎯 Looking for computation {computation_id}...")
        
        # Search for the computation
        find_command = f'find hpc/results -name "*{computation_id}*" -type d 2>/dev/null | head -1'
        result_dir = self.run_ssh_command(find_command)
        
        if not result_dir:
            print(f"❌ Computation {computation_id} not found on cluster")
            return False
        
        # Get computation info
        computation_info = self.get_computation_info(result_dir)
        if not computation_info:
            print(f"❌ Could not read computation info for {computation_id}")
            return False
        
        # Pull the results
        return self.pull_computation_results(computation_info, force_overwrite)

def main():
    parser = argparse.ArgumentParser(description='Pull JSON-tracked results from HPC cluster')
    parser.add_argument('--days', '-d', type=int, default=7, 
                       help='Number of days back to search for results (default: 7)')
    parser.add_argument('--computation-id', '-c', 
                       help='Pull specific computation by ID')
    parser.add_argument('--force', '-f', action='store_true',
                       help='Force overwrite existing local results')
    parser.add_argument('--cluster-host', default='scholten@falcon',
                       help='HPC cluster SSH host (default: scholten@falcon)')
    parser.add_argument('--cluster-path', default='~/globtim_hpc',
                       help='Path to Globtim on cluster (default: ~/globtim_hpc)')
    parser.add_argument('--local-path', default='hpc/results',
                       help='Local results path (default: hpc/results)')
    
    args = parser.parse_args()
    
    # Create puller instance
    puller = JSONTrackedResultsPuller(
        cluster_host=args.cluster_host,
        cluster_path=args.cluster_path,
        local_results_path=args.local_path
    )
    
    if args.computation_id:
        # Pull specific computation
        success = puller.pull_specific_computation(args.computation_id, args.force)
        exit(0 if success else 1)
    else:
        # Pull recent results
        results = puller.pull_recent_results(args.days, args.force)
        exit(0 if results['failed'] == 0 else 1)

if __name__ == "__main__":
    main()
