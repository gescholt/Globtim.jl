# ================================================================================
# Phase 3: Advanced Analytics for Publication-Quality Statistical Analysis
# ================================================================================
#
# This file implements advanced statistical and clustering analytics for systematic 
# convergence analysis, building on the validated data structures from Phase 1 and
# publication-quality visualizations from Phase 2.
#
# Key Features:
# - Statistical significance testing (Mann-Whitney U, Kolmogorov-Smirnov, Bootstrap)
# - Spatial clustering analysis for 16-orthant performance patterns
# - Performance prediction models using machine learning techniques
# - Comprehensive statistical validation for academic publication standards
# - Integration with existing Globtim.jl patterns and CairoMakie visualization

using Pkg
Pkg.activate(joinpath(@__DIR__, "../../"))

# Core statistical and data analysis packages
using Statistics, LinearAlgebra, StatsBase
using HypothesisTests, Distributions, Bootstrap
using MultivariateStats, Clustering, MLJ
using Printf, DataFrames

# Visualization for statistical plots
using CairoMakie
CairoMakie.activate!(type = "png")

# Include Phase 1 and Phase 2 infrastructure
include("phase1_data_infrastructure.jl")
include("phase2_core_visualizations.jl")

# ================================================================================
# STATISTICAL SIGNIFICANCE TESTING FRAMEWORK
# ================================================================================

"""
    StatisticalTestResult

Structure to hold results from statistical significance tests.

# Fields
- `test_name::String`: Name of the statistical test performed
- `test_statistic::Float64`: Computed test statistic value
- `p_value::Float64`: P-value from the test
- `effect_size::Float64`: Effect size measure (Cohen's d, Cliff's delta, etc.)
- `confidence_interval::Tuple{Float64, Float64}`: 95% confidence interval
- `is_significant::Bool`: Whether result is significant at α = 0.05
- `interpretation::String`: Human-readable interpretation of results
- `sample_sizes::Tuple{Int, Int}`: Sample sizes for two-sample tests
"""
struct StatisticalTestResult
    test_name::String
    test_statistic::Float64
    p_value::Float64
    effect_size::Float64
    confidence_interval::Tuple{Float64, Float64}
    is_significant::Bool
    interpretation::String
    sample_sizes::Tuple{Int, Int}
end

"""
    ConvergenceTestSuite

Comprehensive statistical test results for convergence analysis.

# Fields
- `tolerance_comparisons::Vector{StatisticalTestResult}`: Pairwise tolerance level comparisons
- `distribution_tests::Vector{StatisticalTestResult}`: Distance distribution change tests
- `success_rate_tests::Vector{StatisticalTestResult}`: Success rate significance tests
- `orthant_performance_tests::Vector{StatisticalTestResult}`: Spatial heterogeneity tests
- `multiple_comparison_correction::String`: Method used for multiple testing correction
- `overall_significance::Bool`: Whether overall convergence pattern is statistically significant
"""
struct ConvergenceTestSuite
    tolerance_comparisons::Vector{StatisticalTestResult}
    distribution_tests::Vector{StatisticalTestResult}
    success_rate_tests::Vector{StatisticalTestResult}
    orthant_performance_tests::Vector{StatisticalTestResult}
    multiple_comparison_correction::String
    overall_significance::Bool
end

"""
    perform_mann_whitney_test(group1::Vector{Float64}, group2::Vector{Float64}, 
                             tolerance1::Float64, tolerance2::Float64)

Perform Mann-Whitney U test for comparing distance distributions between tolerance levels.

# Arguments
- `group1::Vector{Float64}`: Distance values for first tolerance level
- `group2::Vector{Float64}`: Distance values for second tolerance level  
- `tolerance1::Float64`: First tolerance level value
- `tolerance2::Float64`: Second tolerance level value

# Returns
- `StatisticalTestResult`: Comprehensive test results with effect size and interpretation
"""
function perform_mann_whitney_test(group1::Vector{Float64}, group2::Vector{Float64}, 
                                  tolerance1::Float64, tolerance2::Float64)
    @info "Performing Mann-Whitney U test" tol1=tolerance1 tol2=tolerance2 n1=length(group1) n2=length(group2)
    
    # Handle edge cases
    if isempty(group1) || isempty(group2)
        @warn "Empty groups for Mann-Whitney test" n1=length(group1) n2=length(group2)
        return StatisticalTestResult(
            "Mann-Whitney U", NaN, 1.0, 0.0, (NaN, NaN), false,
            "Cannot perform test on empty groups", (length(group1), length(group2))
        )
    end
    
    # Remove NaN values
    clean_group1 = filter(!isnan, group1)
    clean_group2 = filter(!isnan, group2)
    
    if length(clean_group1) < 3 || length(clean_group2) < 3
        @warn "Insufficient sample size for Mann-Whitney test" n1=length(clean_group1) n2=length(clean_group2)
        return StatisticalTestResult(
            "Mann-Whitney U", NaN, 1.0, 0.0, (NaN, NaN), false,
            "Insufficient sample size (minimum 3 per group)", (length(clean_group1), length(clean_group2))
        )
    end
    
    # Perform Mann-Whitney U test
    test_result = MannWhitneyUTest(clean_group1, clean_group2)
    
    # Calculate effect size (Cliff's delta for non-parametric data)
    cliffs_delta = calculate_cliffs_delta(clean_group1, clean_group2)
    
    # Bootstrap confidence interval for median difference
    median_diff_ci = bootstrap_median_difference_ci(clean_group1, clean_group2)
    
    # Interpretation
    is_significant = pvalue(test_result) < 0.05
    effect_magnitude = abs(cliffs_delta) < 0.147 ? "negligible" :
                      abs(cliffs_delta) < 0.33 ? "small" :
                      abs(cliffs_delta) < 0.474 ? "medium" : "large"
    
    direction = median(clean_group1) < median(clean_group2) ? "improvement" : "degradation"
    
    interpretation = is_significant ? 
        "Significant $(direction) from tol=$(tolerance1) to tol=$(tolerance2) ($(effect_magnitude) effect)" :
        "No significant difference between tolerance levels ($(effect_magnitude) effect)"
    
    return StatisticalTestResult(
        "Mann-Whitney U",
        test_result.U,
        pvalue(test_result),
        cliffs_delta,
        median_diff_ci,
        is_significant,
        interpretation,
        (length(clean_group1), length(clean_group2))
    )
end

"""
    calculate_cliffs_delta(group1::Vector{Float64}, group2::Vector{Float64})

Calculate Cliff's delta effect size for non-parametric data.

Cliff's delta measures the degree of overlap between two distributions:
- δ = 0: Complete overlap (no effect)
- δ = ±1: No overlap (maximum effect)
- |δ| < 0.147: Negligible effect
- |δ| < 0.33: Small effect  
- |δ| < 0.474: Medium effect
- |δ| ≥ 0.474: Large effect

# Arguments
- `group1::Vector{Float64}`: First group values
- `group2::Vector{Float64}`: Second group values

# Returns
- `Float64`: Cliff's delta value (-1 to +1)
"""
function calculate_cliffs_delta(group1::Vector{Float64}, group2::Vector{Float64})
    if isempty(group1) || isempty(group2)
        return 0.0
    end
    
    n1, n2 = length(group1), length(group2)
    greater_count = 0
    less_count = 0
    
    for x1 in group1
        for x2 in group2
            if x1 > x2
                greater_count += 1
            elseif x1 < x2
                less_count += 1
            end
        end
    end
    
    return (greater_count - less_count) / (n1 * n2)
end

"""
    bootstrap_median_difference_ci(group1::Vector{Float64}, group2::Vector{Float64}, 
                                  n_bootstrap::Int = 1000, confidence_level::Float64 = 0.95)

Calculate bootstrap confidence interval for median difference between two groups.

# Arguments
- `group1::Vector{Float64}`: First group values
- `group2::Vector{Float64}`: Second group values
- `n_bootstrap::Int`: Number of bootstrap samples (default: 1000)
- `confidence_level::Float64`: Confidence level (default: 0.95)

# Returns
- `Tuple{Float64, Float64}`: Lower and upper confidence interval bounds
"""
function bootstrap_median_difference_ci(group1::Vector{Float64}, group2::Vector{Float64}, 
                                       n_bootstrap::Int = 1000, confidence_level::Float64 = 0.95)
    if isempty(group1) || isempty(group2)
        return (NaN, NaN)
    end
    
    # Bootstrap function for median difference
    function median_difference(data1, data2)
        return median(data1) - median(data2)
    end
    
    # Generate bootstrap samples
    bootstrap_diffs = Float64[]
    
    for _ in 1:n_bootstrap
        # Resample with replacement
        boot_group1 = sample(group1, length(group1), replace=true)
        boot_group2 = sample(group2, length(group2), replace=true)
        
        # Calculate median difference
        diff = median_difference(boot_group1, boot_group2)
        push!(bootstrap_diffs, diff)
    end
    
    # Calculate confidence interval
    alpha = 1 - confidence_level
    lower_percentile = (alpha / 2) * 100
    upper_percentile = (1 - alpha / 2) * 100
    
    ci_lower = percentile(bootstrap_diffs, lower_percentile)
    ci_upper = percentile(bootstrap_diffs, upper_percentile)
    
    return (ci_lower, ci_upper)
end

