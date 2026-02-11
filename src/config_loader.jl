"""
TOML Experiment Configuration Loader (Bead 70e)

Parses TOML config files into `ExperimentPipelineConfig` for use with
`run_standard_experiment()` and the Dynamic_objectives orchestrator.

This module lives in Globtim (no Dynamic_objectives dependency).
ODE-specific orchestration lives in Dynamic_objectives/src/globtim_integration.jl.

Created: 2026-02-09 (Bead 70e — Unified TOML Experiment Pipeline)
"""

# ═══════════════════════════════════════════════════════════════════════════════
# ExperimentPipelineConfig
# ═══════════════════════════════════════════════════════════════════════════════

"""
    ExperimentPipelineConfig

Flat configuration struct parsed from a TOML experiment file.
Maps directly to `run_standard_experiment()` args + catalogue integration.

# Sections (matching TOML layout)

- `[experiment]`: name, description
- `[model]`: catalogue_path + entry_name (ODE) OR analytical_function + dimension (built-in)
- `[domain]`: radius (symmetric) OR radii (anisotropic) OR bounds (explicit)
- `[polynomial]`: GN, degree_range, basis
- `[solver]`: ODE solver overrides (optional)
- `[refinement]`: post-processing refinement (optional)
- `[output]`: output_dir (optional)
"""
struct ExperimentPipelineConfig
    # [experiment]
    name::String
    description::String

    # [model] — exactly one mode: catalogue XOR analytical
    catalogue_path::Union{Nothing, String}
    entry_name::Union{Nothing, String}
    analytical_function::Union{Nothing, String}
    dimension::Union{Nothing, Int}

    # [domain] — exactly one mode: radius XOR radii XOR bounds
    radius::Union{Nothing, Float64}
    radii::Union{Nothing, Vector{Float64}}
    bounds::Union{Nothing, Vector{Tuple{Float64, Float64}}}

    # [polynomial]
    GN::Int
    degree_range::StepRange{Int, Int}
    basis::Symbol

    # [solver] — optional ODE overrides
    solver_method::Union{Nothing, String}
    solver_abstol::Union{Nothing, Float64}
    solver_reltol::Union{Nothing, Float64}
    solver_numpoints::Union{Nothing, Int}

    # [refinement] — optional post-processing
    refinement_enabled::Bool
    refinement_method::Union{Nothing, String}
    refinement_max_time::Union{Nothing, Float64}
    refinement_gradient_method::Union{Nothing, String}
    refinement_gradient_tolerance::Union{Nothing, Float64}

    # [analysis] — optional CP validation (Newton on ∇f=0, Hessian classification)
    analysis_enabled::Bool
    analysis_gradient_method::Union{Nothing, String}
    analysis_newton_tol::Union{Nothing, Float64}
    analysis_newton_max_iterations::Union{Nothing, Int}
    analysis_hessian_tol::Union{Nothing, Float64}
    analysis_dedup_fraction::Union{Nothing, Float64}

    # [output]
    output_dir::Union{Nothing, String}
end

# ═══════════════════════════════════════════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════════════════════════════════════════

const KNOWN_SOLVER_METHODS = Set([
    "Tsit5", "Vern7", "Vern9", "Rodas5", "Rosenbrock23",
    "AutoTsit5", "TRBDF2", "KenCarp4"
])

const KNOWN_REFINEMENT_METHODS = Set(["NelderMead", "BFGS"])

const KNOWN_GRADIENT_METHODS = Set(["forwarddiff", "finitediff"])

