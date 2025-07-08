#!/usr/bin/env julia

# V4 Quick Start Script - Enhanced Version

println("\n" * "="^80)
println("🚀 V4 QUICK START - Theoretical Point-Centric Analysis")
println("="^80)

# Ensure we're in the right directory
if !isfile("run_v4_analysis.jl")
    error("Please run this script from the v4 directory!")
end

# Option 1: Interactive menu
println("\nChoose an option:")
println("1. Quick test (degrees 3-4, GN=10, with plots)")
println("2. Standard run (degrees 3-4, GN=20, with plots)")
println("3. High accuracy (degrees 3-5, GN=40, tables only)")
println("4. Enhanced analysis with BFGS refinement (degrees 3-4, GN=20)")
println("5. Plot from existing tables")
println("6. Custom parameters")

print("\nEnter choice (1-6): ")
choice = readline()

if choice == "1"
    println("\n📊 Running quick test...")
    include("run_v4_analysis.jl")
    subdomain_tables = run_v4_analysis([3,4], 10, 
                                      output_dir="outputs/quick_test",
                                      plot_results=true)
    println("\n✅ Results saved to: outputs/quick_test")
    
elseif choice == "2"
    println("\n📊 Running standard analysis...")
    include("run_v4_analysis.jl")
    subdomain_tables = run_v4_analysis([3,4], 20, 
                                      output_dir="outputs/standard_run",
                                      plot_results=true)
    println("\n✅ Results saved to: outputs/standard_run")
    
elseif choice == "3"
    println("\n📊 Running high accuracy analysis (no plots)...")
    include("run_v4_analysis.jl")
    subdomain_tables = run_v4_analysis([3,4,5], 40, 
                                      output_dir="outputs/high_accuracy",
                                      plot_results=false)
    println("\n✅ Tables saved to: outputs/high_accuracy")
    println("💡 To generate plots later, use option 5")
    
elseif choice == "4"
    println("\n📊 Running enhanced analysis with BFGS refinement...")
    include("run_v4_analysis.jl")
    results = run_v4_analysis([3,4], 20, 
                            output_dir="outputs/enhanced_run",
                            plot_results=true,
                            enhanced=true)
    println("\n✅ Enhanced results saved to: outputs/enhanced_run")
    if isa(results, NamedTuple) && haskey(results, :refinement_metrics)
        println("\n📈 Refinement effectiveness:")
        for (deg, metrics) in sort(collect(results.refinement_metrics), by=x->x[1])
            println("   Degree $deg: $(metrics.n_computed) → $(metrics.n_refined) points")
            println("            Improvement: $(round(metrics.avg_improvement * 100, digits=1))%")
        end
    end
    
elseif choice == "5"
    print("\nEnter path to existing tables (e.g., outputs/my_analysis): ")
    table_path = readline()
    
    if isdir(table_path)
        print("Enter degrees as comma-separated list (e.g., 3,4,5): ")
        degree_str = readline()
        degrees = parse.(Int, split(degree_str, ","))
        
        println("\n📊 Generating plots from existing tables...")
        include("examples/plot_existing_tables.jl")
        plot_from_existing_tables(table_path, degrees=degrees)
        println("\n✅ Plots saved!")
    else
        println("\n❌ Directory not found: $table_path")
    end
    
elseif choice == "6"
    print("\nEnter degrees as comma-separated list (e.g., 3,4,5): ")
    degree_str = readline()
    degrees = parse.(Int, split(degree_str, ","))
    
    print("Enter GN value (e.g., 20): ")
    GN = parse(Int, readline())
    
    print("Use enhanced mode with BFGS refinement? (y/n): ")
    enhanced_choice = readline()
    use_enhanced = lowercase(enhanced_choice) == "y"
    
    print("Generate plots? (y/n): ")
    plot_choice = readline()
    plot_results = lowercase(plot_choice) == "y"
    
    print("Output directory name: ")
    output_dir = "outputs/" * readline()
    
    println("\n📊 Running custom analysis...")
    include("run_v4_analysis.jl")
    results = run_v4_analysis(degrees, GN, 
                            output_dir=output_dir,
                            plot_results=plot_results,
                            enhanced=use_enhanced)
    println("\n✅ Results saved to: $output_dir")
    
else
    println("\n❌ Invalid choice. Please run again and select 1-6.")
end

println("\n💡 Tips:")
if choice in ["1", "2", "3"]
    println("- View tables: subdomain_tables[\"0000\"]")
    println("- See all subdomains: keys(subdomain_tables)")
    println("- Check averages: subdomain_tables[\"0000\"][end, :]")
elseif choice == "4"
    println("- Access subdomain tables: results.subdomain_tables[\"0000\"]")
    println("- View refinement metrics: results.refinement_metrics")
    println("- Check refined points: results.all_min_refined_points")
end