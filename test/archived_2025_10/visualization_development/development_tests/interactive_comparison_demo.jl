#!/usr/bin/env julia
"""
Interactive File Comparison Demo

This script demonstrates the new interactive file selection capability
integrated into the workflow_integration.jl system.

Usage:
  julia --project=. interactive_comparison_demo.jl

Features:
- Terminal-based file selection with arrow keys
- Multi-file selection with spacebar
- Automatic data loading and basic analysis
- Integration with existing @globtimcore analysis pipeline
- Modular dashboard generation using DashboardCore
"""

using Pkg
Pkg.activate(".")

# Import file selection module at top level
include("src/FileSelection.jl")
using .FileSelection

# Import modular architecture modules
include("src/EnvironmentBridge.jl")
using .EnvironmentBridge

include("src/DashboardCore.jl")
using .DashboardCore

include("src/SafeVisualization.jl")
using .SafeVisualization

# Load the interactive workflow
include("workflow_integration.jl")

"""
Demo of the interactive file comparison workflow with automatic visualization dashboard
"""
function demo_interactive_comparison()
    println("🚀 Interactive File Comparison Demo with Visual Dashboard")
    println("="^60)

    println("This demo shows how to interactively select and compare experiment files.")
    println("You'll be able to:")
    println("  • Browse available CSV files with arrow keys")
    println("  • Select multiple files with spacebar")
    println("  • Get automatic analysis of the combined data")
    println("  • Generate visual dashboard automatically")
    println()

    println("Press Enter to start the interactive selection, or Ctrl+C to cancel...")
    readline()

    try
        # Run the interactive workflow
        result = interactive_comparison_workflow()

        if result !== nothing
            combined_data, output_file = result
            println("\n🎉 SUCCESS!")
            println("   Combined $(nrow(combined_data)) data points")
            println("   Saved to: $output_file")

            # Automatically generate visual dashboard using DashboardCore
            println("\n🎨 Generating comprehensive dashboard...")
            generate_dashboard_with_core(combined_data, output_file)
        else
            println("❌ No data was selected or loaded")
        end

    catch e
        if isa(e, InterruptException)
            println("\n👋 Demo cancelled by user")
        else
            println("\n❌ Error during demo: $e")
        end
    end
end

"""
Non-interactive demo showing available files
"""
function demo_file_discovery()
    println("📁 File Discovery Demo")
    println("="^30)

    # FileSelection module already loaded at top level

    # Discover files in common locations
    locations = ["simple_comparison_output", "."]

    for location in locations
        try
            # Validate directory access before listing files
            if isdir(location) && EnvironmentBridge.validate_path_permissions(location, "read")
                files = FileSelection.discover_csv_files(location)
                if !isempty(files)
                    println("📂 $location:")
                    options = FileSelection.format_menu_options(files)
                    for (i, opt) in enumerate(options)
                        println("   $i. $opt")
                    end
                    println()
                end
            end
        catch e
            @warn "Cannot access directory $location: $e"
            # Continue to next directory rather than failing
        end
    end
end

"""
Enhanced error handling with comprehensive context preservation (Issue #74)
"""
function handle_dashboard_failure(result::DashboardResult, config::DashboardConfig, globtimplots_path::Union{String, Nothing}, output_file::String, combined_data::DataFrame)
    # Identify failed components
    failed_components = String[]
    if !result.success
        if isempty(result.text_files)
            push!(failed_components, "text_dashboard")
        end
        if isempty(result.visual_files)
            push!(failed_components, "visual_dashboard")
        end
    end

    # Create comprehensive error context
    error_details = Dict{String, Any}(
        "failed_components" => failed_components,
        "globtimplots_path" => globtimplots_path,
        "config_output_dir" => config.output_directory,
        "config_visual_enabled" => config.include_visual,
        "execution_time" => result.execution_time,
        "total_errors" => length(result.errors),
        "total_warnings" => length(result.warnings),
        "data_rows" => nrow(combined_data),
        "data_columns" => names(combined_data),
        "source_file" => output_file
    )

    println("❌ Dashboard generation failed")
    println("   📊 Data context: $(nrow(combined_data)) rows, $(length(names(combined_data))) columns")
    println("   📁 Output directory: $(config.output_directory)")
    println("   🎨 Visual enabled: $(config.include_visual)")
    println("   🔗 GlobtimPlots path: $globtimplots_path")
    println("   ⏱️  Execution time: $(round(result.execution_time, digits=2))s")
    println("   ⚠️  Failed components: $(join(failed_components, ", "))")

    if !isempty(result.errors)
        println("   🚨 Errors:")
        for (i, error) in enumerate(result.errors)
            println("      $i. $error")
        end
    end

    if !isempty(result.warnings)
        println("   ⚠️  Warnings:")
        for (i, warning) in enumerate(result.warnings)
            println("      $i. $warning")
        end
    end

    # Enhanced error with context
    original_error = isempty(result.errors) ? "Unknown dashboard failure" : string(result.errors[1])
    throw(EnvironmentBridge.EnvironmentBridgeError(
        "Dashboard generation failed: $original_error",
        "dashboard_generation",
        "cross_environment",
        details=error_details
    ))
