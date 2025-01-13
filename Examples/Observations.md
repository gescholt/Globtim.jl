## To Do ##

- [ ] Generate the figures for the examples --2D.
- [ ] Add Gaussian Mixture example to paper -- fix a pleasing configurations for repeat -- by visual inspection. 
- [ ] To compare with chebfun 2: export from matlab to `.csv` file and import a `.csv` file in Julia, we can use the `CSV` package, and then convert it to a `DataFrame`. `df = CSV.read("path/to/your/file.csv", DataFrame)` -- we should use it as ground truth for Trefethen 
- [ ] Generate the trefethen example on `5/12` ? Seems doable now. Maybe just with cheb? 
- [ ] The difficult example to build is to piece together a differential system example with subdivision of the domain and refinements ?
- [ ] Repeat error plots from Maple: 
  - [ ] the stats of the error and the distribution in  the flattened vector w(s)-f(s) as the number of samples increases at a fixed degree d. 
  - [ ] Plot histogram.
- [ ] Verify that Legendre deals properly with `BigInt` type for large degree $d$ --> got issues with msolve, and the issue persists with Homotopy Continuation too. 

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

## Deuflhard's Example ##
The smallest degree at which the procedure finds all the local minimizers of $f$ is $d=10$, but this is not what we would call a proper capture. "since the topology of the approximant is not matching that of the objective function". 
Indeed, the local minimization method initiated at the critical points of the approximants just happens to converge at least once to every minimizer of $f$.
We have to go up to degree $d=20$ for $w_{d, \Ss}$ to admit at least one critical point within a ball of radius $1$ around each of the local minimizers of $f$.
At that degree, we observe that the topography of the polynomial approximant matches the objective function's, (meaning their contour plots look the same). 

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

## Mixture of Gaussians ##
$N = 12$ with centers chosen at random in $[-.8, .8]$ and standard deviation in...
We see some spurious critical points in the approximants, but we still capture 
- [ ]: We need to set a fixed configuration to work with. 
- [ ]: Explain that functions such as mixtures of Gaussians that admit large "flat" sections can be challenging, since polynomial approximants will have a tendency to oscillate in these regions, and thus create a large number of spurious critical points. These in turn will impact the performance of the polynomial system solving happening in step 2.

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



