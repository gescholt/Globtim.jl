"""
    PostProcessing.jl - DEPRECATED

This module has been moved to the standalone `globtimpostprocessing` package.

For new analysis, use:
    cd ../globtimpostprocessing
    julia interactive_analyze.jl [campaign_directory]

Or in Julia:
    using Pkg
    Pkg.activate("../globtimpostprocessing")
    using GlobtimPostProcessing

    # Load results
    campaign = load_campaign_results("/path/to/hpc_results")

    # Compute statistics
    stats = compute_statistics(campaign.experiments[1])

    # Create plots
    fig = create_experiment_plots(campaign.experiments[1], stats, backend=Interactive)
    display(fig)

The old implementation has been archived to: archived/PostProcessing.jl.old

Author: GlobTim Team
Deprecated: October 2025
"""
module PostProcessing

export load_experiment_results, analyze_experiment, create_experiment_report

@warn """
PostProcessing module has been deprecated and moved to globtimpostprocessing package.

Please use:
    cd ../globtimpostprocessing
    julia interactive_analyze.jl [campaign_directory]

The archived version is available at: archived/PostProcessing.jl.old
"""

# Stub functions that redirect users
function load_experiment_results(args...; kwargs...)
    error("""
    PostProcessing has been deprecated. Use the globtimpostprocessing package instead:

    cd ../globtimpostprocessing
    julia interactive_analyze.jl

    Or in Julia:
        using Pkg
        Pkg.activate("../globtimpostprocessing")
        using GlobtimPostProcessing
        results = load_experiment_results("path/to/results")
    """)
end

function analyze_experiment(args...; kwargs...)
    error("PostProcessing has been deprecated. Use globtimpostprocessing package instead.")
end

function create_experiment_report(args...; kwargs...)
    error("PostProcessing has been deprecated. Use globtimpostprocessing package instead.")
end

end # module
