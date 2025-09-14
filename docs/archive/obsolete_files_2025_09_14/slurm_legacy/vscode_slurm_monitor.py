#!/usr/bin/env python3
"""
VS Code SLURM Job Monitor

Real-time SLURM job monitoring that integrates with VS Code terminal.
Provides live updates, progress tracking, and result notifications.
"""

import subprocess
import time
import json
import os
from datetime import datetime
import argparse

class SlurmMonitor:
    def __init__(self, ssh_host="scholten@falcon", work_dir="~/globtim_hpc"):
        self.ssh_host = ssh_host
        self.work_dir = work_dir
        self.monitored_jobs = {}
        
    def run_ssh_command(self, command):
        """Execute command on remote host via SSH"""
        full_command = f'ssh -o ConnectTimeout=10 -o BatchMode=yes {self.ssh_host} "cd {self.work_dir} && {command}"'
        try:
            result = subprocess.run(full_command, shell=True, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                return f"SSH Error: {result.stderr.strip()}"
        except subprocess.TimeoutExpired:
            return "Command timed out"
        except Exception as e:
            return f"Error: {e}"
    
    def get_job_status(self):
        """Get current SLURM job status"""
        command = "squeue -u $USER --format='%.10i %.15j %.8T %.10M %.6D %R' --noheader"
        output = self.run_ssh_command(command)
        
        jobs = []
        for line in output.split('\n'):
            if line.strip() and 'globtim' in line.lower():
                parts = line.split()
                if len(parts) >= 6:
                    jobs.append({
                        'job_id': parts[0],
                        'name': parts[1],
                        'status': parts[2],
                        'time': parts[3],
                        'nodes': parts[4],
                        'reason': ' '.join(parts[5:])
                    })
        return jobs
    
    def get_job_results(self, job_id):
        """Check for job results"""
        command = f"find results/experiments -name '*{job_id}*' -type d 2>/dev/null | head -1"
        job_dir = self.run_ssh_command(command)
        
        if not job_dir:
            return None
            
        # Check for success/error files
        success_cmd = f"find {job_dir} -name '*success*.txt' 2>/dev/null | head -1"
        error_cmd = f"find {job_dir} -name '*error*.txt' 2>/dev/null | head -1"
        
        success_file = self.run_ssh_command(success_cmd)
        error_file = self.run_ssh_command(error_cmd)
        
        result = {'job_dir': job_dir}
        
        if success_file:
            # Parse success file
            content_cmd = f"cat {success_file}"
            content = self.run_ssh_command(content_cmd)
            result['status'] = 'SUCCESS'
            result['details'] = self.parse_result_file(content)
        elif error_file:
            content_cmd = f"cat {error_file}"
            content = self.run_ssh_command(content_cmd)
            result['status'] = 'FAILED'
            result['error'] = content
        else:
            result['status'] = 'IN_PROGRESS'
            
        return result
    
    def parse_result_file(self, content):
        """Parse result file content"""
        details = {}
        for line in content.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                details[key.strip()] = value.strip()
        return details
    
    def format_status_display(self, jobs):
        """Format job status for display"""
        if not jobs:
            return "🟢 No active Globtim jobs"
        
        display = []
        display.append("📊 SLURM Job Status:")
        display.append("=" * 50)
        
        for job in jobs:
            status_emoji = {
                'RUNNING': '🟢',
                'PENDING': '🟡', 
                'COMPLETED': '✅',
                'FAILED': '❌',
                'CANCELLED': '🚫'
            }.get(job['status'], '🔵')
            
            display.append(f"{status_emoji} {job['job_id']} | {job['name']}")
            display.append(f"   Status: {job['status']} | Time: {job['time']}")
            if job['status'] == 'PENDING':
                display.append(f"   Reason: {job['reason']}")
            display.append("")
            
        return '\n'.join(display)
    
    def monitor_continuous(self, interval=30):
        """Continuous monitoring mode"""
        print("🚀 Starting VS Code SLURM Monitor")
        print("Press Ctrl+C to stop")
        print("=" * 60)
        
        try:
            while True:
                # Clear screen (works in VS Code terminal)
                os.system('clear' if os.name == 'posix' else 'cls')
                
                print(f"🕐 Last Update: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                print()
                
                # Get job status
                jobs = self.get_job_status()
                print(self.format_status_display(jobs))
                
                # Check results for completed jobs
                for job in jobs:
                    if job['status'] in ['COMPLETED', 'FAILED']:
                        result = self.get_job_results(job['job_id'])
                        if result:
                            print(f"📋 Results for {job['job_id']}:")
                            if result['status'] == 'SUCCESS':
                                details = result.get('details', {})
                                print(f"   ✅ L2 Error: {details.get('l2_error', 'N/A')}")
                                print(f"   ✅ Minimizers: {details.get('minimizers_count', 'N/A')}")
                                print(f"   ✅ Convergence: {details.get('convergence_rate', 'N/A')}")
                            elif result['status'] == 'FAILED':
                                print(f"   ❌ Error: {result.get('error', 'Unknown error')}")
                            print()
                
                print(f"Next update in {interval} seconds...")
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n👋 Monitoring stopped")
    
    def monitor_single(self, job_id):
        """Monitor a single job"""
        print(f"🎯 Monitoring Job {job_id}")
        
        jobs = self.get_job_status()
        target_job = next((j for j in jobs if j['job_id'] == job_id), None)
        
        if target_job:
            print(self.format_status_display([target_job]))
            
            # Check for results
            result = self.get_job_results(job_id)
            if result:
                print("📋 Job Results:")
                if result['status'] == 'SUCCESS':
                    details = result.get('details', {})
                    for key, value in details.items():
                        print(f"   {key}: {value}")
                elif result['status'] == 'FAILED':
                    print(f"   ❌ Error: {result.get('error', 'Unknown error')}")
                else:
                    print(f"   ⏳ Status: {result['status']}")
        else:
            print(f"❌ Job {job_id} not found in current queue")
            
            # Check if it's completed
            result = self.get_job_results(job_id)
            if result:
                print("📋 Completed Job Results:")
                if result['status'] == 'SUCCESS':
                    details = result.get('details', {})
                    for key, value in details.items():
                        print(f"   {key}: {value}")

def main():
    parser = argparse.ArgumentParser(description='VS Code SLURM Job Monitor')
    parser.add_argument('--continuous', '-c', action='store_true', help='Continuous monitoring mode')
    parser.add_argument('--job', '-j', help='Monitor specific job ID')
    parser.add_argument('--interval', '-i', type=int, default=30, help='Update interval in seconds')
    
    args = parser.parse_args()
    
    monitor = SlurmMonitor()
    
    if args.continuous:
        monitor.monitor_continuous(args.interval)
    elif args.job:
        monitor.monitor_single(args.job)
    else:
        # Single status check
        jobs = monitor.get_job_status()
        print(monitor.format_status_display(jobs))

if __name__ == "__main__":
    main()
