#!/bin/bash
#SBATCH --job-name=globtim_comp_quick
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:10:00
#SBATCH --output=globtim_comp_587f142d_%j.out
#SBATCH --error=globtim_comp_587f142d_%j.err

echo "=== Globtim Compilation Test - QUICK MODE ==="
echo "Test ID: 587f142d"
echo "Function: Sphere"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start time: $(date)"
echo ""

# Environment setup
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
export JULIA_DEPOT_PATH="$HOME/globtim_hpc/.julia:$JULIA_DEPOT_PATH"

# Change to working directory
cd $HOME/globtim_hpc

echo "=== Environment Check ==="
echo "Working directory: $(pwd)"
echo "Julia threads: $JULIA_NUM_THREADS"
echo "Available space: $(df -h . | tail -1 | awk '{print $4}')"
echo "Julia version: $(/sw/bin/julia --version)"
echo ""

# Create output directory
mkdir -p globtim_compilation_test_587f142d
echo "✅ Output directory created: globtim_compilation_test_587f142d"

# Create input configuration
cat > globtim_compilation_test_587f142d/input_config.txt << 'EOF'
# Globtim Compilation Test Configuration
test_id: 587f142d
timestamp: $(date -Iseconds)
test_type: globtim_compilation
slurm_job_id: $SLURM_JOB_ID
function_name: Sphere
dimension: 2
center: [0.0, 0.0]
sample_range: 2.0
degree: 4
samples: 50
mode: quick
cpus: 4
memory: 8G
time_limit: 00:10:00
EOF

echo "✅ Input configuration created"

# Run the Globtim compilation test
echo ""
echo "=== Running Globtim Compilation Test ==="
/sw/bin/julia -e '
using Dates

println("🚀 Globtim Compilation Test Starting")
println("=" ^ 50)
println("Julia Version: $(VERSION)")
println("Start Time: $(now())")
println("Hostname: $(gethostname())")
println("Working Directory: $(pwd())")
println("Available Threads: $(Threads.nthreads())")
println()

output_dir = "globtim_compilation_test_587f142d"
function_name = "Sphere"
dimension = 2
center = [0.0, 0.0]
sample_range = 2.0
degree = 4
samples = 50

println("📋 Test Configuration:")
println("  Function: $function_name")
println("  Dimension: $dimension")
println("  Center: $center")
println("  Sample range: $sample_range")
println("  Degree: $degree")
println("  Samples: $samples")
println("  Output directory: $output_dir")
println()

# Test 1: Basic module loading
println("📦 Test 1: Module Loading")
try
    # Test basic Julia packages first
    using LinearAlgebra
    println("  ✅ LinearAlgebra loaded")
    
    using Statistics
    println("  ✅ Statistics loaded")
    
    # Try to load Globtim modules
    include("src/BenchmarkFunctions.jl")
    println("  ✅ BenchmarkFunctions.jl loaded")
    
    include("src/LibFunctions.jl") 
    println("  ✅ LibFunctions.jl loaded")
    
    include("src/Samples.jl")
    println("  ✅ Samples.jl loaded")
    
    include("src/Structures.jl")
    println("  ✅ Structures.jl loaded")
    
    # Save module loading results
    open(joinpath(output_dir, "module_loading_results.txt"), "w") do f
        println(f, "Module Loading Test Results")
        println(f, "===========================")
        println(f, "Timestamp: $(now())")
        println(f, "Julia Version: $(VERSION)")
        println(f, "Hostname: $(gethostname())")
        println(f, "")
        println(f, "Successfully loaded modules:")
        println(f, "- LinearAlgebra")
        println(f, "- Statistics") 
        println(f, "- BenchmarkFunctions.jl")
        println(f, "- LibFunctions.jl")
        println(f, "- Samples.jl")
        println(f, "- Structures.jl")
    end
    
    println("  ✅ Module loading test completed successfully")
    
catch e
    println("  ❌ Module loading failed: $e")
    
    # Save error info
    open(joinpath(output_dir, "module_loading_error.txt"), "w") do f
        println(f, "Module Loading Error")
        println(f, "===================")
        println(f, "Timestamp: $(now())")
        println(f, "Error: $e")
    end
    
    exit(1)
end

println()

