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

# Documentation and Code Analysis
- Always record in a central location if you come across poorly documented functions (unclear data types, dead parameters, magic hardcoded values) -- not necessary to fix immediately, but needs to be investigated later
