#!/usr/bin/env julia

"""
Julia Environment Cleanup Script for Globtim

This script resolves package version conflicts and ensures clean environment setup.

Usage:
    julia scripts/fix_julia_environments.jl

What it does:
1. Removes conflicting test manifests
2. Updates project dependencies
3. Precompiles packages
4. Provides environment usage guidance
"""

using Pkg

println("🔧 Globtim Julia Environment Cleanup")
println("====================================")

# Ensure we're in the project environment
if !endswith(Pkg.project().path, "globtim/Project.toml")
    println("⚠️  Activating Globtim project environment...")
    Pkg.activate(".")
end

println("📁 Active project: ", Pkg.project().path)
println()

# Step 1: Clean up any conflicting manifests
println("🧹 Step 1: Cleaning up conflicting manifests...")
test_manifest = "test/Manifest.toml"
if isfile(test_manifest)
    println("   Removing conflicting test manifest: $test_manifest")
    rm(test_manifest)
    println("   ✅ Removed")
else
    println("   ✅ No conflicting test manifest found")
end
println()

# Step 2: Update and resolve dependencies
println("📦 Step 2: Resolving dependencies...")
try
    println("   Resolving package versions...")
    Pkg.resolve()
    println("   ✅ Dependencies resolved")
catch e
    println("   ⚠️  Resolution warning: $e")
    println("   Attempting to update...")
    Pkg.update()
end
println()

# Step 3: Precompile packages
println("⚡ Step 3: Precompiling packages...")
try
    Pkg.precompile()
    println("   ✅ Precompilation complete")
catch e
    println("   ⚠️  Precompilation warning: $e")
end
println()

# Step 4: Status check
println("📊 Step 4: Final status check...")
Pkg.status()
println()

# Step 5: Provide usage guidance
println("🎯 Environment Setup Complete!")
println("==============================")
println()
println("✅ Your Globtim environment is now clean and ready to use.")
println()
println("📋 Best Practices:")
println("   • Always use: julia --project=. (for main development)")
println("   • For testing: julia --project=. test/runtests.jl")
println("   • For scripts: julia --project=. scripts/your_script.jl")
println()
println("🚀 Quick Start:")
println("   julia --project=. -e \"using Globtim; println(\\\"Ready!\\\")\"")
println()
println("💡 The test/ directory no longer has its own Manifest.toml")
println("   Tests will inherit dependencies from the main project.")
println()
