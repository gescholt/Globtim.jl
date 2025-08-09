"""
Core utilities and shared functions for the Documentation Monitoring System
"""

using Dates
using Base.Filesystem
using TOML

"""
Summarize configuration for reporting
"""
function summarize_config(config::Dict{String, Any})::Dict{String, Any}
    summary = Dict{String, Any}()
    
    # Global settings
    global_config = get(config, "global", Dict())
    summary["monitoring_intervals"] = get(global_config, "monitoring", Dict())
    summary["output_settings"] = get(global_config, "output", Dict())
    
    # Enabled analyses
    enabled_analyses = String[]
    
    if get(get(config, "aqua_quality", Dict()), "enabled", true)
        push!(enabled_analyses, "aqua_quality")
    end
    
    if get(get(config, "task_monitoring", Dict()), "enabled", true)
        push!(enabled_analyses, "task_monitoring")
    end
    
    if get(get(config, "doc_linkage_monitoring", Dict()), "enabled", true)
        push!(enabled_analyses, "doc_linkage_monitoring")
    end
    
    if get(get(config, "doc_drift_detection", Dict()), "enabled", true)
        push!(enabled_analyses, "doc_drift_detection")
    end
    
    if get(get(config, "doc_file_management", Dict()), "enabled", true)
        push!(enabled_analyses, "doc_file_management")
    end
    
    summary["enabled_analyses"] = enabled_analyses
    summary["total_analyses"] = length(enabled_analyses)
    
    return summary
end

"""
Find files matching patterns with exclusions
"""
function find_files_with_patterns(root_dir::String, 
                                 include_patterns::Vector{String}, 
                                 exclude_patterns::Vector{String}=String[])::Vector{String}
    found_files = String[]
    
    for pattern in include_patterns
        # Convert glob pattern to regex (simplified)
        if contains(pattern, "**")
            # Recursive pattern
            base_pattern = replace(pattern, "**/" => "")
            for (root, dirs, files) in walkdir(root_dir)
                for file in files
                    if match_pattern(file, base_pattern)
                        full_path = joinpath(root, file)
                        rel_path = relpath(full_path, root_dir)
                        
                        # Check exclusions
                        excluded = false
                        for exclude_pattern in exclude_patterns
                            if match_pattern(rel_path, exclude_pattern) || 
                               match_pattern(full_path, exclude_pattern)
                                excluded = true
                                break
                            end
                        end
                        
                        if !excluded && !(full_path in found_files)
                            push!(found_files, full_path)
                        end
                    end
                end
            end
        else
            # Non-recursive pattern
            pattern_path = joinpath(root_dir, pattern)
            if isfile(pattern_path)
                push!(found_files, pattern_path)
            end
        end
    end
    
    return sort(unique(found_files))
end

"""
Simple pattern matching (supports * and ** wildcards)
"""
function match_pattern(text::String, pattern::String)::Bool
    # Convert glob pattern to regex
    regex_pattern = pattern
    regex_pattern = replace(regex_pattern, "**" => ".*")
    regex_pattern = replace(regex_pattern, "*" => "[^/]*")
    regex_pattern = "^" * regex_pattern * "\$"
    
    try
        return occursin(Regex(regex_pattern), text)
    catch
        # Fallback to simple contains check
        return contains(text, replace(pattern, "*" => ""))
    end
end

"""
Read file content safely with size limits
"""
function read_file_safe(filepath::String, max_size_mb::Int=10)::Union{String, Nothing}
    try
        # Check file size
        file_size = filesize(filepath)
        if file_size > max_size_mb * 1024 * 1024
            @warn "File too large, skipping: $filepath ($(round(file_size/1024/1024, digits=2)) MB)"
            return nothing
        end
        
        return read(filepath, String)
    catch e
        @warn "Could not read file: $filepath - $e"
        return nothing
    end
end

"""
Get file modification time safely
"""
function get_file_mtime(filepath::String)::Union{DateTime, Nothing}
    try
        return unix2datetime(mtime(filepath))
    catch e
        @warn "Could not get modification time for: $filepath - $e"
        return nothing
    end
end

"""
Calculate file age in days
"""
function file_age_days(filepath::String)::Union{Float64, Nothing}
    mtime = get_file_mtime(filepath)
    if mtime === nothing
        return nothing
    end
    
    return (now() - mtime).value / (1000 * 60 * 60 * 24)  # Convert milliseconds to days
end

"""
Extract TODO/FIXME comments from text
"""
function extract_todo_comments(content::String, patterns::Vector{String})::Vector{Dict{String, Any}}
    todos = Dict{String, Any}[]
    
    lines = split(content, '\n')
    for (line_num, line) in enumerate(lines)
        for pattern in patterns
            if contains(uppercase(line), uppercase(pattern))
                # Extract the TODO text
                todo_start = findfirst(uppercase(pattern), uppercase(line))
                if todo_start !== nothing
                    todo_text = strip(line[todo_start[end]+1:end])
                    
                    push!(todos, Dict{String, Any}(
                        "line_number" => line_num,
                        "pattern" => pattern,
                        "text" => todo_text,
                        "full_line" => strip(line)
                    ))
                end
            end
        end
    end
    
    return todos
end

