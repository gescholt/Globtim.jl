#!/bin/bash
# Script Discovery System - Pre-Execution Validation Component
# Part of Issue #27: Implement Pre-Execution Validation Hook System
# Eliminates "script not found" errors through intelligent multi-location search

set -e

# Configuration
GLOBTIM_ROOT="/home/scholten/globtim"
LOCAL_GLOBTIM_ROOT="/Users/ghscholt/globtim"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[SCRIPT-DISCOVERY]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

# Determine the correct root path (local vs HPC)
get_project_root() {
    if [[ -d "$GLOBTIM_ROOT" ]]; then
        echo "$GLOBTIM_ROOT"
    elif [[ -d "$LOCAL_GLOBTIM_ROOT" ]]; then
        echo "$LOCAL_GLOBTIM_ROOT"
    else
        error "Cannot find GlobTim project root directory"
        return 1
    fi
}

# Standard search locations for experiment scripts
get_search_locations() {
    local project_root="$1"
    
    # Priority order: most specific to most general
    echo "$project_root/Examples"
    echo "$project_root/hpc/experiments"
    echo "$project_root/examples"
    echo "$project_root/test"
    echo "$project_root/scripts"
    echo "$project_root"
}

# Search for script by name across multiple locations
search_script_by_name() {
    local script_name="$1"
    local project_root="$2"
    local found_scripts=()
    
    log "Searching for script: $script_name"
    
    # Get search locations
    while IFS= read -r location; do
        if [[ -d "$location" ]]; then
            info "Searching in: $location"
            
            # Direct match first
            if [[ -f "$location/$script_name" ]]; then
                found_scripts+=("$location/$script_name")
                log "Found exact match: $location/$script_name"
            fi
            
            # Recursive search for .jl files
            while IFS= read -r -d '' found_file; do
                local basename_file=$(basename "$found_file")
                if [[ "$basename_file" == "$script_name" ]]; then
                    found_scripts+=("$found_file")
                    log "Found recursive match: $found_file"
                fi
            done < <(find "$location" -name "*.jl" -type f -print0 2>/dev/null || true)
        fi
    done <<< "$(get_search_locations "$project_root")"
    
    # Return results
    if [[ ${#found_scripts[@]} -eq 0 ]]; then
        return 1
    else
        printf '%s\n' "${found_scripts[@]}"
        return 0
    fi
}

# Search for scripts matching a pattern
search_script_by_pattern() {
    local pattern="$1"
    local project_root="$2"
    local found_scripts=()
    
    log "Searching for scripts matching pattern: $pattern"
    
    while IFS= read -r location; do
        if [[ -d "$location" ]]; then
            info "Pattern searching in: $location"
            
            while IFS= read -r -d '' found_file; do
                local basename_file=$(basename "$found_file")
                if [[ "$basename_file" == *"$pattern"* ]]; then
                    found_scripts+=("$found_file")
                    log "Found pattern match: $found_file"
                fi
            done < <(find "$location" -name "*.jl" -type f -print0 2>/dev/null || true)
        fi
    done <<< "$(get_search_locations "$project_root")"
    
    if [[ ${#found_scripts[@]} -eq 0 ]]; then
        return 1
    else
        printf '%s\n' "${found_scripts[@]}"
        return 0
    fi
}

# Validate script exists and is executable
validate_script() {
    local script_path="$1"
    
    if [[ ! -f "$script_path" ]]; then
        error "Script not found: $script_path"
        return 1
    fi
    
    if [[ ! -r "$script_path" ]]; then
        error "Script not readable: $script_path"
        return 1
    fi
    
    # Check if it's a Julia script
    if [[ ! "$script_path" =~ \.jl$ ]]; then
        warning "Script does not have .jl extension: $script_path"
    fi
    
    log "Script validation passed: $script_path"
    return 0
}

# Get absolute path for script
resolve_absolute_path() {
    local script_path="$1"
    
    if [[ "$script_path" = /* ]]; then
        # Already absolute
        echo "$script_path"
    else
        # Make it absolute based on current directory
        echo "$(pwd)/$script_path"
    fi
}

# Main script discovery function
discover_script() {
    local script_input="$1"
    local project_root
    
    if ! project_root=$(get_project_root); then
        return 1
    fi
    
    log "Project root: $project_root"
    log "Input: $script_input"
    
    # Case 1: Absolute path provided
    if [[ "$script_input" = /* ]]; then
        if validate_script "$script_input"; then
            echo "$script_input"
            return 0
        else
            return 1
        fi
    fi
    
    # Case 2: Relative path that exists from current directory
    if [[ -f "$script_input" ]]; then
        local abs_path
        abs_path=$(resolve_absolute_path "$script_input")
        if validate_script "$abs_path"; then
            echo "$abs_path"
            return 0
        fi
    fi
    
    # Case 3: Search by exact name
    local found_scripts
    if found_scripts=$(search_script_by_name "$script_input" "$project_root"); then
        # If multiple found, return the first one but warn about others
        local first_script
        first_script=$(echo "$found_scripts" | head -n1)
        
        local script_count
        script_count=$(echo "$found_scripts" | wc -l)
        
        if [[ $script_count -gt 1 ]]; then
            warning "Multiple scripts found matching '$script_input':"
            echo "$found_scripts" | while IFS= read -r script; do
                warning "  - $script"
            done
            warning "Using first match: $first_script"
        fi
        
        echo "$first_script"
        return 0
    fi
    
    # Case 4: Search by pattern (partial name match)
    if found_scripts=$(search_script_by_pattern "$script_input" "$project_root"); then
        local first_script
        first_script=$(echo "$found_scripts" | head -n1)
        
        local script_count
        script_count=$(echo "$found_scripts" | wc -l)
        
        warning "No exact match found for '$script_input', using pattern matching:"
        if [[ $script_count -gt 1 ]]; then
            warning "Multiple pattern matches found:"
            echo "$found_scripts" | while IFS= read -r script; do
                warning "  - $script"
            done
            warning "Using first match: $first_script"
        else
            warning "Pattern match: $first_script"
        fi
        
        echo "$first_script"
        return 0
    fi
    
    # Case 5: No matches found
    error "Script not found: $script_input"
    error "Searched locations:"
    while IFS= read -r location; do
        if [[ -d "$location" ]]; then
            error "  - $location"
        else
            error "  - $location (does not exist)"
        fi
    done <<< "$(get_search_locations "$project_root")"
    
    return 1
}

# List all available scripts
list_available_scripts() {
    local project_root
    
    if ! project_root=$(get_project_root); then
        return 1
    fi
    
    log "Available Julia scripts in project:"
    
    while IFS= read -r location; do
        if [[ -d "$location" ]]; then
            info "📁 $location:"
            
            while IFS= read -r -d '' script_file; do
                local relative_path=${script_file#$project_root/}
                echo "  📄 $relative_path"
            done < <(find "$location" -name "*.jl" -type f -print0 2>/dev/null | sort -z || true)
        fi
    done <<< "$(get_search_locations "$project_root")"
}

# Show usage information
show_usage() {
    cat << EOF
Script Discovery System - Pre-Execution Validation
==================================================

Usage: $0 <command> [script_name]

Commands:
  discover <script>     - Find script and return absolute path
  validate <script>     - Validate script exists and is readable
  list                  - List all available Julia scripts
  help                  - Show this help message

Examples:
  $0 discover hpc_minimal_2d_example.jl
  $0 discover Examples/hpc_minimal_2d_example.jl
  $0 discover /full/path/to/script.jl
  $0 validate ./my_experiment.jl
  $0 list

Features:
  ✓ Multi-location intelligent search
  ✓ Absolute path resolution
  ✓ Pattern matching for partial names
  ✓ Validation and accessibility checks
  ✓ Detailed error messages and suggestions
EOF
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        discover)
            if [[ $# -lt 2 ]]; then
                error "Usage: $0 discover <script_name>"
                exit 1
            fi
            discover_script "$2"
            ;;
        validate)
            if [[ $# -lt 2 ]]; then
                error "Usage: $0 validate <script_path>"
                exit 1
            fi
            validate_script "$2"
            ;;
        list)
            list_available_scripts
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi