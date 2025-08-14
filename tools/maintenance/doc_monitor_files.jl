"""
Documentation File Management Module

Custom implementation for managing documentation files, detecting orphans, 
duplicates, and broken links. This functionality is not provided by Aqua.jl.
"""

using Dates

"""
Analyze documentation file management across the repository
"""
function analyze_documentation_files(monitor::DocumentationMonitor)::Dict{String, Any}
    config = get(monitor.config, "doc_file_management", Dict())
    
    if !get(config, "enabled", true)
        return Dict{String, Any}("enabled" => false, "timestamp" => now())
    end
    
    results = Dict{String, Any}(
        "timestamp" => now(),
        "enabled" => true,
        "orphan_analysis" => Dict{String, Any}(),
        "duplication_analysis" => Dict{String, Any}(),
        "broken_links_analysis" => Dict{String, Any}(),
        "file_health_score" => 0.0
    )
    
    # Find all documentation files
    doc_patterns = ["docs/**/*.md", "README.md", "**/*README*.md", "**/*.md"]
    exclude_patterns = [".git/**", "node_modules/**", "build/**"]
    doc_files = find_files_with_patterns(monitor.repository_root, doc_patterns, exclude_patterns)
    
    # Analyze orphaned files
    orphan_config = get(config, "orphan_detection", Dict())
    if get(orphan_config, "enabled", true)
        results["orphan_analysis"] = analyze_orphaned_files(monitor, doc_files, orphan_config)
    end
    
    # Analyze duplicate content
    duplication_config = get(config, "duplication_detection", Dict())
    if get(duplication_config, "enabled", true)
        results["duplication_analysis"] = analyze_duplicate_content(monitor, doc_files, duplication_config)
    end
    
    # Analyze broken links
    broken_links_config = get(config, "broken_links", Dict())
    if get(broken_links_config, "enabled", true)
        results["broken_links_analysis"] = analyze_broken_links(monitor, doc_files, broken_links_config)
    end
    
    # Calculate overall file health score
    results["file_health_score"] = calculate_file_health_score(results)
    
    return results
end

"""
Analyze orphaned documentation files
"""
function analyze_orphaned_files(monitor::DocumentationMonitor, 
                               doc_files::Vector{String},
                               config::Dict{String, Any})::Dict{String, Any}
    orphan_results = Dict{String, Any}(
        "orphaned_files" => Vector{Dict{String, Any}}(),
        "potentially_orphaned" => Vector{Dict{String, Any}}(),
        "summary" => Dict{String, Any}()
    )
    
    orphan_threshold_days = get(config, "orphan_threshold_days", 90)
    min_source_activity_days = get(config, "min_source_activity_days", 30)
    
    cutoff_date = now() - Day(orphan_threshold_days)
    source_activity_cutoff = now() - Day(min_source_activity_days)
    
    # Get recent source file activity
    source_patterns = ["src/**/*.jl", "Examples/**/*.jl"]
    source_files = find_files_with_patterns(monitor.repository_root, source_patterns, [])
    
    recent_source_activity = false
    for filepath in source_files
        mtime = get_file_mtime(filepath)
        if mtime !== nothing && mtime > source_activity_cutoff
            recent_source_activity = true
            break
        end
    end
    
    orphaned_count = 0
    potentially_orphaned_count = 0
    
    for filepath in doc_files
        mtime = get_file_mtime(filepath)
        if mtime === nothing
            continue
        end
        
        file_age_days = (now() - mtime).value / (1000 * 60 * 60 * 24)
        rel_path = relpath(filepath, monitor.repository_root)
        
        file_info = Dict{String, Any}(
            "filepath" => filepath,
            "relative_path" => rel_path,
            "last_modified" => mtime,
            "age_days" => file_age_days
        )
        
        if mtime < cutoff_date
            if recent_source_activity
                # Definitely orphaned - old doc file with recent source activity
                push!(orphan_results["orphaned_files"], file_info)
                orphaned_count += 1
            else
                # Potentially orphaned - old doc file, but no recent source activity
                push!(orphan_results["potentially_orphaned"], file_info)
                potentially_orphaned_count += 1
            end
        end
    end
    
    orphan_results["summary"] = Dict{String, Any}(
        "total_doc_files" => length(doc_files),
        "orphaned_files" => orphaned_count,
        "potentially_orphaned" => potentially_orphaned_count,
        "orphan_threshold_days" => orphan_threshold_days,
        "recent_source_activity" => recent_source_activity
    )
    
    return orphan_results
