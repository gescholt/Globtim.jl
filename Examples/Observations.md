## To Do ##

- [X] Generate the figures for the examples --2D.
    - [X] Trefethen
    - [X] Deuflhard
    - [X] Gaussian Mixtures
    - [X] Holder Table 
- [X] Gaussian Mixture -- fix a pleasing configurations for repeat -- by visual inspection. 
- [X] To compare with chebfun 2: export from matlab to `.csv` file and import a `.csv` file in Julia, we can use the `CSV` package, and then convert it to a `DataFrame`. `df = CSV.read("path/to/your/file.csv", DataFrame)` -- we should use it as ground truth for Trefethen 
- [X] Generate the trefethen example on `3/8` ? Seems doable now. Maybe just with cheb? 
- [ ] The difficult example to build is to piece together a differential system example with subdivision of the domain and refinements ?
- [ ] Repeat error plots from Maple: 
  - [ ] the stats of the error and the distribution in  the flattened vector w(s)-f(s) as the number of samples increases at a fixed degree d. 
  - [ ] Plot histogram.
- [ ] Verify that Legendre deals properly with `BigInt` type for large degree $d$ --> got issues with msolve, and the issue persists with Homotopy Continuation too. 
- [ ] Transfer all examples to paper. 
- [ ] $n = 4$ case. We have the two copies of `camel3`. We need to have these points exactly: the function is polynomial. We could do that with chebfun2. If need be, we explain that why the error on the region of the critical points is not very accurate ? There is not that much variation in $z$ in the region of the critical points. 
- [X]  Tensor of two Deuflhard functions. Might work better.

## what is done ##
- [X] In Matlab: reproduce the polynomial measurements --> L28 -- `objectives.mpl` 

 
## In Paper ## 
- [X] Methodology: explain discrete $L^2$-norm. 
- [] Trefethen:
  - [] 100 Digit Challenge 
  - [X] add figures
  - [] add description and challenges 
  - [] add error measurements 
- [] Deuflhard:
  - [X] add figures
  - [] make a noisy version
  

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
The objective `f` is sparse. The approximant should be sparse too in order to work well. In this case, we should benefit from all the advantages of the interpolation if we were to compare both construction methods (vs L.S.).
This error accumulates if evaluations of the polynomial system (a bit) but mostly visible on stability of critical points. 
We see what was expected theoretically: the larger a minima in $L^2$-norm, the easier it is to capture.
Here we have little variation in the center of the domain, plus large values of the boundary. Ratio of entries in sparse polynomial vs $\binom(n+d, d) =210$ in this case.
No need to venture here in how we would solve it. --> Is the trimming of terms small in discrete $L^2$-norm from the paragraph above is some Reproducing Kernel Hilbert Space (RKHS) property ?

## Deuflhard's Example ##
The topography of the function is quite interesting:
- [ ] middle: saddle + two local maxima
- [ ] 6 local minimas, all separated by saddle points.
We can consider this example from two aspects: 
- [X] The approximate version of the problem, where we only really care about the most prominent features of the function. (low degree approximant)
- [X] The exact structure of the function, finding exactly all critical points. of the function. (high degree approximant). 

The smallest degree at which the procedure finds the $6$ global minimizers of $f$ is at $d=8$, but this is not what we would call a proper capture. since the topology of the approximant is not matching that of the objective function.
What we mean by that is we only capture the most prominent features of the function, which are the local minima, not the two relatively small local maximizers at the center of the domain. 
On the other hand, the 3 "wells" around the local minima are less prominent features of the objective.
The central peak is easiest to capture, followed by the two saddle points, and then the $6$ local minima (3 on either side).

Q : What is the degree for proper capture? 
For a polynomial degree of 20, both Chebyshev and Legendre approximants successfully identify all 6 local minima with a precision of $3.5e-4$. When initiating local minimization on `f` at the critical points of these approximants, the method converges to each minimizer of f at least once. Additionally, we observe convergence to saddle points occurs in cases where the initial point lies sufficiently close to a critical point that the function's local geometry appears effectively flat to the optimization routine.


