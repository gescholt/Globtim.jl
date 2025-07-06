# Draft: Tracking All Critical Points

## Key Changes to Incorporate 25 Critical Points

### 1. Data Structure for Critical Points with Types

```julia
# Store critical points with their classification
struct CriticalPointInfo
    point::Vector{Float64}
    type::String           # "min", "saddle", etc.
    is_minimizer::Bool     # Quick check for min+min
end
```

### 2. Generate All 25 Points

```julia
function generate_all_theoretical_points()
    # All 5 critical points in 2D (+,-) orthant
    critical_2d = [
        ([0.126217280731679, -0.126217280731682], "saddle"),
        ([0.507030772828217, -0.917350578608486], "min"),
        ([0.74115190368376, -0.741151903683748], "min"),
        ([0.917350578608475, -0.50703077282823], "min"),
        ([0.459896075906281, -0.459896075906281], "saddle")
    ]
    
    # Generate 5×5 = 25 tensor products
    theoretical_points = []
    for (pt1, type1) in critical_2d
        for (pt2, type2) in critical_2d
            point_4d = [pt1[1], pt1[2], pt2[1], pt2[2]]
            combined_type = "$(type1)+$(type2)"
            is_minimizer = (type1 == "min" && type2 == "min")
            
            push!(theoretical_points, 
                  CriticalPointInfo(point_4d, combined_type, is_minimizer))
        end
    end
    
    return theoretical_points
end
```

### 3. Enhanced Recovery Metrics

```julia
function compute_recovery_metrics(theoretical_points, computed_points; threshold=1e-3)
    # Track recovery for all points and minimizers separately
    all_distances = []
    minimizer_distances = []
    recovery_by_type = Dict()
    
    for theo_info in theoretical_points
        min_dist = minimum(norm(cp - theo_info.point) for cp in computed_points)
        push!(all_distances, min_dist)
        
        if theo_info.is_minimizer
            push!(minimizer_distances, min_dist)
        end
        
        # Track recovery by type
        if min_dist < threshold
            recovery_by_type[theo_info.type] = get(recovery_by_type, theo_info.type, 0) + 1
        end
    end
    
    return all_distances, minimizer_distances, recovery_by_type
end
```

### 4. Enhanced Output

The analysis would now report:
- Recovery of all 25 critical points
- Special tracking of the 9 minimizers (min+min)
- Breakdown by type:
  - min+min: 9 points (the actual minimizers)
  - min+saddle: 6 points
  - saddle+min: 6 points  
  - saddle+saddle: 4 points

### 5. Visualization Enhancement

Add plots showing:
- Overall recovery rate (0-25)
- Minimizer recovery rate (0-9) 
- Recovery by type (stacked bar or separate lines)

### 6. Domain Distribution Analysis

```julia
function analyze_domain_distribution(theoretical_points, subdomains)
    # Count points per subdomain
    points_per_subdomain = Dict{String, Int}()
    type_per_subdomain = Dict{String, Dict{String, Int}}()
    
    for subdomain in subdomains
        subdomain_points = []
        type_counts = Dict{String, Int}()
        
        for pt_info in theoretical_points
            if is_point_in_subdomain(pt_info.point, subdomain)
                push!(subdomain_points, pt_info)
                type_counts[pt_info.type] = get(type_counts, pt_info.type, 0) + 1
            end
        end
        
        points_per_subdomain[subdomain.label] = length(subdomain_points)
        type_per_subdomain[subdomain.label] = type_counts
    end
    
    return points_per_subdomain, type_per_subdomain
end

# Usage in analysis:
pts_per_sub, types_per_sub = analyze_domain_distribution(all_theoretical, subdomains)

# Print distribution summary
println("\nTheoretical points distribution across subdomains:")
for (label, count) in sort(collect(pts_per_sub))
    println("  Subdomain $label: $count points")
    if count > 0
        types = types_per_sub[label]
        for (type, n) in sort(collect(types))
            println("    - $type: $n")
        end
    end
end

# Find which subdomains have minimizers
minimizer_subdomains = [label for (label, types) in types_per_sub 
                       if get(types, "min+min", 0) > 0]
println("\nSubdomains containing minimizers: ", minimizer_subdomains)
```

### 7. Enhanced Recovery Tracking by Subdomain

```julia
function compute_recovery_by_subdomain(theoretical_points, computed_points_by_subdomain, subdomains)
    recovery_stats = Dict{String, Dict}()
    
    for subdomain in subdomains
        # Get theoretical points in this subdomain
        theo_in_sub = filter(pt -> is_point_in_subdomain(pt.point, subdomain), 
                           theoretical_points)
        
        # Get computed points for this subdomain
        computed_in_sub = get(computed_points_by_subdomain, subdomain.label, [])
        
        # Compute recovery metrics
        recovered = 0
        recovered_by_type = Dict{String, Int}()
        
        for pt_info in theo_in_sub
            if !isempty(computed_in_sub)
                min_dist = minimum(norm(cp - pt_info.point) for cp in computed_in_sub)
                if min_dist < 1e-3
                    recovered += 1
                    recovered_by_type[pt_info.type] = get(recovered_by_type, pt_info.type, 0) + 1
                end
            end
        end
        
        recovery_stats[subdomain.label] = Dict(
            "total_theoretical" => length(theo_in_sub),
            "total_recovered" => recovered,
            "recovered_by_type" => recovered_by_type,
            "has_minimizers" => any(pt.is_minimizer for pt in theo_in_sub)
        )
    end
    
    return recovery_stats
end
```

### 8. Summary Statistics

The enhanced analysis would provide:

1. **Global distribution**:
   - Which of the 16 subdomains contain theoretical critical points
   - How many points per subdomain (some may have 0, some may have multiple)
   - Type breakdown per subdomain

2. **Recovery by subdomain**:
   - Recovery rate per subdomain
   - Which subdomains successfully recover their minimizers
   - Identify problematic subdomains

3. **Example output**:
   ```
   Subdomain 0101: 2 points (1 min+min, 1 saddle+saddle)
   Subdomain 1010: 1 point (1 min+saddle)
   Subdomain 1111: 0 points
   ...
   
   Recovery summary by subdomain:
   Subdomain 0101: 2/2 recovered (100%)
   Subdomain 1010: 0/1 recovered (0%) ⚠️
   ```

## Benefits

1. **Complete picture**: See if the polynomial approximation captures all critical point structure, not just minimizers
2. **Type-specific analysis**: Understand which types of critical points are harder to recover
3. **Better debugging**: If minimizers aren't found, check if saddle points near them are found
4. **Research insight**: Understand how polynomial degree affects recovery of different critical point types
5. **Spatial understanding**: Know which subdomains are challenging and why
6. **Targeted improvement**: Focus on subdomains with poor recovery rates

## Minimal Integration

To add this to existing code with minimal changes:

```julia
# Replace:
theoretical_minimizers = generate_theoretical_minimizers()  # 9 points

# With:
all_theoretical = generate_all_theoretical_points()  # 25 points
theoretical_minimizers = [pt.point for pt in all_theoretical if pt.is_minimizer]  # 9 points

# Then optionally add:
println("Tracking $(length(all_theoretical)) critical points, including $(length(theoretical_minimizers)) minimizers")
```

This way existing code continues to work while having access to the full critical point information.