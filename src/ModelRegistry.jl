"""
ModelRegistry.jl

Centralized registry for ODE models and benchmark functions used in globtimcore.
Provides a unified API for querying, validating, and retrieving model definitions.

# Example Usage

```julia
using Globtim.ModelRegistry

# Query available models
models = list_models()                    # All models
ode_models = list_models(category = :ode) # Only ODE models
lv_4d = list_models(dimension = 4)        # 4D models

# Validate model name
if validate_model_name("lv4d_generalized")
    info = get_model("lv4d_generalized")
    func = get_model_function("lv4d_generalized")
    model, params, states, outputs = func()
end
```

# Variable Naming Conventions

This module adheres to the following naming standards:
- `model_name` (not `model`, `model_id`, `model_type`)
- `dimension` (not `dim`, `ndims`, `n_dims`)
- `num_parameters` (not `n_params`, `param_count`, `nparams`)
- `num_states` (not `n_states`, `state_count`, `nstates`)
- `num_outputs` (not `n_outputs`, `output_count`)
"""
module ModelRegistry

export ModelInfo,
    get_model,
    list_models,
    validate_model_name,
    get_model_function,
    register_model!,
    clear_registry!

"""
    ModelInfo

Metadata structure for registered models.

# Fields
- `name::String`: Primary model identifier (lowercase with underscores)
- `aliases::Vector{String}`: Alternative names for the model
- `dimension::Int`: Number of dimensions (state variables for ODE, input dimension for benchmarks)
- `num_parameters::Int`: Number of parameters to be inferred (0 for benchmarks)
- `num_states::Int`: Number of state variables (0 for benchmarks)
- `num_outputs::Int`: Number of observable/measured quantities
- `category::Symbol`: `:ode` or `:benchmark`
- `subcategory::Symbol`: More specific category (e.g., `:lotka_volterra`, `:daisy`, `:fitzhugh_nagumo`)
- `requires_inputs::Bool`: Whether the model requires external inputs
- `definition_function::Function`: Function that returns `(model, parameters, states, measured_quantities)`
- `description::String`: Human-readable description of the model
"""
struct ModelInfo
    name::String
    aliases::Vector{String}
    dimension::Int
    num_parameters::Int
    num_states::Int
    num_outputs::Int
    category::Symbol
    subcategory::Symbol
    requires_inputs::Bool
    definition_function::Function
    description::String

    function ModelInfo(;
        name::String,
        aliases::Vector{String} = String[],
        dimension::Int,
        num_parameters::Int,
        num_states::Int,
        num_outputs::Int,
        category::Symbol,
        subcategory::Symbol,
        requires_inputs::Bool = false,
        definition_function::Function,
        description::String
    )
        # Validation with proper ArgumentError exceptions
        if isempty(name)
            throw(ArgumentError("Model name cannot be empty"))
        end

        if dimension <= 0
            throw(
                ArgumentError(
                    "Model dimension must be positive, got dimension=$dimension for model '$name'"
                )
            )
        end

        if num_parameters < 0
            throw(
                ArgumentError(
                    "num_parameters must be non-negative, got $num_parameters for model '$name'"
                )
            )
        end

        if num_states < 0
            throw(
                ArgumentError(
                    "num_states must be non-negative, got $num_states for model '$name'"
                )
            )
        end

        if num_outputs < 0
            throw(
                ArgumentError(
                    "num_outputs must be non-negative, got $num_outputs for model '$name'"
                )
            )
        end

        valid_categories = [:ode, :benchmark]
        if !(category in valid_categories)
            throw(
                ArgumentError(
                    "category must be one of $valid_categories, got :$category for model '$name'"
                )
            )
        end

        new(name, aliases, dimension, num_parameters, num_states, num_outputs,
            category, subcategory, requires_inputs, definition_function, description)
    end
end

"""
Global registry mapping model names to ModelInfo structs.
"""
const MODELS = Dict{String,ModelInfo}()