Set $d=8$ and $120^2$ samples for the grid, we obtain discrete Riemann sums of `0.8446502489319311` and `0.7018343255811541` for the Chebyshev and Legendre approximants, respectively. 
Set $d=20$ and $120^2$ samples for the grid, we obtain discrete Riemann sums of `1.1237794187711824e-4` and `9.409131839401895e-5` for the Chebyshev and Legendre approximants, respectively.
In either cases, we make consider that all local minima have been captured, because the optimization method `BFGS` has converged when initiated at each critical point of $w_{d, \Ss}$ to each of the 9 local minimizers (those are rather 8 extrema)--> actually it is
From the location of the critical points, we can claim that Chebyshev captures the shape of `f` more accurately than Legendre in this example. 
 
The difference between the two types of polynomial approximants we observe is that the critical points of the approximant are captured up to precision $1e-2$ and with Legendre and $3e-3$ for Chebyshev. (meaning closest critical point of the approximant is within a ball of that radius around the critical point of the objective function) found by `BFGS()`. 

## Deuflhard's 4d Example ##
`center = [0.5, -0.5, 0.5, -0.5]`, with `scale_factor = 3/5`. 
In the 2D case, we needed to go up to degree $d=20$ to capture all the critical points.
In 4D, we are encountering the same issue as we the `camel_4d` example --> not exactly. 
We first try with degree $d=6$.  
we have a loss of precision in the approximant. The way the function is constructed, there should be no cross terms $x_1x_3, x_1x_4, x_2x_3, x_2x_4$. 
we take $f(x) = deufl(x_1, x_2) + deufl(x_3, x_4)$. 
$N = 4$, all $9$ local minimas,  
Chebyshev captures at precision `.25` 
Legendre captures at precision `.3`
`pol_cheb.nrm = 1.038820420775381`, `pol_lege.nrm = 1.5807977980223133`
$N = 6$, all $9$ local minimas,  
Chebyshev captures at precision `.09` 
Legendre captures at precision `.09`
`pol_cheb.nrm = 1.488797779150016` and `pol_lege.nrm = 2.2935077238843333`

We then go up to degree $8$ and $N=10$ samples. 
For homotopy continuation, we have to track 2401 paths. [here it finds a good use, because it speeds up experimental procedures.]
With chebyshev we found 91 critical points, with Legendre we found 81 critical points, in either cases, we capture all 9 local minimas at precision `2e-2`. 

How close are we to the points we have computed with Chebfun (tensor the 2d example and compare-- something with the code needs to be checked). 

Now we try with range of $6/5$ and center back at the origin. 
There is a total of $36$ local minima, we would like to capture all of them.
The optimization method finds more points at which it converges, but as we have seen in lower dimensional examples, that does not mean there is a local minimum there.



In terms of sampling or even increasing the degree, there doesn't seem to be a way to increase the precision, unless we change the way the approximant is constructed.

## Trefethen ##
Q1 : 
- [X]: What is the 100 digit challenge: The 100 digit challenge is succinctly stated: compute the global minimum of the function $f$ and refine the solution to a $100$ digits. 
- [X]: What do we obtain when compared to Chebfun2 on $[-3/8, 3/8]^2$, with $f$ evaluated at $14400=120^2$ samples.
- [] Chebfun2 in Matlab computes a total of $330$ critical points in the domain.
- []: What is the degree at which we capture all the critical points of the function. By the nature of the function `f`, we can expect multiple local minimizers and maximizers, hence an approximant of high degree and small $L^2$-norm approximation error is required to capture all of them.
- []: Note that restricting the domain to $[-1/4, 1/4]^2$ is a relatively easy example comparatively. 

We work over the domain $[-3/8, 3/8]^2$, with $f$ evaluated at $14400=120^2$ samples. The motivation for this example is to showcase the ability of `globtim` to capture a large number of local minimizers on an objective function with a complicated pattern of level sets, meaning the critical points spread out over the domain in an irregular pattern and a wide range in the magnitudes and width of the local extrema.
We compare the outputs of our computations with Chebfun2 at different tolerance levels, which itself constructs a rank $4$ polynomial tensor of degree $53$ in $x_1$ and degree $403$ in $x_2$. The critical points of the approximant are then computed through numerical methods, which can deal pretty well with solving high degree polynomial systems in dimension $n=2$. We use the points constructed by Chebfun2 as a ground truth to compare with the critical points of the approximant because they are constructed with a very small approximation error in $L^{\infty}$.

