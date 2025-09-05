"""
Globtim Notebook Setup - Universal Environment Configuration

This script automatically detects the environment and sets up the appropriate
configuration for local development vs HPC usage.

Usage in notebook (copy this into first cell):
    include(joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl"))

Features:
- Automatic local vs HPC environment detection
- Appropriate package loading for each environment
- Plotting backend configuration
- Clear status reporting
- Works from any directory in the project
"""

using Pkg

# Detect environment
function detect_environment()
    # Check if we're on an HPC cluster (common indicators)
    hpc_indicators = [
        haskey(ENV, "SLURM_JOB_ID"),           # SLURM scheduler
        haskey(ENV, "PBS_JOBID"),              # PBS scheduler  
        haskey(ENV, "LSB_JOBID"),              # LSF scheduler
        haskey(ENV, "SGE_JOB_ID"),             # SGE scheduler
        occursin("cluster", gethostname()),     # hostname contains "cluster"
        occursin("node", gethostname()),       # hostname contains "node"
        occursin("furiosa", gethostname()),    # Your specific cluster
    ]
    
    return any(hpc_indicators) ? :hpc : :local
end

# Get project root (works from any subdirectory)
function find_project_root()
    current_dir = @__DIR__
    while current_dir != "/"
        if isfile(joinpath(current_dir, "Project.toml")) &&
           isdir(joinpath(current_dir, "environments"))
            return current_dir
        end
        current_dir = dirname(current_dir)
    end
    error("Could not find Globtim project root (looking for Project.toml and environments/ folder)")
end

project_root = find_project_root()
env_type = detect_environment()

println("Environment detected: $env_type")

if env_type == :local
    println("Setting up local development environment...")
    env_path = joinpath(project_root, "environments", "local")

    # Activate local environment
    Pkg.activate(env_path)

    # Check if we need to instantiate
    if !isfile(joinpath(env_path, "Manifest.toml"))
        println("Installing local dependencies...")
        Pkg.instantiate()
    end
    
    # Load plotting packages
    try
        println("Loading CairoMakie...")
        using CairoMakie
        CairoMakie.activate!()
        println("CairoMakie activated for high-quality plots")

        # Also make GLMakie available
        using GLMakie
        println("GLMakie available for interactive plots")

    catch e
        println("Plotting packages not available: $e")
        println("Falling back to basic mode...")
    end
    
else  # HPC environment
    println("Setting up HPC environment...")
    env_path = joinpath(project_root, "environments", "hpc")

    # Activate HPC environment
    Pkg.activate(env_path)

    # Check if we need to instantiate
    if !isfile(joinpath(env_path, "Manifest.toml"))
        println("Installing HPC dependencies...")
        Pkg.instantiate()
    end

    println("HPC environment ready - optimized for computation")

    # Check if plotting is forced via environment variable
    force_plotting = get(ENV, "GLOBTIM_FORCE_PLOTTING", "false") == "true"

    if force_plotting
        try
            println("Loading CairoMakie (forced via GLOBTIM_FORCE_PLOTTING)...")
            using CairoMakie
            CairoMakie.activate!()
            println("CairoMakie activated for HPC plotting")
        catch e
            println("Warning: Could not load CairoMakie on HPC: $e")
        end
    else
        println("Plotting available via extensions if needed")
        println("Add plotting: using CairoMakie; CairoMakie.activate!()")
        println("Or set ENV[\"GLOBTIM_FORCE_PLOTTING\"] = \"true\" before setup")
    end
end

# Load core Globtim functionality from main project
try
    println("Loading Globtim from main project...")
    # Add main project to load path
    push!(LOAD_PATH, project_root)
    using Globtim
    using DynamicPolynomials: @polyvar
    using DynamicPolynomials, DataFrames
    using ProgressLogging

    println("Globtim loaded successfully!")
    println("Ready for $(env_type) development!")

    if env_type == :local
        println("Available: Full plotting, interactive development tools")
        println("Switch plotting: GLMakie.activate!() for interactive plots")
    else
        println("Optimized: Minimal dependencies, maximum performance")
        println("Add plotting: using CairoMakie; CairoMakie.activate!()")
    end

catch e
    println("Failed to load Globtim: $e")
    println("Try running: Pkg.instantiate()")
end
