"""
Reporting Module for Documentation Monitoring System

Enhanced reporting that combines Aqua.jl results with custom documentation analysis.
"""

using JSON3
using Dates

"""
Generate all configured reports
"""
function generate_reports(monitor::DocumentationMonitor, results::Dict{String, Any})
    reporting_config = get(monitor.config, "reporting", Dict())
    formats = get(reporting_config, "formats", Dict())
    
    # Generate JSON report
    if get(get(formats, "json", Dict()), "enabled", true)
        output_json(results, monitor.report_dir, monitor.dry_run)
    end
    
    # Generate Markdown report
    if get(get(formats, "markdown", Dict()), "enabled", true)
        output_markdown(results, monitor.report_dir, monitor.dry_run)
    end
    
    # Console output is handled in main monitoring function
end

"""
Output results as JSON
"""
function output_json(results::Dict{String, Any}, report_dir::String, dry_run::Bool)
    if dry_run
        println("  📄 Would generate JSON report in: $report_dir")
        return
    end
    
    try
        mkpath(report_dir)
        
        timestamp = get(results, "timestamp", now())
        filename = "doc_monitoring_$(Dates.format(timestamp, "yyyy-mm-dd_HH-MM-SS")).json"
        filepath = joinpath(report_dir, filename)
        
        # Pretty print JSON
        json_content = JSON3.write(results, allow_inf=true)
        
        open(filepath, "w") do io
            write(io, json_content)
        end
        
        println("  📄 JSON report saved: $filepath")
        
        # Also create a latest.json symlink/copy
        latest_path = joinpath(report_dir, "latest.json")
        if isfile(latest_path)
            rm(latest_path)
        end
        cp(filepath, latest_path)
        
    catch e
        println("  ❌ Failed to generate JSON report: $e")
    end
end

"""
Output results as Markdown
"""
function output_markdown(results::Dict{String, Any}, report_dir::String, dry_run::Bool)
    if dry_run
        println("  📄 Would generate Markdown report in: $report_dir")
        return
    end
    
    try
        mkpath(report_dir)
        
        timestamp = get(results, "timestamp", now())
        filename = "doc_monitoring_$(Dates.format(timestamp, "yyyy-mm-dd_HH-MM-SS")).md"
        filepath = joinpath(report_dir, filename)
        
        markdown_content = generate_markdown_report(results)
        
        open(filepath, "w") do io
            write(io, markdown_content)
        end
        
        println("  📄 Markdown report saved: $filepath")
        
        # Also create a latest.md symlink/copy
        latest_path = joinpath(report_dir, "latest.md")
        if isfile(latest_path)
            rm(latest_path)
        end
        cp(filepath, latest_path)
        
    catch e
        println("  ❌ Failed to generate Markdown report: $e")
    end
end

"""
Generate comprehensive Markdown report
"""
function generate_markdown_report(results::Dict{String, Any})::String
    timestamp = get(results, "timestamp", now())
    mode = get(results, "mode", "unknown")
    health_score = get(results, "health_score", 0.0)
    
    # Health score emoji
    health_emoji = if health_score >= 0.8
        "🟢"
    elseif health_score >= 0.6
        "🟡"
    elseif health_score >= 0.4
        "🟠"
    else
        "🔴"
    end
    
    md = """
    # 📚 Globtim Documentation Monitoring Report
    
    **Generated:** $(Dates.format(timestamp, "yyyy-mm-dd HH:MM:SS"))  
    **Mode:** $mode  
    **Overall Health:** $health_emoji $(round(health_score * 100, digits=1))%
    
    ---
    
    ## 📊 Executive Summary
    
    This report combines **Aqua.jl quality assurance** with **custom documentation monitoring** to provide comprehensive insights into the health of the Globtim.jl documentation ecosystem.
    
    """
    
    analysis_results = get(results, "analysis_results", Dict())
    
    # Aqua.jl Quality Results
    if haskey(analysis_results, "aqua_quality")
        md *= generate_aqua_section(analysis_results["aqua_quality"])
    end
    
    # Task Monitoring Results
    if haskey(analysis_results, "task_monitoring")
        md *= generate_task_section(analysis_results["task_monitoring"])
    end
    
    # Documentation Linkage Results
    if haskey(analysis_results, "doc_linkage")
        md *= generate_linkage_section(analysis_results["doc_linkage"])
    end
    
    # Drift Analysis Results
    if haskey(analysis_results, "drift_analysis")
        md *= generate_drift_section(analysis_results["drift_analysis"])
    end
    
    # File Management Results
    if haskey(analysis_results, "file_management")
        md *= generate_file_management_section(analysis_results["file_management"])
    end
    
    # Recommendations
    md *= generate_recommendations_section(results)
    
    # Technical Details
    md *= generate_technical_details_section(results)
    
    return md
