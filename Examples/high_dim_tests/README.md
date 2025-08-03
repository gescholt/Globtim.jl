# High-Dimensional Test Examples for Globtim

This directory contains implementations of three sophisticated 4D optimization problems designed to test Globtim's basin detection capabilities in higher dimensions. Each example features a 4D active subspace with multiple physical mechanisms that create complex basin structures.

## Directory Structure

```
high_dim_tests/
├── README.md                    # This file
├── tier2_4d_construction.md     # Detailed mathematical construction guide
├── diffusion_inverse/           # 4D Multi-physics transport inverse problem
│   ├── src/                     # Source code
│   ├── test/                    # Unit tests
│   └── docs/                    # Documentation
├── phononic_crystal/            # 4D Phononic crystal band gap optimization
│   ├── src/                     # Source code
│   ├── test/                    # Unit tests
│   └── docs/                    # Documentation
├── chemical_kinetics/           # 4D Chemical reaction parameter fitting
│   ├── src/                     # Source code
│   ├── test/                    # Unit tests
│   └── docs/                    # Documentation
└── shared/                      # Common utilities and framework
    ├── src/                     # Shared source code
    ├── test/                    # Shared tests
    └── docs/                    # Shared documentation
```

## The Three 4D Examples

### 1. Diffusion Inverse Problem (`diffusion_inverse/`)
**4D Active Subspace**: [Diffusion, Advection, Reaction, Anisotropy]

A multi-physics transport problem modeling groundwater flow or medical imaging scenarios. Features:
- Multi-physics PDE with diffusion, advection, reaction, and anisotropic effects
- Multi-sensor measurement system (concentration, gradient, flux sensors)
- Multiple compensation mechanisms creating distinct basins
- Regime switching between transport-dominated and reaction-dominated solutions

### 2. Phononic Crystal Optimization (`phononic_crystal/`)
**4D Active Subspace**: [Resonance, Geometry, Material, Symmetry]

Band gap optimization for phononic crystals with multiple design objectives. Features:
- Unit cell design with variable inclusion geometry and material properties
- Band structure computation via eigenvalue problems
- Multi-objective optimization (primary/secondary gaps, target frequency, manufacturability)
- Multiple gap formation mechanisms (resonance vs Bragg scattering)

### 3. Chemical Kinetics Parameter Fitting (`chemical_kinetics/`)
**4D Active Subspace**: [Low-T, High-T, Low-P, High-P]

Multi-regime catalytic reaction network parameter estimation. Features:
- Temperature and pressure dependent rate constants
- Multiple reaction pathways with regime switching
- Experimental data fitting across different operating conditions
- Compensation effects and pathway competition creating multiple minima

## Shared Framework (`shared/`)

Common utilities for all 4D examples:
- `construct_4d_basis()`: General 4D active subspace construction
- `multi_objective_4d()`: Multi-objective function framework
- Validation and testing utilities
- Visualization tools for 4D basin structures

## Key Design Principles

1. **4D Active Subspaces**: Each example has exactly 4 independent physical mechanisms
2. **Multiple Basins**: Different physical regimes create distinct local minima
3. **Realistic Physics**: Based on actual engineering/scientific applications
4. **Globtim Integration**: Designed to showcase basin detection capabilities
5. **Scalable Testing**: Fast-running examples for development, scalable for thorough testing

## Usage

Each example can be run independently:

```julia
# Load the specific example
include("diffusion_inverse/src/diffusion_problem.jl")

# Create the 4D objective function
objective = construct_4d_diffusion_objective(problem_parameters)

# Use with Globtim for basin detection
using Globtim
result = globtim_solve(objective, domain_bounds, options)
```

## Testing Strategy

1. **Unit Tests**: Individual component testing in each `test/` directory
2. **Integration Tests**: Full 4D problem validation
3. **Basin Validation**: Verify expected number and structure of basins
4. **Scalability Tests**: Performance across different problem sizes

## Development Status

- [x] Folder structure created
- [ ] Diffusion inverse problem implementation
- [ ] Phononic crystal optimization implementation  
- [ ] Chemical kinetics parameter fitting implementation
- [ ] Shared framework utilities
- [ ] Comprehensive testing suite
- [ ] Documentation and examples

## References

See `tier2_4d_construction.md` for detailed mathematical formulations and construction strategies for each example.
