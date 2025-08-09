"""
Detailed printing functions for the integrated documentation monitoring system
"""

"""
Print detailed Aqua.jl results
"""
function print_aqua_results_detailed(aqua_results::Dict{String, Any})
    if !get(aqua_results, "available", false)
        println("  ❌ Aqua.jl analysis not available")
        error_msg = get(aqua_results, "error", "Unknown error")
        println("     Error: $error_msg")
        return
    end
    
    println("  🔬 Comprehensive Aqua.jl Quality Analysis:")
    println("     Package: $(get(aqua_results, "package_name", "unknown"))")
    
    summary = get(aqua_results, "summary", Dict())
    total_tests = get(summary, "total_tests", 0)
    passed_tests = get(summary, "passed_tests", 0)
    failed_tests = get(summary, "failed_tests", 0)
    error_tests = get(summary, "error_tests", 0)
    overall_score = get(summary, "overall_score", 0.0)
    status = get(summary, "status", "unknown")
    
    # Status emoji
    status_emoji = if status == "excellent"
        "🟢"
    elseif status == "good"
        "🟡"
    elseif status in ["needs_attention", "needs_improvement"]
        "🟠"
    else
        "🔴"
    end
    
    println("     Tests run: $total_tests")
    println("     ✅ Passed: $passed_tests")
    if failed_tests > 0
        println("     ❌ Failed: $failed_tests")
    end
    if error_tests > 0
        println("     ⚠️  Errors: $error_tests")
    end
    println("     $status_emoji Overall score: $(round(overall_score * 100, digits=1))%")
    println("     Status: $(titlecase(replace(status, "_" => " ")))")
    
    # Show core vs optional breakdown
    core_passed = get(summary, "core_tests_passed", 0)
    core_total = get(summary, "core_tests_total", 0)
    optional_passed = get(summary, "optional_tests_passed", 0)
    optional_total = get(summary, "optional_tests_total", 0)
    
    if core_total > 0
        core_percentage = round(core_passed / core_total * 100, digits=1)
        println("     📋 Core tests: $core_passed/$core_total passed ($(core_percentage)%)")
    end
    
    if optional_total > 0
        optional_percentage = round(optional_passed / optional_total * 100, digits=1)
        println("     📋 Optional tests: $optional_passed/$optional_total passed ($(optional_percentage)%)")
    end
    
    # Show individual test results
    test_details = get(summary, "test_details", Dict())
    if !isempty(test_details)
        println("     Detailed test results:")
        
        # Group by category
        core_tests = filter(p -> get(p.second, "category", "") == "core", test_details)
        optional_tests = filter(p -> get(p.second, "category", "") == "optional", test_details)
        
        if !isempty(core_tests)
            println("       Core tests:")
            for (test_name, details) in core_tests
                status = get(details, "status", "unknown")
                duration = get(details, "duration_ms", 0)
                emoji = status == "passed" ? "✅" : status == "failed" ? "❌" : "⚠️"
                println("         $emoji $(titlecase(replace(test_name, "_" => " "))): $status ($(duration)ms)")
            end
        end
        
        if !isempty(optional_tests)
            println("       Optional tests:")
            for (test_name, details) in optional_tests
                status = get(details, "status", "unknown")
                duration = get(details, "duration_ms", 0)
                emoji = status == "passed" ? "✅" : status == "failed" ? "❌" : "⚠️"
                println("         $emoji $(titlecase(replace(test_name, "_" => " "))): $status ($(duration)ms)")
            end
        end
    end
end

"""
Print detailed task analysis results
"""
function print_task_results_detailed(task_results::Dict{String, Any})
    println("  📋 Enhanced Task Progress Analysis:")
    
    files_scanned = get(task_results, "files_scanned", 0)
    files_with_todos = get(task_results, "files_with_todos", 0)
    files_with_tasks = get(task_results, "files_with_tasks", 0)
    total_todos = get(task_results, "total_todos", 0)
    total_tasks = get(task_results, "total_markdown_tasks", 0)
    total_items = get(task_results, "total_items", 0)
    completion_rate = get(task_results, "completion_rate", 0.0)
    task_density = get(task_results, "task_density", 0.0)
    
    println("     Files scanned: $files_scanned")
    println("     Files with TODOs: $files_with_todos")
    println("     Files with tasks: $files_with_tasks")
    println("     💭 TODO comments: $total_todos")
    println("     📝 Markdown tasks: $total_tasks")
    println("     📊 Total items: $total_items")
    
    if total_tasks > 0
        completion_emoji = completion_rate >= 0.7 ? "🟢" : completion_rate >= 0.4 ? "🟡" : "🔴"
        println("     $completion_emoji Task completion: $(round(completion_rate * 100, digits=1))%")
    end
    
    density_emoji = task_density <= 1.0 ? "🟢" : task_density <= 2.0 ? "🟡" : "🔴"
    println("     $density_emoji Task density: $(round(task_density, digits=2)) items/file")
    
    # Priority breakdown
    priority_counts = get(task_results, "priority_counts", Dict())
    high_priority = get(priority_counts, "high", 0)
    medium_priority = get(priority_counts, "medium", 0)
    low_priority = get(priority_counts, "low", 0)
    
    if high_priority > 0 || medium_priority > 0 || low_priority > 0
        println("     Priority breakdown:")
        if high_priority > 0
            println("       🔴 High priority: $high_priority")
        end
        if medium_priority > 0
            println("       🟡 Medium priority: $medium_priority")
        end
        if low_priority > 0
            println("       🟢 Low priority: $low_priority")
        end
    end
    
    # Status breakdown
    status_counts = get(task_results, "status_counts", Dict())
    not_started = get(status_counts, "not_started", 0)
    in_progress = get(status_counts, "in_progress", 0)
    completed = get(status_counts, "completed", 0)
    cancelled = get(status_counts, "cancelled", 0)
    
    if not_started > 0 || in_progress > 0 || completed > 0 || cancelled > 0
        println("     Task status breakdown:")
        if not_started > 0
            println("       ⏳ Not started: $not_started")
        end
        if in_progress > 0
            println("       🔄 In progress: $in_progress")
        end
        if completed > 0
            println("       ✅ Completed: $completed")
        end
        if cancelled > 0
            println("       ❌ Cancelled: $cancelled")
        end
    end