end

"""
Generate Aqua.jl section for Markdown report
"""
function generate_aqua_section(aqua_results::Dict{String, Any})::String
    if !get(aqua_results, "available", false)
        return """
        ## 🔬 Aqua.jl Quality Analysis
        
        ❌ **Aqua.jl not available** - Quality analysis limited
        
        """
    end
    
    if !get(aqua_results, "package_loaded", false)
        return """
        ## 🔬 Aqua.jl Quality Analysis
        
        ❌ **Package module not loaded** - Cannot run Aqua.jl tests
        
        """
    end
    
    summary = get(aqua_results, "summary", Dict())
    total_tests = get(summary, "total_tests", 0)
    passed_tests = get(summary, "passed_tests", 0)
    failed_tests = get(summary, "failed_tests", 0)
    error_tests = get(summary, "error_tests", 0)
    overall_score = get(summary, "overall_score", 0.0)
    status = get(summary, "status", "unknown")
    
    status_emoji = if status == "excellent"
        "🟢"
    elseif status == "good"
        "🟡"
    elseif status in ["needs_attention", "needs_improvement"]
        "🟠"
    else
        "🔴"
    end
    
    md = """
    ## 🔬 Aqua.jl Quality Analysis
    
    $status_emoji **Overall Status:** $(titlecase(replace(status, "_" => " "))) ($(round(overall_score * 100, digits=1))%)
    
    | Metric | Count |
    |--------|-------|
    | Total Tests | $total_tests |
    | ✅ Passed | $passed_tests |
    | ❌ Failed | $failed_tests |
    | ⚠️ Errors | $error_tests |
    
    """
    
    # Core tests breakdown
    core_tests = get(aqua_results, "core_tests", Dict())
    if !isempty(core_tests)
        md *= """
        ### Core Quality Tests
        
        | Test | Status | Duration |
        |------|--------|----------|
        """
        
        for (test_name, test_result) in core_tests
            status = get(test_result, "status", "unknown")
            duration = get(test_result, "duration_ms", 0)
            emoji = status == "passed" ? "✅" : status == "failed" ? "❌" : "⚠️"
            test_display_name = get(test_result, "test_name", test_name)
            
            md *= "| $test_display_name | $emoji $status | $(duration)ms |\n"
        end
        
        md *= "\n"
    end
    
    # Optional tests breakdown
    optional_tests = get(aqua_results, "optional_tests", Dict())
    if !isempty(optional_tests)
        md *= """
        ### Optional Tests
        
        | Test | Status | Duration |
        |------|--------|----------|
        """
        
        for (test_name, test_result) in optional_tests
            status = get(test_result, "status", "unknown")
            duration = get(test_result, "duration_ms", 0)
            emoji = status == "passed" ? "✅" : status == "failed" ? "❌" : "⚠️"
            test_display_name = get(test_result, "test_name", test_name)
            
            md *= "| $test_display_name | $emoji $status | $(duration)ms |\n"
        end
        
        md *= "\n"
    end
    
    return md
end

