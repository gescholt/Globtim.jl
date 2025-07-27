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
