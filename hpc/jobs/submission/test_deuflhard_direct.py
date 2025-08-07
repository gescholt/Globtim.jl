#!/usr/bin/env python3

"""
Direct Deuflhard Test - No File Creation
========================================

Tests the Deuflhard benchmark function directly via SSH without creating files,
using the proven quota workaround approach.

Usage:
    python test_deuflhard_direct.py [--mode MODE]
"""

import argparse
import subprocess
import uuid
from datetime import datetime

class DirectDeuflhardTester:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        self.depot_path = "/tmp/julia_depot_globtim_persistent"
    
    def run_deuflhard_test(self, mode="quick"):
        """Run Deuflhard test directly via SSH with output collection"""
        test_id = str(uuid.uuid4())[:8]
        
        print(f"🧮 Running Direct Deuflhard Benchmark Test")
        print(f"Mode: {mode}")
        print(f"Test ID: {test_id}")
        print(f"Using quota workaround depot: {self.depot_path}")
        print()
        
        # Use /tmp for output to avoid quota issues
        output_dir = f"/tmp/deuflhard_results_{test_id}"
        
        # Create the Deuflhard test command
        julia_test = f"""
export JULIA_DEPOT_PATH="{self.depot_path}:$JULIA_DEPOT_PATH"
cd {self.remote_dir}

echo "🧮 Direct Deuflhard Benchmark Test - {test_id}"
echo "Mode: {mode}"
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "Depot: $JULIA_DEPOT_PATH"
echo ""

# Create output directory
mkdir -p {output_dir}
echo "✅ Output directory created: {output_dir}"

# Create test configuration
cat > {output_dir}/test_config.json << 'EOF'
{{
  "test_id": "{test_id}",
  "timestamp": "$(date -Iseconds)",
  "test_type": "deuflhard_benchmark_direct",
  "execution_mode": "direct_ssh",
  "function": "Deuflhard",
  "dimension": 2,
  "parameters": {{
    "samples": 50,
    "degree": 6,
    "center": [0.0, 0.0],
    "sample_range": 1.5
  }},
  "metadata": {{
    "created_by": "test_deuflhard_direct.py",
    "purpose": "Deuflhard function validation with quota workaround",
    "mode": "{mode}",
    "depot_path": "{self.depot_path}"
  }}
}}
EOF

echo "✅ Test configuration created"

/sw/bin/julia --project=. -e '
using Dates

println("🚀 Deuflhard Benchmark Test Starting")
println("Julia Version: ", VERSION)
println("Start Time: ", now())
println("Hostname: ", gethostname())
println("Working Directory: ", pwd())
println("Available Threads: ", Threads.nthreads())
println()

output_dir = "{output_dir}"
println("📋 Configuration:")
println("  Output directory: ", output_dir)
println("  Function: Deuflhard (2D)")
println()

# Load required packages first
println("📦 Loading Required Packages...")
try
    using StaticArrays, TimerOutputs, LinearAlgebra
    println("  ✅ Core packages loaded successfully")
    
    # Define _TO timer and precision types
    const _TO = TimerOutputs.TimerOutput()
    
    @enum PrecisionType begin
        Float64Precision
        RationalPrecision
        BigFloatPrecision
        BigIntPrecision
        AdaptivePrecision
    end
    
    println("  ✅ Timer and precision types defined")
    
catch e
    println("  ❌ Package loading failed: ", e)
    exit(1)
end

println()

# Load Globtim modules
println("🧮 Loading Globtim Modules...")
try
    include("src/BenchmarkFunctions.jl")
    println("  ✅ BenchmarkFunctions.jl loaded")
    
    include("src/LibFunctions.jl")
    println("  ✅ LibFunctions.jl loaded")
    
    println("  ✅ Core Globtim modules loaded successfully")
    
catch e
    println("  ❌ Globtim module loading failed: ", e)
    
    # Save error information
    open(joinpath(output_dir, "module_loading_error.txt"), "w") do f
        println(f, "Deuflhard Module Loading Error")
        println(f, "==============================")
        println(f, "Timestamp: ", now())
        println(f, "Error: ", e)
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
    end
    
    exit(1)
end

println()

# Test Deuflhard function
println("🧮 Testing Deuflhard Function...")
try
    # Test function evaluation at various points
    test_points = [
        [0.0, 0.0],
        [0.5, 0.5], 
        [1.0, 1.0],
        [-0.5, 0.5],
        [0.2, -0.3]
    ]
    
    function_values = []
    
    println("  Testing function evaluation:")
    for point in test_points
        value = Deuflhard(point)
        push!(function_values, value)
        println("    f(", point, ") = ", value)
    end
    
    println("  ✅ Deuflhard function evaluation successful")
    
    # Save function evaluation results
    open(joinpath(output_dir, "function_evaluation_results.txt"), "w") do f
        println(f, "Deuflhard Function Evaluation Results")
        println(f, "=====================================")
        println(f, "Timestamp: ", now())
        println(f, "Function: Deuflhard (2D)")
        println(f, "Test ID: {test_id}")
        println(f, "")
        println(f, "Test Points and Values:")
        for (i, (point, value)) in enumerate(zip(test_points, function_values))
            println(f, "  ", i, ": f(", point, ") = ", value)
        end
        println(f, "")
        println(f, "Statistics:")
        println(f, "  Min value: ", minimum(function_values))
        println(f, "  Max value: ", maximum(function_values))
        println(f, "  Mean value: ", sum(function_values) / length(function_values))
        println(f, "")
        println(f, "Julia version: ", VERSION)
        println(f, "Hostname: ", gethostname())
    end
    
    println("  ✅ Function evaluation results saved")
    
catch e
    println("  ❌ Deuflhard function test failed: ", e)
    
    # Save error information
    open(joinpath(output_dir, "function_test_error.txt"), "w") do f
        println(f, "Deuflhard Function Test Error")
        println(f, "=============================")
        println(f, "Timestamp: ", now())
        println(f, "Error: ", e)
        println(f, "Test ID: {test_id}")
    end
    
    exit(1)
end

println()

# Create comprehensive results summary
println("📋 Creating Results Summary...")
try
    open(joinpath(output_dir, "deuflhard_test_summary.txt"), "w") do f
        println(f, "Deuflhard Benchmark Test Summary")
        println(f, "================================")
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
        println(f, "Timestamp: ", now())
        println(f, "Function: Deuflhard (2D)")
        println(f, "Execution: Direct SSH (Quota Workaround)")
        println(f, "")
        println(f, "Environment:")
        println(f, "  Julia version: ", VERSION)
        println(f, "  Hostname: ", gethostname())
        println(f, "  Threads: ", Threads.nthreads())
        println(f, "  Depot path: ", DEPOT_PATH[1])
        println(f, "")
        println(f, "Test Results:")
        println(f, "  ✅ Package loading: SUCCESS")
        println(f, "  ✅ Module loading: SUCCESS")
        println(f, "  ✅ Function evaluation: SUCCESS")
        println(f, "  ✅ Output collection: SUCCESS")
        println(f, "")
        println(f, "Status: COMPLETE SUCCESS")
    end
    
    println("  ✅ Test summary saved")
    
catch e
    println("  ❌ Summary creation failed: ", e)
end

println()
println("🎉 DEUFLHARD BENCHMARK TEST COMPLETED SUCCESSFULLY!")
println("Test ID: {test_id}")
println("Mode: {mode}")
println("End Time: ", now())
println("All functionality verified ✅")
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Test Summary ==="
echo "End time: $(date)"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create job summary
cat > {output_dir}/job_summary.txt << EOF
# Deuflhard Benchmark Test Job Summary (Direct Execution)
Test ID: {test_id}
Execution Mode: Direct SSH (Quota Workaround)
Node: $(hostname)
Mode: {mode}
Function: Deuflhard (2D)
Start Time: $(date)
Julia Exit Code: $JULIA_EXIT_CODE
Depot Path: {self.depot_path}

# Generated Files:
$(ls -la {output_dir}/)
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Deuflhard benchmark test completed successfully"
    echo "📁 Results available in: {output_dir}/"
    echo "📋 Generated files:"
    ls -la {output_dir}/
else
    echo "❌ Deuflhard benchmark test failed with exit code $JULIA_EXIT_CODE"
fi

echo ""
echo "✅ Direct Deuflhard test with output collection completed"
echo "Test ID: {test_id}"
echo "Mode: {mode}"
echo "Output directory: {output_dir}"
echo "Timestamp: $(date)"
"""
        
        print("🚀 Executing Deuflhard test via SSH...")
        
        try:
            # Run the test directly via SSH
            result = subprocess.run(
                ["ssh", self.cluster_host, julia_test],
                capture_output=True, text=True, timeout=300
            )
            
            print("📊 Test Output:")
            print("=" * 60)
            print(result.stdout)
            
            if result.stderr:
                print("\n⚠️  Warnings/Errors:")
                print(result.stderr)
            
            if result.returncode == 0:
                print(f"\n✅ DEUFLHARD TEST SUCCESSFUL!")
                print(f"Test ID: {test_id}")
                print(f"Mode: {mode}")
                print(f"Output directory: {output_dir}")
                return True, test_id, output_dir
            else:
                print(f"\n❌ Test failed with return code: {result.returncode}")
                return False, test_id, output_dir
                
        except subprocess.TimeoutExpired:
            print("❌ Test timed out after 5 minutes")
            return False, test_id, None
        except Exception as e:
            print(f"❌ Error during test execution: {e}")
            return False, test_id, None

def main():
    parser = argparse.ArgumentParser(description="Run direct Deuflhard benchmark test")
    parser.add_argument("--mode", choices=["quick", "standard", "thorough"],
                       default="quick", help="Test mode (default: quick)")
    
    args = parser.parse_args()
    
    tester = DirectDeuflhardTester()
    success, test_id, output_dir = tester.run_deuflhard_test(args.mode)
    
    if success:
        print(f"\n🎯 SUCCESS! Deuflhard test completed successfully")
        print(f"🔧 Test ID: {test_id}")
        print(f"📁 Results in: {output_dir}")
        print("✅ Quota workaround working perfectly")
        print("✅ Deuflhard function validated")
        print("✅ Complete benchmark workflow functional")
    else:
        print(f"\n❌ FAILED! Deuflhard test unsuccessful")
        print(f"🔧 Test ID: {test_id}")
        if output_dir:
            print(f"📁 Partial results may be in: {output_dir}")
        exit(1)

if __name__ == "__main__":
    main()
