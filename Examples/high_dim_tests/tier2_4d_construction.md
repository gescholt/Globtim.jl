# Detailed 4D Objective Function Construction for Tier 2 Examples

## Overview: Achieving 4D Active Subspaces

**Short Answer**: Yes, we can definitely design these problems to have 4D active subspaces! The dimensionality is not fixed at 2-3D - it depends on the intrinsic complexity of the physical system and how we parameterize the problem.

**Key Insight**: The active subspace dimension equals the number of **independent physical mechanisms** that significantly affect the objective function.

---

## Example 1: 4D Diffusion Inverse Problem

### Physical Setup: Multi-Physics Transport
Instead of simple diffusion, consider a realistic groundwater/medical imaging scenario with 4 independent transport mechanisms:

```julia
# 4D Active Subspace: [Diffusion, Advection, Reaction, Anisotropy]
function construct_4d_diffusion_objective(θ)  # θ ∈ ℝ¹⁰⁰
    
    # === STEP 1: Design 4D Active Subspace ===
    # Manually design the active directions (in practice, these are discovered)
    W_active = [
        # Basis functions weighted by physical importance
        w1_diffusion,    # Overall diffusion strength
        w2_advection,    # Flow velocity field
        w3_reaction,     # Source/sink terms  
        w4_anisotropy    # Directional preferences
    ]  # 100×4 matrix
    
    # Project parameters to 4D active space
    y = W_active' * θ  # y ∈ ℝ⁴
    
    # === STEP 2: Construct Multi-Physics PDE ===
    # ∂u/∂t = ∇·(D(y)∇u) - v(y)·∇u + R(y)u + S(x,y)
    
    # Dimension 1: Diffusion tensor
    D_field = construct_diffusion_tensor(y[1])
    
    # Dimension 2: Advection velocity  
    v_field = construct_velocity_field(y[2])
    
    # Dimension 3: Reaction coefficient
    R_field = construct_reaction_field(y[3])
    
    # Dimension 4: Anisotropy ratio
    anisotropy_ratio = exp(y[4])  # Controls D_xx/D_yy ratio
    
    # === STEP 3: Solve Forward Problem ===
    pde_solution = solve_transport_pde(D_field, v_field, R_field, anisotropy_ratio)
    
    # === STEP 4: Multi-Sensor Objective ===
    # Different sensors measure different physics
    diffusion_sensors = norm(pde_solution[diffusion_locations] - diffusion_measurements)^2
    concentration_sensors = norm(pde_solution[concentration_locations] - concentration_measurements)^2
    gradient_sensors = norm(compute_gradients(pde_solution)[gradient_locations] - gradient_measurements)^2
    flux_sensors = norm(compute_fluxes(pde_solution)[flux_locations] - flux_measurements)^2
    
    total_error = diffusion_sensors + concentration_sensors + gradient_sensors + flux_sensors
    
    # === STEP 5: Regularization ===
    # Encourage smoothness in each physical field
    regularization = λ₁*total_variation(D_field) + λ₂*total_variation(v_field) + 
                    λ₃*total_variation(R_field) + λ₄*norm(y)^2
    
    return total_error + regularization
end
```

### 4D Basin Structure
Each dimension creates different compensation mechanisms:

1. **High Diffusion + Low Advection**: Spreading dominates transport
2. **Low Diffusion + High Advection**: Flow dominates transport  
3. **High Reaction + Balanced Transport**: Local chemistry important
4. **Anisotropic + Moderate Parameters**: Directional effects dominate

### Multiple Minima Sources
- **Regime switching**: Different transport mechanisms dominate in different parameter regions
- **Sensor information content**: Under-determined inverse problem allows multiple solutions
- **Physical compensation**: Different combinations of D, v, R, anisotropy produce similar sensor readings

---

## Example 2: 4D Phononic Crystal Optimization

### Physical Setup: Multi-Scale Band Gap Design
Design phononic crystals considering 4 independent design aspects:

