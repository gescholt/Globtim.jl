# RL-Guided Adaptive Mesh Refinement - Executive Summary

**Date**: 2025-10-09
**Milestone**: #6
**Status**: Ready for Implementation

---

## 🎯 **What We're Building**

A reinforcement learning agent that learns to **efficiently find all significant local minimizers** of smooth objective functions by adaptively refining polynomial approximation subdomains.

### **Key Design Choices**

1. ✅ **Single Agent**: One policy network evaluates all subdomains (simpler than multi-agent)
2. ✅ **Ground Truth Evaluation**: Use ForwardDiff on true function, not symbolic solving
3. ✅ **Budget-Agnostic**: Reward based on minimizers found, works with any stopping criterion
4. ✅ **Scaling Path**: 2D → 3D → 4D+ (smooth functions with multiple minima)

---

## 🏆 **The Reward Function**

```julia
# What we reward:
reward = (
    10.0 * num_novel_local_minimizers +    # PRIMARY: Find new minimizers
    1.0  * progress_toward_minimizers +    # SECONDARY: Dense learning signal
    -0.1 * num_new_subdomains             # PENALTY: Efficiency
)

# How we detect local minimizers:
is_local_minimizer = (
    norm(∇f(x)) < 1e-6 &&                 # Small gradient (critical point)
    all(eigvals(H(x)) .> 0)               # Positive definite Hessian
)
```

**Why no exact solution required?** We directly evaluate the gradient on the **true function** using ForwardDiff during training—no need for HomotopyContinuation's symbolic solving.

---

## 🧪 **Test Progression**

### **Phase 1: 1D (Weeks 1-4) - Sanity Checks**
- Single minimum: `f(x) = (x - 0.5)²`
- Two minima: `f(x) = (x² - 1)²`
- Multiple minima: `f(x) = sin(5πx) + 0.5x²`

**Goal**: Verify basic RL infrastructure works

---

### **Phase 2: 2D (Weeks 5-10) - Core Development**

| Function | Minima | Difficulty | Purpose |
|----------|--------|------------|---------|
| **Rosenbrock** | 1 | Medium | Narrow valley refinement |
| **Six-Hump Camel** | 2 | Medium | Multiple minima discovery |
| **Himmelblau** | 4 | Medium | Completeness (find all 4) |
| **Rastrigin** | Many | Hard | Stress test multimodality |

**Goal**: Demonstrate efficiency gains vs baselines

---

### **Phase 3: 3D+ (Weeks 11-16) - Scaling**
- 3D Rosenbrock
- 4D Styblinski-Tang

**Goal**: Test transfer learning and dimensionality scaling

---

## 📊 **Success Criteria**

We beat baselines if:
- **Completeness**: Find ≥90% of true minimizers
- **Precision**: ≥90% of reported points are true minimizers
- **Efficiency**: Use ≤70% computational cost vs uniform refinement

---

## 📦 **Julia Packages**

```julia
# Core RL
using ReinforcementLearning      # PPO algorithm
using Lux                         # Neural network (policy)
using CommonRLInterface          # Environment standard

# Math & Evaluation
using ForwardDiff                # Gradients & Hessians
using LinearAlgebra              # Eigenvalues

# Existing GlobTim
using Globtim                    # Polynomial approximation
```

---

## 🛠️ **Implementation Steps**

### **Week 1-2: Infrastructure**
```julia
# 1. Data structures
struct GlobTimState
    subdomains::Vector{Subdomain}
    known_minimizers::Vector{Vector{Float64}}
end

# 2. RL Environment
struct GlobTimAMREnv <: CommonRLInterface.AbstractEnv
    objective_func::Function
    state::Ref{GlobTimState}
end

# 3. Reward function
function compute_reward(f, state_before, actions, state_after)
    # Count novel local minimizers using ForwardDiff
end
```

### **Week 3-4: 1D Validation**
```julia
# Train simple agent
agent = PPOAgent(policy_network)
train!(agent, env_1d, n_episodes=100)

# Verify it finds minima faster than uniform
```

### **Week 5-10: 2D Benchmarks**
```julia
# Train on Rosenbrock, Six-Hump, Himmelblau, Rastrigin
# Compare vs 3 baselines
# Generate performance plots
```

---

## 🔬 **Baselines for Comparison**

1. **Uniform**: Subdivide all subdomains equally
2. **Error-Greedy**: Refine highest L2 approximation error
3. **Gradient-Heuristic**: Refine highest gradient magnitude

---

## 🌟 **Why This Will Work**

### **Precedent**
- RL for AMR in finite elements (Luca et al. 2024) showed 30% efficiency gains
- Active learning for sample placement well-established
- Julia ML ecosystem mature (ReinforcementLearning.jl, Lux.jl)

### **Advantages Over Heuristics**
- **Learns patterns**: E.g., "narrow valleys need fine refinement"
- **Problem-specific**: Adapts to function characteristics
- **End-to-end**: Optimizes for final goal (finding minima), not proxy (L2 error)

### **Risk Mitigation**
- Start simple (1D, 2D) before scaling
- Dense reward signal (progress toward minima)
- Multiple baselines for comparison
- Budget-agnostic design allows flexible stopping criteria

---

## 📈 **Expected Outcomes**

### **Short-term (3 months)**
- ✅ Working prototype on 2D benchmarks
- ✅ 20-40% efficiency gains vs uniform refinement
- ✅ Documentation of reward design lessons

### **Medium-term (6 months)**
- ✅ Scaling to 3D-4D problems
- ✅ Transfer learning experiments (2D → higher-D)
- ✅ First research paper draft

### **Long-term Vision**
- 🎯 Production AMR agent in GlobTim
- 🎯 Pre-trained models for common problem classes
- 🎯 "Black-box" mode: user provides function → agent finds all minima

---

## 🚨 **Key Challenges**

| Challenge | Mitigation |
|-----------|-----------|
| Sparse rewards initially | Dense progress signal + curriculum learning |
| Hessian computation cost | Pre-filter with gradient, cache evaluations |
| Dimensionality scaling | Dimension-agnostic features, transfer learning |
| Defining "significant" basin | Make threshold hyperparameter, compare variants |

---

## 📚 **Related Documents**

- **Full milestone**: [MACHINE_LEARNING_INTEGRATION.md](MACHINE_LEARNING_INTEGRATION.md)
- **Detailed plan**: [MILESTONE_6_DETAILED_IMPLEMENTATION.md](MILESTONE_6_DETAILED_IMPLEMENTATION.md)
- **Package research**: See detailed implementation doc for package survey

---

## 🚀 **Next Actions**

1. **This week**: Implement `GlobTimState` and reward function
2. **Next week**: Setup RL environment with CommonRLInterface
3. **Week 3**: First training run on 1D single minimum
4. **Week 4**: Debug and validate 1D results
5. **Week 5**: Scale to 2D Rosenbrock

---

## 💡 **The Big Insight**

Traditional AMR uses hand-crafted heuristics (refine where error is high). But the **true goal** is finding critical points, not minimizing approximation error. RL allows us to **directly optimize for the end goal**.

```julia
# Traditional heuristic:
refine_where = argmax(l2_errors)  # Proxy metric

# RL approach:
refine_where = policy(state)  # Learned to maximize minimizer discovery
```

This is the power of end-to-end learning! 🎯

---

*For questions, see detailed documentation or reach out to the GlobTim team.*
