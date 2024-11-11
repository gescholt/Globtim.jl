What is to do: 

We want to use Legendre Polynomials to make the sampling grid uniform. 
We need a version of the Legendre polynomial that is easy to evaluate and that is normalized to be orthonormal with respect to the uniform distribution on the interval [-1, 1]. 

The other version returns exact coefficients of the Legendre polynomial; to be used for expanding the tensorized polynomial back into a monomial basis. 

[]: # ~ We should use the LegendrePolynomial Package, seems a pain to define recursively, need to get access to symbolic expansion of the coefficients. Maybe I could figure out what types to add to make it compatible with DynamicPolynomials.

[]: # ~ Construct the polynomial matrix using a Hadamard product of matrices constructed in each dimension. Dehomogenize the vector of monomials and evaluate that at all points. If the domain is completely symmetric, we could take advantage of that to further optimize. 

Why do we have an even number of sample columns ? 
K^n --> always divisible by K lol. 
3^3 = 27, we need z to appear at which instances ? Each dimensional layer is split by $K$. 
We can have a recursive function that takes in the current dimension and the current index and splits it into one more dimension 

What did break with Chebyshev sampling model? 
Should I run a notebook presentation tomorrow ?

1) Implement the Legendre Polynomial function using the dynamic Polynomial environment that will return:
Exact coefficient (rational) normalized Legendre polynomial of degree d in a `@polyvar x` variable. 

2) add a switch to work over Float64 vs BigFloat. The vandermonde like matrix is constructed in high precision but then truncated to Float64.