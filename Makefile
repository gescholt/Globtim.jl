# GlobTim Project - Convenient Commands
# Usage: make [target]

.PHONY: help summary analyze test clean deploy deploy-validate deploy-all deploy-git validate git-check auto-commit

help:
	@echo "📚 GlobTim Project Commands:"
	@echo ""
	@echo "Analysis:"
	@echo "  make summary           - Quick HPC results summary"
	@echo "  make analyze           - Analyze most recent results"
	@echo "  make collection        - Comprehensive collection analysis"
	@echo ""
	@echo "Testing:"
	@echo "  make test              - Run Julia tests"
	@echo ""
	@echo "HPC Deployment (Issue #140):"
	@echo "  make deploy            - Quick deploy (no validation)"
	@echo "  make deploy-validate   - Deploy with pre-flight validation (recommended)"
	@echo "  make deploy-git        - Git-aware deploy (Phase 2: prompts for commit)"
	@echo "  make deploy-all        - Complete workflow: git check → validate → deploy (legacy)"
	@echo "  make validate          - Run pre-flight validation only"
	@echo "  make git-check         - Check git status before deployment"
	@echo "  make auto-commit       - Auto-commit if 5+ files changed"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean             - Clean temporary files"
	@echo ""
	@echo "💡 Examples:"
	@echo "  make summary                                      # Quick overview"
	@echo "  make analyze FILE=path.json                       # Analyze specific file"
	@echo "  make deploy-validate EXP=experiments/.../exp2.jl  # Deploy with validation"
	@echo "  make deploy-git EXP=experiments/.../exp2.jl       # Git-aware deploy (Phase 2)"
	@echo "  make auto-commit                                  # Auto-commit if threshold met"

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

# ============================================================================
# HPC Deployment Targets (Issue #140 Phases 1 & 2)
# ============================================================================

# Check for required EXP variable
check-exp:
ifndef EXP
	@echo "❌ ERROR: EXP variable is required"
	@echo ""
	@echo "Usage:"
	@echo "  make deploy-validate EXP=experiments/path/to/experiment.jl"
	@echo ""
	@echo "Example:"
	@echo "  make deploy-validate EXP=experiments/daisy_ex3_4d_study/configs_20251006_160051/lotka_volterra_4d_exp2.jl"
	@exit 1
endif

# Quick deploy without validation
deploy: check-exp
	@echo "🚀 Deploying $(EXP) (no validation)"
	@./tools/hpc/deploy_to_hpc.sh $(EXP) --no-validate

# Deploy with pre-flight validation (recommended for Phase 1)
deploy-validate: check-exp
	@echo "🚀 Deploying $(EXP) with validation"
	@./tools/hpc/deploy_to_hpc.sh $(EXP)

# Git-aware deployment (Phase 2 - RECOMMENDED)
# Checks git status, prompts to commit if needed, records commit hash
deploy-git: check-exp
	@echo "🚀 Git-aware deployment of $(EXP)"
	@./tools/hpc/git_commit_and_deploy.sh $(EXP)

# Complete workflow: git check → validate → deploy (legacy - use deploy-git instead)
deploy-all: git-check deploy-validate
	@echo "✅ Complete deployment workflow finished"
	@echo "💡 TIP: Use 'make deploy-git' for improved git workflow (Phase 2)"

# Run pre-flight validation only
validate: check-exp
	@echo "🔍 Running pre-flight validation for $(EXP)"
	@if [ -f ./tools/hpc/hooks/experiment_preflight_validator.sh ]; then \
		./tools/hpc/hooks/experiment_preflight_validator.sh $(EXP); \
	else \
		echo "⚠️  Pre-flight validator not found"; \
		exit 1; \
	fi

# Check git status before deployment
git-check:
	@echo "🔍 Checking git status..."
	@if ! git diff-index --quiet HEAD --; then \
		echo "⚠️  WARNING: You have uncommitted changes"; \
		git status --short; \
		echo ""; \
		echo "Consider committing your changes before deployment for reproducibility"; \
		echo ""; \
		read -p "Continue anyway? [y/N] " -n 1 -r; \
		echo; \
		if [[ ! $$REPLY =~ ^[Yy]$$ ]]; then \
			echo "❌ Deployment cancelled"; \
			exit 1; \
		fi; \
	else \
		echo "✅ Git working directory is clean"; \
	fi

# Auto-commit if threshold met (Phase 2)
auto-commit:
	@echo "🔍 Checking for changes to auto-commit..."
	@./tools/git/auto_commit.sh