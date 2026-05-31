# basis_comparison.jl
# Chebyshev vs Legendre — node distribution and approximation convergence
# on the 1D Runge function 1 / (1 + 25 x^2) over [-1, 1].
#
# Run with:
#   julia --project=profiles/viz pkg/globtim/examples/basis_comparison.jl
#
# Output: pkg/globtim/docs/src/assets/basis_comparison.png

using Globtim
using CairoMakie
using LinearAlgebra

const ASSET_DIR = abspath(joinpath(@__DIR__, "..", "docs", "src", "assets"))
isdir(ASSET_DIR) || mkpath(ASSET_DIR)

# Runge function — the canonical example where Chebyshev nodes beat uniform sampling.
runge_scalar(x) = 1.0 / (1.0 + 25.0 * x^2)
runge(x) = runge_scalar(x[1])

println("Computing Chebyshev / Legendre / uniform node distributions …")

n_nodes = 21
cheb_nodes = [cos(pi * k / (n_nodes - 1)) for k in 0:(n_nodes - 1)]
leg_nodes  = Globtim.legendre_nodes_exact(n_nodes, Float64)
uni_nodes  = collect(range(-1.0, 1.0; length = n_nodes))

# L2 error of an interpolating polynomial at given nodes,
# evaluated against runge_scalar on a dense quadrature grid.
function uniform_interp_l2_error(degree::Int)
    nodes = collect(range(-1.0, 1.0; length = degree + 1))
    fvals = runge_scalar.(nodes)
    V = [nodes[i]^j for i in 1:(degree + 1), j in 0:degree]
    coeffs = V \ fvals
    eval_p(x) = sum(coeffs[j + 1] * x^j for j in 0:degree)
    # Trapezoidal L2 norm on a dense grid
    M = 2001
    xs = range(-1.0, 1.0; length = M)
    h  = step(xs)
    diffs2 = [(eval_p(x) - runge_scalar(x))^2 for x in xs]
    integral = h * (sum(diffs2) - 0.5 * (diffs2[1] + diffs2[end]))
    return sqrt(max(integral, 0.0))
end

println("Sweeping polynomial degree for all three sampling schemes on Runge …")

degrees = collect(4:2:24)
TR = TestInput(runge; dim = 1, center = [0.0], GN = 200, sample_range = 1.0)

err_cheb = Float64[]
err_leg  = Float64[]
err_uni  = Float64[]
for d in degrees
    pol_c = Constructor(TR, d, basis = :chebyshev, precision = RationalPrecision)
    pol_l = Constructor(TR, d, basis = :legendre,  precision = RationalPrecision)
    e_uni = uniform_interp_l2_error(d)
    push!(err_cheb, pol_c.nrm)
    push!(err_leg,  pol_l.nrm)
    push!(err_uni,  e_uni)
    println("   degree $d:  Chebyshev ‖f−p‖₂ = $(round(pol_c.nrm, sigdigits=3)),  Legendre = $(round(pol_l.nrm, sigdigits=3)),  Uniform-interp = $(round(e_uni, sigdigits=3))")
end

println("Drawing figure …")

fig = Figure(size = (1180, 500), fontsize = 14)

# ─────────────────────────────────────────────────────────────────────
# Left panel: node distribution on [-1, 1]
# ─────────────────────────────────────────────────────────────────────
ax1 = Axis(fig[1, 1];
    title  = "Node distribution on [−1, 1]  (n = $n_nodes)",
    xlabel = "x",
    ylabel = "",
    yticks = ([1.0, 2.0, 3.0], ["Uniform", "Legendre", "Chebyshev"]),
    yticksvisible = false,
    yminorticksvisible = false,
)
xlims!(ax1, -1.15, 1.15)
ylims!(ax1, 0.4, 3.6)
hideydecorations!(ax1; ticklabels = false, label = false)

linesegments!(ax1, [(-1, 1.0), (1, 1.0)]; color = (:gray, 0.25), linewidth = 1)
linesegments!(ax1, [(-1, 2.0), (1, 2.0)]; color = (:gray, 0.25), linewidth = 1)
linesegments!(ax1, [(-1, 3.0), (1, 3.0)]; color = (:gray, 0.25), linewidth = 1)

scatter!(ax1, uni_nodes, fill(1.0, length(uni_nodes));
    color = :crimson, markersize = 13, marker = :xcross,
    strokecolor = :white, strokewidth = 0.8)

scatter!(ax1, leg_nodes, fill(2.0, length(leg_nodes));
    color = :darkorange, markersize = 13, marker = :diamond,
    strokecolor = :white, strokewidth = 1.0)

scatter!(ax1, cheb_nodes, fill(3.0, length(cheb_nodes));
    color = :steelblue, markersize = 13, marker = :circle,
    strokecolor = :white, strokewidth = 1.0)

text!(ax1, 0.0, 0.62; text = "evenly spaced — exhibits Runge phenomenon",
    align = (:center, :center), color = :crimson, fontsize = 10, font = :italic)
text!(ax1, 0.0, 3.4; text = "endpoint-clustered (cos(πk/n))",
    align = (:center, :center), color = :steelblue, fontsize = 10, font = :italic)

# ─────────────────────────────────────────────────────────────────────
# Right panel: log L2 approximation error vs degree
# ─────────────────────────────────────────────────────────────────────
ax2 = Axis(fig[1, 2];
    title  = "‖f − p_d‖₂  on Runge  f(x) = 1 / (1 + 25 x²)",
    xlabel = "Polynomial degree  d",
    ylabel = "L2 approximation error",
    yscale = log10,
    xticks = degrees,
)

lines!(ax2, degrees, err_uni; color = :crimson, linewidth = 2.5,
    label = "Uniform-node interpolation (Runge divergence)")
scatter!(ax2, degrees, err_uni; color = :crimson, markersize = 11, marker = :xcross)

lines!(ax2, degrees, err_cheb; color = :steelblue, linewidth = 2.5,
    label = "Chebyshev basis (Globtim default)")
scatter!(ax2, degrees, err_cheb; color = :steelblue, markersize = 11, marker = :circle)

lines!(ax2, degrees, err_leg; color = :darkorange, linewidth = 2.5, linestyle = :dash,
    label = "Legendre basis")
scatter!(ax2, degrees, err_leg; color = :darkorange, markersize = 11, marker = :diamond)

axislegend(ax2; position = :rt, framevisible = true, backgroundcolor = (:white, 0.92))

colsize!(fig.layout, 1, Relative(0.4))
colsize!(fig.layout, 2, Relative(0.6))

out = joinpath(ASSET_DIR, "basis_comparison.png")
CairoMakie.save(out, fig; px_per_unit = 2)

println("\nSaved: $out")
