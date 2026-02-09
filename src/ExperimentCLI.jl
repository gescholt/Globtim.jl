"""
ExperimentCLI - Command Line Interface for Experiment Scripts

Provides flexible CLI parsing for experiment scripts with support for:
- Positional arguments (backwards compatible)
- Named arguments (--key=value)
- Environment variables (ENV["KEY"])
- Type validation and range checking
- Integration with DrWatson @dict

Usage patterns:
    # Positional (backwards compatible)
    julia script.jl 0.1 10 4:8

    # Named arguments
    julia script.jl --domain=0.1 --GN=10 --degrees=4:8

    # Environment variables
    DOMAIN=0.1 GN=10 DEGREES=4:8 julia script.jl

    # Mixed (named override positional)
    julia script.jl 0.1 --GN=10 --degrees=4:8
"""
module ExperimentCLI

export parse_experiment_args, ExperimentParams, validate_params

using Printf
using TOML

"""
    ExperimentParams

Standard parameter structure for 4D experiments.
All parameters are optional with sensible defaults.
"""
struct ExperimentParams
    domain_size::Float64
    GN::Int
    degree_range::AbstractRange{Int}
    max_time::Float64
    basis::Symbol
    optim_f_tol::Float64
    optim_x_tol::Float64
    max_iterations::Int

    # Feature toggles for ForwardDiff-dependent operations
    enable_gradient_computation::Bool
    enable_hessian_computation::Bool
    enable_bfgs_refinement::Bool

    function ExperimentParams(;
        domain_size::Real = 0.1,
        GN::Integer = 5,
        degree_range::Union{AbstractRange{Int}, String} = 4:4,
        max_time::Real = 45.0,
        basis::Union{Symbol, String} = :chebyshev,
        optim_f_tol::Real = 1e-6,
        optim_x_tol::Real = 1e-6,
        max_iterations::Integer = 300,
        enable_gradient_computation::Bool = true,
        enable_hessian_computation::Bool = true,
        enable_bfgs_refinement::Bool = true
    )
        # Parse degree_range if string
        if degree_range isa String
            degree_range = parse_degree_range(degree_range)
        end

        # Convert basis to Symbol if String
        basis_sym = basis isa String ? Symbol(basis) : basis

        # Validate basis
        if !(basis_sym in [:chebyshev, :legendre])
            error("Invalid basis: $basis_sym. Must be :chebyshev or :legendre")
        end

        # Validate parameters
        validate_params(domain_size, GN, degree_range, max_time)

        new(
            Float64(domain_size),
            Int(GN),
            degree_range,
            Float64(max_time),
            basis_sym,
            Float64(optim_f_tol),
            Float64(optim_x_tol),
            Int(max_iterations),
            enable_gradient_computation,
            enable_hessian_computation,
            enable_bfgs_refinement
        )
    end
end

# Make ExperimentParams compatible with ConstructionBase/Accessors
# Override setproperties to use keyword constructor (avoids positional args issue)
import ConstructionBase

function ConstructionBase.setproperties(obj::ExperimentParams, patch::NamedTuple)
    # Get all current field values as keyword arguments
    current = (;
        domain_size = obj.domain_size,
        GN = obj.GN,
        degree_range = obj.degree_range,
        max_time = obj.max_time,
        basis = obj.basis,
        optim_f_tol = obj.optim_f_tol,
        optim_x_tol = obj.optim_x_tol,
        max_iterations = obj.max_iterations,
        enable_gradient_computation = obj.enable_gradient_computation,
        enable_hessian_computation = obj.enable_hessian_computation,
        enable_bfgs_refinement = obj.enable_bfgs_refinement
    )

    # Merge patch into current values
    merged = merge(current, patch)

    # Call keyword constructor (preserves all validation)
    return ExperimentParams(; merged...)
end

# Make ExperimentParams compatible with DrWatson @dict and NamedTuple operations
Base.pairs(p::ExperimentParams) = (
    domain_size = p.domain_size,
    GN = p.GN,
    degree_range = p.degree_range,
    max_time = p.max_time,
    basis = p.basis,
    optim_f_tol = p.optim_f_tol,
    optim_x_tol = p.optim_x_tol,
    max_iterations = p.max_iterations,
    enable_gradient_computation = p.enable_gradient_computation,
    enable_hessian_computation = p.enable_hessian_computation,
    enable_bfgs_refinement = p.enable_bfgs_refinement
)

