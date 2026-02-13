#!/usr/bin/env python3
"""
Evaluation and Benchmarking Script
Analyzes optimization results and generates comparison metrics
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from statistics import mean, stdev
from typing import Any, Dict, List


def load_json_file(file_path):
    """Load data from JSON file"""
    try:
        with open(file_path, "r") as f:
            data = json.load(f)
        return data
    except FileNotFoundError:
        print(f"ERROR: File not found: {file_path}")
        return None
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {file_path}: {e}")
        return None


def calculate_improvement(baseline, optimized):
    """Calculate improvement percentage"""
    if baseline == 0:
        return 0
    return ((baseline - optimized) / baseline) * 100


def calculate_workload_balance(routes, technicians):
    """Calculate workload balance metrics"""
    tech_hours = {}
    tech_stops = {}

    for tech in technicians:
        tech_id = tech["technician_id"]
        tech_hours[tech_id] = 0.0
        tech_stops[tech_id] = 0

    for tech_id, route in routes.items():
        if route:
            total_hours = (
                sum(wo.get("estimated_duration_minutes", 0) for wo in route) / 60.0
            )
            tech_hours[tech_id] = total_hours
            tech_stops[tech_id] = len(route)

    # Calculate standard deviation (lower is better - more balanced)
    hours_list = [h for h in tech_hours.values() if h > 0]
    stops_list = [s for s in tech_stops.values() if s > 0]

    hours_stdev = stdev(hours_list) if len(hours_list) > 1 else 0
    stops_stdev = stdev(stops_list) if len(stops_list) > 1 else 0
    hours_mean = mean(hours_list) if hours_list else 0
    stops_mean = mean(stops_list) if stops_list else 0

    return {
        "hours_mean": hours_mean,
        "hours_stdev": hours_stdev,
        "stops_mean": stops_mean,
        "stops_stdev": stops_stdev,
        "tech_hours": tech_hours,
        "tech_stops": tech_stops,
    }


def generate_per_technician_report(routes, technicians, algorithm_name):
    """Generate per-technician breakdown"""
    print(f"\n  Per-Technician Breakdown ({algorithm_name}):")
    print(f"  {'-' * 80}")
    print(
        f"  {'Technician ID':<15} {'Name':<20} {'Stops':<10} {'Hours':<10} {'Utilization %':<15}"
    )
    print(f"  {'-' * 80}")

    for tech in technicians:
        tech_id = tech["technician_id"]
        tech_name = tech.get("name", "Unknown")
        route = routes.get(tech_id, [])

        if route:
            stops = len(route)
            hours = sum(wo.get("estimated_duration_minutes", 0) for wo in route) / 60.0
            max_hours = tech.get("max_daily_hours", 8)
            utilization = min((hours / max_hours) * 100, 100) if max_hours > 0 else 0

            print(
                f"  {tech_id:<15} {tech_name:<20} {stops:<10} {hours:<10.2f} {utilization:<15.1f}"
            )
        else:
            print(f"  {tech_id:<15} {tech_name:<20} {0:<10} {0:<10.2f} {0:<15.1f}")

    print(f"  {'-' * 80}")


def generate_comparison_report(results, technicians):
    """Generate detailed comparison report"""
    print("\n" + "=" * 100)
    print("OPTIMIZATION EVALUATION REPORT")
    print("=" * 100)
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Algorithms Compared: {len(results)}")

    # Find baseline (Greedy)
    baseline = None
    for result in results:
        if result["algorithm"] == "Greedy":
            baseline = result
            break

    if not baseline:
        print("\nWARNING: No Greedy baseline found. Using first result as baseline.")
        baseline = results[0]

    print(f"\nBaseline Algorithm: {baseline['algorithm']}")

    # Overall metrics comparison
    print("\n" + "=" * 100)
    print("OVERALL METRICS COMPARISON")
    print("=" * 100)

    for result in results:
        algorithm = result["algorithm"]
        is_baseline = algorithm == baseline["algorithm"]

        print(f"\n{algorithm} Algorithm:")
        print(f"  Total Distance: {result['total_distance']} miles", end="")
        if not is_baseline:
            improvement = calculate_improvement(
                baseline["total_distance"], result["total_distance"]
            )
            print(f" ({improvement:+.2f}% vs baseline)")
        else:
            print(" (baseline)")

        print(f"  Total Time: {result['total_time']} hours", end="")
        if not is_baseline:
            improvement = calculate_improvement(
                baseline["total_time"], result["total_time"]
            )
            print(f" ({improvement:+.2f}% vs baseline)")
        else:
            print(" (baseline)")

        print(f"  Number of Routes: {result['num_routes']}")

        print(f"  Average Utilization: {result['avg_utilization']}%", end="")
        if not is_baseline:
            diff = result["avg_utilization"] - baseline["avg_utilization"]
            print(f" ({diff:+.2f}% vs baseline)")
        else:
            print(" (baseline)")

        print(f"  Unassigned Orders: {result['unassigned_orders']}", end="")
        if not is_baseline:
            diff = baseline["unassigned_orders"] - result["unassigned_orders"]
            print(f" ({diff:+d} vs baseline)")
        else:
            print(" (baseline)")

        print(f"  Solve Time: {result['solve_time']} seconds")

    # Workload balance analysis
    print("\n" + "=" * 100)
    print("WORKLOAD BALANCE ANALYSIS")
    print("=" * 100)

    for result in results:
        algorithm = result["algorithm"]
        routes = result.get("routes", {})

        balance = calculate_workload_balance(routes, technicians)

        print(f"\n{algorithm} Algorithm:")
        print(f"  Average Hours per Technician: {balance['hours_mean']:.2f}")
        print(f"  Std Dev of Hours: {balance['hours_stdev']:.2f} (lower is better)")
        print(f"  Average Stops per Technician: {balance['stops_mean']:.2f}")
        print(f"  Std Dev of Stops: {balance['stops_stdev']:.2f} (lower is better)")

    # Per-technician breakdown
    print("\n" + "=" * 100)
    print("PER-TECHNICIAN BREAKDOWN")
    print("=" * 100)

    for result in results:
        algorithm = result["algorithm"]
        routes = result.get("routes", {})
        generate_per_technician_report(routes, technicians, algorithm)

    # Summary and recommendations
    print("\n" + "=" * 100)
    print("SUMMARY AND RECOMMENDATIONS")
    print("=" * 100)

    # Find best algorithm by different criteria
    best_distance = min(results, key=lambda x: x["total_distance"])
    best_time = min(results, key=lambda x: x["total_time"])
    best_utilization = max(results, key=lambda x: x["avg_utilization"])
    best_coverage = min(results, key=lambda x: x["unassigned_orders"])

    print(
        f"\nBest by Total Distance: {best_distance['algorithm']} ({best_distance['total_distance']} miles)"
    )
    print(
        f"Best by Total Time: {best_time['algorithm']} ({best_time['total_time']} hours)"
    )
    print(
        f"Best by Utilization: {best_utilization['algorithm']} ({best_utilization['avg_utilization']}%)"
    )
    print(
        f"Best by Coverage: {best_coverage['algorithm']} ({best_coverage['unassigned_orders']} unassigned)"
    )

    # Overall recommendation
    print("\nOverall Recommendation:")

    # Score each algorithm (simple scoring system)
    scores = {}
    for result in results:
        score = 0

        # Distance (25% weight)
        if result == best_distance:
            score += 25
        else:
            dist_improvement = calculate_improvement(
                baseline["total_distance"], result["total_distance"]
            )
            score += max(0, min(25, dist_improvement * 5))

        # Time (25% weight)
        if result == best_time:
            score += 25
        else:
            time_improvement = calculate_improvement(
                baseline["total_time"], result["total_time"]
            )
            score += max(0, min(25, time_improvement * 5))

        # Utilization (25% weight)
        if result == best_utilization:
            score += 25
        else:
            util_diff = result["avg_utilization"] - baseline["avg_utilization"]
            score += max(0, min(25, util_diff * 2.5))

        # Coverage (25% weight)
        if result == best_coverage:
            score += 25
        else:
            coverage_improvement = (
                baseline["unassigned_orders"] - result["unassigned_orders"]
            )
            score += max(0, min(25, coverage_improvement * 5))

        scores[result["algorithm"]] = round(score, 2)

    best_overall = max(scores.items(), key=lambda x: x[1])

    print(f"\n  Algorithm Scores (out of 100):")
    for algo, score in sorted(scores.items(), key=lambda x: x[1], reverse=True):
        print(f"    - {algo}: {score}")

    print(f"\n  Recommended Algorithm: {best_overall[0]} (Score: {best_overall[1]})")

    print("\n" + "=" * 100)


def save_evaluation_report(report_text, output_file):
    """Save evaluation report to text file"""
    with open(output_file, "w") as f:
        f.write(report_text)


def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(
        description="Evaluate and compare optimization results"
    )
    parser.add_argument(
        "--results",
        help="Path to optimization results JSON file (default: ../data/sample/optimization_results.json)",
        default=None,
    )
    parser.add_argument(
        "--technicians",
        help="Path to technicians JSON file (default: ../data/sample/technicians.json)",
        default=None,
    )
    parser.add_argument(
        "--output", help="Path to save evaluation report text file", default=None
    )

    args = parser.parse_args()

    # Determine file paths
    if args.results:
        results_file = Path(args.results)
    else:
        results_file = (
            Path(__file__).parent.parent
            / "data"
            / "sample"
            / "optimization_results.json"
        )

    if args.technicians:
        technicians_file = Path(args.technicians)
    else:
        technicians_file = (
            Path(__file__).parent.parent / "data" / "sample" / "technicians.json"
        )

    # Load data
    print("Loading optimization results...")
    results = load_json_file(results_file)
    if not results:
        print(f"ERROR: Could not load results from {results_file}")
        sys.exit(1)

    print("Loading technicians data...")
    technicians = load_json_file(technicians_file)
    if not technicians:
        print(f"ERROR: Could not load technicians from {technicians_file}")
        sys.exit(1)

    # Generate comparison report
    generate_comparison_report(results, technicians)

    # Save report if output specified
    if args.output:
        output_file = Path(args.output)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        print(f"\nSaving report to: {output_file}")
        # Note: In production, you would capture the print output and save it
        print("(Report saved to file - not implemented in this demo)")

    print("\nEvaluation complete!")


if __name__ == "__main__":
    main()
