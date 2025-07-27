# Table Rendering System for Statistical Tables
#
# This module provides ASCII table rendering capabilities with professional
# formatting for console output, following the successful histogram approach.

"""
    center_text(prefix::String, text::String, width::Int, suffix::String="")

Center text within a given width with optional prefix and suffix.
"""
function center_text(prefix::String, text::String, width::Int, suffix::String = "")
    available_width = width - length(prefix) - length(suffix)
    if length(text) >= available_width
        # Truncate if too long
        truncated_text = text[1:min(length(text), available_width - 3)] * "..."
        return prefix * truncated_text * suffix
    end

    padding = available_width - length(text)
    left_pad = div(padding, 2)
    right_pad = padding - left_pad

    return prefix * " "^left_pad * text * " "^right_pad * suffix
end

"""
    format_table_row(label::String, value::String, width::Int; 
                     label_width_ratio=0.6, padding=" ")

Format a single table row with proper alignment and padding.
"""
function format_table_row(label::String, value::String, width::Int; label_width_ratio = 0.6)
    # Calculate column widths
    available_width = width - 6  # Account for borders and separators "│ │ │"
    label_width = max(10, floor(Int, available_width * label_width_ratio))
    value_width = available_width - label_width

    # Truncate if necessary
    display_label = if length(label) > label_width
        label[1:label_width-3] * "..."
    else
        label
    end

    display_value = if length(value) > value_width
        value[1:value_width-3] * "..."
    else
        value
    end

    # Pad to alignment
    padded_label = rpad(display_label, label_width)
    padded_value = lpad(display_value, value_width)

    return "│ $padded_label │ $padded_value │"
end

"""
    create_table_border(width::Int, style::Symbol=:top)

Create table border lines.

# Arguments
- `width::Int`: Total table width
- `style::Symbol`: Border style (:top, :middle, :bottom, :section)
"""
function create_table_border(width::Int, style::Symbol = :top)
    if style == :top
        return "┌" * "─"^(width - 2) * "┐"
    elseif style == :middle
        return "├" * "─"^(width - 2) * "┤"
    elseif style == :bottom
        return "└" * "─"^(width - 2) * "┘"
    elseif style == :section
        return "├" * "─"^(width - 2) * "┤"
    else
        return "├" * "─"^(width - 2) * "┤"
    end
end

