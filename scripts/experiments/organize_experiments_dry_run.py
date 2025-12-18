#!/usr/bin/env python3
"""
DRY RUN: Preview how experiments will be organized.

This script shows what the organization would look like without actually moving files.
"""

import os
from collections import defaultdict

def categorize_experiment(exp_name):
    """Categorize an experiment based on its directory name."""
    # Lotka-Volterra 4D patterns
    if any(pattern in exp_name.lower() for pattern in ["4dlv", "lotka_volterra", "_lv_", "lv4d"]):
        return "lotka_volterra_4d"

    # Daisy Ex3 4D patterns
    elif "daisy" in exp_name.lower():
        return "daisy_ex3_4d"

    # Extended Brusselator patterns
    elif "extended" in exp_name.lower() and "brussels" in exp_name.lower():
        return "extended_brusselator"

    # Extended challenging patterns
    elif "challenging" in exp_name.lower() or ("extended" in exp_name.lower() and "_lv" not in exp_name.lower()):
        return "extended_challenging"

    # Minimal test patterns
    elif "minimal" in exp_name.lower():
        return "minimal_test"

    # Default category
    else:
        return "other"

def main():
    source_dir = "hpc_results"
    target_base = "hpc_results_organized"

    # Track categories
    categories = defaultdict(list)
    with_results = defaultdict(int)
    with_config = defaultdict(int)

    # Scan source directory
    for entry in sorted(os.listdir(source_dir)):
        source_path = os.path.join(source_dir, entry)

        # Skip if not a directory
        if not os.path.isdir(source_path):
            continue

        # Categorize experiment
        category = categorize_experiment(entry)
        categories[category].append(entry)

        # Check for data
        files = os.listdir(source_path) if os.path.isdir(source_path) else []
        if "results_summary.json" in files or "results_summary.jld2" in files:
            with_results[category] += 1
        if "experiment_config.json" in files:
            with_config[category] += 1

    # Print organization plan
    print("="*80)
    print("DRY RUN: Experiment Organization Plan")
    print("="*80)
    print(f"\nSource: {source_dir}/")
    print(f"Target: {target_base}/")
    print("\n" + "-"*80)

    for category in sorted(categories.keys()):
        exps = categories[category]
        print(f"\n📁 {category}/")
        print(f"   Experiments: {len(exps)}")
        print(f"   With results: {with_results[category]}")
        print(f"   With config: {with_config[category]}")

        # Show samples
        if len(exps) <= 5:
            for exp in exps:
                print(f"   - {exp}")
        else:
            for exp in exps[:3]:
                print(f"   - {exp}")
            print(f"   ... and {len(exps) - 3} more")

    print("\n" + "="*80)
    print(f"Total: {sum(len(v) for v in categories.values())} experiments → {len(categories)} categories")
    print("="*80)
    print("\n✓ This was a DRY RUN - no files were moved")
    print("✓ To actually organize, run: python3 organize_experiments.py")

if __name__ == "__main__":
    main()
