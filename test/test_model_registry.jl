"""
Test suite for ModelRegistry.

Two jobs:

1. Pin the standalone-package contract. globtim ships to the public Globtim.jl via
   `git subtree split --prefix=pkg/globtim`, so it must behave correctly with no
   sibling package present. Until 1.3.0 `register_ode_models!` scraped 15 model
   constructors off `Main.DynamicObjectives` — it inverted the dependency arrow,
   fired only when that package happened to be loaded first, and silently
   registered nothing otherwise. These tests assert the registry now contains
   exactly globtim's own models and nothing else.

2. Cover the generic registry contract, which had no tests at all.
"""

using Test
using Globtim
using Globtim: ModelInfo, register_model!, get_model, list_models, clear_registry!
using Globtim: validate_model_name, get_model_function

@testset "ModelRegistry" begin

    # ========================================================================
    # Standalone-package contract
    # ========================================================================

    @testset "no external model package is present" begin
        # Guards the tests below: without this, "0 ODE models" could pass simply
        # because someone forgot to load DynamicObjectives, rather than because
        # globtim no longer reaches for it. Skipped in the workspace, where the
        # package IS resolvable — there the real signal is the leak grep in
        # infra/hooks/pre-push Layer 0.6.
        if Base.identify_package("DynamicObjectives") === nothing
            @test true
        else
            @test_skip "DynamicObjectives resolvable — running in the workspace, not the mirror"
        end
    end

    @testset "registry holds only globtim's own models" begin
        @test isempty(list_models(category = :ode))
        @test length(list_models(category = :benchmark)) == 21
        @test length(list_models()) == 21
    end

    @testset "globtim does not reach into Main for models" begin
        # The regression this file exists for. Even with a decoy module bound in
        # Main under the old name, nothing may be picked up.
        @eval Main module __DecoyDynamicObjectives
        define_lotka_volterra_2D_model() = error("must never be called")
        end
        try
            # clear first — __init__ registers from scratch and rejects duplicates.
            clear_registry!()
            Globtim.ModelRegistry.__init__()
            @test isempty(list_models(category = :ode))
            @test length(list_models(category = :benchmark)) == 21
        finally
            clear_registry!()
            Globtim.ModelRegistry.__init__()
        end
    end

    # ========================================================================
    # Generic registry contract
    # ========================================================================

    @testset "register / get round-trip" begin
        probe = ModelInfo(
            name = "__probe_model",
            aliases = ["__probe_alias"],
            dimension = 2,
            num_parameters = 2,
            num_states = 2,
            num_outputs = 1,
            category = :benchmark,
            subcategory = :test,
            requires_inputs = false,
            definition_function = () -> nothing,
            description = "synthetic entry for tests",
        )

        register_model!(probe)
        try
            @test validate_model_name("__probe_model")
            @test get_model("__probe_model").dimension == 2
            @test get_model("__probe_alias").name == "__probe_model"
            @test get_model_function("__probe_model") === probe.definition_function
            @test "__probe_model" in list_models()
        finally
            # Restore the pristine registry rather than leaving the probe behind.
            clear_registry!()
            Globtim.ModelRegistry.__init__()
        end

        @test !validate_model_name("__probe_model")
        @test length(list_models(category = :benchmark)) == 21
    end

    @testset "unknown model lookups fail loudly" begin
        @test !validate_model_name("definitely_not_a_model")
        @test_throws Exception get_model("definitely_not_a_model")
        @test_throws Exception get_model_function("definitely_not_a_model")
        # The name that used to arrive via the Main scraper.
        @test !validate_model_name("lv4d_generalized")
        @test_throws Exception get_model("lv4d_generalized")
    end

    @testset "clear_registry! empties it" begin
        clear_registry!()
        @test isempty(list_models())
        Globtim.ModelRegistry.__init__()
        @test length(list_models()) == 21
    end
end
