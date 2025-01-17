## To Do ##

- [X] Generate the figures for the examples --2D.
    - [X] Trefethen
    - [X] Deuflhard
    - [X] Gaussian Mixtures
    - [X] Holder Table 
- [X] Gaussian Mixture -- fix a pleasing configurations for repeat -- by visual inspection. 
- [ ] To compare with chebfun 2: export from matlab to `.csv` file and import a `.csv` file in Julia, we can use the `CSV` package, and then convert it to a `DataFrame`. `df = CSV.read("path/to/your/file.csv", DataFrame)` -- we should use it as ground truth for Trefethen 
- [ ] Generate the trefethen example on `5/12` ? Seems doable now. Maybe just with cheb? 
- [ ] The difficult example to build is to piece together a differential system example with subdivision of the domain and refinements ?
- [ ] Repeat error plots from Maple: 
  - [ ] the stats of the error and the distribution in  the flattened vector w(s)-f(s) as the number of samples increases at a fixed degree d. 
  - [ ] Plot histogram.
- [ ] Verify that Legendre deals properly with `BigInt` type for large degree $d$ --> got issues with msolve, and the issue persists with Homotopy Continuation too. 
- [ ] Transfer all examples to paper. 
- [ ] $n = 4$ case. We have the two copies of `camel3`. We need to have these points exactly: the function is polynomial. We could do that with chebfun2. If need be, we explain that why the error on the region of the critical points is not very accurate ? There is not that much variation in $z$ in the region of the critical points. 
- [ ]  Tensor of two Deuflhard functions. Might work better.

## what is done ##
- [X] In Matlab: reproduce the polynomial measurements --> L28 -- `objectives.mpl` 
 
 ## Methodology ##
To give an estimate of the error of approximation in the $L^2$-norm, we compute a Riemann sum over the grid of the approximation.
We consider $N$ points on the interval $[-1, 1]$ distributed according to the measure $\mu$ and the grid is obtained by taking the tensor product of these points. 
therefore the grid can be also viewed as a collection of rectangular cells (products of intervals) in $\R^n$.
The mid-point of each cell is used for the evaluation. 
$$
\left(\sum_{c\in G} vol_c^2 (f(x_c)-w_{d, \Ss}(x_c))^2 \right)
$$

It is hard to study all those criterions at the same time (number of samples, number of critical points in the objective, sensitivity to non-analyticity, to dimension, etc).
Therefore we break it down into individual examples. 
## For Higher Dimensions ## 
the code is in `Examples/cmpr.jl`.
Say we decided to mix two functions: 
$$
f(x) = f1(x_1, x_2) + f2(x_3, x_4)
$$
The respective critical points of`f1` and `f2` are stored in `df1` and `df2`. 
We tensor the two and create a `df_double` where each pair of critical points from `df1` and `df2` forms a row.
We then need a function that would take the `df_approx` we have computed and compare it with `df_double` to see if the critical points are close enough, up to some set tolerance.
The function would return `df_double` with a column of `True` or `False` values called `captured`.

We have the code in the `Examples/cpmr.jl` file. Now we need to create a couple of examples in 4d.

[]: what are the candidates for the examples?
- [ ] Mixture of 2D: Camel_3, Deuflhard 
- [ ] 
We have to be careful about over-fitting in these large dimensions. As the dimension grows, do does the accumulation of numerical errors. I don't know why things become slower or less accurate.

Explanation: for accumulation of error: Any error in the evaluation of a float will be magnified by the number of operations that are performed on it. 
Here we see our transformation method to and from orthogonal polynomials is not perfect. 
What's interesting is that degree is quite relatively low here, so we should find ways to make the linear algebra very well conditioned (or just much better conditioned).
Then next improvement would be on pruning the polynomial terms in the system that measure very close to $0$ in discrete $L^2$-norm. 
Maybe add a condition of having a small discrete $L^{\infty}$-norm too ? (what if polynomial describes a sort of spike at the edge of the domain ?). So statistics on the coefficients of the polynomial once it is in SMB... Is that some optimization on the linear algebra when we compute the polynomial system ? It's really prunning that has to happen in the standard monomial basis, to set terms equal to $0$.

## camel_4d Example ##
Should be a sparse approximant. In this case, we should benefit from all the advantages of the interpolation if we were to compare both construction methods (vs L.S.).
This error accumulates if evaluations of the polynomial system (a bit) but mostly visible on stability of critical points. 
We see what was expected theoretically: the larger a minima in $L^2$-norm, the easier it is to capture.
Here we have little variation in the center of the domain, plus large values of the boundary. Ratio of entries in sparse polynomial vs $\binom(n+d, d) =210$ in this case.
No need to venture here in how we would solve it. --> Is the trimming of terms small in discrete $L^2$-norm from the paragraph above is some Reproducing Kernel Hilbert Space (RKHS) property ?

## Deuflhard's 4d Example ##


