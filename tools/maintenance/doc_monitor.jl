#!/usr/bin/env julia

"""
Documentation Monitoring System for Globtim.jl
Hybrid approach using Aqua.jl for quality assurance + custom documentation monitoring

Usage:
    julia doc_monitor.jl [options]
    
Options:
    --config PATH       Configuration file path (default: doc_monitor_config.yaml)
    --mode MODE         Monitoring mode: daily, weekly, monthly, comprehensive (default: daily)
    --output FORMAT     Output format: console, json, markdown, all (default: console)
    --report-dir PATH   Report output directory (default: reports/doc_monitoring)
    --verbose           Enable verbose output
    --dry-run           Show what would be done without making changes
    --help              Show this help message

Examples:
    julia doc_monitor.jl --mode comprehensive --output all
    julia doc_monitor.jl --config custom_config.yaml --verbose
    julia doc_monitor.jl --mode daily --dry-run
"""

using Pkg
using YAML
using JSON3
using TOML
using Dates
using Statistics
using Base.Filesystem
using Markdown

# Try to load Aqua.jl - install if not available
try
    using Aqua
    global AQUA_AVAILABLE = true
catch e
    @warn "Aqua.jl not available. Installing..."
    try
        Pkg.add("Aqua")
        using Aqua
        global AQUA_AVAILABLE = true
        @info "Aqua.jl installed successfully"
    catch install_error
        @error "Failed to install Aqua.jl: $install_error"
        global AQUA_AVAILABLE = false
    end
end

# Try to load Test.jl for capturing Aqua results
try
    using Test
    global TEST_AVAILABLE = true
catch e
    @warn "Test.jl not available - some features may be limited"
    global TEST_AVAILABLE = false
end

# Add current directory to load path for local modules
push!(LOAD_PATH, @__DIR__)

# Import our custom monitoring modules
include("doc_monitor_core.jl")
include("doc_monitor_aqua.jl")      # New: Aqua.jl integration
include("doc_monitor_tasks.jl")     # Custom: Task monitoring
include("doc_monitor_linkage.jl")   # Custom: Doc-code linkage
include("doc_monitor_drift.jl")     # Custom: Documentation drift
include("doc_monitor_files.jl")     # Custom: File management
include("doc_monitor_reports.jl")   # Enhanced: Unified reporting

"""
Main documentation monitoring system with Aqua.jl integration
"""
struct DocumentationMonitor
    config::Dict{String, Any}
    repository_root::String
    report_dir::String
    verbose::Bool
    dry_run::Bool
    package_module::Union{Module, Nothing}
    
    function DocumentationMonitor(config_path::String; 
                                 report_dir::String="reports/doc_monitoring",
                                 verbose::Bool=false,
                                 dry_run::Bool=false)
        # Load configuration
        config = YAML.load_file(config_path)
        
        # Resolve repository root
        repo_root = get(config["global"], "repository_root", ".")
        repo_root = abspath(repo_root)
        
        # Ensure report directory exists
        report_dir = abspath(report_dir)
        if !dry_run
            mkpath(report_dir)
        end
        
        # Try to load the package module for Aqua.jl analysis
        package_module = load_package_module(repo_root, verbose)
        
        new(config, repo_root, report_dir, verbose, dry_run, package_module)
    end
end

"""
Attempt to load the package module for Aqua.jl analysis
"""
function load_package_module(repo_root::String, verbose::Bool)::Union{Module, Nothing}
    try
        # Check if we're in a Julia package directory
        project_toml = joinpath(repo_root, "Project.toml")
        if !isfile(project_toml)
            verbose && @warn "No Project.toml found - Aqua.jl analysis will be limited"
            return nothing
        end
        
        # Try to load the package
        # First, add the current directory to the load path
        if !(repo_root in LOAD_PATH)
            pushfirst!(LOAD_PATH, repo_root)
        end
        
        # Try to determine package name from Project.toml
        project_data = TOML.parsefile(project_toml)
        package_name = get(project_data, "name", nothing)
        
        if package_name === nothing
            verbose && @warn "No package name found in Project.toml"
            return nothing
        end
        
        # Try to load the package
        try
            package_module = Base.require(Main, Symbol(package_name))
            verbose && @info "Successfully loaded package module: $package_name"
            return package_module
        catch e
            verbose && @warn "Could not load package module $package_name: $e"
            return nothing
        end
        
    catch e
        verbose && @warn "Error loading package module: $e"
        return nothing
    end
end