```julia
# 4D Active Subspace: [Resonance, Geometry, Material, Symmetry]
function construct_4d_phononic_objective(θ)  # θ ∈ ℝ²⁰⁰
    
    # === STEP 1: 4D Active Subspace Design ===
    W_active = [
        w1_resonance,    # Primary resonant frequency
        w2_geometry,     # Inclusion shape complexity
        w3_material,     # Material contrast ratio
        w4_symmetry      # Symmetry breaking parameter
    ]  # 200×4 matrix
    
    y = W_active' * θ  # y ∈ ℝ⁴
    
    # === STEP 2: Construct Unit Cell ===
    # Dimension 1: Resonance frequency (controls inclusion size)
    inclusion_size = decode_size_from_resonance(y[1])
    
    # Dimension 2: Geometric complexity
    inclusion_shape = decode_shape_complexity(y[2])  # circle → square → star → fractal
    
    # Dimension 3: Material properties
    density_ratio = exp(y[3])      # ρ_inclusion/ρ_matrix
    stiffness_ratio = exp(2*y[3])  # E_inclusion/E_matrix (related by scaling)
    
    # Dimension 4: Symmetry operations
    symmetry_breaking = y[4]  # 0 = symmetric, ±1 = various asymmetries
    
    # === STEP 3: Build Phononic Crystal ===
    unit_cell = PhononicUnitCell(
        inclusion_geometry = create_inclusion(inclusion_shape, inclusion_size, symmetry_breaking),
        material_properties = MaterialPair(density_ratio, stiffness_ratio),
        lattice_structure = "square"  # Could also be active dimension
    )
    
    # === STEP 4: Compute Band Structure ===
    # Solve eigenvalue problem: (K - ω²M)φ = 0
    k_points = generate_brillouin_zone_sampling()
    eigenfrequencies = compute_dispersion_relation(unit_cell, k_points)
    
    # === STEP 5: Multi-Objective Band Gap Optimization ===
    band_gaps = find_frequency_gaps(eigenfrequencies)
    
    # Multiple objectives create multiple minima
    primary_gap_width = band_gaps[1].width          # First band gap
    secondary_gap_width = band_gaps[2].width        # Second band gap  
    gap_center_frequency = band_gaps[1].center      # Target frequency
    manufacturing_constraint = assess_manufacturability(unit_cell)
    
    # Weighted multi-objective
    objective = -(w₁*primary_gap_width + w₂*secondary_gap_width + 
                  w₃*exp(-abs(gap_center_frequency - target_freq)) +
                  w₄*manufacturing_constraint)
    
    return objective
end
```

### 4D Basin Structure
1. **Resonance-Based Gaps**: Low-frequency local resonances
2. **Bragg Scattering Gaps**: High-frequency scattering effects
3. **Hybrid Mechanisms**: Combined resonance + scattering
4. **Symmetry-Broken Solutions**: Asymmetric but wider gaps

### Multiple Minima Mechanisms
- **Gap formation physics**: Resonance vs Bragg scattering create distinct solutions
- **Frequency targeting**: Different approaches to achieve same target frequency
- **Manufacturing trade-offs**: Simple high-performance vs complex manufacturable designs

---

## Example 3: 4D Chemical Kinetics Parameter Fitting  

### Physical Setup: Multi-Regime Reaction Network
Consider a catalytic reaction with 4 operating regimes:

```julia
# 4D Active Subspace: [Low-T, High-T, Low-P, High-P]
function construct_4d_kinetics_objective(θ)  # θ ∈ ℝ⁵⁰⁰
    
    # === STEP 1: 4D Regime-Based Active Subspace ===
    # Each dimension represents different operating conditions
    W_active = [
        w1_low_temp,     # Rate constants effective at low temperature
        w2_high_temp,    # Rate constants effective at high temperature  
        w3_low_pressure, # Pressure-dependent reaction pathways
        w4_high_pressure # High-pressure mechanism changes
    ]  # 500×4 matrix
    
    y = W_active' * θ  # y ∈ ℝ⁴
    
    # === STEP 2: Regime-Dependent Rate Constants ===
    # A → B → C (main pathway)
    # A → D     (side reaction)
    # B + E → F (catalyst effect)
    
    # Temperature dependence: k(T) = A*exp(-E/RT)
    function compute_rate_constants(T, P, y)
        # Low temperature regime (y[1])
        k1_low = y[1] * exp(-E1_low/(R*T))    # A → B (low T pathway)
        k2_low = y[1] * exp(-E2_low/(R*T))    # B → C (low T pathway)
        
        # High temperature regime (y[2])  
        k1_high = y[2] * exp(-E1_high/(R*T))  # A → B (high T pathway)
        k2_high = y[2] * exp(-E2_high/(R*T))  # B → C (high T pathway)
        
        # Pressure effects (y[3], y[4])
        k_side = y[3] * P^α * exp(-E_side/(R*T))     # A → D (pressure dependent)
        k_cat = y[4] * (P/(1+K*P)) * exp(-E_cat/(R*T)) # B + E → F (Langmuir-Hinshelwood)
        
        # Regime blending (creates smooth transitions)
        temp_blend = sigmoid((T - T_switch)/T_width)
        pressure_blend = sigmoid((P - P_switch)/P_width)
        
        k1_eff = (1-temp_blend)*k1_low + temp_blend*k1_high
        k2_eff = (1-temp_blend)*k2_low + temp_blend*k2_high
        k_side_eff = (1-pressure_blend)*k_side + pressure_blend*k_cat
        
        return [k1_eff, k2_eff, k_side_eff, k_cat]
    end
    
    # === STEP 3: Solve Kinetics ODEs ===
    total_error = 0.0
    
    for (T, P, t_span, initial_conc, experimental_data) in experimental_conditions
        # Get rate constants for this T, P
        k_values = compute_rate_constants(T, P, y)
        
        # Solve ODEs: dc/dt = f(c, k)
        # dc_A/dt = -k1*c_A - k_side*c_A
        # dc_B/dt = k1*c_A - k2*c_B - k_cat*c_B*c_E  
        # dc_C/dt = k2*c_B
        # dc_D/dt = k_side*c_A
        # dc_F/dt = k_cat*c_B*c_E
        
        solution = solve_ode_system(k_values, initial_conc, t_span)
        
        # Compare with experimental data
        model_concentrations = interpolate_solution(solution, experimental_times)
        error = norm(model_concentrations - experimental_data)^2
        total_error += error
    end
    
    # === STEP 4: Physical Constraints ===
    # Rate constants must be positive
    constraint_penalty = sum(max(0, -y[i])^2 for i in 1:4) * 1000
    
    # Arrhenius parameters should be reasonable
    physical_penalty = assess_physical_reasonableness(y)
    
    return total_error + constraint_penalty + physical_penalty
end
```

