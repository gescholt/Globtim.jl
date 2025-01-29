function get_config_path()
    joinpath(@__DIR__, "..", "data", "config.toml")
end

function load_function_params(func_name::String)
    config_path = get_config_path()
    params = TOML.parsefile(config_path)
    FunctionParameters(params[func_name])
end

# This is the struct definition
struct FunctionParameters
    dim::Int
    center::Vector{Float64}
    num_samples::Int
    sample_range::Float64
    tolerance::Float64
    delta::Float64
    alpha::Float64
end

# This is a constructor function for the struct
function FunctionParameters(config::Dict)
    FunctionParameters(
        config["dim"],
        config["center"],
        config["num_samples"],
        config["sample_range"],
        config["tolerance"],
        config["delta"],
        config["alpha"]
    )
end