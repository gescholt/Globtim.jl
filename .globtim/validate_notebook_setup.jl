#!/usr/bin/env julia

"""
Globtim Notebook Setup Validation Script

This script validates that the notebook environment is set up correctly
and provides troubleshooting information for common issues.

Usage:
    julia .globtim/validate_notebook_setup.jl
    
Or from within Julia:
    include(".globtim/validate_notebook_setup.jl")
"""

using Pkg

function print_header(title)
    println("\n" * "="^60)
    println("  $title")
    println("="^60)
end

function print_section(title)
    println("\n" * "-"^40)
    println("$title")
    println("-"^40)
end

function check_mark(condition, message)
    symbol = condition ? "✓" : "✗"
    status = condition ? "PASS" : "FAIL"
    println("[$symbol] $message - $status")
    return condition
end

function find_project_root()
    current_dir = pwd()
    while current_dir != "/"
        if isfile(joinpath(current_dir, "Project.toml")) && 
           isdir(joinpath(current_dir, "environments"))
            return current_dir
        end
        current_dir = dirname(current_dir)
    end
    return nothing
end

function validate_project_structure()
    print_section("Project Structure Validation")
    
    project_root = find_project_root()
    all_good = true
    
    all_good &= check_mark(project_root !== nothing, "Found Globtim project root")
    
    if project_root !== nothing
        println("   Project root: $project_root")
        
        # Check essential files and directories
        all_good &= check_mark(isfile(joinpath(project_root, "Project.toml")), 
                              "Main Project.toml exists")
        all_good &= check_mark(isdir(joinpath(project_root, "environments")), 
                              "environments/ directory exists")
        all_good &= check_mark(isdir(joinpath(project_root, "environments", "local")), 
                              "environments/local/ directory exists")
        all_good &= check_mark(isdir(joinpath(project_root, "environments", "hpc")), 
                              "environments/hpc/ directory exists")
        all_good &= check_mark(isfile(joinpath(project_root, "environments", "local", "Project.toml")), 
                              "Local environment Project.toml exists")
        all_good &= check_mark(isfile(joinpath(project_root, "environments", "hpc", "Project.toml")), 
                              "HPC environment Project.toml exists")
        all_good &= check_mark(isdir(joinpath(project_root, ".globtim")), 
                              ".globtim/ directory exists")
        all_good &= check_mark(isfile(joinpath(project_root, ".globtim", "notebook_setup.jl")), 
                              "notebook_setup.jl exists")
    else
        println("   ERROR: Not in a Globtim project directory!")
        println("   Please run this script from within the Globtim project.")
    end
    
    return all_good, project_root
end

function validate_environments(project_root)
    print_section("Environment Validation")
    
    all_good = true
    
    # Check local environment
    local_env = joinpath(project_root, "environments", "local")
    if isdir(local_env)
        try
            Pkg.activate(local_env)
            all_good &= check_mark(true, "Can activate local environment")
            
            # Check if Manifest exists (environment is instantiated)
            manifest_exists = isfile(joinpath(local_env, "Manifest.toml"))
            all_good &= check_mark(manifest_exists, "Local environment is instantiated")
            
            if !manifest_exists
                println("   Note: Run 'Pkg.instantiate()' in local environment")
            end
        catch e
            all_good &= check_mark(false, "Can activate local environment")
            println("   Error: $e")
        end
    end
    
    # Check HPC environment
    hpc_env = joinpath(project_root, "environments", "hpc")
    if isdir(hpc_env)
        try
            Pkg.activate(hpc_env)
            all_good &= check_mark(true, "Can activate HPC environment")
            
            # Check if Manifest exists (environment is instantiated)
            manifest_exists = isfile(joinpath(hpc_env, "Manifest.toml"))
            all_good &= check_mark(manifest_exists, "HPC environment is instantiated")
            
            if !manifest_exists
                println("   Note: Run 'Pkg.instantiate()' in HPC environment")
            end
        catch e
            all_good &= check_mark(false, "Can activate HPC environment")
            println("   Error: $e")
        end
    end
    
    return all_good