We execute the `globtim` algorithm construction of an approximant in the Chebyshev tensorized polynomial basis at degree `d= 34, 36, 40`, and compare the computed critical points of the approximant using `Msolve`. We observe that the approximation performs well at capturing the "big" local minimizers of the function, but struggles with the "small" local minimizers. The strip $0.1\leq x_1\leq 0.25$ is particularly challenging, as the function's fluctuations are much smaller in magnitude.

Pushing the method beyond these degree stresses the construction of the approximant too, and the size of the coefficients just gets too large. We would require an additional level of optimization to improve the generation of the polynomial system and (at least a partial) simplification of the coefficients.
- `d=34`, the discrete $L^2$-norm of the approximation error is $0.31213238502738494$
- `d=36`, the discrete $L^2$-norm of the approximation error is $0.21699482585160806$.
we find 317 critical points.  Comparison Summary:
Total points analyzed: 75
Points captured with Optim step: 72
Points matching Chebfun2: 73
Points both captured and matching: 71"
- `d= 40` the discrete $L^2$-norm of the approximation error is $0.07698624195711666$. Computed $290$ critical points.
Comparison Summary:
Total points analyzed: 74
Points captured with Optim step: 72
Points matching Chebfun2: 72
Points both captured and matching: 71

Shallow local minimizers are difficult to capture. 

- [X]: At what tolerance should we consider the critical points to be captured ? Critical points at a tolerance $5e-3$. 
- [X]: for the local minimizers returned by the `Optim` package in Julia, we consider a smaller tolerance, as these points have been "refined", so we set the tolerance to $1e-3$. 
- [X]: Observation: the the minimization routine depends on parameters of convergence. If the magnitude of the gradient in the vicinity of a critical point of $f$ is small, the optimization routine may find a minimizers there, when it actually is a saddle point. We observe a couple of these cases in our examples. 

- At degree $32$, it seems we capture all the local minimizers, by visual inspection --> more level sets. At `tol_dist=.015`, we seem to be capture all local minimizers found using optim. Now then we should compare  with Chebfun2 at the same precision just with the critical points.  
- At degree $40$, what are the precision at which we capture (is it all homotopy continuation ?)
-  We construct the approximants in Big arithmetic, we take little consideration about the huge sizes of the coefficients. So the compute times are pretty bad. 




At this scale, it is not necessary to classify all critical points returned by chebfun. 
If we only consider the local minimizers we found with step 3 of the algorithm, we see a partial picture. 
We may be missing some local minimizers (with relatively small measure locally -- or small radius of convergence for gradient descent).
The only Globtim points (in blue) are interesting, because it seems Chebfun2 has missed them, there is no


we are able to visually identify the local minimizers of the function, and we can see that the approximant captures all of them.

We also notice some of the `Optim` output points appear far from any of the local minimizers. These are numerical artifacts of the optimization method, if the gradient of the objective is very small in the vicinity of where the routine was initiated, it may terminate there. That is why we can find at times some saddle points in the output of the optimization routine.  


Pushing the method beyond these degree stresses the construction of the approximant too, and the size of the coefficients just gets too large. We would require an additional level of optimization to improve the generation of the polynomial system and (at least a partial) simplification of the coefficients.
- `d=34`, the discrete $L^2$-norm of the approximation error is $0.31213238502738494$
- `d=36`, the discrete $L^2$-norm of the approximation error is $0.21699482585160806$.
we find 317 critical points.  Comparison Summary:
Total points analyzed: 75
Points captured with Optim step: 72
Points matching Chebfun2: 73
Points both captured and matching: 71"
- `d= 40` the discrete $L^2$-norm of the approximation error is $0.07698624195711666$. Computed $290$ critical points.
Comparison Summary:
Total points analyzed: 74
Points captured with Optim step: 72
Points matching Chebfun2: 72
Points both captured and matching: 71

Shallow local minimizers are difficult to capture. 

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