Base.getindex(p::ExperimentParams, key::Symbol) = getfield(p, key)

"""
    parse_degree_range(s::String) -> UnitRange{Int}

Parse degree range from string format: "4:8" or "4" (single degree)
"""
function parse_degree_range(s::String)
    if occursin(":", s)
        parts = split(s, ":")
        if length(parts) == 2
            start_deg = parse(Int, strip(parts[1]))
            end_deg = parse(Int, strip(parts[2]))
            return start_deg:end_deg
        elseif length(parts) == 3
            start_deg = parse(Int, strip(parts[1]))
            step_deg = parse(Int, strip(parts[2]))
            end_deg = parse(Int, strip(parts[3]))
            return start_deg:step_deg:end_deg
        else
            error("Invalid degree range format: '$s'. Expected 'start:end' or 'start:step:end'")
        end
    else
        # Single degree
        deg = parse(Int, strip(s))
        return deg:deg
    end
end

"""
    validate_params(domain_size, GN, degree_range, max_time)

Validate parameter ranges and types. Throws descriptive errors on validation failure.
"""
function validate_params(domain_size::Real, GN::Integer, degree_range::AbstractRange{Int}, max_time::Real)
    errors = String[]

    # Domain size validation
    if domain_size <= 0.0
        push!(errors, "domain_size must be positive, got $(domain_size)")
    elseif domain_size > 10.0
        push!(errors, "domain_size must be ≤ 10.0, got $(domain_size)")
    end

    # GN validation
    if GN < 2
        push!(errors, "GN must be ≥ 2, got $(GN)")
    elseif GN > 100
        push!(errors, "GN must be ≤ 100, got $(GN) ($(GN^4) grid points in 4D)")
    end

    # Degree range validation
    if first(degree_range) < 1
        push!(errors, "degree_range must start at ≥ 1, got $(first(degree_range))")
    end
    if last(degree_range) > 30
        push!(errors, "degree_range must end at ≤ 30, got $(last(degree_range))")
    end
    if first(degree_range) > last(degree_range)
        push!(errors, "degree_range must be increasing, got $(first(degree_range)):$(last(degree_range))")
    end

    # Max time validation
    if max_time <= 0.0
        push!(errors, "max_time must be positive, got $(max_time)")
    end

    # Throw combined error if any validations failed
    if !isempty(errors)
        error("Parameter validation failed:\n  " * join(errors, "\n  "))
    end

    return true
end

"""
    parse_named_args(args::Vector{String}) -> Dict{Symbol, String}

Parse named arguments like --domain=0.1 --GN=10

Supports argument aliases:
- --degrees or --degree-range
- --domain or --domain-size
- --gn or --GN
"""
function parse_named_args(args::Vector{String})
    named = Dict{Symbol, String}()

    # Define argument aliases (all lowercase)
    aliases = Dict(
        :degreerange => :degrees,
        :degree_range => :degrees,
        :domainsize => :domain,
        :domain_size => :domain,
        :maxtime => :maxtime,
        :max_time => :maxtime,
        :enable_gradients => :enablegradients,
        :enablegradient => :enablegradients,
        :enable_hessians => :enablehessians,
        :enablehessian => :enablehessians,
        :enable_bfgs => :enablebfgs
    )

    for arg in args
        if startswith(arg, "--")
            # Remove leading --
            arg_clean = arg[3:end]

            if occursin("=", arg_clean)
                parts = split(arg_clean, "=", limit=2)
                raw_key = lowercase(replace(parts[1], "-" => ""))
                key = Symbol(raw_key)
                value = parts[2]

                # Apply alias if exists
                if haskey(aliases, key)
                    key = aliases[key]
                end

                named[key] = value
            else
                error("Named argument missing value: $arg (expected format: --key=value)")
            end
        end
    end

    return named
end

