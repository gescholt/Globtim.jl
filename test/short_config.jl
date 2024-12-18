const TIME_INTERVAL = [0.0, 1.0]
const DATASIZE = 5
const P_TRUE = [0.11, 0.22, 0.33]   # true values of a,b,c
const ic = [0.11, 0.15]
const n = 3
const N = 2
const num_pts_1 = 15

""" 
N is the number of subdivision in each dimension
"""

"The parameters in these inputs are the sample range and the number of samples."

hyp_centers = hypercube_centers(n, N)

sample_configs_1 = [(1 // N, num_pts_1, x) for x in eachrow(hyp_centers)]
# sample_configs_2 = [(1 // N, 8, x) for x in eachrow(hyp_centers)]


# sample_configs_3 = [
#     (0.1, 4),
#     (0.1, 6),
#     (0.1, 8)]
# sample_configs_4 = [
#     (0.05, 4),
#     (0.05, 6),
#     (0.05, 8)]
# sample_configs_5 = [
#     (0.025, 4),
#     (0.025, 6),
#     (0.025, 8)]