#!/usr/bin/env python3
"""
Extract metrics from Vivado reports and simulation logs.
Generates a consolidated CSV for analysis.

Usage: python scripts/extract_metrics.py [accelerator_name]
"""

import re
import sys
import os
from pathlib import Path

def parse_utilization_report(filepath):
    """Parse Vivado utilization report."""
    metrics = {}
    if not os.path.exists(filepath):
        print(f"Warning: {filepath} not found")
        return metrics

    with open(filepath, 'r') as f:
        content = f.read()

    # Extract LUT usage
    match = re.search(r'Slice LUTs\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)', content)
    if match:
        metrics['luts_used'] = int(match.group(1))
        metrics['luts_available'] = int(match.group(2))
        metrics['luts_percent'] = 100.0 * metrics['luts_used'] / metrics['luts_available']

    # Extract FF usage
    match = re.search(r'Slice Registers\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)', content)
    if match:
        metrics['ffs_used'] = int(match.group(1))
        metrics['ffs_available'] = int(match.group(2))
        metrics['ffs_percent'] = 100.0 * metrics['ffs_used'] / metrics['ffs_available']

    # Extract BRAM usage
    match = re.search(r'Block RAM Tile\s*\|\s*([\d.]+)\s*\|\s*\d+\s*\|\s*(\d+)', content)
    if match:
        metrics['bram_used'] = float(match.group(1))
        metrics['bram_available'] = int(match.group(2))
        metrics['bram_percent'] = 100.0 * metrics['bram_used'] / metrics['bram_available']

    # Extract DSP usage
    match = re.search(r'DSPs\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)', content)
    if match:
        metrics['dsps_used'] = int(match.group(1))
        metrics['dsps_available'] = int(match.group(2))
        metrics['dsps_percent'] = 100.0 * metrics['dsps_used'] / metrics['dsps_available']

    return metrics


def parse_timing_report(filepath):
    """Parse Vivado timing summary report."""
    metrics = {}
    if not os.path.exists(filepath):
        print(f"Warning: {filepath} not found")
        return metrics

    with open(filepath, 'r') as f:
        content = f.read()

    # Extract WNS (Worst Negative Slack)
    match = re.search(r'WNS\(ns\)\s*:\s*([-\d.]+)', content)
    if match:
        metrics['wns_ns'] = float(match.group(1))

    # Extract target clock period
    match = re.search(r'Requirement\s*:\s*([\d.]+)ns', content)
    if match:
        metrics['target_period_ns'] = float(match.group(1))
        # Calculate max frequency
        if 'wns_ns' in metrics:
            actual_period = metrics['target_period_ns'] - metrics['wns_ns']
            metrics['fmax_mhz'] = 1000.0 / actual_period if actual_period > 0 else 0

    return metrics


def parse_power_report(filepath):
    """Parse Vivado power report."""
    metrics = {}
    if not os.path.exists(filepath):
        print(f"Warning: {filepath} not found")
        return metrics

    with open(filepath, 'r') as f:
        content = f.read()

    # Extract total on-chip power
    match = re.search(r'Total On-Chip Power \(W\)\s*\|\s*([\d.]+)', content)
    if match:
        metrics['total_power_w'] = float(match.group(1))
        metrics['total_power_mw'] = metrics['total_power_w'] * 1000

    # Extract dynamic power
    match = re.search(r'Dynamic \(W\)\s*\|\s*([\d.]+)', content)
    if match:
        metrics['dynamic_power_w'] = float(match.group(1))
        metrics['dynamic_power_mw'] = metrics['dynamic_power_w'] * 1000

    # Extract static power
    match = re.search(r'Device Static \(W\)\s*\|\s*([\d.]+)', content)
    if match:
        metrics['static_power_w'] = float(match.group(1))
        metrics['static_power_mw'] = metrics['static_power_w'] * 1000

    # Extract clocks power
    match = re.search(r'Clocks\s*\|\s*([\d.]+)', content)
    if match:
        metrics['clock_power_w'] = float(match.group(1))

    # Extract signals power
    match = re.search(r'Signals\s*\|\s*([\d.]+)', content)
    if match:
        metrics['signals_power_w'] = float(match.group(1))

    # Extract logic power
    match = re.search(r'Logic\s*\|\s*([\d.]+)', content)
    if match:
        metrics['logic_power_w'] = float(match.group(1))

    # Extract BRAM power
    match = re.search(r'BRAM\s*\|\s*([\d.]+)', content)
    if match:
        metrics['bram_power_w'] = float(match.group(1))

    # Extract DSP power
    match = re.search(r'DSP\s*\|\s*([\d.]+)', content)
    if match:
        metrics['dsp_power_w'] = float(match.group(1))

    return metrics


