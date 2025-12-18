# Experiment Tracking Infrastructure Migration Plan

## Current State Analysis (September 22, 2025)

### Conflicting Systems Identified

1. **ExperimentPathTracker.jl** - Legacy comprehensive tracking system
2. **Dagger Execution Index** - Active but broken path storage
3. **Demo/Test Indexes** - Hybrid artifacts from testing

### Critical Issues Requiring Resolution

#### 1. Path Storage Inconsistency
- **Dagger Index Issue**: Stores `"/Users/ghscholt/globtimcore"` instead of full experiment paths
- **Impact**: Cannot locate experiment results, breaks path resolution
- **Priority**: CRITICAL

#### 2. Schema Incompatibility
- **ExperimentPathTracker**: Expects `experiment_type_exp{N}_range{X.X}_{YYYYMMDD_HHMMSS}`
- **Dagger Results**: Uses `dagger_*` naming patterns
- **Impact**: Systems cannot interoperate

#### 3. Multiple Index Files
- `dagger_execution_index.json` - Active Dagger tracking
- `demo_experiment_index.json` - Test artifact
- `dagger_test_index.json` - Test artifact
- Missing: `experiment_index.json` (ExperimentPathTracker expected file)

## Migration Strategy

### Phase 1: Archive Legacy Systems
1. Move ExperimentPathTracker.jl to legacy folder (keep for reference)
2. Archive test/demo index files
3. Create unified schema specification

### Phase 2: Fix Active System
1. Repair Dagger index path storage issue
2. Standardize metadata schema
3. Implement backward compatibility

### Phase 3: Consolidation
1. Single source of truth for experiment tracking
2. Unified metadata schema across all experiment types
3. Integration with hook orchestrator system

## Recommended Actions

### Immediate (High Priority)
- Fix dagger_execution_index.json path storage
- Archive test/demo artifacts
- Document unified schema

### Short Term
- Implement ExperimentPathTracker compatibility layer
- Standardize directory naming conventions
- Update hook orchestrator integration

### Long Term
- Single unified tracking system
- Automated migration tools
- Comprehensive testing framework