"""
    register_model!(info::ModelInfo)

Register a new model in the global registry with all its aliases.
Throws ArgumentError if the name or any alias is already registered.

# Arguments
- `info::ModelInfo`: Model metadata to register

# Throws
- `ArgumentError`: If model name or any alias is already registered
"""
function register_model!(info::ModelInfo)
    # Check if name already exists
    if haskey(MODELS, info.name)
        throw(ArgumentError("Model name '$(info.name)' is already registered"))
    end

    # Check if any alias already exists
    for alias in info.aliases
        if haskey(MODELS, alias)
            existing_model = MODELS[alias].name
            throw(
                ArgumentError(
                    "Alias '$alias' for model '$(info.name)' conflicts with existing model '$existing_model'"
                )
            )
        end
    end

    # Register primary name
    MODELS[info.name] = info

    # Register all aliases pointing to the same ModelInfo
    for alias in info.aliases
        MODELS[alias] = info
    end

    return nothing
end

"""
    get_model(model_name::String) :: ModelInfo

Retrieve metadata for a registered model.
Throws `KeyError` if the model is not found.

# Example
```julia
info = get_model("lv4d_generalized")
println(info.dimension)  # 4
```
"""
function get_model(model_name::String)::ModelInfo
    if !haskey(MODELS, model_name)
        throw(KeyError("Model '$model_name' not found in registry. Use list_models() to see available models."))
    end
    return MODELS[model_name]
end

"""
    list_models(; category::Union{Symbol,Nothing}=nothing, dimension::Union{Int,Nothing}=nothing) :: Vector{String}

List all registered model names (primary names only, not aliases), optionally filtered by category and/or dimension.

# Arguments
- `category`: Filter by `:ode` or `:benchmark` (default: no filter)
- `dimension`: Filter by dimension (default: no filter)

# Returns
- `Vector{String}`: Sorted list of primary model names

# Example
```julia
ode_models = list_models(category = :ode)
models_4d = list_models(dimension = 4)
ode_4d = list_models(category = :ode, dimension = 4)
```
"""
function list_models(;
    category::Union{Symbol,Nothing} = nothing,
    dimension::Union{Int,Nothing} = nothing
)::Vector{String}
    # Get unique model names (primary names only, not aliases)
    unique_models = unique([info.name for info in values(MODELS)])

    # Filter by category if specified
    if category !== nothing
        unique_models = filter(unique_models) do model_name
            return get_model(model_name).category == category
        end
    end

    # Filter by dimension if specified
    if dimension !== nothing
        unique_models = filter(unique_models) do model_name
            return get_model(model_name).dimension == dimension
        end
    end

    return sort(unique_models)
end

"""
    validate_model_name(model_name::String) :: Bool

Check if a model name is registered in the registry.

# Example
```julia
if validate_model_name("lv4d_generalized")
    println("Model exists!")
end
```
"""
function validate_model_name(model_name::String)::Bool
    return haskey(MODELS, model_name)
end

"""
    get_model_function(model_name::String) :: Function

Retrieve the definition function for a registered model.

# Example
```julia
func = get_model_function("lv4d_generalized")
model, parameters, states, measured_quantities = func()
```
"""
function get_model_function(model_name::String)::Function
    info = get_model(model_name)
    return info.definition_function
end

# ============================================================================
# Model Registration: ODE Models from Dynamic_objectives package
# ============================================================================