"""
    validate_experiment_toml(d::Dict)

Validate a parsed TOML dict before constructing ExperimentPipelineConfig.
Collects all errors and raises them together.
"""
function validate_experiment_toml(d::Dict)
    errors = String[]

    # --- Required sections ---
    haskey(d, "experiment") || push!(errors, "Missing required section [experiment]")
    haskey(d, "model")      || push!(errors, "Missing required section [model]")
    haskey(d, "polynomial")  || push!(errors, "Missing required section [polynomial]")

    # Bail early if required sections are missing — can't validate further
    if !isempty(errors)
        error("TOML validation failed:\n  " * join(errors, "\n  "))
    end

    exp = d["experiment"]
    mod = d["model"]
    poly = d["polynomial"]
    dom = get(d, "domain", Dict())
    sol = get(d, "solver", Dict())
    ref = get(d, "refinement", Dict())

    # --- [domain] mode flags (needed early for cross-validation) ---
    has_radius = haskey(dom, "radius")
    has_radii  = haskey(dom, "radii")
    has_bounds = haskey(dom, "bounds")
    n_domain_modes = count([has_radius, has_radii, has_bounds])

    # --- [experiment] ---
    haskey(exp, "name") || push!(errors, "[experiment] missing required field 'name'")

    # --- [model] mode validation ---
    has_catalogue = haskey(mod, "catalogue_path") || haskey(mod, "entry_name")
    has_analytical = haskey(mod, "analytical_function")

    if has_catalogue && has_analytical
        push!(errors, "[model] cannot specify both catalogue (catalogue_path/entry_name) and analytical_function")
    elseif !has_catalogue && !has_analytical
        push!(errors, "[model] must specify either catalogue_path+entry_name or analytical_function")
    elseif has_catalogue
        haskey(mod, "catalogue_path") || push!(errors, "[model] catalogue mode requires 'catalogue_path'")
        haskey(mod, "entry_name")     || push!(errors, "[model] catalogue mode requires 'entry_name'")
    elseif has_analytical
        haskey(mod, "dimension") || push!(errors, "[model] analytical mode requires 'dimension'")
        # Validate function name against FUNCTION_REGISTRY
        if haskey(mod, "analytical_function")
            known = known_analytical_function_names()
            fname = mod["analytical_function"]
            if !(lowercase(fname) in [lowercase(n) for n in known])
                push!(errors, "[model] unknown analytical_function \"$fname\". Known: $(join(known, ", "))")
            end
        end
    end

    # Cross-validate bounds dimension matches declared dimension
    if has_analytical && haskey(mod, "dimension") && has_bounds
        dim = mod["dimension"]
        b = dom["bounds"]
        if b isa AbstractVector && length(b) != dim
            push!(errors, "[domain] bounds has $(length(b)) entries but [model] dimension is $dim")
        end
    end

    # --- [domain] mode validation ---
    if n_domain_modes == 0 && !has_catalogue
        push!(errors, "[domain] must specify one of: radius, radii, or bounds (required for analytical models)")
    elseif n_domain_modes > 1
        push!(errors, "[domain] must specify exactly one of: radius, radii, or bounds (got $(n_domain_modes))")
    end

    if has_radius
        r = dom["radius"]
        (r isa Number && r > 0) || push!(errors, "[domain] radius must be a positive number, got: $r")
    end

    if has_radii
        r = dom["radii"]
        if !(r isa AbstractVector)
            push!(errors, "[domain] radii must be an array of positive numbers")
        elseif any(x -> !(x isa Number && x > 0), r)
            push!(errors, "[domain] all radii must be positive numbers")
        end
    end

    if has_bounds
        b = dom["bounds"]
        if !(b isa AbstractVector)
            push!(errors, "[domain] bounds must be an array of [lo, hi] pairs")
        else
            for (i, pair) in enumerate(b)
                if !(pair isa AbstractVector && length(pair) == 2)
                    push!(errors, "[domain] bounds[$i] must be a [lo, hi] pair")
                elseif pair[1] >= pair[2]
                    push!(errors, "[domain] bounds[$i]: lo ($(pair[1])) must be < hi ($(pair[2]))")
                end
            end
        end
    end

    # --- [polynomial] ---
    if haskey(poly, "GN")
        gn = poly["GN"]
        (gn isa Integer && 2 <= gn <= 100) || push!(errors, "[polynomial] GN must be an integer in [2, 100], got: $gn")
    else
        push!(errors, "[polynomial] missing required field 'GN'")
    end

    if haskey(poly, "degree_range")
        dr = poly["degree_range"]
        if !(dr isa AbstractVector && length(dr) == 3)
            push!(errors, "[polynomial] degree_range must be [start, step, stop], got: $dr")
        else
            if any(x -> !(x isa Integer), dr)
                push!(errors, "[polynomial] degree_range values must be integers")
            elseif dr[1] < 1 || dr[3] > 30
                push!(errors, "[polynomial] degree_range values must be in [1, 30], got: $dr")
            elseif dr[1] > dr[3]
                push!(errors, "[polynomial] degree_range start ($(dr[1])) must be <= stop ($(dr[3]))")
            elseif dr[2] < 1
                push!(errors, "[polynomial] degree_range step must be >= 1, got: $(dr[2])")
            end
        end
    else
        push!(errors, "[polynomial] missing required field 'degree_range'")
    end

    if haskey(poly, "basis")
        b = poly["basis"]
        b in ["chebyshev", "legendre"] || push!(errors, "[polynomial] basis must be 'chebyshev' or 'legendre', got: '$b'")
    end

    # --- [solver] (optional) ---
    if haskey(sol, "method")
        sol["method"] in KNOWN_SOLVER_METHODS || push!(errors,
            "[solver] unknown method '$(sol["method"])'. Known: $(join(sort(collect(KNOWN_SOLVER_METHODS)), ", "))")
    end
    if haskey(sol, "abstol")
        (sol["abstol"] isa Number && sol["abstol"] > 0) || push!(errors, "[solver] abstol must be positive")
    end
    if haskey(sol, "reltol")
        (sol["reltol"] isa Number && sol["reltol"] > 0) || push!(errors, "[solver] reltol must be positive")
    end
    if haskey(sol, "numpoints")
        np = sol["numpoints"]
        (np isa Integer && 5 <= np <= 1000) || push!(errors, "[solver] numpoints must be an integer in [5, 1000], got: $np")
    end

    # --- [analysis] (optional — Newton CP validation) ---
    ana = get(d, "analysis", Dict())
    if haskey(ana, "gradient_method")
        ana["gradient_method"] in KNOWN_GRADIENT_METHODS || push!(errors,
            "[analysis] unknown gradient_method '$(ana["gradient_method"])'. Known: $(join(sort(collect(KNOWN_GRADIENT_METHODS)), ", "))")
    end
    if haskey(ana, "newton_tol")
        (ana["newton_tol"] isa Number && ana["newton_tol"] > 0) || push!(errors,
            "[analysis] newton_tol must be positive")
    end
    if haskey(ana, "newton_max_iterations")
        nmi = ana["newton_max_iterations"]
        (nmi isa Integer && nmi > 0) || push!(errors,
            "[analysis] newton_max_iterations must be a positive integer, got: $nmi")
    end
    if haskey(ana, "hessian_tol")
        (ana["hessian_tol"] isa Number && ana["hessian_tol"] > 0) || push!(errors,
            "[analysis] hessian_tol must be positive")
    end
    if haskey(ana, "dedup_fraction")
        df = ana["dedup_fraction"]
        (df isa Number && 0 < df < 1) || push!(errors,
            "[analysis] dedup_fraction must be in (0, 1), got: $df")
    end

    # --- [refinement] (optional) ---
    if haskey(ref, "method")
        ref["method"] in KNOWN_REFINEMENT_METHODS || push!(errors,
            "[refinement] unknown method '$(ref["method"])'. Known: $(join(sort(collect(KNOWN_REFINEMENT_METHODS)), ", "))")
    end
    if haskey(ref, "gradient_method")
        ref["gradient_method"] in KNOWN_GRADIENT_METHODS || push!(errors,
            "[refinement] unknown gradient_method '$(ref["gradient_method"])'. Known: $(join(sort(collect(KNOWN_GRADIENT_METHODS)), ", "))")
    end
    if haskey(ref, "max_time")
        (ref["max_time"] isa Number && ref["max_time"] > 0) || push!(errors, "[refinement] max_time must be positive")
    end
    if haskey(ref, "gradient_tolerance")
        (ref["gradient_tolerance"] isa Number && ref["gradient_tolerance"] > 0) || push!(errors,
            "[refinement] gradient_tolerance must be positive")
    end

    # --- Raise all errors ---
    if !isempty(errors)
        error("TOML validation failed:\n  " * join(errors, "\n  "))
    end

    return nothing