"""
Run comprehensive documentation monitoring analysis
"""
function run_monitoring(monitor::DocumentationMonitor, mode::String="daily")
    println("🔍 Starting Globtim Documentation Monitoring (mode: $mode)")
    println("Repository: $(monitor.repository_root)")
    println("Report directory: $(monitor.report_dir)")
    println("Aqua.jl available: $AQUA_AVAILABLE")
    println("Package module: $(monitor.package_module !== nothing ? "✅" : "❌")")
    println("Timestamp: $(now())")
    println()
    
    # Initialize results structure
    results = Dict{String, Any}(
        "timestamp" => now(),
        "mode" => mode,
        "repository_root" => monitor.repository_root,
        "config_summary" => summarize_config(monitor.config),
        "analysis_results" => Dict{String, Any}(),
        "aqua_available" => AQUA_AVAILABLE,
        "package_module_loaded" => monitor.package_module !== nothing
    )
    
    try
        # 1. Aqua.jl Quality Assurance (replaces custom quality checks)
        if should_run_analysis(monitor.config, "aqua_quality", mode) && AQUA_AVAILABLE
            monitor.verbose && println("🔬 Running Aqua.jl quality assurance...")
            aqua_results = run_aqua_analysis(monitor)
            results["analysis_results"]["aqua_quality"] = aqua_results
            print_aqua_summary(aqua_results, monitor.verbose)
        elseif should_run_analysis(monitor.config, "aqua_quality", mode)
            @warn "Aqua.jl analysis requested but Aqua.jl not available"
        end
        
        # 2. Task List Progress Monitoring (custom implementation)
        if should_run_analysis(monitor.config, "task_monitoring", mode)
            monitor.verbose && println("📋 Running task list progress monitoring...")
            task_results = analyze_task_progress(monitor)
            results["analysis_results"]["task_monitoring"] = task_results
            print_task_summary(task_results, monitor.verbose)
        end
        
        # 3. Documentation-Code Linkage Analysis (custom implementation)
        if should_run_analysis(monitor.config, "doc_linkage_monitoring", mode)
            monitor.verbose && println("🔗 Running documentation-code linkage analysis...")
            linkage_results = analyze_documentation_linkage(monitor)
            results["analysis_results"]["doc_linkage"] = linkage_results
            print_linkage_summary(linkage_results, monitor.verbose)
        end
        
        # 4. Documentation Drift Detection (custom implementation)
        if should_run_analysis(monitor.config, "doc_drift_detection", mode)
            monitor.verbose && println("📊 Running documentation drift detection...")
            drift_results = analyze_documentation_drift(monitor)
            results["analysis_results"]["drift_analysis"] = drift_results
            print_drift_summary(drift_results, monitor.verbose)
        end
        
        # 5. Documentation File Management (custom implementation)
        if should_run_analysis(monitor.config, "doc_file_management", mode)
            monitor.verbose && println("📁 Running documentation file management analysis...")
            file_results = analyze_documentation_files(monitor)
            results["analysis_results"]["file_management"] = file_results
            print_file_summary(file_results, monitor.verbose)
        end
        
        # 6. Generate comprehensive health score
        health_score = calculate_documentation_health_score(results["analysis_results"])
        results["health_score"] = health_score
        
        # 7. Generate reports
        if !monitor.dry_run
            generate_reports(monitor, results)
        end
        
        # 8. Print final summary
        print_final_summary(results, monitor.verbose)
        
        return results
        
    catch e
        println("❌ Error during monitoring: $e")
        if monitor.verbose
            println("Stack trace:")
            showerror(stdout, e, catch_backtrace())
        end
        return Dict("error" => string(e), "timestamp" => now())
    end
end

"""
Determine if a specific analysis should run based on mode and configuration
"""
function should_run_analysis(config::Dict, analysis_type::String, mode::String)::Bool
    # Always run in comprehensive mode
    if mode == "comprehensive"
        return true
    end
    
    # Check if analysis is enabled in config
    analysis_config = get(config, analysis_type, Dict())
    if get(analysis_config, "enabled", true) == false
        return false
    end
    
    # Mode-specific logic
    if mode == "daily"
        # Run Aqua + lightweight analyses daily
        return analysis_type in ["aqua_quality", "task_monitoring", "doc_drift_detection"]
    elseif mode == "weekly"
        # Run most analyses weekly
        return analysis_type in ["aqua_quality", "task_monitoring", "doc_linkage_monitoring", 
                               "doc_drift_detection", "doc_file_management"]
    elseif mode == "monthly"
        # Run all analyses monthly
        return true
    end
    
    return true
end

"""
Calculate overall documentation health score (0.0 to 1.0)
Enhanced to include Aqua.jl results
"""
function calculate_documentation_health_score(analysis_results::Dict)::Float64
    scores = Float64[]
    weights = Float64[]
    
    # Aqua.jl quality score (higher weight since it's proven)
    if haskey(analysis_results, "aqua_quality")
        aqua_data = analysis_results["aqua_quality"]
        if haskey(aqua_data, "overall_score")
            push!(scores, aqua_data["overall_score"])
            push!(weights, 0.4)  # High weight for proven quality metrics
        end
    end
    
    # Task completion score
    if haskey(analysis_results, "task_monitoring")
        task_data = analysis_results["task_monitoring"]
        if haskey(task_data, "completion_rate")
            push!(scores, task_data["completion_rate"])
            push!(weights, 0.15)  # Reduced weight
        end
    end
    
    # Linkage health score
    if haskey(analysis_results, "doc_linkage")
        linkage_data = analysis_results["doc_linkage"]
        if haskey(linkage_data, "linkage_health_score")
            push!(scores, linkage_data["linkage_health_score"])
            push!(weights, 0.25)  # Moderate weight
        end
    end
    
    # Drift score (inverse of drift severity)
    if haskey(analysis_results, "drift_analysis")
        drift_data = analysis_results["drift_analysis"]
        if haskey(drift_data, "drift_severity")
            drift_score = max(0.0, 1.0 - drift_data["drift_severity"])
            push!(scores, drift_score)
            push!(weights, 0.15)  # Reduced weight
        end
    end
    
    # File management score
    if haskey(analysis_results, "file_management")
        file_data = analysis_results["file_management"]
        if haskey(file_data, "file_health_score")
            push!(scores, file_data["file_health_score"])
            push!(weights, 0.05)  # Low weight
        end
    end
    
    # Calculate weighted average
    if isempty(scores)
        return 0.5  # Neutral score if no data
    end
    
    return sum(scores .* weights) / sum(weights)
end

# Include argument parsing and main function from the original implementation
include("doc_monitor_main.jl")