"""
Generate task monitoring section for Markdown report
"""
function generate_task_section(task_results::Dict{String, Any})::String
    if !get(task_results, "enabled", false)
        return """
        ## 📋 Task List Progress Monitoring
        
        ⚪ **Disabled**
        
        """
    end
    
    task_summary = get(task_results, "task_summary", Dict())
    total_todos = get(task_summary, "total_todo_comments", 0)
    total_tasks = get(task_summary, "total_markdown_tasks", 0)
    completed = get(task_summary, "completed_tasks", 0)
    in_progress = get(task_summary, "in_progress_tasks", 0)
    not_started = get(task_summary, "not_started_tasks", 0)
    completion_rate = get(task_summary, "completion_rate", 0.0)
    
    completion_emoji = if completion_rate >= 0.8
        "🟢"
    elseif completion_rate >= 0.6
        "🟡"
    else
        "🔴"
    end
    
    md = """
    ## 📋 Task List Progress Monitoring
    
    $completion_emoji **Completion Rate:** $(round(completion_rate * 100, digits=1))%
    
    | Task Type | Count |
    |-----------|-------|
    | 💭 TODO Comments | $total_todos |
    | 📝 Markdown Tasks | $total_tasks |
    | ✅ Completed | $completed |
    | 🔄 In Progress | $in_progress |
    | ⏳ Not Started | $not_started |
    
    """
    
    # Velocity analysis
    velocity = get(task_results, "velocity_analysis", Dict())
    if get(velocity, "velocity_available", false)
        recent_rate = get(velocity, "recent_completion_rate", 0.0)
        trend = get(velocity, "trend", "unknown")
        window_days = get(velocity, "window_days", 14)
        
        trend_emoji = if trend == "excellent"
            "🚀"
        elseif trend == "good"
            "📈"
        elseif trend == "moderate"
            "📊"
        else
            "📉"
        end
        
        md *= """
        ### Recent Velocity ($(window_days) days)
        
        $trend_emoji **Trend:** $(titlecase(trend)) ($(round(recent_rate * 100, digits=1))% completion rate)
        
        """
    end
    
    return md
end

"""
Generate linkage analysis section for Markdown report
"""
function generate_linkage_section(linkage_results::Dict{String, Any})::String
    if !get(linkage_results, "enabled", false)
        return """
        ## 🔗 Documentation-Code Linkage
        
        ⚪ **Disabled**
        
        """
    end
    
    linkage_analysis = get(linkage_results, "linkage_analysis", Dict())
    linkage_stats = get(linkage_analysis, "linkage_statistics", Dict())
    
    total_functions = get(linkage_stats, "total_functions", 0)
    documented_functions = get(linkage_stats, "documented_functions", 0)
    undocumented_functions = get(linkage_stats, "undocumented_functions", 0)
    documentation_coverage = get(linkage_stats, "documentation_coverage", 0.0)
    health_score = get(linkage_results, "linkage_health_score", 0.0)
    
    health_emoji = if health_score >= 0.8
        "🟢"
    elseif health_score >= 0.6
        "🟡"
    else
        "🔴"
    end
    
    md = """
    ## 🔗 Documentation-Code Linkage
    
    $health_emoji **Linkage Health:** $(round(health_score * 100, digits=1))%
    
    | Metric | Count |
    |--------|-------|
    | Total Functions | $total_functions |
    | ✅ Documented | $documented_functions |
    | ❌ Undocumented | $undocumented_functions |
    | 📊 Coverage | $(round(documentation_coverage * 100, digits=1))% |
    
    """
    
    return md
end

