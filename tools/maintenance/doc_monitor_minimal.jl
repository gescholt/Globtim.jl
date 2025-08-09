#!/usr/bin/env julia

"""
Minimal Documentation Monitoring System for Globtim.jl
Works with built-in Julia packages only - no external dependencies required

This is a simplified version that demonstrates the Aqua.jl integration concept
without requiring additional package installations that might conflict with
the existing environment.
"""

using Pkg
using Dates
using Statistics
using Base.Filesystem

# Try to load Aqua.jl if available
global AQUA_AVAILABLE = false
try
    using Aqua
    global AQUA_AVAILABLE = true
    println("✅ Aqua.jl is available")
catch e
    println("⚠️  Aqua.jl not available: $e")
    println("   Install with: julia -e 'using Pkg; Pkg.add(\"Aqua\")'")
end

# Try to load Test.jl for capturing Aqua results
global TEST_AVAILABLE = false
try
    using Test
    global TEST_AVAILABLE = true
catch e
    println("⚠️  Test.jl not available - some features may be limited")
end

"""
Simple configuration structure (replaces YAML dependency)
"""
function get_default_config()
    return Dict{String, Any}(
        "aqua_quality" => Dict{String, Any}(
            "enabled" => true,
            "core_tests" => Dict{String, Any}(
                "undefined_exports" => true,
                "unbound_args" => true,
                "ambiguities" => true,
                "persistent_tasks" => true,
                "project_extras" => true
            ),
            "optional_tests" => Dict{String, Any}(
                "stale_deps" => false,  # Often causes issues
                "deps_compat" => false,
                "piracies" => false
            )
        ),
        "task_monitoring" => Dict{String, Any}(
            "enabled" => true,
            "scan_patterns" => ["**/*.jl", "**/*.md"],
            "exclude_patterns" => [".git/**", "build/**"]
        )
    )
end

"""
Simple file pattern matching
"""
function find_julia_files(root_dir::String)::Vector{String}
    files = String[]
    
    for (root, dirs, filenames) in walkdir(root_dir)
        # Skip hidden and build directories
        if contains(root, ".git") || contains(root, "build") || contains(root, "node_modules")
            continue
        end
        
        for filename in filenames
            if endswith(filename, ".jl") || endswith(filename, ".md")
                push!(files, joinpath(root, filename))
            end
        end
    end
    
    return files
end

"""
Extract TODO comments and markdown tasks from text
"""
function extract_todos(content::String)::Vector{Dict{String, Any}}
    todos = Dict{String, Any}[]
    todo_patterns = ["TODO:", "FIXME:", "HACK:", "XXX:", "NOTE:"]
    markdown_patterns = ["- [ ]", "- [x]", "- [/]", "- [-]"]

    lines = split(content, '\n')
    for (line_num, line) in enumerate(lines)
        # Extract TODO comments
        for pattern in todo_patterns
            if contains(uppercase(line), pattern)
                todo_start = findfirst(uppercase(pattern), uppercase(line))
                if todo_start !== nothing
                    todo_text = strip(line[todo_start[end]+1:end])
                    push!(todos, Dict{String, Any}(
                        "line_number" => line_num,
                        "pattern" => pattern,
                        "type" => "todo_comment",
                        "text" => todo_text,
                        "full_line" => strip(line),
                        "priority" => get_todo_priority(pattern)
                    ))
                end
            end
        end

        # Extract markdown tasks
        stripped_line = strip(line)
        for pattern in markdown_patterns
            if startswith(stripped_line, pattern)
                status = if pattern == "- [ ]"
                    "not_started"
                elseif pattern == "- [x]"
                    "completed"
                elseif pattern == "- [/]"
                    "in_progress"
                elseif pattern == "- [-]"
                    "cancelled"
                else
                    "unknown"
                end

                task_text = strip(stripped_line[length(pattern)+1:end])
                push!(todos, Dict{String, Any}(
                    "line_number" => line_num,
                    "pattern" => pattern,
                    "type" => "markdown_task",
                    "status" => status,
                    "text" => task_text,
                    "full_line" => stripped_line,
                    "priority" => status == "not_started" ? "medium" : "low"
                ))
            end
        end
    end

    return todos
end