end

# ═══════════════════════════════════════════════════════════════════════════════
# Path Resolution
# ═══════════════════════════════════════════════════════════════════════════════

const _RESULTS_PREFIX = "globtim_results" * Base.Filesystem.path_separator

"""
    _resolve_config_path(p, config_dir) -> Union{String, Nothing}

Resolve a relative path from a TOML config to an absolute path.

- `nothing` passes through unchanged
- Absolute paths pass through unchanged
- Paths starting with `"globtim_results/"` are resolved via `get_results_root()`
  (respects `GLOBTIM_RESULTS_ROOT` env var)
- Other relative paths are resolved relative to `config_dir` (the TOML file's directory)
"""
function _resolve_config_path(p::Nothing, ::AbstractString)
    return nothing
end

function _resolve_config_path(p::AbstractString, config_dir::AbstractString)
    isabspath(p) && return p

    if startswith(p, _RESULTS_PREFIX)
        # "globtim_results/lv4d_catalogue.jsonl" → get_results_root() * "/lv4d_catalogue.jsonl"
        return joinpath(get_results_root(), p[length(_RESULTS_PREFIX)+1:end])
    end

    # Other relative paths resolve relative to the TOML file's directory
    return joinpath(config_dir, p)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Parser
# ═══════════════════════════════════════════════════════════════════════════════