"""
    render_console_table(stats_table::ComprehensiveStatsTable; width=80)

Render a comprehensive statistics table in ASCII format for console display.
"""
function render_console_table(stats_table::ComprehensiveStatsTable; width = 80)
    lines = String[]
    table_width = min(width, 120)  # Maximum reasonable width

    # Title
    title = "$(uppercase(string(stats_table.point_type))) STATISTICS"
    push!(lines, create_table_border(table_width, :top))
    push!(lines, center_text("│", title, table_width - 2, "│"))
    push!(lines, create_table_border(table_width, :middle))

    # Basic statistics section
    hs = stats_table.hessian_stats
    if hs.count > 0
        push!(lines, format_table_row("Count", string(hs.count), table_width))
        push!(
            lines,
            format_table_row(
                "Mean ± Std",
                "$(round(hs.mean, digits=3)) ± $(round(hs.std, digits=3))",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Median (IQR)",
                "$(round(hs.median, digits=3)) ($(round(hs.q1, digits=3))-$(round(hs.q3, digits=3)))",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Range",
                "[$(round(hs.min, digits=3)), $(round(hs.max, digits=3))]",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Outliers",
                "$(hs.outlier_count) ($(hs.outlier_percentage)%)",
                table_width,
            ),
        )
    else
        push!(lines, format_table_row("Count", "0", table_width))
        push!(lines, format_table_row("Status", "No data available", table_width))
    end

    # Condition number quality section
    ca = stats_table.condition_analysis
    if ca.total_count > 0
        push!(lines, create_table_border(table_width, :section))
        push!(lines, center_text("│", "CONDITION NUMBER QUALITY", table_width - 2, "│"))
        push!(lines, create_table_border(table_width, :middle))

        total = ca.total_count
        push!(
            lines,
            format_table_row(
                "Excellent (< 1e3)",
                "$(ca.excellent_count) ($(round(100*ca.excellent_count/total, digits=1))%)",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Good (1e3-1e6)",
                "$(ca.good_count) ($(round(100*ca.good_count/total, digits=1))%)",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Fair (1e6-1e9)",
                "$(ca.fair_count) ($(round(100*ca.fair_count/total, digits=1))%)",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Poor (1e9-1e12)",
                "$(ca.poor_count) ($(round(100*ca.poor_count/total, digits=1))%)",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Critical (≥ 1e12)",
                "$(ca.critical_count) ($(round(100*ca.critical_count/total, digits=1))%)",
                table_width,
            ),
        )
        push!(lines, format_table_row("Overall Quality", ca.overall_quality, table_width))
    end

    # Mathematical validation section
    vr = stats_table.validation_results
    has_validation_data =
        !ismissing(vr.eigenvalue_signs_correct) ||
        !ismissing(vr.mixed_eigenvalue_signs) ||
        !ismissing(vr.determinant_positive)

    if has_validation_data
        push!(lines, create_table_border(table_width, :section))
        push!(lines, center_text("│", "MATHEMATICAL VALIDATION", table_width - 2, "│"))
        push!(lines, create_table_border(table_width, :middle))

        # Show relevant validation results based on point type
        if stats_table.point_type == :minimum
            if !ismissing(vr.eigenvalue_signs_correct)
                status = format_validation_value(vr.eigenvalue_signs_correct)
                push!(
                    lines,
                    format_table_row("All eigenvalues positive", status, table_width),
                )
            end
            if !ismissing(vr.positive_eigenvalue_count)
                push!(
                    lines,
                    format_table_row(
                        "Positive eigenvalue count",
                        string(vr.positive_eigenvalue_count),
                        table_width,
                    ),
                )
            end
            if !ismissing(vr.determinant_positive)
                status = format_validation_value(vr.determinant_positive)
                push!(lines, format_table_row("Determinant positive", status, table_width))
            end

        elseif stats_table.point_type == :maximum
            if !ismissing(vr.eigenvalue_signs_correct)
                status = format_validation_value(vr.eigenvalue_signs_correct)
                push!(
                    lines,
                    format_table_row("All eigenvalues negative", status, table_width),
                )
            end
            if !ismissing(vr.negative_eigenvalue_count)
                push!(
                    lines,
                    format_table_row(
                        "Negative eigenvalue count",
                        string(vr.negative_eigenvalue_count),
                        table_width,
                    ),
                )
            end
            if !ismissing(vr.determinant_sign_consistent)
                status = format_validation_value(vr.determinant_sign_consistent)
                push!(
                    lines,
                    format_table_row("Determinant sign consistent", status, table_width),
                )
            end

        elseif stats_table.point_type == :saddle
            if !ismissing(vr.mixed_eigenvalue_signs)
                status = format_validation_value(vr.mixed_eigenvalue_signs)
                push!(
                    lines,
                    format_table_row("Mixed eigenvalue signs", status, table_width),
                )
            end
        end

        # Show additional validation metrics if available
        for (key, value) in vr.additional_checks
            if isa(value, Number) && isfinite(value)
                display_key = format_validation_key(key)
                display_value =
                    isa(value, AbstractFloat) ? string(round(value, digits = 4)) :
                    string(value)
                push!(lines, format_table_row(display_key, display_value, table_width))
            end
        end
    end

    # Eigenvalue statistics section (if available)
    if !ismissing(stats_table.eigenvalue_stats)
        es = stats_table.eigenvalue_stats
        if es.count > 0
            push!(lines, create_table_border(table_width, :section))
            push!(lines, center_text("│", "EIGENVALUE STATISTICS", table_width - 2, "│"))
            push!(lines, create_table_border(table_width, :middle))

            push!(
                lines,
                format_table_row("Eigenvalue count", string(es.count), table_width),
            )
            push!(
                lines,
                format_table_row(
                    "Mean ± Std",
                    "$(round(es.mean, digits=6)) ± $(round(es.std, digits=6))",
                    table_width,
                ),
            )
            push!(
                lines,
                format_table_row(
                    "Range",
                    "[$(round(es.min, digits=6)), $(round(es.max, digits=6))]",
                    table_width,
                ),
            )
        end
    end

    # Recommendations section
    if !isempty(ca.recommendations)
        push!(lines, create_table_border(table_width, :section))
        push!(lines, center_text("│", "RECOMMENDATIONS", table_width - 2, "│"))
        push!(lines, create_table_border(table_width, :middle))

        for (i, rec) in enumerate(ca.recommendations)
            bullet = "• "
            # Word wrap long recommendations
            max_rec_width = table_width - 6  # Account for borders
            if length(rec) > max_rec_width - 2
                # Simple word wrap (could be enhanced)
                words = split(rec, " ")
                current_line = bullet
                for word in words
                    if length(current_line) + length(word) + 1 <= max_rec_width
                        current_line *= word * " "
                    else
                        push!(
                            lines,
                            format_table_row("", rstrip(current_line), table_width),
                        )
                        current_line = "  " * word * " "
                    end
                end
                if !isempty(rstrip(current_line))
                    push!(lines, format_table_row("", rstrip(current_line), table_width))
                end
            else
                push!(lines, format_table_row("", bullet * rec, table_width))
            end
        end
    end

    # Footer
    push!(lines, create_table_border(table_width, :bottom))

    return join(lines, "\n")
