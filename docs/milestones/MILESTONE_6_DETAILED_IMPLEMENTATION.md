# Milestone #6: RL-Guided Adaptive Mesh Refinement - Detailed Implementation Plan

**Status**: 📋 Ready for Implementation
**Updated**: 2025-10-09
**Parent Milestone**: [MACHINE_LEARNING_INTEGRATION.md](MACHINE_LEARNING_INTEGRATION.md)

---

## 🎯 **Clarified Objective**

**Primary Goal**: Learn a reinforcement learning policy that efficiently finds **all significant local minimizers** of smooth objective functions over compact domains through adaptive polynomial approximation refinement.

### **Key Design Decisions**

1. **Single Agent Architecture**: One policy network evaluates all subdomains (not multi-agent)
2. **Budget-Agnostic Reward**: Reward function independent of computational budget
3. **Gradient-Based Ground Truth**: Use ForwardDiff on true objective function (not symbolic solving)
4. **Scaling Path**: Start 2D → scale to higher dimensions (4D, 6D+)
5. **Target Functions**: Smooth functions with multiple local minima

---

## 🏆 **Reward Function Design**

### **Core Principle: Reward Finding Local Minimizers**

A point `x*` is a **local minimizer** if:
1. **||∇f(x*)|| < ε_gradient** (gradient is small - critical point)
2. **H(x*) is positive definite** (all eigenvalues > 0)
3. **Basin depth is significant** (optional filter for "large enough" minima)

```julia
"""
Budget-agnostic reward function for finding local minimizers.

Evaluates TRUE objective function f using ForwardDiff, not polynomial approximation.
No symbolic solving required during training.
"""
function compute_reward(
    objective_func::Function,        # Ground truth function
    state_before::GlobTimState,
    refinement_actions::Vector{Int}, # Which subdomains were refined
    state_after::GlobTimState;
    ε_gradient::Float64 = 1e-6,     # Gradient threshold
    ε_eigenvalue::Float64 = 1e-8     # Hessian PD threshold
)
    # Extract candidate points from refined subdomains
    candidates = extract_candidate_points(state_after)

    # Track discovered minimizers
    local_minimizers = []

    for point in candidates
        # Check if gradient is small
        grad = ForwardDiff.gradient(objective_func, point)
        grad_norm = norm(grad)

        if grad_norm < ε_gradient
            # Check if Hessian is positive definite
            hess = ForwardDiff.hessian(objective_func, point)
            eigenvals = eigvals(Symmetric(hess))

            if all(λ -> λ > ε_eigenvalue, eigenvals)
                push!(local_minimizers, point)
            end
        end
    end

    # Count novel minimizers (not already discovered)
    novel_minimizers = filter_novel(
        local_minimizers,
        state_before.known_minimizers,
        threshold = 0.01  # Within 1% of domain size
    )

    # PRIMARY REWARD: Novel local minimizers
    r_discovery = 10.0 * length(novel_minimizers)

    # SECONDARY REWARD: Dense signal for progress
    # Reward points with small gradients (even if not yet at minimum)
    r_progress = sum(
        1.0 / (1.0 + (norm(ForwardDiff.gradient(objective_func, p)) / ε_gradient)^2)
        for p in candidates
    )

    # PENALTY: Efficiency (budget-agnostic, just relative cost)
    num_new_subdomains = length(state_after.subdomains) -
                         length(state_before.subdomains)
    r_efficiency = -0.1 * num_new_subdomains

    total_reward = r_discovery + r_progress + r_efficiency

    return total_reward
end
```

### **Why This Design is Budget-Agnostic**

- **No time penalties**: Reward is based on minimizers found, not time taken
- **No absolute limits**: Works with any stopping criterion (time, iterations, subdomains)
- **Relative efficiency penalty**: Small penalty discourages waste but doesn't dominate
- **Episode returns comparable**: Different budget settings give comparable reward scales

---

## 🧪 **Test Suite: Progressive Complexity**

### **Phase 1: 1D Validation (Sanity Checks)**

Simple 1D problems to verify basic functionality.

