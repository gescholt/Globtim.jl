#!/usr/bin/env python3
"""
Organize experiments from flat hpc_results/ into hierarchical structure by objective function.

This script moves experiments from:
  hpc_results/exp_name_timestamp/
to:
  hpc_results_organized/objective_name/exp_name_timestamp/

Categorization is based on directory name patterns.
"""

import os
import shutil
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

    # Create target base directory
    os.makedirs(target_base, exist_ok=True)

    # Track categories
    categories = defaultdict(list)

    # Scan source directory
    for entry in sorted(os.listdir(source_dir)):
        source_path = os.path.join(source_dir, entry)

        # Skip if not a directory
        if not os.path.isdir(source_path):
            continue

        # Categorize experiment
        category = categorize_experiment(entry)
        categories[category].append(entry)

        # Create category directory
        category_dir = os.path.join(target_base, category)
        os.makedirs(category_dir, exist_ok=True)

        # Target path
        target_path = os.path.join(category_dir, entry)

        # Check if target already exists
        if os.path.exists(target_path):
            print(f"⚠️  Skipping {entry} - already exists in {category}")
            continue

        # Move experiment
        print(f"Moving {entry} -> {category}/")
        shutil.move(source_path, target_path)

    # Print summary
    print("\n" + "="*80)
    print("ORGANIZATION SUMMARY")
    print("="*80)
    for category, exps in sorted(categories.items()):
        print(f"\n{category}: {len(exps)} experiments")
        if len(exps) <= 5:
            for exp in exps:
                print(f"  - {exp}")
        else:
            for exp in exps[:3]:
                print(f"  - {exp}")
            print(f"  ... and {len(exps) - 3} more")

    print(f"\n✓ Organized {sum(len(v) for v in categories.values())} experiments into {len(categories)} categories")
    print(f"✓ Output directory: {target_base}/")

if __name__ == "__main__":
    main()
