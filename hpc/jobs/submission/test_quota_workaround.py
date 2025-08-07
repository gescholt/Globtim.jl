#!/usr/bin/env python3

"""
Test Quota Workaround - Direct SSH Approach
===========================================

Tests the quota workaround by directly executing commands via SSH
without needing to copy files to the full home directory.

Usage:
    python test_quota_workaround.py
"""

import subprocess
import uuid
from datetime import datetime

def run_ssh_command(command, timeout=60):
    """Execute SSH command and return output"""
    try:
        result = subprocess.run(
            ["ssh", "scholten@falcon", command],
            capture_output=True, text=True, timeout=timeout
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)

def test_quota_workaround():
    """Test the quota workaround approach"""
    print("🧪 Testing Quota Workaround for Julia Package Installation")
    print("=" * 60)
    
    test_id = str(uuid.uuid4())[:8]
    depot_path = f"/tmp/julia_depot_test_{test_id}"
    
    print(f"Test ID: {test_id}")
    print(f"Alternative depot: {depot_path}")
    print()
    
    # Step 1: Analyze the quota problem
    print("📊 Step 1: Analyzing Quota Problem")
    print("-" * 40)
    
    cmd = f"""
    echo "=== Home Directory Quota Status ==="
    quota -u scholten 2>/dev/null || echo "Quota command not available"
    echo ""
    echo "=== Home Directory Usage ==="
    du -sh ~/.julia 2>/dev/null || echo "No ~/.julia directory"
    echo ""
    echo "=== Available Storage Options ==="
    df -h /tmp | tail -1
    df -h /lustre | tail -1
    """
    
    returncode, stdout, stderr = run_ssh_command(cmd)
    print(stdout)
    if stderr:
        print(f"Errors: {stderr}")
    
    # Step 2: Test alternative depot creation
    print("🔧 Step 2: Testing Alternative Depot Creation")
    print("-" * 40)
    
    cmd = f"""
    echo "Creating alternative Julia depot..."
    mkdir -p {depot_path}
    echo "✅ Created: {depot_path}"
    
    echo "Testing write permissions..."
    touch {depot_path}/test_write && rm {depot_path}/test_write
    if [ $? -eq 0 ]; then
        echo "✅ Depot is writable"
    else
        echo "❌ Depot is not writable"
        exit 1
    fi
    
    echo "Setting Julia depot path..."
    export JULIA_DEPOT_PATH="{depot_path}:$JULIA_DEPOT_PATH"
    echo "✅ JULIA_DEPOT_PATH set to: $JULIA_DEPOT_PATH"
    """
    
    returncode, stdout, stderr = run_ssh_command(cmd)
    print(stdout)
    if stderr:
        print(f"Errors: {stderr}")
    
    if returncode != 0:
        print("❌ Alternative depot creation failed")
        return False
    
    # Step 3: Test package installation with alternative depot
    print("📦 Step 3: Testing Package Installation with Alternative Depot")
    print("-" * 40)
    
    cmd = f"""
    cd ~/globtim_hpc
    export JULIA_DEPOT_PATH="{depot_path}:$JULIA_DEPOT_PATH"
    
    /sw/bin/julia -e '
    using Pkg
    
    println("🚀 Testing Package Installation with Alternative Depot")
    println("Julia Version: $(VERSION)")
    println("Depot paths:")
    for (i, path) in enumerate(DEPOT_PATH)
        println("  $i: $path")
    end
    println()
    
    # Test installing a simple package
    println("Testing installation of TOML package...")
    try
        Pkg.add("TOML")
        using TOML
        println("✅ TOML package installed and loaded successfully")
        
        # Test the package works
        using Dates
        test_data = Dict("test" => "success", "timestamp" => string(now()))
        toml_string = TOML.print(test_data)
        println("✅ TOML package functionality verified")
        println("Test output: $toml_string")
        
        exit(0)
    catch e
        println("❌ Package installation failed: $e")
        exit(1)
    end
    '
    """
    
    returncode, stdout, stderr = run_ssh_command(cmd, timeout=120)
    print(stdout)
    if stderr:
        print(f"Errors: {stderr}")
    
    success = returncode == 0
    
    # Step 4: Cleanup
    print("🧹 Step 4: Cleanup")
    print("-" * 40)
    
    cleanup_cmd = f"rm -rf {depot_path}"
    run_ssh_command(cleanup_cmd)
    print(f"✅ Cleaned up test depot: {depot_path}")
    
    return success

