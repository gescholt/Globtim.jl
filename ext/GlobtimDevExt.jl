module GlobtimDevExt

using Globtim
import Parameters

# Export development functionality when Parameters is available
if isdefined(@__MODULE__, :Parameters)
    # Parameters-dependent functionality can be added here
    # (Most Parameters usage is likely in included files)
end

end