```julia
# Test 1.1: Single minimum (convex)
f1(x) = (x[1] - 0.5)^2
# Domain: [-1, 1]
# Expected: 1 minimum at x* = 0.5

# Test 1.2: Two minima (symmetric)
f2(x) = (x[1]^2 - 1)^2
# Domain: [-2, 2]
# Expected: 2 minima at x* = ±1.0

# Test 1.3: Multiple minima (periodic)
f3(x) = sin(5 * π * x[1]) + 0.5 * x[1]^2
# Domain: [-1, 1]
# Expected: ~5 local minima
```

**Success Criteria**: Agent finds all minima in <20 refinement steps

---

### **Phase 2: 2D Benchmark Functions**

Standard optimization benchmarks for 2D testing.

#### **Test 2.1: Rosenbrock (Narrow Valley)**
```julia
rosenbrock(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
# Domain: [-2, 2] × [-1, 3]
# Minima: 1 global minimum at (1, 1), f* = 0
# Difficulty: Medium - narrow curved valley
```

**Why this test?**
- Classic benchmark for optimization algorithms
- Tests ability to refine along narrow features
- Single minimum - simpler credit assignment

**Success Criteria**:
- Find minimum within distance 0.01 of true location
- Use ≤50% of subdomains compared to uniform refinement

---

#### **Test 2.2: Six-Hump Camel Function**
```julia
six_hump_camel(x) = (4 - 2.1*x[1]^2 + x[1]^4/3) * x[1]^2 +
                     x[1]*x[2] + (-4 + 4*x[2]^2) * x[2]^2
# Domain: [-3, 3] × [-2, 2]
# Minima: 2 global minima at (±0.0898, ∓0.7126), f* ≈ -1.0316
# Difficulty: Medium - multiple minima
```

**Why this test?**
- Tests finding multiple distinct minima
- Symmetric structure - checks if agent explores both sides
- Well-studied function with known ground truth

**Success Criteria**:
- Find both global minima
- Ignore any shallow local minima (if present)

---

#### **Test 2.3: Rastrigin (Highly Multimodal)**
```julia
rastrigin(x) = 20 + sum(xi^2 - 10*cos(2π*xi) for xi in x)
# Domain: [-5.12, 5.12]²
# Minima: 1 global minimum at (0, 0), f* = 0
#         Many local minima at regular grid
# Difficulty: Hard - numerous local minima
```

**Why this test?**
- Stress test for exploration
- Many local minima (agent must distinguish significant ones)
- Tests basin depth filtering

**Success Criteria**:
- Find global minimum
- If using basin depth filter: ignore shallow local minima
- If not: find ≥80% of local minima within domain

---

#### **Test 2.4: Himmelblau's Function**
```julia
himmelblau(x) = (x[1]^2 + x[2] - 11)^2 + (x[1] + x[2]^2 - 7)^2
# Domain: [-5, 5]²
# Minima: 4 global minima (all f* = 0):
#   (3.0, 2.0), (-2.805118, 3.131312),
#   (-3.779310, -3.283186), (3.584428, -1.848126)
# Difficulty: Medium - 4-fold symmetry
```

**Why this test?**
- Tests finding ALL minima (completeness)
- Non-obvious symmetry
- Good for visualizing agent's search strategy

**Success Criteria**:
- Find all 4 minima
- Balanced exploration (not biased to one region)

---

### **Phase 3: 3D Extensions**

```julia
# Test 3.1: 3D Rosenbrock
rosenbrock_3d(x) = sum(
    100*(x[i+1] - x[i]^2)^2 + (1 - x[i])^2
    for i in 1:(length(x)-1)
)
# Domain: [-2, 2]³
# Minima: 1 at (1, 1, 1)

# Test 3.2: 3D Rastrigin
rastrigin_3d(x) = 30 + sum(xi^2 - 10*cos(2π*xi) for xi in x)
# Domain: [-5.12, 5.12]³
# Many local minima
```

**Success Criteria**:
- Same as 2D versions
- Test if learned policy transfers from 2D

---