def test_globtim_with_workaround():
    """Test Globtim functionality with the quota workaround"""
    print("\n🧮 Testing Globtim with Quota Workaround")
    print("=" * 60)
    
    test_id = str(uuid.uuid4())[:8]
    depot_path = f"/tmp/julia_depot_globtim_{test_id}"
    
    print(f"Test ID: {test_id}")
    print(f"Globtim depot: {depot_path}")
    print()
    
    cmd = f"""
    cd ~/globtim_hpc
    mkdir -p {depot_path}
    export JULIA_DEPOT_PATH="{depot_path}:$JULIA_DEPOT_PATH"
    
    /sw/bin/julia -e '
    using Pkg
    
    println("🧮 Testing Globtim with Alternative Depot")
    println("Depot: {depot_path}")
    println()
    
    # Try to install StaticArrays (needed for Globtim)
    println("Installing StaticArrays...")
    try
        Pkg.add("StaticArrays")
        using StaticArrays
        println("✅ StaticArrays installed successfully")
        
        # Test StaticArrays functionality
        v = @SVector [1.0, 2.0, 3.0]
        println("✅ StaticArrays test: $v")
        
        # Now try to load Globtim modules
        println("Testing Globtim module loading...")
        include("src/BenchmarkFunctions.jl")
        println("✅ BenchmarkFunctions.jl loaded")
        
        # Test a function
        result = Sphere([0.0, 0.0])
        println("✅ Sphere function test: f([0,0]) = $result")
        
        println("🎉 GLOBTIM WORKS WITH QUOTA WORKAROUND!")
        exit(0)
        
    catch e
        println("❌ Globtim test failed: $e")
        exit(1)
    end
    '
    """
    
    returncode, stdout, stderr = run_ssh_command(cmd, timeout=180)
    print(stdout)
    if stderr:
        print(f"Errors: {stderr}")
    
    # Cleanup
    cleanup_cmd = f"rm -rf {depot_path}"
    run_ssh_command(cleanup_cmd)
    print(f"✅ Cleaned up Globtim test depot: {depot_path}")
    
    return returncode == 0

def main():
    print("🔍 HPC Quota Workaround Analysis & Testing")
    print("=" * 60)
    print("Root Cause: Home directory quota exceeded (Error -122: EDQUOT)")
    print("Solution: Use alternative Julia depot in /tmp or /lustre")
    print()
    
    # Test basic quota workaround
    basic_success = test_quota_workaround()
    
    if basic_success:
        print("\n✅ Basic quota workaround successful!")
        
        # Test Globtim with workaround
        globtim_success = test_globtim_with_workaround()
        
        if globtim_success:
            print("\n🎉 COMPLETE SUCCESS!")
            print("=" * 60)
            print("✅ Quota workaround works")
            print("✅ Package installation works")
            print("✅ Globtim modules load successfully")
            print()
            print("💡 SOLUTION SUMMARY:")
            print("1. Use alternative Julia depot: export JULIA_DEPOT_PATH=\"/tmp/julia_depot_USER:$JULIA_DEPOT_PATH\"")
            print("2. Install packages normally: julia -e 'using Pkg; Pkg.add(\"PackageName\")'")
            print("3. Packages install to /tmp instead of home directory")
            print("4. Bypasses 1GB home directory quota limit")
            
            return 0
        else:
            print("\n⚠️ Partial success - basic workaround works but Globtim needs more dependencies")
            return 1
    else:
        print("\n❌ Quota workaround failed")
        return 1

if __name__ == "__main__":
    exit(main())
