#!/usr/bin/env julia

"""
Install dependencies for the Documentation Monitoring System
"""

using Pkg

function install_doc_monitor_dependencies()
    println("📦 Installing Documentation Monitor Dependencies")
    println("=" ^ 50)
    
    # Required packages for the documentation monitoring system
    required_packages = [
        "YAML",      # Configuration file parsing
        "JSON3",     # JSON report generation
        "ArgParse",  # Command line argument parsing
        "TOML"       # Project.toml parsing
    ]
    
    # Optional but recommended packages
    optional_packages = [
        "Aqua"       # Quality assurance (main integration target)
    ]
    
    println("Installing required packages...")
    for pkg in required_packages
        try
            println("  Installing $pkg...")
            Pkg.add(pkg)
            println("  ✅ $pkg installed successfully")
        catch e
            println("  ❌ Failed to install $pkg: $e")
            return false
        end
    end
    
    println("\nInstalling optional packages...")
    for pkg in optional_packages
        try
            println("  Installing $pkg...")
            Pkg.add(pkg)
            println("  ✅ $pkg installed successfully")
        catch e
            println("  ⚠️  Failed to install optional package $pkg: $e")
            println("     (This is optional - the system will work without it)")
        end
    end
    
    println("\n🎉 Dependency installation completed!")
    println("\nNext steps:")
    println("1. Run the test suite: julia tools/maintenance/test_doc_monitor.jl")
    println("2. Test the system: julia tools/maintenance/doc_monitor.jl --test-config")
    println("3. Run monitoring: julia tools/maintenance/doc_monitor.jl --mode daily --verbose")
    
    return true
end

# Run installation if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    success = install_doc_monitor_dependencies()
    exit(success ? 0 : 1)
end
