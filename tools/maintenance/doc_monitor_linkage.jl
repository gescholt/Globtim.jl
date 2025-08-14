"""
Documentation-Code Linkage Monitoring Module

Custom implementation for tracking connections between documentation and source code.
This functionality is not provided by Aqua.jl and remains as custom code.
"""

using Dates

"""
Analyze documentation-code linkage across the repository
"""
function analyze_documentation_linkage(monitor::DocumentationMonitor)::Dict{String, Any}
    config = get(monitor.config, "doc_linkage_monitoring", Dict())
    
    if !get(config, "enabled", true)
        return Dict{String, Any}("enabled" => false, "timestamp" => now())
    end
    
    results = Dict{String, Any}(
        "timestamp" => now(),
        "enabled" => true,
        "source_analysis" => Dict{String, Any}(),
        "documentation_analysis" => Dict{String, Any}(),
        "linkage_analysis" => Dict{String, Any}(),
        "linkage_health_score" => 0.0
    )
    
    # Analyze source code files
    source_config = get(config, "source_monitoring", Dict())
    results["source_analysis"] = analyze_source_files(monitor, source_config)
    
    # Analyze documentation files
    doc_patterns = get(config, "documentation_files", Dict("patterns" => ["docs/**/*.md", "README.md"]))
    results["documentation_analysis"] = analyze_documentation_files_linkage(monitor, doc_patterns)
    
    # Analyze linkage between source and documentation
    linkage_rules = get(config, "linkage_rules", Dict())
    results["linkage_analysis"] = analyze_code_doc_linkage(
        results["source_analysis"],
        results["documentation_analysis"],
        linkage_rules
    )
    
    # Calculate overall linkage health score
    results["linkage_health_score"] = calculate_linkage_health_score(results)
    
    return results
end

"""
Analyze source code files for functions, structs, and exports
"""
function analyze_source_files(monitor::DocumentationMonitor, config::Dict{String, Any})::Dict{String, Any}
    source_results = Dict{String, Any}(
        "julia_files" => Dict{String, Any}(),
        "python_files" => Dict{String, Any}(),
        "summary" => Dict{String, Any}()
    )
    
    # Analyze Julia files
    julia_config = get(config, "julia_files", Dict())
    if get(julia_config, "track_functions", true)
        julia_patterns = get(julia_config, "patterns", ["src/**/*.jl"])
        julia_files = find_files_with_patterns(monitor.repository_root, julia_patterns, [])
        
        total_functions = 0
        total_structs = 0
        total_exports = 0
        
        for filepath in julia_files
            content = read_file_safe(filepath)
            if content === nothing
                continue
            end
            
            rel_path = relpath(filepath, monitor.repository_root)
            file_analysis = Dict{String, Any}(
                "filepath" => filepath,
                "relative_path" => rel_path,
                "functions" => extract_julia_functions(content),
                "structs" => extract_julia_structs(content),
                "exports" => extract_julia_exports(content)
            )
            
            total_functions += length(file_analysis["functions"])
            total_structs += length(file_analysis["structs"])
            total_exports += length(file_analysis["exports"])
            
            source_results["julia_files"][rel_path] = file_analysis
        end
        
        source_results["summary"]["julia"] = Dict{String, Any}(
            "files_analyzed" => length(julia_files),
            "total_functions" => total_functions,
            "total_structs" => total_structs,
            "total_exports" => total_exports
        )
    end
    
    # Analyze Python files (simplified)
    python_config = get(config, "python_files", Dict())
    if get(python_config, "track_functions", true)
        python_patterns = get(python_config, "patterns", ["**/*.py"])
        python_files = find_files_with_patterns(monitor.repository_root, python_patterns, [])
        
        # Simplified Python analysis (could be expanded)
        source_results["summary"]["python"] = Dict{String, Any}(
            "files_analyzed" => length(python_files),
            "total_functions" => 0,  # Would need Python AST parsing
            "total_classes" => 0
        )
    end
    
    return source_results