### **Phase 4: Higher Dimensions (4D+)**

```julia
# Test 4.1: Styblinski-Tang (scalable)
styblinski_tang(x) = sum(xi^4 - 16*xi^2 + 5*xi for xi in x) / 2
# Domain: [-5, 5]^n
# Global minimum at (-2.903534, ..., -2.903534)

# Test 4.2: Custom smooth multimodal
custom_4d(x) = sum(sin(πxi)^2 for xi in x) + 0.1*sum(xi^2 for xi in x)
# Domain: [-3, 3]^4
```

**Success Criteria**:
- Find global minimum
- Demonstrate scaling efficiency vs baseline

---

## 📊 **Baseline Comparison Methods**

Compare RL agent against:

### **Baseline 1: Uniform Refinement**
```julia
# Subdivide all subdomains equally each iteration
for iteration in 1:max_iterations
    for subdomain in active_subdomains
        subdivide!(subdomain)
    end
end
```

### **Baseline 2: Error-Based Greedy**
```julia
# Refine subdomains with highest L2 approximation error
for iteration in 1:max_iterations
    errors = [subdomain.l2_error for subdomain in subdomains]
    top_k = partialsortperm(errors, 1:budget, rev=true)
    subdivide!.(subdomains[top_k])
end
```

### **Baseline 3: Gradient-Based Heuristic**
```julia
# Refine subdomains with highest gradient magnitude
for iteration in 1:max_iterations
    grad_norms = [
        maximum(norm(ForwardDiff.gradient(f, p)) for p in sample_points(s))
        for s in subdomains
    ]
    top_k = partialsortperm(grad_norms, 1:budget, rev=true)
    subdivide!.(subdomains[top_k])
end
```

---

## 🛠️ **Implementation Roadmap**

### **Week 1-2: Infrastructure**

**Deliverable**: Basic RL environment wrapping GlobTim

```julia
# Implement core structures
struct GlobTimState
    subdomains::Vector{Subdomain}
    known_minimizers::Vector{MinimizerInfo}
    total_l2_error::Float64
    iteration::Int
end

struct Subdomain
    bounds::Vector{Float64}      # [xmin, xmax, ymin, ymax, ...]
    polynomial::ApproxPoly        # From existing GlobTim
    grid::Matrix{Float64}         # Grid points
    l2_error::Float64
end

# Implement environment interface
struct GlobTimAMREnv <: CommonRLInterface.AbstractEnv
    objective_func::Function
    domain_bounds::Tuple
    current_state::Ref{GlobTimState}
end

# Implement reward function
function compute_reward(f, state_before, actions, state_after)
    # As defined above
end
```

**Tasks**:
- [ ] Define data structures
- [ ] Implement `CommonRLInterface` methods
- [ ] Implement reward function with gradient checking
- [ ] Unit tests for reward function

---

### **Week 3-4: 1D Validation**

**Deliverable**: Working RL agent on 1D test problems

```julia
# Setup simple policy network
using Lux, ReinforcementLearning

policy_net = Lux.Chain(
    Lux.Dense(20 => 64, Lux.relu),   # 20 = feature dimension per subdomain
    Lux.Dense(64 => 64, Lux.relu),
    Lux.Dense(64 => 1, Lux.tanh)     # Output: refinement score
)

# Train with PPO on 1D problems
env = GlobTimAMREnv(f1, domain=([-1.0], [1.0]))
agent = PPOAgent(policy_net)
train!(agent, env, n_episodes=100)
```

**Tasks**:
- [ ] Implement subdomain feature extraction
- [ ] Setup PPO training loop
- [ ] Run on Test 1.1, 1.2, 1.3
- [ ] Verify reward signal works (plot learning curves)
- [ ] Debug any issues

**Success Metric**: Agent learns to find minima faster than uniform refinement

---

### **Week 5-8: 2D Benchmarks**

**Deliverable**: Trained agent on 2D Rosenbrock, Six-Hump Camel, Himmelblau

