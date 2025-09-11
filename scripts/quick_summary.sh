#!/bin/bash

# Quick HPC results summary script
# Usage: ./scripts/quick_summary.sh

echo "🔍 GlobTim HPC Results Quick Summary"
echo "===================================="

# Check if we're in the right directory
if [[ ! -f "Project.toml" ]]; then
    echo "❌ Run this from the globtim project root directory"
    exit 1
fi

# Show most recent results
echo "📁 Most recent HPC experiments:"
if [[ -d "hpc_results" ]]; then
    ls -la hpc_results/ | tail -5
else
    echo "❌ No hpc_results directory found"
    exit 1
fi

echo ""
echo "📊 Running comprehensive analysis..."
julia --project=. docs/hpc/analysis/scripts/comprehensive_collection_analysis.jl

echo ""
echo "💡 Quick commands:"
echo "  • Analyze specific result: julia scripts/analyze_results.jl path/to/result.json"
echo "  • Comprehensive analysis: julia scripts/analyze_results.jl comprehensive"
echo "  • Most recent result: julia scripts/analyze_results.jl"