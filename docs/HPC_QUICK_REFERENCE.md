# Globtim HPC Quick Reference

## 🚀 Quick Start Commands

```bash
# Deploy and test
./sync_fileserver_to_hpc.sh --test

# Submit quick job
./submit_minimal_job.sh

# Monitor jobs
./monitor_jobs.sh

# Check specific job
./monitor_jobs.sh <job_id>
```

## 📊 SLURM Partitions

| Partition | Max CPUs | Max Time | Max Memory | Best For |
|-----------|----------|----------|------------|----------|
| `batch` (default) | 24 | 24h | 256GB | General use |
| `long` | 32 | ∞ | 256GB | Long jobs |
| `bigmem` | 48 | ∞ | 1TB | Memory-heavy |
| `gpu` | 40 | ∞ | 512GB | GPU tasks |

## 🔧 Job Templates

| Template | CPUs | Memory | Time | Purpose |
|----------|------|--------|------|---------|
| `globtim_quick.slurm` | 4 | 8GB | 10min | Quick test |
| `globtim_minimal.slurm` | 24 | 32GB | 30min | Full test |
| `globtim_benchmark.slurm` | 24 | 64GB | 2h | Benchmarks |
| `globtim_custom.slurm.template` | Custom | Custom | Custom | Your code |

## 📁 File Locations

```
Local Machine:
├── sync_fileserver_to_hpc.sh     # Main deployment
├── submit_minimal_job.sh          # Quick job submission  
├── monitor_jobs.sh                # Job monitoring
├── *.slurm                        # Job templates
└── cluster_config.sh              # Your settings (gitignored)

Fileserver (backup):
└── scholten@fileserver-ssh:~/globtim/

HPC Cluster (computation):
└── scholten@falcon:~/globtim_hpc/
```

## 🖥️ Direct SLURM Commands

```bash
# Connect to cluster
ssh scholten@falcon

# Submit job
sbatch my_job.slurm

# Check queue
squeue -u $USER

# Job details
scontrol show job <job_id>

# Cancel job
scancel <job_id>

# Job history
sacct -u $USER --format=JobID,JobName,State,ExitCode,Start,End,Elapsed

# View output
cat globtim_*_<job_id>.out
cat globtim_*_<job_id>.err
```

## ⚡ Julia on HPC

```bash
# Julia location
/sw/bin/julia

# Environment setup (in SLURM jobs)
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="/tmp/julia_depot_${USER}_${SLURM_JOB_ID}"

# Load Globtim modules
include("src/Structures.jl")
include("src/BenchmarkFunctions.jl")
include("src/LibFunctions.jl")
```

## 🔍 Troubleshooting

| Problem | Solution |
|---------|----------|
| Disk quota exceeded | `ssh scholten@falcon "rm -rf ~/globtim_*"` |
| Job pending too long | Use fewer CPUs/memory, try different partition |
| SSH connection fails | Check `./test_hpc_access.sh` |
| Julia packages fail | Use temporary JULIA_DEPOT_PATH |

## 📈 Resource Guidelines

| Task | CPUs | Memory | Time | Partition |
|------|------|--------|------|-----------|
| Quick test | 4 | 8GB | 10min | batch |
| Standard run | 24 | 32GB | 2h | batch |
| Long optimization | 24 | 64GB | 12h | long |
| Memory-intensive | 48 | 256GB | 4h | bigmem |

## 🔐 Security Checklist

- ✅ SSH keys configured (`./setup_ssh_keys.sh`)
- ✅ Sensitive files gitignored
- ✅ No credentials in scripts
- ✅ Automatic cleanup enabled

## 📞 Support

- **HPC Support**: Contact hpcsupport for `/projects` space
- **Documentation**: See `docs/HPC_CLUSTER_GUIDE.md` for full details
- **Test Status**: ✅ Verified working (Job 59769879, Julia 1.11.2, 4 threads)

## 🎯 Typical Workflow

1. **Develop locally** → Edit Globtim code
2. **Deploy** → `./sync_fileserver_to_hpc.sh`
3. **Submit job** → `./submit_minimal_job.sh` or custom SLURM script
4. **Monitor** → `./monitor_jobs.sh`
5. **Analyze results** → Check output files
6. **Iterate** → Repeat with improvements
