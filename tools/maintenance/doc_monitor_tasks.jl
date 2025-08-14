"""
Task List Progress Monitoring Module

Custom implementation for tracking TODO comments and markdown tasks across the codebase.
This functionality is not provided by Aqua.jl and remains as custom code.
"""

using Dates
using Statistics

"""
Analyze task progress across the repository
"""
function analyze_task_progress(monitor::DocumentationMonitor)::Dict{String, Any}
    config = get(monitor.config, "task_monitoring", Dict())
    
    if !get(config, "enabled", true)
        return Dict{String, Any}("enabled" => false, "timestamp" => now())
    end
    
    scan_patterns = get(config, "scan_patterns", ["**/*.jl", "**/*.md"])
    exclude_patterns = get(config, "exclude_patterns", [".git/**"])
    task_patterns = get(config, "task_patterns", Dict())
    stale_threshold = get(config, "stale_task_threshold", 30)
    
    results = Dict{String, Any}(
        "timestamp" => now(),
        "enabled" => true,
        "scan_summary" => Dict{String, Any}(),
        "task_summary" => Dict{String, Any}(),
        "file_analysis" => Dict{String, Any}(),
        "stale_tasks" => Vector{Dict{String, Any}}(),
        "velocity_analysis" => Dict{String, Any}()
    )
    
    # Find files to scan
    files_to_scan = find_files_with_patterns(
        monitor.repository_root, 
        scan_patterns, 
        exclude_patterns
    )
    
    results["scan_summary"]["total_files"] = length(files_to_scan)
    results["scan_summary"]["scan_patterns"] = scan_patterns
    results["scan_summary"]["exclude_patterns"] = exclude_patterns
    
    # Initialize counters
    total_todos = 0
    total_markdown_tasks = 0
    completed_tasks = 0
    in_progress_tasks = 0
    cancelled_tasks = 0
    stale_tasks = Vector{Dict{String, Any}}()
    
    files_with_tasks = 0
    
    # Process each file
    for (file_idx, filepath) in enumerate(files_to_scan)
        if monitor.verbose && file_idx % 100 == 0
            println("    Processing file $file_idx/$(length(files_to_scan)): $(basename(filepath))")
        end
        
        content = read_file_safe(filepath)
        if content === nothing
            continue
        end
        
        file_results = Dict{String, Any}(
            "filepath" => filepath,
            "relative_path" => relpath(filepath, monitor.repository_root),
            "todos" => Vector{Dict{String, Any}}(),
            "markdown_tasks" => Vector{Dict{String, Any}}(),
            "file_age_days" => file_age_days(filepath)
        )
        
        # Extract TODO comments
        todo_patterns = get(task_patterns, "todo_comments", ["TODO:", "FIXME:", "HACK:", "XXX:", "NOTE:"])
        todos = extract_todo_comments(content, todo_patterns)
        file_results["todos"] = todos
        total_todos += length(todos)
        
        # Extract markdown tasks
        markdown_patterns = get(task_patterns, "markdown_tasks", ["- [ ]", "- [x]", "- [/]", "- [-]"])
        markdown_tasks = extract_markdown_tasks(content, markdown_patterns)
        file_results["markdown_tasks"] = markdown_tasks
        total_markdown_tasks += length(markdown_tasks)
        
        # Count task statuses
        for task in markdown_tasks
            status = get(task, "status", "unknown")
            if status == "completed"
                completed_tasks += 1
            elseif status == "in_progress"
                in_progress_tasks += 1
            elseif status == "cancelled"
                cancelled_tasks += 1
            end
        end
        
        # Check for stale tasks
        file_age = file_age_days(filepath)
        if file_age !== nothing && file_age > stale_threshold
            for todo in todos
                push!(stale_tasks, Dict{String, Any}(
                    "type" => "todo",
                    "filepath" => filepath,
                    "relative_path" => file_results["relative_path"],
                    "line_number" => todo["line_number"],
                    "text" => todo["text"],
                    "pattern" => todo["pattern"],
                    "file_age_days" => file_age
                ))
            end
            
            for task in markdown_tasks
                if get(task, "status", "") in ["not_started", "in_progress"]
                    push!(stale_tasks, Dict{String, Any}(
                        "type" => "markdown_task",
                        "filepath" => filepath,
                        "relative_path" => file_results["relative_path"],
                        "line_number" => task["line_number"],
                        "text" => task["text"],
                        "status" => task["status"],
                        "file_age_days" => file_age
                    ))
                end
            end
        end
        
        # Track files with tasks
        if length(todos) > 0 || length(markdown_tasks) > 0
            files_with_tasks += 1
            results["file_analysis"][file_results["relative_path"]] = file_results
        end
    end
    
    # Calculate summary statistics
    total_tasks = total_markdown_tasks
    not_started_tasks = total_markdown_tasks - completed_tasks - in_progress_tasks - cancelled_tasks
    
    results["task_summary"] = Dict{String, Any}(
        "total_todo_comments" => total_todos,
        "total_markdown_tasks" => total_markdown_tasks,
        "total_tasks" => total_tasks,
        "completed_tasks" => completed_tasks,
        "in_progress_tasks" => in_progress_tasks,
        "not_started_tasks" => not_started_tasks,
        "cancelled_tasks" => cancelled_tasks,
        "completion_rate" => total_tasks > 0 ? completed_tasks / total_tasks : 0.0,
        "files_with_tasks" => files_with_tasks,
        "stale_tasks_count" => length(stale_tasks)
    )
    
    results["stale_tasks"] = stale_tasks
    
    # Velocity analysis (if enabled)
    velocity_config = get(config, "velocity_tracking", Dict())
    if get(velocity_config, "enabled", true)
        results["velocity_analysis"] = analyze_task_velocity(
            results["file_analysis"],
            get(velocity_config, "window_days", 14),
            get(velocity_config, "min_tasks_for_velocity", 5)
        )
    end
    
    return results