"""
Register all ODE models from Dynamic_objectives package

Note: This function only works if Dynamic_objectives is loaded in the user's environment.
Load it explicitly in your experiment:
    using Dynamic_objectives
"""
function register_ode_models!()
    # Check if Dynamic_objectives is available
    if !isdefined(Main, :Dynamic_objectives)
        return
    end

    # Import functions from the loaded module
    define_generalized_lotka_volterra_4D = Main.Dynamic_objectives.define_generalized_lotka_volterra_4D
    define_constrained_lotka_volterra_4D = Main.Dynamic_objectives.define_constrained_lotka_volterra_4D
    define_daisy_ex3_model_4D = Main.Dynamic_objectives.define_daisy_ex3_model_4D
    define_daisy_ex3_model_4D_no_input = Main.Dynamic_objectives.define_daisy_ex3_model_4D_no_input
    define_fitzhugh_nagumo_3D_model = Main.Dynamic_objectives.define_fitzhugh_nagumo_3D_model
    define_lotka_volterra_3D_model = Main.Dynamic_objectives.define_lotka_volterra_3D_model
    define_lotka_volterra_3D_model_v2 = Main.Dynamic_objectives.define_lotka_volterra_3D_model_v2
    define_lotka_volterra_2D_model = Main.Dynamic_objectives.define_lotka_volterra_2D_model
    define_lotka_volterra_2D_model_v2 = Main.Dynamic_objectives.define_lotka_volterra_2D_model_v2
    define_lotka_volterra_2D_model_v3 = Main.Dynamic_objectives.define_lotka_volterra_2D_model_v3
    define_lotka_volterra_2D_model_v3_two_outputs = Main.Dynamic_objectives.define_lotka_volterra_2D_model_v3_two_outputs
    define_simple_2D_model_locally_identifiable = Main.Dynamic_objectives.define_simple_2D_model_locally_identifiable
    define_simple_2D_model_locally_identifiable_square = Main.Dynamic_objectives.define_simple_2D_model_locally_identifiable_square
    define_simple_1D_model_locally_identifiable = Main.Dynamic_objectives.define_simple_1D_model_locally_identifiable

    # Lotka-Volterra 4D - Generalized
    register_model!(ModelInfo(
        name = "lv4d_generalized",
        aliases = ["lv4d_gen", "generalized_lv4d"],
        dimension = 4,
        num_parameters = 20,
        num_states = 4,
        num_outputs = 4,
        category = :ode,
        subcategory = :lotka_volterra,
        requires_inputs = false,
        definition_function = define_generalized_lotka_volterra_4D,
        description = "Generalized 4D Lotka-Volterra model with full interaction matrix (20 parameters: 4 growth rates + 16 interaction coefficients)"
    ))

    # Lotka-Volterra 4D - Constrained
    register_model!(ModelInfo(
        name = "lv4d_constrained",
        aliases = ["lv4d_const", "constrained_lv4d"],
        dimension = 4,
        num_parameters = 4,
        num_states = 4,
        num_outputs = 4,
        category = :ode,
        subcategory = :lotka_volterra,
        requires_inputs = false,
        definition_function = define_constrained_lotka_volterra_4D,
        description = "Constrained 4D Lotka-Volterra with skew-symmetric perturbations (4 epsilon parameters)"
    ))

    # DAISY Ex3 4D - with input
    register_model!(ModelInfo(
        name = "daisy_ex3_4d",
        aliases = ["daisy_ex3", "daisy4d"],
        dimension = 4,
        num_parameters = 4,
        num_states = 4,
        num_outputs = 2,
        category = :ode,
        subcategory = :daisy,
        requires_inputs = true,
        definition_function = define_daisy_ex3_model_4D,
        description = "DAISY Example 3 4D model with input (4 parameters: p1, p3, p4, p6)"
    ))

    # DAISY Ex3 4D - no input
    register_model!(ModelInfo(
        name = "daisy_ex3_4d_no_input",
        aliases = ["daisy_ex3_noinput", "daisy3d"],
        dimension = 3,
        num_parameters = 4,
        num_states = 3,
        num_outputs = 2,
        category = :ode,
        subcategory = :daisy,
        requires_inputs = false,
        definition_function = define_daisy_ex3_model_4D_no_input,
        description = "DAISY Example 3 4D model without input (3 states: x1, x2, x3)"
    ))

    # FitzHugh-Nagumo 3D
    register_model!(ModelInfo(
        name = "fitzhugh_nagumo_3d",
        aliases = ["fhn3d", "fitzhugh_nagumo"],
        dimension = 2,
        num_parameters = 3,
        num_states = 2,
        num_outputs = 1,
        category = :ode,
        subcategory = :fitzhugh_nagumo,
        requires_inputs = false,
        definition_function = define_fitzhugh_nagumo_3D_model,
        description = "FitzHugh-Nagumo 3D neuronal model (3 parameters: g, a, b)"
    ))

    # Lotka-Volterra 3D
    register_model!(ModelInfo(
        name = "lv3d",
        aliases = ["lotka_volterra_3d"],
        dimension = 2,
        num_parameters = 3,
        num_states = 2,
        num_outputs = 1,
        category = :ode,
        subcategory = :lotka_volterra,
        requires_inputs = false,
        definition_function = define_lotka_volterra_3D_model,
        description = "Lotka-Volterra 3D model (3 parameters: a, b, c)"
    ))

    # Lotka-Volterra 3D v2
    register_model!(ModelInfo(
        name = "lv3d_v2",
        aliases = ["lotka_volterra_3d_v2"],
        dimension = 2,
        num_parameters = 3,
        num_states = 2,
        num_outputs = 1,
        category = :ode,
        subcategory = :lotka_volterra,
        requires_inputs = false,
        definition_function = define_lotka_volterra_3D_model_v2,
        description = "Lotka-Volterra 3D model variant 2 with modified interaction terms"
    ))

    # Lotka-Volterra 2D
    register_model!(ModelInfo(
        name = "lv2d",
        aliases = ["lotka_volterra_2d"],
        dimension = 2,
        num_parameters = 2,
        num_states = 2,
        num_outputs = 1,
        category = :ode,
        subcategory = :lotka_volterra,
        requires_inputs = false,
        definition_function = define_lotka_volterra_2D_model,
        description = "Lotka-Volterra 2D model with c=1 (2 parameters: a, b)"
    ))

    # Lotka-Volterra 2D v2
    register_model!(ModelInfo(
        name = "lv2d_v2",
        aliases = ["lotka_volterra_2d_v2"],
        dimension = 2,
        num_parameters = 2,
        num_states = 2,
        num_outputs = 1,
        category = :ode,
        subcategory = :lotka_volterra,
        requires_inputs = false,
        definition_function = define_lotka_volterra_2D_model_v2,
        description = "Lotka-Volterra 2D model with c=0.1"
    ))

    # Lotka-Volterra 2D v3
    register_model!(ModelInfo(
        name = "lv2d_v3",
        aliases = ["lotka_volterra_2d_v3"],
        dimension = 2,
        num_parameters = 2,
        num_states = 2,
        num_outputs = 1,
        category = :ode,
        subcategory = :lotka_volterra,
        requires_inputs = false,
        definition_function = define_lotka_volterra_2D_model_v3,
        description = "Lotka-Volterra 2D model with c=0.5"
    ))

    # Lotka-Volterra 2D v3 two outputs
    register_model!(ModelInfo(
        name = "lv2d_v3_two_outputs",
        aliases = ["lotka_volterra_2d_v3_2out"],
        dimension = 2,
        num_parameters = 2,
        num_states = 2,
        num_outputs = 2,
        category = :ode,
        subcategory = :lotka_volterra,
        requires_inputs = false,
        definition_function = define_lotka_volterra_2D_model_v3_two_outputs,
        description = "Lotka-Volterra 2D model with c=0.5 and two outputs (both species observable)"
    ))

    # Simple 2D locally identifiable
    register_model!(ModelInfo(
        name = "simple_2d_locally_identifiable",
        aliases = ["simple_2d_identifiable"],
        dimension = 1,
        num_parameters = 2,
        num_states = 1,
        num_outputs = 1,
        category = :ode,
        subcategory = :identifiability_test,
        requires_inputs = false,
        definition_function = define_simple_2D_model_locally_identifiable,
        description = "Simple 2D model for testing local identifiability (dx/dt = ab*x + (a+b))"
    ))

    # Simple 2D locally identifiable square
    register_model!(ModelInfo(
        name = "simple_2d_locally_identifiable_square",
        aliases = ["simple_2d_identifiable_sq"],
        dimension = 1,
        num_parameters = 2,
        num_states = 1,
        num_outputs = 1,
        category = :ode,
        subcategory = :identifiability_test,
        requires_inputs = false,
        definition_function = define_simple_2D_model_locally_identifiable_square,
        description = "Simple 2D model with squared term for testing identifiability (dx/dt = a*x + b²)"
    ))

    # Simple 1D locally identifiable
    register_model!(ModelInfo(
        name = "simple_1d_locally_identifiable",
        aliases = ["simple_1d_identifiable"],
        dimension = 1,
        num_parameters = 1,
        num_states = 1,
        num_outputs = 1,
        category = :ode,
        subcategory = :identifiability_test,
        requires_inputs = false,
        definition_function = define_simple_1D_model_locally_identifiable,
        description = "Simple 1D model for testing identifiability (dx/dt = x + a²)"
    ))
