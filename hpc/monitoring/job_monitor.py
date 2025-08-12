#!/usr/bin/env python3
"""
HPC Job Monitoring System for GlobTim
Automated monitoring, output collection, and result analysis for SLURM jobs
"""

import subprocess
import json
import time
import argparse
import os
from datetime import datetime
from pathlib import Path
import re
from typing import Dict, List, Optional, Tuple

class HPCJobMonitor:
    """Monitor and collect outputs from HPC jobs"""
    
    def __init__(self, ssh_host="scholten@falcon", remote_dir="/home/scholten"):
        self.ssh_host = ssh_host
        self.remote_dir = remote_dir
        self.local_results_dir = Path("hpc/monitoring/results")
        self.local_results_dir.mkdir(parents=True, exist_ok=True)
        
    def submit_job(self, slurm_script: str, job_name: Optional[str] = None) -> Optional[int]:
        """Submit a SLURM job and return job ID"""
        try:
            # Copy script to remote
            script_name = Path(slurm_script).name
            scp_cmd = f"scp {slurm_script} {self.ssh_host}:{self.remote_dir}/"
            subprocess.run(scp_cmd, shell=True, check=True, capture_output=True)
            
            # Submit job
            submit_cmd = f"ssh {self.ssh_host} 'cd {self.remote_dir} && sbatch {script_name}'"
            result = subprocess.run(submit_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                # Extract job ID from output like "Submitted batch job 12345"
                match = re.search(r'Submitted batch job (\d+)', result.stdout)
                if match:
                    job_id = int(match.group(1))
                    print(f"✅ Submitted job {job_id}: {job_name or script_name}")
                    return job_id
            else:
                print(f"❌ Failed to submit job: {result.stderr}")
                return None
                
        except Exception as e:
            print(f"❌ Error submitting job: {e}")
            return None
    
    def get_job_status(self, job_id: int) -> Dict:
        """Get current status of a job"""
        try:
            cmd = f"ssh {self.ssh_host} 'squeue -j {job_id} --format=\"%i|%T|%M|%N|%r\" -h'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.stdout.strip():
                parts = result.stdout.strip().split('|')
                return {
                    'job_id': job_id,
                    'state': parts[1] if len(parts) > 1 else 'UNKNOWN',
                    'time': parts[2] if len(parts) > 2 else '0:00',
                    'node': parts[3] if len(parts) > 3 else 'N/A',
                    'reason': parts[4] if len(parts) > 4 else ''
                }
            else:
                # Job not in queue, check if completed
                return self.get_completed_job_info(job_id)
                
        except Exception as e:
            print(f"Error getting job status: {e}")
            return {'job_id': job_id, 'state': 'ERROR', 'error': str(e)}
    
    def get_completed_job_info(self, job_id: int) -> Dict:
        """Get information about a completed job"""
        try:
            cmd = f"ssh {self.ssh_host} 'sacct -j {job_id} --format=\"JobID,State,ExitCode,Elapsed\" -n -X'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.stdout.strip():
                parts = result.stdout.strip().split()
                state = parts[1] if len(parts) > 1 else 'UNKNOWN'
                exit_code = parts[2] if len(parts) > 2 else '0:0'
                elapsed = parts[3] if len(parts) > 3 else '00:00:00'
                
                return {
                    'job_id': job_id,
                    'state': state,
                    'exit_code': exit_code,
                    'elapsed': elapsed,
                    'completed': True
                }
            else:
                return {'job_id': job_id, 'state': 'NOT_FOUND'}
                
        except Exception as e:
            return {'job_id': job_id, 'state': 'ERROR', 'error': str(e)}
    
    def get_job_output(self, job_id: int, tail_lines: int = 100) -> Tuple[str, str]:
        """Get stdout and stderr from a job"""
        try:
            # Try different output file patterns
            patterns = [
                f"*{job_id}.out",
                f"*_{job_id}.out",
                f"slurm-{job_id}.out"
            ]
            
            stdout_content = ""
            stderr_content = ""
            
            for pattern in patterns:
                cmd_out = f"ssh {self.ssh_host} 'tail -n {tail_lines} {self.remote_dir}/{pattern} 2>/dev/null'"
                result = subprocess.run(cmd_out, shell=True, capture_output=True, text=True)
                if result.stdout:
                    stdout_content = result.stdout
                    break
            
            # Similar for stderr
            patterns_err = [p.replace('.out', '.err') for p in patterns]
            for pattern in patterns_err:
                cmd_err = f"ssh {self.ssh_host} 'tail -n {tail_lines} {self.remote_dir}/{pattern} 2>/dev/null'"
                result = subprocess.run(cmd_err, shell=True, capture_output=True, text=True)
                if result.stdout:
                    stderr_content = result.stdout
                    break
                    
            return stdout_content, stderr_content
            
        except Exception as e:
            print(f"Error getting job output: {e}")
            return "", ""
    
    def monitor_job(self, job_id: int, interval: int = 30, max_wait: int = 3600) -> Dict:
        """Monitor a job until completion"""
        print(f"\n📊 Monitoring job {job_id}")
        print("=" * 50)
        
        start_time = time.time()
        last_state = None
        
        while time.time() - start_time < max_wait:
            status = self.get_job_status(job_id)
            current_state = status.get('state', 'UNKNOWN')
            
            # Print status update if state changed
            if current_state != last_state:
                timestamp = datetime.now().strftime("%H:%M:%S")
                if current_state == 'RUNNING':
                    print(f"[{timestamp}] 🏃 Job {job_id} is RUNNING on {status.get('node', 'unknown')}")
                elif current_state == 'PENDING':
                    print(f"[{timestamp}] ⏳ Job {job_id} is PENDING: {status.get('reason', '')}")
                elif current_state in ['COMPLETED', 'FAILED', 'CANCELLED', 'TIMEOUT']:
                    print(f"[{timestamp}] 🏁 Job {job_id} {current_state}: {status.get('exit_code', '')}")
                    break
                else:
                    print(f"[{timestamp}] ❓ Job {job_id} state: {current_state}")
                
                last_state = current_state
            
            # Check for completion
            if status.get('completed', False) or current_state in ['COMPLETED', 'FAILED', 'CANCELLED', 'TIMEOUT', 'NOT_FOUND']:
                break
                
            time.sleep(interval)
        
        # Get final output
        stdout, stderr = self.get_job_output(job_id)
        
        # Prepare result
        result = {
            'job_id': job_id,
            'final_status': status,
            'stdout': stdout,
            'stderr': stderr,
            'monitoring_duration': time.time() - start_time,
            'timestamp': datetime.now().isoformat()
        }
        
        # Save result
        self.save_result(job_id, result)
        
        return result
    
    def save_result(self, job_id: int, result: Dict):
        """Save job result to local file"""
        filename = self.local_results_dir / f"job_{job_id}_result.json"
        with open(filename, 'w') as f:
            json.dump(result, f, indent=2, default=str)
        print(f"💾 Result saved to {filename}")
    
    def collect_remote_files(self, job_id: int, patterns: List[str] = None):
        """Collect output files from remote system"""
        if patterns is None:
            patterns = [f"*{job_id}*"]
        
        collected_dir = self.local_results_dir / f"job_{job_id}_files"
        collected_dir.mkdir(exist_ok=True)
        
        for pattern in patterns:
            cmd = f"scp {self.ssh_host}:{self.remote_dir}/{pattern} {collected_dir}/ 2>/dev/null"
            result = subprocess.run(cmd, shell=True, capture_output=True)
            if result.returncode == 0:
                print(f"📥 Collected files matching {pattern}")
    
    def check_compilation_success(self, job_id: int) -> bool:
        """Check if GlobTim compilation was successful"""
        stdout, stderr = self.get_job_output(job_id, tail_lines=500)
        
        # Success indicators
        success_patterns = [
            "GlobTim modules loaded successfully",
            "Test completed successfully",
            "Compilation successful",
            "✅",
            "using GlobTim"
        ]
        
        # Failure indicators
        failure_patterns = [
            "ERROR:",
            "LoadError",
            "MethodError",
            "UndefVarError",
            "Failed to precompile",
            "Exit code: [1-9]",
            "FAILED"
        ]
        
        # Check for success
        success_found = any(pattern in stdout for pattern in success_patterns)
        
        # Check for failures
        failure_found = any(pattern in stdout or pattern in stderr for pattern in failure_patterns)
        
        # Analyze exit code from status
        status = self.get_job_status(job_id)
        exit_code = status.get('exit_code', '0:0')
        if ':' in exit_code:
            main_exit, signal = exit_code.split(':')
            if int(main_exit) != 0:
                failure_found = True
        
        return success_found and not failure_found
    
    def generate_report(self, job_ids: List[int]) -> Dict:
        """Generate summary report for multiple jobs"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'total_jobs': len(job_ids),
            'successful': 0,
            'failed': 0,
            'jobs': []
        }
        
        for job_id in job_ids:
            success = self.check_compilation_success(job_id)
            status = self.get_job_status(job_id)
            
            job_info = {
                'job_id': job_id,
                'status': status.get('state', 'UNKNOWN'),
                'compilation_success': success,
                'exit_code': status.get('exit_code', 'N/A')
            }
            
            report['jobs'].append(job_info)
            
            if success:
                report['successful'] += 1
            else:
                report['failed'] += 1
        
        return report


def create_simple_compilation_test() -> str:
    """Create a simple SLURM script to test GlobTim compilation"""
    script_content = '''#!/bin/bash
#SBATCH --job-name=globtim_compile_test
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:15:00
#SBATCH --mem=8G
#SBATCH --output=globtim_compile_%j.out
#SBATCH --error=globtim_compile_%j.err

echo "GlobTim Compilation Test"
echo "Job ID: $SLURM_JOB_ID"
echo "Start time: $(date)"
echo ""

# Extract bundle
WORK_DIR="/tmp/globtim_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR && cd $WORK_DIR
tar -xzf /home/scholten/globtim_hpc_bundle.tar.gz

# Set environment
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_NO_NETWORK="1"

# Test compilation
echo "Testing GlobTim compilation..."
/sw/bin/julia --project=. -e '
    println("Loading GlobTim packages...")
    using Pkg
    
    # Test core dependencies
    using ForwardDiff
    using StaticArrays
    using DynamicPolynomials
    using TimerOutputs
    println("✅ Core dependencies loaded")
    
    # Load GlobTim modules
    include("src/BenchmarkFunctions.jl")
    include("src/LibFunctions.jl")
    include("src/Samples.jl")
    include("src/Structures.jl")
    println("✅ GlobTim modules loaded successfully")
    
    # Test basic functionality
    test_point = [0.5, 0.5]
    result = Deuflhard(test_point)
    println("✅ Function evaluation: Deuflhard($test_point) = $result")
    
    println("✅ Compilation test completed successfully!")
'

EXIT_CODE=$?
echo ""
echo "Exit code: $EXIT_CODE"
echo "End time: $(date)"

# Cleanup
cd /tmp && rm -rf $WORK_DIR
exit $EXIT_CODE
'''
    
    # Save script
    script_path = Path("hpc/jobs/submission/test_compilation_auto.slurm")
    script_path.parent.mkdir(parents=True, exist_ok=True)
    script_path.write_text(script_content)
    
    return str(script_path)


def main():
    parser = argparse.ArgumentParser(description='HPC Job Monitor for GlobTim')
    parser.add_argument('--submit', action='store_true', help='Submit a test compilation job')
    parser.add_argument('--monitor', type=int, help='Monitor a specific job ID')
    parser.add_argument('--check', type=int, help='Check compilation success for job ID')
    parser.add_argument('--report', nargs='+', type=int, help='Generate report for job IDs')
    parser.add_argument('--interval', type=int, default=30, help='Monitoring interval in seconds')
    
    args = parser.parse_args()
    
    monitor = HPCJobMonitor()
    
    if args.submit:
        # Create and submit test job
        script_path = create_simple_compilation_test()
        print(f"📝 Created test script: {script_path}")
        
        job_id = monitor.submit_job(script_path, "GlobTim Compilation Test")
        if job_id:
            print(f"\n🚀 Submitted job {job_id}")
            
            # Monitor the job
            result = monitor.monitor_job(job_id, interval=args.interval)
            
            # Check compilation success
            success = monitor.check_compilation_success(job_id)
            print(f"\n{'✅' if success else '❌'} Compilation {'successful' if success else 'failed'}")
            
            # Collect output files
            monitor.collect_remote_files(job_id)
            
    elif args.monitor:
        result = monitor.monitor_job(args.monitor, interval=args.interval)
        success = monitor.check_compilation_success(args.monitor)
        print(f"\n{'✅' if success else '❌'} Compilation {'successful' if success else 'failed'}")
        
    elif args.check:
        success = monitor.check_compilation_success(args.check)
        status = monitor.get_job_status(args.check)
        print(f"Job {args.check}: {status.get('state', 'UNKNOWN')}")
        print(f"Compilation: {'✅ Success' if success else '❌ Failed'}")
        
    elif args.report:
        report = monitor.generate_report(args.report)
        print("\n📊 JOB REPORT")
        print("=" * 40)
        print(f"Total jobs: {report['total_jobs']}")
        print(f"Successful: {report['successful']} ✅")
        print(f"Failed: {report['failed']} ❌")
        print("\nDetails:")
        for job in report['jobs']:
            status_icon = '✅' if job['compilation_success'] else '❌'
            print(f"  Job {job['job_id']}: {job['status']} {status_icon}")
        
        # Save report
        report_file = Path(f"hpc/monitoring/results/report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
        report_file.parent.mkdir(parents=True, exist_ok=True)
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\n💾 Report saved to {report_file}")
    
    else:
        print("Usage: python job_monitor.py [--submit] [--monitor JOB_ID] [--check JOB_ID] [--report JOB_IDS...]")


if __name__ == "__main__":
    main()