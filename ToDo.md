<!-- What is to do for Globtim Paper: -->

[X]: # ~ Make a local git repo on MPI gitlab.

[]: # ~ Explore connections to spectral methods.

[]: # ~ Construct the polynomial matrix using a Hadamard product of matrices constructed in each dimension. Dehomogenize the vector of monomials and evaluate that at all points. If the domain is completely symmetric, we could take advantage of that to further optimize.

## For the Numerical Algebraic Geometry Presentation ##

Fun stuff: test Trefethen 3d with over-sampled grid


Structure: 
1) state of the art: Chebfun 
2) Go up to construction of a Holder function --> huge degree 
3) Start with the Chebfun plot of Holder. 
4) L^2 norm vs L^{infty} norm
5) Our strategy

6) What they work with: Chebyshev Polynomials: 
    - visual slides standard monomials vs Chebyshev polynomials
    - Lit. and stuff to explore
7) Introduce Regularity Conditions (C1) & (C2) 
8) Our theorem:
    - Theorem: State. How to illustrate $(\lambda, r)$ --> 1d function image is enough (did we have that already?)
    - Numerical example: Do we want $L^{infty}$ next to distance of critical points ?
    - Lagrange 2 orbits of JWST is a saddle point of effective potential. 
9) What has been done with Least Squares - Cohen Milgio 
10) Quick description of probabilities:
 - what happens when we remove points.  
   
11) 3D example: Trefethen 3D [end]

Problem: too much notation to introduce. Use $\err_d$ ?


- Making slides:
    - [X]: Make intro slide with lab logos
    - [X]: grant number.
    - []: We need some 2d visuals too. Plot polynomial surfaces `gen_fig.jl`
    - []: Scatter plot of points distributed according to the density function of $\mu$.
    - [X]: 1D example of why Chebyshev polynomials are best basis ?
    - []: Some of the measurements from paper
    - []: Add results graphs from paper.
    - [X]: Clean-up biblio
  - For Later:
    - []: Differential equations.
- Coding:
    - []: We have a plots for talk file `TALK_3d`
    - []: The augmented samples do something weird, but they are added around the critical point --> maybe just put less of them ?
    - []: we need to re-test the differential parameter estimation.
- []: Video animation of Trefethen 3D: For that I need: 
    - []: We are not correctly increasing the size of the sample grid. 
    - []: I thought we already had something efficient to augment the samples per level set, maybe the slider implementation is just much easier... 
    - []: In the end, I just want the Makie plot with the slider moving really slowly and a bit of rotation and output the result of that --->  as a video. 

- []: some 3d animations of figures. (instead of level sets). Only needs to be generated for 1 degree --> fast. But haven't figured out how to make video yet. 
- []: It would be nice to augment the number of samples around the critical points. 
- I think a good idea for that is to over sample around the points where we have identified critical points. Have a flag to do or not do that. 
- We need a picture (color gradient one) for the density function for $\mu$, and how it appears as samples (scatter plot)
- Questions of grids versus make them giggle a bit --> portray as random. 
- Dynamical Systems 

* Add mention of the use of large deviation theory for the probabilistic results of Cohen & Miglioratti 
* Going backwards: from perfect approximant, how likely is $w__{d, \Ss$ going to get worse as we reduce the size of the sample set. 
* It’s a connection between how the L^2 norms of each element of the basis is spread out through the domain and the measure $\mu$. That’s why chebyshev is relatively nice: You can use a definition, or precision of "density of points" that is reasonable on most of the domain but slightly more on the boundary: Makes sense. 
* 

What has been done: 

[X]: Legendre polynomials for uniform sampling grid. (Normalized ?)

[X]: Chebyshev polynomials for best construction of stable polynomial approximant.

[?]: Add a switch between Float64 vs BigFloat. The Vandermonde-like matrix is constructed in high precision but then truncated to Float64.

Old stuff: []: # ~ We should use the LegendrePolynomial Package --> didn't do that in the end. It seems too numerical in its approach. Make it compatible with DynamicPolynomials. 