end

"""
Analyze documentation files for references to code elements
"""
function analyze_documentation_files_linkage(monitor::DocumentationMonitor, config::Dict{String, Any})::Dict{String, Any}
    doc_results = Dict{String, Any}(
        "files_analyzed" => Dict{String, Any}(),
        "summary" => Dict{String, Any}()
    )
    
    doc_patterns = get(config, "patterns", ["docs/**/*.md", "README.md"])
    doc_files = find_files_with_patterns(monitor.repository_root, doc_patterns, [])
    
    total_function_refs = 0
    total_file_refs = 0
    total_module_refs = 0
    
    for filepath in doc_files
        content = read_file_safe(filepath)
        if content === nothing
            continue
        end
        
        rel_path = relpath(filepath, monitor.repository_root)
        
        # Extract various types of references
        function_refs = extract_function_references(content)
        file_refs = extract_file_references(content)
        module_refs = extract_module_references(content)
        
        total_function_refs += length(function_refs)
        total_file_refs += length(file_refs)
        total_module_refs += length(module_refs)
        
        doc_results["files_analyzed"][rel_path] = Dict{String, Any}(
            "filepath" => filepath,
            "relative_path" => rel_path,
            "function_references" => function_refs,
            "file_references" => file_refs,
            "module_references" => module_refs
        )
    end
    
    doc_results["summary"] = Dict{String, Any}(
        "files_analyzed" => length(doc_files),
        "total_function_references" => total_function_refs,
        "total_file_references" => total_file_refs,
        "total_module_references" => total_module_refs
    )
    
    return doc_results
end

"""
Analyze linkage between source code and documentation
"""
function analyze_code_doc_linkage(source_analysis::Dict{String, Any}, 
                                 doc_analysis::Dict{String, Any},
                                 linkage_rules::Dict{String, Any})::Dict{String, Any}
    linkage_results = Dict{String, Any}(
        "documented_functions" => Vector{String}(),
        "undocumented_functions" => Vector{String}(),
        "broken_references" => Vector{Dict{String, Any}}(),
        "orphaned_documentation" => Vector{String}(),
        "linkage_statistics" => Dict{String, Any}()
    )
    
    # Get all functions from source code
    all_functions = Set{String}()
    julia_files = get(source_analysis, "julia_files", Dict())
    
    for (filepath, file_data) in julia_files
        functions = get(file_data, "functions", [])
        for func in functions
            push!(all_functions, get(func, "name", ""))
        end
    end
    
    # Get all function references from documentation
    all_doc_refs = Set{String}()
    doc_files = get(doc_analysis, "files_analyzed", Dict())
    
    for (filepath, file_data) in doc_files
        func_refs = get(file_data, "function_references", [])
        for ref in func_refs
            push!(all_doc_refs, ref)
        end
    end
    
    # Find documented vs undocumented functions
    documented_functions = intersect(all_functions, all_doc_refs)
    undocumented_functions = setdiff(all_functions, all_doc_refs)
    broken_references = setdiff(all_doc_refs, all_functions)
    
    linkage_results["documented_functions"] = collect(documented_functions)
    linkage_results["undocumented_functions"] = collect(undocumented_functions)
    linkage_results["broken_references"] = [Dict("reference" => ref, "type" => "function") for ref in broken_references]
    
    # Calculate statistics
    total_functions = length(all_functions)
    documented_count = length(documented_functions)
    documentation_coverage = total_functions > 0 ? documented_count / total_functions : 0.0
    
    linkage_results["linkage_statistics"] = Dict{String, Any}(
        "total_functions" => total_functions,
        "documented_functions" => documented_count,
        "undocumented_functions" => length(undocumented_functions),
        "documentation_coverage" => documentation_coverage,
        "broken_references" => length(broken_references)
    )
    
    return linkage_results
end

