"""
JSON-Tracked HPC Job Creator

Creates HPC jobs with comprehensive JSON-based input/output tracking.
Uses the new JSON tracking infrastructure to ensure full reproducibility
and systematic result collection.
"""

# Activate the main Globtim project environment
using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "..", ".."))

using Dates
using UUIDs
using JSON3

# Load JSON I/O utilities
include(joinpath(@__DIR__, "..", "..", "infrastructure", "json_io.jl"))

"""
Configuration for different job types
"""
struct JobConfig
    name::String
    description::String
    time_limit::String
    memory::String
    cpus::Int
    partition::String
end

const JOB_CONFIGS = Dict(
    "quick" => JobConfig(
        "quick_test",
        "Quick test with minimal parameters",
        "00:30:00",
        "16G",
        8,
        "batch"
    ),
    "standard" => JobConfig(
        "standard_test", 
        "Standard test with moderate parameters",
        "02:00:00",
        "32G",
        16,
        "batch"
    ),
    "thorough" => JobConfig(
        "thorough_test",
        "Thorough test with comprehensive parameters", 
        "04:00:00",
        "64G",
        24,
        "batch"
    ),
    "long" => JobConfig(
        "long_test",
        "Long-running test for complex problems",
        "12:00:00",
        "128G",
        24,
        "long"
    )
)

"""
    create_deuflhard_job(job_type::String="standard"; degree::Int=8, 
                        basis::Symbol=:chebyshev, samples::Int=100,
                        sample_range::Float64=1.5, enable_hessian::Bool=true,
                        tags::Vector{String}=String[], description::String="")

Create a Deuflhard benchmark job with JSON tracking.
"""
function create_deuflhard_job(job_type::String="standard"; 
                             degree::Int=8, basis::Symbol=:chebyshev, 
                             samples::Int=100, sample_range::Float64=1.5,
                             enable_hessian::Bool=true, tags::Vector{String}=String[],
                             description::String="")
    
    if !haskey(JOB_CONFIGS, job_type)
        error("Unknown job type: $job_type. Available: $(keys(JOB_CONFIGS))")
    end
    
    config = JOB_CONFIGS[job_type]
    computation_id = generate_computation_id()
    
    println("🚀 Creating JSON-tracked Deuflhard job")
    println("=" ^ 50)
    println("Job type: $job_type")
    println("Computation ID: $computation_id")
    println("Description: $(config.description)")
    println()
    
    # Create job-specific description
    if isempty(description)
        description = "deg$(degree)_$(basis)_$(job_type)"
    end
    
    # Set up default tags
    default_tags = ["deuflhard", "2d", string(basis), "degree$degree", job_type]
    all_tags = unique(vcat(default_tags, tags))
    
    # Create test input configuration
    println("📋 Creating input configuration...")

    # Note: We don't need to create the actual test_input here,
    # just the configuration parameters that will be used in the job
    
    # Create metadata
    metadata = Dict(
        "computation_id" => computation_id,
        "timestamp" => string(now()),
        "function_name" => "Deuflhard",
        "description" => "$(config.description) - $description",
        "tags" => all_tags,
        "job_type" => job_type
    )
    
    # Create input configuration
    input_config = Dict(
        "metadata" => metadata,
        "test_input" => Dict(
            "function_name" => "Deuflhard",
            "dimension" => 2,
            "center" => [0.0, 0.0],
            "sample_range" => sample_range,
            "GN" => samples,
            "tolerance" => nothing,
            "precision_params" => nothing,
            "noise_params" => nothing,
            "reduce_samples" => nothing,
            "degree_max" => nothing
        ),
        "polynomial_construction" => Dict(
            "degree" => degree,
            "basis" => string(basis),
            "precision_type" => "RationalPrecision",
            "normalized" => false,
            "power_of_two_denom" => false,
            "verbose" => 0
        ),
        "critical_point_analysis" => Dict(
            "tol_dist" => 0.001,
            "enable_hessian" => enable_hessian,
            "max_iters_in_optim" => 100,
            "hessian_tol_zero" => 1e-8,
            "bfgs_g_tol" => 1e-8,
            "bfgs_f_abstol" => 1e-8,
            "bfgs_x_abstol" => 0.0,
            "verbose" => true
        ),
        "computational_environment" => Dict(
            "time_limit" => config.time_limit,
            "memory_limit" => config.memory,
            "cpus" => config.cpus,
            "partition" => config.partition
        )
    )
    
    # Create output directory (use absolute path from project root)
    project_root = joinpath(@__DIR__, "..", "..", "..")
    results_base = joinpath(project_root, "hpc", "results")
    output_dir = create_computation_directory(results_base, "Deuflhard", computation_id, description)
    
    println("✅ Output directory created: $output_dir")
    
    # Save input configuration
    input_config_path = joinpath(output_dir, "input_config.json")
    save_input_config(input_config, input_config_path)
    
    # Create SLURM job script from template
    println("📄 Creating SLURM job script...")

    # Find template path relative to script location
    script_dir = @__DIR__
    template_path = joinpath(script_dir, "..", "templates", "globtim_json_tracking.slurm.template")

    if !isfile(template_path)
        error("Template file not found: $template_path")
    end
    
    template_content = read(template_path, String)
    
    # Replace template variables
    job_name = "$(config.name)_$(computation_id)"
    replacements = Dict(
        "{{JOB_NAME}}" => job_name,
        "{{COMPUTATION_ID}}" => computation_id,
        "{{FUNCTION_NAME}}" => "Deuflhard",
        "{{PARTITION}}" => config.partition,
        "{{CPUS}}" => string(config.cpus),
        "{{MEMORY}}" => config.memory,
        "{{TIME_LIMIT}}" => config.time_limit,
        "{{OUTPUT_DIR}}" => output_dir
    )
    
    job_script = template_content
    for (placeholder, value) in replacements
        job_script = replace(job_script, placeholder => value)
    end
    
    # Write job script
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    job_filename = "$(job_name)_$(timestamp).slurm"
    job_path = joinpath(output_dir, job_filename)
    
    open(job_path, "w") do f
        write(f, job_script)
    end
    
    println("✅ SLURM job script created: $job_path")
    
    # Create symlinks for organization
    create_symlinks(output_dir, computation_id, "Deuflhard", all_tags)
    println("✅ Organization symlinks created")
    
    # Print summary
    println()
    println("📊 Job Configuration Summary:")
    println("   Function: Deuflhard")
    println("   Dimension: 2")
    println("   Degree: $degree")
    println("   Basis: $basis")
    println("   Samples: $samples")
    println("   Sample range: $sample_range")
    println("   Hessian analysis: $enable_hessian")
    println("   Time limit: $(config.time_limit)")
    println("   Memory: $(config.memory)")
    println("   CPUs: $(config.cpus)")
    println("   Partition: $(config.partition)")
    println("   Tags: $(join(all_tags, ", "))")
    println()
    
    println("🚀 To submit this job:")
    println("   scp $job_path scholten@falcon:~/globtim_hpc/")
    println("   ssh scholten@falcon 'cd ~/globtim_hpc && sbatch $(basename(job_path))'")
    println()
    
    println("📊 Monitor with:")
    println("   python hpc/monitoring/python/slurm_monitor.py --job [JOB_ID]")
    println()
    
    println("📁 Results will be available in:")
    println("   $output_dir")
    println()
    
    result = Dict(
        "computation_id" => computation_id,
        "job_script_path" => job_path,
        "output_directory" => output_dir,
        "input_config_path" => input_config_path
    )

    # Output machine-readable summary for automation scripts
    println()
    println("=== AUTOMATION_INFO ===")
    println("COMPUTATION_ID=$computation_id")
    println("JOB_SCRIPT_PATH=$job_path")
    println("OUTPUT_DIRECTORY=$output_dir")
    println("=== END_AUTOMATION_INFO ===")

    return result
