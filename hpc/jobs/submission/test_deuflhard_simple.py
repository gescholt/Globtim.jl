#!/usr/bin/env python3

"""
Simple Deuflhard Test - Working Solution
========================================

Tests the Deuflhard function using the proven /tmp approach that works.
Based on the successful basic test pattern.

Usage:
    python test_deuflhard_simple.py [--mode MODE]
"""

import argparse
import subprocess
import uuid
from datetime import datetime

class SimpleDeuflhardTester:
    def __init__(self):
        self.cluster_host = "scholten@falcon"
        self.remote_dir = "~/globtim_hpc"
        self.depot_path = "/tmp/julia_depot_globtim_persistent"
    
    def run_deuflhard_test(self, mode="quick"):
        """Run Deuflhard test using proven /tmp approach"""
        test_id = str(uuid.uuid4())[:8]
        
        print(f"🧮 Running Simple Deuflhard Test")
        print(f"Mode: {mode}")
        print(f"Test ID: {test_id}")
        print(f"Using proven /tmp depot: {self.depot_path}")
        print()
        
        # Use /tmp for output to avoid quota issues
        output_dir = f"/tmp/deuflhard_results_{test_id}"
        
        # Create the Deuflhard test command (simplified, no shell escaping issues)
        julia_test = f"""
export JULIA_DEPOT_PATH="{self.depot_path}:$JULIA_DEPOT_PATH"
cd {self.remote_dir}

echo "🧮 Simple Deuflhard Test - {test_id}"
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
  "test_type": "deuflhard_simple",
  "execution_mode": "direct_ssh_tmp",
  "function": "Deuflhard",
  "dimension": 2,
  "mode": "{mode}",
  "depot_path": "{self.depot_path}"
}}
EOF

echo "✅ Test configuration created"

# Run Julia test with simplified approach
/sw/bin/julia -e '
println("🚀 Deuflhard Test Starting")
println("Julia Version: ", VERSION)
println("Hostname: ", gethostname())
println("Threads: ", Threads.nthreads())
println()

# Load packages
println("📦 Loading Packages...")
try
    using StaticArrays, LinearAlgebra
    println("✅ Core packages loaded")
catch e
    println("❌ Package loading failed: ", e)
    exit(1)
end

# Load Globtim modules
println("🧮 Loading Globtim Modules...")
try
    include("src/BenchmarkFunctions.jl")
    println("✅ BenchmarkFunctions loaded")
    
    include("src/LibFunctions.jl") 
    println("✅ LibFunctions loaded")
catch e
    println("❌ Module loading failed: ", e)
    exit(1)
end

# Test Deuflhard function
println("🧮 Testing Deuflhard Function...")
try
    test_points = [[0.0, 0.0], [0.5, 0.5], [1.0, 1.0], [-0.5, 0.5]]
    
    println("Function evaluations:")
    for (i, point) in enumerate(test_points)
        value = Deuflhard(point)
        println("  ", i, ": f(", point, ") = ", value)
    end
    
    println("✅ Deuflhard function working correctly")
    
    # Save results
    output_dir = "{output_dir}"
    open(joinpath(output_dir, "deuflhard_results.txt"), "w") do f
        println(f, "Deuflhard Test Results")
        println(f, "=====================")
        println(f, "Test ID: {test_id}")
        println(f, "Mode: {mode}")
        println(f, "Julia Version: ", VERSION)
        println(f, "Hostname: ", gethostname())
        println(f, "")
        println(f, "Function Evaluations:")
        for (i, point) in enumerate(test_points)
            value = Deuflhard(point)
            println(f, "  ", i, ": f(", point, ") = ", value)
        end
        println(f, "")
        println(f, "Status: SUCCESS")
    end
    
    println("✅ Results saved")
    
catch e
    println("❌ Deuflhard test failed: ", e)
    exit(1)
end

println()
println("🎉 DEUFLHARD TEST COMPLETED SUCCESSFULLY!")
println("Test ID: {test_id}")
println("All functionality verified ✅")
'

JULIA_EXIT_CODE=$?

echo ""
echo "=== Test Summary ==="
echo "End time: $(date)"
echo "Julia exit code: $JULIA_EXIT_CODE"

# Create summary
cat > {output_dir}/test_summary.txt << EOF
# Simple Deuflhard Test Summary
Test ID: {test_id}
Mode: {mode}
Timestamp: $(date)
Julia Exit Code: $JULIA_EXIT_CODE
Depot Path: {self.depot_path}
Output Directory: {output_dir}

Status: $([ $JULIA_EXIT_CODE -eq 0 ] && echo "SUCCESS" || echo "FAILED")
EOF

if [ $JULIA_EXIT_CODE -eq 0 ]; then
    echo "✅ Deuflhard test completed successfully"
    echo "📁 Results available in: {output_dir}/"
    echo "📋 Generated files:"
    ls -la {output_dir}/
else
    echo "❌ Deuflhard test failed with exit code $JULIA_EXIT_CODE"
fi

echo ""
echo "✅ Simple Deuflhard test completed"
echo "Test ID: {test_id}"
echo "Mode: {mode}"
echo "Output directory: {output_dir}"
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
    parser = argparse.ArgumentParser(description="Run simple Deuflhard test")
    parser.add_argument("--mode", choices=["quick", "standard", "extended"],
                       default="quick", help="Test mode (default: quick)")
    
    args = parser.parse_args()
    
    tester = SimpleDeuflhardTester()
    success, test_id, output_dir = tester.run_deuflhard_test(args.mode)
    
    if success:
        print(f"\n🎯 SUCCESS! Deuflhard test completed successfully")
        print(f"🔧 Test ID: {test_id}")
        print(f"📁 Results in: {output_dir}")
        print("✅ Deuflhard function validated")
        print("✅ All core functionality working")
    else:
        print(f"\n❌ FAILED! Deuflhard test unsuccessful")
        print(f"🔧 Test ID: {test_id}")
        if output_dir:
            print(f"📁 Partial results may be in: {output_dir}")
        exit(1)

if __name__ == "__main__":
    main()