end

"""
Enhanced error handling with error categorization integration (Issue #74)
"""
function enhanced_error_handling(e::Exception, context::String, additional_context::Dict{String, Any})
    println("❌ Enhanced error context for: $context")
    println("   🔍 Error type: $(typeof(e))")
    println("   📝 Error message: $(string(e))")

    if haskey(additional_context, "data_rows")
        println("   📊 Data context: $(additional_context["data_rows"]) rows, $(length(additional_context["data_columns"])) columns")
    end

    if haskey(additional_context, "source_file")
        println("   📁 Source file: $(additional_context["source_file"])")
    end

    if haskey(additional_context, "globtimplots_path")
        println("   🔗 GlobtimPlots path: $(additional_context["globtimplots_path"])")
    end

    # Create enhanced error with all context
    enhanced_details = merge(additional_context, Dict{String, Any}(
        "error_type" => string(typeof(e)),
        "original_error" => string(e),
        "context" => context
    ))

    throw(EnvironmentBridge.EnvironmentBridgeError("$context failed: $(string(e))", "enhanced_error", "cross_environment", details=enhanced_details))
end

"""
Generate comprehensive dashboard using DashboardCore module
"""
function generate_dashboard_with_core(combined_data::DataFrame, output_file::String)
    # Issue #77: Transform and validate data for dashboard generation
    local dashboard_data::DataFrame
    try
        # Use semantic data pipeline transformation for dashboard compatibility
        dashboard_data = EnvironmentBridge.prepare_comparison_data(combined_data, transform_for_dashboard=true)
        println("✅ Data preparation successful:")
        println("   Original: $(nrow(combined_data)) rows, $(length(names(combined_data))) columns")
        println("   Dashboard: $(nrow(dashboard_data)) rows, $(length(names(dashboard_data))) columns")
        println("   Data type: $(DataFrameInterface.detect_data_type(dashboard_data))")
    catch e
        if isa(e, EnvironmentBridge.EnvironmentBridgeError)
            println("❌ Data preparation failed: $(e.message)")
            # Enhanced error reporting with data context
            error_details = Dict(
                "original_data_rows" => nrow(combined_data),
                "original_data_columns" => names(combined_data),
                "original_data_type" => DataFrameInterface.detect_data_type(combined_data),
                "source_file" => output_file,
                "transformation_error" => e.error_type
            )
            throw(EnvironmentBridge.EnvironmentBridgeError(
                "Dashboard generation failed during data preparation: $(e.message)",
                "dashboard_preparation",
                "globtimcore",
                details=merge(e.details, error_details)
            ))
        else
            # Re-throw unexpected errors
            rethrow(e)
        end
    end

    try
        # Attempt to locate globtimplots using multiple search paths
        globtimplots_path = nothing

        # Search paths in order of preference
        search_paths = [
            abspath("../globtimplots"),
            joinpath(dirname(dirname(@__FILE__)), "globtimplots"),
            joinpath(pwd(), "..", "globtimplots")
        ]

        # Enhanced path discovery with permission validation
        for path in search_paths
            try
                if isdir(path) && EnvironmentBridge.validate_path_permissions(path, "read")
                    globtimplots_path = path
                    break
                end
            catch e
                @warn "Failed to access globtimplots path $path: $e"
                # Continue to next path rather than failing
            end
        end

        # Create output directory with validation
        output_dir = "comparison_dashboard_$(Dates.format(Dates.now(), "yyyymmdd_HHMMSS"))"

        # Validate output directory permissions
        try
            EnvironmentBridge.validate_output_directory(output_dir)
        catch e
            throw(EnvironmentBridge.EnvironmentBridgeError(
                "Dashboard output directory validation failed: $e",
                "output_validation_failed",
                "globtimcore",
                details=Dict("output_directory" => output_dir, "error" => string(e))
            ))
        end

        # Create dashboard configuration
        config = DashboardConfig(
            output_directory=output_dir,
            include_visual=(globtimplots_path !== nothing),
            include_text=true,
            experiment_analysis=true,
            performance_metrics=true
        )

        if globtimplots_path === nothing
            println("⚠️  @globtimplots not found in any search location.")
            println("   Searched paths:")
            for path in search_paths
                println("     • $path")
            end
            println("   Creating text-only dashboard with local visualization...")

            # Create text dashboard using DashboardCore (with transformed data)
            text_result = create_text_dashboard(dashboard_data, config; source_file=output_file)

            # Create local visualization using SafeVisualization (with transformed data)
            viz_result = create_visualization_dashboard(dashboard_data, config; source_file=output_file)

            # Combine results
            result = DashboardResult(
                text_result.success && viz_result.success,
                config.output_directory,
                text_result.text_files,
                viz_result.visual_files,
                merge(text_result.summary_data, viz_result.summary_data),
                text_result.execution_time + viz_result.execution_time,
                vcat(text_result.errors, viz_result.errors),
                vcat(text_result.warnings, viz_result.warnings)
            )
        else
            println("✅ Found @globtimplots at: $(relpath(globtimplots_path))")
            println("🎯 Creating combined dashboard with text and enhanced visual components...")

            # Create text dashboard using DashboardCore (with transformed data)
            text_result = create_text_dashboard(dashboard_data, config; source_file=output_file)

            # Create enhanced visualization using SafeVisualization with @globtimplots (with transformed data)
            viz_result = create_visualization_dashboard(dashboard_data, config; globtimplots_path=globtimplots_path, source_file=output_file)

            # Combine results
            result = DashboardResult(
                text_result.success && viz_result.success,
                config.output_directory,
                text_result.text_files,
                viz_result.visual_files,
                merge(text_result.summary_data, viz_result.summary_data),
                text_result.execution_time + viz_result.execution_time,
                vcat(text_result.errors, viz_result.errors),
                vcat(text_result.warnings, viz_result.warnings)
            )
        end

        if result.success
            println("\n✨ DASHBOARD COMPLETE!")
            println("   📁 Dashboard directory: $(result.dashboard_directory)")
            println("   ⏱️  Execution time: $(round(result.execution_time, digits=2))s")
            println("   📊 Text files: $(length(result.text_files))")
            println("   🎨 Visual files: $(length(result.visual_files))")

            if !isempty(result.text_files)
                println("   📄 Text components:")
                for file in result.text_files
                    println("      • $(basename(file))")
                end
            end

            if !isempty(result.visual_files)
                println("   🎨 Visual components:")
                for file in result.visual_files
                    println("      • $(basename(file))")
                end
            end

            # Display key results if available
            if haskey(result.summary_data, "text_dashboard") &&
               haskey(result.summary_data["text_dashboard"], "critical_values") &&
               !haskey(result.summary_data["text_dashboard"]["critical_values"], "error")

                cv = result.summary_data["text_dashboard"]["critical_values"]
                println("\n📈 Key Results:")
                println("   🎯 Best L2 norm: $(round(cv["min"], digits=8))")
                println("   📏 Mean performance: $(round(cv["mean"], digits=6))")
                println("   🔢 Total data points: $(cv["count"])")
            end
        else
            # Enhanced error handling with comprehensive context preservation
            handle_dashboard_failure(result, config, globtimplots_path, output_file, combined_data)
        end

    catch e
        # Enhanced error handling with full context
        enhanced_error_handling(e, "dashboard_generation", Dict(
            "data_rows" => nrow(combined_data),
            "data_columns" => names(combined_data),
            "source_file" => output_file,
            "timestamp" => Dates.now(),
            "globtimplots_path" => globtimplots_path
        ))
    end
end

"""
Main demo function
"""
function main()
    println("🎯 Interactive File Comparison System Demo")
    println("="^50)

    # Show what files are available
    demo_file_discovery()

    # Ask user what they want to do
    println("What would you like to do?")
    println("  1. Run interactive file selection + visual dashboard (RECOMMENDED)")
    println("  2. Just show file discovery (non-interactive)")
    println("  3. Exit")

    print("Enter choice (1-3): ")
    choice = strip(readline())

    if choice == "1"
        demo_interactive_comparison()
    elseif choice == "2"
        println("\n✅ File discovery completed (shown above)")
    elseif choice == "3"
        println("👋 Goodbye!")
    else
        println("❌ Invalid choice: $choice")
    end
end

# Run demo if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end