"""
    load_experiment_config(path::String) -> ExperimentPipelineConfig

Parse a TOML experiment configuration file and return a validated
`ExperimentPipelineConfig`.

# Example
```julia
config = load_experiment_config("experiments/lv4d_basic.toml")
config.GN          # => 12
config.degree_range # => 4:2:8
config.basis        # => :chebyshev
```
"""
function load_experiment_config(path::String)
    isfile(path) || error("Config file not found: $path")

    d = TOML.parsefile(path)
    validate_experiment_toml(d)

    exp  = d["experiment"]
    mod  = d["model"]
    poly = d["polynomial"]
    dom  = get(d, "domain", Dict())
    sol  = get(d, "solver", Dict())
    ref  = get(d, "refinement", Dict())
    out  = get(d, "output", Dict())

    # Parse degree_range: [start, step, stop] -> StepRange
    dr = poly["degree_range"]
    degree_range = dr[1]:dr[2]:dr[3]

    # Parse basis
    basis = Symbol(get(poly, "basis", "chebyshev"))

    # Parse domain
    radius = nothing
    radii  = nothing
    bounds = nothing
    if haskey(dom, "radius")
        radius = Float64(dom["radius"])
    elseif haskey(dom, "radii")
        radii = Float64.(dom["radii"])
    elseif haskey(dom, "bounds")
        bounds = [Tuple{Float64,Float64}((Float64(pair[1]), Float64(pair[2]))) for pair in dom["bounds"]]
    end

    # Parse model mode
    catalogue_path     = haskey(mod, "catalogue_path") ? String(mod["catalogue_path"]) : nothing
    entry_name         = haskey(mod, "entry_name") ? String(mod["entry_name"]) : nothing
    analytical_function = haskey(mod, "analytical_function") ? String(mod["analytical_function"]) : nothing
    model_dimension    = haskey(mod, "dimension") ? Int(mod["dimension"]) : nothing

    # Parse solver overrides
    solver_method = haskey(sol, "method") ? String(sol["method"]) : nothing
    solver_abstol = haskey(sol, "abstol") ? Float64(sol["abstol"]) : nothing
    solver_reltol = haskey(sol, "reltol") ? Float64(sol["reltol"]) : nothing
    solver_numpoints = haskey(sol, "numpoints") ? Int(sol["numpoints"]) : nothing

    # Parse refinement
    refinement_enabled = get(ref, "enabled", false)::Bool
    refinement_method = haskey(ref, "method") ? String(ref["method"]) : nothing
    refinement_max_time = haskey(ref, "max_time") ? Float64(ref["max_time"]) : nothing
    refinement_gradient_method = haskey(ref, "gradient_method") ? String(ref["gradient_method"]) : nothing
    refinement_gradient_tolerance = haskey(ref, "gradient_tolerance") ? Float64(ref["gradient_tolerance"]) : nothing

    # Parse analysis
    ana = get(d, "analysis", Dict())
    analysis_enabled = get(ana, "enabled", false)::Bool
    analysis_gradient_method = haskey(ana, "gradient_method") ? String(ana["gradient_method"]) : nothing
    analysis_newton_tol = haskey(ana, "newton_tol") ? Float64(ana["newton_tol"]) : nothing
    analysis_newton_max_iterations = haskey(ana, "newton_max_iterations") ? Int(ana["newton_max_iterations"]) : nothing
    analysis_hessian_tol = haskey(ana, "hessian_tol") ? Float64(ana["hessian_tol"]) : nothing
    analysis_dedup_fraction = haskey(ana, "dedup_fraction") ? Float64(ana["dedup_fraction"]) : nothing

    # Parse output
    output_dir = haskey(out, "dir") ? String(out["dir"]) : nothing

    # ── Resolve relative paths ──
    # TOML configs use relative paths like "globtim_results/lv4d_catalogue.jsonl".
    # These must be resolved to absolute paths so they work regardless of pwd().
    # Paths under "globtim_results/" are resolved via PathManager.get_results_root()
    # (which respects the GLOBTIM_RESULTS_ROOT env var). Other relative paths are
    # resolved relative to the TOML file's directory.
    config_dir = dirname(abspath(path))
    catalogue_path = _resolve_config_path(catalogue_path, config_dir)
    output_dir     = _resolve_config_path(output_dir, config_dir)

    return ExperimentPipelineConfig(
        # [experiment]
        String(exp["name"]),
        String(get(exp, "description", "")),
        # [model]
        catalogue_path,
        entry_name,
        analytical_function,
        model_dimension,
        # [domain]
        radius,
        radii,
        bounds,
        # [polynomial]
        Int(poly["GN"]),
        degree_range,
        basis,
        # [solver]
        solver_method,
        solver_abstol,
        solver_reltol,
        solver_numpoints,
        # [refinement]
        refinement_enabled,
        refinement_method,
        refinement_max_time,
        refinement_gradient_method,
        refinement_gradient_tolerance,
        # [analysis]
        analysis_enabled,
        analysis_gradient_method,
        analysis_newton_tol,
        analysis_newton_max_iterations,
        analysis_hessian_tol,
        analysis_dedup_fraction,
        # [output]
        output_dir,
    )
end

"""
    config_to_experiment_params(config::ExperimentPipelineConfig) -> ExperimentParams

Convert the polynomial/solver fields of an ExperimentPipelineConfig into an
ExperimentParams suitable for `run_standard_experiment()`.

ODE objectives are ForwardDiff-incompatible, so gradient/hessian/BFGS are
disabled when using catalogue models. Analytical models enable them by default.
"""
function config_to_experiment_params(config::ExperimentPipelineConfig)
    is_ode = config.catalogue_path !== nothing

    return ExperimentParams(
        GN = config.GN,
        degree_range = config.degree_range,
        basis = config.basis,
        domain_size = _infer_domain_size(config),
        enable_gradient_computation = !is_ode,
        enable_hessian_computation = !is_ode,
        enable_bfgs_refinement = !is_ode,
    )
end

"""Infer a scalar domain_size from the config (used by ExperimentParams)."""
function _infer_domain_size(config::ExperimentPipelineConfig)
    if config.radius !== nothing
        return config.radius
    elseif config.radii !== nothing
        return maximum(config.radii)
    elseif config.bounds !== nothing
        return maximum((hi - lo) / 2 for (lo, hi) in config.bounds)
    else
        return 0.1  # safe default, only used for display
    end
end