end

"""
Print detailed documentation coverage results
"""
function print_doc_results_detailed(doc_results::Dict{String, Any})
    println("  📚 Enhanced Documentation Coverage Analysis:")
    
    total_functions = get(doc_results, "total_functions", 0)
    documented_functions = get(doc_results, "documented_functions", 0)
    undocumented_functions = get(doc_results, "undocumented_functions", 0)
    coverage_rate = get(doc_results, "coverage_rate", 0.0)
    
    println("     Functions analyzed: $total_functions")
    println("     ✅ Documented: $documented_functions")
    println("     ❌ Undocumented: $undocumented_functions")
    
    coverage_emoji = if coverage_rate >= 0.8
        "🟢"
    elseif coverage_rate >= 0.6
        "🟡"
    elseif coverage_rate >= 0.4
        "🟠"
    else
        "🔴"
    end
    
    println("     $coverage_emoji Coverage rate: $(round(coverage_rate * 100, digits=1))%")
    
    if undocumented_functions > 0
        undocumented_list = get(doc_results, "undocumented_list", [])
        if !isempty(undocumented_list)
            println("     Undocumented functions (showing first few):")
            for func_info in undocumented_list[1:min(3, length(undocumented_list))]
                println("       📝 $func_info")
            end
            if length(undocumented_list) > 3
                println("       ... and $(undocumented_functions - 3) more")
            end
        end
    end
end

"""
Calculate enhanced health score with Aqua.jl integration
"""
function calculate_enhanced_health_score(results::Dict{String, Any})::Float64
    scores = Float64[]
    weights = Float64[]
    
    # Aqua.jl score (highest weight since it's proven)
    if haskey(results, "aqua_analysis")
        aqua_data = results["aqua_analysis"]
        if get(aqua_data, "available", false)
            aqua_summary = get(aqua_data, "summary", Dict())
            aqua_score = get(aqua_summary, "overall_score", 0.0)
            push!(scores, aqua_score)
            push!(weights, 0.4)  # 40% weight for Aqua.jl
        end
    end
    
    # Documentation coverage score
    if haskey(results, "documentation_analysis")
        doc_data = results["documentation_analysis"]
        coverage_rate = get(doc_data, "coverage_rate", 0.0)
        push!(scores, coverage_rate)
        push!(weights, 0.3)  # 30% weight for documentation
    end
    
    # Task management score
    if haskey(results, "task_analysis")
        task_data = results["task_analysis"]
        task_density = get(task_data, "task_density", 0.0)
        task_score = max(0.0, 1.0 - min(1.0, task_density / 5.0))
        push!(scores, task_score)
        push!(weights, 0.2)  # 20% weight for task management
    end
    
    # Task completion score
    if haskey(results, "task_analysis")
        task_data = results["task_analysis"]
        completion_rate = get(task_data, "completion_rate", 0.0)
        push!(scores, completion_rate)
        push!(weights, 0.1)  # 10% weight for completion
    end
    
    # Calculate weighted average
    if isempty(scores)
        return 0.5  # Neutral score if no data
    end
    
    return sum(scores .* weights) / sum(weights)
end

