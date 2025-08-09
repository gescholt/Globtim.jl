#!/usr/bin/env julia

"""
Deuflhard Function Test with Full Globtim Environment
Tests the actual Deuflhard function from Globtim with proper HPC configuration
"""

using Dates
using Printf

println("=== Deuflhard Globtim Test ===")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("SLURM Job ID: ", get(ENV, "SLURM_JOB_ID", "not_set"))
println("Working Directory: ", pwd())
println()

# Step 1: Set up HPC environment
println("🔧 Step 1: Setting up HPC Environment")
try
    # Use HPC-specific Project.toml (no plotting packages)
    if isfile("Project_HPC.toml")
        println("  ✅ Found HPC-specific Project.toml")
        
        # Activate HPC environment
        using Pkg
        Pkg.activate(".")
        
        # Copy HPC project file to main Project.toml temporarily
        cp("Project_HPC.toml", "Project.toml", force=true)
        println("  ✅ Activated HPC environment")
        
        # Instantiate to ensure all packages are available
        println("  📦 Instantiating HPC environment...")
        Pkg.instantiate()
        println("  ✅ HPC environment ready")
    else
        println("  ⚠️  No HPC Project.toml found, using default environment")
    end
catch e
    println("  ❌ Error setting up environment: $e")
end
println()

# Step 2: Load Globtim package
println("📦 Step 2: Loading Globtim Package")
try
    # Load core Globtim modules
    println("  📥 Loading Globtim.jl...")
    include("src/Globtim.jl")
    println("  ✅ Globtim.jl loaded")
    
    # Import Globtim namespace
    using .Globtim
    println("  ✅ Globtim namespace imported")
    
    # Check if Deuflhard is available
    if isdefined(Globtim, :Deuflhard)
        println("  ✅ Deuflhard function found in Globtim")
    else
        println("  ⚠️  Deuflhard function not found, checking LibFunctions...")
        include("src/LibFunctions.jl")
        if @isdefined(Deuflhard)
            println("  ✅ Deuflhard function loaded from LibFunctions")
        else
            println("  ❌ Deuflhard function not available")
        end
    end
    
catch e
    println("  ❌ Error loading Globtim: $e")
    println("  🔄 Trying alternative loading method...")
    
    try
        # Alternative: Load individual modules
        include("src/LibFunctions.jl")
        include("src/BenchmarkFunctions.jl")
        println("  ✅ Individual modules loaded")
    catch e2
        println("  ❌ Alternative loading failed: $e2")
    end
end
println()

# Step 3: Test Deuflhard function
println("🧮 Step 3: Testing Deuflhard Function")
test_points = [
    [0.0, 0.0],
    [0.1, 0.1],
    [0.5, 0.5],
    [1.0, 1.0],
    [1.5, 1.5],
    [-0.5, 0.5],
    [0.25, 0.75],
    [2.0, 0.0],
    [0.0, 2.0],
    [-1.0, -1.0]
]

results = []
successful_evaluations = 0

for (i, point) in enumerate(test_points)
    try
        if @isdefined(Deuflhard)
            value = Deuflhard(point)
            push!(results, (point, value, "SUCCESS"))
            successful_evaluations += 1
            @printf("  Point %2d: Deuflhard([%6.3f, %6.3f]) = %12.6f ✅\n", i, point[1], point[2], value)
        else
            push!(results, (point, NaN, "FUNCTION_NOT_AVAILABLE"))
            println("  Point $i: Deuflhard function not available ❌")
        end
    catch e
        push!(results, (point, NaN, "ERROR: $e"))
        println("  Point $i: Error at $point - $e ❌")
    end
end

println()
println("📊 Evaluation Summary:")
println("  Total points: $(length(test_points))")
println("  Successful evaluations: $successful_evaluations")
println("  Success rate: $(round(100*successful_evaluations/length(test_points), digits=1))%")
println()