"""
Extract markdown tasks from text
"""
function extract_markdown_tasks(content::String, patterns::Vector{String})::Vector{Dict{String, Any}}
    tasks = Dict{String, Any}[]
    
    lines = split(content, '\n')
    for (line_num, line) in enumerate(lines)
        stripped_line = strip(line)
        
        for pattern in patterns
            if startswith(stripped_line, pattern)
                # Determine task status
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
                
                # Extract task text
                task_text = strip(stripped_line[length(pattern)+1:end])
                
                push!(tasks, Dict{String, Any}(
                    "line_number" => line_num,
                    "status" => status,
                    "text" => task_text,
                    "full_line" => stripped_line,
                    "pattern" => pattern
                ))
            end
        end
    end
    
    return tasks
end

"""
Calculate similarity between two strings (simple Jaccard similarity)
"""
function text_similarity(text1::String, text2::String)::Float64
    if isempty(text1) && isempty(text2)
        return 1.0
    elseif isempty(text1) || isempty(text2)
        return 0.0
    end
    
    # Convert to word sets
    words1 = Set(split(lowercase(text1)))
    words2 = Set(split(lowercase(text2)))
    
    # Calculate Jaccard similarity
    intersection_size = length(intersect(words1, words2))
    union_size = length(union(words1, words2))
    
    return union_size > 0 ? intersection_size / union_size : 0.0
end

"""
Extract function definitions from Julia code
"""
function extract_julia_functions(content::String)::Vector{Dict{String, Any}}
    functions = Dict{String, Any}[]
    
    lines = split(content, '\n')
    for (line_num, line) in enumerate(lines)
        stripped = strip(line)
        
        # Simple function detection (can be improved)
        if occursin(r"^function\s+(\w+)", stripped) || 
           occursin(r"^(\w+)\s*\(.*\)\s*=", stripped) ||
           occursin(r"^(\w+)\s*\(.*\)\s*::", stripped)
            
            # Extract function name
            func_match = match(r"function\s+(\w+)", stripped)
            if func_match === nothing
                func_match = match(r"^(\w+)\s*\(", stripped)
            end
            
            if func_match !== nothing
                func_name = func_match.captures[1]
                push!(functions, Dict{String, Any}(
                    "name" => func_name,
                    "line_number" => line_num,
                    "definition" => stripped
                ))
            end
        end
    end
    
    return functions
end

"""
Extract struct definitions from Julia code
"""
function extract_julia_structs(content::String)::Vector{Dict{String, Any}}
    structs = Dict{String, Any}[]
    
    lines = split(content, '\n')
    for (line_num, line) in enumerate(lines)
        stripped = strip(line)
        
        # Detect struct definitions
        struct_match = match(r"^(?:mutable\s+)?struct\s+(\w+)", stripped)
        if struct_match !== nothing
            struct_name = struct_match.captures[1]
            push!(structs, Dict{String, Any}(
                "name" => struct_name,
                "line_number" => line_num,
                "definition" => stripped,
                "mutable" => contains(stripped, "mutable")
            ))
        end
    end
    
    return structs
end

"""
Extract export statements from Julia code
"""
function extract_julia_exports(content::String)::Vector{Dict{String, Any}}
    exports = Dict{String, Any}[]
    
    lines = split(content, '\n')
    for (line_num, line) in enumerate(lines)
        stripped = strip(line)
        
        # Detect export statements
        if startswith(stripped, "export ")
            export_text = stripped[8:end]  # Remove "export "
            exported_names = [strip(name) for name in split(export_text, ',')]
            
            for name in exported_names
                # Clean up the name (remove trailing comments, etc.)
                clean_name = strip(split(name, '#')[1])
                if !isempty(clean_name)
                    push!(exports, Dict{String, Any}(
                        "name" => clean_name,
                        "line_number" => line_num,
                        "full_line" => stripped
                    ))
                end
            end
        end
    end
    
    return exports
end

"""
Format duration in human-readable format
"""
function format_duration(duration_ms::Real)::String
    if duration_ms < 1000
        return "$(round(Int, duration_ms))ms"
    elseif duration_ms < 60000
        return "$(round(duration_ms/1000, digits=1))s"
    else
        minutes = div(duration_ms, 60000)
        seconds = (duration_ms % 60000) / 1000
        return "$(minutes)m $(round(seconds, digits=1))s"
    end
end

"""
Format file size in human-readable format
"""
function format_file_size(size_bytes::Integer)::String
    if size_bytes < 1024
        return "$(size_bytes)B"
    elseif size_bytes < 1024^2
        return "$(round(size_bytes/1024, digits=1))KB"
    elseif size_bytes < 1024^3
        return "$(round(size_bytes/1024^2, digits=1))MB"
    else
        return "$(round(size_bytes/1024^3, digits=1))GB"
    end
end

"""
Create a progress bar string
"""
function create_progress_bar(current::Int, total::Int, width::Int=20)::String
    if total == 0
        return "[$(" " ^ width)] 0/0"
    end
    
    progress = current / total
    filled = round(Int, progress * width)
    empty = width - filled
    
    bar = "█" ^ filled * "░" ^ empty
    percentage = round(progress * 100, digits=1)
    
    return "[$bar] $current/$total ($(percentage)%)"
end
