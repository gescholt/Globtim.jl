"""
Main function and argument parsing for Documentation Monitoring System
"""

using ArgParse

"""
Parse command line arguments
"""
function parse_arguments()
    s = ArgParseSettings(
        description = "Documentation Monitoring System for Globtim.jl - Hybrid Aqua.jl + Custom Analysis",
        version = "2.0.0",
        add_version = true
    )

    @add_arg_table! s begin
        "--config", "-c"
            help = "Configuration file path"
            arg_type = String
            default = "tools/maintenance/doc_monitor_config.yaml"
            
        "--mode", "-m"
            help = "Monitoring mode"
            arg_type = String
            default = "daily"
            range_tester = x -> x in ["daily", "weekly", "monthly", "comprehensive"]
            
        "--output", "-o"
            help = "Output format"
            arg_type = String
            default = "console"
            range_tester = x -> x in ["console", "json", "markdown", "all"]
            
        "--report-dir", "-r"
            help = "Report output directory"
            arg_type = String
            default = "reports/doc_monitoring"
            
        "--verbose", "-v"
            help = "Enable verbose output"
            action = :store_true
            
        "--dry-run", "-n"
            help = "Show what would be done without making changes"
            action = :store_true
            
        "--install-aqua"
            help = "Install Aqua.jl if not available"
            action = :store_true
            
        "--test-config"
            help = "Test configuration file and exit"
            action = :store_true
    end

    return parse_args(s)
end

"""
Test configuration file validity
"""
function test_configuration(config_path::String)::Bool
    println("🔧 Testing configuration file: $config_path")
    
    try
        if !isfile(config_path)
            println("❌ Configuration file not found: $config_path")
            return false
        end
        
        config = YAML.load_file(config_path)
        println("✅ Configuration file loaded successfully")
        
        # Test required sections
        required_sections = ["global", "aqua_quality", "task_monitoring"]
        for section in required_sections
            if !haskey(config, section)
                println("⚠️  Missing configuration section: $section")
            else
                println("✅ Found section: $section")
            end
        end
        
        # Test global settings
        global_config = get(config, "global", Dict())
        repo_root = get(global_config, "repository_root", ".")
        
        if !isdir(repo_root)
            println("❌ Repository root not found: $repo_root")
            return false
        else
            println("✅ Repository root exists: $repo_root")
        end
        
        # Test Aqua.jl availability if enabled
        aqua_config = get(config, "aqua_quality", Dict())
        if get(aqua_config, "enabled", true)
            if AQUA_AVAILABLE
                println("✅ Aqua.jl is available")
            else
                println("⚠️  Aqua.jl not available - quality analysis will be limited")
            end
        end
        
        println("✅ Configuration test completed successfully")
        return true
        
    catch e
        println("❌ Configuration test failed: $e")
        return false
    end
end

"""
Install Aqua.jl if requested and not available
"""
function install_aqua_if_requested(install_flag::Bool)
    if install_flag && !AQUA_AVAILABLE
        println("📦 Installing Aqua.jl...")
        try
            Pkg.add("Aqua")
            println("✅ Aqua.jl installed successfully")
            println("ℹ️  Please restart the script to use Aqua.jl functionality")
        catch e
            println("❌ Failed to install Aqua.jl: $e")
            println("ℹ️  You can install manually with: julia -e 'using Pkg; Pkg.add(\"Aqua\")'")
        end
    elseif install_flag && AQUA_AVAILABLE
        println("✅ Aqua.jl is already available")
    end
end

"""
Print startup banner
"""
function print_banner()
    println("╔══════════════════════════════════════════════════════════════╗")
    println("║              📚 Globtim Documentation Monitor v2.0           ║")
    println("║                   Hybrid Aqua.jl + Custom Analysis          ║")
    println("╚══════════════════════════════════════════════════════════════╝")
    println()
end

