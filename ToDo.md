What is to do: 

[]: # ~ Make a local git repo on MPI gitlab.

[]: # ~ Explore connections to spectral methods. 

[]: # ~ Construct the polynomial matrix using a Hadamard product of matrices constructed in each dimension. Dehomogenize the vector of monomials and evaluate that at all points. If the domain is completely symmetric, we could take advantage of that to further optimize.


What has been done: 

[]: Legendre polynomials for uniform sampling grid. (Normalized ?)

[]: Chebyshev polynomials for best construction of stable polynomial approximant.


Old stuff: []: # ~ We should use the LegendrePolynomial Package --> didn't do that in the end. It seems too numerical in its approach. Make it compatible with DynamicPolynomials. 
2) Add a switch between Float64 vs BigFloat. The Vandermonde-like matrix is constructed in high precision but then truncated to Float64.