```julia
# Train on each 2D problem
problems_2d = [
    (name="rosenbrock", f=rosenbrock, domain=([-2,2], [-1,3])),
    (name="six_hump", f=six_hump_camel, domain=([-3,3], [-2,2])),
    (name="himmelblau", f=himmelblau, domain=([-5,5], [-5,5])),
]

for prob in problems_2d
    agent = train_agent(prob.f, prob.domain, n_episodes=500)
    evaluate_agent(agent, prob.f, prob.domain, n_trials=20)
end
```

**Tasks**:
- [ ] Extend to 2D state features
- [ ] Implement visualization (subdomain boundaries + found minima)
- [ ] Train separate agents for each problem
- [ ] Compare vs all 3 baselines
- [ ] Generate performance plots

**Success Metrics**:
- Find all minima in ≥90% of trials
- Use ≤70% computational cost vs uniform refinement
- Learning curves show convergence

---

### **Week 9-10: Rastrigin Stress Test**

**Deliverable**: Agent handling highly multimodal function

```julia
# Rastrigin with basin depth filtering
agent = train_agent(
    rastrigin,
    domain=([-5.12, 5.12], [-5.12, 5.12]),
    reward_config=(
        basin_depth_threshold=1.0,  # Filter tiny minima
    ),
    n_episodes=1000
)
```

**Tasks**:
- [ ] Implement basin depth filtering in reward
- [ ] Train with different basin thresholds
- [ ] Analyze exploration strategy (heatmaps)
- [ ] Document trade-offs (find all vs find significant only)

---

### **Week 11-12: 3D Scaling**

**Deliverable**: Test transfer learning 2D → 3D

```julia
# Option 1: Train from scratch on 3D
agent_3d_scratch = train_agent(rosenbrock_3d, domain_3d, n_episodes=500)

# Option 2: Fine-tune 2D agent on 3D
agent_3d_transfer = fine_tune(agent_2d, rosenbrock_3d, domain_3d, n_episodes=100)

# Compare
compare_performance(agent_3d_scratch, agent_3d_transfer)
```

**Tasks**:
- [ ] Extend feature extraction to 3D
- [ ] Test both training strategies
- [ ] Measure sample efficiency
- [ ] Document dimensionality challenges

---

### **Week 13-16: Higher Dimensions (Optional)**

**Deliverable**: Preliminary results on 4D problems

**Tasks**:
- [ ] Test Styblinski-Tang 4D
- [ ] Identify scaling bottlenecks
- [ ] Document challenges for future work

---

## 📦 **Julia Package Stack**

Based on research (from previous discussion):

### **Essential (Tier 1)**
```julia
using ReinforcementLearning      # PPO, SAC algorithms
using Lux                         # Policy network (preferred over Flux)
using CommonRLInterface          # Environment interface
using ForwardDiff                # Gradient/Hessian computation
using Optimization               # Training optimizers
using LinearAlgebra              # Eigenvalue analysis
```

### **Recommended (Tier 2)**
```julia
using Plots, CairoMakie          # Visualization
using DataFrames                 # Logging/analysis
using Statistics                 # Metrics
using Random                     # Reproducibility
```

### **Existing GlobTim**
```julia
using Globtim                    # Polynomial approximation
using HomotopyContinuation       # (Optional) symbolic solving for validation
```

---

## 📈 **Evaluation Metrics**

### **Primary Metrics**

1. **Completeness**: % of true minima found
   ```julia
   completeness = num_minima_found / num_true_minima
   ```

2. **Precision**: % of reported minima that are true minima
   ```julia
   precision = num_true_positives / num_reported_minima
   ```

3. **Efficiency**: Computational cost vs baseline
   ```julia
   efficiency = baseline_cost / agent_cost  # >1 is better
   ```

### **Secondary Metrics**

4. **Sample Efficiency**: Episodes to convergence
5. **Robustness**: Std dev over multiple random seeds
6. **Scalability**: Performance degradation with dimension

---

## 🎯 **Success Criteria per Phase**