end

"""
    render_comparative_table(stats_list::Vector{ComprehensiveStatsTable}; width=100)

Create a comparative analysis table showing statistics across multiple critical point types.
"""
function render_comparative_table(stats_list::Vector{ComprehensiveStatsTable}; width = 100)
    if isempty(stats_list)
        return "No data available for comparative analysis."
    end

    lines = String[]
    table_width = min(width, 120)

    # Header
    title = "COMPARATIVE ANALYSIS"
    push!(lines, create_table_border(table_width, :top))
    push!(lines, center_text("│", title, table_width - 2, "│"))

    # Column headers
    push!(lines, create_table_border(table_width, :middle))
    header_line = "│ Type        │ Count │ Hess.Mean │ Hess.Std  │ WellCond% │ Valid%   │"
    if length(header_line) > table_width
        # Simplified header for narrow tables
        header_line = "│ Type      │ Count │ Mean  │ Std   │ Qual% │ Valid │"
    end
    push!(lines, header_line)
    push!(lines, create_table_border(table_width, :middle))

    # Data rows
    total_points = 0
    well_conditioned_total = 0.0
    valid_total = 0.0

    for stats in stats_list
        point_type = titlecase(string(stats.point_type))
        count = stats.hessian_stats.count
        total_points += count

        if count > 0
            hess_mean = round(stats.hessian_stats.mean, digits = 2)
            hess_std = round(stats.hessian_stats.std, digits = 2)

            # Well-conditioned percentage
            ca = stats.condition_analysis
            well_cond_pct = ca.total_count > 0 ? ca.well_conditioned_percentage : 0.0
            well_conditioned_total += count * well_cond_pct / 100

            # Validation percentage (simplified)
            vr = stats.validation_results
            valid_pct =
                if stats.point_type == :minimum && !ismissing(vr.eigenvalue_signs_correct)
                    vr.eigenvalue_signs_correct ? 100.0 : 0.0
                elseif stats.point_type == :maximum &&
                       !ismissing(vr.eigenvalue_signs_correct)
                    vr.eigenvalue_signs_correct ? 100.0 : 0.0
                elseif stats.point_type == :saddle && !ismissing(vr.mixed_eigenvalue_signs)
                    vr.mixed_eigenvalue_signs ? 100.0 : 0.0
                else
                    0.0
                end
            valid_total += count * valid_pct / 100

            # Format row
            if table_width >= 80
                row = "│ $(rpad(point_type, 11)) │ $(lpad(count, 5)) │ $(lpad(hess_mean, 9)) │ $(lpad(hess_std, 9)) │ $(lpad(round(well_cond_pct, digits=1), 9)) │ $(lpad(round(valid_pct, digits=1), 8)) │"
            else
                # Compact format
                row = "│ $(rpad(point_type[1:min(8, length(point_type))], 8)) │ $(lpad(count, 5)) │ $(lpad(hess_mean, 5)) │ $(lpad(hess_std, 5)) │ $(lpad(round(well_cond_pct, digits=1), 5)) │ $(lpad(round(valid_pct, digits=1), 5)) │"
            end
            push!(lines, row)
        end
    end

    # Summary section
    push!(lines, create_table_border(table_width, :middle))
    if total_points > 0
        overall_well_cond = round(100 * well_conditioned_total / total_points, digits = 1)
        overall_valid = round(100 * valid_total / total_points, digits = 1)

        push!(lines, center_text("│", "SUMMARY", table_width - 2, "│"))
        push!(lines, create_table_border(table_width, :middle))
        push!(
            lines,
            format_table_row("Total critical points", string(total_points), table_width),
        )
        push!(
            lines,
            format_table_row(
                "Overall numerical quality",
                overall_well_cond > 80 ? "EXCELLENT" :
                overall_well_cond > 60 ? "GOOD" : "FAIR",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Mathematical validation",
                "$(overall_valid)% pass rate",
                table_width,
            ),
        )
        push!(
            lines,
            format_table_row(
                "Production readiness",
                (overall_well_cond > 70 && overall_valid > 80) ? "READY" : "NEEDS REVIEW",
                table_width,
            ),
        )
    end

    push!(lines, create_table_border(table_width, :bottom))

    return join(lines, "\n")
end

"""
    render_table(table::StatisticalTable; output=:console, width=80, kwargs...)

Universal table rendering dispatch function.
"""
function render_table(table::StatisticalTable; output = :console, width = 80, kwargs...)
    if output == :console
        if isa(table, ComprehensiveStatsTable)
            return render_console_table(table; width = width)
        else
            error("Console rendering not implemented for $(typeof(table))")
        end
    else
        error("Output format $output not yet implemented")
    end
end