end

# ============================================================================
# Model Registration: Benchmark Functions from LibFunctions.jl
# ============================================================================

"""
Register all benchmark functions from src/LibFunctions.jl
"""
function register_benchmark_functions!()
    # Benchmark functions should already be loaded via Globtim.jl
    # which includes LibFunctions.jl before ModelRegistry.jl
    # Access them through the parent Globtim module
    parent_module = parentmodule(ModelRegistry)

    # Helper to register benchmark functions with standard pattern
    function register_benchmark(
        name::String,
        func_name::Symbol,
        dim::Int,
        desc::String;
        aliases::Vector{String} = String[]
    )
        func = getfield(parent_module, func_name)
        register_model!(ModelInfo(
            name = name,
            aliases = aliases,
            dimension = dim,
            num_parameters = 0,
            num_states = 0,
            num_outputs = 1,
            category = :benchmark,
            subcategory = :mathematical,
            requires_inputs = false,
            definition_function = func,
            description = desc
        ))
    end

    # Register benchmark functions that exist in LibFunctions.jl
    # Note: Dimension info from LibFunctions.jl function signatures

    register_benchmark("sphere", :Sphere, 2,
        "Sphere function - simple convex unimodal function")

    register_benchmark("rosenbrock", :Rosenbrock, 2,
        "Rosenbrock function - classic optimization test with narrow valley")

    register_benchmark("griewank", :Griewank, 2,
        "Griewank function - multimodal with many local minima")

    register_benchmark("schwefel", :Schwefel, 2,
        "Schwefel function - highly multimodal")

    register_benchmark("levy", :Levy, 2,
        "Levy function - multimodal")

    register_benchmark("zakharov", :Zakharov, 2,
        "Zakharov function - unimodal plate-shaped")

    register_benchmark("beale", :Beale, 2,
        "Beale function - multimodal with steep ridges")

    register_benchmark("booth", :Booth, 2,
        "Booth function - plate-shaped with single global minimum")

    register_benchmark("branin", :Branin, 2,
        "Branin function - multimodal with three global minima")

    register_benchmark("goldstein_price", :GoldsteinPrice, 2,
        "Goldstein-Price function - multimodal")

    register_benchmark("matyas", :Matyas, 2,
        "Matyas function - plate-shaped with single global minimum")

    register_benchmark("mccormick", :McCormick, 2,
        "McCormick function - bowl-shaped with single global minimum")

    register_benchmark("michalewicz", :Michalewicz, 2,
        "Michalewicz function - multimodal with steep ridges")

    register_benchmark("styblinski_tang", :StyblinskiTang, 2,
        "Styblinski-Tang function - multimodal")

    register_benchmark("sum_of_different_powers", :SumOfDifferentPowers, 2,
        "Sum of Different Powers function - unimodal")

    register_benchmark("trid", :Trid, 2,
        "Trid function - unimodal with many parameters")

    register_benchmark("rotated_hyper_ellipsoid", :RotatedHyperEllipsoid, 2,
        "Rotated Hyper-Ellipsoid function - unimodal")

    register_benchmark("powell", :Powell, 4,
        "Powell function - unimodal, requires n=4k dimensions")

    register_benchmark("holder_table", :HolderTable, 2,
        "Holder Table function - multimodal with four global minima")

    register_benchmark("deuflhard", :Deuflhard, 2,
        "Deuflhard function - polynomial test function")

    register_benchmark("rastrigin", :Rastringin, 2,
        "Rastrigin function - highly multimodal with regularly distributed local minima")