"""
Print final summary of monitoring results
"""
function print_final_summary(results::Dict{String, Any}, verbose::Bool)
    println()
    println("📊 Final Summary:")
    println("=" ^ 50)
    
    # Overall health score
    health_score = get(results, "health_score", 0.0)
    health_emoji = if health_score >= 0.8
        "🟢"
    elseif health_score >= 0.6
        "🟡"
    elseif health_score >= 0.4
        "🟠"
    else
        "🔴"
    end
    
    println("$health_emoji Overall Documentation Health: $(round(health_score * 100, digits=1))%")
    
    # Analysis summary
    analysis_results = get(results, "analysis_results", Dict())
    analyses_run = length(analysis_results)
    println("🔍 Analyses completed: $analyses_run")
    
    # Individual analysis status
    for (analysis_name, analysis_data) in analysis_results
        if analysis_name == "aqua_quality"
            aqua_summary = get(analysis_data, "summary", Dict())
            status = get(aqua_summary, "status", "unknown")
            score = get(aqua_summary, "overall_score", 0.0)
            
            status_emoji = if status == "excellent"
                "🟢"
            elseif status == "good"
                "🟡"
            elseif status in ["needs_attention", "needs_improvement"]
                "🟠"
            else
                "🔴"
            end
            
            println("  $status_emoji Aqua.jl Quality: $(round(score * 100, digits=1))% ($status)")
            
        elseif analysis_name == "task_monitoring"
            task_summary = get(analysis_data, "task_summary", Dict())
            completion_rate = get(task_summary, "completion_rate", 0.0)
            total_tasks = get(task_summary, "total_markdown_tasks", 0)
            
            if total_tasks > 0
                println("  📋 Task Progress: $(round(completion_rate * 100, digits=1))% ($total_tasks tasks)")
            else
                println("  📋 Task Progress: No tasks found")
            end
            
        elseif analysis_name == "doc_linkage"
            linkage_score = get(analysis_data, "linkage_health_score", 0.0)
            println("  🔗 Doc Linkage: $(round(linkage_score * 100, digits=1))%")
            
        elseif analysis_name == "drift_analysis"
            drift_severity = get(analysis_data, "drift_severity", 0.0)
            drift_score = max(0.0, 1.0 - drift_severity)
            println("  📊 Drift Analysis: $(round(drift_score * 100, digits=1))%")
            
        elseif analysis_name == "file_management"
            file_score = get(analysis_data, "file_health_score", 0.0)
            println("  📁 File Management: $(round(file_score * 100, digits=1))%")
        end
    end
    
    # Recommendations
    println()
    println("💡 Recommendations:")
    
    if health_score < 0.4
        println("  🔴 Critical: Documentation health is very low - immediate attention required")
    elseif health_score < 0.6
        println("  🟠 Warning: Documentation health needs improvement")
    elseif health_score < 0.8
        println("  🟡 Good: Documentation is in good shape with room for improvement")
    else
        println("  🟢 Excellent: Documentation health is excellent!")
    end
    
    # Specific recommendations based on analysis results
    if haskey(analysis_results, "aqua_quality")
        aqua_data = analysis_results["aqua_quality"]
        aqua_summary = get(aqua_data, "summary", Dict())
        failed_tests = get(aqua_summary, "failed_tests", 0)
        
        if failed_tests > 0
            println("  🔬 Fix Aqua.jl quality issues: $failed_tests tests failing")
        end
    end
    
    if haskey(analysis_results, "task_monitoring")
        task_data = analysis_results["task_monitoring"]
        task_summary = get(task_data, "task_summary", Dict())
        stale_count = get(task_summary, "stale_tasks_count", 0)
        
        if stale_count > 0
            println("  📋 Address stale tasks: $stale_count tasks need attention")
        end
    end
    
    # Timestamp and mode
    timestamp = get(results, "timestamp", now())
    mode = get(results, "mode", "unknown")
    println()
    println("⏰ Analysis completed: $timestamp (mode: $mode)")
end

"""
Main function
"""
function main()
    # Parse arguments
    args = parse_arguments()
    
    # Print banner
    print_banner()
    
    # Install Aqua.jl if requested
    install_aqua_if_requested(args["install-aqua"])
    
    # Test configuration if requested
    if args["test-config"]
        success = test_configuration(args["config"])
        exit(success ? 0 : 1)
    end
    
    # Validate configuration file exists
    if !isfile(args["config"])
        println("❌ Configuration file not found: $(args["config"])")
        println("ℹ️  Create a configuration file or use --test-config to validate")
        exit(1)
    end
    
    try
        # Create monitor instance
        monitor = DocumentationMonitor(
            args["config"];
            report_dir = args["report-dir"],
            verbose = args["verbose"],
            dry_run = args["dry-run"]
        )
        
        # Run monitoring
        results = run_monitoring(monitor, args["mode"])
        
        # Handle output format
        if args["output"] in ["json", "all"]
            output_json(results, monitor.report_dir, args["dry-run"])
        end
        
        if args["output"] in ["markdown", "all"]
            output_markdown(results, monitor.report_dir, args["dry-run"])
        end
        
        # Exit with appropriate code based on health score
        health_score = get(results, "health_score", 0.0)
        if health_score < 0.4
            exit(2)  # Critical issues
        elseif health_score < 0.6
            exit(1)  # Warning issues
        else
            exit(0)  # Success
        end
        
    catch e
        println("❌ Fatal error: $e")
        if args["verbose"]
            println("Stack trace:")
            showerror(stdout, e, catch_backtrace())
        end
        exit(3)
    end
end

# Run main function if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