"""
Get priority level for TODO patterns
"""
function get_todo_priority(pattern::String)::String
    if pattern == "FIXME:"
        return "high"
    elseif pattern == "HACK:"
        return "high"
    elseif pattern == "TODO:"
        return "medium"
    elseif pattern == "XXX:"
        return "medium"
    else
        return "low"
    end
end

"""
Run Aqua.jl analysis if available
"""
function run_aqua_analysis(package_module)::Dict{String, Any}
    if !AQUA_AVAILABLE || package_module === nothing
        return Dict{String, Any}(
            "available" => false,
            "error" => AQUA_AVAILABLE ? "No package module" : "Aqua.jl not available"
        )
    end
    
    results = Dict{String, Any}(
        "available" => true,
        "package_name" => string(package_module),
        "tests" => Dict{String, Any}()
    )
    
    # Run core Aqua tests
    core_tests = [
        ("undefined_exports", () -> Aqua.test_undefined_exports(package_module)),
        ("unbound_args", () -> Aqua.test_unbound_args(package_module)),
        ("ambiguities", () -> Aqua.test_ambiguities(package_module)),
        ("persistent_tasks", () -> Aqua.test_persistent_tasks(package_module))
    ]
    
    for (test_name, test_func) in core_tests
        try
            start_time = time()
            test_func()
            duration = time() - start_time
            
            results["tests"][test_name] = Dict{String, Any}(
                "status" => "passed",
                "duration_ms" => round(Int, duration * 1000)
            )
        catch e
            results["tests"][test_name] = Dict{String, Any}(
                "status" => "failed",
                "error" => string(e)
            )
        end
    end
    
    # Calculate summary
    total_tests = length(results["tests"])
    passed_tests = count(t -> get(t, "status", "") == "passed", values(results["tests"]))
    
    results["summary"] = Dict{String, Any}(
        "total_tests" => total_tests,
        "passed_tests" => passed_tests,
        "failed_tests" => total_tests - passed_tests,
        "overall_score" => total_tests > 0 ? passed_tests / total_tests : 0.0
    )
    
    return results
end

"""
Enhanced task monitoring with detailed analysis
"""
function analyze_tasks(root_dir::String)::Dict{String, Any}
    files = find_julia_files(root_dir)

    # Detailed counters
    total_todos = 0
    total_markdown_tasks = 0
    files_with_todos = 0
    files_with_tasks = 0

    # Priority and status counters
    priority_counts = Dict("high" => 0, "medium" => 0, "low" => 0)
    status_counts = Dict("not_started" => 0, "in_progress" => 0, "completed" => 0, "cancelled" => 0)
    pattern_counts = Dict{String, Int}()

    # File-level analysis
    file_analysis = Dict{String, Any}()

    for filepath in files
        try
            content = read(filepath, String)
            todos = extract_todos(content)

            if !isempty(todos)
                rel_path = relpath(filepath, root_dir)

                # Separate todos and tasks
                file_todos = filter(t -> get(t, "type", "") == "todo_comment", todos)
                file_tasks = filter(t -> get(t, "type", "") == "markdown_task", todos)

                if !isempty(file_todos)
                    files_with_todos += 1
                    total_todos += length(file_todos)
                end

                if !isempty(file_tasks)
                    files_with_tasks += 1
                    total_markdown_tasks += length(file_tasks)
                end

                # Count priorities and statuses
                for todo in todos
                    priority = get(todo, "priority", "low")
                    priority_counts[priority] = get(priority_counts, priority, 0) + 1

                    pattern = get(todo, "pattern", "unknown")
                    pattern_counts[pattern] = get(pattern_counts, pattern, 0) + 1

                    if haskey(todo, "status")
                        status = todo["status"]
                        status_counts[status] = get(status_counts, status, 0) + 1
                    end
                end

                # Store file analysis
                file_analysis[rel_path] = Dict{String, Any}(
                    "filepath" => filepath,
                    "todos" => file_todos,
                    "tasks" => file_tasks,
                    "total_items" => length(todos)
                )
            end
        catch e
            # Skip files that can't be read
            continue
        end
    end

    # Calculate completion rate for markdown tasks
    total_tasks = total_markdown_tasks
    completed_tasks = get(status_counts, "completed", 0)
    completion_rate = total_tasks > 0 ? completed_tasks / total_tasks : 0.0

    # Calculate task density (items per file)
    task_density = length(files) > 0 ? (total_todos + total_markdown_tasks) / length(files) : 0.0

    return Dict{String, Any}(
        "files_scanned" => length(files),
        "files_with_todos" => files_with_todos,
        "files_with_tasks" => files_with_tasks,
        "total_todos" => total_todos,
        "total_markdown_tasks" => total_markdown_tasks,
        "total_items" => total_todos + total_markdown_tasks,
        "priority_counts" => priority_counts,
        "status_counts" => status_counts,
        "pattern_counts" => pattern_counts,
        "completion_rate" => completion_rate,
        "task_density" => task_density,
        "file_analysis" => file_analysis
    )