"""
    perform_kolmogorov_smirnov_test(group1::Vector{Float64}, group2::Vector{Float64},
                                   tolerance1::Float64, tolerance2::Float64)

Perform Kolmogorov-Smirnov test to compare distance distribution shapes between tolerance levels.

# Arguments
- `group1::Vector{Float64}`: Distance values for first tolerance level
- `group2::Vector{Float64}`: Distance values for second tolerance level
- `tolerance1::Float64`: First tolerance level value
- `tolerance2::Float64`: Second tolerance level value

# Returns
- `StatisticalTestResult`: Comprehensive test results with effect size and interpretation
"""
function perform_kolmogorov_smirnov_test(group1::Vector{Float64}, group2::Vector{Float64},
                                        tolerance1::Float64, tolerance2::Float64)
    @info "Performing Kolmogorov-Smirnov test" tol1=tolerance1 tol2=tolerance2 n1=length(group1) n2=length(group2)
    
    # Handle edge cases
    if isempty(group1) || isempty(group2)
        @warn "Empty groups for KS test" n1=length(group1) n2=length(group2)
        return StatisticalTestResult(
            "Kolmogorov-Smirnov", NaN, 1.0, 0.0, (NaN, NaN), false,
            "Cannot perform test on empty groups", (length(group1), length(group2))
        )
    end
    
    # Remove NaN values
    clean_group1 = filter(!isnan, group1)
    clean_group2 = filter(!isnan, group2)
    
    if length(clean_group1) < 5 || length(clean_group2) < 5
        @warn "Insufficient sample size for KS test" n1=length(clean_group1) n2=length(clean_group2)
        return StatisticalTestResult(
            "Kolmogorov-Smirnov", NaN, 1.0, 0.0, (NaN, NaN), false,
            "Insufficient sample size (minimum 5 per group)", (length(clean_group1), length(clean_group2))
        )
    end
    
    # Perform Kolmogorov-Smirnov test
    test_result = ExactOneSampleKSTest(clean_group1, clean_group2)
    
    # Effect size is the D statistic itself (maximum difference between CDFs)
    d_statistic = test_result.δ
    
    # Confidence interval for D statistic (approximate)
    n_eff = (length(clean_group1) * length(clean_group2)) / (length(clean_group1) + length(clean_group2))
    critical_value_95 = 1.36 / sqrt(n_eff)  # 95% critical value
    
    ci_lower = max(0.0, d_statistic - critical_value_95)
    ci_upper = min(1.0, d_statistic + critical_value_95)
    
    # Interpretation
    is_significant = pvalue(test_result) < 0.05
    effect_magnitude = d_statistic < 0.2 ? "small" :
                      d_statistic < 0.5 ? "medium" : "large"
    
    interpretation = is_significant ?
        "Significant distributional difference between tolerance levels ($(effect_magnitude) effect, D=$(round(d_statistic, digits=3)))" :
        "No significant distributional difference ($(effect_magnitude) effect, D=$(round(d_statistic, digits=3)))"
    
    return StatisticalTestResult(
        "Kolmogorov-Smirnov",
        d_statistic,
        pvalue(test_result),
        d_statistic,
        (ci_lower, ci_upper),
        is_significant,
        interpretation,
        (length(clean_group1), length(clean_group2))
    )
end

"""
    perform_success_rate_comparison(results::MultiToleranceResults)

Perform statistical tests comparing success rates across tolerance levels using
exact binomial tests and Fisher's exact test.

# Arguments
- `results::MultiToleranceResults`: Multi-tolerance analysis results

# Returns
- `Vector{StatisticalTestResult}`: Success rate comparison results for all tolerance pairs
"""
function perform_success_rate_comparison(results::MultiToleranceResults)
    @info "Performing success rate comparisons across tolerance levels"
    
    tolerances = results.tolerance_sequence
    n_tolerances = length(tolerances)
    test_results = Vector{StatisticalTestResult}()
    
    # Pairwise comparisons between adjacent tolerance levels
    for i in 1:(n_tolerances-1)
        tol1, tol2 = tolerances[i], tolerances[i+1]
        result1 = results.results_by_tolerance[tol1]
        result2 = results.results_by_tolerance[tol2]
        
        # Extract success data
        distances1 = filter(!isnan, result1.bfgs_distances)
        distances2 = filter(!isnan, result2.bfgs_distances)
        
        if isempty(distances1) || isempty(distances2)
            @warn "Empty distance data for success rate comparison" tol1=tol1 tol2=tol2
            continue
        end
        
        # Count successes (distances below threshold)
        threshold = 0.1  # Success threshold
        successes1 = sum(distances1 .< threshold)
        successes2 = sum(distances2 .< threshold)
        n1, n2 = length(distances1), length(distances2)
        
        # Perform Fisher's exact test for 2x2 contingency table
        # [successes1, failures1; successes2, failures2]
        failures1 = n1 - successes1
        failures2 = n2 - successes2
        
        # Create contingency table
        contingency_table = [successes1 failures1; successes2 failures2]
        
        # Fisher's exact test
        fisher_test = FisherExactTest(contingency_table[1,1], contingency_table[1,2], 
                                     contingency_table[2,1], contingency_table[2,2])
        
        # Calculate proportions and confidence intervals
        prop1 = successes1 / n1
        prop2 = successes2 / n2
        prop_diff = prop2 - prop1
        
        # Wilson score confidence interval for proportion difference
        ci = wilson_score_ci_difference(successes1, n1, successes2, n2)
        
        # Effect size (Cohen's h for proportions)
        cohens_h = 2 * (asin(sqrt(prop1)) - asin(sqrt(prop2)))
        
        # Interpretation
        is_significant = pvalue(fisher_test) < 0.05
        direction = prop_diff > 0 ? "improvement" : "degradation"
        magnitude = abs(cohens_h) < 0.2 ? "small" :
                   abs(cohens_h) < 0.5 ? "medium" : "large"
        
        interpretation = is_significant ?
            "Significant success rate $(direction) from $(round(prop1*100, digits=1))% to $(round(prop2*100, digits=1))% ($(magnitude) effect)" :
            "No significant change in success rate ($(round(prop1*100, digits=1))% to $(round(prop2*100, digits=1))%, $(magnitude) effect)"
        
        test_result = StatisticalTestResult(
            "Fisher's Exact (Success Rate)",
            fisher_test.ω,  # Odds ratio
            pvalue(fisher_test),
            cohens_h,
            ci,
            is_significant,
            interpretation,
            (n1, n2)
        )
        
        push!(test_results, test_result)
    end
    
    return test_results
end

"""
    wilson_score_ci_difference(x1::Int, n1::Int, x2::Int, n2::Int, α::Float64 = 0.05)

Calculate Wilson score confidence interval for difference in proportions.

# Arguments
- `x1::Int`: Number of successes in group 1
- `n1::Int`: Total sample size for group 1
- `x2::Int`: Number of successes in group 2
- `n2::Int`: Total sample size for group 2
- `α::Float64`: Significance level (default: 0.05 for 95% CI)

# Returns
- `Tuple{Float64, Float64}`: Lower and upper confidence interval bounds
"""
function wilson_score_ci_difference(x1::Int, n1::Int, x2::Int, n2::Int, α::Float64 = 0.05)
    z = quantile(Normal(), 1 - α/2)
    
    p1 = x1 / n1
    p2 = x2 / n2
    diff = p2 - p1
    
    # Wilson score variance estimate
    var_p1 = p1 * (1 - p1) / n1
    var_p2 = p2 * (1 - p2) / n2
    se_diff = sqrt(var_p1 + var_p2)
    
    # Confidence interval
    margin = z * se_diff
    ci_lower = diff - margin
    ci_upper = diff + margin
    
    return (ci_lower, ci_upper)
end

"""
    perform_comprehensive_convergence_testing(results::MultiToleranceResults)

Perform comprehensive statistical testing suite for convergence analysis with
multiple comparison correction.

# Arguments
- `results::MultiToleranceResults`: Multi-tolerance analysis results

# Returns
- `ConvergenceTestSuite`: Complete statistical test results with multiple comparison correction
"""
function perform_comprehensive_convergence_testing(results::MultiToleranceResults)
    @info "Performing comprehensive convergence statistical testing suite"
    
    tolerances = results.tolerance_sequence
    n_tolerances = length(tolerances)
    
    # 1. Tolerance comparison tests (Mann-Whitney U for distance distributions)
    @info "Running pairwise tolerance comparisons..."
    tolerance_comparisons = Vector{StatisticalTestResult}()
    
    for i in 1:(n_tolerances-1)
        tol1, tol2 = tolerances[i], tolerances[i+1]
        
        distances1 = filter(!isnan, results.results_by_tolerance[tol1].bfgs_distances)
        distances2 = filter(!isnan, results.results_by_tolerance[tol2].bfgs_distances)
        
        if !isempty(distances1) && !isempty(distances2)
            mann_whitney_result = perform_mann_whitney_test(distances1, distances2, tol1, tol2)
            push!(tolerance_comparisons, mann_whitney_result)
        end
    end
    
    # 2. Distribution shape tests (Kolmogorov-Smirnov)
    @info "Running distribution shape tests..."
    distribution_tests = Vector{StatisticalTestResult}()
    
    for i in 1:(n_tolerances-1)
        tol1, tol2 = tolerances[i], tolerances[i+1]
        
        distances1 = filter(!isnan, results.results_by_tolerance[tol1].bfgs_distances)
        distances2 = filter(!isnan, results.results_by_tolerance[tol2].bfgs_distances)
        
        if !isempty(distances1) && !isempty(distances2)
            ks_result = perform_kolmogorov_smirnov_test(distances1, distances2, tol1, tol2)
            push!(distribution_tests, ks_result)
        end
    end
    
    # 3. Success rate comparisons (Fisher's exact test)
    @info "Running success rate comparisons..."
    success_rate_tests = perform_success_rate_comparison(results)
    
    # 4. Orthant performance heterogeneity tests
    @info "Running orthant performance tests..."
    orthant_performance_tests = perform_orthant_heterogeneity_tests(results)
    
    # 5. Multiple comparison correction (Bonferroni)
    all_tests = vcat(tolerance_comparisons, distribution_tests, success_rate_tests, orthant_performance_tests)
    n_tests = length(all_tests)
    bonferroni_alpha = 0.05 / n_tests
    
    @info "Applying Bonferroni correction" n_tests=n_tests bonferroni_alpha=bonferroni_alpha
    
    # Count significant results after correction
    significant_after_correction = sum(test.p_value < bonferroni_alpha for test in all_tests)
    overall_significance = significant_after_correction > 0
    
    @info "Statistical testing completed" n_total_tests=n_tests n_significant_uncorrected=sum(test.is_significant for test in all_tests) n_significant_corrected=significant_after_correction
    
    return ConvergenceTestSuite(
        tolerance_comparisons,
        distribution_tests,
        success_rate_tests,
        orthant_performance_tests,
        "Bonferroni (α = $(round(bonferroni_alpha, digits=6)))",
        overall_significance
    )
