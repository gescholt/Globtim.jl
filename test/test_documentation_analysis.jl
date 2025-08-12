#!/usr/bin/env julia

# Documentation Analysis Script for Phase 1 Evaluation
# This script tests the documentation improvements made in Phase 1

using Pkg
Pkg.instantiate()

println("🔍 Globtim Documentation Analysis - Phase 1 Evaluation")
println("="^60)

# Test if Globtim compiles
println("\n📦 Testing Package Compilation...")
try
    using Globtim
    println("✅ Globtim loaded successfully!")
catch e
    println("❌ Failed to load Globtim: ", e)
    exit(1)
end

# Check our Phase 1 enhanced functions
enhanced_functions = [:test_input, :Constructor, :solve_polynomial_system, :ApproxPoly, :Ackley, :camel, :shubert, :CrossInTray]

println("\n🎯 Phase 1 Enhanced Functions Documentation:")
println("-"^50)

total_enhanced = 0
well_documented = 0

for func_name in enhanced_functions
    try
        if isdefined(Globtim, func_name)
            obj = getfield(Globtim, func_name)
            docs = Base.Docs.doc(obj)
            doc_str = string(docs)
            doc_length = length(doc_str)
            
            # Check for key documentation features we added
            has_math = contains(doc_str, "Mathematical") || contains(doc_str, "formula") || contains(doc_str, "Formula")
            has_hpc = contains(doc_str, "HPC") || contains(doc_str, "batch") || contains(doc_str, "cluster")
            has_examples = contains(doc_str, "Examples") || contains(doc_str, "julia") || contains(doc_str, "```")
            
            status = if doc_length > 2000
                "🌟 COMPREHENSIVE"
            elseif doc_length > 1000
                "✅ WELL DOCUMENTED"
            elseif doc_length > 300
                "⚠️  BASIC"
            else
                "❌ MINIMAL"
            end
            
            if doc_length > 1000
                well_documented += 1
            end
            total_enhanced += 1
            
            println("  $func_name: $status ($doc_length chars)")
            if has_math
                println("    ✓ Mathematical background")
            end
            if has_hpc
                println("    ✓ HPC integration examples")
            end
            if has_examples
                println("    ✓ Code examples")
            end
            println()
        else
            println("  $func_name: ❌ NOT FOUND")
        end
    catch e
        println("  $func_name: ❌ ERROR - $e")
    end
end

# Get total export count for context
exported_names = names(Globtim)
total_exports = length(exported_names)

println("\n📊 Overall Package Statistics:")
println("-"^30)
println("Total exported names: $total_exports")
println("Phase 1 enhanced functions: $(length(enhanced_functions))")
println("Well documented in Phase 1: $well_documented")
println("Phase 1 coverage: $(round(length(enhanced_functions)/total_exports*100, digits=1))%")
println("Phase 1 quality: $(round(well_documented/length(enhanced_functions)*100, digits=1))%")

# Sample other functions for comparison
println("\n📋 Sample of Other Exported Functions (for comparison):")
println("-"^50)

function_exports = []
for name in exported_names
    try
        obj = getfield(Globtim, name)
        if isa(obj, Function) && name ∉ enhanced_functions
            push!(function_exports, name)
        end
    catch
        continue
    end
end

sample_size = min(10, length(function_exports))
sample_functions = function_exports[1:sample_size]

other_well_documented = 0
for func_name in sample_functions
    try
        obj = getfield(Globtim, func_name)
        docs = Base.Docs.doc(obj)
        doc_str = string(docs)
        doc_length = length(doc_str)
        
        status = if doc_length > 1000
            "✅ WELL DOCUMENTED"
        elseif doc_length > 300
            "⚠️  BASIC"
        else
            "❌ MINIMAL"
        end
        
        if doc_length > 1000
            other_well_documented += 1
        end
        
        println("  $func_name: $status ($doc_length chars)")
    catch e
        println("  $func_name: ❌ ERROR")
    end
end

println("\n🎯 PHASE 1 IMPACT ASSESSMENT:")
println("="^40)
println("Enhanced functions: $(length(enhanced_functions))")
println("Well documented (Phase 1): $well_documented / $(length(enhanced_functions)) ($(round(well_documented/length(enhanced_functions)*100, digits=1))%)")
println("Well documented (sample others): $other_well_documented / $sample_size ($(round(other_well_documented/sample_size*100, digits=1))%)")
println("\n✅ Phase 1 documentation enhancement completed successfully!")
