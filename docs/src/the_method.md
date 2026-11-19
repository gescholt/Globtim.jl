# The method

This page states what Globtim computes, what is proved about it, and which parts of
the pipeline lie outside the proof. The code that runs each step is on
[Core Algorithm](core_algorithm.md).

## Setting

Let ``K = \prod_{i=1}^{n} [a_i, b_i] \subset \mathbb{R}^n`` be a box and
``f : K \to \mathbb{R}`` a function that can be evaluated at any point of ``K``,
possibly up to an error of size ``\eta``. Nothing else is assumed available: no
formula, no gradient. The box is mapped affinely onto ``[-1, 1]^n``, and everything
below is written on ``[-1, 1]^n``.

A point ``x`` is a *critical point* of ``f`` if ``\nabla f(x) = 0``. The aim is the
set ``\operatorname{lmin}(f)`` of all local minimizers of ``f`` in the interior of
``K``, and more generally the critical points of ``f`` in ``K`` with their Morse
indices.

## The approximant

Let ``\mathcal{P}_{n,d}`` be the space of real polynomials in ``n`` variables of total
degree at most ``d``; it has dimension ``D = \binom{n+d}{n}``. Given a finite sample
set ``S \subset [-1,1]^n`` with ``k`` points, the *discrete least-squares approximant*
of ``f`` of degree ``d`` on ``S`` is

```math
w_{d,S} \;=\; \operatorname*{arg\,min}_{w \in \mathcal{P}_{n,d}} \;
\Big( \frac{1}{k} \sum_{s \in S} \big( w(s) - f(s) \big)^2 \Big)^{1/2} .
```

It is unique as soon as ``S`` contains ``D`` points in general position. Globtim
computes ``w_{d,S}`` in an orthogonal basis (Chebyshev by default, Legendre on
request); `Constructor(TR, d)` returns it.

The number `pol.nrm` that `Constructor` reports is the size of the residual
``f - w_{d,S}`` on the sample set: the discrete ``L^2`` norm over ``S`` with the
quadrature weights of the chosen basis. For the Chebyshev basis this is the
quadrature value, on the sample grid, of the norm

```math
\| g \|_{L^2(\mu)} = \Big( \int_{[-1,1]^n} g(x)^2 \, d\mu(x) \Big)^{1/2},
\qquad
d\mu(x) = \prod_{i=1}^n \frac{dx_i}{\sqrt{1 - x_i^2}} ,
```

which is the norm of the theorem below. `relative_l2_error(pol)` divides it by the
same norm of ``f``. Both measure the fit *at the samples*; neither is a bound on
``\sup_K |f - w_{d,S}|`` or on the error of the gradient.

## The critical system

The critical points of the approximant are the real solutions in the box of

```math
\nabla w_{d,S}(x) = 0 ,
```

