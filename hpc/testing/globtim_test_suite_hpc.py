#!/usr/bin/env python3

"""
Globtim Test Suite HPC Execution
================================

This script specifically runs the Globtim test suite (test/runtests.jl) on the HPC cluster
to validate that the core Julia environment and Globtim package functionality works
correctly with the new NFS depot configuration.

Usage:
    python globtim_test_suite_hpc.py [--timeout MINUTES] [--monitor]
"""

import argparse
import subprocess
import uuid
import time
import json
from datetime import datetime
from pathlib import Path
import sys

class GlobtimTestSuiteRunner:
    def __init__(self, timeout_minutes=30):
        self.test_id = str(uuid.uuid4())[:8]
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.timeout_minutes = timeout_minutes
        self.cluster_user = "scholten"
        self.cluster_host = "falcon"
        self.job_id = None
        
    def log(self, message, level="INFO"):
        """Log message with timestamp"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {level}: {message}")
        
    def run_ssh_command(self, command, timeout=300):
        """Execute command on HPC cluster"""
        ssh_cmd = f"ssh {self.cluster_user}@{self.cluster_host} '{command}'"
        try:
            result = subprocess.run(
                ssh_cmd, 
                shell=True, 
                capture_output=True, 
                text=True, 
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", f"Command timed out after {timeout} seconds"
            
    def create_test_slurm_script(self):
        """Create SLURM script for Globtim test suite"""
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=globtim_test_{self.test_id}
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:45:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=4000
#SBATCH -o globtim_test_{self.test_id}_%j.out
#SBATCH -e globtim_test_{self.test_id}_%j.err

echo "=== Globtim Test Suite - HPC Migration Validation ==="
echo "Test ID: {self.test_id}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Source NFS Julia configuration
echo "=== Configuring Julia Environment ==="
cd ~/globtim_hpc
source ./setup_nfs_julia.sh

# Verify environment is working
echo "=== Environment Verification ==="
echo "Working directory: $(pwd)"
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia version: $(julia --version)"
echo ""

# Check if depot is accessible and has packages
echo "=== Depot Status Check ==="
if [ -d "$JULIA_DEPOT_PATH" ]; then
    echo "✅ Julia depot accessible: $JULIA_DEPOT_PATH"
    echo "Depot size: $(du -sh $JULIA_DEPOT_PATH 2>/dev/null | cut -f1)"
    echo "Package count: $(find $JULIA_DEPOT_PATH -name '*.toml' 2>/dev/null | wc -l)"
else
    echo "❌ Julia depot not accessible: $JULIA_DEPOT_PATH"
    exit 1
fi
echo ""

# Verify Globtim project structure
echo "=== Project Structure Check ==="
if [ -f "Project.toml" ]; then
    echo "✅ Project.toml found"
    echo "Project name: $(grep '^name' Project.toml | cut -d'=' -f2 | tr -d ' "' || echo 'Unknown')"
else
    echo "❌ Project.toml not found"
    exit 1
fi

if [ -f "test/runtests.jl" ]; then
    echo "✅ Test suite found: test/runtests.jl"
else
    echo "❌ Test suite not found: test/runtests.jl"
    exit 1
fi
echo ""

# Run basic Julia functionality test first
echo "=== Basic Julia Functionality Test ==="
julia --project=. -e '
    println("Julia ", VERSION, " on ", gethostname())
    println("Depot paths:")
    for path in DEPOT_PATH
        println("  ", path)
    end
    println()
    
    # Test basic package loading
    try
        using Pkg
        println("✅ Pkg loaded successfully")
        
        # Show project status
        println("Project status:")
        Pkg.status()
    catch e
        println("❌ Error loading Pkg: ", e)
        exit(1)
    end
'

if [ $? -ne 0 ]; then
    echo "❌ Basic Julia functionality test failed"
    exit 1
fi
echo ""

# Run Globtim test suite
echo "=== Running Globtim Test Suite ==="
echo "Command: julia --project=. test/runtests.jl"
echo "Start time: $(date)"
echo ""

# Capture both stdout and stderr, and the exit code
julia --project=. test/runtests.jl
TEST_EXIT_CODE=$?

echo ""
echo "=== Test Suite Results ==="
echo "End time: $(date)"
echo "Exit code: $TEST_EXIT_CODE"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ Globtim test suite PASSED"
else
    echo "❌ Globtim test suite FAILED with exit code $TEST_EXIT_CODE"
fi

echo ""
echo "=== Job Summary ==="
echo "Test ID: {self.test_id}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Duration: $SECONDS seconds"
echo "Final status: $([ $TEST_EXIT_CODE -eq 0 ] && echo 'SUCCESS' || echo 'FAILURE')"
echo ""
echo "=== End of Job ==="

# Exit with the same code as the test suite
exit $TEST_EXIT_CODE
"""
        return slurm_script
        
    def submit_test_job(self):
        """Submit the Globtim test suite job to SLURM"""
        self.log("📝 Creating SLURM script for Globtim test suite...")
        
        slurm_script = self.create_test_slurm_script()
        script_filename = f"globtim_test_{self.test_id}.slurm"
        
        # Create script on cluster
        create_script_cmd = f"cd ~/globtim_hpc && cat > {script_filename} << 'EOF'\n{slurm_script}\nEOF"
        returncode, stdout, stderr = self.run_ssh_command(create_script_cmd)
        
        if returncode != 0:
            self.log(f"❌ Failed to create SLURM script: {stderr}", "ERROR")
            return False
            
        self.log("✅ SLURM script created successfully")
        
        # Submit job
        self.log("🚀 Submitting job to SLURM...")
        submit_cmd = f"cd ~/globtim_hpc && sbatch {script_filename}"
        returncode, stdout, stderr = self.run_ssh_command(submit_cmd)
        
        if returncode != 0:
            self.log(f"❌ Failed to submit job: {stderr}", "ERROR")
            return False
            
        # Extract job ID
        self.job_id = stdout.strip().split()[-1]
        self.log(f"✅ Job submitted successfully!")
        self.log(f"📋 SLURM Job ID: {self.job_id}")
        self.log(f"🔧 Test ID: {self.test_id}")
        
        return True
        
    def monitor_job(self):
        """Monitor job progress until completion"""
        if not self.job_id:
            self.log("❌ No job ID available for monitoring", "ERROR")
            return False
            
        self.log(f"⏳ Monitoring job {self.job_id} for completion...")
        self.log(f"⏰ Timeout: {self.timeout_minutes} minutes")
        
        start_time = time.time()
        timeout_seconds = self.timeout_minutes * 60
        check_interval = 30  # Check every 30 seconds
        
        while time.time() - start_time < timeout_seconds:
            # Check job status
            returncode, stdout, stderr = self.run_ssh_command(f"squeue -j {self.job_id}")
            
            if returncode != 0 or self.job_id not in stdout:
                # Job completed (no longer in queue)
                elapsed_time = int(time.time() - start_time)
                self.log(f"✅ Job {self.job_id} completed (elapsed: {elapsed_time}s)")
                return True
                
            elapsed_time = int(time.time() - start_time)
            self.log(f"⏳ Job {self.job_id} still running (elapsed: {elapsed_time}s)")
            time.sleep(check_interval)
            
        self.log(f"⚠️ Job {self.job_id} monitoring timed out after {self.timeout_minutes} minutes", "WARNING")
        return False
        
    def collect_results(self):
        """Collect and analyze job results"""
        if not self.job_id:
            self.log("❌ No job ID available for result collection", "ERROR")
            return None
            
        self.log("📊 Collecting job results...")
        
        # Get output files
        output_file = f"globtim_test_{self.test_id}_{self.job_id}.out"
        error_file = f"globtim_test_{self.test_id}_{self.job_id}.err"
        
        # Collect stdout
        returncode, stdout, stderr = self.run_ssh_command(f"cd ~/globtim_hpc && cat {output_file} 2>/dev/null")
        job_stdout = stdout if returncode == 0 else "Output file not found"
        
        # Collect stderr  
        returncode, stdout, stderr = self.run_ssh_command(f"cd ~/globtim_hpc && cat {error_file} 2>/dev/null")
        job_stderr = stdout if returncode == 0 else "Error file not found"
        
        # Analyze results
        results = {
            "test_id": self.test_id,
            "job_id": self.job_id,
            "timestamp": self.timestamp,
            "stdout": job_stdout,
            "stderr": job_stderr,
            "analysis": self.analyze_output(job_stdout, job_stderr)
        }
        
        return results
        
    def analyze_output(self, stdout, stderr):
        """Analyze job output to determine success/failure"""
        analysis = {
            "job_completed": False,
            "test_suite_passed": False,
            "julia_working": False,
            "depot_accessible": False,
            "project_found": False,
            "errors": [],
            "warnings": []
        }
        
        if "End of Job" in stdout:
            analysis["job_completed"] = True
            
        if "✅ Globtim test suite PASSED" in stdout:
            analysis["test_suite_passed"] = True
        elif "❌ Globtim test suite FAILED" in stdout:
            analysis["test_suite_passed"] = False
            analysis["errors"].append("Globtim test suite failed")
            
        if "✅ Pkg loaded successfully" in stdout:
            analysis["julia_working"] = True
            
        if "✅ Julia depot accessible" in stdout:
            analysis["depot_accessible"] = True
        elif "❌ Julia depot not accessible" in stdout:
            analysis["depot_accessible"] = False
            analysis["errors"].append("Julia depot not accessible")
            
        if "✅ Project.toml found" in stdout:
            analysis["project_found"] = True
        elif "❌ Project.toml not found" in stdout:
            analysis["project_found"] = False
            analysis["errors"].append("Project.toml not found")
            
        # Check for common error patterns
        error_patterns = [
            "ERROR: LoadError:",
            "BoundsError:",
            "MethodError:",
            "UndefVarError:",
            "Package not found"
        ]
        
        for pattern in error_patterns:
            if pattern in stdout or pattern in stderr:
                analysis["errors"].append(f"Found error pattern: {pattern}")
                
        return analysis
        
    def generate_report(self, results):
        """Generate human-readable test report"""
        print("\n" + "="*60)
        print("  GLOBTIM TEST SUITE - HPC VALIDATION RESULTS")
        print("="*60)
        print(f"Test ID: {results['test_id']}")
        print(f"Job ID: {results['job_id']}")
        print(f"Timestamp: {results['timestamp']}")
        print()
        
        analysis = results["analysis"]
        
        # Overall status
        if analysis["test_suite_passed"] and analysis["job_completed"]:
            print("🎉 OVERALL STATUS: SUCCESS")
            print("✅ Globtim test suite passed on HPC cluster")
        else:
            print("❌ OVERALL STATUS: FAILURE")
            print("❌ Globtim test suite failed or did not complete")
            
        print()
        print("📋 Detailed Results:")
        
        status_items = [
            ("Job Completed", analysis["job_completed"]),
            ("Test Suite Passed", analysis["test_suite_passed"]),
            ("Julia Working", analysis["julia_working"]),
            ("Depot Accessible", analysis["depot_accessible"]),
            ("Project Found", analysis["project_found"])
        ]
        
        for item_name, status in status_items:
            emoji = "✅" if status else "❌"
            print(f"  {emoji} {item_name}: {'PASS' if status else 'FAIL'}")
            
        if analysis["errors"]:
            print()
            print("❌ Errors Found:")
            for error in analysis["errors"]:
                print(f"  • {error}")
                
        if analysis["warnings"]:
            print()
            print("⚠️ Warnings:")
            for warning in analysis["warnings"]:
                print(f"  • {warning}")
                
        print()
        print("="*60)
        
        # Save detailed results
        results_file = f"globtim_test_results_{results['test_id']}.json"
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"📄 Detailed results saved to: {results_file}")
        print("="*60)
        
        return analysis["test_suite_passed"] and analysis["job_completed"]

