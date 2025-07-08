We now attempt a problem that can't be directly solved with current implementations. We merge two copies of the Deuflhard function, $f(x)= f(x_1,x_2) + f(x_3, x_4)$. 
As we recall from Example, the geometry of the local minimizers of this function is relatively complicated and requires a high degree approximant to be captured. 
One may rightfully assume that the polynomial expansion of the objective could be expected to be sparse, as we have no reason for `x1x3, x1x4, x2x3, x2x4` terms to arise. Yet the polynomial approximant we construct is always of full support due to the numerical nature of the construction. 
For the moment, we do not support adaptive subdivision, but in this case, the domain would be too large and require to construct and approximant too large in degree, that would be challenging to maintain accuracy in the numerical part and would be of too high degree to solve the polynomial system of partials. 

Because we are not able to efficiently construct accurate polynomial approximations of such high degree appproximant without spending too long computing, we choose to reduce the domain to `([0,1]\times[-1,0])^2`. This domain contains 9 local minimizers of the function. 
We subdivide that region even further and work with a lower degree approximant. 
We subdivide this domain even further by cutting it into 16 subdomains, each of which is a square of  side length `0.5`. 

We run a routine relatively similar to the 2d case, we iteratively increase the degree of the polynomial approximant and we collect all the critical points we compute (by degree) by going over all the subdomains.

The plots we have:
_ convergence of polynomial approximant in L2-norm by degree `v4_l2_convergence.png`
_ convergence of critical points of `w_d` towards the critical points of the original function `v4_distance_convergence` 

_ the convergence curve for the critical points in each subdomain. 