#!/usr/bin/env julia

"""
Script to automatically fix Julia test manifest inconsistencies.
This removes the test/Manifest.toml file and ensures the test environment
uses the parent project's manifest for consistency.
"""

using Pkg

function fix_test_manifest()
    # Get the project root directory
    project_root = dirname(@__DIR__)
    test_dir = joinpath(project_root, "test")
    test_manifest = joinpath(test_dir, "Manifest.toml")

    println("Fixing test manifest inconsistencies...")

    # Remove the test manifest if it exists
    if isfile(test_manifest)
        println("  Removing test/Manifest.toml...")
        rm(test_manifest)
    end

    # Activate the test environment and instantiate with parent manifest
    println("  Activating test environment...")
    Pkg.activate(test_dir)

    # Develop the parent package to ensure test uses the local version
    println("  Developing parent package...")
    Pkg.develop(path = project_root)

    # Update and resolve dependencies
    println("  Resolving dependencies...")
    Pkg.resolve()
    Pkg.instantiate()

    # Return to parent project
    Pkg.activate(project_root)

    println("✓ Test manifest issues resolved!")
    println("  The test environment now uses the parent project's dependencies.")
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    fix_test_manifest()
end
