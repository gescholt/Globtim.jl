#!/usr/bin/env python3

"""
Automated Job Monitor and Output Collector
==========================================

Monitors SLURM jobs at regular intervals and automatically collects outputs
when jobs complete. Improves upon existing monitoring infrastructure.

Usage:
    python automated_job_monitor.py --job-id JOB_ID [--interval SECONDS]
    python automated_job_monitor.py --test-id TEST_ID [--interval SECONDS]
"""

import argparse
import subprocess
import time
import json
from pathlib import Path
from datetime import datetime
import os
import sys

class AutomatedJobMonitor:
    def __init__(self, cluster_host="scholten@falcon", remote_dir="~/globtim_hpc"):
        self.cluster_host = cluster_host
        self.remote_dir = remote_dir
        self.local_results_dir = Path("collected_results")
        self.local_results_dir.mkdir(exist_ok=True)
        
    def run_ssh_command(self, command):
        """Execute SSH command and return output"""
        try:
            result = subprocess.run(
                ["ssh", self.cluster_host, command],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                print(f"⚠️  SSH command failed: {result.stderr}")
                return None
        except subprocess.TimeoutExpired:
            print("⚠️  SSH command timed out")
            return None
        except Exception as e:
            print(f"⚠️  SSH error: {e}")
            return None
    
    def get_job_status(self, job_id):
        """Get current job status from SLURM"""
        command = f"sacct -j {job_id} --format=JobID,JobName,State,ExitCode,Start,End,Elapsed --parsable2 --noheader"
        output = self.run_ssh_command(command)
        
        if not output:
            return None
            
        lines = output.split('\n')
        for line in lines:
            if line.strip() and not line.endswith('.batch') and not line.endswith('.extern'):
                parts = line.split('|')
                if len(parts) >= 7:
                    return {
                        'job_id': parts[0],
                        'name': parts[1],
                        'state': parts[2],
                        'exit_code': parts[3],
                        'start_time': parts[4],
                        'end_time': parts[5],
                        'elapsed': parts[6]
                    }
        return None
    
    def find_job_files(self, job_id, test_id=None):
        """Find all files related to a job"""
        files = {}
        
        # Common patterns for job files
        patterns = [
            f"*{job_id}*",
            f"*{test_id}*" if test_id else None
        ]
        
        for pattern in patterns:
            if pattern:
                command = f"find {self.remote_dir} -name '{pattern}' -type f 2>/dev/null"
                output = self.run_ssh_command(command)
                if output:
                    for file_path in output.split('\n'):
                        if file_path.strip():
                            file_name = os.path.basename(file_path)
                            files[file_name] = file_path
        
        return files
    
    def collect_job_outputs(self, job_id, test_id=None):
        """Collect all outputs from a completed job"""
        print(f"📁 Collecting outputs for job {job_id}...")
        
        # Create local directory for this job
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        local_job_dir = self.local_results_dir / f"job_{job_id}_{timestamp}"
        local_job_dir.mkdir(exist_ok=True)
        
        # Find all related files
        job_files = self.find_job_files(job_id, test_id)
        
        if not job_files:
            print(f"⚠️  No files found for job {job_id}")
            return local_job_dir
        
        print(f"📄 Found {len(job_files)} files to collect:")
        
        collected_files = {}
        for file_name, remote_path in job_files.items():
            print(f"  📥 Collecting {file_name}...")
            
            local_file_path = local_job_dir / file_name
            scp_command = ["scp", f"{self.cluster_host}:{remote_path}", str(local_file_path)]
            
            try:
                result = subprocess.run(scp_command, capture_output=True, text=True)
                if result.returncode == 0:
                    collected_files[file_name] = str(local_file_path)
                    print(f"    ✅ {file_name} collected")
                else:
                    print(f"    ❌ Failed to collect {file_name}: {result.stderr}")
            except Exception as e:
                print(f"    ❌ Error collecting {file_name}: {e}")
        
        # Create collection summary
        summary = {
            "job_id": job_id,
            "test_id": test_id,
            "collection_timestamp": datetime.now().isoformat(),
            "local_directory": str(local_job_dir),
            "collected_files": collected_files,
            "total_files": len(collected_files)
        }
        
        summary_file = local_job_dir / "collection_summary.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)
        
        print(f"✅ Collection complete! {len(collected_files)} files saved to {local_job_dir}")
        return local_job_dir
    
    def monitor_job(self, job_id, test_id=None, interval=15, max_wait_time=3600):
        """Monitor a job until completion and collect outputs"""
        print(f"🚀 Starting automated monitoring for job {job_id}")
        print(f"📊 Check interval: {interval} seconds")
        print(f"⏰ Maximum wait time: {max_wait_time} seconds")
        print(f"🔧 Test ID: {test_id or 'Unknown'}")
        print("=" * 60)
        
        start_time = time.time()
        last_status = None
        
        try:
            while True:
                current_time = time.time()
                elapsed = current_time - start_time
                
                # Check if we've exceeded maximum wait time
                if elapsed > max_wait_time:
                    print(f"\n⏰ Maximum wait time ({max_wait_time}s) exceeded")
                    print("Job monitoring stopped, but job may still be running")
                    break
                
                # Get current job status
                status = self.get_job_status(job_id)
                
                if not status:
                    print(f"⚠️  Could not get status for job {job_id}")
                    time.sleep(interval)
                    continue
                
                # Print status if it changed
                if status != last_status:
                    timestamp = datetime.now().strftime("%H:%M:%S")
                    print(f"[{timestamp}] Job {job_id}: {status['state']}")
                    
                    if status['state'] not in ['PENDING', 'RUNNING']:
                        print(f"  Exit code: {status['exit_code']}")
                        print(f"  Elapsed time: {status['elapsed']}")
                    
                    last_status = status
                
                # Check if job is complete
                if status['state'] in ['COMPLETED', 'FAILED', 'CANCELLED', 'TIMEOUT']:
                    print(f"\n🏁 Job {job_id} finished with state: {status['state']}")
                    
                    # Collect outputs
                    local_dir = self.collect_job_outputs(job_id, test_id)
                    
                    # Create final summary
                    final_summary = {
                        "monitoring_summary": {
                            "job_id": job_id,
                            "test_id": test_id,
                            "final_state": status['state'],
                            "exit_code": status['exit_code'],
                            "elapsed_time": status['elapsed'],
                            "monitoring_duration": f"{elapsed:.1f}s",
                            "collection_directory": str(local_dir)
                        },
                        "job_details": status
                    }
                    
                    summary_file = local_dir / "monitoring_summary.json"
                    with open(summary_file, 'w') as f:
                        json.dump(final_summary, f, indent=2)
                    
                    print(f"\n🎯 MONITORING COMPLETE!")
                    print(f"📁 Results collected in: {local_dir}")
                    print(f"📊 Final status: {status['state']} (exit code: {status['exit_code']})")
                    
                    return local_dir, status
                
                # Wait before next check
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print(f"\n👋 Monitoring interrupted by user")
            print(f"Job {job_id} may still be running")
            return None, None
        except Exception as e:
            print(f"\n❌ Monitoring error: {e}")
            return None, None
    
    def quick_collect(self, job_id, test_id=None):
        """Quickly collect outputs without monitoring (for already completed jobs)"""
        print(f"📥 Quick collection for job {job_id}")
        
        # Check job status first
        status = self.get_job_status(job_id)
        if status:
            print(f"Job status: {status['state']} (exit code: {status['exit_code']})")
        
        # Collect outputs
        local_dir = self.collect_job_outputs(job_id, test_id)
        
        print(f"✅ Quick collection complete: {local_dir}")
        return local_dir

def main():
    parser = argparse.ArgumentParser(description="Automated job monitoring and output collection")
    parser.add_argument("--job-id", required=True, help="SLURM job ID to monitor")
    parser.add_argument("--test-id", help="Test ID for better file identification")
    parser.add_argument("--interval", type=int, default=15, help="Check interval in seconds (default: 15)")
    parser.add_argument("--max-wait", type=int, default=3600, help="Maximum wait time in seconds (default: 3600)")
    parser.add_argument("--quick", action="store_true", help="Quick collection without monitoring")
    
    args = parser.parse_args()
    
    monitor = AutomatedJobMonitor()
    
    if args.quick:
        local_dir = monitor.quick_collect(args.job_id, args.test_id)
    else:
        local_dir, status = monitor.monitor_job(
            args.job_id, 
            args.test_id, 
            args.interval, 
            args.max_wait
        )
    
    if local_dir:
        print(f"\n📁 Results available in: {local_dir}")
    else:
        print(f"\n❌ Collection failed or was interrupted")
        sys.exit(1)

if __name__ == "__main__":
    main()