end

"""
Extract Julia functions from source code
"""
function extract_julia_functions(content::String)::Vector{Dict{String, Any}}
    functions = Dict{String, Any}[]

    lines = split(content, '\n')
    for (line_num, line) in enumerate(lines)
        stripped = strip(line)

        # Match function definitions
        func_match = match(r"^function\s+([a-zA-Z_][a-zA-Z0-9_!]*)", stripped)
        if func_match === nothing
            # Try short-form function definition
            func_match = match(r"^([a-zA-Z_][a-zA-Z0-9_!]*)\s*\([^)]*\)\s*=", stripped)
        end

        if func_match !== nothing
            func_name = func_match.captures[1]

            # Check if function has docstring (look at previous lines)
            has_docstring = false
            if line_num > 1
                prev_lines = lines[max(1, line_num-5):line_num-1]
                for prev_line in reverse(prev_lines)
                    prev_stripped = strip(prev_line)
                    if startswith(prev_stripped, "\"\"\"") || startswith(prev_stripped, "\"")
                        has_docstring = true
                        break
                    elseif !isempty(prev_stripped) && !startswith(prev_stripped, "#")
                        break
                    end
                end
            end

            push!(functions, Dict{String, Any}(
                "name" => func_name,
                "line_number" => line_num,
                "definition" => stripped,
                "has_docstring" => has_docstring
            ))
        end
    end

    return functions
end

"""
Analyze documentation coverage
"""
function analyze_documentation_coverage(root_dir::String)::Dict{String, Any}
    julia_files = filter(f -> endswith(f, ".jl"), find_julia_files(root_dir))

    total_functions = 0
    documented_functions = 0
    undocumented_functions = String[]

    for filepath in julia_files
        try
            content = read(filepath, String)
            functions = extract_julia_functions(content)

            for func in functions
                total_functions += 1
                if get(func, "has_docstring", false)
                    documented_functions += 1
                else
                    push!(undocumented_functions, "$(relpath(filepath, root_dir)):$(func["line_number"]) - $(func["name"])")
                end
            end
        catch e
            continue
        end
    end

    coverage_rate = total_functions > 0 ? documented_functions / total_functions : 0.0

    return Dict{String, Any}(
        "total_functions" => total_functions,
        "documented_functions" => documented_functions,
        "undocumented_functions" => length(undocumented_functions),
        "coverage_rate" => coverage_rate,
        "undocumented_list" => undocumented_functions[1:min(10, length(undocumented_functions))]  # Show first 10
    )
end

"""
Try to load the package module
"""
function load_package_module(root_dir::String)
    try
        # Check for Project.toml
        project_file = joinpath(root_dir, "Project.toml")
        if !isfile(project_file)
            return nothing
        end

        # Simple TOML parsing (without TOML.jl dependency)
        content = read(project_file, String)
        name_match = match(r"name\s*=\s*\"([^\"]+)\"", content)

        if name_match === nothing
            return nothing
        end

        package_name = name_match.captures[1]

        # Try to load the package
        try
            return Base.require(Main, Symbol(package_name))
        catch e
            return nothing
        end

    catch e
        return nothing
    end
end