# Step 4: Save results
println("💾 Step 4: Saving Results")
try
    # Create results directory
    results_dir = "results"
    if !isdir(results_dir)
        mkdir(results_dir)
        println("  ✅ Created results directory")
    end
    
    # Generate unique test ID
    test_id = "deuflhard_globtim_$(replace(string(now()), ":" => ""))"
    test_results_dir = joinpath(results_dir, test_id)
    mkdir(test_results_dir)
    println("  ✅ Created test results directory: $test_results_dir")
    
    # Save CSV results
    csv_file = joinpath(test_results_dir, "deuflhard_evaluations.csv")
    open(csv_file, "w") do f
        println(f, "point_id,x1,x2,function_value,status,timestamp")
        for (i, (point, value, status)) in enumerate(results)
            println(f, "$i,$(point[1]),$(point[2]),$value,$status,$(now())")
        end
    end
    println("  ✅ CSV results saved: $csv_file")
    
    # Save detailed summary
    summary_file = joinpath(test_results_dir, "test_summary.txt")
    open(summary_file, "w") do f
        println(f, "Deuflhard Globtim Test Summary")
        println(f, "=============================")
        println(f, "")
        println(f, "Test Details:")
        println(f, "- Test ID: $test_id")
        println(f, "- Julia version: $(VERSION)")
        println(f, "- Hostname: $(gethostname())")
        println(f, "- SLURM Job ID: $(get(ENV, "SLURM_JOB_ID", "not_set"))")
        println(f, "- Timestamp: $(now())")
        println(f, "- Working directory: $(pwd())")
        println(f, "")
        println(f, "Environment:")
        println(f, "- Globtim loaded: $(@isdefined(Globtim) ? "Yes" : "No")")
        println(f, "- Deuflhard available: $(@isdefined(Deuflhard) ? "Yes" : "No")")
        println(f, "- HPC environment: $(isfile("Project_HPC.toml") ? "Yes" : "No")")
        println(f, "")
        println(f, "Results:")
        println(f, "- Total evaluation points: $(length(test_points))")
        println(f, "- Successful evaluations: $successful_evaluations")
        println(f, "- Success rate: $(round(100*successful_evaluations/length(test_points), digits=1))%")
        println(f, "")
        println(f, "Detailed Results:")
        for (i, (point, value, status)) in enumerate(results)
            if status == "SUCCESS"
                @printf(f, "  Point %2d: f([%6.3f, %6.3f]) = %12.6f\n", i, point[1], point[2], value)
            else
                println(f, "  Point $i: f($point) = $status")
            end
        end
    end
    println("  ✅ Summary saved: $summary_file")
    
    # Save environment info
    env_file = joinpath(test_results_dir, "environment_info.txt")
    open(env_file, "w") do f
        println(f, "Julia Environment Information")
        println(f, "============================")
        println(f, "")
        println(f, "Julia Version: $(VERSION)")
        println(f, "Hostname: $(gethostname())")
        println(f, "Working Directory: $(pwd())")
        println(f, "")
        println(f, "Environment Variables:")
        for var in ["SLURM_JOB_ID", "SLURM_CPUS_PER_TASK", "SLURM_MEM_PER_NODE", "JULIA_DEPOT_PATH"]
            println(f, "  $var: $(get(ENV, var, "not_set"))")
        end
        println(f, "")
        println(f, "Julia Depot Paths:")
        for (i, path) in enumerate(DEPOT_PATH)
            println(f, "  $i: $path")
        end
        println(f, "")
        println(f, "Available Files:")
        println(f, "  Project_HPC.toml: $(isfile("Project_HPC.toml"))")
        println(f, "  src/Globtim.jl: $(isfile("src/Globtim.jl"))")
        println(f, "  src/LibFunctions.jl: $(isfile("src/LibFunctions.jl"))")
        println(f, "  src/BenchmarkFunctions.jl: $(isfile("src/BenchmarkFunctions.jl"))")
    end
    println("  ✅ Environment info saved: $env_file")
    
    println()
    println("📁 All results saved to: $test_results_dir")
    
catch e
    println("  ❌ Error saving results: $e")
end

println()
println("=== Deuflhard Globtim Test Complete ===")
println("End Time: ", now())

# Exit with appropriate code
if successful_evaluations > 0
    println("✅ Test completed with $(successful_evaluations) successful evaluations")
    exit(0)
else
    println("❌ Test completed with no successful evaluations")
    exit(1)
end
