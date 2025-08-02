# GitLab CI/CD Guide for Globtim.jl

## Overview

The GitLab CI/CD pipeline automatically runs Julia tests and coverage analysis when you:
- Push to `main` or `clean-version` branches
- Create or update a merge request
- Manually trigger a pipeline

## Pipeline Structure

### Stages
1. **test** - Runs Julia tests on multiple versions
2. **coverage** - Generates coverage reports

### Jobs

#### `test:julia-1.11` (Primary)
- Runs full test suite with Julia 1.11
- Generates coverage data
- Produces JUnit test reports
- **Required to pass**

#### `test:julia-1.10` (Compatibility)
- Tests backward compatibility
- **Allowed to fail** (won't block pipeline)

#### `syntax-check` (Quick)
- Fast syntax validation
- Runs on every push
- **Allowed to fail**

#### `coverage` (Analysis)
- Processes test coverage data
- Generates LCOV reports
- Shows coverage percentage

## Features

### 🚀 Caching
- Julia packages cached between runs
- Faster subsequent pipelines
- Cache key based on branch and job

### 📊 Test Reports
- JUnit XML reports for test results
- Coverage reports in multiple formats
- Artifacts stored for 1 week

### 🔍 Coverage Integration
- Coverage percentage shown in MR
- Detailed line-by-line coverage
- LCOV format for external tools

## Pipeline Rules

| Event | Branches | Jobs Run |
|-------|----------|----------|
| Push | main, clean-version | All jobs |
| Push | other branches | syntax-check only |
| Merge Request | any → any | test + coverage |
| Manual | any | All jobs |

## Monitoring

### Command Line
```bash
# Check pipeline status
./scripts/pipeline-status.sh

# View latest pipeline logs
source .env.gitlab
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/pipelines/latest"
```

### Web Interface
- Pipelines: https://git.mpi-cbg.de/scholten/globtim/-/pipelines
- Jobs: Click on any pipeline to see individual jobs
- Artifacts: Download test reports and coverage data

## Troubleshooting

### Pipeline Not Starting
1. Check if `.gitlab-ci.yml` is committed
2. Verify you're pushing to a configured branch
3. Check GitLab runners are available

### Test Failures
1. Click on failed job for logs
2. Download artifacts for detailed reports
3. Run tests locally: `julia --project=@. -e 'using Pkg; Pkg.test()'`

### Coverage Issues
1. Ensure tests actually run code
2. Check Coverage.jl is in test dependencies
3. Look for syntax errors in coverage job

## Local Testing

Before pushing, test locally:
```bash
# Run tests
julia --project=@. -e 'using Pkg; Pkg.test()'

# Check syntax
find src -name "*.jl" -exec julia --syntax-check {} \;

# Generate coverage locally
julia --project=@. -e 'using Pkg; Pkg.test(coverage=true)'
```

## Best Practices

1. **Write tests first** - TDD helps maintain coverage
2. **Check locally** - Don't rely on CI to find issues
3. **Keep jobs fast** - Use caching effectively
4. **Monitor trends** - Track coverage over time
5. **Fix immediately** - Don't let failing tests accumulate

## Integration with Issues

Link pipelines to issues:
- Reference issue: `Fixes #123` in commit message
- Pipeline status shown in issue
- Automatic issue updates on pipeline completion
