function get_config_path()
    joinpath(@__DIR__, "..", "data", "config.toml")
end

function load_function_params(func_name::String)
    config_path = get_config_path()
    params = TOML.parsefile(config_path)
    FunctionParameters(params[func_name])
end

struct FunctionParameters
    dim::Int
    center::Vector{Float64}
    num_samples::Int
    sample_range::Float64
    tolerance::Union{Float64, Nothing}
    delta::Union{Float64, Nothing}
    alpha::Union{Float64, Nothing}
end

function FunctionParameters(config::Dict)
    FunctionParameters(
        config["dim"],
        config["center"],
        config["num_samples"],
        config["sample_range"],
        get(config, "tolerance", nothing),
        get(config, "delta", nothing),
        get(config, "alpha", nothing)
    )
end