"""
Generate drift analysis section for Markdown report
"""
function generate_drift_section(drift_results::Dict{String, Any})::String
    if !get(drift_results, "enabled", false)
        return """
        ## 📊 Documentation Drift Analysis
        
        ⚪ **Disabled**
        
        """
    end
    
    drift_severity = get(drift_results, "drift_severity", 0.0)
    
    drift_emoji = if drift_severity < 0.2
        "🟢"
    elseif drift_severity < 0.4
        "🟡"
    elseif drift_severity < 0.7
        "🟠"
    else
        "🔴"
    end
    
    md = """
    ## 📊 Documentation Drift Analysis
    
    $drift_emoji **Drift Severity:** $(round(drift_severity * 100, digits=1))%
    
    """
    
    # Lag analysis
    lag_analysis = get(drift_results, "lag_analysis", Dict())
    lag_stats = get(lag_analysis, "lag_statistics", Dict())
    
    if !isempty(lag_stats)
        recent_source = get(lag_stats, "recent_source_changes", 0)
        recent_docs = get(lag_stats, "recent_doc_changes", 0)
        max_lag_days = get(lag_stats, "max_lag_days", 7)
        
        md *= """
        ### Recent Activity ($(max_lag_days) days)
        
        | Type | Changes |
        |------|---------|
        | 📝 Source Files | $recent_source |
        | 📚 Documentation | $recent_docs |
        
        """
    end
    
    return md
end

"""
Generate file management section for Markdown report
"""
function generate_file_management_section(file_results::Dict{String, Any})::String
    if !get(file_results, "enabled", false)
        return """
        ## 📁 Documentation File Management
        
        ⚪ **Disabled**
        
        """
    end
    
    health_score = get(file_results, "file_health_score", 0.0)
    
    health_emoji = if health_score >= 0.8
        "🟢"
    elseif health_score >= 0.6
        "🟡"
    else
        "🔴"
    end
    
    md = """
    ## 📁 Documentation File Management
    
    $health_emoji **File Health:** $(round(health_score * 100, digits=1))%
    
    """
    
    # Add specific file management metrics here
    # (orphans, broken links, duplicates)
    
    return md
end

"""
Generate recommendations section
"""
function generate_recommendations_section(results::Dict{String, Any})::String
    health_score = get(results, "health_score", 0.0)
    
    md = """
    ## 💡 Recommendations
    
    """
    
    if health_score < 0.4
        md *= "🔴 **Critical:** Documentation health is very low - immediate attention required\n\n"
    elseif health_score < 0.6
        md *= "🟠 **Warning:** Documentation health needs improvement\n\n"
    elseif health_score < 0.8
        md *= "🟡 **Good:** Documentation is in good shape with room for improvement\n\n"
    else
        md *= "🟢 **Excellent:** Documentation health is excellent!\n\n"
    end
    
    # Add specific recommendations based on analysis results
    analysis_results = get(results, "analysis_results", Dict())
    
    if haskey(analysis_results, "aqua_quality")
        aqua_data = analysis_results["aqua_quality"]
        aqua_summary = get(aqua_data, "summary", Dict())
        failed_tests = get(aqua_summary, "failed_tests", 0)
        
        if failed_tests > 0
            md *= "- 🔬 **Fix Aqua.jl quality issues:** $failed_tests tests failing\n"
        end
    end
    
    return md * "\n"
end

"""
Generate technical details section
"""
function generate_technical_details_section(results::Dict{String, Any})::String
    timestamp = get(results, "timestamp", now())
    mode = get(results, "mode", "unknown")
    aqua_available = get(results, "aqua_available", false)
    package_loaded = get(results, "package_module_loaded", false)
    
    md = """
    ## 🔧 Technical Details
    
    | Setting | Value |
    |---------|-------|
    | Analysis Mode | $mode |
    | Timestamp | $(Dates.format(timestamp, "yyyy-mm-dd HH:MM:SS")) |
    | Aqua.jl Available | $(aqua_available ? "✅" : "❌") |
    | Package Module Loaded | $(package_loaded ? "✅" : "❌") |
    
    ---
    
    *Report generated by Globtim Documentation Monitor v2.0*  
    *Hybrid Aqua.jl + Custom Analysis System*
    """
    
    return md
end
