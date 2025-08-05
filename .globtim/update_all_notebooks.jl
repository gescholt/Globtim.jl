#!/usr/bin/env julia

"""
Update All Notebooks Script

This script updates all Jupyter notebooks in the Examples/Notebooks/ directory
to use the new standardized notebook setup approach.

Usage:
    julia .globtim/update_all_notebooks.jl
"""

# No external dependencies needed - using text processing

function find_project_root()
    current_dir = pwd()
    while current_dir != "/"
        if isfile(joinpath(current_dir, "Project.toml")) && 
           isdir(joinpath(current_dir, "environments"))
            return current_dir
        end
        current_dir = dirname(current_dir)
    end
    error("Could not find Globtim project root")
end

function get_standard_setup_cell()
    return [
        "# Globtim Notebook Setup - Universal Header Cell",
        "# This cell automatically detects your environment and sets up the appropriate configuration", 
        "# No editing required - works from any location in the project",
        "",
        "include(joinpath(dirname(Base.find_package(\"Globtim\")), \"..\", \".globtim\", \"notebook_setup.jl\"))"
    ]
end

function is_setup_cell(source_lines)
    # Check if this looks like a setup cell
    source_text = join(source_lines, "\n")
    
    # Look for common setup patterns
    setup_patterns = [
        "smart_notebook_setup",
        "notebook_setup", 
        "include(\"../",
        "using Pkg",
        "Pkg.activate",
        "using CairoMakie",
        "using GLMakie",
        "using Globtim"
    ]
    
    # If it contains multiple setup patterns, it's likely a setup cell
    pattern_count = sum(occursin(pattern, source_text) for pattern in setup_patterns)
    return pattern_count >= 2
end

function analyze_notebook(notebook_path)
    println("Analyzing: $(basename(notebook_path))")

    # Read notebook as text
    content = read(notebook_path, String)

    # Check for different setup patterns
    has_new_setup = occursin(".globtim", content) && occursin("notebook_setup.jl", content)
    has_old_setup = occursin("smart_notebook_setup", content) ||
                   occursin("include(\"../", content) ||
                   (occursin("using Pkg", content) && occursin("Pkg.activate", content))

    if has_new_setup
        println("  ✓ Has new standardized setup")
        return "updated"
    elseif has_old_setup
        println("  ⚠ Has old setup - needs updating")
        return "needs_update"
    else
        println("  ? No clear setup pattern found")
        return "unclear"
    end
end

function show_update_instructions()
    println()
    println("="^60)
    println("  Manual Update Instructions")
    println("="^60)
    println()
    println("For notebooks that need updating, replace the first code cell with:")
    println()
    println("```julia")
    for line in get_standard_setup_cell()
        println(line)
    end
    println("```")
    println()
    println("This universal setup cell:")
    println("• Works from any location in the project")
    println("• Automatically detects local vs HPC environment")
    println("• Loads appropriate packages and plotting backends")
    println("• Requires no path editing or customization")
    println()
    println("Benefits:")
    println("• No more broken relative paths")
    println("• Consistent setup across all notebooks")
    println("• Easy sharing and collaboration")
    println("• Automatic environment optimization")
end

function main()
    println("="^60)
    println("  Globtim Notebook Update Script")
    println("="^60)
    
    project_root = find_project_root()
    notebooks_dir = joinpath(project_root, "Examples", "Notebooks")
    
    if !isdir(notebooks_dir)
        println("ERROR: Notebooks directory not found: $notebooks_dir")
        return
    end
    
    # Find all .ipynb files
    notebook_files = []
    for file in readdir(notebooks_dir)
        if endswith(file, ".ipynb")
            push!(notebook_files, joinpath(notebooks_dir, file))
        end
    end
    
    if isempty(notebook_files)
        println("No notebook files found in $notebooks_dir")
        return
    end
    
    println("Found $(length(notebook_files)) notebook files")
    println()
    
    # Analyze each notebook
    status_counts = Dict("updated" => 0, "needs_update" => 0, "unclear" => 0)
    needs_update_files = String[]

    for notebook_path in notebook_files
        try
            status = analyze_notebook(notebook_path)
            status_counts[status] += 1
            if status == "needs_update"
                push!(needs_update_files, basename(notebook_path))
            end
        catch e
            println("  ❌ Error processing $(basename(notebook_path)): $e")
        end
        println()
    end

    println("="^60)
    println("  Analysis Summary")
    println("="^60)
    println("Total notebooks: $(length(notebook_files))")
    println("✓ Already updated: $(status_counts["updated"])")
    println("⚠ Need updating: $(status_counts["needs_update"])")
    println("? Unclear status: $(status_counts["unclear"])")

    if status_counts["needs_update"] > 0
        println()
        println("Notebooks that need updating:")
        for file in needs_update_files
            println("  • $file")
        end
        show_update_instructions()
    else
        println()
        println("🎉 All notebooks are up to date!")
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