a system of ``n`` polynomial equations of degree ``d - 1`` in ``n`` unknowns. When
its complex solutions are isolated there are at most ``(d-1)^n`` of them (Bézout's
bound), and they can all be computed: numerically by homotopy continuation
([HomotopyContinuation.jl](https://www.juliahomotopycontinuation.org/)), or
symbolically with [msolve](https://msolve.lip6.fr/). This is the step no local method
has: it returns every critical point of ``w_{d,S}``, not the one nearest to a starting
guess.

Isolated solutions are the generic case, not a certainty. A fit that does not depend
on one of the variables, for instance, has a non-isolated critical set; homotopy continuation
then ends on singular solutions and the list it returns is not complete.

## Back to ``f``

A critical point of ``w_{d,S}`` is a *candidate*: a point where ``f`` may have a
critical point nearby. Each candidate inside the box is handed to a local method that
works on ``f`` itself. The method is a parameter of the pipeline (Nelder–Mead by
default in `analyze_critical_points`; gradient-based refiners in
GlobtimPostProcessing).

What the package returns, and what should be reported, is the set of *verified
critical points*: points in the interior of the box at which the gradient of ``f``
vanishes to a stated tolerance and the Hessian of ``f`` is nondegenerate, together
with the *displacement* of each, the distance between the candidate and the point it
was refined to. Several candidates may refine to one point, and a candidate may refine
to nothing; the count of verified points and their displacements are read together.

## What is proved

The guarantee is Theorem 1 of [safeyeldin2026probabilistic](@citet). Its setting:

- ``f`` is a *Morse function* of class ``C^m`` on ``K``: all its critical points lie
  in the interior of ``K`` and have a nondegenerate Hessian. Such a function has
  finitely many critical points.
- ``\lambda > 0`` is a lower bound for every eigenvalue of the Hessian of ``f`` at
  every local minimizer.
- ``\kappa > 0`` bounds the differentials of ``f`` up to order ``m``:
  ``\max_{x \in K} \| d^j f(x) \| \le \kappa`` for ``1 \le j \le m``.
- A finite set ``G`` *captures* ``\operatorname{lmin}(f)`` at precision
  ``\varepsilon`` if every local minimizer of ``f`` lies within ``\varepsilon`` of a
  point of ``G``. A polynomial ``w`` captures ``\operatorname{lmin}(f)`` if it has
  finitely many critical points and ``\operatorname{lmin}(w)`` captures
  ``\operatorname{lmin}(f)``.

**Theorem.** Let ``\beta = \ln 3 / (2 \ln 2) \approx 0.79``, let
``m \ge \max(3, \beta n + 1)`` be an integer, and let ``\varepsilon > 0`` satisfy
``\kappa \varepsilon \le 3 \lambda``. Let ``f`` be as above, evaluated with error at
most ``\eta``, and let ``\alpha \in (0,1)``. There are explicit constants ``A_1`` and
``A_2``, depending on ``n``, ``m``, ``\kappa`` and a free parameter
``\delta \in (0,1)``, such that if the degree ``d \ge 2`` satisfies

```math
\Big( \frac{A_1}{d^{\,2m-2}} + A_2 \, \eta^2 \Big) \, d^{\,2 \beta n}
\;\le\; \lambda^2 \varepsilon^4 ,
```

then for a set ``S`` of ``k`` points drawn independently from the measure ``\mu``,
with

```math
\frac{k}{\ln k + \ln (4/\alpha)} \;\ge\; \frac{2 D^{2\beta}}{\delta^2} ,
```

the approximant ``w_{d,S}`` captures ``\operatorname{lmin}(f)`` at precision
``\varepsilon`` with probability greater than ``1 - \alpha``.

The constants ``A_1`` and ``A_2`` are written out in the paper; they are not
reproduced here. Three consequences of the statement:

- The degree needed grows like a power of ``1/\varepsilon``, and the exponent improves
  with the smoothness ``m``; halving ``\varepsilon`` multiplies the degree by a factor
  independent of ``n``.
- The evaluation error must shrink with the degree, ``\eta \lesssim \lambda
  \varepsilon^2 / d^{\beta n}``: a noisy ``f`` limits the degree that is useful.
- The number of samples ``k`` grows polynomially in ``D``; it does not have to exceed
  ``D`` by an order of magnitude.

## What the proof covers, and what the package does

| Step | In the theorem | In the package |
| :-- | :-- | :-- |
| Function | Morse, of class ``C^m``; ``\lambda`` and ``\kappa`` known | anything that can be evaluated; ``\lambda`` and ``\kappa`` unknown |
| Samples | ``k`` independent draws from ``\mu`` | tensor Chebyshev grid, `GN + 1` nodes per axis (default); scattered or Christoffel-weighted samples |
| Degree | fixed by ``\kappa``, ``\lambda``, ``\varepsilon``, ``\eta`` | chosen by the user, or raised until the reported error stops improving |
| Critical points | all of them, assumed computed | homotopy continuation (a path can fail, see [Solvers](solvers.md)) or msolve |
| Conclusion | minimizers of ``w`` capture those of ``f`` | candidates, each refined and checked on ``f`` |
| Boundary | none: critical points are interior | boundary minima occur; `box_strata_census` counts them |

Because ``\lambda`` and ``\kappa`` are not known for a function given by evaluations,
the theorem is used as a statement about the regime in which the method works, not as
a certificate for a particular run. What certifies a particular run is the row
"Conclusion": each returned point is checked on ``f``. That check establishes that the
returned points are critical points of ``f``. It does not establish that none is
missing; completeness of a run rests on the fit being accurate enough, which the
reported error indicates and does not prove.
