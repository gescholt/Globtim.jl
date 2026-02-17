# Enhanced Analysis Integration for Phase 3 Statistical Tables
#
# This module extends the existing analyze_critical_points function to include
# comprehensive statistical table generation and display.

using Dates

include("statistical_tables.jl")
include("table_rendering.jl")

"""
    analyze_critical_points_with_tables(f, df, TR; 
                                       enable_hessian=true,
                                       enable_valley_detection=false,
                                       show_tables=true,
                                       table_format=:console,
                                       table_detail=:comprehensive,
                                       table_types=[:minimum, :maximum, :saddle],
                                       table_width=80,
                                       export_tables=false,
                                       export_prefix="critical_point_analysis",
                                       kwargs...)

Enhanced analyze_critical_points with integrated statistical table display.

This function performs the standard Phase 2 Hessian analysis and optionally generates
comprehensive statistical tables for detailed critical point analysis.

# Arguments
- `f`: Objective function
- `df`: Critical points DataFrame from process_crit_pts
- `TR`: TestInput structure
- `enable_hessian::Bool=true`: Enable Phase 2 Hessian analysis  
- `enable_valley_detection::Bool=false`: Enable valley detection analysis
- `show_tables::Bool=true`: Display statistical tables
- `table_format::Symbol=:console`: Table output format (:console, :html, :latex, :markdown)
- `table_detail::Symbol=:comprehensive`: Detail level (:basic, :comprehensive, :publication)
- `table_types::Vector{Symbol}`: Which point types to analyze ([:minimum, :maximum, :saddle, :degenerate])
- `table_width::Int=80`: Console table width
- `export_tables::Bool=false`: Save tables to files
- `export_prefix::String`: Base filename for exported tables

# Returns
- `DataFrame`: Enhanced DataFrame with Phase 2 Hessian analysis
- `DataFrame`: Minima DataFrame
- `Dict{Symbol, String}`: Rendered tables by critical point type (if show_tables=true)
- `Dict{Symbol, ComprehensiveStatsTable}`: Statistical table objects for programmatic access

# Examples
```julia
# Basic usage with tables
df_enhanced, df_min, tables, stats_objects = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true
)

# Publication-ready analysis with export
df_enhanced, df_min, tables, stats_objects = analyze_critical_points_with_tables(
    f, df, TR,
    enable_hessian=true,
    show_tables=true,
    table_format=:console,
    table_detail=:publication,
    table_types=[:minimum, :maximum, :saddle],
    export_tables=true,
    export_prefix="publication_analysis"
)
```
"""
function analyze_critical_points_with_tables(
    f,
    df,
    TR;
    enable_hessian = true,
    enable_valley_detection = false,
    show_tables = true,
    table_format = :console,
    table_types = [:minimum, :maximum, :saddle, :degenerate],
    table_width = 80,
    export_tables = false,
    export_prefix = "critical_point_analysis",
    kwargs...
)

    # Perform standard Phase 2 analysis first
    @debug "Running analyze_critical_points with enable_hessian=$enable_hessian"
    df_enhanced, df_minima =
        analyze_critical_points(f, df, TR, enable_hessian = enable_hessian, kwargs...)
    @debug "analyze_critical_points completed. DataFrame columns: $(names(df_enhanced))"

    # Perform valley detection analysis if requested
    if enable_valley_detection
        @info "Performing valley detection analysis..."
        df_enhanced = analyze_valleys_in_critical_points(f, df_enhanced)
        @debug "Valley detection completed. Added columns: is_valley, valley_dimension, manifold_score"
    end

    # Initialize return containers
    rendered_tables = Dict{Symbol, String}()
    stats_objects = Dict{Symbol, ComprehensiveStatsTable}()

    # Generate tables if requested and Hessian analysis is enabled
    if show_tables && enable_hessian
        @info "Generating statistical tables for critical point analysis..."

        # Verify that the Phase 2 analysis was actually performed
        required_columns = [:critical_point_type, :hessian_norm, :hessian_condition_number]
        available_columns = Symbol.(names(df_enhanced))  # Convert String to Symbol
        missing_columns = [col for col in required_columns if !(col in available_columns)]

        if !isempty(missing_columns)
            @error "Phase 2 Hessian analysis appears to have failed. Missing columns: $missing_columns"
            @error "Available columns: $(names(df_enhanced))"
            @error "This usually indicates a problem with ForwardDiff compatibility or function evaluation."
            @error "Try running analyze_critical_points directly with verbose=true to debug."

            # Return basic results without tables
            return df_enhanced, df_minima, rendered_tables, stats_objects
        end

        for point_type in table_types
            # Compute type-specific statistics
            stats_table = compute_type_specific_statistics(df_enhanced, point_type)

            # Skip if no points of this type
            if stats_table.hessian_stats.count == 0
                @debug "No $(point_type) points found, skipping table generation"
                continue
            end

            @info "Processing $(stats_table.hessian_stats.count) $(point_type) points..."

            # Store stats object for programmatic access
            stats_objects[point_type] = stats_table

            # Render table in requested format
            table_string =
                render_table(stats_table, output = table_format, width = table_width)

            rendered_tables[point_type] = table_string

            # Display immediately if console format
            if table_format == :console
                println("\n" * "="^table_width)
                println(table_string)
                println("="^table_width)
            end

            # Export if requested
            if export_tables
                timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
                extension = table_format == :console ? "txt" : string(table_format)
                export_filename = "$(export_prefix)_$(point_type)_$(timestamp).$(extension)"

                try
                    write(export_filename, table_string)
                    @info "Table exported: $export_filename"
                catch e
                    @warn "Failed to export table: $export_filename" exception = e
                end
            end
        end

        # Generate comparative summary if multiple types
        if length(stats_objects) > 1
            @info "Generating comparative analysis..."

            stats_list = collect(values(stats_objects))
            comparative_table = render_comparative_table(stats_list; width = table_width)
            rendered_tables[:comparative] = comparative_table

            if table_format == :console
                println("\n" * "="^table_width)
                println("COMPARATIVE ANALYSIS")
                println("="^table_width)
                println(comparative_table)
                println("="^table_width)
            end

            # Export comparative table
            if export_tables
                timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
                extension = table_format == :console ? "txt" : string(table_format)
                export_filename = "$(export_prefix)_comparative_$(timestamp).$(extension)"

                try
                    write(export_filename, comparative_table)
                    @info "Comparative table exported: $export_filename"
                catch e
                    @warn "Failed to export comparative table: $export_filename" exception =
                        e
                end
            end
        end

        # Summary message
        if !isempty(rendered_tables)
            @info "Statistical table generation complete. Generated $(length(rendered_tables)) tables."
        else
            @warn "No statistical tables generated. Check that critical points were found."
        end
    end

    return df_enhanced, df_minima, rendered_tables, stats_objects
