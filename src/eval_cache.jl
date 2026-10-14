# eval_cache.jl
#
# Memoising wrapper for expensive objectives.
#
# `MainGenerate` evaluates the objective on the full tensor grid every time `Constructor`
# runs; `TestInput` stores no values. In a degree sweep with fixed `GN` the grid is the
# same `(GN+1)^n` point set at every degree (the nodes are regenerated bit-identically
# from `cos((2i+1)π/(2GN+2))`), so a 4 → 16 sweep evaluates an ODE objective thirteen
# times on identical points. Wrapping the objective in a `CachedObjective` turns every
# evaluation after the first degree into a dictionary lookup.
#
# Keys are the exact Float64 coordinates handed to the objective (after the box → physical
# affine map), so two calls hit the same entry iff they are bit-identical. Nearby but not
# identical points (a different GN, a Christoffel draw, a refinement step) are misses,
# which is the correct behaviour for a cache that must never change a computed value.
#
# ForwardDiff duals bypass the cache (the gradient fit and the Hessian classifier call the
# objective with Dual inputs); the cache stores Float64 values only.

"""
    CachedObjective(f)

Memoising wrapper around a 1-argument objective. `f` is called with the same argument
it would have received without the wrapper (a `Vector`/`SVector` of Float64, or a scalar
for 1-D problems); its Float64 result is stored under the bit-exact key and returned on
every later call with the same argument. Thread-safe: lookups and inserts hold a lock,
evaluations of `f` run outside it so a threaded fit still fans out.

Inputs whose element type is not `Float64` (ForwardDiff duals, BigFloat) are forwarded
to `f` uncached.

See [`cache_stats`](@ref), [`clear_cache!`](@ref).

# Example
```julia
cached = CachedObjective(expensive_ode_misfit)
TR = TestInput(cached; dim = 3, center = c, GN = 12, sample_range = r)
for d in 4:2:12
    pol = Constructor(TR, d)        # objective evaluated once, at d = 4
end
cache_stats(cached)                 # (hits = 4*13^3, misses = 13^3, size = 13^3)
```
"""
mutable struct CachedObjective{F}
    f::F
    cache::Dict{Vector{Float64},Float64}
    lock::ReentrantLock
    hits::Int
    misses::Int
end

CachedObjective(f) = CachedObjective{typeof(f)}(f, Dict{Vector{Float64},Float64}(), ReentrantLock(), 0, 0)

_cache_key(x::AbstractVector{Float64}) = Vector{Float64}(x)
_cache_key(x::Float64) = Float64[x]

function _cached_call(c::CachedObjective, key::Vector{Float64}, x)
    lock(c.lock)
    cached = get(c.cache, key, nothing)
    if cached !== nothing
        c.hits += 1
        unlock(c.lock)
        return cached
    end
    c.misses += 1
    unlock(c.lock)

    v = Float64(c.f(x))   # evaluated outside the lock; a concurrent duplicate is harmless

    lock(c.lock)
    c.cache[key] = v
    unlock(c.lock)
    return v
end

(c::CachedObjective)(x::AbstractVector{Float64}) = _cached_call(c, _cache_key(x), x)
(c::CachedObjective)(x::Float64) = _cached_call(c, _cache_key(x), x)
# Duals, BigFloat, Rational inputs: no caching, exact passthrough.
(c::CachedObjective)(x::AbstractVector) = c.f(x)
(c::CachedObjective)(x::Real) = c.f(x)

"""
    cache_stats(c::CachedObjective) -> NamedTuple

`(hits, misses, size, hit_rate)` since construction or the last [`clear_cache!`](@ref).
"""
function cache_stats(c::CachedObjective)
    lock(c.lock)
    s = (
        hits = c.hits,
        misses = c.misses,
        size = length(c.cache),
        hit_rate = c.hits + c.misses == 0 ? 0.0 : c.hits / (c.hits + c.misses),
    )
    unlock(c.lock)
    return s
end

"""
    clear_cache!(c::CachedObjective)

Drop every stored value and reset the counters.
"""
function clear_cache!(c::CachedObjective)
    lock(c.lock)
    empty!(c.cache)
    c.hits = 0
    c.misses = 0
    unlock(c.lock)
    return c
end

original_objective(c::CachedObjective) = c.f
