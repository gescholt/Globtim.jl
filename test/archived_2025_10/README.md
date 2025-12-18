# Archived Tests - October 2025

This directory contains test files archived during the October 2025 repository cleanup.

## Archive Categories

- **drwatson_integration/**: Tests for abandoned DrWatson.jl integration (6 files)
- **visualization_development/**: Development tests for plotting/visualization (24 files)
- **modular_architecture/**: Experimental architecture tests not adopted (4 files)
- **launch_infrastructure/**: Tests for abandoned launch helpers (5 files)
- **development_experiments/**: One-off development test files
- **integration_snapshots/**: Timestamped integration test results (4 files)

## Why Were These Archived?

These test files were not included in the main test suite (`runtests.jl`) and fell into one of these categories:

1. **Development/Experimental Tests**: Created during development but not integrated into production
2. **Abandoned Features**: Tests for features that were explored but not adopted
3. **One-off Investigations**: Tests created for specific debugging or investigation purposes
4. **Duplicate/Variant Tests**: Multiple versions of similar tests

## Archive Statistics

- **Total files archived**: ~43 test files
- **Percentage of total tests**: ~25% of test files
- **Main test suite size**: 26 core tests remain active

## Restoration

If you need to restore any of these tests:

1. Move the file back to `test/`
2. Add appropriate `include()` to `test/runtests.jl` if needed
3. Update dependencies in `Project.toml` if required

Example:
```bash
# Restore a specific test
cp test/archived_2025_10/drwatson_integration/test_savename.jl test/
```

## Safe to Delete?

These tests can be safely deleted if:
- No issues arise from main test suite for 2+ months
- No features from archived tests are re-implemented
- All relevant functionality covered by current test suite

## Main Test Suite Verification

After archiving, the main test suite was verified to pass:
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Related Documentation

See `docs/repository_cleanup_2025_10.md` for the complete audit report and cleanup rationale.

---

**Archived Date**: 2025-10-20
**Archived By**: Claude Code
**Audit Report**: `docs/repository_cleanup_2025_10.md`