end

"""
    display_statistical_table(stats_table::ComprehensiveStatsTable; width=80)

Display a single statistical table with proper formatting.
"""
function display_statistical_table(stats_table::ComprehensiveStatsTable; width = 80)
    table_string = render_console_table(stats_table; width = width)
    println("\n" * "="^width)
    println(table_string)
    println("="^width)
    return table_string
end

"""
    export_analysis_tables(rendered_tables::Dict{Symbol, String}, 
                          base_filename::String;
                          formats=[:console],
                          include_timestamp=true)

Export statistical tables in multiple formats for different use cases.

# Arguments
- `rendered_tables::Dict{Symbol, String}`: Tables to export
- `base_filename::String`: Base filename for exports
- `formats::Vector{Symbol}=[:console]`: Export formats
- `include_timestamp::Bool=true`: Include timestamp in filenames

# Examples
```julia
# Export tables from analysis
export_analysis_tables(tables, "critical_point_analysis", 
                      formats=[:console, :markdown])
```
"""
function export_analysis_tables(
    rendered_tables::Dict{Symbol, String},
    base_filename::String;
    formats = [:console],
    include_timestamp = true
)

    timestamp_str = include_timestamp ? "_$(Dates.format(now(), "yyyymmdd_HHMMSS"))" : ""

    for (point_type, table_content) in rendered_tables
        for format in formats
            extension = format == :console ? "txt" : string(format)
            filename = "$(base_filename)_$(point_type)$(timestamp_str).$(extension)"

            try
                if format == :console
                    # Direct export of console content
                    write(filename, table_content)
                else
                    # Future: implement format conversion
                    @warn "Format conversion not yet implemented: $format"
                    continue
                end

                @info "Table exported: $filename"
            catch e
                @error "Failed to export table: $filename" exception = e
            end
        end
    end
