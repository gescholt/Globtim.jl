"""
GlobTim HPC Job Manager
Handles SLURM job submission, tracking, and lifecycle management
"""

import subprocess
import json
import time
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field
import yaml
import logging

logger = logging.getLogger(__name__)


@dataclass
class JobConfig:
    """Configuration for a single HPC job"""
    name: str
    script_path: str
    account: str = "mpi"
    partition: str = "batch"
    time: str = "02:00:00"
    memory: str = "16G"
    nodes: int = 1
    tasks: int = 1
    output_dir: str = "."
    dependencies: List[str] = field(default_factory=list)
    environment: Dict[str, str] = field(default_factory=dict)
    parameters: Dict[str, any] = field(default_factory=dict)


@dataclass
class JobStatus:
    """Status information for a submitted job"""
    job_id: str
    name: str
    state: str  # PENDING, RUNNING, COMPLETED, FAILED, CANCELLED
    submit_time: datetime
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    exit_code: Optional[int] = None
    output_file: Optional[str] = None
    error_file: Optional[str] = None
    metrics: Dict[str, any] = field(default_factory=dict)


class JobManager:
    """Manages HPC job submission and tracking"""
    
    def __init__(self, config_file: Optional[str] = None):
        """Initialize job manager with configuration"""
        self.config = self._load_config(config_file)
        self.active_jobs: Dict[str, JobStatus] = {}
        self.completed_jobs: List[JobStatus] = []
        self.ssh_cmd = f"ssh {self.config['user']}@{self.config['cluster']}"
        self.scp_cmd = f"scp"
        
    def _load_config(self, config_file: Optional[str]) -> Dict:
        """Load configuration from file or use defaults"""
        default_config = {
            'cluster': 'falcon',
            'user': 'scholten',
            'account': 'mpi',
            'partition': 'batch',
            'bundle_path': '/home/scholten/globtim_hpc_bundle.tar.gz',
            'work_dir': '/tmp',
            'results_dir': './results'
        }
        
        if config_file and Path(config_file).exists():
            with open(config_file, 'r') as f:
                user_config = yaml.safe_load(f)
                default_config.update(user_config)
                
        return default_config
    
    def submit_job(self, job_config: JobConfig) -> str:
        """Submit a job to the HPC cluster"""
        # Generate SLURM script from config
        script_content = self._generate_slurm_script(job_config)
        
        # Create temporary script file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        temp_script = f"/tmp/{job_config.name}_{timestamp}.slurm"
        
        with open(temp_script, 'w') as f:
            f.write(script_content)
        
        # Copy script to cluster
        remote_script = f"~/{job_config.name}_{timestamp}.slurm"
        scp_command = f"{self.scp_cmd} {temp_script} {self.config['user']}@{self.config['cluster']}:{remote_script}"
        subprocess.run(scp_command, shell=True, check=True)
        
        # Submit job
        submit_command = f"{self.ssh_cmd} 'sbatch {remote_script}'"
        result = subprocess.run(submit_command, shell=True, capture_output=True, text=True)
        
        if result.returncode != 0:
            raise RuntimeError(f"Job submission failed: {result.stderr}")
        
        # Parse job ID from output
        match = re.search(r'Submitted batch job (\d+)', result.stdout)
        if not match:
            raise RuntimeError(f"Could not parse job ID from: {result.stdout}")
        
        job_id = match.group(1)
        
        # Track job
        job_status = JobStatus(
            job_id=job_id,
            name=job_config.name,
            state="PENDING",
            submit_time=datetime.now(),
            output_file=f"{job_config.name}_{job_id}.out",
            error_file=f"{job_config.name}_{job_id}.err"
        )
        
        self.active_jobs[job_id] = job_status
        logger.info(f"Submitted job {job_config.name} with ID {job_id}")
        
        return job_id
    
    def _generate_slurm_script(self, job_config: JobConfig) -> str:
        """Generate SLURM script from job configuration"""
        script = f"""#!/bin/bash
#SBATCH --job-name={job_config.name}
#SBATCH --account={job_config.account}
#SBATCH --partition={job_config.partition}
#SBATCH --time={job_config.time}
#SBATCH --mem={job_config.memory}
#SBATCH --nodes={job_config.nodes}
#SBATCH --ntasks={job_config.tasks}
#SBATCH --output={job_config.name}_%j.out
#SBATCH --error={job_config.name}_%j.err
"""
        
        # Add dependencies if any
        if job_config.dependencies:
            deps = ":".join(job_config.dependencies)
            script += f"#SBATCH --dependency=afterok:{deps}\n"
        
        script += f"""
# Job metadata
echo "========== Job Information =========="
echo "Job ID: $SLURM_JOB_ID"
echo "Job Name: {job_config.name}"
echo "Node: $HOSTNAME"
echo "Start Time: $(date)"
echo "====================================="
echo ""

# Setup work directory
WORK_DIR="/tmp/globtim_${{SLURM_JOB_ID}}"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Extract bundle
echo "Extracting GlobTim bundle..."
tar -xzf {self.config['bundle_path']}

# Set environment
export JULIA_DEPOT_PATH="$WORK_DIR/globtim_bundle/depot"
export JULIA_PROJECT="$WORK_DIR/globtim_bundle/globtim_hpc"
export JULIA_NO_NETWORK="1"
"""
        
        # Add custom environment variables
        for key, value in job_config.environment.items():
            script += f'export {key}="{value}"\n'
        
        # Add custom script content or default test
        if Path(job_config.script_path).exists():
            with open(job_config.script_path, 'r') as f:
                custom_content = f.read()
            script += f"\n# Custom job content\n{custom_content}\n"
        else:
            script += f"""
# Default test execution
/sw/bin/julia --project="$JULIA_PROJECT" -e '
    println("Loading GlobTim packages...")
    using Pkg
    Pkg.instantiate()
    
    # Run test
    include("{job_config.script_path}")
'
"""
        
        script += f"""
# Cleanup
echo ""
echo "====================================="
echo "End Time: $(date)"
echo "====================================="
cd /tmp
rm -rf $WORK_DIR
"""
        
        return script
    
    def get_job_status(self, job_id: str) -> JobStatus:
        """Get current status of a job"""
        command = f"{self.ssh_cmd} 'squeue -j {job_id} --format=\"%T,%S,%e\" --noheader'"
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        
        if job_id not in self.active_jobs:
            raise ValueError(f"Job {job_id} not tracked")
        
        job_status = self.active_jobs[job_id]
        
        if result.returncode == 0 and result.stdout.strip():
            # Job is still in queue
            parts = result.stdout.strip().split(',')
            state = parts[0]
            
            job_status.state = state
            
            if state == "RUNNING" and not job_status.start_time:
                job_status.start_time = datetime.now()
        else:
            # Job completed or failed
            job_status.state = "COMPLETED"
            job_status.end_time = datetime.now()
            
            # Get exit code
            sacct_cmd = f"{self.ssh_cmd} 'sacct -j {job_id} --format=ExitCode --noheader'"
            exit_result = subprocess.run(sacct_cmd, shell=True, capture_output=True, text=True)
            
            if exit_result.returncode == 0:
                exit_code_str = exit_result.stdout.strip().split(':')[0]
                try:
                    job_status.exit_code = int(exit_code_str)
                    if job_status.exit_code != 0:
                        job_status.state = "FAILED"
                except ValueError:
                    pass
        
        return job_status
    
    def monitor_jobs(self, interval: int = 10) -> None:
        """Monitor all active jobs"""
        while self.active_jobs:
            print(f"\n{'='*60}")
            print(f"Job Monitor - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"{'='*60}")
            
            completed = []
            for job_id, job_status in self.active_jobs.items():
                status = self.get_job_status(job_id)
                
                status_symbol = {
                    'PENDING': '⏳',
                    'RUNNING': '🔄',
                    'COMPLETED': '✅',
                    'FAILED': '❌',
                    'CANCELLED': '⚠️'
                }.get(status.state, '❓')
                
                runtime = ""
                if status.start_time:
                    elapsed = (datetime.now() - status.start_time).total_seconds()
                    runtime = f" ({elapsed:.0f}s)"
                
                print(f"{status_symbol} {status.name} [{job_id}]: {status.state}{runtime}")
                
                if status.state in ['COMPLETED', 'FAILED', 'CANCELLED']:
                    completed.append(job_id)
            
            # Move completed jobs
            for job_id in completed:
                self.completed_jobs.append(self.active_jobs[job_id])
                del self.active_jobs[job_id]
            
            if self.active_jobs:
                time.sleep(interval)
        
        print(f"\n{'='*60}")
        print("All jobs completed!")
        print(f"{'='*60}")
    
    def collect_results(self, job_id: str, local_dir: str = "./results") -> Dict:
        """Collect results from a completed job"""
        if job_id in self.active_jobs:
            job_status = self.active_jobs[job_id]
        else:
            job_status = next((j for j in self.completed_jobs if j.job_id == job_id), None)
        
        if not job_status:
            raise ValueError(f"Job {job_id} not found")
        
        Path(local_dir).mkdir(parents=True, exist_ok=True)
        
        # Download output files
        files_to_collect = [
            (f"~/{job_status.output_file}", f"{local_dir}/{job_status.output_file}"),
            (f"~/{job_status.error_file}", f"{local_dir}/{job_status.error_file}")
        ]
        
        results = {
            'job_id': job_id,
            'name': job_status.name,
            'state': job_status.state,
            'exit_code': job_status.exit_code,
            'runtime': None,
            'files': []
        }
        
        if job_status.start_time and job_status.end_time:
            results['runtime'] = (job_status.end_time - job_status.start_time).total_seconds()
        
        for remote_file, local_file in files_to_collect:
            scp_command = f"{self.scp_cmd} {self.config['user']}@{self.config['cluster']}:{remote_file} {local_file}"
            result = subprocess.run(scp_command, shell=True, capture_output=True)
            
            if result.returncode == 0:
                results['files'].append(local_file)
                
                # Parse metrics from output file
                if local_file.endswith('.out'):
                    results['metrics'] = self._parse_output_metrics(local_file)
        
        return results
    
    def _parse_output_metrics(self, output_file: str) -> Dict:
        """Parse metrics from job output file"""
        metrics = {}
        
        with open(output_file, 'r') as f:
            content = f.read()
            
            # Look for common patterns
            patterns = {
                'total_time': r'Total time:\s*([\d.]+)\s*seconds',
                'memory_used': r'Memory used:\s*([\d.]+)\s*MB',
                'iterations': r'Iterations:\s*(\d+)',
                'error': r'Error:\s*([\d.e+-]+)'
            }
            
            for key, pattern in patterns.items():
                match = re.search(pattern, content, re.IGNORECASE)
                if match:
                    try:
                        metrics[key] = float(match.group(1))
                    except ValueError:
                        metrics[key] = match.group(1)
        
        return metrics
    
    def cancel_job(self, job_id: str) -> bool:
        """Cancel a running job"""
        command = f"{self.ssh_cmd} 'scancel {job_id}'"
        result = subprocess.run(command, shell=True, capture_output=True)
        
        if result.returncode == 0:
            if job_id in self.active_jobs:
                self.active_jobs[job_id].state = "CANCELLED"
                self.active_jobs[job_id].end_time = datetime.now()
            return True
        return False
    
    def get_summary(self) -> Dict:
        """Get summary of all jobs"""
        total_jobs = len(self.active_jobs) + len(self.completed_jobs)
        
        summary = {
            'total_jobs': total_jobs,
            'active': len(self.active_jobs),
            'completed': sum(1 for j in self.completed_jobs if j.state == 'COMPLETED'),
            'failed': sum(1 for j in self.completed_jobs if j.state == 'FAILED'),
            'cancelled': sum(1 for j in self.completed_jobs if j.state == 'CANCELLED'),
            'total_runtime': sum(
                (j.end_time - j.start_time).total_seconds()
                for j in self.completed_jobs
                if j.start_time and j.end_time
            ),
            'jobs': []
        }
        
        for job in self.completed_jobs + list(self.active_jobs.values()):
            summary['jobs'].append({
                'id': job.job_id,
                'name': job.name,
                'state': job.state,
                'exit_code': job.exit_code,
                'runtime': (
                    (job.end_time - job.start_time).total_seconds()
                    if job.start_time and job.end_time else None
                )
            })
        
        return summary