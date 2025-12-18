# Generated Experiments

This directory contains auto-generated experiment scripts created from templates.

## Purpose

Experiments in this directory are programmatically generated (e.g., via MCP tools or automation scripts) and should **not be edited manually**.

## Usage

- Generated files follow the naming pattern: `{experiment_type}_deg{min}-{max}_domain{size}_GN{gridnodes}_{timestamp}.jl`
- These files are typically temporary and can be regenerated from templates
- **Note**: Generated experiment files (`*.jl`) are ignored by git (see `.gitignore`)

## Regeneration

To regenerate an experiment:
1. Use the appropriate template from the parent experiment directory
2. Run the generation tool/script with desired parameters
3. The new file will be created here with a fresh timestamp

## Cleanup

Generated files can be safely deleted - they can always be regenerated from templates when needed.