## Deuflhard's Example ##
The smallest degree at which the procedure finds the $6$ global minimizers of $f$ is at $d=10$, but this is not what we would call a proper capture. "since the topology of the approximant is not matching that of the objective function". 

Q : What is the degree for proper capture? 
For a polynomial degree of 20, both Chebyshev and Legendre approximants successfully identify all 6 local minima with a precision of $3.5e-4$. When initiating local minimization on `f` at the critical points of these approximants, the method converges to each minimizer of f at least once. Additionally, we observe convergence to saddle points occurs in cases where the initial point lies sufficiently close to a critical point that the function's local geometry appears effectively flat to the optimization routine.


Set $d=12$ and $120^2$ samples for the grid, we obtain discrete Riemann sums of `.0.15858587551180692` and `0.13333680604026193` for the Chebyshev and Legendre approximants, respectively --> verify what degree we should measure this with. 
In either cases, we make consider that all local minima have been captured, because the optimization method `BFGS` has converged when initiated at each critical point of $w_{d, \Ss}$ to each of the 9 local minimizers--> actually it is
 
- [ ] middle: saddle + two local maxima
- [ ] sides: two very flat saddle points
- [ ] 6 local minimas    
 
From the location of the critical points, we can claim that Chebyshev captures the shape of `f` more accurately than Legendre in this example. 
 
The difference between the two types of polynomial approximants we observe is that the critical points of the approximant are captured up to precision $1e-2$ and with Legendre and $3e-3$ for Chebyshev. (meaning closest critical point of the approximant is within a ball of that radius around the critical point of the objective function) found by `BFGS()`. 

## Trefethen ##
The 100 digit challenge is succinctly stated: compute the global minimum of the function $f$ and refine the solution to a $100$ digits. 
In the present case, the uncaptured points that appear on the plot not in the vicinity of any of the local minimizers are numerical artifacts of the minimization routine. 
In this case, we compare with the critical points computed using `Chebfun2`. There is no direct way to isolate all local minimizers from them, we just return the collection of all critical points.

We work over the domain $[-3/8, 3/8]^2$, with $120^2$ samples. 
Chebfun2 in Matlab computes a total of $330$ critical points in the domain. With a polynomial approximant in Chebyshev basis of degree $38$, we are able to...

We compare with the outputs of Chebfun2, at a precision of $0.025$ if the points are matching.

Pushing the method beyond these degree stresses the construction of the approximant too, and the size of the coefficients just gets too large. We would require an additional level of optimization to improve the generation of the polynomial system and (at least a partial) simplification of the coefficients.

## Mixture of Gaussians ##
$N = 12$ Gaussians, each centered at random in $[-.8, .8]^2$, and standard deviation in...
We see some spurious critical points in the approximants, but we still capture 
- [X]: We need to set a fixed configuration to work with. 
- [ ]: Explain that functions such as mixtures of Gaussians that admit large "flat" sections can be challenging, since polynomial approximants will have a tendency to oscillate in these regions, and thus create a large number of spurious critical points. These in turn will impact the performance of the polynomial system solving happening in step 2.
We capture all 3 local minima at degree $d=24$ on $120^2$ sample points, both with Chebyshev and Legendre approximants, $err_cheb = 5.77e-2$, $err_lege = 5.50e-2$. But we have to go up to degree $34$ and $err_cheb = 0.019882472570469396$ to capture the "small" local maxima located in the middle at  

Observation: small fluctuations in the objective can easily be missed by the approximant.
Variance is set to `6/10 * rand()` where `rand()` is a float in `[0, 1]`. 
The centers are at least `0.2` apart.

## Holder Table ##

$d \simeq 20$ starts to get decent. 
We have to relax the numerical analysis standards of what we consider a "capture" of a critical point. For them $10^-4$ may be quite bad for a convergence criterion. 
Maybe we should plot where the Hessian of `f` is positive definite (how far around the critical point). 

Matlab generates a chebfun of rank $16$ and maximal degree in `x` and `y` (65536). The `roots` function computes all these critical points (displayed in figure), but we get numerical precision flags raised for each one of them. 


## Matlab with Polynomials ## 
We can compute the critical points of the bi-variate polynomials, no problem with that. 
We obtain approximants of sharp degree in each coordinate (8, 8), the approximants are of rank $9$. 

## General Obs ##
In the examples we have tested, the number of samples does not appear to be a limitation. 
Out main obstacle is always the binomial$(n+d, d)$ growth of the size of the basis of polynomials of degree at most $d$ in $n$ variables.

### BFGS ###
- [ ]:The local optimization method will converge to a saddle point if the neighborhood of that point is flat enough.
- []: The local optimization method will converge to a local minimum if the neighborhood of that point is convex enough.
- []: Last but not least, it is quite frequent that the polynomial approximant will admit critical points in regions where the objective function is difficult to operate with, especially in the context of running gradient-free optimization algorithms such as BFGS. In that case, the user may have to specify parameters for step 3, or, reiterate running the algorithm around the critical point at which the local minimization method has failed. 



