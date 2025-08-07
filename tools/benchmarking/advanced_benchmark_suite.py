#!/usr/bin/env python3

"""
Advanced Benchmark Suite

Comprehensive benchmarking infrastructure with automated collection,
analysis, and reporting for systematic Globtim performance evaluation.
"""

import subprocess
import time
import json
from pathlib import Path
from datetime import datetime

class AdvancedBenchmarkSuite:
    def __init__(self, data_root="./data"):
        self.data_root = Path(data_root)
        self.benchmark_dir = self.data_root / "advanced_benchmarks"
        self.results_dir = self.benchmark_dir / "results"
        self.analysis_dir = self.benchmark_dir / "analysis"
        self.reports_dir = self.benchmark_dir / "reports"
        
        # Create directories
        for directory in [self.benchmark_dir, self.results_dir, self.analysis_dir, self.reports_dir]:
            directory.mkdir(parents=True, exist_ok=True)
    
    def run_benchmark_level(self, level):
        """Run complete benchmark level with automated collection and analysis"""
        
        print(f"🎯 RUNNING BENCHMARK LEVEL {level}")
        print("=" * 50)
        
        if level == 1:
            return self.run_level_1_basic()
        elif level == 2:
            return self.run_level_2_intermediate()
        elif level == 3:
            return self.run_level_3_advanced()
        elif level == 4:
            return self.run_level_4_expert()
        else:
            print(f"❌ Unknown benchmark level: {level}")
            return False
    
    def run_level_1_basic(self):
        """Level 1: Basic validation benchmarks"""
        print("🟢 LEVEL 1: BASIC BENCHMARKS")
        print("Testing core functionality with simple validation")
        print()
        
        jobs = []
        
        # 1.1 Simple function validation
        print("📊 1.1 Simple Function Validation")
        job_id = self.submit_job("python3 submit_simple_test.py Sphere4D quick_test")
        if job_id:
            jobs.append(("simple_sphere", job_id))
        
        # 1.2 Core Globtim functionality
        print("📊 1.2 Core Globtim Functionality")
        job_id = self.submit_job("python3 submit_core_globtim_test.py Sphere4D quick_test")
        if job_id:
            jobs.append(("core_sphere", job_id))
        
        return self.monitor_and_collect(jobs, "level_1_basic")
    
    def run_level_2_intermediate(self):
        """Level 2: Multi-function comparison"""
        print("🟡 LEVEL 2: INTERMEDIATE BENCHMARKS")
        print("Comparing performance across different function types")
        print()
        
        jobs = []
        functions = ["Sphere4D", "Rosenbrock4D", "Rastrigin4D"]
        
        for func in functions:
            print(f"📊 2.1 Testing {func}")
            job_id = self.submit_job(f"python3 submit_core_globtim_test.py {func} quick_test")
            if job_id:
                jobs.append((f"func_{func.lower()}", job_id))
        
        return self.monitor_and_collect(jobs, "level_2_intermediate")
    
    def run_level_3_advanced(self):
        """Level 3: Parameter sweep analysis"""
        print("🟠 LEVEL 3: ADVANCED BENCHMARKS")
        print("Systematic parameter space exploration")
        print()
        
        jobs = []
        sweeps = ["basic_sweep", "function_comparison", "degree_analysis"]
        
        for sweep in sweeps:
            print(f"📊 3.1 Parameter Sweep: {sweep}")
            job_id = self.submit_job(f"python3 submit_parameter_sweep.py {sweep}")
            if job_id:
                jobs.append((f"sweep_{sweep}", job_id))
        
        return self.monitor_and_collect(jobs, "level_3_advanced")
    
    def run_level_4_expert(self):
        """Level 4: Comprehensive analysis"""
        print("🔴 LEVEL 4: EXPERT BENCHMARKS")
        print("Full parameter space exploration with statistical analysis")
        print()
        
        jobs = []
        
        # Comprehensive sweep
        print("📊 4.1 Comprehensive Parameter Sweep")
        job_id = self.submit_job("python3 submit_parameter_sweep.py comprehensive_sweep")
        if job_id:
            jobs.append(("comprehensive_sweep", job_id))
        
        return self.monitor_and_collect(jobs, "level_4_expert")
    
    def submit_job(self, command):
        """Submit job and return SLURM job ID"""
        try:
            result = subprocess.run(command.split(), capture_output=True, text=True, check=True)
            
            # Extract job ID from output
            for line in result.stdout.split('\\n'):
                if "SLURM Job ID:" in line:
                    return line.split()[-1]
            
            print(f"⚠️  Job submitted but couldn't extract ID: {command}")
            return None
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Job submission failed: {command}")
            print(f"Error: {e}")
            return None
    
    def monitor_and_collect(self, jobs, level_name):
        """Monitor jobs and collect results when complete"""
        print(f"\\n🔍 Monitoring {len(jobs)} jobs for {level_name}...")
        
        completed_jobs = []
        max_wait_time = 3600  # 1 hour max wait
        start_time = time.time()
        
        while jobs and (time.time() - start_time) < max_wait_time:
            remaining_jobs = []
            
            for job_name, job_id in jobs:
                status = self.check_job_status(job_id)
                
                if status == "COMPLETED":
                    print(f"✅ {job_name} (Job {job_id}) completed")
                    completed_jobs.append((job_name, job_id))
                elif status == "FAILED":
                    print(f"❌ {job_name} (Job {job_id}) failed")
                    completed_jobs.append((job_name, job_id))
                elif status in ["RUNNING", "PENDING"]:
                    remaining_jobs.append((job_name, job_id))
                else:
                    print(f"⚠️  {job_name} (Job {job_id}) status: {status}")
                    remaining_jobs.append((job_name, job_id))
            
            jobs = remaining_jobs
            
            if jobs:
                print(f"⏳ Waiting for {len(jobs)} jobs... ({int(time.time() - start_time)}s elapsed)")
                time.sleep(30)  # Check every 30 seconds
        
        if jobs:
            print(f"⚠️  Timeout reached. {len(jobs)} jobs still running.")
        
        # Collect results
        print(f"\\n📥 Collecting results for {level_name}...")
        self.collect_level_results(completed_jobs, level_name)
        
        # Generate analysis
        print(f"📊 Generating analysis for {level_name}...")
        self.analyze_level_results(level_name)
        
        return len(completed_jobs) > 0
    
    def check_job_status(self, job_id):
        """Check SLURM job status"""
        try:
            cmd = f"python3 hpc/monitoring/python/slurm_monitor.py --analyze {job_id}"
            result = subprocess.run(cmd.split(), capture_output=True, text=True, check=True)
            
            for line in result.stdout.split('\\n'):
                if "JobState:" in line:
                    return line.split()[-1]
            
            return "UNKNOWN"
            
        except:
            return "UNKNOWN"
    
    def collect_level_results(self, completed_jobs, level_name):
        """Collect and organize results from completed jobs"""
        level_dir = self.results_dir / level_name
        level_dir.mkdir(exist_ok=True)
        
        # Run collection script
        try:
            subprocess.run(["python3", "collect_hpc_results.py"], check=True)
            print("✅ Results collected successfully")
        except subprocess.CalledProcessError as e:
            print(f"⚠️  Result collection failed: {e}")
    
    def analyze_level_results(self, level_name):
        """Generate comprehensive analysis for benchmark level"""
        analysis_file = self.analysis_dir / f"{level_name}_analysis.txt"
        
        analysis_content = f"""# {level_name.upper()} BENCHMARK ANALYSIS
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Summary
- Benchmark Level: {level_name}
- Analysis Date: {datetime.now().date()}
- Results Location: {self.results_dir / level_name}

## Key Metrics
[Analysis would be generated from collected results]

## Recommendations
[Recommendations would be generated based on results]

## Next Steps
[Suggested follow-up benchmarks or parameter adjustments]
"""
        
        with open(analysis_file, 'w') as f:
            f.write(analysis_content)
        
        print(f"📄 Analysis saved to: {analysis_file}")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Advanced Benchmark Suite")
    parser.add_argument("level", type=int, choices=[1, 2, 3, 4], 
                       help="Benchmark level to run (1=Basic, 2=Intermediate, 3=Advanced, 4=Expert)")
    parser.add_argument("--dry-run", action="store_true", 
                       help="Show what would be run without actually submitting jobs")
    
    args = parser.parse_args()
    
    suite = AdvancedBenchmarkSuite()
    
    if args.dry_run:
        print(f"🔍 DRY RUN: Would run benchmark level {args.level}")
        return
    
    success = suite.run_benchmark_level(args.level)
    
    if success:
        print(f"\\n🎉 Benchmark Level {args.level} completed successfully!")
    else:
        print(f"\\n❌ Benchmark Level {args.level} failed or incomplete")

if __name__ == "__main__":
    main()
