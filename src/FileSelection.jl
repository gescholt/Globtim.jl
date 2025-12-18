#!/usr/bin/env julia
"""
File Selection Interface Module

Provides interactive terminal-based file selection capabilities for comparing
experiment outputs. Integrates with TerminalMenus for a clean user experience.
"""

module FileSelection

export interactive_file_selection, discover_csv_files, select_multiple_files

using CSV, DataFrames
import REPL
using REPL.TerminalMenus

# Import defensive CSV loading (Issue #79)
include("DefensiveCSV.jl")
using .DefensiveCSV

"""
    discover_csv_files(search_path::String = ".") -> Vector{String}

Discover all CSV files in the given path and subdirectories.
Returns full paths to discovered files.
"""
function discover_csv_files(search_path::String = ".")::Vector{String}
    csv_files = String[]

    for (root, dirs, files) in walkdir(search_path)
        for file in files
            if endswith(lowercase(file), ".csv")
                full_path = joinpath(root, file)
                push!(csv_files, full_path)
            end
        end
    end

    return sort(csv_files)
end

"""
    filter_csv_files(files::Vector{String}) -> Vector{String}

Filter a list of files to include only CSV files.
"""
function filter_csv_files(files::Vector{String})::Vector{String}
    return filter(f -> endswith(lowercase(f), ".csv"), files)
end

"""
    format_menu_options(files::Vector{String}) -> Vector{String}

Format file paths for display in terminal menu.
Shows relative path and file size for better selection.
"""
function format_menu_options(files::Vector{String})::Vector{String}
    formatted = String[]

    for file in files
        # Get relative path from current directory
        rel_path = relpath(file, pwd())

        # Get file size if possible
        size_str = ""
        if isfile(file)
            try
                size_bytes = filesize(file)
                if size_bytes < 1024
                    size_str = " ($(size_bytes)B)"
                elseif size_bytes < 1024^2
                    size_str = " ($(round(size_bytes/1024, digits=1))KB)"
                else
                    size_str = " ($(round(size_bytes/1024^2, digits=1))MB)"
                end
            catch
                size_str = ""
            end
        end

        # Format: filename [path] (size)
        filename = basename(file)
        dir_part = dirname(rel_path)
        if dir_part == "."
            display_text = "$filename$size_str"
        else
            display_text = "$filename [$dir_part]$size_str"
        end

        push!(formatted, display_text)
    end

    return formatted
end

"""
    validate_csv_file(file_path::String) -> Bool

Validate that a file exists and can be read as CSV.
"""
function validate_csv_file(file_path::String)::Bool
    if !isfile(file_path)
        return false
    end

    try
        # Try to read header using defensive loading to validate CSV format
        result = defensive_csv_read(file_path, validate_columns=false, detect_interface_issues=false)
        return result.success
    catch
        return false
    end
end

"""
    validate_selection(indices::Vector{Int}, files::Vector{String}) -> Bool

Validate that selected indices are valid for the given file list.
"""
function validate_selection(indices::Vector{Int}, files::Vector{String})::Bool
    if isempty(indices)
        return false
    end

    return all(1 <= i <= length(files) for i in indices)
end

"""
    interactive_file_selection(search_path::String = ".";
                              allow_multiple::Bool = false) -> Union{String, Vector{String}, Nothing}

Interactive terminal-based file selection interface.
Returns selected file path(s) or nothing if cancelled.
"""
function interactive_file_selection(search_path::String = ".";
    allow_multiple::Bool = false)
    println("🔍 Discovering CSV files in: $(abspath(search_path))")

    # Discover available files
    csv_files = discover_csv_files(search_path)

    if isempty(csv_files)
        println("❌ No CSV files found in $search_path")
        return nothing
    end

    println("📁 Found $(length(csv_files)) CSV file$(length(csv_files) > 1 ? "s" : "")")

    # Format options for display
    menu_options = format_menu_options(csv_files)

    if allow_multiple
        # Multiple selection menu
        menu = MultiSelectMenu(menu_options, pagesize = 10)
        prompt = "Select CSV files for comparison (use space to select, enter to confirm):"

        selected_indices = request(prompt, menu)

        if isempty(selected_indices) || selected_indices == [-1]
            println("Selection cancelled.")
            return nothing
        end

        selected_files = [csv_files[i] for i in selected_indices]

        println(
            "✅ Selected $(length(selected_files)) file$(length(selected_files) > 1 ? "s" : ""):"
        )
        for file in selected_files
            println("   - $(relpath(file, pwd()))")
        end

        return selected_files
    else
        # Single selection menu
        menu = RadioMenu(menu_options, pagesize = 10)
        prompt = "Select a CSV file for analysis:"

        selected_index = request(prompt, menu)

        if selected_index == -1
            println("Selection cancelled.")
            return nothing
        end

        selected_file = csv_files[selected_index]
        println("✅ Selected: $(relpath(selected_file, pwd()))")

        return selected_file
    end
end

"""
    select_multiple_files(search_path::String = ".") -> Vector{String}

Convenience function for multiple file selection.
"""
function select_multiple_files(search_path::String = ".")
    result = interactive_file_selection(search_path, allow_multiple = true)
    return result === nothing ? String[] : result
end

"""
    load_selected_data(files::Vector{String}) -> DataFrame

Load and combine data from selected CSV files.
Adds a 'source_file' column to track origin of each row.
"""
function load_selected_data(files::Vector{String})::DataFrame
    if isempty(files)
        return DataFrame()
    end

    combined_data = DataFrame()

    for file in files
        println("📖 Loading: $(relpath(file, pwd()))")

        # Use defensive loading (Issue #79)
        result = defensive_csv_read(file, detect_interface_issues=true)

        if result.success
            file_data = result.data

            # Log any warnings
            if !isempty(result.warnings)
                println("⚠️  Warnings for $(basename(file)):")
                for warning in result.warnings
                    println("    • $warning")
                end
            end

            # Add source tracking
            file_data[!, :source_file] = fill(basename(file), nrow(file_data))

            if nrow(combined_data) == 0
                combined_data = file_data
            else
                # Append data, handling column mismatches with defensive approach
                try
                    # Check column compatibility before appending
                    if Set(names(file_data)) ⊆ Set(names(combined_data)) ||
                       Set(names(combined_data)) ⊆ Set(names(file_data))
                        append!(combined_data, file_data, cols = :union)
                    else
                        println("⚠️  Column structure mismatch in $(basename(file)), attempting union...")
                        append!(combined_data, file_data, cols = :union)
                    end
                catch e
                    @warn "Failed to combine data from $(basename(file)): $e"
                    continue
                end
            end
        else
            @warn "Failed to load $(basename(file)): $(result.error)"
            continue
        end
    end

    println(
        "✅ Loaded $(nrow(combined_data)) total rows from $(length(files)) file$(length(files) > 1 ? "s" : "")"
    )
    return combined_data
end

end  # module FileSelection
