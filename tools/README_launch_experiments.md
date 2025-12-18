# Experiment Launch Helper Tool

**Unified tool for launching experiments locally or on HPC clusters**

## Overview

The `launch_experiments.jl` tool eliminates manual SSH/rsync/nohup workflows by providing a single command to:

- Launch experiments locally or on HPC
- Auto-detect environment (local vs. HPC)
- Handle file synchronization
- Manage background processes
- Provide monitoring commands

## Features

✅ **Single command** - No manual SSH/rsync
✅ **Auto-detection** - Knows if it's local or HPC
✅ **Background execution** - Runs experiments as daemon processes
✅ **Log redirection** - Captures stdout/stderr to log files
✅ **Monitoring info** - Provides commands to check status
✅ **Validation** - Checks config files and provides clear errors

## Installation

The tool is located at `tools/launch_experiments.jl` and requires:

- Julia 1.10+
- ArgParse.jl package (added to project dependencies)
- JSON.jl package (already in dependencies)

## Usage

### Basic Syntax

```bash
julia tools/launch_experiments.jl --config <path/to/master_config.json> [OPTIONS]
```

### Options

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--config` | `-c` | (required) | Path to master configuration JSON file |
| `--target` | `-t` | `auto` | Launch target: `auto`, `local`, or `hpc` |
| `--hpc-host` | | `r04n02` | HPC hostname |
| `--hpc-user` | | `$USER` | HPC username |
| `--help` | `-h` | | Show help message |
| `--version` | | | Show version |

### Examples

#### Auto-detect and launch

```bash
# Automatically detects if running locally or on HPC
julia tools/launch_experiments.jl --config experiments/my_study/config_20251005/master_config.json
```

#### Force local launch

```bash
# Always launch on local machine
julia tools/launch_experiments.jl --config config.json --target local
```

#### Force HPC launch

```bash
# Always deploy to HPC cluster
julia tools/launch_experiments.jl --config config.json --target hpc
```

#### Custom HPC settings

```bash
# Use different HPC host/user
julia tools/launch_experiments.jl \
    --config config.json \
    --target hpc \
    --hpc-host gpu01 \
    --hpc-user myusername
```

## Configuration File Format

The tool expects a JSON configuration file with the following structure:

```json
{
  "experiment_name": "my_experiment",
  "campaigns": [
    {
      "campaign_id": "campaign_1",
      "experiments": [
        {
          "exp_id": "exp_1",
          "script": "experiment_1.jl"
        },
        {
          "exp_id": "exp_2",
          "script": "experiment_2.jl"
        }
      ]
    }
  ]
}
```

**Notes:**
- The `script` paths are relative to the config file directory
- You can use `../` to reference scripts in parent directories
- All referenced scripts must exist

## How It Works

### Environment Detection

The tool automatically detects your environment by checking:

1. **SLURM_JOB_ID** environment variable (HPC)
2. **Hostname patterns** (e.g., r04n02, gpu01, login01)
3. Otherwise assumes **local** environment

### Local Launch Workflow

1. Parse configuration file
2. Extract experiment scripts
3. For each script:
   - Launch as background process using `sh -c "julia script.jl > log.log 2>&1 &"`
   - Capture PID
   - Create log file (`script.log`)
4. Report PIDs of launched processes

**Log files** are created in the same directory as the script with `.log` extension.

### HPC Launch Workflow

1. Parse configuration file
2. **Sync files** to HPC using rsync:
   - Config directory → HPC
   - Setup scripts → HPC
3. **Launch experiments** via SSH:
   - Connect to HPC
   - Navigate to experiment directory
   - Use `nohup` for background execution
   - Redirect output to log files
4. **Verify** processes started
5. **Print monitoring commands** for user

## Monitoring Experiments

After launching on HPC, the tool provides commands to:

### Check logs

```bash
ssh user@host 'tail -20 globtimcore/experiments/study/configs_*/exp*.log'
```

### Check running processes

```bash
ssh user@host "ps aux | grep 'julia lotka' | grep -v grep"
```

### Download results

```bash
rsync -avz user@host:globtimcore/experiments/study/configs_*/ ./results/
```

## Example Workflows

### Local Testing

```bash
# Test experiments locally before deploying to HPC
julia tools/launch_experiments.jl \
    --config experiments/daisy_ex3_4d_study/configs_test/master_config.json \
    --target local

# Check logs
tail -f experiments/daisy_ex3_4d_study/configs_test/*.log
```

### HPC Production Run

```bash
# Deploy and launch on HPC
julia tools/launch_experiments.jl \
    --config experiments/daisy_ex3_4d_study/configs_20251005_105246/master_config.json \
    --target hpc \
    --hpc-host r04n02 \
    --hpc-user scholten

# (Tool will print monitoring commands)
```

### Wildcard Configs

```bash
# Launch most recent config directory
julia tools/launch_experiments.jl --config experiments/*/master_config.json
```

## Troubleshooting

### Config file not found

```
ERROR: Config file not found: path/to/config.json
```

**Solution:** Check the path is correct and file exists.

### No experiment scripts found

```
ERROR: No experiment scripts found in config: path/to/config.json
```

**Solution:** Verify your config JSON has the correct structure with `campaigns` and `experiments` arrays.

### SSH connection fails

Check:
- HPC hostname is correct
- You can SSH manually: `ssh user@host`
- Your SSH keys are set up

### Experiments not running on HPC

After launching, verify with:

```bash
ssh user@host "ps aux | grep julia"
```

Check logs for errors:

```bash
ssh user@host "cat globtimcore/experiments/study/configs_*/exp*.log"
```

## Testing

The tool includes comprehensive tests in `test/test_launch_experiments.jl`:

```bash
# Run all tests
julia --project=. -e 'using Test; include("test/test_launch_experiments.jl")'
```

Test coverage:
- Environment detection
- CLI argument parsing
- Local experiment launch
- Log file redirection
- Monitoring info generation
- Integration tests

## Implementation Notes

### Design Principles

1. **No fallbacks** - Errors are explicit, not hidden
2. **Test-driven** - All functionality has tests
3. **Clear errors** - Helpful messages when things fail
4. **Shell redirection** - Uses `sh -c` for reliable stdout/stderr capture

### Limitations

- **HPC sync** is currently hardcoded for `daisy_ex3_4d_study` structure
  - Future: Make experiment path detection more generic
- **Process verification** looks for specific Julia process patterns
  - Future: Use PID files or process tracking
- **No dry-run mode yet**
  - Future: Add `--dry-run` to preview actions

## Related Issues

- GitLab Issue #136: Create Unified Experiment Launch Helper Tool
- GitLab Issue #126: Automated experiment runner integration
- GitLab Issue #129: Automation epic

## Future Enhancements

- [ ] Add `--dry-run` mode
- [ ] Generic experiment path detection (not hardcoded to lotka_volterra)
- [ ] PID file tracking for better process management
- [ ] Progress monitoring during launch
- [ ] Automatic result download after completion
- [ ] Support for SLURM job submission (alternative to nohup)
- [ ] Email notifications on completion/failure

## Contributing

When modifying this tool:

1. **Update tests** - Add tests for new functionality
2. **Update docs** - Keep this README in sync
3. **Test locally** - Verify with mock configs before HPC testing
4. **Test on HPC** - Ensure SSH/rsync work correctly
5. **Update GitLab** - Note changes in issue #136

## License

GPL-3.0 (same as Globtim project)

## Authors

- Georgy Scholten <scholtengeorgy@gmail.com>
- Claude (Implementation assistance)