def main():
    parser = argparse.ArgumentParser(description="Run Globtim test suite on HPC cluster")
    parser.add_argument("--timeout", type=int, default=30, 
                       help="Timeout in minutes for job completion (default: 30)")
    parser.add_argument("--monitor", action="store_true", 
                       help="Monitor job until completion")
    parser.add_argument("--submit-only", action="store_true",
                       help="Only submit job, don't monitor or collect results")
    
    args = parser.parse_args()
    
    print("🧪 Globtim Test Suite - HPC Cluster Validation")
    print(f"Timeout: {args.timeout} minutes")
    print(f"Monitor: {'Yes' if args.monitor else 'No'}")
    print()
    
    runner = GlobtimTestSuiteRunner(timeout_minutes=args.timeout)
    
    try:
        # Submit job
        if not runner.submit_test_job():
            return 1
            
        if args.submit_only:
            print(f"✅ Job submitted successfully (ID: {runner.job_id})")
            print("Use --monitor flag to wait for completion and analyze results")
            return 0
            
        # Monitor job if requested
        if args.monitor:
            if not runner.monitor_job():
                print("⚠️ Job monitoring timed out, but job may still be running")
                print(f"Check manually with: ssh falcon 'squeue -j {runner.job_id}'")
                return 1
                
        # Collect and analyze results
        results = runner.collect_results()
        if results is None:
            return 1
            
        # Generate report
        success = runner.generate_report(results)
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\n⚠️ Testing interrupted by user")
        if runner.job_id:
            print(f"Job {runner.job_id} may still be running on the cluster")
        return 1
    except Exception as e:
        print(f"\n❌ Testing failed with error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
