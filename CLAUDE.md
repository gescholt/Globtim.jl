- To push to the public version, push main branch to github

# Branch Structure
- **Private development**: GitLab - `main` branch (local development)
- **Public release**: GitHub - `github-release` branch (should be set as default branch on GitHub)
- The `main` branch is for private development on GitLab
- The `github-release` branch contains the public version that should be registered with Julia

# Working with Jupyter Notebooks (.ipynb files)

When analyzing Jupyter notebooks:
1. Use the `NotebookRead` tool to read notebook contents
2. When you see "Outputs are too large to include", use `NotebookRead` with the `cell_id` parameter to read specific cell outputs
3. For editing notebooks, use the `NotebookEdit` tool instead of regular `Edit`
4. To execute notebook code, use the `mcp__ide__executeCode` tool if available
5. Pay attention to both the code cells and their outputs to understand the full context
6. Cell outputs may contain error messages, warnings, or successful execution results that are crucial for analysis

# Bug Fixing and Patterns
- When fixing bugs, document the underlying pattern or root cause in a compact, clear manner to build a repository of debugging insights

## Fixed Issues
- **Circular import in lambda_vandermonde_anisotropic.jl**: Fixed precompilation warnings caused by attempting to import functions from `.Globtim` while being included within the Globtim module itself. The functions are already available in the module scope when the file is included.
- **Test manifest inconsistencies**: Created automation scripts to fix Julia manifest warnings that occur when test/Manifest.toml diverges from the parent project's Manifest.toml. The scripts remove the test manifest and ensure the test environment uses the parent project's dependencies.
- **Automatic degree increase beyond bounds in tests**: When `test_input` is created with a `tolerance` parameter and `Constructor` is called with an initial degree, the Constructor will automatically increase the degree until it achieves the specified tolerance. This caused tests to exceed the degree bound of 14. **Pattern**: `TR = test_input(f, ..., tolerance = 1e-X); pol = Constructor(TR, initial_degree)`. **Fix**: Set the initial degree to the maximum allowed (14) to prevent auto-increment, or remove the tolerance parameter from test_input if the goal is to test a specific degree.
- **Default tolerance in test_input causing auto-increase**: The `test_input` function has a default tolerance of `2e-3` when not specified. This means even when tolerance is not explicitly set, it still triggers automatic degree increase in Constructor. **Pattern**: `TR = test_input(f, ...); pol = Constructor(TR, degree < 14)`. **Fix**: Explicitly set `tolerance = nothing` in test_input when you want to test a specific degree without auto-increase.

# Documentation and Code Analysis
- Always record in a central location if you come across poorly documented functions (unclear data types, dead parameters, magic hardcoded values) -- not necessary to fix immediately, but needs to be investigated later

# GitLab CI/CD Pipeline Usage

## Pipeline Overview
The GitLab CI/CD pipeline automatically runs tests on every push to `main` branch and on merge requests. It tests the code on Julia 1.10 and 1.11, and generates coverage reports.

## Checking Pipeline Status via API
We have GitLab API scripts to check pipeline status without accessing the web interface:

```bash
# Check recent pipeline statuses
source .env.gitlab && curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/pipelines?per_page=10" | jq '.[] | {id: .id, status: .status, ref: .ref, created_at: .created_at}'

# Get details of a specific pipeline's jobs
source .env.gitlab && curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/pipelines/PIPELINE_ID/jobs" | jq '.[] | {name: .name, status: .status, stage: .stage}'

# Get error logs from a failed job
source .env.gitlab && job_id=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/pipelines/PIPELINE_ID/jobs" | jq '.[] | select(.name=="JOB_NAME") | .id') && curl -s -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/jobs/$job_id/trace" | tail -50
```

## Pipeline Configuration
The pipeline is configured in `.gitlab-ci.yml` with the following stages:
- **test**: Runs Julia tests on versions 1.10 and 1.11, plus a syntax check
- **coverage**: Generates coverage reports after successful tests

### Important Configuration Details
- All jobs must specify `tags: [Ubuntu-docker]` to use Docker runners (otherwise they fail with "julia: command not found")
- The pipeline uses Julia Docker images (e.g., `image: julia:1.11`)
- Coverage reports are generated using the Coverage.jl package
- Test artifacts and coverage reports are kept for 1 week

## Available Scripts
- `scripts/gitlab-explore.sh`: Comprehensive GitLab project information including pipelines, issues, MRs
- `scripts/setup-gitlab-env.sh`: Sets up GitLab environment variables
- `scripts/get-gitlab-project-id.sh`: Gets the GitLab project ID

## Troubleshooting
- If pipelines fail with "julia: command not found", ensure the job has `tags: [Ubuntu-docker]`
- The `.env.gitlab` file must exist with proper API credentials for the scripts to work
