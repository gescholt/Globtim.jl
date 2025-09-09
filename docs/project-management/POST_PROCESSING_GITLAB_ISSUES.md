# GitLab Issues for Post-Processing Implementation

## Issue 1: Fix project-task-updater agent GitLab API communication
**Type**: bug  
**Priority**: high  
**Epic**: project-management  
**Labels**: type:bug, priority:high, epic:project-management

**Description**:
The project-task-updater agent is using incorrect protocol to communicate with GitLab API, causing failed token usage and API calls.

**Problem**: 
- Agent attempts to use GitLab API but fails with 401 Unauthorized
- Token retrieval works but subsequent API calls fail  
- Communication protocol mismatch between agent and GitLab

**Required Fix**:
- Review and fix project-task-updater agent GitLab API integration
- Ensure proper token usage in API calls
- Test GitLab issue creation and update functionality
- Document correct GitLab API communication protocol

**Acceptance Criteria**:
- [ ] project-task-updater agent can successfully create GitLab issues
- [ ] Agent can update existing issues without errors
- [ ] Token usage is correct and secure
- [ ] API communication protocol is documented

---

## Issue 2: Implement lightweight post-processing metrics for standardized examples
**Type**: feature  
**Priority**: high  
**Epic**: post-processing  
**Labels**: type:feature, priority:high, epic:post-processing  
**Milestone**: Short Term

**Description**:
Create functions to compute basic statistics from standardized example outputs without external dependencies.

**Current Standardized Outputs**:
- L2_norm: Final approximation error from polynomial construction
- condition_number: Numerical stability metric
- dimension, degree: Problem configuration  
- sample_range, total_samples: Sampling information
- center: Parameter center point
- CSV files: Function evaluation points and values

**Required Features**:
- Extract L2 norm improvements across degrees (when available)
- Compute distances from critical points to true solutions/local minima
- Basic convergence statistics
- Quality assessment based on L2 norm thresholds
- **Enhanced**: Track % decrease when multiple degrees available (not just absolute thresholds)
- Sampling efficiency analysis (sample/monomial ratios)

**Implementation Requirements**:
- Use only Julia standard library (no external dependencies)
- Work with existing JSON and CSV output formats
- Focus on computational outputs, not verbose analysis
- Build on actual standardized example architecture

**Acceptance Criteria**:
- [ ] Function to load and parse standard experiment outputs
- [ ] L2 norm quality classification with percentage improvement tracking
- [ ] Critical point distance computation utilities
- [ ] Sampling efficiency metrics
- [ ] Integration with hpc_minimal_2d_example.jl output format

---

## Issue 3: Create minimal computational results reporting
**Type**: feature  
**Priority**: medium  
**Epic**: post-processing  
**Labels**: type:feature, priority:medium, epic:post-processing  
**Milestone**: Short Term

**Description**:
Generate executable reports showing computation outputs and statistics in Julia script or notebook format.

**Report Requirements**:
- **Format**: Julia script or notebook (executable, not static markdown)
- **Content Focus**: Numerical outputs, minimal explanatory text
- **Key Outputs**:
  - Critical point distances to true solutions
  - L2 norm progression if multiple degrees available
  - Convergence statistics
  - Quality assessment results

**Anti-Requirements** (what to avoid):
- Verbose markdown reports with lots of text
- Non-executable documentation
- Complex plotting dependencies initially

**Implementation Approach**:
- Create executable Julia scripts that can be run to display results
- Focus on `println()` statements showing numerical results
- Use simple formatting for readability
- Design for easy integration with existing workflow

**Acceptance Criteria**:
- [ ] Executable Julia report script template
- [ ] Integration with standardized example outputs
- [ ] Numerical results display (distances, norms, statistics)
- [ ] Simple formatting without external dependencies
- [ ] Documentation on usage and customization

---

## Issue 4: Integrate post-processing with robust experiment runner
**Type**: enhancement  
**Priority**: medium  
**Epic**: hpc-automation  
**Labels**: type:enhancement, priority:medium, epic:hpc-automation  
**Milestone**: Short Term

**Description**:
Automatically call post-processing after successful experiment completion using existing HPC infrastructure.

**Integration Points**:
- Hook into robust_experiment_runner.sh completion
- Use existing HPC monitoring integration
- Generate reports in experiment temp directory
- Leverage existing tmux session framework

**Implementation Requirements**:
- Minimal changes to existing robust_experiment_runner.sh
- Automatic detection of successful experiment completion
- Post-processing execution only after validated success
- Integration with existing HPC resource monitor hooks
- Output reports to appropriate experiment directories

**Design Considerations**:
- Build on existing HPC infrastructure (don't duplicate)
- Use established experiment output formats
- Maintain compatibility with current workflow
- Provide option to disable post-processing if needed

**Acceptance Criteria**:
- [ ] Integration hook in robust_experiment_runner.sh
- [ ] Automatic post-processing trigger after experiment success
- [ ] Report generation in experiment output directory
- [ ] Optional post-processing disable flag
- [ ] No breaking changes to existing workflow
- [ ] Documentation on integration approach

---

## Issue 5: Prepare visualization framework for future plotting capabilities
**Type**: feature  
**Priority**: low  
**Epic**: visualization  
**Labels**: type:feature, priority:low, epic:visualization  
**Milestone**: Medium Term

**Description**:
Design extensible framework for future plotting capabilities, specifically L2-norm vs degree plots.

**Preparation Requirements**:
- Create interfaces for future plot generation
- L2-norm vs degree plot framework preparation
- Parameter space visualization readiness
- Integration points for CairoMakie/GLMakie when available

**Design Principles**:
- Extensible architecture for adding plots later
- Clean separation between data processing and visualization
- Optional plotting (graceful degradation when packages unavailable)
- Integration with existing post-processing metrics

**Future Plot Types** (to prepare for):
- L2-norm vs polynomial degree
- Condition number vs degree  
- Parameter space sampling visualization
- Convergence trajectory plots
- Comparative analysis across experiments

**Implementation Approach**:
- Abstract plotting interface
- Data preparation functions separate from plotting
- Plugin-style architecture for different plot types
- Configuration system for plot preferences

**Acceptance Criteria**:
- [ ] Abstract plotting interface design
- [ ] Data preparation functions for L2-norm vs degree plots
- [ ] Framework for optional plotting dependencies
- [ ] Integration points defined for future CairoMakie/GLMakie
- [ ] Documentation on extending visualization capabilities
- [ ] Example of how to add new plot types

---

## Implementation Order

1. **Issue 1**: Fix agent communication (blocker for automated management)
2. **Issue 2**: Core metrics computation (foundation)  
3. **Issue 3**: Executable reporting (immediate value)
4. **Issue 4**: Integration with experiment runner (automation)
5. **Issue 5**: Visualization preparation (future enhancement)

## GitLab Integration Notes

These issues should be created manually in GitLab at: https://git.mpi-cbg.de/scholten/globtim/-/issues

Each issue should include:
- Appropriate labels (type:feature/bug/enhancement, priority:high/medium/low, epic:post-processing/etc)
- Milestone assignment where specified
- Clear acceptance criteria checkboxes
- Reference to related issues where applicable