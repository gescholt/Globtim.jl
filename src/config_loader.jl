"""
TOML Experiment Configuration Loader

Parses TOML config files into `ExperimentPipelineConfig` for use with
`run_standard_experiment()` and external orchestrators.

This module lives in Globtim with no external dependencies.
Domain-specific orchestration is handled by downstream packages.

Created: 2026-02-09
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
- `[model]`: catalogue_path + entry_name (catalogue) OR analytical_function + dimension (built-in)
  Optional: time_interval (override catalogue default, catalogue mode only)
  Optional: sample_times (explicit time sample points, overrides time_interval + numpoints)
- `[domain]`: radius (symmetric) OR radii (anisotropic) OR bounds (explicit)
- `[polynomial]`: GN, degree_range, basis, truncation_threshold (opt-in), truncation_mode
- `[solver]`: solver overrides (optional)
- `[refinement]`: post-processing refinement (optional)
- `[output]`: output_dir (optional)
"""
Base.@kwdef struct ExperimentPipelineConfig
    # [experiment]
    name::String
    description::String = ""

    # [model] — exactly one mode: catalogue XOR analytical
    catalogue_path::Union{Nothing, String} = nothing
    entry_name::Union{Nothing, String} = nothing
    analytical_function::Union{Nothing, String} = nothing
    dimension::Union{Nothing, Int} = nothing
    time_interval::Union{Nothing, Vector{Float64}} = nothing  # override catalogue default
    sample_times::Union{Nothing, Vector{Float64}} = nothing   # explicit time sample points (overrides time_interval + numpoints)
    p_true::Union{Nothing, Vector{Float64}} = nothing         # override catalogue p_true

    # [domain] — exactly one mode: radius XOR radii XOR bounds
    radius::Union{Nothing, Float64} = nothing
    radii::Union{Nothing, Vector{Float64}} = nothing
    bounds::Union{Nothing, Vector{Tuple{Float64, Float64}}} = nothing
    p_center::Union{Nothing, Vector{Float64}} = nothing       # domain center (default: p_true)

    # [polynomial]
    GN::Int
    degree_range::StepRange{Int, Int}
    basis::Symbol = :chebyshev
    truncation_threshold::Union{Nothing, Float64} = nothing  # opt-in coefficient truncation
    truncation_mode::Symbol = :relative                      # :relative or :absolute

    # [solver] — optional solver overrides
    solver_method::Union{Nothing, String} = nothing
    solver_abstol::Union{Nothing, Float64} = nothing
    solver_reltol::Union{Nothing, Float64} = nothing
    solver_numpoints::Union{Nothing, Int} = nothing

    # [refinement] — optional post-processing
    refinement_enabled::Bool = false
    refinement_method::Union{Nothing, String} = nothing
    refinement_max_time::Union{Nothing, Float64} = nothing
    refinement_gradient_method::Union{Nothing, String} = nothing
    refinement_gradient_tolerance::Union{Nothing, Float64} = nothing

    # [analysis] — optional CP refinement and classification
    analysis_enabled::Bool = false
    analysis_refinement_goal::Union{Nothing, String} = nothing  # "minimum" or "critical_point"
    analysis_gradient_method::Union{Nothing, String} = nothing
    analysis_newton_tol::Union{Nothing, Float64} = nothing
    analysis_newton_max_iterations::Union{Nothing, Int} = nothing
    analysis_max_time_per_point::Union{Nothing, Float64} = nothing
    analysis_hessian_tol::Union{Nothing, Float64} = nothing
    analysis_dedup_fraction::Union{Nothing, Float64} = nothing
    analysis_top_k::Union{Nothing, Int} = nothing
    analysis_accept_tol::Union{Nothing, Float64} = nothing
    analysis_f_accept_tol::Union{Nothing, Float64} = nothing
    analysis_valley_walking::Bool = false
    analysis_deep_diagnostics::Bool = false

    # [output]
    output_dir::Union{Nothing, String} = nothing
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

    # Validate p_true (only valid in catalogue mode)
    if haskey(mod, "p_true")
        if has_analytical
            push!(errors, "[model] p_true is only valid in catalogue mode, not with analytical_function")
        else
            pt = mod["p_true"]
            if !(pt isa AbstractVector && all(x -> x isa Number, pt))
                push!(errors, "[model] p_true must be a numeric array, got: $pt")
            end
        end
    end

    # Validate p_center (only meaningful with radius/radii domain modes)
    if haskey(dom, "p_center")
        pc = dom["p_center"]
        if !(pc isa AbstractVector && all(x -> x isa Number, pc))
            push!(errors, "[domain] p_center must be a numeric array, got: $pc")
        end
        if has_bounds
            push!(errors, "[domain] p_center is not used with explicit bounds (bounds already define the domain)")
        end
        if !has_radius && !has_radii && !has_catalogue
            push!(errors, "[domain] p_center requires radius or radii to define the domain")
        end
    end

    # Validate time_interval override (only valid in catalogue mode)
    if haskey(mod, "time_interval")
        if has_analytical
            push!(errors, "[model] time_interval is only valid in catalogue mode, not with analytical_function")
        else
            ti = mod["time_interval"]
            if !(ti isa AbstractVector && length(ti) == 2)
                push!(errors, "[model] time_interval must be [start, end], got: $ti")
            elseif !(ti[1] isa Number && ti[2] isa Number)
                push!(errors, "[model] time_interval values must be numbers")
            elseif ti[2] <= ti[1]
                push!(errors, "[model] time_interval end ($(ti[2])) must be > start ($(ti[1]))")
            end
        end
    end

    # Validate sample_times (only valid in catalogue mode, conflicts with time_interval)
    if haskey(mod, "sample_times")
        if has_analytical
            push!(errors, "[model] sample_times is only valid in catalogue mode, not with analytical_function")
        elseif haskey(mod, "time_interval")
            push!(errors, "[model] cannot specify both sample_times and time_interval (sample_times implies the time interval)")
        else
            st = mod["sample_times"]
            if !(st isa AbstractVector && length(st) >= 2)
                push!(errors, "[model] sample_times must be an array with at least 2 time points, got: $st")
            elseif !all(x -> x isa Number, st)
                push!(errors, "[model] sample_times values must be numbers")
            else
                st_sorted = sort(Float64.(st))
                if st_sorted != Float64.(st)
                    push!(errors, "[model] sample_times must be in ascending order")
                end
                if st_sorted[end] <= st_sorted[1]
                    push!(errors, "[model] sample_times must span a non-zero time interval")
                end
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
            elseif dr[1] < 1
                push!(errors, "[polynomial] degree_range start must be >= 1, got: $dr")
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

    if haskey(poly, "truncation_threshold")
        t = poly["truncation_threshold"]
        (t isa Number && t > 0) || push!(errors, "[polynomial] truncation_threshold must be positive, got: $t")
    end
    if haskey(poly, "truncation_mode")
        m = poly["truncation_mode"]
        m in ["relative", "absolute"] || push!(errors, "[polynomial] truncation_mode must be 'relative' or 'absolute', got: '$m'")
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
    if haskey(ana, "accept_tol")
        (ana["accept_tol"] isa Number && ana["accept_tol"] > 0) || push!(errors,
            "[analysis] accept_tol must be positive")
    end
    if haskey(ana, "f_accept_tol")
        (ana["f_accept_tol"] isa Number && ana["f_accept_tol"] > 0) || push!(errors,
            "[analysis] f_accept_tol must be positive")
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

    # Parse truncation (optional)
    truncation_threshold = haskey(poly, "truncation_threshold") ? Float64(poly["truncation_threshold"]) : nothing
    truncation_mode = Symbol(get(poly, "truncation_mode", "relative"))

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
    time_interval      = haskey(mod, "time_interval") ? Float64.(mod["time_interval"]) : nothing
    sample_times       = haskey(mod, "sample_times") ? Float64.(mod["sample_times"]) : nothing
    p_true             = haskey(mod, "p_true") ? Float64.(mod["p_true"]) : nothing

    # Parse p_center from [domain]
    p_center = haskey(dom, "p_center") ? Float64.(dom["p_center"]) : nothing

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
    analysis_refinement_goal = haskey(ana, "refinement_goal") ? String(ana["refinement_goal"]) : nothing
    analysis_gradient_method = haskey(ana, "gradient_method") ? String(ana["gradient_method"]) : nothing
    analysis_newton_tol = haskey(ana, "newton_tol") ? Float64(ana["newton_tol"]) : nothing
    analysis_newton_max_iterations = haskey(ana, "newton_max_iterations") ? Int(ana["newton_max_iterations"]) : nothing
    analysis_max_time_per_point = haskey(ana, "max_time_per_point") ? Float64(ana["max_time_per_point"]) : nothing
    analysis_hessian_tol = haskey(ana, "hessian_tol") ? Float64(ana["hessian_tol"]) : nothing
    analysis_dedup_fraction = haskey(ana, "dedup_fraction") ? Float64(ana["dedup_fraction"]) : nothing
    analysis_top_k = haskey(ana, "top_k") ? Int(ana["top_k"]) : nothing

    # Parse output
    output_dir = haskey(out, "dir") ? String(out["dir"]) : nothing

    # ── Resolve relative paths ──
    # TOML configs use relative paths like "globtim_results/lv4d_catalogue.jsonl".
    # These must be resolved to absolute paths so they work regardless of pwd().
    # Paths under "globtim_results/" are resolved via PathManager.get_results_root()
    # (which respects the GLOBTIM_RESULTS_ROOT env var). Other relative paths are
    # resolved relative to the TOML file's directory.
    config_dir = dirname(realpath(path))  # realpath: resolve symlinks so copied/linked TOMLs find their relative paths
    catalogue_path = _resolve_config_path(catalogue_path, config_dir)
    output_dir     = _resolve_config_path(output_dir, config_dir)

    # Parse analysis accept tolerances and valley walking
    analysis_accept_tol = haskey(ana, "accept_tol") ? Float64(ana["accept_tol"]) : nothing
    analysis_f_accept_tol = haskey(ana, "f_accept_tol") ? Float64(ana["f_accept_tol"]) : nothing
    analysis_valley_walking = Bool(get(ana, "valley_walking", false))
    analysis_deep_diagnostics = Bool(get(ana, "deep_diagnostics", false))

    return ExperimentPipelineConfig(
        # [experiment]
        name = String(exp["name"]),
        description = String(get(exp, "description", "")),
        # [model]
        catalogue_path = catalogue_path,
        entry_name = entry_name,
        analytical_function = analytical_function,
        dimension = model_dimension,
        time_interval = time_interval,
        sample_times = sample_times,
        p_true = p_true,
        # [domain]
        radius = radius,
        radii = radii,
        bounds = bounds,
        p_center = p_center,
        # [polynomial]
        GN = Int(poly["GN"]),
        degree_range = degree_range,
        basis = basis,
        truncation_threshold = truncation_threshold,
        truncation_mode = truncation_mode,
        # [solver]
        solver_method = solver_method,
        solver_abstol = solver_abstol,
        solver_reltol = solver_reltol,
        solver_numpoints = solver_numpoints,
        # [refinement]
        refinement_enabled = refinement_enabled,
        refinement_method = refinement_method,
        refinement_max_time = refinement_max_time,
        refinement_gradient_method = refinement_gradient_method,
        refinement_gradient_tolerance = refinement_gradient_tolerance,
        # [analysis]
        analysis_enabled = analysis_enabled,
        analysis_refinement_goal = analysis_refinement_goal,
        analysis_gradient_method = analysis_gradient_method,
        analysis_newton_tol = analysis_newton_tol,
        analysis_newton_max_iterations = analysis_newton_max_iterations,
        analysis_max_time_per_point = analysis_max_time_per_point,
        analysis_hessian_tol = analysis_hessian_tol,
        analysis_dedup_fraction = analysis_dedup_fraction,
        analysis_top_k = analysis_top_k,
        analysis_accept_tol = analysis_accept_tol,
        analysis_f_accept_tol = analysis_f_accept_tol,
        analysis_valley_walking = analysis_valley_walking,
        analysis_deep_diagnostics = analysis_deep_diagnostics,
        # [output]
        output_dir = output_dir,
    )
end

"""
    config_to_experiment_params(config::ExperimentPipelineConfig) -> ExperimentParams

Convert the polynomial/solver fields of an ExperimentPipelineConfig into an
ExperimentParams suitable for `run_standard_experiment()`.

Catalogue objectives may be ForwardDiff-incompatible, so gradient/hessian/BFGS are
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
        truncation_threshold = config.truncation_threshold,
        truncation_mode = config.truncation_mode,
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
