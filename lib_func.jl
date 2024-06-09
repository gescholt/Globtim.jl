## Library of functions to approximate ##

# Define the function
alpine = (x) -> abs(x[1] * sin(x[1]) + 0.1 * x[1]) + 
               abs(x[2] * sin(x[2]) + 0.1 * x[2]) + 
               abs(x[3] * sin(x[3]) + 0.1 * x[3])


# Define the Schubert function
function schubert(xx)
    x1 = xx[1]
    x2 = xx[2]

    sum1 = sum(ii * cos((ii + 1) * x1 + ii) for ii in 1:5)
    sum2 = sum(ii * cos((ii + 1) * x2 + ii) for ii in 1:5)

    return sum1 * sum2
end

# Example usage
x = [1.0, 2.0, 3.0]
result = alpine(x)
println("Result: $result")

xx = [1.0, 2.0]
result = schubert(xx)
println("Result: $result")