"""
Main monitoring function
"""
function run_minimal_monitoring(root_dir::String=".")
    println("🔍 Globtim Documentation Monitor (Minimal Version)")
    println("Repository: $(abspath(root_dir))")
    println("Timestamp: $(now())")
    println("Aqua.jl available: $AQUA_AVAILABLE")
    println()
    
    # Load package module
    package_module = load_package_module(root_dir)
    println("Package module loaded: $(package_module !== nothing ? "✅" : "❌")")
    
    results = Dict{String, Any}(
        "timestamp" => now(),
        "repository_root" => abspath(root_dir),
        "aqua_available" => AQUA_AVAILABLE,
        "package_module_loaded" => package_module !== nothing
    )
    
    # Run Aqua.jl analysis
    println("\n🔬 Running Aqua.jl Quality Analysis...")
    aqua_results = run_aqua_analysis(package_module)
    results["aqua_analysis"] = aqua_results
    
    if get(aqua_results, "available", false)
        summary = get(aqua_results, "summary", Dict())
        total = get(summary, "total_tests", 0)
        passed = get(summary, "passed_tests", 0)
        score = get(summary, "overall_score", 0.0)
        
        println("  Package: $(get(aqua_results, "package_name", "unknown"))")
        println("  Tests run: $total")
        println("  ✅ Passed: $passed")
        println("  ❌ Failed: $(total - passed)")
        println("  📊 Score: $(round(score * 100, digits=1))%")
        
        # Show individual test results
        tests = get(aqua_results, "tests", Dict())
        for (test_name, test_result) in tests
            status = get(test_result, "status", "unknown")
            duration = get(test_result, "duration_ms", 0)
            emoji = status == "passed" ? "✅" : "❌"
            println("    $emoji $test_name: $status ($(duration)ms)")
        end
    else
        error_msg = get(aqua_results, "error", "Unknown error")
        println("  ❌ $error_msg")
    end
    
    # Run task analysis
    println("\n📋 Running Task Analysis...")
    task_results = analyze_tasks(root_dir)
    results["task_analysis"] = task_results

    files_scanned = get(task_results, "files_scanned", 0)
    files_with_todos = get(task_results, "files_with_todos", 0)
    files_with_tasks = get(task_results, "files_with_tasks", 0)
    total_todos = get(task_results, "total_todos", 0)
    total_tasks = get(task_results, "total_markdown_tasks", 0)
    total_items = get(task_results, "total_items", 0)
    completion_rate = get(task_results, "completion_rate", 0.0)
    task_density = get(task_results, "task_density", 0.0)

    println("  Files scanned: $files_scanned")
    println("  Files with TODOs: $files_with_todos")
    println("  Files with tasks: $files_with_tasks")
    println("  💭 TODO comments: $total_todos")
    println("  📝 Markdown tasks: $total_tasks")
    println("  📊 Total items: $total_items")

    if total_tasks > 0
        println("  ✅ Task completion: $(round(completion_rate * 100, digits=1))%")
    end

    println("  📈 Task density: $(round(task_density, digits=2)) items/file")

    # Show priority breakdown
    priority_counts = get(task_results, "priority_counts", Dict())
    high_priority = get(priority_counts, "high", 0)
    medium_priority = get(priority_counts, "medium", 0)
    low_priority = get(priority_counts, "low", 0)

    if high_priority > 0 || medium_priority > 0 || low_priority > 0
        println("  Priority breakdown:")
        if high_priority > 0
            println("    🔴 High: $high_priority")
        end
        if medium_priority > 0
            println("    🟡 Medium: $medium_priority")
        end
        if low_priority > 0
            println("    🟢 Low: $low_priority")
        end
    end

    # Show status breakdown for markdown tasks
    status_counts = get(task_results, "status_counts", Dict())
    not_started = get(status_counts, "not_started", 0)
    in_progress = get(status_counts, "in_progress", 0)
    completed = get(status_counts, "completed", 0)
    cancelled = get(status_counts, "cancelled", 0)

    if not_started > 0 || in_progress > 0 || completed > 0 || cancelled > 0
        println("  Task status breakdown:")
        if not_started > 0
            println("    ⏳ Not started: $not_started")
        end
        if in_progress > 0
            println("    🔄 In progress: $in_progress")
        end
        if completed > 0
            println("    ✅ Completed: $completed")
        end
        if cancelled > 0
            println("    ❌ Cancelled: $cancelled")
        end
    end
    
    # Run documentation coverage analysis
    println("\n📚 Running Documentation Coverage Analysis...")
    doc_results = analyze_documentation_coverage(root_dir)
    results["documentation_analysis"] = doc_results

    total_functions = get(doc_results, "total_functions", 0)
    documented_functions = get(doc_results, "documented_functions", 0)
    undocumented_functions = get(doc_results, "undocumented_functions", 0)
    coverage_rate = get(doc_results, "coverage_rate", 0.0)

    println("  Functions found: $total_functions")
    println("  ✅ Documented: $documented_functions")
    println("  ❌ Undocumented: $undocumented_functions")
    println("  📊 Coverage rate: $(round(coverage_rate * 100, digits=1))%")

    if undocumented_functions > 0
        undocumented_list = get(doc_results, "undocumented_list", [])
        if !isempty(undocumented_list)
            println("  Undocumented functions (showing first few):")
            for func_info in undocumented_list[1:min(3, length(undocumented_list))]
                println("    📝 $func_info")
            end
            if length(undocumented_list) > 3
                println("    ... and $(undocumented_functions - 3) more")
            end
        end
    end

    # Calculate overall health score
    aqua_score = if get(aqua_results, "available", false)
        get(get(aqua_results, "summary", Dict()), "overall_score", 0.0)
    else
        0.5  # Neutral score if Aqua not available
    end

    # Enhanced health calculation with multiple factors
    task_score = max(0.0, 1.0 - min(1.0, task_density / 5.0))  # Penalize high task density
    completion_score = completion_rate  # Reward task completion
    documentation_score = coverage_rate  # Reward documentation coverage

    # Weighted health score
    overall_health = if get(aqua_results, "available", false)
        # With Aqua.jl: Aqua 40%, docs 30%, tasks 20%, completion 10%
        aqua_score * 0.4 + documentation_score * 0.3 + task_score * 0.2 + completion_score * 0.1
    else
        # Without Aqua.jl: docs 50%, tasks 30%, completion 20%
        documentation_score * 0.5 + task_score * 0.3 + completion_score * 0.2
    end

    results["overall_health_score"] = overall_health
    results["component_scores"] = Dict{String, Any}(
        "aqua_score" => aqua_score,
        "task_score" => task_score,
        "completion_score" => completion_score,
        "documentation_score" => documentation_score
    )
    
    # Final summary
    println("\n📊 Final Summary:")
    println("=" ^ 40)
    
    health_emoji = if overall_health >= 0.8
        "🟢"
    elseif overall_health >= 0.6
        "🟡"
    else
        "🔴"
    end
    
    println("$health_emoji Overall Health: $(round(overall_health * 100, digits=1))%")

    # Show component scores
    component_scores = get(results, "component_scores", Dict())
    aqua_score = get(component_scores, "aqua_score", 0.0)
    task_score = get(component_scores, "task_score", 0.0)
    completion_score = get(component_scores, "completion_score", 0.0)
    documentation_score = get(component_scores, "documentation_score", 0.0)

    println("\n📊 Component Scores:")
    if AQUA_AVAILABLE && package_module !== nothing
        println("  🔬 Aqua.jl Quality: $(round(aqua_score * 100, digits=1))%")
    end
    println("  📚 Documentation Coverage: $(round(documentation_score * 100, digits=1))%")
    println("  📋 Task Management: $(round(task_score * 100, digits=1))%")
    if total_tasks > 0
        println("  ✅ Task Completion: $(round(completion_score * 100, digits=1))%")
    end
    
    # Enhanced recommendations
    println("\n💡 Recommendations:")

    recommendations = String[]

    # Aqua.jl recommendations
    if !AQUA_AVAILABLE
        push!(recommendations, "🔬 Install Aqua.jl for comprehensive quality analysis: julia -e 'using Pkg; Pkg.add(\"Aqua\")'")
    end

    # Package loading recommendations
    if package_module === nothing
        push!(recommendations, "📦 Ensure you're running from a Julia package directory with Project.toml")
    end

    # Documentation recommendations
    if documentation_score < 0.7
        push!(recommendations, "📚 Improve documentation coverage (currently $(round(documentation_score * 100, digits=1))%)")
        if undocumented_functions > 5
            push!(recommendations, "📝 Add docstrings to $undocumented_functions undocumented functions")
        end
    end

    # Task management recommendations
    if high_priority > 0
        push!(recommendations, "🔴 Address $high_priority high-priority items (FIXME/HACK)")
    end

    if total_todos > 20
        push!(recommendations, "📋 Consider addressing some of the $total_todos TODO items")
    elseif total_todos > 10
        push!(recommendations, "📋 Review and prioritize $total_todos TODO items")
    end

    # Task completion recommendations
    if total_tasks > 0 && completion_rate < 0.5
        push!(recommendations, "✅ Improve task completion rate (currently $(round(completion_rate * 100, digits=1))%)")
    end

    if not_started > 5
        push!(recommendations, "⏳ Start work on $not_started pending tasks")
    end

    # Overall health recommendations
    if overall_health < 0.4
        push!(recommendations, "🚨 Critical: Documentation health is very low - immediate attention required")
    elseif overall_health < 0.6
        push!(recommendations, "⚠️  Documentation health needs improvement")
    elseif overall_health >= 0.8
        push!(recommendations, "🎉 Excellent documentation health! Keep up the good work")
    end

    # Task density recommendations
    if task_density > 2.0
        push!(recommendations, "📈 High task density detected - consider organizing tasks better")
    end

    # Show recommendations
    if isempty(recommendations)
        println("  🎯 No specific recommendations - documentation health looks good!")
    else
        for (i, rec) in enumerate(recommendations)
            println("  $i. $rec")
        end
    end
    
    return results
