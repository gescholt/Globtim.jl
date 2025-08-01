"""
Install Optional Dependencies for AdaptivePrecision Development

This script installs the optional packages needed for the full
AdaptivePrecision development environment.

Usage:
    julia Examples/install_optional_deps.jl
    
Or in REPL:
    include("Examples/install_optional_deps.jl")
"""

using Pkg

println("🔧 Installing Optional Dependencies for AdaptivePrecision Development")
println("=" ^ 70)

# List of optional packages
optional_packages = [
    ("BenchmarkTools", "Detailed performance benchmarking"),
    ("ProfileView", "Interactive performance profiling"),
    ("PlotlyJS", "Interactive plotting in notebooks"),
    ("Revise", "Automatic code reloading for development")
]

# Check which packages are already installed
println("\n📋 Checking current package status...")
installed_packages = []
missing_packages = []

for (pkg, description) in optional_packages
    try
        # Try to load the package
        eval(:(using $(Symbol(pkg))))
        println("  ✅ $pkg: Already installed")
        push!(installed_packages, pkg)
    catch
        println("  ❌ $pkg: Not installed - $description")
        push!(missing_packages, pkg)
    end
end

# Install missing packages
if !isempty(missing_packages)
    println("\n🚀 Installing missing packages...")
    
    for pkg in missing_packages
        try
            println("  Installing $pkg...")
            Pkg.add(pkg)
            println("  ✅ $pkg installed successfully")
        catch e
            println("  ❌ Failed to install $pkg: $e")
        end
    end
    
    println("\n🎉 Installation complete!")
    println("📋 Restart Julia and reload your notebook/script to use the new packages.")
    
else
    println("\n✅ All optional packages are already installed!")
end

println("\n💡 Package Usage:")
println("  • BenchmarkTools: Detailed timing with @benchmark macro")
println("  • ProfileView: Interactive profiling with ProfileView.view()")
println("  • PlotlyJS: Interactive plots in notebooks")
println("  • Revise: Automatic code reloading - load with 'using Revise' first")

println("\n🚀 Ready for AdaptivePrecision development!")
println("📓 Open: Examples/Notebooks/AdaptivePrecision_4D_Development.ipynb")
println("🔧 Or run: Examples/adaptive_precision_4d_dev.jl")
