# GlobTim Project - Convenient Commands
# Usage: make [target]

.PHONY: help summary analyze test clean

help:
	@echo "📚 GlobTim Project Commands:"
	@echo "  make summary    - Quick HPC results summary"
	@echo "  make analyze    - Analyze most recent results"
	@echo "  make collection - Comprehensive collection analysis"  
	@echo "  make test      - Run Julia tests"
	@echo "  make clean     - Clean temporary files"
	@echo ""
	@echo "💡 Examples:"
	@echo "  make summary                    # Quick overview"
	@echo "  make analyze FILE=path.json     # Analyze specific file"
	@echo "  julia scripts/analyze_results.jl comprehensive"

summary:
	@./scripts/quick_summary.sh

analyze:
ifdef FILE
	@julia --project=. scripts/analyze_results.jl $(FILE)
else
	@julia --project=. scripts/analyze_results.jl
endif

collection:
	@julia --project=. docs/hpc/analysis/scripts/comprehensive_collection_analysis.jl

test:
	@julia --project=. -e "using Pkg; Pkg.test()"

clean:
	@rm -f *_report.txt
	@rm -rf .julia_cache
	@echo "🧹 Cleaned temporary files"