end

"""
Analyze task completion velocity over time
"""
function analyze_task_velocity(file_analysis::Dict{String, Any}, 
                              window_days::Int, 
                              min_tasks::Int)::Dict{String, Any}
    velocity_results = Dict{String, Any}(
        "window_days" => window_days,
        "min_tasks_threshold" => min_tasks,
        "velocity_available" => false,
        "recent_completion_rate" => 0.0,
        "trend" => "unknown"
    )
    
    # This is a simplified velocity analysis
    # In a real implementation, you'd want to track task completion over time
    # using git history or a task tracking database
    
    recent_files = 0
    recent_completed = 0
    recent_total = 0
    
    cutoff_date = now() - Day(window_days)
    
    for (filepath, file_data) in file_analysis
        file_age = get(file_data, "file_age_days", nothing)
        if file_age !== nothing && file_age <= window_days
            recent_files += 1
            
            markdown_tasks = get(file_data, "markdown_tasks", [])
            for task in markdown_tasks
                recent_total += 1
                if get(task, "status", "") == "completed"
                    recent_completed += 1
                end
            end
        end
    end
    
    if recent_total >= min_tasks
        velocity_results["velocity_available"] = true
        velocity_results["recent_completion_rate"] = recent_completed / recent_total
        velocity_results["recent_files_analyzed"] = recent_files
        velocity_results["recent_tasks_analyzed"] = recent_total
        velocity_results["recent_completed_tasks"] = recent_completed
        
        # Simple trend analysis (would be better with historical data)
        if velocity_results["recent_completion_rate"] > 0.8
            velocity_results["trend"] = "excellent"
        elseif velocity_results["recent_completion_rate"] > 0.6
            velocity_results["trend"] = "good"
        elseif velocity_results["recent_completion_rate"] > 0.4
            velocity_results["trend"] = "moderate"
        else
            velocity_results["trend"] = "needs_attention"
        end
    end
    
    return velocity_results
end

"""
Print task monitoring summary to console
"""
function print_task_summary(results::Dict{String, Any}, verbose::Bool)
    if !get(results, "enabled", false)
        println("  📋 Task Monitoring: Disabled")
        return
    end
    
    println("  📋 Task List Progress Monitoring:")
    
    scan_summary = get(results, "scan_summary", Dict())
    task_summary = get(results, "task_summary", Dict())
    
    total_files = get(scan_summary, "total_files", 0)
    files_with_tasks = get(task_summary, "files_with_tasks", 0)
    
    println("     Files scanned: $total_files")
    println("     Files with tasks: $files_with_tasks")
    
    # TODO comments
    total_todos = get(task_summary, "total_todo_comments", 0)
    if total_todos > 0
        println("     💭 TODO comments: $total_todos")
    end
    
    # Markdown tasks
    total_tasks = get(task_summary, "total_markdown_tasks", 0)
    completed = get(task_summary, "completed_tasks", 0)
    in_progress = get(task_summary, "in_progress_tasks", 0)
    not_started = get(task_summary, "not_started_tasks", 0)
    cancelled = get(task_summary, "cancelled_tasks", 0)
    completion_rate = get(task_summary, "completion_rate", 0.0)
    
    if total_tasks > 0
        println("     ✅ Markdown tasks: $total_tasks total")
        println("        ✅ Completed: $completed")
        println("        🔄 In progress: $in_progress")
        println("        ⏳ Not started: $not_started")
        if cancelled > 0
            println("        ❌ Cancelled: $cancelled")
        end
        println("        📊 Completion rate: $(round(completion_rate * 100, digits=1))%")
    end
    
    # Stale tasks
    stale_count = get(task_summary, "stale_tasks_count", 0)
    if stale_count > 0
        println("     ⚠️  Stale tasks: $stale_count")
    end
    
    # Velocity analysis
    velocity = get(results, "velocity_analysis", Dict())
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
        
        println("     $trend_emoji Recent velocity ($(window_days)d): $(round(recent_rate * 100, digits=1))% ($trend)")
    end
    
    # Detailed breakdown if verbose
    if verbose && total_tasks > 0
        println("     Detailed task breakdown:")
        
        file_analysis = get(results, "file_analysis", Dict())
        task_files = sort(collect(keys(file_analysis)))
        
        for filepath in task_files[1:min(5, length(task_files))]  # Show top 5
            file_data = file_analysis[filepath]
            todos = length(get(file_data, "todos", []))
            tasks = length(get(file_data, "markdown_tasks", []))
            
            if todos > 0 || tasks > 0
                println("       📄 $(basename(filepath)): $todos TODOs, $tasks tasks")
            end
        end
        
        if length(task_files) > 5
            println("       ... and $(length(task_files) - 5) more files")
        end
    end
end