"""
Extract function references from documentation text
"""
function extract_function_references(content::String)::Vector{String}
    references = String[]
    
    # Look for backticked function names (simple heuristic)
    backtick_pattern = r"`([a-zA-Z_][a-zA-Z0-9_]*)\(`"
    for match in eachmatch(backtick_pattern, content)
        if length(match.captures) > 0 && match.captures[1] !== nothing
            push!(references, match.captures[1])
        end
    end
    
    return unique(references)
end

"""
Extract file references from documentation text
"""
function extract_file_references(content::String)::Vector{String}
    references = String[]
    
    # Look for .jl file references
    file_pattern = r"([a-zA-Z0-9_/]+\.jl)"
    for match in eachmatch(file_pattern, content)
        push!(references, match.match)
    end
    
    return unique(references)
end

"""
Extract module references from documentation text
"""
function extract_module_references(content::String)::Vector{String}
    references = String[]
    
    # Look for using/import statements in code blocks
    using_pattern = r"using\s+([a-zA-Z_][a-zA-Z0-9_]*)"
    for match in eachmatch(using_pattern, content)
        if length(match.captures) > 0 && match.captures[1] !== nothing
            push!(references, match.captures[1])
        end
    end
    
    return unique(references)
end

"""
Calculate overall linkage health score
"""
function calculate_linkage_health_score(results::Dict{String, Any})::Float64
    linkage_analysis = get(results, "linkage_analysis", Dict())
    linkage_stats = get(linkage_analysis, "linkage_statistics", Dict())
    
    documentation_coverage = get(linkage_stats, "documentation_coverage", 0.0)
    broken_references = get(linkage_stats, "broken_references", 0)
    total_functions = get(linkage_stats, "total_functions", 1)
    
    # Base score from documentation coverage
    base_score = documentation_coverage
    
    # Penalty for broken references
    broken_penalty = min(0.5, broken_references / max(1, total_functions))
    
    # Final score
    final_score = max(0.0, base_score - broken_penalty)
    
    return final_score
end

"""
Print linkage analysis summary to console
"""
function print_linkage_summary(results::Dict{String, Any}, verbose::Bool)
    if !get(results, "enabled", false)
        println("  🔗 Documentation Linkage: Disabled")
        return
    end
    
    println("  🔗 Documentation-Code Linkage Analysis:")
    
    linkage_analysis = get(results, "linkage_analysis", Dict())
    linkage_stats = get(linkage_analysis, "linkage_statistics", Dict())
    
    total_functions = get(linkage_stats, "total_functions", 0)
    documented_functions = get(linkage_stats, "documented_functions", 0)
    undocumented_functions = get(linkage_stats, "undocumented_functions", 0)
    broken_references = get(linkage_stats, "broken_references", 0)
    documentation_coverage = get(linkage_stats, "documentation_coverage", 0.0)
    
    println("     Functions found: $total_functions")
    println("     ✅ Documented: $documented_functions")
    println("     ❌ Undocumented: $undocumented_functions")
    
    if broken_references > 0
        println("     🔗 Broken references: $broken_references")
    end
    
    println("     📊 Documentation coverage: $(round(documentation_coverage * 100, digits=1))%")
    
    # Health score
    health_score = get(results, "linkage_health_score", 0.0)
    health_emoji = if health_score >= 0.8
        "🟢"
    elseif health_score >= 0.6
        "🟡"
    else
        "🔴"
    end
    
    println("     $health_emoji Linkage health: $(round(health_score * 100, digits=1))%")
    
    if verbose && undocumented_functions > 0
        undocumented_list = get(linkage_analysis, "undocumented_functions", [])
        println("     Undocumented functions (showing first 5):")
        for func_name in undocumented_list[1:min(5, length(undocumented_list))]
            println("       📝 $func_name")
        end
        
        if length(undocumented_list) > 5
            println("       ... and $(length(undocumented_list) - 5) more")
        end
    end
end
