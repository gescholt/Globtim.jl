# 4D Diffusion Inverse Problem

## Overview

This example implements a sophisticated 4D inverse problem for multi-physics transport phenomena. The problem models scenarios such as groundwater flow characterization or medical imaging parameter estimation, where multiple physical mechanisms interact to create complex basin structures suitable for testing Globtim's basin detection capabilities.

## Mathematical Formulation

### Governing PDE

The transport equation combines diffusion, advection, and reaction:

```
∂u/∂t = ∇·(D(x,y)∇u) - v(x,y)·∇u + R(x,y)u + S(x,y)
```

For steady-state problems:
```
0 = ∇·(D(x,y)∇u) - v(x,y)·∇u + R(x,y)u + S(x,y)
```

Where:
- `u(x,y)` is the concentration field
- `D(x,y)` is the spatially-varying diffusion tensor
- `v(x,y) = [vx, vy]` is the advection velocity field
- `R(x,y)` is the reaction coefficient field
- `S(x,y)` is the source term

### 4D Active Subspace

The problem is parameterized by θ ∈ ℝⁿ (typically n=50-500) but has an intrinsic 4D structure:

**Active Coordinates**: y = W'θ where y ∈ ℝ⁴

1. **y₁ (Diffusion)**: Controls overall diffusion strength and spatial variation
2. **y₂ (Advection)**: Controls velocity field magnitude and pattern
3. **y₃ (Reaction)**: Controls reaction rate and localization
4. **y₄ (Anisotropy)**: Controls directional preferences in diffusion tensor

### Field Construction

#### Diffusion Tensor (y₁)
```julia
D(x,y) = exp(y₁) * [1 + 0.3*sin(2πx/Lx)*cos(2πy/Ly)] * [anisotropy_ratio  0; 0  1/anisotropy_ratio]
```

#### Velocity Field (y₂)
Divergence-free field from stream function:
```julia
ψ = y₂ * sin(πx/Lx) * sin(πy/Ly)
vx = ∂ψ/∂y,  vy = -∂ψ/∂x
```

#### Reaction Field (y₃)
Localized reaction zones:
```julia
R(x,y) = y₃ * [exp(-10*d₁²/Lx²) + exp(-10*d₂²/Lx²)]
```
where d₁, d₂ are distances to reaction centers.

#### Anisotropy (y₄)
```julia
anisotropy_ratio = exp(y₄)
```

### Multi-Sensor Objective Function

The inverse problem uses multiple sensor types:

```julia
J(θ) = Σᵢ(u_model(xᵢ) - u_measured(xᵢ))² +           # Concentration sensors
       Σⱼ(|∇u_model(xⱼ)| - |∇u_measured(xⱼ)|)² +     # Gradient sensors  
       Σₖ(|flux_model(xₖ)| - |flux_measured(xₖ)|)² +  # Flux sensors
       λ₁*TV(D) + λ₂*TV(v) + λ₃*TV(R) + λ₄*||y||²     # Regularization
```

## Basin Structure

The 4D problem creates multiple local minima through several compensation mechanisms:

### 1. Transport Mechanism Trade-offs
- **High Diffusion + Low Advection**: Spreading-dominated transport
- **Low Diffusion + High Advection**: Flow-dominated transport
- Both can produce similar sensor readings

### 2. Reaction vs Transport Balance
- **Transport-Dominated**: Fast transport, slow reaction
- **Reaction-Dominated**: Slow transport, fast reaction
- **Balanced Regimes**: Intermediate combinations

### 3. Anisotropy Effects
- **Isotropic**: Equal diffusion in all directions
- **Anisotropic**: Preferential diffusion directions
- Different anisotropy patterns can compensate for other mechanisms

### 4. Sensor Information Content
- Under-determined inverse problem allows multiple solutions
- Different sensor types provide different information
- Spatial distribution of sensors affects identifiability

## Usage

### Basic Usage

```julia
using LinearAlgebra
include("src/diffusion_problem.jl")

# Create synthetic problem
problem, θ_true = create_synthetic_diffusion_problem(
    n_params=100,
    grid_size=(21, 21),
    domain_size=(1.0, 1.0),
    n_sensors=10
)

# Construct objective function
objective = construct_4d_diffusion_objective(problem)

# Evaluate at true parameters
obj_value = objective(θ_true)
```

### With Globtim

```julia
using Globtim

# Define search domain
domain_bounds = [-2.0, 2.0]  # Box constraints

# Run basin detection
result = globtim_solve(objective, domain_bounds, options)
```

### Running the Example

```julia
# Run complete demonstration
include("src/example_usage.jl")

# This will:
# 1. Create a synthetic problem
# 2. Demonstrate the objective function
# 3. Show basin formation mechanisms
# 4. Analyze 4D active subspace structure
```

## File Structure

```
diffusion_inverse/
├── src/
│   ├── diffusion_problem.jl    # Main implementation
│   └── example_usage.jl        # Usage examples
├── test/
│   └── test_diffusion_problem.jl  # Unit tests
└── docs/
    └── README.md               # This file
```

## Key Functions

### Core Functions
- `construct_diffusion_tensor(y1, grid_size, domain_size)`: Build diffusion field
- `construct_velocity_field(y2, grid_size, domain_size)`: Build velocity field
- `construct_reaction_field(y3, grid_size, domain_size)`: Build reaction field
- `solve_transport_pde(...)`: Solve the forward PDE problem

### Objective Function
- `construct_4d_diffusion_objective(problem)`: Main objective function constructor
- `create_synthetic_diffusion_problem(...)`: Generate test problems

### Utilities
- `compute_gradients(u, grid_size, domain_size)`: Compute spatial gradients
- `compute_fluxes(...)`: Compute diffusive and advective fluxes
- `total_variation(field)`: Regularization term

## Testing

Run the test suite:

```julia
include("test/test_diffusion_problem.jl")
```

Tests cover:
- Field construction functions
- PDE solver accuracy
- Gradient and flux computations
- Objective function evaluation
- Error handling for edge cases

## Expected Basin Count

For typical parameters:
- **2-4 major basins**: Corresponding to different transport regimes
- **8-16 local minima**: Including compensation mechanisms
- **Basin depth**: Varies with sensor noise and regularization

The exact number depends on:
- Problem size and grid resolution
- Sensor placement and noise level
- Regularization parameter values
- Domain bounds for optimization

## Performance Notes

- **Grid size**: (21,21) is good for development, (51,51) for production
- **Parameter dimension**: 50-200 typical, up to 500 for stress testing
- **Sensor count**: 8-20 provides good information content
- **PDE solve**: O(n²) for direct solver, can be optimized for larger grids

## References

1. Multi-physics transport modeling in porous media
2. Inverse problems in groundwater hydrology
3. Medical imaging parameter estimation
4. Active subspace methods for high-dimensional problems