"""
Print integrated final summary
"""
function print_integrated_summary(results::Dict{String, Any})
    println("\n📊 Final Integrated Summary:")
    println("=" ^ 50)
    
    # Overall health score
    health_score = get(results, "overall_health_score", 0.0)
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
    
    # Component breakdown
    println("\n📊 Component Scores:")
    
    # Aqua.jl score
    if haskey(results, "aqua_analysis")
        aqua_data = results["aqua_analysis"]
        if get(aqua_data, "available", false)
            aqua_summary = get(aqua_data, "summary", Dict())
            aqua_score = get(aqua_summary, "overall_score", 0.0)
            aqua_status = get(aqua_summary, "status", "unknown")
            
            status_emoji = if aqua_status == "excellent"
                "🟢"
            elseif aqua_status == "good"
                "🟡"
            elseif aqua_status in ["needs_attention", "needs_improvement"]
                "🟠"
            else
                "🔴"
            end
            
            println("  $status_emoji Aqua.jl Quality: $(round(aqua_score * 100, digits=1))% ($aqua_status)")
        else
            println("  ❌ Aqua.jl Quality: Not available")
        end
    end
    
    # Documentation coverage
    if haskey(results, "documentation_analysis")
        doc_data = results["documentation_analysis"]
        coverage_rate = get(doc_data, "coverage_rate", 0.0)
        
        coverage_emoji = if coverage_rate >= 0.8
            "🟢"
        elseif coverage_rate >= 0.6
            "🟡"
        else
            "🔴"
        end
        
        println("  $coverage_emoji Documentation Coverage: $(round(coverage_rate * 100, digits=1))%")
    end
    
    # Task management
    if haskey(results, "task_analysis")
        task_data = results["task_analysis"]
        task_density = get(task_data, "task_density", 0.0)
        completion_rate = get(task_data, "completion_rate", 0.0)
        
        task_score = max(0.0, 1.0 - min(1.0, task_density / 5.0))
        task_emoji = task_score >= 0.7 ? "🟢" : task_score >= 0.4 ? "🟡" : "🔴"
        
        println("  $task_emoji Task Management: $(round(task_score * 100, digits=1))%")
        
        if get(task_data, "total_markdown_tasks", 0) > 0
            completion_emoji = completion_rate >= 0.7 ? "🟢" : completion_rate >= 0.4 ? "🟡" : "🔴"
            println("  $completion_emoji Task Completion: $(round(completion_rate * 100, digits=1))%")
        end
    end
    
    # Enhanced recommendations
    println("\n💡 Enhanced Recommendations:")
    
    recommendations = String[]
    
    # Aqua.jl specific recommendations
    if haskey(results, "aqua_analysis")
        aqua_data = results["aqua_analysis"]
        if get(aqua_data, "available", false)
            aqua_summary = get(aqua_data, "summary", Dict())
            failed_tests = get(aqua_summary, "failed_tests", 0)
            error_tests = get(aqua_summary, "error_tests", 0)
            
            if failed_tests > 0
                push!(recommendations, "🔬 Fix $failed_tests failing Aqua.jl quality tests")
            end
            
            if error_tests > 0
                push!(recommendations, "⚠️  Resolve $error_tests Aqua.jl test errors")
            end
        end
    end
    
    # Documentation recommendations
    if haskey(results, "documentation_analysis")
        doc_data = results["documentation_analysis"]
        coverage_rate = get(doc_data, "coverage_rate", 0.0)
        undocumented_functions = get(doc_data, "undocumented_functions", 0)
        
        if coverage_rate < 0.7
            push!(recommendations, "📚 Improve documentation coverage (currently $(round(coverage_rate * 100, digits=1))%)")
        end
        
        if undocumented_functions > 10
            push!(recommendations, "📝 Add docstrings to $undocumented_functions undocumented functions")
        end
    end
    
    # Task recommendations
    if haskey(results, "task_analysis")
        task_data = results["task_analysis"]
        priority_counts = get(task_data, "priority_counts", Dict())
        high_priority = get(priority_counts, "high", 0)
        completion_rate = get(task_data, "completion_rate", 0.0)
        
        if high_priority > 0
            push!(recommendations, "🔴 Address $high_priority high-priority items (FIXME/HACK)")
        end
        
        if completion_rate < 0.3 && get(task_data, "total_markdown_tasks", 0) > 0
            push!(recommendations, "✅ Improve task completion rate (currently $(round(completion_rate * 100, digits=1))%)")
        end
    end
    
    # Overall health recommendations
    if health_score < 0.4
        push!(recommendations, "🚨 Critical: Documentation health is very low - immediate attention required")
    elseif health_score < 0.6
        push!(recommendations, "⚠️  Documentation health needs improvement")
    elseif health_score >= 0.8
        push!(recommendations, "🎉 Excellent documentation health! Keep up the good work")
    end
    
    # Show recommendations
    if isempty(recommendations)
        println("  🎯 No specific recommendations - documentation health looks good!")
    else
        for (i, rec) in enumerate(recommendations)
            println("  $i. $rec")
        end
    end
    
    # Technical details
    timestamp = get(results, "timestamp", now())
    environment = get(results, "environment", "unknown")
    package_loaded = get(results, "package_module_loaded", false)
    
    println("\n🔧 Technical Details:")
    println("  Environment: $environment")
    println("  Package loaded: $(package_loaded ? "✅" : "❌")")
    println("  Analysis completed: $(Dates.format(timestamp, "yyyy-mm-dd HH:MM:SS"))")
end