# Test 2: Function evaluation
println("🧮 Test 2: Function Evaluation")
try
    # Get the function
    test_func = eval(Symbol(function_name))
    
    # Test function evaluation at center
    test_point = center
    func_value = test_func(test_point)
    
    println("  ✅ Function $function_name evaluated at $test_point")
    println("  ✅ Function value: $func_value")
    
    # Test function evaluation at a few random points
    test_results = []
    for i in 1:5
        random_point = center .+ (rand(dimension) .- 0.5) .* sample_range
        value = test_func(random_point)
        push!(test_results, (random_point, value))
        println("  ✅ f($random_point) = $value")
    end
    
    # Save function evaluation results
    open(joinpath(output_dir, "function_evaluation_results.txt"), "w") do f
        println(f, "Function Evaluation Test Results")
        println(f, "===============================")
        println(f, "Timestamp: $(now())")
        println(f, "Function: $function_name")
        println(f, "Dimension: $dimension")
        println(f, "")
        println(f, "Function value at center $center: $func_value")
        println(f, "")
        println(f, "Random point evaluations:")
        for (i, (point, value)) in enumerate(test_results)
            println(f, "  Point $i: $point -> $value")
        end
    end
    
    println("  ✅ Function evaluation test completed successfully")
    
catch e
    println("  ❌ Function evaluation failed: $e")
    
    # Save error info
    open(joinpath(output_dir, "function_evaluation_error.txt"), "w") do f
        println(f, "Function Evaluation Error")
        println(f, "========================")
        println(f, "Timestamp: $(now())")
        println(f, "Function: $function_name")
        println(f, "Error: $e")
    end
    
    exit(1)
end

println()

# Test 3: Basic test_input creation (if possible)
println("🔧 Test 3: Test Input Creation")
try
    test_func = eval(Symbol(function_name))
    
    # Try to create test input
    TR = test_input(test_func, 
                   dim=dimension,
                   center=center,
                   sample_range=sample_range,
                   GN=samples)
    
    println("  ✅ test_input created successfully")
    println("  ✅ Sample count: $(length(TR.sample_points))")
    println("  ✅ Function values computed: $(length(TR.function_values))")
    
    # Save test input results
    open(joinpath(output_dir, "test_input_results.txt"), "w") do f
        println(f, "Test Input Creation Results")
        println(f, "==========================")
        println(f, "Timestamp: $(now())")
        println(f, "Function: $function_name")
        println(f, "Dimension: $dimension")
        println(f, "Center: $center")
        println(f, "Sample range: $sample_range")
        println(f, "Number of samples: $samples")
        println(f, "")
        println(f, "Results:")
        println(f, "Sample points generated: $(length(TR.sample_points))")
        println(f, "Function values computed: $(length(TR.function_values))")
        println(f, "Min function value: $(minimum(TR.function_values))")
        println(f, "Max function value: $(maximum(TR.function_values))")
        println(f, "Mean function value: $(sum(TR.function_values) / length(TR.function_values))")
    end
    
    println("  ✅ Test input creation completed successfully")
    
catch e
    println("  ❌ Test input creation failed: $e")
    
    # Save error info  
    open(joinpath(output_dir, "test_input_error.txt"), "w") do f
        println(f, "Test Input Creation Error")
        println(f, "========================")
        println(f, "Timestamp: $(now())")
        println(f, "Function: $function_name")
        println(f, "Error: $e")
    end
    
    # This is not a fatal error for compilation test
    println("  ⚠️  Continuing despite test_input failure...")
end

println()
println("🎉 GLOBTIM COMPILATION TEST COMPLETED!")
println("End Time: $(now())")
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Job Summary ==="
echo "End time: $(date)"
echo "Duration: $SECONDS seconds"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > globtim_compilation_test_587f142d/job_summary.txt << EOF
# Globtim Compilation Test Job Summary
Test ID: 587f142d
SLURM Job ID: $SLURM_JOB_ID
Node: $SLURMD_NODENAME
Function: Sphere
Mode: quick
Start Time: $(date)
Duration: $SECONDS seconds
Julia Exit Code: $JULIA_EXIT_CODE
CPUs: 4
Memory: 8G
Time Limit: 00:10:00

# Generated Files:
$(ls -la globtim_compilation_test_587f142d/)
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Globtim compilation test completed successfully"
    echo "📁 Results available in: globtim_compilation_test_587f142d/"
else
    echo "❌ Globtim compilation test failed with exit code $JULIA_EXIT_CODE"
fi

exit $JULIA_EXIT_CODE
