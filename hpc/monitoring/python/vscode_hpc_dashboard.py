#!/usr/bin/env python3
"""
VS Code HPC Dashboard

Local VS Code integration for monitoring remote SLURM jobs.
Works from your local machine via SSH to the HPC cluster.
"""

import subprocess
import time
import json
import os
import sys
from datetime import datetime
import threading
import signal

class VSCodeHPCDashboard:
    def __init__(self):
        self.ssh_host = "scholten@falcon"
        self.work_dir = "~/globtim_hpc"
        self.running = True
        self.current_jobs = {}
        
    def run_ssh_command(self, command):
        """Execute command on HPC cluster via SSH"""
        full_command = f'ssh -o ConnectTimeout=10 -o BatchMode=yes {self.ssh_host} "cd {self.work_dir} && {command}"'
        try:
            result = subprocess.run(full_command, shell=True, capture_output=True, text=True, timeout=15)
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                return None
        except:
            return None
    
    def get_job_status(self):
        """Get current SLURM job status"""
        command = "squeue -u $USER --format='%.10i %.15j %.8T %.10M %.6D %R' --noheader 2>/dev/null"
        output = self.run_ssh_command(command)
        
        if not output:
            return []
            
        jobs = []
        for line in output.split('\n'):
            if line.strip() and ('globtim' in line.lower() or 'working_' in line.lower() or 'params_' in line.lower()):
                parts = line.split()
                if len(parts) >= 6:
                    jobs.append({
                        'job_id': parts[0],
                        'name': parts[1],
                        'status': parts[2],
                        'time': parts[3],
                        'nodes': parts[4],
                        'reason': ' '.join(parts[5:]) if len(parts) > 5 else ''
                    })
        return jobs
    
    def get_recent_jobs(self):
        """Get recently completed jobs"""
        command = "sacct -u $USER --starttime=today --format=JobID,JobName,State,ExitCode,End --parsable2 --noheader 2>/dev/null | grep -E '(globtim|working_|params_)' | grep -v '.batch\\|.extern'"
        output = self.run_ssh_command(command)
        
        if not output:
            return []
            
        jobs = []
        for line in output.split('\n'):
            if line.strip():
                parts = line.split('|')
                if len(parts) >= 5:
                    jobs.append({
                        'job_id': parts[0],
                        'name': parts[1],
                        'status': parts[2],
                        'exit_code': parts[3],
                        'end_time': parts[4]
                    })
        return jobs[:5]  # Last 5 jobs
    
    def check_job_results(self, job_id):
        """Check for job results"""
        command = f"find results/experiments -name '*{job_id}*' -type d 2>/dev/null | head -1"
        job_dir = self.run_ssh_command(command)
        
        if not job_dir:
            return None
            
        # Check for success/error files
        success_cmd = f"find {job_dir} -name '*success*.txt' 2>/dev/null | head -1"
        success_file = self.run_ssh_command(success_cmd)
        
        if success_file:
            content_cmd = f"cat {success_file} 2>/dev/null"
            content = self.run_ssh_command(content_cmd)
            if content:
                return {'status': 'SUCCESS', 'content': content}
        
        error_cmd = f"find {job_dir} -name '*error*.txt' 2>/dev/null | head -1"
        error_file = self.run_ssh_command(error_cmd)
        
        if error_file:
            content_cmd = f"cat {error_file} 2>/dev/null"
            content = self.run_ssh_command(content_cmd)
            if content:
                return {'status': 'FAILED', 'content': content}
                
        return {'status': 'IN_PROGRESS'}
    
    def format_vscode_output(self, jobs, recent_jobs):
        """Format output for VS Code terminal"""
        output = []
        
        # Header
        output.append("🎯 HPC Job Dashboard")
        output.append("=" * 50)
        output.append(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        output.append("")
        
        # Current jobs
        if jobs:
            output.append("🔄 Active Jobs:")
            for job in jobs:
                status_emoji = {
                    'RUNNING': '🟢',
                    'PENDING': '🟡', 
                    'COMPLETED': '✅',
                    'FAILED': '❌'
                }.get(job['status'], '🔵')
                
                output.append(f"  {status_emoji} {job['job_id']} | {job['name']}")
                output.append(f"     Status: {job['status']} | Time: {job['time']}")
                if job['status'] == 'PENDING':
                    output.append(f"     Reason: {job['reason']}")
                output.append("")
        else:
            output.append("✅ No active jobs")
            output.append("")
        
        # Recent completions
        if recent_jobs:
            output.append("📋 Recent Completions:")
            for job in recent_jobs:
                status_emoji = '✅' if job['status'] == 'COMPLETED' else '❌'
                output.append(f"  {status_emoji} {job['job_id']} | {job['name']}")
                output.append(f"     Status: {job['status']} | Exit: {job['exit_code']}")
                
                # Check for results
                results = self.check_job_results(job['job_id'])
                if results and results['status'] == 'SUCCESS':
                    output.append("     🎉 Results available!")
                elif results and results['status'] == 'FAILED':
                    output.append("     ❌ Job failed - check logs")
                output.append("")
        
        return '\n'.join(output)
    
    def monitor_once(self):
        """Single monitoring check"""
        jobs = self.get_job_status()
        recent_jobs = self.get_recent_jobs()
        
        output = self.format_vscode_output(jobs, recent_jobs)
        print(output)
        
        # Return status for VS Code tasks
        active_count = len(jobs)
        completed_count = len([j for j in recent_jobs if j['status'] == 'COMPLETED'])
        failed_count = len([j for j in recent_jobs if j['status'] == 'FAILED'])
        
        return {
            'active': active_count,
            'completed': completed_count,
            'failed': failed_count
        }
    
    def monitor_continuous(self, interval=30):
        """Continuous monitoring for VS Code terminal"""
        print("🚀 Starting HPC Job Monitor")
        print("Press Ctrl+C to stop")
        print("=" * 50)
        
        def signal_handler(sig, frame):
            print("\n👋 Stopping monitor...")
            self.running = False
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        
        try:
            while self.running:
                # Clear screen for VS Code terminal
                os.system('clear' if os.name == 'posix' else 'cls')
                
                status = self.monitor_once()
                
                print(f"\n⏰ Next update in {interval} seconds...")
                print(f"📊 Active: {status['active']} | Completed: {status['completed']} | Failed: {status['failed']}")
                
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n👋 Monitor stopped")

def main():
    dashboard = VSCodeHPCDashboard()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == '--continuous':
            interval = int(sys.argv[2]) if len(sys.argv) > 2 else 30
            dashboard.monitor_continuous(interval)
        elif sys.argv[1] == '--json':
            # JSON output for VS Code extensions
            jobs = dashboard.get_job_status()
            recent_jobs = dashboard.get_recent_jobs()
            print(json.dumps({
                'active_jobs': jobs,
                'recent_jobs': recent_jobs,
                'timestamp': datetime.now().isoformat()
            }))
        else:
            print("Usage: python3 vscode_hpc_dashboard.py [--continuous [interval] | --json]")
    else:
        dashboard.monitor_once()

if __name__ == "__main__":
    main()
