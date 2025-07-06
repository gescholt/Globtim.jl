# TableGeneration.jl - Summary table utilities for analysis results

module TableGeneration

using PrettyTables
using Printf
using DataFrames, CSV

export generate_degree_summary_table, generate_subdivision_summary_table
export export_results_to_csv, export_subdivision_results_to_csv

"""
    generate_degree_summary_table(results; title="Degree Analysis Summary")

Generate formatted summary table for degree analysis results.

# Arguments
- `results`: Vector of DegreeAnalysisResult objects
- `title`: Table title

# Returns
- Nothing (prints table to stdout)
"""
function generate_degree_summary_table(results; title="Degree Analysis Summary")
    if isempty(results)
        println("No results to display")
        return
    end
    
    # Prepare table data
    table_data = []
    for r in results
        push!(table_data, [
            r.degree,
            @sprintf("%.2e", r.l2_norm),
            r.n_computed_points,
            r.n_theoretical_points,
            @sprintf("%.1f%%", r.success_rate * 100),
            @sprintf("%.1f%%", r.min_min_success_rate * 100),
            @sprintf("%.1f", r.runtime_seconds),
            r.converged ? "Yes" : "No"
        ])
    end
    
    headers = ["Degree", "L²-Norm", "Found", "Expected", "Success %", "Min+Min %", "Runtime(s)", "Converged"]
    
    # Convert to matrix
    n_rows = length(table_data)
    n_cols = length(headers)
    table_matrix = Matrix{String}(undef, n_rows, n_cols)
    
    for (i, row) in enumerate(table_data)
        for (j, val) in enumerate(row)
            table_matrix[i, j] = string(val)
        end
    end
    
    pretty_table(
        table_matrix,
        header = headers,
        alignment = [:c, :r, :c, :c, :r, :r, :r, :c],
        title = title
    )
end

"""
    generate_subdivision_summary_table(all_results; title="Subdivision Analysis Summary")

Generate summary table for subdivision analysis results.

# Arguments
- `all_results`: Dict{String, Vector{DegreeAnalysisResult}} mapping labels to results
- `title`: Table title

# Returns
- Nothing (prints table to stdout)
"""
function generate_subdivision_summary_table(all_results; title="Subdivision Analysis Summary")
    if isempty(all_results)
        println("No results to display")
        return
    end
    
    # Prepare table data
    table_data = []
    for label in sort(collect(keys(all_results)))
        results = all_results[label]
        if !isempty(results)
            # Find best result
            best_idx = argmin([r.l2_norm for r in results])
            best_result = results[best_idx]
            
            # Check convergence
            converged = any([r.converged for r in results])
            convergence_degree = converged ? 
                results[findfirst([r.converged for r in results])].degree : "None"
            
            total_runtime = sum([r.runtime_seconds for r in results])
            
            push!(table_data, [
                label,
                length(results),
                @sprintf("%.2e", best_result.l2_norm),
                best_result.degree,
                string(convergence_degree),
                best_result.n_theoretical_points,
                @sprintf("%.1f%%", best_result.success_rate * 100),
                @sprintf("%.1f", total_runtime)
            ])
        end
    end
    
    headers = ["Subdomain", "Degrees", "Best L²", "Best Deg", "Conv. Deg", "Theory Pts", "Success %", "Runtime(s)"]
    
    # Convert to matrix
    n_rows = length(table_data)
    n_cols = length(headers)
    table_matrix = Matrix{String}(undef, n_rows, n_cols)
    
    for (i, row) in enumerate(table_data)
        for (j, val) in enumerate(row)
            table_matrix[i, j] = string(val)
        end
    end
    
    pretty_table(
        table_matrix,
        header = headers,
        alignment = [:c, :c, :r, :c, :c, :c, :r, :r],
        title = title
    )
end

"""
    export_results_to_csv(results, filepath)

Export degree analysis results to CSV file.

# Arguments
- `results`: Vector of DegreeAnalysisResult objects
- `filepath`: Path to save CSV file
"""
function export_results_to_csv(results, filepath)
    if isempty(results)
        @warn "No results to export"
        return
    end
    
    # Create DataFrame
    df = DataFrame(
        degree = [r.degree for r in results],
        l2_norm = [r.l2_norm for r in results],
        n_computed_points = [r.n_computed_points for r in results],
        n_theoretical_points = [r.n_theoretical_points for r in results],
        n_successful_recoveries = [r.n_successful_recoveries for r in results],
        success_rate = [r.success_rate for r in results],
        min_min_success_rate = [r.min_min_success_rate for r in results],
        runtime_seconds = [r.runtime_seconds for r in results],
        converged = [r.converged for r in results]
    )
    
    CSV.write(filepath, df)
    @info "Results exported to CSV" path=filepath n_rows=nrow(df)
end

"""
    export_subdivision_results_to_csv(all_results, filepath)

Export subdivision analysis results to CSV file.

# Arguments
- `all_results`: Dict{String, Vector{DegreeAnalysisResult}}
- `filepath`: Path to save CSV file
"""
function export_subdivision_results_to_csv(all_results, filepath)
    if isempty(all_results)
        @warn "No results to export"
        return
    end
    
    # Flatten results
    rows = []
    for (label, results) in all_results
        for r in results
            push!(rows, (
                subdomain = label,
                degree = r.degree,
                l2_norm = r.l2_norm,
                n_computed_points = r.n_computed_points,
                n_theoretical_points = r.n_theoretical_points,
                success_rate = r.success_rate,
                runtime_seconds = r.runtime_seconds,
                converged = r.converged
            ))
        end
    end
    
    df = DataFrame(rows)
    CSV.write(filepath, df)
    @info "Subdivision results exported to CSV" path=filepath n_rows=nrow(df)
end

end # module