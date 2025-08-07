#!/usr/bin/env python3
"""
Job Tracker for JSON-Tracked Computations

Automatically tracks job submissions and enables automated result pulling
without manual job ID management.
"""

import json
import os
import subprocess
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional
import re

class JobTracker:
    """
    Tracks submitted jobs and automates result pulling.
    """
    
    def __init__(self, tracker_file="hpc/infrastructure/.job_tracker.json"):
        self.tracker_file = Path(tracker_file)
        self.tracker_file.parent.mkdir(parents=True, exist_ok=True)
        self.jobs = self.load_jobs()
    
    def load_jobs(self) -> Dict:
        """Load job tracking data"""
        if self.tracker_file.exists():
            try:
                with open(self.tracker_file, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                pass
        return {"jobs": {}, "last_updated": str(datetime.now())}
    
    def save_jobs(self):
        """Save job tracking data"""
        self.jobs["last_updated"] = str(datetime.now())
        with open(self.tracker_file, 'w') as f:
            json.dump(self.jobs, f, indent=2)
    
    def add_job(self, computation_id: str, job_id: str, job_script_path: str, 
                output_directory: str, description: str = ""):
        """Add a new job to tracking"""
        self.jobs["jobs"][computation_id] = {
            "job_id": job_id,
            "computation_id": computation_id,
            "job_script_path": job_script_path,
            "output_directory": output_directory,
            "description": description,
            "submitted_at": str(datetime.now()),
            "status": "SUBMITTED",
            "pulled": False,
            "pull_attempts": 0,
            "last_check": None
        }
        self.save_jobs()
        print(f"✅ Tracking job {job_id} (computation {computation_id})")
    
    def update_job_status(self, computation_id: str, status: str):
        """Update job status"""
        if computation_id in self.jobs["jobs"]:
            self.jobs["jobs"][computation_id]["status"] = status
            self.jobs["jobs"][computation_id]["last_check"] = str(datetime.now())
            self.save_jobs()
    
    def get_pending_jobs(self) -> List[Dict]:
        """Get jobs that haven't been pulled yet"""
        pending = []
        for comp_id, job_info in self.jobs["jobs"].items():
            if not job_info.get("pulled", False) and job_info.get("status") != "FAILED":
                pending.append(job_info)
        return pending
    
    def check_job_status(self, job_id: str) -> Optional[str]:
        """Check SLURM job status"""
        try:
            # Use squeue to check if job is still running
            result = subprocess.run(
                ["ssh", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes", 
                 "scholten@falcon", f"squeue -j {job_id} -h -o %T 2>/dev/null || echo 'NOT_FOUND'"],
                capture_output=True, text=True, timeout=15
            )
            
            if result.returncode == 0:
                status = result.stdout.strip()
                if status == "NOT_FOUND":
                    # Job not in queue, check if it completed
                    sacct_result = subprocess.run(
                        ["ssh", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes",
                         "scholten@falcon", f"sacct -j {job_id} -n -o State | head -1 | tr -d ' '"],
                        capture_output=True, text=True, timeout=15
                    )
                    if sacct_result.returncode == 0:
                        sacct_status = sacct_result.stdout.strip()
                        if sacct_status in ["COMPLETED", "FAILED", "CANCELLED", "TIMEOUT"]:
                            return sacct_status
                    return "COMPLETED"  # Assume completed if not in queue
                else:
                    return status
            return None
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
            return None
    
    def auto_pull_completed_jobs(self, force: bool = False) -> Dict:
        """Automatically pull results for completed jobs"""
        print("🔍 Checking for completed jobs to pull...")
        
        pending_jobs = self.get_pending_jobs()
        if not pending_jobs:
            print("✅ No pending jobs to check")
            return {"checked": 0, "pulled": 0, "failed": 0}
        
        pulled = 0
        failed = 0
        
        for job_info in pending_jobs:
            job_id = job_info["job_id"]
            computation_id = job_info["computation_id"]
            
            print(f"\n📊 Checking job {job_id} (computation {computation_id})...")
            
            # Check job status
            status = self.check_job_status(job_id)
            if status:
                self.update_job_status(computation_id, status)
                print(f"   Status: {status}")
                
                if status in ["COMPLETED", "FAILED", "CANCELLED", "TIMEOUT"]:
                    if status == "COMPLETED":
                        # Try to pull results
                        print(f"   🎯 Attempting to pull results...")
                        success = self.pull_job_results(computation_id, force)
                        if success:
                            self.jobs["jobs"][computation_id]["pulled"] = True
                            self.jobs["jobs"][computation_id]["pulled_at"] = str(datetime.now())
                            pulled += 1
                            print(f"   ✅ Successfully pulled results for {computation_id}")
                        else:
                            self.jobs["jobs"][computation_id]["pull_attempts"] += 1
                            failed += 1
                            print(f"   ❌ Failed to pull results for {computation_id}")
                    else:
                        # Job failed, mark as such
                        self.jobs["jobs"][computation_id]["pulled"] = True  # Don't try again
                        print(f"   ⚠️  Job {status.lower()}, not pulling results")
                else:
                    print(f"   ⏳ Job still {status.lower()}, waiting...")
            else:
                print(f"   ❓ Could not determine job status")
        
        self.save_jobs()
        
        print(f"\n📊 Auto-pull summary:")
        print(f"   Jobs checked: {len(pending_jobs)}")
        print(f"   Results pulled: {pulled}")
        print(f"   Pull failures: {failed}")
        
        return {"checked": len(pending_jobs), "pulled": pulled, "failed": failed}
    
    def pull_job_results(self, computation_id: str, force: bool = False) -> bool:
        """Pull results for a specific computation"""
        try:
            cmd = ["./hpc/infrastructure/pull_results.sh", "--computation-id", computation_id]
            if force:
                cmd.append("--force")
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
            return False
    
    def list_jobs(self, status_filter: Optional[str] = None):
        """List tracked jobs"""
        jobs = self.jobs["jobs"]
        if not jobs:
            print("No jobs being tracked")
            return
        
        print("📋 Tracked Jobs:")
        print("-" * 80)
        print(f"{'Computation ID':<12} {'Job ID':<10} {'Status':<12} {'Pulled':<8} {'Description'}")
        print("-" * 80)
        
        for comp_id, job_info in jobs.items():
            if status_filter and job_info.get("status") != status_filter:
                continue
                
            status = job_info.get("status", "UNKNOWN")
            pulled = "✅" if job_info.get("pulled", False) else "❌"
            description = job_info.get("description", "")[:30]
            
            print(f"{comp_id:<12} {job_info['job_id']:<10} {status:<12} {pulled:<8} {description}")
    
    def cleanup_old_jobs(self, days_old: int = 30):
        """Remove tracking for old completed jobs"""
        cutoff_date = datetime.now() - timedelta(days=days_old)
        
        to_remove = []
        for comp_id, job_info in self.jobs["jobs"].items():
            if job_info.get("pulled", False):
                submitted_at = datetime.fromisoformat(job_info["submitted_at"])
                if submitted_at < cutoff_date:
                    to_remove.append(comp_id)
        
        for comp_id in to_remove:
            del self.jobs["jobs"][comp_id]
        
        if to_remove:
            self.save_jobs()
            print(f"🧹 Cleaned up {len(to_remove)} old job records")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Job tracker for JSON-tracked computations')
    parser.add_argument('--auto-pull', action='store_true',
                       help='Automatically pull completed jobs')
    parser.add_argument('--list', action='store_true',
                       help='List all tracked jobs')
    parser.add_argument('--status', choices=['SUBMITTED', 'RUNNING', 'COMPLETED', 'FAILED'],
                       help='Filter jobs by status')
    parser.add_argument('--cleanup', type=int, metavar='DAYS',
                       help='Clean up jobs older than DAYS (default: 30)')
    parser.add_argument('--force', action='store_true',
                       help='Force pull even if already pulled')
    
    args = parser.parse_args()
    
    tracker = JobTracker()
    
    if args.auto_pull:
        tracker.auto_pull_completed_jobs(args.force)
    elif args.list:
        tracker.list_jobs(args.status)
    elif args.cleanup:
        tracker.cleanup_old_jobs(args.cleanup)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
