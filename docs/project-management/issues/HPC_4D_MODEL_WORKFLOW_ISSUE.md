## 4D Model Experiments: HPC Workflow Validation and Experimental Setup

### Overview
This issue tracks the comprehensive setup and validation of our 4D model experiments on the r04n02 HPC compute node using the new tmux-based persistent execution framework for single-user compute node access.

### Objective
Develop a robust, validated workflow for running 4D polynomial approximation experiments on the HPC cluster, ensuring computational reliability and establishing a reproducible experimental pipeline.

### Labels
- `priority::high`
- `category::hpc-infrastructure`
- `phase::experimental-setup`
- `effort::large`
- `status::implemented`
- `ready-for-testing`

### Milestone
HPC 4D Model Experiments - Phase 1 Validation

### Phases and Detailed Tasks

#### Phase 1: tmux-Based Workflow Implementation ✅ UPDATED
- [x] Create tmux-based persistent execution framework
  - [x] Validate Julia availability (Julia 1.11.6 via juliaup)
  - [x] Confirm direct compute node execution
  - [x] Test tmux session management and persistence

- [x] Develop 2D Deuflhard example as workflow prototype
  - [x] Implement minimal working example from Deuflhard notebook
  - [x] Verify computational correctness
  - [x] Establish job timing and resource monitoring mechanisms

- [x] Output Collection and Analysis Infrastructure
  - [x] Design standardized output directory structure
  - [x] Create log collection and error tracking system
  - [x] Implement basic performance metrics extraction

### Implementation Status
- Phase 1: ✅ COMPLETE (September 2, 2025) - tmux-based framework operational
- Phase 2: 🚀 IN PROGRESS (September 15, 2025) - Minimal 4D example created and ready for HPC deployment
- All scripts created and documented
- Minimal 4D Lotka-Volterra example validated locally

### Files Created (Updated for tmux Framework)
- `hpc/experiments/robust_experiment_runner.sh` - Automated tmux session management
- `hpc/experiments/experiment_manager.jl` - Julia checkpointing system
- `hpc/experiments/test_2d_deuflhard.jl`
- `hpc/experiments/config_4d_model.jl`
- `hpc/monitoring/live_monitor.sh` - Real-time monitoring for tmux sessions
- `docs/hpc/ROBUST_WORKFLOW_GUIDE.md` - Complete tmux-based workflow documentation
- ✅ NEW: `tests/validation/lotka_volterra_4d_minimal.jl` - Minimal 4D Lotka-Volterra example (Sept 15, 2025)

#### Phase 2: 4D Model Experimental Setup
- [x] ✅ **PROGRESS UPDATE (September 15, 2025)**: Minimal 4D Lotka-Volterra Example Created
  - **File Created**: `tests/validation/lotka_volterra_4d_minimal.jl`
  - **Implementation**: Standard 5-step Globtim workflow following notebook patterns:
    1. `test_input()` - Grid generation with 4D Lotka-Volterra parameters
    2. `Constructor()` - Chebyshev polynomial approximation (degree=6)
    3. `solve_polynomial_system()` - Critical point solving using HomotopyContinuation.jl
    4. `process_crit_pts()` - Critical point processing and bounds checking
    5. `analyze_critical_points()` - Final analysis with optimization identification
  - **Safe 4D Parameters**: dim=4, degree=6, samples=12 per dimension (20,736 total grid points)
  - **Memory Optimization**: Uses safe parameters validated from Issue #70 memory fixes
  - **Diagnostic Output**: Essential prints for validation without excessive verbosity

- [ ] Parameter Configuration Framework
  - [x] Define initial testing parameters (completed with minimal example)
    - Sample size: 12 samples per dimension (optimized from memory analysis)
    - Domain: Safe 4D experimental domain with center=[0,0,0,0], range=2.0
    - Parameters: [1.2, 1.1, 1.05, 0.95] for 4D Lotka-Volterra system
  - [ ] Create parameter sweep configuration mechanism
  - [ ] Implement parameter validation checks

- [ ] Numerical Stability Analysis
  - Monitor matrix conditioning numbers
  - Develop conditioning number tracking and logging
  - Set up automatic conditioning number threshold alerts

- [ ] Approximant Comparison Framework
  - Design infrastructure for dense vs sparse polynomial approximant comparison
  - Create comparative metrics and logging system
  - Implement automated result aggregation

### Acceptance Criteria
1. Successfully execute persistent Julia experiments on r04n02 using tmux framework
2. Demonstrate 2D Deuflhard example working end-to-end with checkpoint recovery
3. Establish robust output collection and real-time monitoring mechanism
4. Develop flexible 4D parameter configuration system
5. Create comparative framework for dense/sparse approximants
6. Validate numerical stability tracking for matrix operations

### Risks and Mitigation
- **Risk**: Computational resource constraints
  - Mitigation: Implement incremental scaling, start with small samples
- **Risk**: Numerical instability in 4D experiments
  - Mitigation: Rigorous conditioning number monitoring
  - Fallback: Adaptive parameter adjustment mechanisms

### Documentation Requirements
- ✅ Updated `docs/hpc/ROBUST_WORKFLOW_GUIDE.md` with tmux-based execution framework
- ✅ Updated `docs/hpc/HPC_DIRECT_NODE_MIGRATION_PLAN.md` with current infrastructure
- Create new document `docs/hpc/4D_MODEL_WORKFLOW_VALIDATION.md` to track experimental methodology

### Expected Outcomes
- Complete, reproducible workflow for 4D polynomial approximation experiments
- Validated computational infrastructure on r04n02
- Comprehensive performance and stability tracking system

### Next Steps
- [x] Review current HPC infrastructure readiness
- [x] Validate Julia environment on compute node (Julia 1.11.6 via juliaup)
- [x] Implement tmux-based persistent execution framework
- [x] ✅ Create minimal 4D Lotka-Volterra example (COMPLETED Sept 15, 2025)
- [ ] 🚀 **IMMEDIATE NEXT STEPS** (Ready for HPC Deployment):
  1. Deploy `lotka_volterra_4d_minimal.jl` to r04n02 HPC node
  2. Execute validation test to confirm approximant construction completes
  3. Verify HomotopyContinuation successfully finds critical points in 4D
  4. Validate L2 norm computation and memory optimization fixes are working
  5. Confirm end-to-end 4D mathematical pipeline functionality
- [ ] ✅ Framework ready for comprehensive HPC testing
- [ ] 🔄 Initiate full 4D model experimental workflow using tmux sessions
- [ ] 🎯 Begin detailed performance and stability analysis with live monitoring

### Estimated Timeline
- Week 1-2: Infrastructure setup and 2D prototype
- Week 3-4: 4D parameter framework development
- Week 5: Comprehensive testing and validation

/label ~infrastructure ~hpc ~experiments
/milestone 4D-Model-Experiments-Phase1