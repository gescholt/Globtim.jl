#!/bin/bash
# Dependency Health Monitor Hook
# Issue #42 - HPC Infrastructure Analysis & New Hook System Recommendations
# 
# Purpose: Prevent JSON3/CSV package loading failures causing 88.2% HPC failure rate
# Phases: validation, monitoring
# Critical: true

set -e

# Hook metadata
HOOK_NAME="dependency_health_monitor"
HOOK_VERSION="1.0.0"
HOOK_PURPOSE="Prevent JSON3/CSV package loading failures"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration - Auto-detect environment
if [[ -d "/home/scholten/globtim" ]]; then
    GLOBTIM_DIR="/home/scholten/globtim"
    ENVIRONMENT="hpc"
else
    GLOBTIM_DIR="/Users/ghscholt/globtim"
    ENVIRONMENT="local"
fi

LOG_DIR="$GLOBTIM_DIR/tools/hpc/hooks/logs"
DEPENDENCY_CACHE="$GLOBTIM_DIR/.cache/dependency_health"
mkdir -p "$LOG_DIR" "$DEPENDENCY_CACHE"

# Logging functions
log_info() {
    echo -e "${BOLD}${GREEN}[DEPENDENCY-HEALTH]${NC} $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] [DEPENDENCY-HEALTH] $*" >> "$LOG_DIR/dependency_health.log"
}

log_warning() {
    echo -e "${BOLD}${YELLOW}[DEPENDENCY-HEALTH WARNING]${NC} $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] [DEPENDENCY-HEALTH] $*" >> "$LOG_DIR/dependency_health.log"
}

log_error() {
    echo -e "${BOLD}${RED}[DEPENDENCY-HEALTH ERROR]${NC} $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] [DEPENDENCY-HEALTH] $*" >> "$LOG_DIR/dependency_health.log"
}

log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${BOLD}${BLUE}[DEPENDENCY-HEALTH DEBUG]${NC} $*" >&2
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] [DEPENDENCY-HEALTH] $*" >> "$LOG_DIR/dependency_health.log"
}