end

"""
    create_custom_job(function_name::String, dimension::Int, center::Vector{Float64},
                     sample_range::Float64; kwargs...)

Create a custom job for any function with JSON tracking.
"""
function create_custom_job(function_name::String, dimension::Int, center::Vector{Float64},
                          sample_range::Float64; job_type::String="standard", 
                          degree::Int=6, basis::Symbol=:chebyshev, samples::Int=100,
                          enable_hessian::Bool=true, tags::Vector{String}=String[],
                          description::String="", kwargs...)
    
    # Similar implementation to create_deuflhard_job but with custom parameters
    # This would be expanded based on specific needs
    
    println("🚧 Custom job creation not yet fully implemented")
    println("   Function: $function_name")
    println("   Dimension: $dimension")
    println("   Center: $center")
    println("   Sample range: $sample_range")
    
    return nothing
end

# Command line interface
function main()
    if length(ARGS) == 0
        println("JSON-Tracked HPC Job Creator")
        println()
        println("Usage:")
        println("  julia create_json_tracked_job.jl deuflhard [job_type] [options]")
        println()
        println("Job types: $(join(keys(JOB_CONFIGS), ", "))")
        println()
        println("Examples:")
        println("  julia create_json_tracked_job.jl deuflhard quick")
        println("  julia create_json_tracked_job.jl deuflhard standard --degree 10")
        println("  julia create_json_tracked_job.jl deuflhard thorough --basis legendre")
        return
    end
    
    if ARGS[1] == "deuflhard"
        job_type = length(ARGS) >= 2 ? ARGS[2] : "standard"
        
        # Parse additional options (simplified for now)
        degree = 8
        basis = :chebyshev
        
        for i in 3:length(ARGS)
            if ARGS[i] == "--degree" && i < length(ARGS)
                degree = parse(Int, ARGS[i+1])
            elseif ARGS[i] == "--basis" && i < length(ARGS)
                basis = Symbol(ARGS[i+1])
            end
        end
        
        result = create_deuflhard_job(job_type, degree=degree, basis=basis)
        println("✅ Job created successfully!")
        
    else
        println("❌ Unknown function: $(ARGS[1])")
        println("Available functions: deuflhard")
    end
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