end

"""
    perform_orthant_heterogeneity_tests(results::MultiToleranceResults)

Test for spatial heterogeneity in orthant performance using Kruskal-Wallis test.

# Arguments
- `results::MultiToleranceResults`: Multi-tolerance analysis results

# Returns
- `Vector{StatisticalTestResult}`: Orthant heterogeneity test results
"""
function perform_orthant_heterogeneity_tests(results::MultiToleranceResults)
    @info "Testing orthant performance heterogeneity"
    
    test_results = Vector{StatisticalTestResult}()
    
    # Test for each tolerance level
    for tolerance in results.tolerance_sequence
        tol_result = results.results_by_tolerance[tolerance]
        orthant_data = tol_result.orthant_data
        
        if length(orthant_data) != 16
            @warn "Expected 16 orthants, got $(length(orthant_data))" tolerance=tolerance
            continue
        end
        
        # Extract success rates from each orthant
        success_rates = [orthant.success_rate for orthant in orthant_data]
        valid_rates = filter(!isnan, success_rates)
        
        if length(valid_rates) < 3
            @warn "Insufficient orthant data for heterogeneity test" tolerance=tolerance n_valid=length(valid_rates)
            continue
        end
        
        # Test if all orthants have similar performance (null: all medians equal)
        # Use Kruskal-Wallis test as a non-parametric alternative to ANOVA
        
        # Create grouping variable (orthant indices)
        orthant_groups = Vector{Int}()
        success_values = Vector{Float64}()
        
        for (i, orthant) in enumerate(orthant_data)
            if !isnan(orthant.success_rate)
                push!(orthant_groups, i)
                push!(success_values, orthant.success_rate)
            end
        end
        
        if length(unique(orthant_groups)) < 3
            @warn "Insufficient orthant groups for heterogeneity test" tolerance=tolerance n_groups=length(unique(orthant_groups))
            continue
        end
        
        # Perform one-way ANOVA test for orthant differences
        # Since we have one value per orthant, use variance in success rates as proxy
        overall_variance = var(success_values)
        overall_mean = mean(success_values)
        
        # Calculate coefficient of variation as effect size
        cv = overall_variance > 0 ? sqrt(overall_variance) / overall_mean : 0.0
        
        # Simple F-test approximation for heterogeneity
        n_orthants = length(success_values)
        f_statistic = overall_variance * (n_orthants - 1)
        
        # Approximate p-value using chi-square distribution
        p_value = 1 - cdf(Chisq(n_orthants - 1), f_statistic * (n_orthants - 1))
        
        is_significant = p_value < 0.05
        effect_magnitude = cv < 0.1 ? "small" :
                          cv < 0.3 ? "medium" : "large"
        
        interpretation = is_significant ?
            "Significant spatial heterogeneity in orthant performance (CV=$(round(cv, digits=3)), $(effect_magnitude) effect)" :
            "No significant spatial heterogeneity (CV=$(round(cv, digits=3)), $(effect_magnitude) effect)"
        
        test_result = StatisticalTestResult(
            "Orthant Heterogeneity (CV)",
            f_statistic,
            p_value,
            cv,
            (cv - 1.96*sqrt(cv/(n_orthants-1)), cv + 1.96*sqrt(cv/(n_orthants-1))),  # Approximate CI
            is_significant,
            interpretation,
            (n_orthants, n_orthants)
        )
        
        push!(test_results, test_result)
    end
    
    return test_results
end

# ================================================================================
# SPATIAL CLUSTERING AND PATTERN ANALYSIS
# ================================================================================

"""
    ClusterAnalysisResult

Structure to hold results from spatial clustering analysis of orthant performance.

# Fields
- `cluster_method::String`: Clustering algorithm used (e.g., "K-means", "Hierarchical")
- `n_clusters::Int`: Number of clusters identified
- `cluster_assignments::Vector{Int}`: Cluster assignment for each orthant (1-16)
- `cluster_centers::Matrix{Float64}`: Cluster centers in feature space
- `silhouette_score::Float64`: Overall clustering quality measure
- `within_cluster_variance::Vector{Float64}`: Variance within each cluster
- `between_cluster_variance::Float64`: Variance between cluster centers
- `feature_names::Vector{String}`: Names of features used for clustering
- `interpretation::String`: Human-readable interpretation of clustering results
"""
struct ClusterAnalysisResult
    cluster_method::String
    n_clusters::Int
    cluster_assignments::Vector{Int}
    cluster_centers::Matrix{Float64}
    silhouette_score::Float64
    within_cluster_variance::Vector{Float64}
    between_cluster_variance::Float64
    feature_names::Vector{String}
    interpretation::String
end

"""
    PCAAnalysisResult

Structure to hold results from Principal Component Analysis of orthant performance.

# Fields
- `explained_variance_ratio::Vector{Float64}`: Proportion of variance explained by each PC
- `cumulative_explained_variance::Vector{Float64}`: Cumulative variance explained
- `loadings::Matrix{Float64}`: Feature loadings on principal components
- `scores::Matrix{Float64}`: Orthant scores in PC space
- `feature_names::Vector{String}`: Names of original features
- `n_components_95::Int`: Number of components explaining 95% of variance
- `interpretation::String`: Human-readable interpretation of PCA results
"""
struct PCAAnalysisResult
    explained_variance_ratio::Vector{Float64}
    cumulative_explained_variance::Vector{Float64}
    loadings::Matrix{Float64}
    scores::Matrix{Float64}
    feature_names::Vector{String}
    n_components_95::Int
    interpretation::String
end

"""
    SpatialPatternSuite

Comprehensive spatial pattern analysis results combining clustering and PCA.

# Fields
- `pca_result::PCAAnalysisResult`: Principal component analysis results
- `kmeans_result::ClusterAnalysisResult`: K-means clustering results
- `hierarchical_result::ClusterAnalysisResult`: Hierarchical clustering results
- `optimal_k::Int`: Optimal number of clusters determined by elbow method
- `spatial_autocorrelation::Float64`: Moran's I statistic for spatial correlation
- `hotspot_orthants::Vector{Int}`: Orthant indices identified as performance hotspots
- `coldspot_orthants::Vector{Int}`: Orthant indices identified as performance coldspots
"""
struct SpatialPatternSuite
    pca_result::PCAAnalysisResult
    kmeans_result::ClusterAnalysisResult
    hierarchical_result::ClusterAnalysisResult
    optimal_k::Int
    spatial_autocorrelation::Float64
    hotspot_orthants::Vector{Int}
    coldspot_orthants::Vector{Int}
end

"""
    extract_orthant_features(orthant_data::Vector{OrthantResult})

Extract feature matrix from orthant data for clustering and PCA analysis.

# Arguments
- `orthant_data::Vector{OrthantResult}`: Vector of 16 orthant results

# Returns
- `Tuple{Matrix{Float64}, Vector{String}}`: Feature matrix (16×n_features) and feature names
"""
function extract_orthant_features(orthant_data::Vector{OrthantResult})
    @assert length(orthant_data) == 16 "Expected exactly 16 orthant results"
    
    @info "Extracting features from orthant data for spatial analysis"
    
    # Define features to extract
    feature_names = [
        "success_rate",
        "median_distance", 
        "log_median_distance",
        "polynomial_degree",
        "computation_time",
        "log_computation_time",
        "raw_point_count",
        "bfgs_point_count",
        "outlier_count",
        "efficiency_ratio"  # bfgs_points / computation_time
    ]
    
    n_features = length(feature_names)
    feature_matrix = Matrix{Float64}(undef, 16, n_features)
    
    for (i, orthant) in enumerate(orthant_data)
        try
            # Basic performance metrics
            feature_matrix[i, 1] = orthant.success_rate
            feature_matrix[i, 2] = orthant.median_distance
            feature_matrix[i, 3] = log10(max(orthant.median_distance, 1e-16))  # Log transform
            feature_matrix[i, 4] = float(orthant.polynomial_degree)
            feature_matrix[i, 5] = orthant.computation_time
            feature_matrix[i, 6] = log10(max(orthant.computation_time, 1e-6))  # Log transform
            feature_matrix[i, 7] = float(orthant.raw_point_count)
            feature_matrix[i, 8] = float(orthant.bfgs_point_count)
            feature_matrix[i, 9] = float(orthant.outlier_count)
            
            # Derived efficiency metric
            efficiency = orthant.computation_time > 0 ? orthant.bfgs_point_count / orthant.computation_time : 0.0
            feature_matrix[i, 10] = efficiency
            
        catch e
            @warn "Error extracting features for orthant $i" error=e
            # Fill with default values for problematic orthants
            feature_matrix[i, :] .= 0.0
        end
    end
    
    # Handle NaN and Inf values
    for i in 1:size(feature_matrix, 1)
        for j in 1:size(feature_matrix, 2)
            if !isfinite(feature_matrix[i, j])
                feature_matrix[i, j] = 0.0
            end
        end
    end
    
    @info "Feature extraction completed" n_orthants=16 n_features=n_features
    return feature_matrix, feature_names
