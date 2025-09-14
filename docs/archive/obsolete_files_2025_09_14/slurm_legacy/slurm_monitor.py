#!/usr/bin/env python3
"""
SLURM Job Monitor for Globtim HPC Benchmarking

Comprehensive Python tool for monitoring SLURM jobs with real-time updates,
result analysis, and integration with VS Code.
"""

import subprocess
import time
import json
import os
import sys
import argparse
from datetime import datetime, timedelta
import re
from typing import Dict, List, Optional
import threading
import signal

class SlurmMonitor:
    def __init__(self, ssh_host="scholten@falcon", work_dir="~/globtim_hpc"):
        self.ssh_host = ssh_host
        self.work_dir = work_dir
        self.running = True
        self.job_history = {}
        
    def run_ssh_command(self, command: str, timeout: int = 15) -> Optional[str]:
        """Execute command on HPC cluster via SSH"""
        full_command = f'ssh -o ConnectTimeout=10 -o BatchMode=yes {self.ssh_host} "cd {self.work_dir} && {command}"'
        try:
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
    
    def get_active_jobs(self) -> List[Dict]:
        """Get currently active SLURM jobs"""
        command = "squeue -u $USER --format='%.10i %.20j %.8T %.10M %.6D %R' --noheader 2>/dev/null"
        output = self.run_ssh_command(command)
        
        if not output:
            return []
            
        jobs = []
        for line in output.split('\n'):
            if line.strip():
                parts = line.split()
                if len(parts) >= 6:
                    job_id = parts[0]
                    name = parts[1]
                    status = parts[2]
                    time_str = parts[3]
                    nodes = parts[4]
                    reason = ' '.join(parts[5:])
                    
                    # Filter for Globtim-related jobs
                    if any(keyword in name.lower() for keyword in ['globtim', 'working_', 'params_']):
                        jobs.append({
                            'job_id': job_id,
                            'name': name,
                            'status': status,
                            'time': time_str,
                            'nodes': nodes,
                            'reason': reason,
                            'timestamp': datetime.now()
                        })
        return jobs
    
    def get_recent_jobs(self, hours: int = 24) -> List[Dict]:
        """Get recently completed jobs"""
        start_time = (datetime.now() - timedelta(hours=hours)).strftime('%Y-%m-%d')
        command = f"sacct -u $USER --starttime={start_time} --format=JobID,JobName,State,ExitCode,Start,End,Elapsed --parsable2 --noheader 2>/dev/null | grep -E '(globtim|working_|params_)' | grep -v '.batch\\|.extern'"
        output = self.run_ssh_command(command)
        
        if not output:
            return []
            
        jobs = []
        for line in output.split('\n'):
            if line.strip():
                parts = line.split('|')
                if len(parts) >= 7:
                    jobs.append({
                        'job_id': parts[0],
                        'name': parts[1],
                        'status': parts[2],
                        'exit_code': parts[3],
                        'start_time': parts[4],
                        'end_time': parts[5],
                        'elapsed': parts[6]
                    })
        return jobs[:10]  # Last 10 jobs
    
    def get_job_details(self, job_id: str) -> Optional[Dict]:
        """Get detailed information about a specific job"""
        command = f"scontrol show job {job_id} 2>/dev/null"
        output = self.run_ssh_command(command)
        
        if not output:
            return None
            
        details = {}
        for line in output.split('\n'):
            if '=' in line:
                for pair in line.split():
                    if '=' in pair:
                        key, value = pair.split('=', 1)
                        details[key] = value
        
        return details
    
    def check_job_results(self, job_id: str) -> Optional[Dict]:
        """Check for job results and output files"""
        # Find job directory
        command = f"find results/experiments -name '*{job_id}*' -type d 2>/dev/null | head -1"
        job_dir = self.run_ssh_command(command)
        
        if not job_dir:
            return None
            
        result = {'job_dir': job_dir, 'files': {}}
        
        # Check for various result files
        file_patterns = {
            'success': '*success*.txt',
            'error': '*error*.txt', 
            'results': '*results*.txt',
            'csv': '*.csv',
            'slurm_out': 'slurm_output/*.out',
            'slurm_err': 'slurm_output/*.err'
        }
        
        for file_type, pattern in file_patterns.items():
            command = f"find {job_dir} -name '{pattern}' 2>/dev/null | head -1"
            file_path = self.run_ssh_command(command)
            if file_path:
                result['files'][file_type] = file_path
                
                # Get file content for small text files
                if file_type in ['success', 'error', 'results']:
                    content_command = f"head -20 {file_path} 2>/dev/null"
                    content = self.run_ssh_command(content_command)
                    if content:
                        result['files'][f'{file_type}_content'] = content
        
        return result
    
    def parse_job_metrics(self, content: str) -> Dict:
        """Parse job metrics from result content"""
        metrics = {}
        
        patterns = {
            'l2_error': r'l2_error:\s*([\d.e-]+)',
            'minimizers_count': r'minimizers_count:\s*(\d+)',
            'convergence_rate': r'convergence_rate:\s*([\d.]+)',
            'construction_time': r'construction_time:\s*([\d.]+)',
            'min_distance_to_global': r'min_distance_to_global:\s*([\d.e-]+)'
        }
        
        for key, pattern in patterns.items():
            match = re.search(pattern, content)
            if match:
                try:
                    metrics[key] = float(match.group(1))
                except ValueError:
                    metrics[key] = match.group(1)
        
        return metrics
    
    def format_status_display(self, active_jobs: List[Dict], recent_jobs: List[Dict]) -> str:
        """Format comprehensive status display"""
        lines = []
        
        # Header
        lines.append("🎯 SLURM Job Monitor - Globtim HPC")
        lines.append("=" * 60)
        lines.append(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("")
        
        # Active jobs
        if active_jobs:
            lines.append("🔄 Active Jobs:")
            lines.append("-" * 40)
            for job in active_jobs:
                status_emoji = {
                    'RUNNING': '🟢',
                    'PENDING': '🟡', 
                    'COMPLETED': '✅',
                    'FAILED': '❌',
                    'CANCELLED': '🚫'
                }.get(job['status'], '🔵')
                
                lines.append(f"{status_emoji} {job['job_id']} | {job['name']}")
                lines.append(f"   Status: {job['status']} | Runtime: {job['time']} | Nodes: {job['nodes']}")
                
                if job['status'] == 'PENDING':
                    lines.append(f"   Reason: {job['reason']}")
                elif job['status'] == 'RUNNING':
                    # Get additional details for running jobs
                    details = self.get_job_details(job['job_id'])
                    if details:
                        lines.append(f"   Node: {details.get('NodeList', 'Unknown')}")
                        lines.append(f"   CPUs: {details.get('NumCPUs', 'Unknown')}")
                
                lines.append("")
        else:
            lines.append("✅ No active Globtim jobs")
            lines.append("")
        
        # Recent completions
        if recent_jobs:
            lines.append("📋 Recent Completions (Last 24h):")
            lines.append("-" * 40)
            
            for job in recent_jobs[:5]:  # Show last 5
                status_emoji = '✅' if job['status'] == 'COMPLETED' else '❌'
                lines.append(f"{status_emoji} {job['job_id']} | {job['name']}")
                lines.append(f"   Status: {job['status']} | Exit: {job['exit_code']} | Duration: {job['elapsed']}")
                
                # Check for results
                results = self.check_job_results(job['job_id'])
                if results and 'success_content' in results['files']:
                    metrics = self.parse_job_metrics(results['files']['success_content'])
                    if metrics:
                        lines.append("   📊 Results:")
                        for key, value in metrics.items():
                            if key == 'convergence_rate':
                                lines.append(f"      {key}: {value*100:.1f}%")
                            elif key in ['l2_error', 'min_distance_to_global']:
                                lines.append(f"      {key}: {value:.2e}")
                            else:
                                lines.append(f"      {key}: {value}")
                elif results and 'error_content' in results['files']:
                    lines.append("   ❌ Error - check logs")
                
                lines.append("")
        
        # System status
        lines.append("🖥️  Cluster Status:")
        lines.append("-" * 40)
        
        # Get partition info
        partition_cmd = "sinfo --format='%.10P %.5a %.10l %.6D %.6t' --noheader | head -5"
        partition_info = self.run_ssh_command(partition_cmd)
        if partition_info:
            lines.append("Partitions:")
            for line in partition_info.split('\n'):
                if line.strip():
                    lines.append(f"  {line}")
        
        lines.append("")
        lines.append("🔄 Next update in monitoring mode...")
        
        return '\n'.join(lines)
    
    def monitor_once(self) -> Dict:
        """Single monitoring check"""
        active_jobs = self.get_active_jobs()
        recent_jobs = self.get_recent_jobs()
        
        display = self.format_status_display(active_jobs, recent_jobs)
        print(display)
        
        return {
            'active_jobs': len(active_jobs),
            'recent_jobs': len(recent_jobs),
            'timestamp': datetime.now().isoformat()
        }
    
    def monitor_continuous(self, interval: int = 30):
        """Continuous monitoring mode"""
        print("🚀 Starting Continuous SLURM Monitor")
        print("Press Ctrl+C to stop")
        print("=" * 60)
        
        def signal_handler(sig, frame):
            print("\n👋 Stopping monitor...")
            self.running = False
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        
        try:
            while self.running:
                os.system('clear' if os.name == 'posix' else 'cls')
                
                status = self.monitor_once()
                
                print(f"\n⏰ Next update in {interval} seconds...")
                print(f"📊 Summary: {status['active_jobs']} active, {status['recent_jobs']} recent")
                
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n👋 Monitor stopped")
    
    def analyze_job(self, job_id: str):
        """Detailed analysis of a specific job"""
        print(f"🔍 Analyzing Job {job_id}")
        print("=" * 40)
        
        # Get job details
        details = self.get_job_details(job_id)
        if details:
            print("📋 Job Details:")
            important_fields = ['JobState', 'RunTime', 'NodeList', 'NumCPUs', 'MinMemoryNode', 'StartTime', 'EndTime']
            for field in important_fields:
                if field in details:
                    print(f"  {field}: {details[field]}")
            print()
        
        # Get results
        results = self.check_job_results(job_id)
        if results:
            print("📁 Result Files:")
            for file_type, file_path in results['files'].items():
                if not file_type.endswith('_content'):
                    print(f"  {file_type}: {file_path}")
            print()
            
            # Show metrics if available
            if 'success_content' in results['files']:
                metrics = self.parse_job_metrics(results['files']['success_content'])
                if metrics:
                    print("📊 Performance Metrics:")
                    for key, value in metrics.items():
                        print(f"  {key}: {value}")
                    print()
            
            # Show recent output
            if 'slurm_out' in results['files']:
                print("📄 Recent Output (last 10 lines):")
                tail_cmd = f"tail -10 {results['files']['slurm_out']} 2>/dev/null"
                output = self.run_ssh_command(tail_cmd)
                if output:
                    for line in output.split('\n'):
                        print(f"  {line}")
                print()

def main():
    parser = argparse.ArgumentParser(description='SLURM Job Monitor for Globtim')
    parser.add_argument('--continuous', '-c', action='store_true', help='Continuous monitoring mode')
    parser.add_argument('--interval', '-i', type=int, default=30, help='Update interval in seconds')
    parser.add_argument('--analyze', '-a', help='Analyze specific job ID')
    parser.add_argument('--json', action='store_true', help='Output in JSON format')
    
    args = parser.parse_args()
    
    monitor = SlurmMonitor()
    
    if args.analyze:
        monitor.analyze_job(args.analyze)
    elif args.continuous:
        monitor.monitor_continuous(args.interval)
    elif args.json:
        active_jobs = monitor.get_active_jobs()
        recent_jobs = monitor.get_recent_jobs()
        print(json.dumps({
            'active_jobs': active_jobs,
            'recent_jobs': recent_jobs,
            'timestamp': datetime.now().isoformat()
        }, indent=2))
    else:
        monitor.monitor_once()

if __name__ == "__main__":
    main()
