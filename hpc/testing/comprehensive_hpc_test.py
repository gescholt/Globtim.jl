#!/usr/bin/env python3

"""
Comprehensive Julia HPC Migration Testing Suite
==============================================

This script systematically validates the Julia HPC migration by running
comprehensive tests on the cluster infrastructure.

Testing Strategy:
1. Core Validation: Run Globtim test suite on HPC cluster
2. Workflow Validation: Test updated submission scripts
3. Performance Validation: Measure and compare performance metrics
4. Output Analysis: Systematic analysis of test results

Usage:
    python comprehensive_hpc_test.py [--test-type TYPE] [--mode MODE]
"""

import argparse
import subprocess
import uuid
import json
import time
from datetime import datetime
from pathlib import Path
import sys
import os

class HpcTestSuite:
    def __init__(self):
        self.test_id = str(uuid.uuid4())[:8]
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.results_dir = f"hpc_test_results_{self.test_id}_{self.timestamp}"
        self.cluster_user = "scholten"
        self.cluster_host = "falcon"
        self.remote_dir = "~/globtim_hpc"
        
        # Test configuration
        self.test_results = {
            "test_id": self.test_id,
            "timestamp": self.timestamp,
            "tests": {}
        }
        
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
            
    def test_infrastructure_status(self):
        """Test 1: Verify basic infrastructure is working"""
        self.log("🔍 Testing infrastructure status...")
        
        test_result = {
            "name": "Infrastructure Status",
            "status": "RUNNING",
            "details": {}
        }
        
        # Test SSH connectivity
        returncode, stdout, stderr = self.run_ssh_command("echo 'SSH test successful'", timeout=30)
        test_result["details"]["ssh_connectivity"] = {
            "success": returncode == 0,
            "output": stdout.strip() if returncode == 0 else stderr
        }
        
        # Test NFS depot accessibility
        returncode, stdout, stderr = self.run_ssh_command(
            "cd ~/globtim_hpc && source ./setup_nfs_julia.sh >/dev/null 2>&1 && echo $JULIA_DEPOT_PATH && ls -la $JULIA_DEPOT_PATH | head -3"
        )
        test_result["details"]["nfs_depot"] = {
            "success": returncode == 0,
            "depot_path": stdout.split('\n')[0] if returncode == 0 else "FAILED",
            "accessible": "packages" in stdout if returncode == 0 else False
        }
        
        # Test Julia availability
        returncode, stdout, stderr = self.run_ssh_command(
            "cd ~/globtim_hpc && source ./setup_nfs_julia.sh >/dev/null 2>&1 && julia --version"
        )
        test_result["details"]["julia_version"] = {
            "success": returncode == 0,
            "version": stdout.strip() if returncode == 0 else "FAILED"
        }
        
        # Determine overall status
        all_success = all(detail["success"] for detail in test_result["details"].values())
        test_result["status"] = "PASSED" if all_success else "FAILED"
        
        self.test_results["tests"]["infrastructure"] = test_result
        self.log(f"✅ Infrastructure test: {test_result['status']}")
        return test_result["status"] == "PASSED"
        
    def test_globtim_test_suite(self):
        """Test 2: Run Globtim test suite on HPC cluster"""
        self.log("🧪 Running Globtim test suite on HPC cluster...")
        
        test_result = {
            "name": "Globtim Test Suite",
            "status": "RUNNING",
            "slurm_job_id": None,
            "details": {}
        }
        
        # Create SLURM script for Globtim test suite
        slurm_script = f"""#!/bin/bash
#SBATCH --job-name=globtim_test_suite_{self.test_id}
#SBATCH --account=mpi
#SBATCH --partition=batch
#SBATCH --time=00:30:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem-per-cpu=2000
#SBATCH -o globtim_test_suite_{self.test_id}_%j.out
#SBATCH -e globtim_test_suite_{self.test_id}_%j.err

echo "=== Globtim Test Suite - HPC Migration Validation ==="
echo "Test ID: {self.test_id}"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"
echo ""

# Source NFS Julia configuration
echo "=== Configuring Julia Environment ==="
cd ~/globtim_hpc
source ./setup_nfs_julia.sh

# Verify environment
echo "Julia depot: $JULIA_DEPOT_PATH"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Julia version: $(julia --version)"
echo ""

# Run Globtim test suite
echo "=== Running Globtim Test Suite ==="
julia --project=. test/runtests.jl

echo ""
echo "=== Test Suite Complete ==="
echo "End time: $(date)"
echo "Exit code: $?"
"""
        
        # Submit SLURM job
        create_script_cmd = f"cd ~/globtim_hpc && cat > globtim_test_suite_{self.test_id}.slurm << 'EOF'\n{slurm_script}\nEOF"
        returncode, stdout, stderr = self.run_ssh_command(create_script_cmd)
        
        if returncode != 0:
            test_result["status"] = "FAILED"
            test_result["details"]["error"] = f"Failed to create SLURM script: {stderr}"
            self.test_results["tests"]["globtim_test_suite"] = test_result
            return False
            
        # Submit job
        submit_cmd = f"cd ~/globtim_hpc && sbatch globtim_test_suite_{self.test_id}.slurm"
        returncode, stdout, stderr = self.run_ssh_command(submit_cmd)
        
        if returncode != 0:
            test_result["status"] = "FAILED"
            test_result["details"]["error"] = f"Failed to submit job: {stderr}"
        else:
            # Extract job ID
            job_id = stdout.strip().split()[-1]
            test_result["slurm_job_id"] = job_id
            test_result["status"] = "SUBMITTED"
            test_result["details"]["submission_time"] = datetime.now().isoformat()
            self.log(f"📋 Globtim test suite submitted as job {job_id}")
            
        self.test_results["tests"]["globtim_test_suite"] = test_result
        return test_result["status"] == "SUBMITTED"
        
    def test_submission_scripts(self):
        """Test 3: Test updated submission scripts"""
        self.log("🚀 Testing updated submission scripts...")
        
        test_result = {
            "name": "Submission Scripts",
            "status": "RUNNING",
            "scripts_tested": {},
            "details": {}
        }
        
        # Test scripts to validate
        scripts_to_test = [
            {
                "name": "submit_simple_julia_test.py",
                "command": "python3 submit_simple_julia_test.py",
                "expected_patterns": ["Job submitted successfully", "SLURM Job ID"]
            },
            {
                "name": "submit_deuflhard_hpc.py", 
                "command": "python3 submit_deuflhard_hpc.py --mode quick",
                "expected_patterns": ["Job submitted successfully", "SLURM Job ID"]
            }
        ]
        
        for script in scripts_to_test:
            self.log(f"Testing {script['name']}...")
            
            # Run from submission directory
            cmd = f"cd ~/globtim/hpc/jobs/submission && {script['command']}"
            returncode, stdout, stderr = self.run_ssh_command(cmd, timeout=120)
            
            script_result = {
                "returncode": returncode,
                "success": returncode == 0,
                "stdout": stdout,
                "stderr": stderr,
                "patterns_found": []
            }
            
            # Check for expected patterns
            if returncode == 0:
                for pattern in script["expected_patterns"]:
                    if pattern in stdout:
                        script_result["patterns_found"].append(pattern)
                        
                script_result["all_patterns_found"] = len(script_result["patterns_found"]) == len(script["expected_patterns"])
            else:
                script_result["all_patterns_found"] = False
                
            test_result["scripts_tested"][script["name"]] = script_result
            
        # Determine overall status
        all_success = all(
            result["success"] and result["all_patterns_found"] 
            for result in test_result["scripts_tested"].values()
        )
        test_result["status"] = "PASSED" if all_success else "FAILED"
        
        self.test_results["tests"]["submission_scripts"] = test_result
        self.log(f"✅ Submission scripts test: {test_result['status']}")
        return test_result["status"] == "PASSED"
        
    def monitor_job_completion(self, job_id, timeout_minutes=30):
        """Monitor SLURM job until completion"""
        self.log(f"⏳ Monitoring job {job_id} for completion...")
        
        start_time = time.time()
        timeout_seconds = timeout_minutes * 60
        
        while time.time() - start_time < timeout_seconds:
            # Check job status
            returncode, stdout, stderr = self.run_ssh_command(f"squeue -j {job_id}")
            
            if returncode != 0 or job_id not in stdout:
                # Job completed (no longer in queue)
                self.log(f"✅ Job {job_id} completed")
                return True
                
            self.log(f"⏳ Job {job_id} still running... (elapsed: {int(time.time() - start_time)}s)")
            time.sleep(30)  # Check every 30 seconds
            
        self.log(f"⚠️ Job {job_id} monitoring timed out after {timeout_minutes} minutes")
        return False
        
    def analyze_test_results(self):
        """Analyze and report test results"""
        self.log("📊 Analyzing test results...")
        
        # Save results to file
        results_file = f"{self.results_dir}_results.json"
        with open(results_file, 'w') as f:
            json.dump(self.test_results, f, indent=2)
            
        # Generate summary report
        self.generate_summary_report()
        
    def generate_summary_report(self):
        """Generate human-readable summary report"""
        print("\n" + "="*60)
        print("  JULIA HPC MIGRATION - TEST RESULTS SUMMARY")
        print("="*60)
        print(f"Test ID: {self.test_id}")
        print(f"Timestamp: {self.timestamp}")
        print()
        
        total_tests = len(self.test_results["tests"])
        passed_tests = sum(1 for test in self.test_results["tests"].values() 
                          if test["status"] == "PASSED")
        
        print(f"📊 Overall Results: {passed_tests}/{total_tests} tests passed")
        print()
        
        for test_name, test_data in self.test_results["tests"].items():
            status_emoji = "✅" if test_data["status"] == "PASSED" else "❌" if test_data["status"] == "FAILED" else "⏳"
            print(f"{status_emoji} {test_data['name']}: {test_data['status']}")
            
            # Show key details
            if "details" in test_data:
                for key, value in test_data["details"].items():
                    if isinstance(value, dict) and "success" in value:
                        detail_emoji = "✅" if value["success"] else "❌"
                        print(f"   {detail_emoji} {key}: {'PASS' if value['success'] else 'FAIL'}")
                        
        print()
        print("="*60)
        
        # Overall assessment
        if passed_tests == total_tests:
            print("🎉 MIGRATION VALIDATION: SUCCESSFUL")
            print("All tests passed - Julia HPC migration is working correctly!")
        else:
            print("⚠️ MIGRATION VALIDATION: ISSUES DETECTED")
            print("Some tests failed - review results and address issues.")
            
        print("="*60)

def main():
    parser = argparse.ArgumentParser(description="Comprehensive Julia HPC Migration Testing")
    parser.add_argument("--test-type", choices=["all", "infrastructure", "globtim", "scripts"], 
                       default="all", help="Type of tests to run")
    parser.add_argument("--mode", choices=["quick", "full"], default="quick",
                       help="Test mode (quick=basic validation, full=comprehensive)")
    
    args = parser.parse_args()
    
    print("🚀 Starting Comprehensive Julia HPC Migration Testing")
    print(f"Test type: {args.test_type}")
    print(f"Mode: {args.mode}")
    print()
    
    suite = HpcTestSuite()
    
    try:
        # Run selected tests
        if args.test_type in ["all", "infrastructure"]:
            if not suite.test_infrastructure_status():
                print("❌ Infrastructure test failed - aborting remaining tests")
                return 1
                
        if args.test_type in ["all", "globtim"]:
            suite.test_globtim_test_suite()
            
        if args.test_type in ["all", "scripts"]:
            suite.test_submission_scripts()
            
        # Analyze results
        suite.analyze_test_results()
        
        return 0
        
    except KeyboardInterrupt:
        print("\n⚠️ Testing interrupted by user")
        return 1
    except Exception as e:
        print(f"\n❌ Testing failed with error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