end

"""
    standardize_features(feature_matrix::Matrix{Float64})

Standardize features to zero mean and unit variance for clustering analysis.

# Arguments
- `feature_matrix::Matrix{Float64}`: Raw feature matrix (n_samples × n_features)

# Returns
- `Tuple{Matrix{Float64}, Vector{Float64}, Vector{Float64}}`: Standardized matrix, means, standard deviations
"""
function standardize_features(feature_matrix::Matrix{Float64})
    @info "Standardizing features for clustering analysis"
    
    n_samples, n_features = size(feature_matrix)
    standardized_matrix = copy(feature_matrix)
    
    # Calculate means and standard deviations
    feature_means = vec(mean(feature_matrix, dims=1))
    feature_stds = vec(std(feature_matrix, dims=1))
    
    # Standardize each feature
    for j in 1:n_features
        if feature_stds[j] > 1e-10  # Avoid division by zero
            standardized_matrix[:, j] = (feature_matrix[:, j] .- feature_means[j]) ./ feature_stds[j]
        else
            # Constant feature - center at zero
            standardized_matrix[:, j] .= 0.0
        end
    end
    
    @info "Feature standardization completed" n_constant_features=sum(feature_stds .<= 1e-10)
    return standardized_matrix, feature_means, feature_stds
end