end

"""
Analyze duplicate content in documentation files
"""
function analyze_duplicate_content(monitor::DocumentationMonitor,
                                  doc_files::Vector{String},
                                  config::Dict{String, Any})::Dict{String, Any}
    duplication_results = Dict{String, Any}(
        "duplicate_groups" => Vector{Vector{Dict{String, Any}}}(),
        "similar_files" => Vector{Dict{String, Any}}(),
        "summary" => Dict{String, Any}()
    )
    
    similarity_threshold = get(config, "similarity_threshold", 0.8)
    check_filename_similarity = get(config, "filename_similarity", true)
    check_header_similarity = get(config, "header_similarity", true)
    
    # Compare all pairs of files
    duplicate_groups = Vector{Vector{Dict{String, Any}}}()
    similar_pairs = Vector{Dict{String, Any}}()
    
    for i in 1:length(doc_files)
        for j in (i+1):length(doc_files)
            file1 = doc_files[i]
            file2 = doc_files[j]
            
            # Read file contents
            content1 = read_file_safe(file1)
            content2 = read_file_safe(file2)
            
            if content1 === nothing || content2 === nothing
                continue
            end
            
            # Calculate similarity
            similarity = text_similarity(content1, content2)
            
            if similarity >= similarity_threshold
                pair_info = Dict{String, Any}(
                    "file1" => relpath(file1, monitor.repository_root),
                    "file2" => relpath(file2, monitor.repository_root),
                    "similarity" => similarity,
                    "type" => "content_similarity"
                )
                push!(similar_pairs, pair_info)
            end
            
            # Check filename similarity if enabled
            if check_filename_similarity
                name1 = basename(file1)
                name2 = basename(file2)
                name_similarity = text_similarity(name1, name2)
                
                if name_similarity >= 0.7 && similarity >= 0.5
                    pair_info = Dict{String, Any}(
                        "file1" => relpath(file1, monitor.repository_root),
                        "file2" => relpath(file2, monitor.repository_root),
                        "content_similarity" => similarity,
                        "filename_similarity" => name_similarity,
                        "type" => "filename_and_content_similarity"
                    )
                    push!(similar_pairs, pair_info)
                end
            end
        end
    end
    
    duplication_results["similar_files"] = similar_pairs
    duplication_results["summary"] = Dict{String, Any}(
        "total_files_analyzed" => length(doc_files),
        "similar_pairs_found" => length(similar_pairs),
        "similarity_threshold" => similarity_threshold
    )
    
    return duplication_results
end

