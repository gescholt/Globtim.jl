module GlobtimConstructionBaseExt

# ConstructionBase.setproperties for Globtim.ExperimentCLI.ExperimentParams: the default
# would call the positional constructor; this one goes through the keyword constructor,
# which keeps its validation. Loads with `using ConstructionBase` (or Accessors).

using Globtim: ExperimentCLI
import ConstructionBase

function ConstructionBase.setproperties(obj::ExperimentCLI.ExperimentParams, patch::NamedTuple)
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
        enable_bfgs_refinement = obj.enable_bfgs_refinement,
        truncation_threshold = obj.truncation_threshold,
        truncation_mode = obj.truncation_mode,
        degree_timeout_seconds = obj.degree_timeout_seconds,
        msolve_timeout_seconds = obj.msolve_timeout_seconds,
    )

    # Merge patch into current values
    merged = merge(current, patch)

    # Call keyword constructor (preserves all validation)
    return ExperimentCLI.ExperimentParams(; merged...)
end

end # module
