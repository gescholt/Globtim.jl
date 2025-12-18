# Globtim Notebook Setup Template

## Standard First Cell for All Notebooks

Copy and paste this code into the first cell of any Globtim notebook:

```julia
# Globtim Notebook Setup - Universal Header Cell
# This cell automatically detects your environment and sets up the appropriate configuration
# No editing required - works from any location in the project

include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))
```

## Alternative Setup (if the above doesn't work)

If you encounter issues with the automatic detection, use this fallback:

```julia
# Globtim Notebook Setup - Manual Fallback
# Navigate to project root and include setup

# Find project root
current_dir = pwd()
while !isfile(joinpath(current_dir, "Project.toml")) || !isdir(joinpath(current_dir, "environments"))
    parent_dir = dirname(current_dir)
    if parent_dir == current_dir
        error("Could not find Globtim project root")
    end
    current_dir = parent_dir
end

include(joinpath(current_dir, ".globtim", "notebook_setup.jl"))
```

## What This Does

The setup cell will:

1. **Detect Environment**: Automatically determine if you're on local machine or HPC cluster
2. **Activate Appropriate Environment**: 
   - Local: Full plotting capabilities with CairoMakie, GLMakie, development tools
   - HPC: Minimal dependencies optimized for computation
3. **Load Core Packages**: Globtim, DynamicPolynomials, DataFrames, etc.
4. **Configure Plotting**: Set up appropriate plotting backend for your environment
5. **Provide Status**: Clear feedback on what was loaded and available features

## Expected Output

### Local Environment
```
Environment detected: local
Setting up local development environment...
Loading CairoMakie...
CairoMakie activated for high-quality plots
GLMakie available for interactive plots
Loading Globtim from main project...
Globtim loaded successfully!
Ready for local development!
Available: Full plotting, interactive development tools
Switch plotting: GLMakie.activate!() for interactive plots
```

### HPC Environment
```
Environment detected: hpc
Setting up HPC environment...
Loading Globtim from main project...
Globtim loaded successfully!
Ready for hpc development!
Optimized: Minimal dependencies, maximum performance
Add plotting: using CairoMakie; CairoMakie.activate!()
```

## Troubleshooting

If the setup fails:

1. **Check Project Structure**: Ensure you're in a Globtim project directory
2. **Verify Environments**: Make sure `environments/local/` and `environments/hpc/` exist
3. **Manual Setup**: Use the alternative setup code above
4. **Environment Issues**: Run the validation script (see documentation)

## Usage in Different Scenarios

### New Notebook
1. Create new notebook in any subdirectory of the project
2. Add the standard first cell
3. Run the cell
4. Start your analysis

### Existing Notebook
1. Add the standard first cell at the top
2. Remove any old environment setup code
3. Run the new setup cell
4. Continue with your analysis

### Sharing Notebooks
- Notebooks with this setup cell work for anyone with the Globtim project
- No need to modify paths or environment settings
- Automatically adapts to local vs HPC environments
