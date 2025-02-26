"""
    msolve_polynomial_system(
        pol::ApproxPoly,
        x;
        n = 2,
        basis = :chebyshev,
        threads::Int = 10,
        verbose::Bool = false
    ) -> String

Solve a polynomial system using msolve.

# Arguments
- `pol`: ApproxPoly object containing polynomial information
- `x`: Variables
- `n`: Number of variables (default: 2)
- `basis`: Type of basis (:chebyshev or :legendre) (default: :chebyshev)
- `threads`: Number of threads for msolve to use (default: 10)
- `verbose`: Whether to print debug information (default: false)

# Returns
- Output filename for further processing
"""
function msolve_polynomial_system(
    pol::ApproxPoly,
    x;
    n=2,
    basis=:chebyshev,
    threads::Int=10,
    verbose::Bool=false
)
    if verbose
        println("Entering msolve_polynomial_system with ApproxPoly")
        println("pol.degree = $(pol.degree)")
        println("n = $n")
        println("basis = $basis")
        println("threads = $threads")
    end

    # Generate random temporary filenames
    random_suffix = randstring(8)
    input_file = "tmp_input_$(random_suffix).ms"
    output_file = "tmp_output_$(random_suffix).ms"

    if verbose
        println("input_file = $input_file")
        println("output_file = $output_file")
    end

    try
        # Process polynomial system
        names = [x[i].name for i = 1:length(x)]
        if verbose
            println("Variable names: $(join(names, ", "))")
        end

        # Write variable names to file
        open(input_file, "w") do file
            println(file, join(names, ", "))
            println(file, 0)
        end

        if verbose
            println("Input file created")
        end

        # Convert coefficients to BigRational
        rational_coeffs = [Rational{BigInt}(c) for c in pol.coeffs]

        # Create the polynomial in the monomial basis using the new function
        p = construct_orthopoly_polynomial(
            x,
            rational_coeffs,
            pol.degree,
            basis,
            RationalPrecision;  # Note the semicolon after this positional argument
            normalized=true,
            power_of_two_denom=false,
            verbose=verbose
        )
        
        # Compute gradient
        grad = differentiate.(p, x)

        if verbose
            println("Gradient computed successfully")
            println("Writing gradient to file")
        end

        # Write gradient to file, replacing // with / for msolve compatibility
        open(input_file, "a") do file
            for i = 1:n
                poly_str = replace(string(grad[i]), "//" => "/")

                if i < n
                    println(file, poly_str, ",")
                else
                    println(file, poly_str)
                end
            end
        end

        # Check file content if verbose
        if verbose
            println("File content:")
            println(read(input_file, String))
        end

        # Run msolve
        verbosity_level = verbose ? 1 : 0
        msolve_cmd = `msolve -v $verbosity_level -t $threads -f $input_file -o $output_file`

        if verbose
            println("Command: $msolve_cmd")
        end

        run(msolve_cmd)

        if verbose
            println("msolve command completed")
            if isfile(output_file)
                println("Output file exists with size $(filesize(output_file)) bytes")
                if filesize(output_file) > 0
                    println("First 200 chars of output file: $(first(read(output_file, String), 200))")
                end
            else
                println("WARNING - Output file does not exist!")
            end
        end

        # Return the output filename so it can be used by msolve_parser
        return output_file

    catch e
        println("Error in msolve_polynomial_system: ", e)
        if verbose
            for (exc, bt) in Base.catch_stack()
                showerror(stdout, exc, bt)
                println()
            end
        end
        rethrow(e)
    finally
        # Clean up only the input file here - important!
        if isfile(input_file)
            if verbose
                println("Cleaning up input file")
            end
            rm(input_file)
        end
    end
end

"""
    solve_and_parse(
        pol::ApproxPoly,
        x,
        f::Function,
        TR::test_input;
        basis = :chebyshev,
        threads::Int = 10,
        verbose::Bool = false,
        skip_filtering::Bool = false
    ) -> DataFrame

Solve a polynomial system using msolve and parse the results into a DataFrame.

# Arguments
- `pol`: ApproxPoly object containing the polynomial approximation
- `x`: Variables for the polynomial system
- `f`: Original function for evaluating solutions
- `TR`: test_input object containing problem parameters
- `basis`: Type of basis (:chebyshev or :legendre) (default: :chebyshev)
- `threads`: Number of threads for msolve to use (default: 10)
- `verbose`: Whether to print debug information (default: false)
- `skip_filtering`: If true, skips the [-1,1] bounds filtering (default: false)

# Returns
- DataFrame containing the parsed solutions
"""
function solve_and_parse(
    pol::ApproxPoly,
    x,
    f::Function,
    TR::test_input;
    basis=:chebyshev,
    threads::Int=10,
    verbose::Bool=false,
    skip_filtering::Bool=false,
    kwargs...
)
    if verbose
        println("Starting solve_and_parse with ApproxPoly of degree $(pol.degree)")
        println("TR.dim = $(TR.dim)")
    end

    # First run msolve_polynomial_system and get the output file path
    output_file = msolve_polynomial_system(
        pol,
        x;
        n=TR.dim,
        basis=basis,
        threads=threads,
        verbose=verbose
    )

    if verbose
        println("Parsing results with skip_filtering = $skip_filtering")
    end

    # Then parse the results and get the DataFrame
    df = msolve_parser(output_file, f, TR; skip_filtering=skip_filtering)

    if verbose
        println("Parsing complete, DataFrame contains $(nrow(df)) rows")
    end

    return df
end