end

"""
    clear_registry!()

Clear all registered models from the registry.

⚠️ **For testing only.** This function removes all registered models.

# Example
```julia
# In tests
clear_registry!()
# Register test models...
```
"""
function clear_registry!()
    empty!(MODELS)
    return nothing
end

# ============================================================================
# Model Registration: SAR Imaging Functions
# ============================================================================

"""
Register SAR (Synthetic Aperture Radar) imaging cost functions

Note: Requires SARCostFunction module to be loaded. This is a Julia port
of MATLAB ionospheric phase screen compensation code.

The SAR cost function minimizes:
  - L4 norm (contrast enhancement)
  - Regularization on phase screen derivatives

Parameters: 12D (6 complex Fourier coefficients → 12 real parameters)
"""
function register_sar_functions!()
    # Check if SARCostFunction is available in the Julia load path
    # This is typically at /Users/ghscholt/GlobalOptim/matlab/julia/SARCostFunction
    sar_available = false
    try
        # Try to find and load SARCostFunction if not already loaded
        if !isdefined(Main, :SARCostFunction)
            push!(LOAD_PATH, joinpath(@__DIR__, "../../matlab/julia/SARCostFunction/src"))
            try
                @eval Main using SARCostFunction
                sar_available = true
            catch
                pop!(LOAD_PATH)
            end
        else
            sar_available = true
        end
    catch e
        @debug "SARCostFunction not available: $e"
        return
    end

    if !sar_available
        return
    end

    # Wrapper function that returns a callable matching registry interface
    function sar_cost_function_wrapper()
        # Return a function that takes a parameter vector and returns cost
        # This wrapper adapts the SAR interface to the standard registry interface
        return Main.SARCostFunction.cost_from_control_vars
    end

    register_model!(ModelInfo(
        name = "sar_ionospheric_compensation",
        aliases = ["sar", "sar_imaging", "ionospheric_sar"],
        dimension = 12,
        num_parameters = 12,  # 6 complex amplitudes = 12 real parameters (p1,q1,...,p6,q6)
        num_states = 0,
        num_outputs = 2,  # l4norm and regularization
        category = :benchmark,
        subcategory = :imaging,
        requires_inputs = true,  # Requires UscStruct and Setup
        definition_function = sar_cost_function_wrapper,
        description = "SAR ionospheric phase screen compensation via Fourier series (12D: 6 complex coefficients). Minimizes -L4_norm + regularization for image quality."
    ))
end

# ============================================================================
# Module Initialization
# ============================================================================

"""
Initialize the model registry by registering all models from:
- Dynamic_objectives package (ODE models)
- src/LibFunctions.jl (benchmark functions)
- matlab/julia/SARCostFunction (SAR imaging)
"""
function __init__()
    try
        register_ode_models!()
    catch e
        @warn "Failed to register ODE models (this is expected if Dynamic_objectives is not loaded): $e"
    end

    try
        register_benchmark_functions!()
    catch e
        @warn "Failed to register benchmark functions: $e"
    end

    try
        register_sar_functions!()
    catch e
        @debug "Failed to register SAR functions (this is expected if SARCostFunction is not available): $e"
    end

    n_total = length(unique([info.name for info in values(MODELS)]))
    n_ode = length(list_models(category=:ode))
    n_benchmark = length(list_models(category=:benchmark))

    if n_total > 0
        @info "ModelRegistry initialized with $n_total models ($n_ode ODE, $n_benchmark benchmarks)"
    else
        @info "ModelRegistry initialized with no models (use register_model! to add models)"
    end
end

end # module ModelRegistry