end

"""
Parse simple command line arguments
"""
function parse_simple_args(args::Vector{String})::Dict{String, Any}
    config = Dict{String, Any}(
        "root_dir" => ".",
        "verbose" => false,
        "show_files" => false,
        "help" => false
    )

    i = 1
    while i <= length(args)
        arg = args[i]

        if arg == "--help" || arg == "-h"
            config["help"] = true
        elseif arg == "--verbose" || arg == "-v"
            config["verbose"] = true
        elseif arg == "--show-files" || arg == "-f"
            config["show_files"] = true
        elseif !startswith(arg, "-")
            config["root_dir"] = arg
        end

        i += 1
    end

    return config
end

"""
Show help message
"""
function show_help()
    println("""
    📚 Globtim Documentation Monitor (Minimal Version)

    Usage: julia doc_monitor_minimal.jl [options] [directory]

    Options:
      -h, --help        Show this help message
      -v, --verbose     Enable verbose output
      -f, --show-files  Show detailed file analysis

    Arguments:
      directory         Root directory to analyze (default: current directory)

    Examples:
      julia doc_monitor_minimal.jl
      julia doc_monitor_minimal.jl --verbose
      julia doc_monitor_minimal.jl --show-files /path/to/project
      julia doc_monitor_minimal.jl --help
    """)
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    # Parse command line arguments
    config = parse_simple_args(ARGS)

    if config["help"]
        show_help()
        exit(0)
    end

    root_dir = config["root_dir"]
    verbose = config["verbose"]
    show_files = config["show_files"]

    try
        results = run_minimal_monitoring(root_dir)

        # Show detailed file analysis if requested
        if show_files
            println("\n📁 Detailed File Analysis:")
            println("=" ^ 40)

            task_analysis = get(results, "task_analysis", Dict())
            file_analysis = get(task_analysis, "file_analysis", Dict())

            if !isempty(file_analysis)
                for (rel_path, file_data) in file_analysis
                    total_items = get(file_data, "total_items", 0)
                    println("  📄 $rel_path: $total_items items")

                    if verbose
                        todos = get(file_data, "todos", [])
                        tasks = get(file_data, "tasks", [])

                        for todo in todos
                            priority = get(todo, "priority", "low")
                            pattern = get(todo, "pattern", "")
                            text = get(todo, "text", "")
                            line_num = get(todo, "line_number", 0)

                            priority_emoji = if priority == "high"
                                "🔴"
                            elseif priority == "medium"
                                "🟡"
                            else
                                "🟢"
                            end

                            println("    $priority_emoji Line $line_num: $pattern $text")
                        end

                        for task in tasks
                            status = get(task, "status", "unknown")
                            text = get(task, "text", "")
                            line_num = get(task, "line_number", 0)

                            status_emoji = if status == "completed"
                                "✅"
                            elseif status == "in_progress"
                                "🔄"
                            elseif status == "cancelled"
                                "❌"
                            else
                                "⏳"
                            end

                            println("    $status_emoji Line $line_num: $text")
                        end
                    end
                end
            else
                println("  No files with tasks or TODOs found")
            end
        end

        # Exit with appropriate code
        health_score = get(results, "overall_health_score", 0.0)
        if health_score < 0.4
            exit(2)  # Critical
        elseif health_score < 0.6
            exit(1)  # Warning
        else
            exit(0)  # Success
        end
    catch e
        println("❌ Error: $e")
        if verbose
            println("Stack trace:")
            showerror(stdout, e, catch_backtrace())
        end
        exit(3)
    end
end