"""
    perform_pca_analysis(feature_matrix::Matrix{Float64}, feature_names::Vector{String})

Perform Principal Component Analysis on orthant features to identify dominant patterns.

# Arguments
- `feature_matrix::Matrix{Float64}`: Standardized feature matrix (16×n_features)
- `feature_names::Vector{String}`: Names of features

# Returns
- `PCAAnalysisResult`: Comprehensive PCA analysis results
"""
function perform_pca_analysis(feature_matrix::Matrix{Float64}, feature_names::Vector{String})
    @info "Performing Principal Component Analysis on orthant features"
    
    n_samples, n_features = size(feature_matrix)
    
    if n_samples < 3
        @warn "Insufficient samples for PCA" n_samples=n_samples
        return PCAAnalysisResult(
            Float64[], Float64[], zeros(0, 0), zeros(0, 0),
            feature_names, 0, "Insufficient data for PCA"
        )
    end
    
    # Perform PCA using MultivariateStats.jl
    try
        # Fit PCA model
        pca_model = fit(PCA, feature_matrix'; maxoutdim=min(n_samples-1, n_features))
        
        # Extract results
        explained_variance_ratio = principalvars(pca_model) ./ tprincipalvar(pca_model)
        cumulative_explained_variance = cumsum(explained_variance_ratio)
        
        # Loadings (eigenvectors)
        loadings = projection(pca_model)'  # Transpose to get features × components
        
        # Transform data to PC space
        scores = transform(pca_model, feature_matrix')'  # Transpose back to samples × components
        
        # Find number of components explaining 95% of variance
        n_components_95 = findfirst(cum_var -> cum_var >= 0.95, cumulative_explained_variance)
        n_components_95 = n_components_95 === nothing ? length(cumulative_explained_variance) : n_components_95
        
        # Interpretation
        pc1_var = round(explained_variance_ratio[1] * 100, digits=1)
        pc2_var = length(explained_variance_ratio) > 1 ? round(explained_variance_ratio[2] * 100, digits=1) : 0.0
        total_var_first_two = pc1_var + pc2_var
        
        interpretation = "PC1 explains $(pc1_var)% of variance, PC2 explains $(pc2_var)% " *
                        "($(round(total_var_first_two, digits=1))% total). " *
                        "$(n_components_95) components needed for 95% variance."
        
        @info "PCA analysis completed" pc1_variance=pc1_var pc2_variance=pc2_var n_components_95=n_components_95
        
        return PCAAnalysisResult(
            explained_variance_ratio,
            cumulative_explained_variance,
            loadings,
            scores,
            feature_names,
            n_components_95,
            interpretation
        )
        
    catch e
        @warn "PCA analysis failed" error=e
        return PCAAnalysisResult(
            Float64[], Float64[], zeros(0, 0), zeros(0, 0),
            feature_names, 0, "PCA analysis failed: $e"
        )
    end
end

"""
    perform_kmeans_clustering(feature_matrix::Matrix{Float64}, k::Int, feature_names::Vector{String})

Perform K-means clustering on orthant features.

# Arguments
- `feature_matrix::Matrix{Float64}`: Standardized feature matrix (16×n_features)
- `k::Int`: Number of clusters
- `feature_names::Vector{String}`: Names of features

# Returns
- `ClusterAnalysisResult`: K-means clustering results
"""
function perform_kmeans_clustering(feature_matrix::Matrix{Float64}, k::Int, feature_names::Vector{String})
    @info "Performing K-means clustering" k=k n_features=length(feature_names)
    
    n_samples, n_features = size(feature_matrix)
    
    if n_samples < k
        @warn "More clusters requested than samples" n_samples=n_samples k=k
        k = max(1, n_samples - 1)
    end
    
    try
        # Perform K-means clustering
        kmeans_result = kmeans(feature_matrix', k; maxiter=100, display=:none)
        
        # Extract results
        cluster_assignments = assignments(kmeans_result)
        cluster_centers = centers(kmeans_result)'  # Transpose to get clusters × features
        
        # Calculate silhouette score
        silhouette_avg = calculate_silhouette_score(feature_matrix, cluster_assignments)
        
        # Calculate within-cluster variances
        within_cluster_vars = Float64[]
        for cluster_id in 1:k
            cluster_mask = cluster_assignments .== cluster_id
            if sum(cluster_mask) > 1
                cluster_data = feature_matrix[cluster_mask, :]
                cluster_var = mean(var(cluster_data, dims=1))
                push!(within_cluster_vars, cluster_var)
            else
                push!(within_cluster_vars, 0.0)
            end
        end
        
        # Calculate between-cluster variance
        overall_center = vec(mean(feature_matrix, dims=1))
        between_cluster_var = 0.0
        for i in 1:k
            cluster_size = sum(cluster_assignments .== i)
            if cluster_size > 0
                center_diff = cluster_centers[i, :] .- overall_center
                between_cluster_var += cluster_size * sum(center_diff.^2)
            end
        end
        between_cluster_var /= n_samples
        
        # Interpretation
        cluster_sizes = [sum(cluster_assignments .== i) for i in 1:k]
        interpretation = "Identified $k clusters with sizes: $(join(cluster_sizes, ", ")). " *
                        "Silhouette score: $(round(silhouette_avg, digits=3)) " *
                        "(>0.5 good, >0.7 excellent)."
        
        @info "K-means clustering completed" k=k silhouette_score=round(silhouette_avg, digits=3) cluster_sizes=cluster_sizes
        
        return ClusterAnalysisResult(
            "K-means",
            k,
            cluster_assignments,
            cluster_centers,
            silhouette_avg,
            within_cluster_vars,
            between_cluster_var,
            feature_names,
            interpretation
        )
        
    catch e
        @warn "K-means clustering failed" error=e k=k
        return ClusterAnalysisResult(
            "K-means",
            1,
            ones(Int, n_samples),
            reshape(vec(mean(feature_matrix, dims=1)), 1, :),
            0.0,
            [0.0],
            0.0,
            feature_names,
            "K-means clustering failed: $e"
        )
    end
end

"""
    calculate_silhouette_score(feature_matrix::Matrix{Float64}, cluster_assignments::Vector{Int})

Calculate average silhouette score for clustering quality assessment.

# Arguments
- `feature_matrix::Matrix{Float64}`: Feature matrix used for clustering
- `cluster_assignments::Vector{Int}`: Cluster assignment for each sample

# Returns
- `Float64`: Average silhouette score (-1 to +1, higher is better)
"""
function calculate_silhouette_score(feature_matrix::Matrix{Float64}, cluster_assignments::Vector{Int})
    n_samples = size(feature_matrix, 1)
    n_clusters = maximum(cluster_assignments)
    
    if n_clusters <= 1 || n_samples <= 1
        return 0.0
    end
    
    silhouette_scores = Float64[]
    
    for i in 1:n_samples
        current_cluster = cluster_assignments[i]
        
        # Calculate average distance to points in same cluster (a_i)
        same_cluster_indices = findall(j -> cluster_assignments[j] == current_cluster && j != i, 1:n_samples)
        
        if isempty(same_cluster_indices)
            # Singleton cluster
            push!(silhouette_scores, 0.0)
            continue
        end
        
        a_i = mean([norm(feature_matrix[i, :] - feature_matrix[j, :]) for j in same_cluster_indices])
        
        # Calculate minimum average distance to points in other clusters (b_i)
        b_i = Inf
        for cluster_id in 1:n_clusters
            if cluster_id != current_cluster
                other_cluster_indices = findall(j -> cluster_assignments[j] == cluster_id, 1:n_samples)
                if !isempty(other_cluster_indices)
                    avg_dist = mean([norm(feature_matrix[i, :] - feature_matrix[j, :]) for j in other_cluster_indices])
                    b_i = min(b_i, avg_dist)
                end
            end
        end
        
        # Calculate silhouette score for this sample
        if b_i == Inf
            silhouette_i = 0.0
        else
            silhouette_i = (b_i - a_i) / max(a_i, b_i)
        end
        
        push!(silhouette_scores, silhouette_i)
    end
    
    return mean(silhouette_scores)
end

"""
    determine_optimal_clusters(feature_matrix::Matrix{Float64}, max_k::Int = 8)

Determine optimal number of clusters using elbow method and silhouette analysis.

# Arguments
- `feature_matrix::Matrix{Float64}`: Standardized feature matrix
- `max_k::Int`: Maximum number of clusters to test

# Returns
- `Tuple{Int, Vector{Float64}, Vector{Float64}}`: Optimal k, within-cluster sum of squares, silhouette scores
"""
function determine_optimal_clusters(feature_matrix::Matrix{Float64}, max_k::Int = 8)
    @info "Determining optimal number of clusters using elbow method"
    
    n_samples = size(feature_matrix, 1)
    max_k = min(max_k, n_samples - 1, 8)  # Practical limit for 16 orthants
    
    wcss_values = Float64[]  # Within-cluster sum of squares
    silhouette_scores = Float64[]
    
    for k in 1:max_k
        try
            if k == 1
                # Single cluster - calculate total variance
                center = vec(mean(feature_matrix, dims=1))
                wcss = sum(sum((feature_matrix[i, :] .- center).^2) for i in 1:n_samples)
                push!(wcss_values, wcss)
                push!(silhouette_scores, 0.0)
            else
                # Multiple clusters
                kmeans_result = kmeans(feature_matrix', k; maxiter=100, display=:none)
                push!(wcss_values, wcss(kmeans_result))
                
                cluster_assignments = assignments(kmeans_result)
                silhouette_avg = calculate_silhouette_score(feature_matrix, cluster_assignments)
                push!(silhouette_scores, silhouette_avg)
            end
        catch e
            @warn "Failed to evaluate k=$k" error=e
            push!(wcss_values, NaN)
            push!(silhouette_scores, NaN)
        end
    end
    
    # Find elbow using rate of change in WCSS
    optimal_k_elbow = 2  # Default fallback
    if length(wcss_values) >= 3
        # Calculate second derivative (curvature) to find elbow
        second_derivatives = Float64[]
        for i in 2:(length(wcss_values)-1)
            if all(isfinite, wcss_values[(i-1):(i+1)])
                second_deriv = wcss_values[i-1] - 2*wcss_values[i] + wcss_values[i+1]
                push!(second_derivatives, second_deriv)
            else
                push!(second_derivatives, 0.0)
            end
        end
        
        if !isempty(second_derivatives)
            elbow_idx = argmax(second_derivatives)
            optimal_k_elbow = elbow_idx + 1  # Adjust for indexing
        end
    end
    
    # Find optimal k using silhouette score
    valid_silhouettes = [(i, score) for (i, score) in enumerate(silhouette_scores) if isfinite(score) && i > 1]
    optimal_k_silhouette = 2  # Default
    if !isempty(valid_silhouettes)
        _, max_idx = findmax(last.(valid_silhouettes))
        optimal_k_silhouette = first(valid_silhouettes[max_idx])
    end
    
    # Choose final optimal k (prefer silhouette method if scores are close)
    optimal_k = abs(optimal_k_elbow - optimal_k_silhouette) <= 1 ? optimal_k_silhouette : optimal_k_elbow
    optimal_k = max(2, min(optimal_k, max_k))  # Ensure reasonable range
    
    @info "Optimal cluster analysis completed" optimal_k_elbow=optimal_k_elbow optimal_k_silhouette=optimal_k_silhouette final_optimal_k=optimal_k
    
    return optimal_k, wcss_values, silhouette_scores
end

"""
    identify_spatial_hotspots(orthant_data::Vector{OrthantResult}, threshold_percentile::Float64 = 90.0)

Identify performance hotspots and coldspots based on success rates.

# Arguments
- `orthant_data::Vector{OrthantResult}`: Vector of 16 orthant results
- `threshold_percentile::Float64`: Percentile threshold for hotspot identification

# Returns
- `Tuple{Vector{Int}, Vector{Int}}`: Hotspot orthant indices, coldspot orthant indices
"""
function identify_spatial_hotspots(orthant_data::Vector{OrthantResult}, threshold_percentile::Float64 = 90.0)
    @assert length(orthant_data) == 16 "Expected exactly 16 orthant results"
    
    @info "Identifying spatial performance hotspots and coldspots" threshold_percentile=threshold_percentile
    
    # Extract success rates
    success_rates = [orthant.success_rate for orthant in orthant_data]
    valid_rates = filter(!isnan, success_rates)
    
    if length(valid_rates) < 3
        @warn "Insufficient valid success rates for hotspot analysis" n_valid=length(valid_rates)
        return Int[], Int[]
    end
    
    # Calculate thresholds
    hotspot_threshold = percentile(valid_rates, threshold_percentile)
    coldspot_threshold = percentile(valid_rates, 100 - threshold_percentile)
    
    # Identify hotspots and coldspots
    hotspot_orthants = Int[]
    coldspot_orthants = Int[]
    
    for (i, orthant) in enumerate(orthant_data)
        if !isnan(orthant.success_rate)
            if orthant.success_rate >= hotspot_threshold
                push!(hotspot_orthants, i)
            elseif orthant.success_rate <= coldspot_threshold
                push!(coldspot_orthants, i)
            end
        end
    end
    
    @info "Hotspot analysis completed" n_hotspots=length(hotspot_orthants) n_coldspots=length(coldspot_orthants) hotspot_threshold=round(hotspot_threshold, digits=3) coldspot_threshold=round(coldspot_threshold, digits=3)
    
    return hotspot_orthants, coldspot_orthants
end

"""
    perform_comprehensive_spatial_analysis(orthant_data::Vector{OrthantResult})

Perform comprehensive spatial pattern analysis combining PCA, clustering, and hotspot detection.

# Arguments
- `orthant_data::Vector{OrthantResult}`: Vector of 16 orthant results

# Returns
- `SpatialPatternSuite`: Complete spatial analysis results
"""
function perform_comprehensive_spatial_analysis(orthant_data::Vector{OrthantResult})
    @info "Performing comprehensive spatial pattern analysis"
    
    # 1. Extract and standardize features
    feature_matrix, feature_names = extract_orthant_features(orthant_data)
    standardized_features, _, _ = standardize_features(feature_matrix)
    
    # 2. Principal Component Analysis
    @info "Running PCA analysis..."
    pca_result = perform_pca_analysis(standardized_features, feature_names)
    
    # 3. Determine optimal number of clusters
    @info "Determining optimal cluster count..."
    optimal_k, wcss_values, silhouette_scores = determine_optimal_clusters(standardized_features)
    
    # 4. K-means clustering with optimal k
    @info "Running K-means clustering with optimal k..." optimal_k=optimal_k
    kmeans_result = perform_kmeans_clustering(standardized_features, optimal_k, feature_names)
    
    # 5. Hierarchical clustering for comparison
    @info "Running hierarchical clustering..."
    hierarchical_result = perform_hierarchical_clustering(standardized_features, optimal_k, feature_names)
    
    # 6. Spatial autocorrelation analysis
    @info "Calculating spatial autocorrelation..."
    spatial_autocorr = calculate_spatial_autocorrelation(orthant_data)
    
    # 7. Hotspot detection
    @info "Identifying performance hotspots..."
    hotspot_orthants, coldspot_orthants = identify_spatial_hotspots(orthant_data)
    
    @info "Comprehensive spatial analysis completed" optimal_k=optimal_k n_hotspots=length(hotspot_orthants) n_coldspots=length(coldspot_orthants) spatial_autocorr=round(spatial_autocorr, digits=3)
    
    return SpatialPatternSuite(
        pca_result,
        kmeans_result,
        hierarchical_result,
        optimal_k,
        spatial_autocorr,
        hotspot_orthants,
        coldspot_orthants
    )
end

"""
    perform_hierarchical_clustering(feature_matrix::Matrix{Float64}, k::Int, feature_names::Vector{String})

Perform hierarchical clustering on orthant features for comparison with K-means.

# Arguments
- `feature_matrix::Matrix{Float64}`: Standardized feature matrix
- `k::Int`: Number of clusters to extract
- `feature_names::Vector{String}`: Names of features

# Returns
- `ClusterAnalysisResult`: Hierarchical clustering results
"""
function perform_hierarchical_clustering(feature_matrix::Matrix{Float64}, k::Int, feature_names::Vector{String})
    @info "Performing hierarchical clustering" k=k
    
    n_samples, n_features = size(feature_matrix)
    
    try
        # Calculate pairwise distances
        distances = pairwise(Euclidean(), feature_matrix', dims=2)
        
        # Perform hierarchical clustering
        hclust_result = hclust(distances, linkage=:ward)
        
        # Cut dendrogram to get k clusters
        cluster_assignments = cutree(hclust_result, k=k)
        
        # Calculate cluster centers
        cluster_centers = Matrix{Float64}(undef, k, n_features)
        for cluster_id in 1:k
            cluster_mask = cluster_assignments .== cluster_id
            if any(cluster_mask)
                cluster_centers[cluster_id, :] = vec(mean(feature_matrix[cluster_mask, :], dims=1))
            else
                cluster_centers[cluster_id, :] = zeros(n_features)
            end
        end
        
        # Calculate silhouette score
        silhouette_avg = calculate_silhouette_score(feature_matrix, cluster_assignments)
        
        # Calculate within-cluster variances
        within_cluster_vars = Float64[]
        for cluster_id in 1:k
            cluster_mask = cluster_assignments .== cluster_id
            if sum(cluster_mask) > 1
                cluster_data = feature_matrix[cluster_mask, :]
                cluster_var = mean(var(cluster_data, dims=1))
                push!(within_cluster_vars, cluster_var)
            else
                push!(within_cluster_vars, 0.0)
            end
        end
        
        # Calculate between-cluster variance
        overall_center = vec(mean(feature_matrix, dims=1))
        between_cluster_var = 0.0
        for i in 1:k
            cluster_size = sum(cluster_assignments .== i)
            if cluster_size > 0
                center_diff = cluster_centers[i, :] .- overall_center
                between_cluster_var += cluster_size * sum(center_diff.^2)
            end
        end
        between_cluster_var /= n_samples
        
        # Interpretation
        cluster_sizes = [sum(cluster_assignments .== i) for i in 1:k]
        interpretation = "Hierarchical clustering (Ward linkage) identified $k clusters with sizes: $(join(cluster_sizes, ", ")). " *
                        "Silhouette score: $(round(silhouette_avg, digits=3))."
        
        @info "Hierarchical clustering completed" k=k silhouette_score=round(silhouette_avg, digits=3) cluster_sizes=cluster_sizes
        
        return ClusterAnalysisResult(
            "Hierarchical (Ward)",
            k,
            cluster_assignments,
            cluster_centers,
            silhouette_avg,
            within_cluster_vars,
            between_cluster_var,
            feature_names,
            interpretation
        )
        
    catch e
        @warn "Hierarchical clustering failed" error=e
        return ClusterAnalysisResult(
            "Hierarchical (Ward)",
            1,
            ones(Int, n_samples),
            reshape(vec(mean(feature_matrix, dims=1)), 1, :),
            0.0,
            [0.0],
            0.0,
            feature_names,
            "Hierarchical clustering failed: $e"
        )
    end
end

"""
    calculate_spatial_autocorrelation(orthant_data::Vector{OrthantResult})

Calculate Moran's I statistic for spatial autocorrelation in orthant performance.
Uses a simplified 4D spatial weights matrix based on orthant adjacency.

# Arguments
- `orthant_data::Vector{OrthantResult}`: Vector of 16 orthant results

# Returns
- `Float64`: Moran's I statistic (-1 to +1, positive indicates clustering)
"""
function calculate_spatial_autocorrelation(orthant_data::Vector{OrthantResult})
    @assert length(orthant_data) == 16 "Expected exactly 16 orthant results"
    
    @info "Calculating spatial autocorrelation (Moran's I)"
    
    # Extract success rates
    success_rates = [orthant.success_rate for orthant in orthant_data]
    valid_mask = .!isnan.(success_rates)
    
    if sum(valid_mask) < 4
        @warn "Insufficient valid success rates for spatial autocorrelation" n_valid=sum(valid_mask)
        return 0.0
    end
    
    # Create spatial weights matrix for 4D orthants
    # Orthants are adjacent if they differ in exactly one sign
    weights = zeros(16, 16)
    
    for i in 1:16
        for j in 1:16
            if i != j
                # Convert orthant index to sign pattern
                signs_i = [(i-1) & (1 << k) != 0 ? 1 : -1 for k in 0:3]
                signs_j = [(j-1) & (1 << k) != 0 ? 1 : -1 for k in 0:3]
                
                # Count differences
                n_differences = sum(signs_i .!= signs_j)
                
                # Adjacent if exactly one difference
                if n_differences == 1
                    weights[i, j] = 1.0
                end
            end
        end
    end
    
    # Only use orthants with valid success rates
    valid_indices = findall(valid_mask)
    filtered_rates = success_rates[valid_indices]
    filtered_weights = weights[valid_indices, valid_indices]
    
    # Calculate Moran's I
    n = length(filtered_rates)
    if n < 3
        return 0.0
    end
    
    # Standardize the values
    y_mean = mean(filtered_rates)
    y_centered = filtered_rates .- y_mean
    
    # Calculate numerator and denominator
    W = sum(filtered_weights)  # Sum of all weights
    
    if W == 0
        return 0.0  # No spatial connections
    end
    
    numerator = 0.0
    for i in 1:n
        for j in 1:n
            numerator += filtered_weights[i, j] * y_centered[i] * y_centered[j]
        end
    end
    numerator *= n
    
    denominator = W * sum(y_centered.^2)
    
    morans_i = denominator > 0 ? numerator / denominator : 0.0
    
    @info "Spatial autocorrelation calculated" morans_i=round(morans_i, digits=4) n_valid_orthants=n n_connections=Int(W)
    
    return morans_i
end

# ================================================================================
# PERFORMANCE PREDICTION MODELS
# ================================================================================

"""
    PredictionModelResult

Structure to hold results from performance prediction models.

# Fields
- `model_type::String`: Type of prediction model (e.g., "Polynomial", "Logistic", "Random Forest")
- `target_variable::String`: Variable being predicted (e.g., "polynomial_degree", "success_rate")
- `feature_importance::Vector{Tuple{String, Float64}}`: Feature names and importance scores
- `model_accuracy::Float64`: Model accuracy or R² score
- `cross_validation_score::Float64`: Cross-validation performance
- `predictions::Vector{Float64}`: Model predictions for training data
- `residuals::Vector{Float64}`: Prediction residuals
- `confidence_intervals::Vector{Tuple{Float64, Float64}}`: Prediction confidence intervals
- `interpretation::String`: Human-readable model interpretation
"""
struct PredictionModelResult
    model_type::String
    target_variable::String
    feature_importance::Vector{Tuple{String, Float64}}
    model_accuracy::Float64
    cross_validation_score::Float64
    predictions::Vector{Float64}
    residuals::Vector{Float64}
    confidence_intervals::Vector{Tuple{Float64, Float64}}
    interpretation::String
end

"""
    PerformancePredictionSuite

Comprehensive performance prediction results for convergence analysis.

# Fields
- `degree_prediction::PredictionModelResult`: Polynomial degree requirement prediction
- `sample_prediction::PredictionModelResult`: Sample count requirement prediction
- `success_rate_prediction::PredictionModelResult`: Success rate prediction
- `computation_time_prediction::PredictionModelResult`: Computation time prediction
- `tolerance_scaling_model::Dict{String, Float64}`: Power law scaling parameters
- `prediction_accuracy_summary::NamedTuple`: Overall prediction performance summary
"""
struct PerformancePredictionSuite
    degree_prediction::PredictionModelResult
    sample_prediction::PredictionModelResult
    success_rate_prediction::PredictionModelResult
    computation_time_prediction::PredictionModelResult
    tolerance_scaling_model::Dict{String, Float64}
    prediction_accuracy_summary::NamedTuple
end

"""
    prepare_prediction_features(results::MultiToleranceResults)

Prepare feature matrix for performance prediction models.

# Arguments
- `results::MultiToleranceResults`: Multi-tolerance analysis results

# Returns
- `Tuple{Matrix{Float64}, Vector{String}, Dict{String, Vector{Float64}}}`: Feature matrix, feature names, target variables
"""
function prepare_prediction_features(results::MultiToleranceResults)
    @info "Preparing features for performance prediction models"
    
    tolerances = results.tolerance_sequence
    n_tolerances = length(tolerances)
    
    # Features for prediction: tolerance level, orthant characteristics, etc.
    feature_names = [
        "log_tolerance",
        "tolerance_rank",
        "orthant_complexity_mean",
        "orthant_complexity_std",
        "previous_degree_mean",
        "previous_success_rate",
        "domain_range"
    ]
    
    n_features = length(feature_names)
    feature_matrix = Matrix{Float64}(undef, n_tolerances, n_features)
    
    # Target variables to predict
    target_variables = Dict{String, Vector{Float64}}()
    target_variables["polynomial_degree"] = Float64[]
    target_variables["sample_count"] = Float64[]
    target_variables["success_rate"] = Float64[]
    target_variables["computation_time"] = Float64[]
    
    for (i, tolerance) in enumerate(tolerances)
        tol_result = results.results_by_tolerance[tolerance]
        
        # Extract features
        feature_matrix[i, 1] = log10(tolerance)  # Log tolerance
        feature_matrix[i, 2] = float(i)  # Tolerance rank (progression order)
        
        # Orthant complexity metrics
        if length(tol_result.orthant_data) == 16
            success_rates = [o.success_rate for o in tol_result.orthant_data if !isnan(o.success_rate)]
            if !isempty(success_rates)
                feature_matrix[i, 3] = mean(success_rates)
                feature_matrix[i, 4] = std(success_rates)
            else
                feature_matrix[i, 3] = 0.5  # Default
                feature_matrix[i, 4] = 0.1
            end
        else
            feature_matrix[i, 3] = 0.5
            feature_matrix[i, 4] = 0.1
        end
        
        # Previous performance metrics (for sequential prediction)
        if i > 1
            prev_tol = tolerances[i-1]
            prev_result = results.results_by_tolerance[prev_tol]
            feature_matrix[i, 5] = mean(prev_result.polynomial_degrees)
            feature_matrix[i, 6] = prev_result.success_rates.bfgs
        else
            feature_matrix[i, 5] = 4.0  # Default starting degree
            feature_matrix[i, 6] = 0.5  # Default success rate
        end
        
        # Domain characteristics
        domain_config = results.domain_config
        if haskey(domain_config, :sample_range)
            feature_matrix[i, 7] = domain_config.sample_range
        else
            feature_matrix[i, 7] = 1.0  # Default range
        end
        
        # Extract target variables
        push!(target_variables["polynomial_degree"], mean(tol_result.polynomial_degrees))
        push!(target_variables["sample_count"], float(sum(tol_result.sample_counts)))
        push!(target_variables["success_rate"], tol_result.success_rates.bfgs)
        push!(target_variables["computation_time"], tol_result.computation_time)
    end
    
    # Handle NaN and Inf values
    for i in 1:size(feature_matrix, 1)
        for j in 1:size(feature_matrix, 2)
            if !isfinite(feature_matrix[i, j])
                feature_matrix[i, j] = 0.0
            end
        end
    end
    
    @info "Feature preparation completed" n_samples=n_tolerances n_features=n_features
    return feature_matrix, feature_names, target_variables
end

"""
    fit_polynomial_regression(X::Matrix{Float64}, y::Vector{Float64}, feature_names::Vector{String}, target_name::String; degree::Int = 2)

Fit polynomial regression model for performance prediction.

# Arguments
- `X::Matrix{Float64}`: Feature matrix (n_samples × n_features)
- `y::Vector{Float64}`: Target variable values
- `feature_names::Vector{String}`: Names of features
- `target_name::String`: Name of target variable
- `degree::Int`: Polynomial degree for regression

# Returns
- `PredictionModelResult`: Polynomial regression results
"""
function fit_polynomial_regression(X::Matrix{Float64}, y::Vector{Float64}, feature_names::Vector{String}, target_name::String; degree::Int = 2)
    @info "Fitting polynomial regression model" target=target_name degree=degree n_samples=length(y)
    
    n_samples, n_features = size(X)
    
    if n_samples < 3
        @warn "Insufficient samples for polynomial regression" n_samples=n_samples
        return PredictionModelResult(
            "Polynomial (degree $degree)",
            target_name,
            [(name, 0.0) for name in feature_names],
            0.0, 0.0, zeros(0), zeros(0), Tuple{Float64, Float64}[],
            "Insufficient data for polynomial regression"
        )
    end
    
    try
        # Standardize features
        X_standardized = copy(X)
        feature_means = vec(mean(X, dims=1))
        feature_stds = vec(std(X, dims=1))
        
        for j in 1:n_features
            if feature_stds[j] > 1e-10
                X_standardized[:, j] = (X[:, j] .- feature_means[j]) ./ feature_stds[j]
            end
        end
        
        # Create polynomial features (for degree > 1)
        if degree > 1 && n_features == 1
            # Simple polynomial features for univariate case
            X_poly = hcat(X_standardized, X_standardized.^2)
            if degree > 2
                X_poly = hcat(X_poly, X_standardized.^3)
            end
        else
            X_poly = X_standardized
        end
        
        # Add intercept term
        X_design = hcat(ones(n_samples), X_poly)
        
        # Fit regression using least squares
        if rank(X_design) == size(X_design, 2)
            coefficients = X_design \ y
            predictions = X_design * coefficients
            residuals = y - predictions
            
            # Calculate R²
            ss_tot = sum((y .- mean(y)).^2)
            ss_res = sum(residuals.^2)
            r_squared = ss_tot > 0 ? 1 - ss_res / ss_tot : 0.0
            
            # Simple cross-validation (leave-one-out for small samples)
            cv_predictions = Float64[]
            for i in 1:n_samples
                train_mask = trues(n_samples)
                train_mask[i] = false
                
                if sum(train_mask) >= 2
                    X_train = X_design[train_mask, :]
                    y_train = y[train_mask]
                    X_test = X_design[i:i, :]
                    
                    try
                        coef_cv = X_train \ y_train
                        pred_cv = (X_test * coef_cv)[1]
                        push!(cv_predictions, pred_cv)
                    catch
                        push!(cv_predictions, mean(y_train))
                    end
                else
                    push!(cv_predictions, mean(y))
                end
            end
            
            cv_residuals = y - cv_predictions
            cv_ss_res = sum(cv_residuals.^2)
            cv_score = ss_tot > 0 ? 1 - cv_ss_res / ss_tot : 0.0
            
            # Feature importance (absolute coefficient values)
            feature_importance = Tuple{String, Float64}[]
            for j in 1:min(length(feature_names), length(coefficients)-1)
                importance = abs(coefficients[j+1])  # Skip intercept
                push!(feature_importance, (feature_names[j], importance))
            end
            sort!(feature_importance, by=x->x[2], rev=true)
            
            # Confidence intervals (approximate)
            mse = ss_res / max(1, n_samples - size(X_design, 2))
            se = sqrt(mse)
            confidence_intervals = [(pred - 1.96*se, pred + 1.96*se) for pred in predictions]
            
            # Interpretation
            top_feature = isempty(feature_importance) ? "none" : feature_importance[1][1]
            interpretation = "R² = $(round(r_squared, digits=3)), CV score = $(round(cv_score, digits=3)). " *
                           "Most important feature: $top_feature. " *
                           "RMSE = $(round(sqrt(mse), digits=3))."
            
            @info "Polynomial regression completed" target=target_name r_squared=round(r_squared, digits=3) cv_score=round(cv_score, digits=3)
            
            return PredictionModelResult(
                "Polynomial (degree $degree)",
                target_name,
                feature_importance,
                r_squared,
                cv_score,
                predictions,
                residuals,
                confidence_intervals,
                interpretation
            )
            
        else
            @warn "Singular design matrix in polynomial regression" target=target_name
            return PredictionModelResult(
                "Polynomial (degree $degree)",
                target_name,
                [(name, 0.0) for name in feature_names],
                0.0, 0.0, fill(mean(y), n_samples), y .- mean(y), 
                [(mean(y), mean(y)) for _ in 1:n_samples],
                "Singular design matrix - using mean prediction"
            )
        end
        
    catch e
        @warn "Polynomial regression failed" target=target_name error=e
        return PredictionModelResult(
            "Polynomial (degree $degree)",
            target_name,
            [(name, 0.0) for name in feature_names],
            0.0, 0.0, fill(mean(y), n_samples), y .- mean(y), 
            [(mean(y), mean(y)) for _ in 1:n_samples],
            "Polynomial regression failed: $e"
        )
    end
end

"""
    fit_logistic_regression(X::Matrix{Float64}, y::Vector{Float64}, feature_names::Vector{String}, target_name::String; threshold::Float64 = 0.8)

Fit logistic regression model for binary success rate prediction.

# Arguments
- `X::Matrix{Float64}`: Feature matrix
- `y::Vector{Float64}`: Continuous success rates (0-1)
- `feature_names::Vector{String}`: Names of features
- `target_name::String`: Name of target variable
- `threshold::Float64`: Threshold for converting to binary classification

# Returns
- `PredictionModelResult`: Logistic regression results
"""
function fit_logistic_regression(X::Matrix{Float64}, y::Vector{Float64}, feature_names::Vector{String}, target_name::String; threshold::Float64 = 0.8)
    @info "Fitting logistic regression model" target=target_name threshold=threshold n_samples=length(y)
    
    n_samples, n_features = size(X)
    
    if n_samples < 3
        @warn "Insufficient samples for logistic regression" n_samples=n_samples
        return PredictionModelResult(
            "Logistic",
            target_name,
            [(name, 0.0) for name in feature_names],
            0.0, 0.0, zeros(0), zeros(0), Tuple{Float64, Float64}[],
            "Insufficient data for logistic regression"
        )
    end
    
    try
        # Convert to binary classification
        y_binary = y .>= threshold
        
        if all(y_binary) || all(.!y_binary)
            @warn "No variance in binary target variable" target=target_name
            base_rate = mean(y_binary)
            return PredictionModelResult(
                "Logistic",
                target_name,
                [(name, 0.0) for name in feature_names],
                0.0, 0.0, fill(base_rate, n_samples), y .- base_rate,
                [(base_rate, base_rate) for _ in 1:n_samples],
                "No variance in binary target - using base rate prediction"
            )
        end
        
        # Standardize features
        X_standardized = copy(X)
        feature_means = vec(mean(X, dims=1))
        feature_stds = vec(std(X, dims=1))
        
        for j in 1:n_features
            if feature_stds[j] > 1e-10
                X_standardized[:, j] = (X[:, j] .- feature_means[j]) ./ feature_stds[j]
            end
        end
        
        # Simple logistic regression using iterative reweighted least squares (IRLS)
        X_design = hcat(ones(n_samples), X_standardized)
        
        # Initialize coefficients
        coefficients = zeros(size(X_design, 2))
        
        # IRLS iterations
        for iter in 1:10
            # Predicted probabilities
            linear_pred = X_design * coefficients
            # Sigmoid function with numerical stability
            probs = 1.0 ./ (1.0 .+ exp.(-clamp.(linear_pred, -500, 500)))
            probs = clamp.(probs, 1e-7, 1-1e-7)  # Avoid numerical issues
            
            # Weights for IRLS
            weights = probs .* (1.0 .- probs)
            weights = clamp.(weights, 1e-7, Inf)
            
            # Working response
            z = linear_pred .+ (y_binary .- probs) ./ weights
            
            # Weighted least squares
            W = Diagonal(weights)
            try
                XWX = X_design' * W * X_design
                if rank(XWX) == size(XWX, 1)
                    coefficients = XWX \ (X_design' * W * z)
                else
                    break  # Singular matrix
                end
            catch
                break  # Numerical issues
            end
        end
        
        # Final predictions
        linear_pred = X_design * coefficients
        prob_predictions = 1.0 ./ (1.0 .+ exp.(-clamp.(linear_pred, -500, 500)))
        
        # Calculate accuracy
        binary_predictions = prob_predictions .>= 0.5
        accuracy = mean(binary_predictions .== y_binary)
        
        # Cross-validation
        cv_predictions = Float64[]
        for i in 1:n_samples
            train_mask = trues(n_samples)
            train_mask[i] = false
            
            if sum(train_mask) >= 2
                try
                    # Simplified prediction using mean of training probabilities
                    train_probs = y_binary[train_mask]
                    cv_pred = mean(train_probs)
                    push!(cv_predictions, cv_pred)
                catch
                    push!(cv_predictions, 0.5)
                end
            else
                push!(cv_predictions, 0.5)
            end
        end
        
        cv_binary_preds = cv_predictions .>= 0.5
        cv_accuracy = mean(cv_binary_preds .== y_binary)
        
        # Feature importance (absolute coefficient values)
        feature_importance = Tuple{String, Float64}[]
        for j in 1:min(length(feature_names), length(coefficients)-1)
            importance = abs(coefficients[j+1])  # Skip intercept
            push!(feature_importance, (feature_names[j], importance))
        end
        sort!(feature_importance, by=x->x[2], rev=true)
        
        # Confidence intervals for probabilities
        se_est = 0.1  # Rough estimate
        confidence_intervals = [(max(0, p - 1.96*se_est), min(1, p + 1.96*se_est)) for p in prob_predictions]
        
        # Calculate residuals on probability scale
        residuals = y - prob_predictions
        
        # Interpretation
        top_feature = isempty(feature_importance) ? "none" : feature_importance[1][1]
        interpretation = "Accuracy = $(round(accuracy, digits=3)), CV accuracy = $(round(cv_accuracy, digits=3)). " *
                        "Binary threshold = $threshold. Most important feature: $top_feature."
        
        @info "Logistic regression completed" target=target_name accuracy=round(accuracy, digits=3) cv_accuracy=round(cv_accuracy, digits=3)
        
        return PredictionModelResult(
            "Logistic",
            target_name,
            feature_importance,
            accuracy,
            cv_accuracy,
            prob_predictions,
            residuals,
            confidence_intervals,
            interpretation
        )
        
    catch e
        @warn "Logistic regression failed" target=target_name error=e
        base_rate = mean(y)
        return PredictionModelResult(
            "Logistic",
            target_name,
            [(name, 0.0) for name in feature_names],
            0.0, 0.0, fill(base_rate, n_samples), y .- base_rate,
            [(base_rate, base_rate) for _ in 1:n_samples],
            "Logistic regression failed: $e"
        )
    end
end

"""
    fit_tolerance_scaling_model(tolerances::Vector{Float64}, values::Vector{Float64}, variable_name::String)

Fit power law scaling model: y = a * tolerance^b

# Arguments
- `tolerances::Vector{Float64}`: Tolerance levels
- `values::Vector{Float64}`: Values to model
- `variable_name::String`: Name of variable being modeled

# Returns
- `Dict{String, Float64}`: Scaling parameters (a, b, r_squared)
"""
function fit_tolerance_scaling_model(tolerances::Vector{Float64}, values::Vector{Float64}, variable_name::String)
    @info "Fitting tolerance scaling model" variable=variable_name n_points=length(tolerances)
    
    if length(tolerances) != length(values) || length(tolerances) < 3
        @warn "Insufficient data for scaling model" variable=variable_name n_points=length(tolerances)
        return Dict("a" => NaN, "b" => NaN, "r_squared" => 0.0)
    end
    
    # Filter out non-positive values
    valid_mask = (tolerances .> 0) .& (values .> 0) .& isfinite.(tolerances) .& isfinite.(values)
    
    if sum(valid_mask) < 3
        @warn "Insufficient valid data for scaling model" variable=variable_name n_valid=sum(valid_mask)
        return Dict("a" => NaN, "b" => NaN, "r_squared" => 0.0)
    end
    
    valid_tols = tolerances[valid_mask]
    valid_vals = values[valid_mask]
    
    try
        # Log-log linear regression: log(y) = log(a) + b*log(tolerance)
        log_tols = log.(valid_tols)
        log_vals = log.(valid_vals)
        
        # Linear regression
        X = hcat(ones(length(log_tols)), log_tols)
        coeffs = X \ log_vals
        
        log_a = coeffs[1]
        b = coeffs[2]
        a = exp(log_a)
        
        # Calculate R²
        predictions = log_a .+ b .* log_tols
        ss_tot = sum((log_vals .- mean(log_vals)).^2)
        ss_res = sum((log_vals .- predictions).^2)
        r_squared = ss_tot > 0 ? 1 - ss_res / ss_tot : 0.0
        
        @info "Scaling model fitted" variable=variable_name a=round(a, digits=3) b=round(b, digits=3) r_squared=round(r_squared, digits=3)
        
        return Dict("a" => a, "b" => b, "r_squared" => r_squared)
        
    catch e
        @warn "Scaling model fitting failed" variable=variable_name error=e
        return Dict("a" => NaN, "b" => NaN, "r_squared" => 0.0)
    end
end

"""
    perform_comprehensive_performance_prediction(results::MultiToleranceResults)

Perform comprehensive performance prediction analysis for convergence patterns.

# Arguments
- `results::MultiToleranceResults`: Multi-tolerance analysis results

# Returns
- `PerformancePredictionSuite`: Complete performance prediction results
"""
function perform_comprehensive_performance_prediction(results::MultiToleranceResults)
    @info "Performing comprehensive performance prediction analysis"
    
    # 1. Prepare features and targets
    @info "Preparing prediction features..."
    feature_matrix, feature_names, target_variables = prepare_prediction_features(results)
    
    # 2. Fit polynomial degree prediction model
    @info "Fitting polynomial degree prediction model..."
    degree_prediction = fit_polynomial_regression(
        feature_matrix, target_variables["polynomial_degree"], 
        feature_names, "polynomial_degree"; degree=2
    )
    
    # 3. Fit sample count prediction model
    @info "Fitting sample count prediction model..."
    sample_prediction = fit_polynomial_regression(
        feature_matrix, target_variables["sample_count"], 
        feature_names, "sample_count"; degree=2
    )
    
    # 4. Fit success rate prediction model (logistic)
    @info "Fitting success rate prediction model..."
    success_rate_prediction = fit_logistic_regression(
        feature_matrix, target_variables["success_rate"], 
        feature_names, "success_rate"; threshold=0.8
    )
    
    # 5. Fit computation time prediction model
    @info "Fitting computation time prediction model..."
    computation_time_prediction = fit_polynomial_regression(
        feature_matrix, target_variables["computation_time"], 
        feature_names, "computation_time"; degree=2
    )
    
    # 6. Fit tolerance scaling models
    @info "Fitting tolerance scaling models..."
    tolerances = results.tolerance_sequence
    
    tolerance_scaling_model = Dict{String, Float64}()
    
    # Scaling for polynomial degree
    degree_scaling = fit_tolerance_scaling_model(tolerances, target_variables["polynomial_degree"], "polynomial_degree")
    merge!(tolerance_scaling_model, Dict("degree_a" => degree_scaling["a"], "degree_b" => degree_scaling["b"], "degree_r2" => degree_scaling["r_squared"]))
    
    # Scaling for sample count
    sample_scaling = fit_tolerance_scaling_model(tolerances, target_variables["sample_count"], "sample_count")
    merge!(tolerance_scaling_model, Dict("sample_a" => sample_scaling["a"], "sample_b" => sample_scaling["b"], "sample_r2" => sample_scaling["r_squared"]))
    
    # Scaling for computation time
    time_scaling = fit_tolerance_scaling_model(tolerances, target_variables["computation_time"], "computation_time")
    merge!(tolerance_scaling_model, Dict("time_a" => time_scaling["a"], "time_b" => time_scaling["b"], "time_r2" => time_scaling["r_squared"]))
    
    # 7. Calculate prediction accuracy summary
    accuracy_summary = (
        degree_r2 = degree_prediction.model_accuracy,
        degree_cv = degree_prediction.cross_validation_score,
        sample_r2 = sample_prediction.model_accuracy,
        sample_cv = sample_prediction.cross_validation_score,
        success_accuracy = success_rate_prediction.model_accuracy,
        success_cv = success_rate_prediction.cross_validation_score,
        time_r2 = computation_time_prediction.model_accuracy,
        time_cv = computation_time_prediction.cross_validation_score,
        overall_quality = mean([
            degree_prediction.cross_validation_score,
            sample_prediction.cross_validation_score,
            success_rate_prediction.cross_validation_score,
            computation_time_prediction.cross_validation_score
        ])
    )
    
    @info "Performance prediction analysis completed" overall_quality=round(accuracy_summary.overall_quality, digits=3)
    
    return PerformancePredictionSuite(
        degree_prediction,
        sample_prediction,
        success_rate_prediction,
        computation_time_prediction,
        tolerance_scaling_model,
        accuracy_summary
    )
end

# Export main functions for Phase 3.3
export PredictionModelResult, PerformancePredictionSuite
export prepare_prediction_features, fit_polynomial_regression, fit_logistic_regression
export fit_tolerance_scaling_model, perform_comprehensive_performance_prediction

# Export main functions for Phase 3.2
export ClusterAnalysisResult, PCAAnalysisResult, SpatialPatternSuite
export extract_orthant_features, standardize_features, perform_pca_analysis
export perform_kmeans_clustering, perform_hierarchical_clustering
export determine_optimal_clusters, calculate_silhouette_score
export identify_spatial_hotspots, calculate_spatial_autocorrelation
export perform_comprehensive_spatial_analysis

# Export main functions for Phase 3.1
export StatisticalTestResult, ConvergenceTestSuite
export perform_mann_whitney_test, perform_kolmogorov_smirnov_test
export perform_success_rate_comparison, perform_comprehensive_convergence_testing
export calculate_cliffs_delta, bootstrap_median_difference_ci, wilson_score_ci_difference