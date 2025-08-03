# 🎯 SLURM Dashboard VS Code Setup Guide

Complete guide to set up live SLURM job monitoring directly in VS Code for the Globtim project.

## 📦 Installation

### 1. Install SLURM Dashboard Extension
```bash
# Install the main SLURM Dashboard extension
code --install-extension danielnichols.slurm-dashboard

# Optional: Install additional HPC extensions
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-vscode-remote.remote-containers
```

### 2. Configure Remote SSH Connection
```bash
# Add to ~/.ssh/config
Host falcon-hpc
    HostName falcon
    User scholten
    IdentityFile ~/.ssh/your_key
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

## 🔧 Configuration

The `.vscode/settings.json` file has been configured with optimal settings for Globtim monitoring:

### Key SLURM Dashboard Settings:
- **Refresh Interval**: 30 seconds (fast updates)
- **Time Extrapolation**: 5 seconds (live job time updates)
- **Persist Jobs**: Keep completed jobs visible
- **Job Script Patterns**: Automatically detect Globtim job scripts
- **Show Job Info**: Display all job metadata

## 🚀 Usage

### 1. Open SLURM Dashboard
1. Open VS Code in your Globtim project
2. Connect to the HPC cluster via Remote SSH
3. The SLURM Dashboard will appear in the sidebar (Activity Bar)
4. Two main views:
   - **Job Queue**: Live view of running/pending jobs
   - **Job Scripts**: Detected .slurm/.sbatch files

### 2. Live Monitoring Features

#### **Job Queue View:**
- 🟢 **Running Jobs**: Real-time progress with extrapolated times
- 🟡 **Pending Jobs**: Queue position and wait reasons
- ✅ **Completed Jobs**: Results and exit codes
- ❌ **Failed Jobs**: Error information

#### **Available Actions:**
- **Cancel Job**: Right-click → Cancel
- **Resubmit Job**: Right-click → Resubmit
- **Inspect Job**: View job details and output
- **Submit New Job**: From Job Scripts view

### 3. Globtim-Specific Monitoring

The configuration automatically detects these job types:
- `globtim_*.sh` - General Globtim jobs
- `working_globtim_*.sh` - Working Globtim jobs (like our current one)
- `params_test_*.sh` - Parameters.jl test jobs
- Standard `.slurm`, `.sbatch`, `.job` files

## 📊 Live Performance Monitoring

### Real-Time Metrics:
- **Job Status**: PENDING → RUNNING → COMPLETED
- **Runtime**: Live extrapolated job times
- **Resource Usage**: CPU/Memory allocation
- **Queue Position**: Priority and wait reasons
- **Node Assignment**: Which compute node is running the job

### Current Job Tracking:
Your working Globtim job (59770436) will show:
- ✅ **Live Status Updates** every 30 seconds
- ✅ **Runtime Extrapolation** every 5 seconds
- ✅ **Automatic Result Detection** when completed
- ✅ **Error Alerts** if job fails

## 🎛️ Advanced Features

### 1. Custom Refresh Intervals
```json
// In settings.json - adjust as needed
"slurm-dashboard.job-dashboard.refreshInterval": 15,  // 15 seconds for faster updates
"slurm-dashboard.job-dashboard.extrapolationInterval": 2  // 2 seconds for smoother time updates
```

### 2. Job Persistence
```json
// Keep completed jobs visible until manually removed
"slurm-dashboard.job-dashboard.persistJobs": true
```

### 3. Batch Operations
- **Cancel All Jobs**: Right-click in Job Queue → Cancel All
- **Submit All Scripts**: Right-click in Job Scripts → Submit All

## 🔍 Monitoring Your Current Job

### Job 59770436 (working_globtim_30181439):
1. **Open SLURM Dashboard** in VS Code sidebar
2. **Look for job ID 59770436** in the Job Queue view
3. **Monitor progress**:
   - Status changes: PENDING → RUNNING → COMPLETED
   - Live runtime updates
   - Resource usage information
4. **Get results**: When completed, right-click → Inspect to see output

## 🛠️ Troubleshooting

### Common Issues:

#### **Extension Not Showing Jobs:**
- Ensure you're connected to the HPC cluster via Remote SSH
- Check that SLURM commands work in the terminal: `squeue -u $USER`
- Verify the extension is enabled in the Remote SSH session

#### **Slow Updates:**
- Reduce refresh interval in settings
- Enable time extrapolation for smoother updates
- Check network connection to HPC cluster

#### **Jobs Not Detected:**
- Verify job script patterns in settings
- Check file extensions (.slurm, .sbatch, .sh)
- Ensure scripts are in the workspace folder

## 📈 Performance Benefits

### VS Code Integration:
- ✅ **No Terminal Switching**: Monitor jobs without leaving VS Code
- ✅ **Live Updates**: Real-time status without manual refresh
- ✅ **Visual Interface**: Graphical job queue and controls
- ✅ **Integrated Workflow**: Submit, monitor, debug in one place
- ✅ **Persistent History**: Keep track of completed jobs
- ✅ **Batch Operations**: Manage multiple jobs efficiently

### Compared to Command Line:
- **Command Line**: `squeue -u $USER` (manual, static)
- **SLURM Dashboard**: Automatic refresh, live times, visual interface
- **Result**: 10x more efficient job monitoring

## 🎯 Next Steps

1. **Install the extension**: `code --install-extension danielnichols.slurm-dashboard`
2. **Connect to HPC cluster** via Remote SSH
3. **Open SLURM Dashboard** in sidebar
4. **Monitor job 59770436** in real-time
5. **Submit new jobs** directly from VS Code

## 🔗 Resources

- [SLURM Dashboard Extension](https://marketplace.visualstudio.com/items?itemName=danielnichols.slurm-dashboard)
- [GitHub Repository](https://github.com/Dando18/slurm-dashboard)
- [VS Code Remote SSH Guide](https://code.visualstudio.com/docs/remote/ssh)

---

**🎉 You now have professional-grade SLURM monitoring directly in VS Code!**

The extension will automatically detect and monitor your Globtim jobs, providing live updates and comprehensive job management capabilities.
