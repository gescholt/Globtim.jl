"""
Unit Tests for Enhanced Error Context (Schema v1.3.0)

Focused unit tests for error context capture without requiring full experiment runs.
"""

using Test
using Globtim.StandardExperiment
using JSON3
using Dates

@testset "Error Context Unit Tests" begin

    @testset "DegreeResult Type - Error Field Variants" begin
        # Test 1: Success case (error = nothing)
        success_result = StandardExperiment.DegreeResult(
            4, "success",
            10, 8, 15, 10,
            [1.0, 2.0], 0.001, 0.05,
            1e-6, 100.0,
            1.0, 2.0, 3.0, 0.5, 0.2, 0.1, 7.0,
            Dict("converged" => 10, "failed" => 5),
            Dict("critical_verified" => 8, "critical_spurious" => 2),
            nothing  # No error
        )
        @test success_result.status == "success"
        @test success_result.error === nothing

        # Test 2: Legacy string error (backward compatibility)
        legacy_result = StandardExperiment.DegreeResult(
            6, "failed",
            0, 0, 0, 0,
            nothing, nothing, nothing,
            NaN, NaN,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5,
            Dict("converged" => 0, "failed" => 1),
            Dict("critical_verified" => 0, "critical_spurious" => 0),
            "Simple error message"  # String error
        )
        @test legacy_result.status == "failed"
        @test legacy_result.error isa String
        @test legacy_result.error == "Simple error message"

        # Test 3: Rich error context (new format)
        error_context = Dict{String, Any}(
            "error_message" => "HomotopyContinuation failed to converge",
            "error_type" => "ConvergenceError",
            "stacktrace" => ["frame1", "frame2", "frame3"],
            "degree" => 8,
            "dimension" => 4,
            "GN" => 16,
            "basis" => "chebyshev",
            "timestamp" => "2025-11-16 12:00:00",
            "computation_time" => 45.2
        )

        rich_result = StandardExperiment.DegreeResult(
            8, "failed",
            0, 0, 0, 0,
            nothing, nothing, nothing,
            NaN, NaN,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 45.2,
            Dict("converged" => 0, "failed" => 1),
            Dict("critical_verified" => 0, "critical_spurious" => 0),
            error_context  # Dict error
        )
        @test rich_result.status == "failed"
        @test rich_result.error isa Dict{String, Any}
        @test haskey(rich_result.error, "error_message")
        @test haskey(rich_result.error, "degree")
        @test rich_result.error["degree"] == 8
        @test rich_result.error["dimension"] == 4

        println("✓ DegreeResult supports all three error variants: nothing, String, Dict")
    end

    @testset "Error Context Structure Validation" begin
        error_ctx = Dict{String, Any}(
            "error_message" => "Test error",
            "error_type" => "ErrorException",
            "stacktrace" => ["trace1", "trace2"],
            "degree" => 6,
            "dimension" => 3,
            "GN" => 8,
            "basis" => "legendre",
            "timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
            "computation_time" => 12.5
        )

        # Verify all required fields are present
        required_fields = [
            "error_message", "error_type", "stacktrace",
            "degree", "dimension", "GN", "basis",
            "timestamp", "computation_time"
        ]

        for field in required_fields
            @test haskey(error_ctx, field)
        end

        # Verify field types
        @test error_ctx["error_message"] isa String
        @test error_ctx["error_type"] isa String
        @test error_ctx["stacktrace"] isa Vector
        @test error_ctx["degree"] isa Int
        @test error_ctx["dimension"] isa Int
        @test error_ctx["GN"] isa Int
        @test error_ctx["basis"] isa String
        @test error_ctx["timestamp"] isa String
        @test error_ctx["computation_time"] isa Number

        println("✓ Error context has all required fields with correct types")
    end

    @testset "JSON Serialization - Error Variants" begin
        # Test serialization of string error
        legacy_result = StandardExperiment.DegreeResult(
            4, "failed", 0, 0, 0, 0, nothing, nothing, nothing,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
            Dict(), Dict(), "Legacy error"
        )

        sanitized_legacy = StandardExperiment.sanitize_for_json(legacy_result)
        @test sanitized_legacy["error"] == "Legacy error"
        json_legacy = JSON3.write(sanitized_legacy)
        @test occursin("Legacy error", json_legacy)

        # Test serialization of dict error
        error_ctx = Dict{String, Any}(
            "error_message" => "Test message",
            "degree" => 6,
            "GN" => 8
        )

        rich_result = StandardExperiment.DegreeResult(
            6, "failed", 0, 0, 0, 0, nothing, nothing, nothing,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
            Dict(), Dict(), error_ctx
        )

        sanitized_rich = StandardExperiment.sanitize_for_json(rich_result)
        @test sanitized_rich["error"] isa Dict
        @test sanitized_rich["error"]["degree"] == 6
        json_rich = JSON3.write(sanitized_rich)
        @test occursin("Test message", json_rich)
        @test occursin("degree", json_rich)

        println("✓ Both string and Dict errors serialize to JSON correctly")
    end

    @testset "NaN/Inf Sanitization in Error Context" begin
        # Create result with NaN/Inf in quality metrics
        error_ctx = Dict{String, Any}(
            "error_message" => "Singular matrix",
            "computation_time" => Inf  # Inf in error context
        )

        result = StandardExperiment.DegreeResult(
            4, "failed", 0, 0, 0, 0, nothing, nothing, nothing,
            NaN, Inf,  # NaN and Inf in metrics
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
            Dict(), Dict(), error_ctx
        )

        sanitized = StandardExperiment.sanitize_for_json(result)

        # Check that NaN/Inf in metrics were sanitized
        @test sanitized["l2_approx_error"] === nothing
        @test sanitized["condition_number"] === nothing

        # Check that error context is preserved
        @test sanitized["error"] isa Dict
        @test sanitized["error"]["error_message"] == "Singular matrix"

        # Verify JSON serialization works
        json_str = JSON3.write(sanitized)
        @test !occursin("NaN", json_str)
        @test !occursin("Inf", json_str)
        @test occursin("null", json_str)  # NaN/Inf become null

        println("✓ NaN/Inf values sanitized to null in JSON")
    end

    @testset "Error Context Round-Trip" begin
        # Create error context
        original_ctx = Dict{String, Any}(
            "error_message" => "DimensionMismatch: expected 3, got 4",
            "error_type" => "DimensionMismatch",
            "stacktrace" => ["at line 42", "at line 85"],
            "degree" => 10,
            "dimension" => 3,
            "GN" => 12,
            "basis" => "chebyshev",
            "timestamp" => "2025-11-16 15:30:00",
            "computation_time" => 67.8
        )

        # Create result
        result = StandardExperiment.DegreeResult(
            10, "failed", 0, 0, 0, 0, nothing, nothing, nothing,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 67.8,
            Dict(), Dict(), original_ctx
        )

        # Serialize to JSON
        sanitized = StandardExperiment.sanitize_for_json(result)
        json_str = JSON3.write(sanitized)

        # Parse back
        parsed = JSON3.read(json_str, Dict{String, Any})

        # Verify error context survived round-trip
        @test parsed["error"]["error_message"] == original_ctx["error_message"]
        @test parsed["error"]["error_type"] == original_ctx["error_type"]
        @test parsed["error"]["degree"] == original_ctx["degree"]
        @test parsed["error"]["dimension"] == original_ctx["dimension"]
        @test parsed["error"]["GN"] == original_ctx["GN"]
        @test parsed["error"]["basis"] == original_ctx["basis"]

        println("✓ Error context survives JSON round-trip correctly")
    end
end

println("\n✅ All error context unit tests passed!")
println("   - DegreeResult type accepts String, Dict, or Nothing")
println("   - Error context structure validated")
println("   - JSON serialization works for all variants")
println("   - NaN/Inf sanitization correct")
println("   - Round-trip serialization verified")
