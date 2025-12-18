#!/usr/bin/env bash
# Wrapper script to run lv4d_experiment.jl without Julia 1.12 world age warnings
#
# Usage:
#   ./run_lv4d_clean.sh --GN 6 --degree-range 4:5 --domain 0.1 --basis chebyshev --seed 42
#
# The warnings are cosmetic and don't affect correctness. They occur because DynamicalSystems.jl
# is loaded dynamically at runtime via include(). Future fix: make it a precompiled module.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Suppress world age warnings by redirecting stderr through grep filter
# Filter out all lines related to world age warnings (WARNING lines and all hint/context lines)
julia --project="$PROJECT_ROOT" "$SCRIPT_DIR/lv4d_experiment.jl" "$@" 2>&1 | grep -v -E "(WARNING: Detected access to binding|world prior to its definition|Julia 1.12 has introduced|This code may malfunction|This code will error|Hint: Add an appropriate|To make this warning an error|depwarn=error)" >&2
