The split should happen after the Pseudo Vandermonde matrix has been constructed. 
Then we can solve the linear system $$Ax= F$$ multiple times, the matrix `A` will stay the same. 

What could I and what should I test the method on ?

Need to adapt the HomotopyContinuation method to the dynamic systems framework.

#In the adaptive constructor: the adaptive part to test: we are potentially in an infinite recursion loop. --> How many recursion levels do we allow ? What if we tried one recursion level => one increase in the degree, 5 recurrence levels allowed, Centered at `p_center = p_true.

We should take `scale_factor` equal to the one with degree `d=6` and `p_center = p_true` of the example we have ran. 


Suggested variables: 
and `recurrence_levels = 5` and `tolerance = 1e-6` and `max_iter = 1000` and `verbose = True` and `plot = True` and `save = True` and `save_path = 'Examples/trials/'` and `save_name = 'adaptive_degree_increase'` and `save_format = 'pdf'` and `save_dpi


## Outputs of test of evaluations of error_func with 6 time points ##
julia> error_func([ 0.0983664,0.298058,0.227237])
0.0030858247237905423

julia> error_func([ 0.1083664,0.298058,0.227237])
0.3671064831244547

julia> error_func([ 0.1,0.298058,0.227237])
0.05769651440328122

julia> error_func([ 0.1,0.228058,0.227237])
0.3722476966744437

julia> error_func([ 0.1,0.22,0.227237])
0.42132090713103976

julia> error_func([ 0.1,0.22,0.2])
0.4352194304032414

julia> error_func([ 0.1,0.22,0.3])
0.38309764221753223

julia> error_func([ 0.1,0.22,0.33])
0.36686064266903684

julia> error_func([ 0.11,0.22,0.33])
0.0

julia> error_func([ 0.11,0.22,0.3])
0.016373776191550005