# Core dependency health check functions
check_json3_health() {
    local test_result_file="$DEPENDENCY_CACHE/json3_health.json"
    local status="unknown"
    local details=""
    
    log_info "🔍 Checking JSON3 package health..."
    
    # Test JSON3 loading and functionality
    local test_output
    if test_output=$(julia --project="$GLOBTIM_DIR" -e "
        try
            using JSON3
            
            # Test basic functionality
            test_data = Dict(\"test\" => \"json3_health_check\", \"number\" => 42, \"array\" => [1,2,3])
            json_str = JSON3.write(test_data)
            parsed = JSON3.read(json_str, Dict)
            
            # Verify roundtrip
            if parsed[\"test\"] == \"json3_health_check\" && parsed[\"number\"] == 42 && length(parsed[\"array\"]) == 3
                println(\"SUCCESS: JSON3 fully functional\")
                exit(0)
            else
                println(\"ERROR: JSON3 functionality test failed\")
                exit(1)
            end
            
        catch e
            println(\"ERROR: JSON3 loading or functionality failed: \$e\")
            exit(1)
        end
    " 2>&1); then
        status="healthy"
        details="JSON3 package loaded and functional"
        log_info "✅ JSON3 health check: PASSED"
    else
        status="failed"
        details="JSON3 health check failed: $test_output"
        log_error "❌ JSON3 health check: FAILED"
        log_error "Details: $test_output"
    fi
    
    # Save health status
    cat > "$test_result_file" << EOF
{
    "package": "JSON3",
    "status": "$status",
    "details": "$details",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "test_output": "$test_output"
}
EOF
    
    [[ "$status" == "healthy" ]]
}

check_csv_extension_health() {
    local test_result_file="$DEPENDENCY_CACHE/csv_health.json"
    local status="unknown"
    local details=""
    
    log_info "🔍 Checking CSV extension health (weakdep configuration)..."
    
    # Test CSV extension loading and functionality
    local test_output
    if test_output=$(julia --project="$GLOBTIM_DIR" -e "
        try
            using CSV, DataFrames
            
            # Create test DataFrame
            test_df = DataFrame(
                x = [1, 2, 3, 4],
                y = [1.1, 2.2, 3.3, 4.4],
                z = [\"a\", \"b\", \"c\", \"d\"]
            )
            
            # Test CSV write/read roundtrip
            temp_file = tempname() * \".csv\"
            try
                CSV.write(temp_file, test_df)
                loaded_df = CSV.read(temp_file, DataFrame)
                
                # Verify data integrity
                if nrow(loaded_df) == 4 && ncol(loaded_df) == 3 && loaded_df.x == test_df.x
                    println(\"SUCCESS: CSV extension fully functional\")
                    exit(0)
                else
                    println(\"ERROR: CSV functionality test failed - data integrity issue\")
                    exit(1)
                end
            finally
                isfile(temp_file) && rm(temp_file)
            end
            
        catch e
            # Check if it's specifically a CSV loading issue
            if occursin(\"CSV\", string(e)) || occursin(\"extension\", string(e))
                println(\"ERROR: CSV extension loading failed: \$e\")
            else
                println(\"ERROR: CSV functionality test failed: \$e\")
            end
            exit(1)
        end
    " 2>&1); then
        status="healthy"
        details="CSV extension loaded and functional"
        log_info "✅ CSV extension health check: PASSED"
    else
        status="failed"
        details="CSV extension health check failed: $test_output"
        log_warning "⚠️  CSV extension health check: FAILED (this is a major cause of 88.2% failure rate)"
        log_warning "Details: $test_output"
        
        # This is a known issue with weakdep configurations
        if [[ "$test_output" =~ "ArgumentError: Package CSV not found" ]] || [[ "$test_output" =~ "extension" ]]; then
            log_warning "🔧 This appears to be the weakdep CSV extension loading issue"
            log_warning "Recommendation: Add CSV to direct dependencies instead of weakdeps"
        fi
    fi
    
    # Save health status
    cat > "$test_result_file" << EOF
{
    "package": "CSV",
    "status": "$status", 
    "details": "$details",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "test_output": "$test_output",
    "is_weakdep": true,
    "extension_name": "GlobtimDataExt"
}
EOF
    
    [[ "$status" == "healthy" ]]
}

check_globtim_extensions() {
    local test_result_file="$DEPENDENCY_CACHE/globtim_extensions_health.json"
    local status="unknown"
    local details=""
    
    log_info "🔍 Checking GlobTim extension loading..."
    
    # Test GlobTim extension functionality
    local test_output
    if test_output=$(julia --project="$GLOBTIM_DIR" -e "
        try
            using Globtim
            
            # Check if CSV-dependent functions are available
            if isdefined(Globtim, :load_data) && isdefined(Globtim, :save_data)
                println(\"SUCCESS: GlobtimDataExt extension functions available\")
                extension_status = \"loaded\"
            else
                println(\"WARNING: GlobtimDataExt extension functions not available\")
                extension_status = \"not_loaded\"
            end
            
            # Try to access the extension module directly
            if haskey(Base.loaded_modules, Base.PkgId(Base.UUID(\"a93c6f00-e57d-5684-b7b6-d8193f3e46c0\"), \"DataFrames\"))
                df_loaded = true
            else
                df_loaded = false
            end
            
            println(\"Extension status: \$extension_status\")
            println(\"DataFrames loaded: \$df_loaded\")
            
            if extension_status == \"loaded\"
                exit(0)
            else
                exit(1)
            end
            
        catch e
            println(\"ERROR: Globtim extension check failed: \$e\")
            exit(1)
        end
    " 2>&1); then
        status="healthy"
        details="GlobTim extensions loaded successfully"
        log_info "✅ GlobTim extensions check: PASSED"
    else
        status="failed"
        details="GlobTim extensions check failed: $test_output"
        log_warning "⚠️  GlobTim extensions check: FAILED"
        log_warning "Details: $test_output"
    fi
    
    # Save health status
    cat > "$test_result_file" << EOF
{
    "component": "globtim_extensions",
    "status": "$status",
    "details": "$details", 
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "test_output": "$test_output"
}
EOF
    
    [[ "$status" == "healthy" ]]
}

check_package_environment_consistency() {
    local test_result_file="$DEPENDENCY_CACHE/package_env_consistency.json"
    local status="unknown"
    local details=""
    
    log_info "🔍 Checking package environment consistency..."
    
    # Test package environment consistency
    local test_output
    if test_output=$(julia --project="$GLOBTIM_DIR" -e "
        using Pkg
        
        try
            # Check if Project.toml and Manifest.toml are consistent
            Pkg.instantiate()
            
            # Verify key packages are in the correct versions
            project_dict = Pkg.project().dependencies
            
            # Check critical packages
            critical_packages = [
                (\"JSON3\", Base.UUID(\"0f8b85d8-7281-11e9-16c2-39a750bddbf1\")),
                (\"JSON\", Base.UUID(\"682c06a0-de6a-54ab-a142-c8b1cf79cde6\")),
                (\"DataFrames\", Base.UUID(\"a93c6f00-e57d-5684-b7b6-d8193f3e46c0\"))
            ]
            
            missing_packages = []
            for (pkg_name, expected_uuid) in critical_packages
                if !haskey(project_dict, expected_uuid)
                    push!(missing_packages, pkg_name)
                end
            end
            
            if isempty(missing_packages)
                println(\"SUCCESS: Package environment consistent\")
                exit(0)
            else
                println(\"ERROR: Missing critical packages: \$(join(missing_packages, \", \"))\")
                exit(1)
            end
            
        catch e
            println(\"ERROR: Package environment consistency check failed: \$e\")
            exit(1)
        end
    " 2>&1); then
        status="healthy"
        details="Package environment is consistent"
        log_info "✅ Package environment consistency: PASSED"
    else
        status="failed"
        details="Package environment consistency check failed: $test_output"
        log_error "❌ Package environment consistency: FAILED"
        log_error "Details: $test_output"
    fi
    
    # Save health status
    cat > "$test_result_file" << EOF
{
    "component": "package_environment_consistency",
    "status": "$status",
    "details": "$details",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "test_output": "$test_output"
}
EOF
    
    [[ "$status" == "healthy" ]]
}

# Recovery and repair functions
attempt_dependency_repair() {
    log_info "🔧 Attempting dependency repair..."
    
    local repair_successful=false
    
    # Step 1: Try Pkg.instantiate() (addresses Issue #53)
    log_info "Step 1: Running Pkg.instantiate()..."
    if julia --project="$GLOBTIM_DIR" -e "using Pkg; Pkg.instantiate()" 2>/dev/null; then
        log_info "✅ Pkg.instantiate() completed successfully"
    else
        log_warning "⚠️  Pkg.instantiate() had issues"
    fi
    
    # Step 2: Try to explicitly add missing packages
    log_info "Step 2: Checking and adding missing packages..."
    julia --project="$GLOBTIM_DIR" -e "
        using Pkg
        
        # List of critical packages that should be available
        critical_packages = [\"JSON3\", \"CSV\", \"DataFrames\"]
        
        for pkg in critical_packages
            try
                eval(Meta.parse(\"using \$pkg\"))
                println(\"✅ \$pkg is available\")
            catch e
                println(\"⚠️  \$pkg not available, attempting to add...\")
                try
                    Pkg.add(pkg)
                    println(\"✅ Successfully added \$pkg\")
                catch add_error
                    println(\"❌ Failed to add \$pkg: \$add_error\")
                end
            end
        end
    " 2>&1 | tee "$LOG_DIR/dependency_repair.log"
    
    # Step 3: Verify repair was successful
    log_info "Step 3: Verifying repair..."
    if check_json3_health && check_csv_extension_health; then
        log_info "✅ Dependency repair successful!"
        repair_successful=true
    else
        log_error "❌ Dependency repair failed"
    fi
    
    # Save repair attempt log
    cat > "$DEPENDENCY_CACHE/repair_attempt.json" << EOF
{
    "repair_attempted": true,
    "repair_successful": $repair_successful,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "repair_log": "$(cat "$LOG_DIR/dependency_repair.log" | tr '\n' '\\n')"
}
EOF
    
    $repair_successful
}

generate_dependency_health_report() {
    local report_file="$LOG_DIR/dependency_health_report_$(date +%Y%m%d_%H%M%S).json"
    
    log_info "📊 Generating dependency health report..."
    
    # Collect all cached health results
    local json3_status="unknown"
    local csv_status="unknown"
    local extensions_status="unknown"
    local environment_status="unknown"
    
    # Read cached results if available
    if [[ -f "$DEPENDENCY_CACHE/json3_health.json" ]]; then
        json3_status=$(cat "$DEPENDENCY_CACHE/json3_health.json" | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
    fi
    
    if [[ -f "$DEPENDENCY_CACHE/csv_health.json" ]]; then
        csv_status=$(cat "$DEPENDENCY_CACHE/csv_health.json" | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
    fi
    
    if [[ -f "$DEPENDENCY_CACHE/globtim_extensions_health.json" ]]; then
        extensions_status=$(cat "$DEPENDENCY_CACHE/globtim_extensions_health.json" | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
    fi
    
    if [[ -f "$DEPENDENCY_CACHE/package_env_consistency.json" ]]; then
        environment_status=$(cat "$DEPENDENCY_CACHE/package_env_consistency.json" | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
    fi
    
    # Calculate overall health score
    local healthy_count=0
    local total_checks=4
    
    [[ "$json3_status" == "healthy" ]] && ((healthy_count++))
    [[ "$csv_status" == "healthy" ]] && ((healthy_count++))
    [[ "$extensions_status" == "healthy" ]] && ((healthy_count++))
    [[ "$environment_status" == "healthy" ]] && ((healthy_count++))
    
    local health_score=$((100 * healthy_count / total_checks))
    
    # Determine overall status
    local overall_status="critical"
    if [[ $health_score -ge 100 ]]; then
        overall_status="excellent"
    elif [[ $health_score -ge 75 ]]; then
        overall_status="good"
    elif [[ $health_score -ge 50 ]]; then
        overall_status="warning"
    fi
    
    # Generate comprehensive report
    cat > "$report_file" << EOF
{
    "hook_name": "$HOOK_NAME",
    "hook_version": "$HOOK_VERSION", 
    "purpose": "$HOOK_PURPOSE",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "overall_status": "$overall_status",
    "health_score": $health_score,
    "issue_reference": "#42 - HPC Infrastructure Analysis",
    "target_problem": "88.2% HPC experiment failure rate",
    "component_health": {
        "json3_package": "$json3_status",
        "csv_extension": "$csv_status",
        "globtim_extensions": "$extensions_status",
        "package_environment": "$environment_status"
    },
    "recommendations": [
        $(if [[ "$csv_status" != "healthy" ]]; then echo "\"Move CSV from weakdeps to direct dependencies in Project.toml\","; fi)
        $(if [[ "$json3_status" != "healthy" ]]; then echo "\"Investigate JSON3 package loading issues\","; fi)
        $(if [[ "$extensions_status" != "healthy" ]]; then echo "\"Fix GlobTim extension loading mechanism\","; fi)
        $(if [[ "$environment_status" != "healthy" ]]; then echo "\"Run Pkg.instantiate() to fix package environment\","; fi)
        "Monitor dependency health before each experiment"
    ]
}
EOF
    
    log_info "📊 Dependency health report saved to: $report_file"
    echo "$report_file"
}

# Main hook execution function
main() {
    local context="${1:-validation}"
    local exit_code=0
    
    log_info "🚀 Starting Dependency Health Monitor Hook"
    log_info "Context: $context"
    log_info "Purpose: Prevent JSON3/CSV loading failures (Issue #42)"
    log_info "Environment: $ENVIRONMENT"
    
    case "$context" in
        validation)
            log_info "🔍 Running dependency validation checks..."
            
            # Run all health checks
            local checks_passed=0
            local total_checks=4
            
            if check_json3_health; then
                ((checks_passed++))
            else
                log_error "JSON3 health check failed"
                exit_code=1
            fi
            
            if check_csv_extension_health; then
                ((checks_passed++))
            else
                log_warning "CSV extension health check failed (weakdep issue)"
                # Don't fail validation for CSV issues - attempt repair instead
            fi
            
            if check_globtim_extensions; then
                ((checks_passed++))
            else
                log_warning "GlobTim extensions check failed"
            fi
            
            if check_package_environment_consistency; then
                ((checks_passed++))
            else
                log_error "Package environment consistency check failed"
                exit_code=1
            fi
            
            # If critical checks failed, attempt repair
            if [[ $exit_code -ne 0 ]] || [[ $checks_passed -lt 3 ]]; then
                log_warning "⚠️  Dependency issues detected - attempting repair..."
                if attempt_dependency_repair; then
                    log_info "✅ Dependency repair successful - validation passed"
                    exit_code=0
                else
                    log_error "❌ Dependency repair failed - validation failed"
                    exit_code=1
                fi
            fi
            
            log_info "Validation checks passed: $checks_passed/$total_checks"
            ;;
            
        monitoring)
            log_info "📊 Running dependency monitoring checks..."
            
            # Lighter monitoring checks
            if check_json3_health && check_package_environment_consistency; then
                log_info "✅ Dependency monitoring: All critical dependencies healthy"
            else
                log_warning "⚠️  Dependency monitoring: Issues detected"
                exit_code=1
            fi
            ;;
            
        repair)
            log_info "🔧 Running dependency repair..."
            if attempt_dependency_repair; then
                log_info "✅ Dependency repair completed successfully"
            else
                log_error "❌ Dependency repair failed"
                exit_code=1
            fi
            ;;
            
        report)
            log_info "📊 Generating dependency health report..."
            local report_file
            report_file=$(generate_dependency_health_report)
            echo "Report saved to: $report_file"
            ;;
            
        *)
            log_error "Unknown context: $context"
            echo "Usage: $0 {validation|monitoring|repair|report}"
            exit 1
            ;;
    esac
    
    # Always generate a report for analysis
    generate_dependency_health_report >/dev/null
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "✅ Dependency Health Monitor Hook completed successfully"
    else
        log_error "❌ Dependency Health Monitor Hook completed with issues"
    fi
    
    exit $exit_code
}

# Execute main function
main "$@"