def parse_simulation_log(filepath):
    """Parse simulation log for performance metrics."""
    metrics = {}
    if not os.path.exists(filepath):
        print(f"Warning: {filepath} not found")
        return metrics

    with open(filepath, 'r') as f:
        content = f.read()

    # Look for CSV output section
    csv_match = re.search(r'CSV OUTPUT.*?\n(.*?)={5,}', content, re.DOTALL)
    if csv_match:
        csv_section = csv_match.group(1)
        for line in csv_section.strip().split('\n'):
            if ',' in line and line != 'metric,value':
                parts = line.split(',')
                if len(parts) == 2:
                    key, value = parts
                    try:
                        metrics[f'sim_{key}'] = float(value)
                    except ValueError:
                        metrics[f'sim_{key}'] = value

    return metrics


def calculate_derived_metrics(metrics):
    """Calculate derived metrics like GOPS/W, energy per inference."""
    derived = {}

    # Energy per inference (µJ)
    if 'total_power_mw' in metrics and 'sim_avg_latency_cycles' in metrics:
        latency_us = metrics['sim_avg_latency_cycles'] * 0.01  # at 100 MHz
        derived['energy_per_inference_uj'] = metrics['total_power_mw'] * latency_us / 1000

    # GOPS/W
    if 'sim_gops' in metrics and 'total_power_w' in metrics and metrics['total_power_w'] > 0:
        derived['gops_per_watt'] = metrics['sim_gops'] / metrics['total_power_w']

    # Energy per MAC (pJ)
    if 'energy_per_inference_uj' in metrics and 'sim_macs_per_inference' in metrics:
        derived['energy_per_mac_pj'] = (derived['energy_per_inference_uj'] * 1e6) / metrics['sim_macs_per_inference']

    return derived


def generate_report(name, metrics):
    """Generate summary report and CSV."""
    print("\n" + "=" * 60)
    print(f"METRICS SUMMARY: {name}")
    print("=" * 60)

    categories = [
        ("Resource Utilization", ['luts_used', 'luts_percent', 'ffs_used', 'ffs_percent',
                                   'bram_used', 'bram_percent', 'dsps_used', 'dsps_percent']),
        ("Timing", ['wns_ns', 'target_period_ns', 'fmax_mhz']),
        ("Power (Active)", ['total_power_mw', 'dynamic_power_mw', 'static_power_mw']),
        ("Performance", ['sim_avg_latency_cycles', 'sim_inferences_per_sec', 'sim_gops']),
        ("Efficiency", ['energy_per_inference_uj', 'gops_per_watt', 'energy_per_mac_pj']),
    ]

    for cat_name, keys in categories:
        print(f"\n{cat_name}:")
        for key in keys:
            if key in metrics:
                value = metrics[key]
                if isinstance(value, float):
                    print(f"  {key}: {value:.4f}")
                else:
                    print(f"  {key}: {value}")

    # Write CSV
    csv_path = f"reports/benchmark/{name}_metrics.csv"
    os.makedirs(os.path.dirname(csv_path), exist_ok=True)
    with open(csv_path, 'w') as f:
        f.write("metric,value\n")
        for key, value in sorted(metrics.items()):
            f.write(f"{key},{value}\n")

    print(f"\nCSV written to: {csv_path}")


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "mlp"
    report_dir = "reports/benchmark"

    # Collect all metrics
    metrics = {}

    # Parse utilization
    metrics.update(parse_utilization_report(f"{report_dir}/utilization_impl.txt"))

    # Parse timing
    metrics.update(parse_timing_report(f"{report_dir}/timing_impl.txt"))

    # Parse power (active)
    metrics.update(parse_power_report(f"{report_dir}/power_active.txt"))

    # Parse simulation log
    sim_log = f"{report_dir}/../{name}/results/{name}_top.log"
    if os.path.exists(sim_log):
        metrics.update(parse_simulation_log(sim_log))

    # Also try benchmark log location
    benchmark_log = f"build/mlp_benchmark/mlp_benchmark.sim/sim_1/behav/xsim/simulate.log"
    if os.path.exists(benchmark_log):
        metrics.update(parse_simulation_log(benchmark_log))

    # Calculate derived metrics
    metrics.update(calculate_derived_metrics(metrics))

    # Generate report
    generate_report(name, metrics)


if __name__ == "__main__":
    main()
