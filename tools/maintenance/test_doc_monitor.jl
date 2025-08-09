#!/usr/bin/env julia

"""
Test script for the Documentation Monitoring System

This script tests the hybrid Aqua.jl + custom documentation monitoring system
to ensure all components work correctly.
"""

# Check if required packages are available
println("📦 Checking required dependencies...")

# Try to load required packages
try
    using Pkg
    using YAML
    using JSON3
    using TOML
    println("✅ All required packages are available")
catch e
    println("❌ Missing required packages!")
    println("Error: $e")
    println()
    println("Please install dependencies by running:")
    println("  julia tools/maintenance/install_dependencies.jl")
    println()
    println("Or install manually:")
    println("  julia -e 'using Pkg; Pkg.add([\"YAML\", \"JSON3\", \"ArgParse\", \"TOML\"])'")
    exit(1)
end

# Add current directory to load path
push!(LOAD_PATH, @__DIR__)

# Test configuration
function test_configuration()
    println("🔧 Testing configuration...")
    
    config_path = joinpath(@__DIR__, "doc_monitor_config.yaml")
    
    if !isfile(config_path)
        println("❌ Configuration file not found: $config_path")
        return false
    end
    
    try
        config = YAML.load_file(config_path)
        println("✅ Configuration loaded successfully")
        
        # Test required sections
        required_sections = ["global", "aqua_quality", "task_monitoring"]
        for section in required_sections
            if haskey(config, section)
                println("✅ Found section: $section")
            else
                println("❌ Missing section: $section")
                return false
            end
        end
        
        return true
    catch e
        println("❌ Configuration test failed: $e")
        return false
    end
end

# Test module loading
function test_module_loading()
    println("\n📦 Testing module loading...")
    
    modules_to_test = [
        "doc_monitor_core.jl",
        "doc_monitor_aqua.jl", 
        "doc_monitor_tasks.jl",
        "doc_monitor_linkage.jl",
        "doc_monitor_drift.jl",
        "doc_monitor_files.jl",
        "doc_monitor_reports.jl",
        "doc_monitor_main.jl"
    ]
    
    for module_file in modules_to_test
        module_path = joinpath(@__DIR__, module_file)
        
        if !isfile(module_path)
            println("❌ Module file not found: $module_file")
            return false
        end
        
        try
            include(module_path)
            println("✅ Loaded module: $module_file")
        catch e
            println("❌ Failed to load module $module_file: $e")
            return false
        end
    end
    
    return true
end

# Test Aqua.jl availability
function test_aqua_availability()
    println("\n🔬 Testing Aqua.jl availability...")
    
    try
        using Aqua
        println("✅ Aqua.jl is available")
        return true
    catch e
        println("⚠️  Aqua.jl not available: $e")
        println("ℹ️  Install with: julia -e 'using Pkg; Pkg.add(\"Aqua\")'")
        return false
    end
end

# Test basic functionality
function test_basic_functionality()
    println("\n⚙️  Testing basic functionality...")
    
    try
        # Test core utilities
        test_files = find_files_with_patterns(".", ["*.jl"], [".git/**"])
        println("✅ File pattern matching works (found $(length(test_files)) .jl files)")
        
        # Test configuration parsing
        config_path = joinpath(@__DIR__, "doc_monitor_config.yaml")
        config = YAML.load_file(config_path)
        summary = summarize_config(config)
        println("✅ Configuration summarization works")
        
        # Test text utilities
        similarity = text_similarity("hello world", "hello julia")
        println("✅ Text similarity calculation works (similarity: $(round(similarity, digits=2)))")
        
        return true
    catch e
        println("❌ Basic functionality test failed: $e")
        return false
    end
end

# Test dry run
function test_dry_run()
    println("\n🧪 Testing dry run mode...")
    
    try
        config_path = joinpath(@__DIR__, "doc_monitor_config.yaml")
        
        # Create monitor instance in dry run mode
        monitor = DocumentationMonitor(
            config_path;
            report_dir = "test_reports",
            verbose = false,
            dry_run = true
        )
        
        println("✅ Monitor instance created successfully")
        
        # Test individual analysis functions (dry run)
        println("  Testing task monitoring...")
        task_results = analyze_task_progress(monitor)
        println("  ✅ Task monitoring works")
        
        println("  Testing linkage analysis...")
        linkage_results = analyze_documentation_linkage(monitor)
        println("  ✅ Linkage analysis works")
        
        println("  Testing drift detection...")
        drift_results = analyze_documentation_drift(monitor)
        println("  ✅ Drift detection works")
        
        println("  Testing file management...")
        file_results = analyze_documentation_files(monitor)
        println("  ✅ File management works")
        
        return true
    catch e
        println("❌ Dry run test failed: $e")
        if isa(e, LoadError)
            println("Stack trace:")
            showerror(stdout, e)
        end
        return false
    end
end

# Main test function
function run_tests()
    println("╔══════════════════════════════════════════════════════════════╗")
    println("║           🧪 Documentation Monitor Test Suite                ║")
    println("║              Hybrid Aqua.jl + Custom Analysis               ║")
    println("╚══════════════════════════════════════════════════════════════╝")
    println()
    
    tests = [
        ("Configuration", test_configuration),
        ("Module Loading", test_module_loading),
        ("Aqua.jl Availability", test_aqua_availability),
        ("Basic Functionality", test_basic_functionality),
        ("Dry Run", test_dry_run)
    ]
    
    passed = 0
    total = length(tests)
    
    for (test_name, test_func) in tests
        println("Running test: $test_name")
        println("-" ^ 50)
        
        if test_func()
            passed += 1
            println("✅ $test_name: PASSED")
        else
            println("❌ $test_name: FAILED")
        end
        
        println()
    end
    
    println("📊 Test Results:")
    println("=" ^ 50)
    println("Passed: $passed/$total")
    
    if passed == total
        println("🎉 All tests passed!")
        return true
    else
        println("⚠️  Some tests failed")
        return false
    end
end

# Run tests if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    success = run_tests()
    exit(success ? 0 : 1)
end