### 4D Basin Structure
1. **Low-T Dominated**: Slow, selective reactions
2. **High-T Dominated**: Fast, less selective reactions  
3. **Pressure-Limited**: Mass transfer controlled
4. **Catalyst-Limited**: Surface reaction controlled

### Multiple Minima Mechanisms
- **Compensation effects**: Different (A,E) pairs give same k at operating temperature
- **Regime dominance**: Different rate-limiting steps under different conditions
- **Pathway competition**: Main pathway vs side reactions can switch dominance

---

## General Strategy for 4D Design

### 1. Identify 4 Independent Physical Mechanisms
- **Transport**: Diffusion, advection, reaction, dispersion
- **Wave Physics**: Resonance, scattering, dispersion, nonlinearity  
- **Chemical**: Temperature, pressure, concentration, catalyst effects

### 2. Construct Basis Functions for Each Mechanism
```julia
# Example: 4D basis construction
function construct_4d_basis(domain, n_total=100)
    n_per_dimension = n_total ÷ 4
    
    # Mechanism 1: Low-frequency modes
    basis_1 = [fourier_mode(k) for k in 1:n_per_dimension]
    
    # Mechanism 2: High-frequency modes  
    basis_2 = [fourier_mode(k) for k in (n_per_dimension+1):(2*n_per_dimension)]
    
    # Mechanism 3: Localized features
    basis_3 = [gaussian_rbf(center, width) for center in grid_points[1:n_per_dimension]]
    
    # Mechanism 4: Boundary effects
    basis_4 = [boundary_mode(k) for k in 1:n_per_dimension]
    
    return [basis_1; basis_2; basis_3; basis_4]
end
```

### 3. Multi-Objective Function Design
```julia
# Create multiple objectives that depend on different mechanisms
function multi_objective_4d(y)  # y ∈ ℝ⁴
    obj1 = mechanism_1_objective(y[1])    # Depends primarily on y[1]
    obj2 = mechanism_2_objective(y[2])    # Depends primarily on y[2]  
    obj3 = mechanism_3_objective(y[3])    # Depends primarily on y[3]
    obj4 = mechanism_4_objective(y[4])    # Depends primarily on y[4]
    
    # Cross-coupling creates basin structure
    coupling_12 = interaction_term(y[1], y[2])
    coupling_34 = interaction_term(y[3], y[4])
    
    return w1*obj1 + w2*obj2 + w3*obj3 + w4*obj4 + w12*coupling_12 + w34*coupling_34
end
```

### 4. Validation Strategy
- **Synthetic data**: Generate data from known 4D structure, verify recovery
- **Dimensionality tests**: Compare 2D, 3D, 4D, 5D active subspaces
- **Basin counting**: Use globtim to count distinct minima in each dimension

## Key Advantage of 4D

**4D is optimal for globtim**: 
- **2D-3D**: May be too simple, miss important basin structure
- **4D**: Rich enough for complex physics, still tractable for basin exploration
- **5D+**: Becomes difficult for comprehensive basin detection

**Basin visualization**: 4D allows projection to 3D for visualization while maintaining rich structure.

The 4D construction gives you enough complexity to capture realistic multi-physics behavior while remaining computationally tractable for your basin detection strategy with globtim.