end

function test_notebook_setup(project_root)
    print_section("Notebook Setup Test")
    
    all_good = true
    
    try
        # Test the notebook setup script
        setup_file = joinpath(project_root, ".globtim", "notebook_setup.jl")
        
        println("Testing notebook setup script...")
        include(setup_file)
        
        all_good &= check_mark(true, "Notebook setup script runs without errors")
        
        # Check if Globtim is loaded
        globtim_loaded = isdefined(Main, :Globtim)
        all_good &= check_mark(globtim_loaded, "Globtim package loaded successfully")
        
        # Check plotting availability
        cairo_loaded = isdefined(Main, :CairoMakie)
        if cairo_loaded
            println("   [✓] CairoMakie loaded - plotting available")
        else
            println("   [i] CairoMakie not loaded - this is normal for HPC environment")
        end
        
    catch e
        all_good &= check_mark(false, "Notebook setup script runs without errors")
        println("   Error: $e")
        println("   This indicates a problem with the setup script or environment")
    end
    
    return all_good
end

function test_universal_include()
    print_section("Universal Include Test")
    
    all_good = true
    
    try
        # Test the universal include path
        universal_path = joinpath(dirname(Base.find_package("Globtim")), "..", ".globtim", "notebook_setup.jl")
        all_good &= check_mark(isfile(universal_path), "Universal include path resolves correctly")
        println("   Path: $universal_path")
    catch e
        all_good &= check_mark(false, "Universal include path resolves correctly")
        println("   Error: $e")
        println("   This means the universal notebook setup won't work")
    end
    
    return all_good
end

function provide_troubleshooting_info()
    print_section("System Information")
    
    println("Julia version: $(VERSION)")
    println("Platform: $(Sys.MACHINE)")
    println("Current directory: $(pwd())")
    println("Active project: $(Base.active_project())")
    
    # Environment variables that affect setup
    println("\nRelevant environment variables:")
    for var in ["SLURM_JOB_ID", "PBS_JOBID", "GLOBTIM_FORCE_PLOTTING", "GLOBTIM_ENV", "DISPLAY"]
        value = get(ENV, var, "not set")
        println("  $var: $value")
    end
    
    # Package information
    println("\nPackage status:")
    try
        pkg_status = Pkg.status()
        println("  Package environment appears healthy")
    catch e
        println("  Warning: Issue with package environment: $e")
    end
end

function main()
    print_header("Globtim Notebook Setup Validation")
    
    println("This script validates your Globtim notebook environment setup.")
    println("It will check project structure, environments, and test the setup script.")
    
    # Run all validation checks
    structure_ok, project_root = validate_project_structure()
    
    if project_root !== nothing
        env_ok = validate_environments(project_root)
        setup_ok = test_notebook_setup(project_root)
        include_ok = test_universal_include()
        
        # Overall status
        print_header("Validation Summary")
        
        overall_ok = structure_ok && env_ok && setup_ok && include_ok
        
        if overall_ok
            println("🎉 ALL CHECKS PASSED!")
            println("\nYour notebook environment is properly configured.")
            println("You can use this setup cell in any notebook:")
            println()
            println("```julia")
            println("include(joinpath(dirname(Base.find_package(\"Globtim\")), \"..\", \".globtim\", \"notebook_setup.jl\"))")
            println("```")
        else
            println("❌ SOME CHECKS FAILED")
            println("\nPlease address the failed checks above.")
            println("Common solutions:")
            println("- Run 'Pkg.instantiate()' in both environments")
            println("- Ensure you're in the correct project directory")
            println("- Check that all required files exist")
        end
    else
        println("❌ PROJECT STRUCTURE INVALID")
        println("\nCannot proceed with validation - not in a Globtim project directory.")
    end
    
    provide_troubleshooting_info()
    
    print_header("Validation Complete")
end

# Run validation if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
