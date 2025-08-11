#!/usr/bin/env python3

"""
Test Runner - Clean Interface for HPC Tests
==========================================

This script provides a clean, simple interface for running various tests
on the HPC cluster using the separated SLURM infrastructure.

Usage:
    python run_tests.py deuflhard --config quick
    python run_tests.py basic --config standard
    python run_tests.py custom --julia-code "println('Hello HPC')" --name my_test
"""

import argparse
import sys
from slurm_infrastructure import SLURMJobManager, TestJobBuilder

def run_deuflhard_test(config: str):
    """Run Deuflhard benchmark test"""
    print("🧮 Running Deuflhard Benchmark Test")
    print(f"Configuration: {config}")
    print()
    
    manager = SLURMJobManager()
    builder = TestJobBuilder(manager)
    
    job_id, test_id = builder.submit_deuflhard_test(config)
    
    if job_id:
        print(f"✅ Deuflhard test submitted successfully!")
        print(f"Job ID: {job_id}")
        print(f"Test ID: {test_id}")
        return True
    else:
        print(f"❌ Deuflhard test submission failed")
        return False

def run_basic_test(config: str):
    """Run basic functionality test"""
    print("🔧 Running Basic Functionality Test")
    print(f"Configuration: {config}")
    print()
    
    manager = SLURMJobManager()
    builder = TestJobBuilder(manager)
    
    job_id, test_id = builder.submit_basic_test(config)
    
    if job_id:
        print(f"✅ Basic test submitted successfully!")
        print(f"Job ID: {job_id}")
        print(f"Test ID: {test_id}")
        return True
    else:
        print(f"❌ Basic test submission failed")
        return False

def run_custom_test(julia_code: str, job_name: str, config: str):
    """Run custom Julia test"""
    print(f"🚀 Running Custom Test: {job_name}")
    print(f"Configuration: {config}")
    print()
    
    manager = SLURMJobManager()
    builder = TestJobBuilder(manager)
    
    job_content = builder.create_julia_test_job(julia_code, job_name)
    job_id, test_id = manager.submit_job(job_content, job_name, config)
    
    if job_id:
        print(f"✅ Custom test submitted successfully!")
        print(f"Job ID: {job_id}")
        print(f"Test ID: {test_id}")
        return True
    else:
        print(f"❌ Custom test submission failed")
        return False

def monitor_job(job_id: str):
    """Monitor a specific job"""
    print(f"📊 Monitoring Job: {job_id}")
    
    manager = SLURMJobManager()
    status = manager.monitor_job(job_id)
    print(status)

def list_configs():
    """List available configurations"""
    manager = SLURMJobManager()
    
    print("Available Configurations:")
    print("=" * 40)
    
    for name, config in manager.standard_configs.items():
        print(f"📋 {name}:")
        print(f"  Time Limit: {config['time_limit']}")
        print(f"  Memory: {config['memory']}")
        print(f"  CPUs: {config['cpus']}")
        print(f"  Partition: {config['partition']}")
        print()

def main():
    parser = argparse.ArgumentParser(description="HPC Test Runner with Clean Infrastructure")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Deuflhard test
    deuflhard_parser = subparsers.add_parser("deuflhard", help="Run Deuflhard benchmark test")
    deuflhard_parser.add_argument("--config", choices=["quick", "standard", "extended", "bigmem"],
                                 default="quick", help="Configuration to use")
    
    # Basic test
    basic_parser = subparsers.add_parser("basic", help="Run basic functionality test")
    basic_parser.add_argument("--config", choices=["quick", "standard", "extended", "bigmem"],
                             default="quick", help="Configuration to use")
    
    # Custom test
    custom_parser = subparsers.add_parser("custom", help="Run custom Julia test")
    custom_parser.add_argument("--julia-code", required=True, help="Julia code to execute")
    custom_parser.add_argument("--name", required=True, help="Job name")
    custom_parser.add_argument("--config", choices=["quick", "standard", "extended", "bigmem"],
                              default="quick", help="Configuration to use")
    
    # Monitor job
    monitor_parser = subparsers.add_parser("monitor", help="Monitor a specific job")
    monitor_parser.add_argument("job_id", help="SLURM job ID to monitor")
    
    # List configurations
    subparsers.add_parser("configs", help="List available configurations")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Execute commands
    success = True
    
    if args.command == "deuflhard":
        success = run_deuflhard_test(args.config)
    
    elif args.command == "basic":
        success = run_basic_test(args.config)
    
    elif args.command == "custom":
        success = run_custom_test(args.julia_code, args.name, args.config)
    
    elif args.command == "monitor":
        monitor_job(args.job_id)
    
    elif args.command == "configs":
        list_configs()
    
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
