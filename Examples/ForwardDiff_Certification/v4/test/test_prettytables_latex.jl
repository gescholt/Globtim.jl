#!/usr/bin/env julia

# Test PrettyTables for LaTeX export

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../../"))

using DataFrames
using PrettyTables
using CSV

# Load a sample CSV file
csv_file = joinpath(@__DIR__, "../outputs/enhanced_14-31/function_value_error_summary.csv")
if isfile(csv_file)
    df = CSV.read(csv_file, DataFrame)
    
    println("Original DataFrame:")
    println(df)
    
    println("\n\nLaTeX output (basic):")
    pretty_table(df, backend = Val(:latex))
    
    println("\n\nLaTeX output with booktabs:")
    pretty_table(df, backend = Val(:latex), tf = tf_latex_booktabs)
    
    println("\n\nLaTeX output with custom formatting:")
    pretty_table(df, 
        backend = Val(:latex),
        tf = tf_latex_booktabs,
        label = "tab:error_summary"
    )
    
    # Save to file with wrapping for caption
    latex_file = "test_output.tex"
    open(latex_file, "w") do io
        println(io, "\\begin{table}[htbp]")
        println(io, "\\centering")
        println(io, "\\caption{Function value errors for 4D Deuflhard composite function by polynomial degree}")
        println(io, "\\label{tab:error_summary}")
        pretty_table(io, df,
            backend = Val(:latex),
            tf = tf_latex_booktabs,
            show_subheader = false  # Hide type row
        )
        println(io, "\\end{table}")
    end
    println("\n\nLaTeX table saved to: $latex_file")
else
    println("Sample CSV file not found. Creating a test DataFrame...")
    
    # Create test data similar to our summary table
    test_df = DataFrame(
        Degree = [3, 4, 5],
        Min_Captured = ["4/9", "7/9", "9/9"],
        Avg_Rel_Error = ["4.201%", "1.523%", "0.341%"],
        Max_Error = ["4.2e-02", "1.5e-02", "3.4e-03"],
        Saddle_Captured = ["0/16", "5/16", "12/16"],
        Avg_Error_Saddle = ["-", "2.3e-03", "8.7e-04"],
        Max_Error_Saddle = ["-", "5.1e-03", "1.2e-03"]
    )
    
    println("Test DataFrame:")
    println(test_df)
    
    println("\n\nLaTeX with booktabs and custom headers:")
    pretty_table(test_df,
        backend = Val(:latex),
        tf = tf_latex_booktabs,
        label = "tab:test",
        caption = "Test summary table",
        alignment = [:c, :c, :r, :r, :c, :r, :r]
    )
end