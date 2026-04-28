# Tests for the [grid_scoring] (bead 0thk) and [screening] (bead 20p7) TOML
# sections added to ExperimentPipelineConfig. Pure config-loader tests — no
# heavy dependencies, no precompilation cost beyond the parser.

using TOML

const _MIN_TOML = """
[experiment]
name = "test"
[model]
analytical_function = "Ackley"
dimension = 2
[domain]
bounds = [[-1.0, 1.0], [-1.0, 1.0]]
[polynomial]
GN = 8
degree_range = [4, 2, 6]
"""

function _write_tmp(toml_body::String)
    path, io = mktemp()
    write(io, toml_body)
    close(io)
    return path
end

@testset "[grid_scoring] section (bead 0thk)" begin
    @testset "all fields parse" begin
        body = _MIN_TOML * """
        [grid_scoring]
        points_per_dim = 18
        numpoints = 25
        interestingness_threshold = 0.7
        negative_control_threshold = 0.45
        min_local_minima = 1
        catalogue_files = [
            "globtim_results/lv2d_catalogue.jsonl",
            "globtim_results/fhn3d_catalogue.jsonl",
        ]
        """
        path = _write_tmp(body)
        cfg = Globtim.load_experiment_config(path)
        @test cfg.grid_scoring_points_per_dim == 18
        @test cfg.grid_scoring_numpoints == 25
        @test cfg.grid_scoring_interestingness_threshold ≈ 0.7
        @test cfg.grid_scoring_negative_control_threshold ≈ 0.45
        @test cfg.grid_scoring_min_local_minima == 1
        @test cfg.grid_scoring_catalogue_files !== nothing
        @test length(cfg.grid_scoring_catalogue_files) == 2
        @test "globtim_results/lv2d_catalogue.jsonl" in cfg.grid_scoring_catalogue_files
    end

    @testset "section is optional — defaults to nothing" begin
        path = _write_tmp(_MIN_TOML)
        cfg = Globtim.load_experiment_config(path)
        @test cfg.grid_scoring_points_per_dim === nothing
        @test cfg.grid_scoring_interestingness_threshold === nothing
        @test cfg.grid_scoring_catalogue_files === nothing
    end

    @testset "validation rejects bad thresholds" begin
        # interestingness_threshold > 1
        body = _MIN_TOML * """
        [grid_scoring]
        interestingness_threshold = 1.5
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)

        # negative_control >= interestingness (must be strictly less)
        body = _MIN_TOML * """
        [grid_scoring]
        interestingness_threshold = 0.6
        negative_control_threshold = 0.7
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)

        # points_per_dim must be >= 2
        body = _MIN_TOML * """
        [grid_scoring]
        points_per_dim = 1
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)

        # min_local_minima rejects negatives
        body = _MIN_TOML * """
        [grid_scoring]
        min_local_minima = -1
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)
    end
end

@testset "[screening] section (bead 20p7)" begin
    @testset "all fields parse" begin
        body = _MIN_TOML * """
        [screening]
        model_factory = "define_lotka_volterra_2D_model"
        ic = [0.5, 0.5]
        bounds = [[-0.1, 0.1], [-0.1, 0.1]]
        time_interval = [0.0, 10.0]
        catalogue_path = "globtim_results/test_catalogue.jsonl"
        name_prefix = "TEST"
        description = "regression-test catalogue"
        n_candidates = 50
        n_probes = 5
        top_n = 3
        numpoints_screen = 15
        numpoints_probe = 25
        min_finite_fraction = 0.8
        max_noise_ratio = 2.0
        ranking_strategy = "dynamic_range"
        solver = "Tsit5"
        """
        path = _write_tmp(body)
        cfg = Globtim.load_experiment_config(path)
        @test cfg.screening_model_factory == "define_lotka_volterra_2D_model"
        @test cfg.screening_ic == [0.5, 0.5]
        @test cfg.screening_bounds == [(-0.1, 0.1), (-0.1, 0.1)]
        @test cfg.screening_time_interval == [0.0, 10.0]
        @test cfg.screening_n_candidates == 50
        @test cfg.screening_n_probes == 5
        @test cfg.screening_top_n == 3
        @test cfg.screening_min_finite_fraction ≈ 0.8
        @test cfg.screening_max_noise_ratio ≈ 2.0
        @test cfg.screening_ranking_strategy == "dynamic_range"
        @test cfg.screening_solver == "Tsit5"
        @test cfg.screening_name_prefix == "TEST"
        @test endswith(cfg.screening_catalogue_path, "test_catalogue.jsonl")  # path resolved
    end

    @testset "section is optional — defaults to nothing" begin
        path = _write_tmp(_MIN_TOML)
        cfg = Globtim.load_experiment_config(path)
        @test cfg.screening_model_factory === nothing
        @test cfg.screening_ic === nothing
        @test cfg.screening_bounds === nothing
        @test cfg.screening_n_candidates === nothing
    end

    @testset "validation rejects bad fields" begin
        # Unknown solver
        body = _MIN_TOML * """
        [screening]
        solver = "RK4_pirate_edition"
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)

        # Unknown ranking_strategy
        body = _MIN_TOML * """
        [screening]
        ranking_strategy = "vibes"
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)

        # n_candidates must be positive
        body = _MIN_TOML * """
        [screening]
        n_candidates = 0
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)

        # min_finite_fraction must be in [0,1]
        body = _MIN_TOML * """
        [screening]
        min_finite_fraction = 1.5
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)

        # bounds must be array of [lo, hi] pairs
        body = _MIN_TOML * """
        [screening]
        bounds = [[1.0, 2.0, 3.0], [0.0, 1.0]]
        """
        path = _write_tmp(body)
        @test_throws ErrorException Globtim.load_experiment_config(path)
    end

    @testset "known solver + ranking sets are non-empty" begin
        @test "Tsit5" in Globtim.KNOWN_SCREENING_SOLVERS
        @test "AutoTsit5_Rosenbrock23" in Globtim.KNOWN_SCREENING_SOLVERS
        @test "dynamic_range" in Globtim.KNOWN_SCREENING_RANKING_STRATEGIES
    end
end