"""
Analyze broken links in documentation files
"""
function analyze_broken_links(monitor::DocumentationMonitor,
                             doc_files::Vector{String},
                             config::Dict{String, Any})::Dict{String, Any}
    broken_links_results = Dict{String, Any}(
        "broken_internal_links" => Vector{Dict{String, Any}}(),
        "broken_file_references" => Vector{Dict{String, Any}}(),
        "broken_anchor_links" => Vector{Dict{String, Any}}(),
        "summary" => Dict{String, Any}()
    )
    
    check_internal = get(config, "check_internal_links", true)
    check_file_refs = get(config, "check_file_references", true)
    check_anchors = get(config, "check_anchor_links", true)
    
    link_patterns = get(config, "link_patterns", [
        "\\[.*\\]\\(.*\\)",  # Markdown links
        "\\[.*\\]\\[.*\\]",  # Reference links
        "include\\(\".*\"\\)",  # Julia includes
        "\\`.*\\.jl\\`"  # Backticked file references
    ])
    
    total_links_checked = 0
    broken_internal = 0
    broken_file_refs = 0
    broken_anchors = 0
    
    for filepath in doc_files
        content = read_file_safe(filepath)
        if content === nothing
            continue
        end
        
        rel_path = relpath(filepath, monitor.repository_root)
        
        # Extract and check markdown links
        if check_internal
            markdown_links = extract_markdown_links(content)
            for link in markdown_links
                total_links_checked += 1
                
                # Check if internal link exists
                if is_internal_link(link) && !link_target_exists(monitor.repository_root, filepath, link)
                    push!(broken_links_results["broken_internal_links"], Dict{String, Any}(
                        "source_file" => rel_path,
                        "link" => link,
                        "type" => "internal_link"
                    ))
                    broken_internal += 1
                end
            end
        end
        
        # Check file references
        if check_file_refs
            file_refs = extract_file_references_from_content(content)
            for file_ref in file_refs
                total_links_checked += 1
                
                # Check if referenced file exists
                if !file_reference_exists(monitor.repository_root, file_ref)
                    push!(broken_links_results["broken_file_references"], Dict{String, Any}(
                        "source_file" => rel_path,
                        "file_reference" => file_ref,
                        "type" => "file_reference"
                    ))
                    broken_file_refs += 1
                end
            end
        end
    end
    
    broken_links_results["summary"] = Dict{String, Any}(
        "total_files_analyzed" => length(doc_files),
        "total_links_checked" => total_links_checked,
        "broken_internal_links" => broken_internal,
        "broken_file_references" => broken_file_refs,
        "broken_anchor_links" => broken_anchors
    )
    
    return broken_links_results
end

"""
Extract markdown links from content
"""
function extract_markdown_links(content::String)::Vector{String}
    links = String[]
    
    # Match [text](url) pattern
    link_pattern = r"\[([^\]]*)\]\(([^)]+)\)"
    for match in eachmatch(link_pattern, content)
        if length(match.captures) >= 2 && match.captures[2] !== nothing
            push!(links, match.captures[2])
        end
    end
    
    return links
end

"""
Check if a link is internal (relative path)
"""
function is_internal_link(link::String)::Bool
    return !startswith(link, "http://") && !startswith(link, "https://") && !startswith(link, "mailto:")
end

"""
Check if a link target exists
"""
function link_target_exists(repo_root::String, source_file::String, link::String)::Bool
    # Remove anchor part
    link_path = split(link, '#')[1]
    
    if isempty(link_path)
        return true  # Anchor-only link in same file
    end
    
    # Resolve relative path
    source_dir = dirname(source_file)
    target_path = normpath(joinpath(source_dir, link_path))
    
    return isfile(target_path) || isdir(target_path)
end

"""
Extract file references from content (simplified)
"""
function extract_file_references_from_content(content::String)::Vector{String}
    refs = String[]
    
    # Look for .jl file references
    file_pattern = r"([a-zA-Z0-9_/.-]+\.jl)"
    for match in eachmatch(file_pattern, content)
        push!(refs, match.match)
    end
    
    return unique(refs)
end

"""
Check if a file reference exists
"""
function file_reference_exists(repo_root::String, file_ref::String)::Bool
    # Try different possible locations
    possible_paths = [
        joinpath(repo_root, file_ref),
        joinpath(repo_root, "src", file_ref),
        joinpath(repo_root, "Examples", file_ref)
    ]
    
    for path in possible_paths
        if isfile(path)
            return true
        end
    end
    
    return false
end