end

"""
    create_statistical_summary(df_enhanced::DataFrame)

Create a quick statistical summary of all critical point types.

# Returns
- `String`: Formatted summary table
"""
function create_statistical_summary(df_enhanced::DataFrame)
    if !hasproperty(df_enhanced, :critical_point_type)
        return "No critical point type information available."
    end

    # Count by type
    type_counts = DataFrames.combine(
        DataFrames.groupby(df_enhanced, :critical_point_type),
        DataFrames.nrow => :count
    )
    total_points = nrow(df_enhanced)

    lines = String[]
    push!(lines, "┌─────────────────────────────────────────┐")
    push!(lines, "│           CRITICAL POINT SUMMARY        │")
    push!(lines, "├─────────────────┬───────────┬───────────┤")
    push!(lines, "│ Type            │ Count     │ Percent   │")
    push!(lines, "├─────────────────┼───────────┼───────────┤")

    for row in eachrow(type_counts)
        type_name = titlecase(string(row.critical_point_type))
        count = row.count
        percentage = round(100 * count / total_points, digits = 1)

        line = "│ $(rpad(type_name, 15)) │ $(lpad(count, 9)) │ $(lpad("$(percentage)%", 9)) │"
        push!(lines, line)
    end

    push!(lines, "├─────────────────┼───────────┼───────────┤")
    push!(
        lines,
        "│ $(rpad("TOTAL", 15)) │ $(lpad(total_points, 9)) │ $(lpad("100.0%", 9)) │"
    )
    push!(lines, "└─────────────────┴───────────┴───────────┘")

    return join(lines, "\n")
end

"""
    quick_table_preview(f, df, TR; point_types=[:minimum, :maximum])

Generate a quick preview of statistical tables without full analysis.
Useful for rapid exploration of results.
"""
function quick_table_preview(f, df, TR; point_types = [:minimum, :maximum])
    @info "Generating quick table preview..."

    # Perform minimal Phase 2 analysis if needed
    if !hasproperty(df, :critical_point_type) || !hasproperty(df, :hessian_norm)
        @info "Phase 2 analysis required, performing minimal analysis..."
        df_enhanced, _ =
            analyze_critical_points(f, df, TR, enable_hessian = true, verbose = false)
    else
        df_enhanced = df
    end

    # Show basic summary
    summary_table = create_statistical_summary(df_enhanced)
    println(summary_table)

    # Show simplified statistics for requested types
    for point_type in point_types
        stats_table = compute_type_specific_statistics(df_enhanced, point_type)
        if stats_table.hessian_stats.count > 0
            # Simplified display
            hs = stats_table.hessian_stats
            ca = stats_table.condition_analysis

            println("\n$(uppercase(string(point_type))) Quick Stats:")
            println("  Count: $(hs.count)")
            println(
                "  Hessian norm: $(round(hs.mean, digits=3)) ± $(round(hs.std, digits=3))"
            )
            if ca.total_count > 0
                println("  Well-conditioned: $(ca.well_conditioned_percentage)%")
                println("  Quality: $(ca.overall_quality)")
            end
        end
    end

    println("\nFor detailed analysis, use: analyze_critical_points_with_tables()")
end
