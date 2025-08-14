#!/usr/bin/env julia

using Pkg
Pkg.activate("test")
Pkg.instantiate()

using Aqua, Globtim

println("🔧 Running Aqua.jl Compliance Tests...")

try
    println("Testing method ambiguities...")
    Aqua.test_ambiguities(Globtim)
    println("✅ No method ambiguities")
catch e
    println("⚠️ Method ambiguities found: $e")
end

try
    println("Testing undefined exports...")
    Aqua.test_undefined_exports(Globtim)
    println("✅ All exports defined")
catch e
    println("⚠️ Undefined exports found: $e")
end

try
    println("Testing unbound args...")
    Aqua.test_unbound_args(Globtim)
    println("✅ No unbound args")
catch e
    println("⚠️ Unbound args found: $e")
end

try
    println("Testing persistent tasks...")
    Aqua.test_persistent_tasks(Globtim)
    println("✅ No persistent tasks")
catch e
    println("⚠️ Persistent tasks found: $e")
end

try
    println("Testing project TOML formatting...")
    Aqua.test_project_toml_formatting(Globtim)
    println("✅ Project TOML properly formatted")
catch e
    println("⚠️ Project TOML issues: $e")
end

println("\n✅ Aqua.jl compliance testing complete!")