"""
Calculate overall file health score
"""
function calculate_file_health_score(results::Dict{String, Any})::Float64
    scores = Float64[]
    weights = Float64[]
    
    # Orphan analysis score
    if haskey(results, "orphan_analysis")
        orphan_data = results["orphan_analysis"]
        orphan_summary = get(orphan_data, "summary", Dict())
        total_files = get(orphan_summary, "total_doc_files", 1)
        orphaned = get(orphan_summary, "orphaned_files", 0)
        
        orphan_score = max(0.0, 1.0 - (orphaned / total_files))
        push!(scores, orphan_score)
        push!(weights, 0.3)
    end
    
    # Broken links score
    if haskey(results, "broken_links_analysis")
        links_data = results["broken_links_analysis"]
        links_summary = get(links_data, "summary", Dict())
        total_links = get(links_summary, "total_links_checked", 1)
        broken_links = get(links_summary, "broken_internal_links", 0) + 
                      get(links_summary, "broken_file_references", 0)
        
        links_score = max(0.0, 1.0 - (broken_links / total_links))
        push!(scores, links_score)
        push!(weights, 0.5)
    end
    
    # Duplication score
    if haskey(results, "duplication_analysis")
        dup_data = results["duplication_analysis"]
        dup_summary = get(dup_data, "summary", Dict())
        total_files = get(dup_summary, "total_files_analyzed", 1)
        similar_pairs = get(dup_summary, "similar_pairs_found", 0)
        
        # Penalty for duplicates
        dup_score = max(0.0, 1.0 - (similar_pairs / total_files))
        push!(scores, dup_score)
        push!(weights, 0.2)
    end
    
    # Calculate weighted average
    if isempty(scores)
        return 0.5  # Neutral score if no data
    end
    
    return sum(scores .* weights) / sum(weights)
end

"""
Print file management summary to console
"""
function print_file_summary(results::Dict{String, Any}, verbose::Bool)
    if !get(results, "enabled", false)
        println("  📁 File Management: Disabled")
        return
    end
    
    println("  📁 Documentation File Management:")
    
    # Orphan analysis
    if haskey(results, "orphan_analysis")
        orphan_data = results["orphan_analysis"]
        orphan_summary = get(orphan_data, "summary", Dict())
        
        total_files = get(orphan_summary, "total_doc_files", 0)
        orphaned = get(orphan_summary, "orphaned_files", 0)
        potentially_orphaned = get(orphan_summary, "potentially_orphaned", 0)
        
        println("     📄 Total documentation files: $total_files")
        
        if orphaned > 0
            println("     🗑️  Orphaned files: $orphaned")
        end
        
        if potentially_orphaned > 0
            println("     ⚠️  Potentially orphaned: $potentially_orphaned")
        end
    end
    
    # Broken links analysis
    if haskey(results, "broken_links_analysis")
        links_data = results["broken_links_analysis"]
        links_summary = get(links_data, "summary", Dict())
        
        total_links = get(links_summary, "total_links_checked", 0)
        broken_internal = get(links_summary, "broken_internal_links", 0)
        broken_files = get(links_summary, "broken_file_references", 0)
        
        println("     🔗 Links checked: $total_links")
        
        if broken_internal > 0
            println("     ❌ Broken internal links: $broken_internal")
        end
        
        if broken_files > 0
            println("     ❌ Broken file references: $broken_files")
        end
        
        if broken_internal == 0 && broken_files == 0 && total_links > 0
            println("     ✅ All links valid")
        end
    end
    
    # Duplication analysis
    if haskey(results, "duplication_analysis")
        dup_data = results["duplication_analysis"]
        dup_summary = get(dup_data, "summary", Dict())
        
        similar_pairs = get(dup_summary, "similar_pairs_found", 0)
        
        if similar_pairs > 0
            println("     📋 Similar content pairs: $similar_pairs")
        end
    end
    
    # Overall health score
    health_score = get(results, "file_health_score", 0.0)
    health_emoji = if health_score >= 0.8
        "🟢"
    elseif health_score >= 0.6
        "🟡"
    else
        "🔴"
    end
    
    println("     $health_emoji File health score: $(round(health_score * 100, digits=1))%")
end