"""
    parse_positional_args(args::Vector{String}) -> Vector{String}

Extract positional arguments (non-named arguments)
"""
function parse_positional_args(args::Vector{String})
    return filter(arg -> !startswith(arg, "--"), args)
end

"""
    parse_experiment_args(
        args::Vector{String} = ARGS;
        defaults::NamedTuple = NamedTuple()
    ) -> ExperimentParams

Parse experiment arguments with priority:
1. Named CLI arguments (--key=value)
2. Positional CLI arguments
3. Environment variables
4. Provided defaults
5. Built-in defaults

# Arguments
- `args`: Command line arguments (defaults to ARGS)
- `defaults`: Default values as NamedTuple (e.g., (GN=5, domain_size=0.1))

# Returns
- `ExperimentParams`: Validated parameter struct

# Examples
```julia
# Positional arguments (backwards compatible)
params = parse_experiment_args(["0.1", "10", "4:8"])
# -> domain_size=0.1, GN=10, degrees=4:8

# Named arguments
params = parse_experiment_args(["--domain=0.1", "--GN=10", "--degrees=4:8"])
# -> domain_size=0.1, GN=10, degrees=4:8

# Environment variables
ENV["DOMAIN"] = "0.1"
ENV["GN"] = "10"
params = parse_experiment_args([])
# -> domain_size=0.1, GN=10

# Mixed
params = parse_experiment_args(["0.1", "--GN=10"])
# -> domain_size=0.1, GN=10

# With custom defaults
params = parse_experiment_args([], defaults=(GN=8, max_time=120.0))
# -> uses GN=8, max_time=120.0
```
"""
function parse_experiment_args(
    args::Vector = ARGS;
    defaults::NamedTuple = NamedTuple()
)
    # Convert to Vector{String} if needed
    args = String[string(arg) for arg in args]
    # Parse named arguments
    named_args = parse_named_args(args)

    # Parse positional arguments
    positional_args = parse_positional_args(args)

    # Validate recognized arguments (fail-fast on unknown arguments)
    valid_keys = Set([:degrees, :domain, :gn, :maxtime, :outputdir, :output_dir,
                      :enablegradients, :enable_gradients,
                      :enablehessians, :enable_hessians,
                      :enablebfgs, :enable_bfgs,
                      :config, :basis])
    unrecognized = setdiff(Set(keys(named_args)), valid_keys)
    if !isempty(unrecognized)
        error("Unrecognized named arguments: $(join(sort([string(k) for k in unrecognized]), ", "))\n" *
              "Valid arguments: --config, --degrees, --degree-range, --domain, --domain-size, --GN, --max-time, --maxtime, " *
              "--basis, --enable-gradients, --enable-hessians, --enable-bfgs")
    end

    # If --config is specified, load TOML file as base defaults (CLI args override)
    if haskey(named_args, :config)
        config_path = named_args[:config]
        isfile(config_path) || error("Config file not found: $config_path")
        toml = TOML.parsefile(config_path)

        # Extract polynomial section values as defaults
        poly = get(toml, "polynomial", Dict())
        if haskey(poly, "GN") && !haskey(named_args, :gn)
            named_args[:gn] = string(Int(poly["GN"]))
        end
        if haskey(poly, "degree_range") && !haskey(named_args, :degrees)
            dr = poly["degree_range"]
            if length(dr) == 3
                named_args[:degrees] = "$(dr[1]):$(dr[2]):$(dr[3])"
            elseif length(dr) == 2
                named_args[:degrees] = "$(dr[1]):$(dr[2])"
            end
        end
        if haskey(poly, "basis") && !haskey(named_args, :basis)
            named_args[:basis] = string(poly["basis"])
        end

        # Extract domain section
        dom = get(toml, "domain", Dict())
        if haskey(dom, "radius") && !haskey(named_args, :domain)
            named_args[:domain] = string(Float64(dom["radius"]))
        end

        # Remove :config from named_args so it doesn't interfere with downstream parsing
        delete!(named_args, :config)
    end

    # Helper to get value with priority: named > positional > env > defaults
    function get_param(
        key::Symbol,
        positional_idx::Union{Int,Nothing} = nothing,
        env_key::String = uppercase(string(key)),
        parser::Function = identity
    )
        # 1. Named argument (highest priority)
        if haskey(named_args, key)
            return parser(named_args[key])
        end

        # 2. Positional argument
        if positional_idx !== nothing && length(positional_args) >= positional_idx
            return parser(positional_args[positional_idx])
        end

        # 3. Environment variable
        if haskey(ENV, env_key)
            return parser(ENV[env_key])
        end

        # 4. Provided defaults
        if haskey(defaults, key)
            return defaults[key]
        end

        # 5. Return nothing (will use built-in default in ExperimentParams constructor)
        return nothing
    end

    # Parse each parameter
    domain_size = get_param(:domain, 1, "DOMAIN", s -> parse(Float64, s))
    GN = get_param(:gn, 2, "GN", s -> parse(Int, s))

    # Degree range can be "4:8" or positional args 3 and 4 as separate start/end
    degree_range_str = get_param(:degrees, nothing, "DEGREES", identity)

    if degree_range_str !== nothing
        degree_range = parse_degree_range(degree_range_str)
    else
        # Try parsing as separate start/end in positional args
        if length(positional_args) >= 3
            if occursin(":", positional_args[3])
                # Format: "4:8"
                degree_range = parse_degree_range(positional_args[3])
            elseif length(positional_args) >= 4
                # Format: 4 8 (separate start and end)
                deg_start = parse(Int, positional_args[3])
                deg_end = parse(Int, positional_args[4])
                degree_range = deg_start:deg_end
            else
                # Single degree
                deg = parse(Int, positional_args[3])
                degree_range = deg:deg
            end
        else
            degree_range = nothing
        end
    end

    max_time = get_param(:maxtime, nothing, "MAX_TIME", s -> parse(Float64, s))

    # Parse boolean feature toggles
    # Helper function to parse boolean strings
    parse_bool = function(s::String)
        s_lower = lowercase(strip(s))
        if s_lower in ["true", "1", "yes", "on"]
            return true
        elseif s_lower in ["false", "0", "no", "off"]
            return false
        else
            error("Invalid boolean value: '$s'. Use true/false, 1/0, yes/no, or on/off")
        end
    end

    enable_gradients = get_param(:enablegradients, nothing, "ENABLE_GRADIENTS", parse_bool)
    enable_hessians = get_param(:enablehessians, nothing, "ENABLE_HESSIANS", parse_bool)
    enable_bfgs = get_param(:enablebfgs, nothing, "ENABLE_BFGS", parse_bool)

    # Parse basis (string -> passed through to ExperimentParams which converts to Symbol)
    basis = get_param(:basis, nothing, "BASIS", identity)

    # Build kwargs dict: start with provided defaults, then override with parsed values
    kwargs = Dict{Symbol, Any}(pairs(defaults))
    if domain_size !== nothing; kwargs[:domain_size] = domain_size; end
    if GN !== nothing; kwargs[:GN] = GN; end
    if degree_range !== nothing; kwargs[:degree_range] = degree_range; end
    if max_time !== nothing; kwargs[:max_time] = max_time; end
    if basis !== nothing; kwargs[:basis] = basis; end
    if enable_gradients !== nothing; kwargs[:enable_gradient_computation] = enable_gradients; end
    if enable_hessians !== nothing; kwargs[:enable_hessian_computation] = enable_hessians; end
    if enable_bfgs !== nothing; kwargs[:enable_bfgs_refinement] = enable_bfgs; end

    # Construct ExperimentParams (will use built-in defaults for missing values)
    return ExperimentParams(; kwargs...)
end

"""
    print_params(params::ExperimentParams; title="Experiment Parameters")

Pretty-print experiment parameters.
"""
function print_params(params::ExperimentParams; title="Experiment Parameters")
    println("=" ^ 60)
    println(title)
    println("=" ^ 60)
    println("  Domain size:     ±$(params.domain_size)")
    println("  Grid samples:    GN=$(params.GN) ($(params.GN^4) points in 4D)")
    println("  Degree range:    $(first(params.degree_range)):$(last(params.degree_range))")
    println("  Max time/degree: $(params.max_time)s")
    println("=" ^ 60)
end

end # module ExperimentCLI