| Phase | Test | Completeness | Precision | Efficiency vs Uniform |
|-------|------|--------------|-----------|----------------------|
| 1D Validation | Single min | ≥95% | ≥95% | ≥1.0 (baseline) |
| 2D Rosenbrock | 1 minimum | ≥95% | ≥95% | ≥1.3 |
| 2D Six-Hump | 2 minima | ≥90% | ≥90% | ≥1.2 |
| 2D Himmelblau | 4 minima | ≥85% | ≥85% | ≥1.2 |
| 2D Rastrigin | Many minima | ≥80% | ≥70% | ≥1.1 |
| 3D Rosenbrock | 1 minimum | ≥90% | ≥90% | ≥1.2 |

---

## 🔬 **Experimental Protocol**

### **Training**
- Episodes: 500-1000 per problem
- Random seeds: 5 independent runs
- Early stopping: If no improvement for 100 episodes
- Checkpointing: Save best model every 50 episodes

### **Evaluation**
- Test trials: 20 per problem
- Unseen instances: Vary domain size, initial conditions
- Statistical testing: Wilcoxon signed-rank test vs baselines

### **Reproducibility**
- Fix random seeds
- Log all hyperparameters
- Version control training scripts
- Archive trained models

---

## 🚧 **Known Challenges & Mitigations**

### **Challenge 1: Sparse Reward Signal**
**Problem**: Finding first minimizer may take many steps (no reward until then)

**Mitigation**:
- Include dense progress reward (gradient magnitude reduction)
- Curriculum learning: start with easy problems (single minimum)
- Reward shaping: bonus for exploring high-gradient regions

---

### **Challenge 2: Dimensionality Scaling**
**Problem**: Feature space grows with dimensions, state space explodes

**Mitigation**:
- Use dimension-agnostic features (per-subdomain statistics)
- Test transfer learning (2D → 3D)
- Consider attention mechanisms for variable-length subdomain lists

---

### **Challenge 3: Computational Cost of Hessian**
**Problem**: Computing Hessian for every candidate point is expensive

**Mitigation**:
- Cache Hessian evaluations
- Only compute Hessian for points with ||∇f|| < ε (gradient pre-filter)
- Sample subset of candidate points per step
- Use GPU acceleration (ForwardDiff supports CUDA)

---

### **Challenge 4: Defining "Significant" Minima**
**Problem**: What basin depth threshold to use?

**Mitigation**:
- Make it a hyperparameter (test multiple values)
- Adaptive threshold based on function range
- Let user specify (domain knowledge)
- Compare with/without filtering

---

## 📝 **Next Immediate Actions**

1. **Week 1 Day 1-3**: Implement `GlobTimState` and `Subdomain` data structures
2. **Week 1 Day 4-5**: Implement reward function with unit tests
3. **Week 2 Day 1-3**: Implement `CommonRLInterface` environment
4. **Week 2 Day 4-5**: Setup PPO training infrastructure
5. **Week 3**: Train on 1D Test 1.1 (single minimum sanity check)

---

## 📚 **References**

### **RL for AMR Literature**
- Luca et al. (2024) "Deep Reinforcement Learning for Adaptive Mesh Refinement"
- Karumuri et al. (2024) "G-Adaptive mesh refinement leveraging GNNs"

### **Optimization Benchmarks**
- Jamil & Yang (2013) "A Literature Survey of Benchmark Functions"
- SciPy optimization benchmark suite

### **Julia RL Resources**
- ReinforcementLearning.jl docs: https://juliareinforcementlearning.org/
- Lux.jl tutorial: https://lux.csail.mit.edu/

---

## 🎯 **Big Picture Vision**

### **Short-term (3 months)**
- Working prototype on 2D benchmarks
- Demonstrated efficiency gains vs baselines
- Documented reward design principles

### **Medium-term (6 months)**
- Scaling to 3D-4D
- Transfer learning experiments
- First paper draft

### **Long-term (1+ year)**
- Production-ready AMR agent
- Pre-trained models for common problem types
- Integration into main GlobTim pipeline
- Auto-configuration: "find all minima of this function" → agent handles everything

---

*This document will be updated as experiments progress. All code, results, and lessons learned will be version-controlled and documented.*
