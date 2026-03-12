#!/usr/bin/env python3
"""
Generate publication-quality figures from Timeloop DSE sweep results.

Reads the full sweep CSV (timeloop_dse_full_sweep.csv) and produces:
  1. Energy vs. Latency Pareto front (by bitwidth, colored by MAC count)
  2. Energy breakdown stacked bar (per-component fJ/compute)
  3. Problem size scaling (energy vs. compute count)
  4. Annotated Pareto front highlighting configs selected for FPGA validation

Usage:
  python scripts/timeloop/plot_timeloop_dse.py [--csv PATH] [--outdir PATH]
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Dict, List

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

# ---------------------------------------------------------------------------
# Styling
# ---------------------------------------------------------------------------
plt.rcParams.update({
    "font.family": "serif",
    "font.size": 10,
    "axes.labelsize": 11,
    "axes.titlesize": 12,
    "legend.fontsize": 9,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "figure.dpi": 150,
    "savefig.dpi": 300,
    "axes.grid": True,
    "grid.alpha": 0.3,
})

MAC_COLORS = {1: "#1f77b4", 3: "#ff7f0e", 9: "#2ca02c"}
MAC_MARKERS = {1: "o", 3: "s", 9: "D"}
BW_COLORS = {4: "#9467bd", 8: "#1f77b4", 16: "#d62728"}
BW_MARKERS = {4: "^", 8: "o", 16: "v"}

PROBLEM_LABELS = {
    "conv2d_8x8": "8x8",
    "conv2d_16x16": "16x16",
    "conv2d_32x32": "32x32",
    "conv2d_16x16_c3": "16x16 C=3",
    "conv2d_16x16_k4": "16x16 K=4",
    "conv2d_16x16_c3k8": "16x16 C=3,K=8",
}

# Configs selected for FPGA validation (1/3/9 MAC x INT4/8/16, conv2d_16x16 baseline)
FPGA_SELECTED = [
    {"mac_count": mac, "bitwidth": bw, "problem": "conv2d_16x16"}
    for mac in [1, 3, 9]
    for bw in [4, 8, 16]
]


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------
def load_csv(csv_path: Path) -> List[Dict]:
    """Load CSV and filter to new-format results only (with __ separator)."""
    rows = list(csv.DictReader(csv_path.open(encoding="utf-8")))
    # Filter to new-format only (exclude legacy splitbuf variants)
    # Also skip rows with missing critical fields
    new_rows = [
        r for r in rows
        if "__" in r["config"] and r.get("cycles") and r.get("energy_uj")
    ]
    # Convert numeric fields
    for r in new_rows:
        r["mac_count"] = int(r["mac_count"])
        r["bitwidth"] = int(r["bitwidth"])
        r["cycles"] = int(r["cycles"])
        r["energy_uj"] = float(r["energy_uj"])
        r["computes_total"] = int(r["computes_total"])
        r["fj_per_compute_total"] = float(r["fj_per_compute_total"])
        r["fj_per_compute_mac"] = float(r.get("fj_per_compute_mac", 0))
        r["fj_per_compute_dram"] = float(r.get("fj_per_compute_dram", 0))
        r["utilization_pct"] = float(r.get("utilization_pct", 0))
        r["area_mm2_summary"] = float(r.get("area_mm2_summary", 0))
        # On-chip buffer energy
        for buf in ("ifmap_buffer", "weight_buffer", "ofmap_buffer"):
            key = f"fj_per_compute_{buf}"
            r[key] = float(r.get(key, 0) or 0)
        r["fj_per_compute_onchip"] = (
            r["fj_per_compute_ifmap_buffer"]
            + r["fj_per_compute_weight_buffer"]
            + r["fj_per_compute_ofmap_buffer"]
        )
    return new_rows


# ---------------------------------------------------------------------------
# Helper: save figure as PNG + PDF
# ---------------------------------------------------------------------------
def _save(fig, outdir: Path, name: str) -> None:
    for ext in ("png", "pdf"):
        path = outdir / f"{name}.{ext}"
        fig.savefig(path)
        print(f"  Saved {path}")
    plt.close(fig)


# ---------------------------------------------------------------------------
# Figure 1: Energy vs. Latency Pareto Front
# ---------------------------------------------------------------------------
def plot_energy_vs_latency(rows: List[Dict], outdir: Path) -> None:
    """Scatter: cycles (x) vs energy_uj (y), colored by MAC, shaped by bitwidth."""
    fig, ax = plt.subplots(figsize=(8, 5.5))

    for bw in sorted(set(r["bitwidth"] for r in rows)):
        for mac in sorted(set(r["mac_count"] for r in rows)):
            subset = [r for r in rows if r["mac_count"] == mac and r["bitwidth"] == bw]
            if not subset:
                continue
            x = [r["cycles"] for r in subset]
            y = [r["energy_uj"] for r in subset]
            ax.scatter(
                x, y,
                c=MAC_COLORS[mac],
                marker=BW_MARKERS[bw],
                s=60,
                alpha=0.8,
                edgecolors="k",
                linewidths=0.5,
                label=f"{mac}-MAC INT{bw}",
            )

    ax.set_xlabel("Latency (cycles)")
    ax.set_ylabel("Energy per Inference (\u00b5J)")
    ax.set_title("Energy vs. Latency \u2014 Timeloop DSE (All Configurations)")
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.legend(
        bbox_to_anchor=(1.02, 1), loc="upper left", borderaxespad=0,
        ncol=1, framealpha=0.9,
    )

    fig.tight_layout()
    _save(fig, outdir, "fig1_energy_vs_latency")


# ---------------------------------------------------------------------------
# Figure 2: Energy Breakdown (Stacked Bar)
# ---------------------------------------------------------------------------
def plot_energy_breakdown(rows: List[Dict], outdir: Path) -> None:
    """Stacked bar chart of fJ/compute breakdown for 16x16 baseline across all configs."""
    subset = sorted(
        [r for r in rows if r["problem"] == "conv2d_16x16"],
        key=lambda r: (r["bitwidth"], r["mac_count"]),
    )
    if not subset:
        return

    labels = [f"INT{r['bitwidth']}\n{r['mac_count']}-MAC" for r in subset]
    mac_e = [r["fj_per_compute_mac"] for r in subset]
    ifmap_e = [r["fj_per_compute_ifmap_buffer"] for r in subset]
    weight_e = [r["fj_per_compute_weight_buffer"] for r in subset]
    ofmap_e = [r["fj_per_compute_ofmap_buffer"] for r in subset]
    dram_e = [r["fj_per_compute_dram"] for r in subset]

    x = np.arange(len(labels))
    width = 0.6

    fig, ax = plt.subplots(figsize=(10, 5))
    bottom = np.zeros(len(labels))

    components = [
        ("MAC", mac_e, "#2ca02c"),
        ("ifmap SRAM", ifmap_e, "#1f77b4"),
        ("weight SRAM", weight_e, "#ff7f0e"),
        ("ofmap SRAM", ofmap_e, "#9467bd"),
        ("DRAM", dram_e, "#d62728"),
    ]
    for name, values, color in components:
        vals = np.array(values, dtype=float)
        ax.bar(x, vals, width, bottom=bottom, label=name, color=color, edgecolor="white", linewidth=0.5)
        bottom += vals

    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_ylabel("Energy (fJ / compute)")
    ax.set_title("Energy Breakdown by Component \u2014 Conv2D 16\u00d716 Baseline")
    ax.legend(loc="upper right")

    # Add total energy labels on top
    for i, r in enumerate(subset):
        total = r["fj_per_compute_total"]
        ax.text(i, total + 500, f"{total:.0f}", ha="center", va="bottom", fontsize=8)

    fig.tight_layout()
    _save(fig, outdir, "fig2_energy_breakdown")


# ---------------------------------------------------------------------------
# Figure 3: Problem Size Scaling
# ---------------------------------------------------------------------------
def plot_problem_scaling(rows: List[Dict], outdir: Path) -> None:
    """Bar chart: energy and cycles across all 6 problem sizes, INT8 only."""
    int8_rows = [r for r in rows if r["bitwidth"] == 8]
    problems = sorted(set(r["problem"] for r in int8_rows))

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5))

    x = np.arange(len(problems))
    width = 0.25

    for i, mac in enumerate([1, 3, 9]):
        energies = []
        cycles_list = []
        for prob in problems:
            match = [r for r in int8_rows if r["mac_count"] == mac and r["problem"] == prob]
            if match:
                energies.append(match[0]["energy_uj"])
                cycles_list.append(match[0]["cycles"])
            else:
                energies.append(0)
                cycles_list.append(0)

        ax1.bar(
            x + i * width, energies, width,
            label=f"{mac}-MAC", color=MAC_COLORS[mac], edgecolor="white", linewidth=0.5,
        )
        ax2.bar(
            x + i * width, cycles_list, width,
            label=f"{mac}-MAC", color=MAC_COLORS[mac], edgecolor="white", linewidth=0.5,
        )

    prob_labels = [PROBLEM_LABELS.get(p, p) for p in problems]
    for ax in (ax1, ax2):
        ax.set_xticks(x + width)
        ax.set_xticklabels(prob_labels, rotation=30, ha="right")
        ax.legend()

    ax1.set_ylabel("Energy per Inference (\u00b5J)")
    ax1.set_title("Energy vs. Problem Size (INT8)")
    ax2.set_ylabel("Latency (cycles)")
    ax2.set_title("Latency vs. Problem Size (INT8)")
    ax2.set_yscale("log")

    fig.tight_layout()
    _save(fig, outdir, "fig3_problem_scaling")


# ---------------------------------------------------------------------------
# Figure 4: Annotated Pareto Front — Selected FPGA Validation Configs
# ---------------------------------------------------------------------------
def plot_annotated_pareto(rows: List[Dict], outdir: Path) -> None:
    """Pareto front with 9 selected FPGA validation configs (3 MACs x 3 bitwidths)."""
    from matplotlib.lines import Line2D

    fig, ax = plt.subplots(figsize=(10, 6.5))

    # Plot all points as faded background
    for bw in sorted(set(r["bitwidth"] for r in rows)):
        for mac in sorted(set(r["mac_count"] for r in rows)):
            subset = [r for r in rows if r["mac_count"] == mac and r["bitwidth"] == bw]
            if not subset:
                continue
            x = [r["cycles"] for r in subset]
            y = [r["energy_uj"] for r in subset]
            ax.scatter(
                x, y,
                c=MAC_COLORS[mac],
                marker=BW_MARKERS[bw],
                s=30,
                alpha=0.2,
                edgecolors="none",
            )

    # Find selected FPGA configs
    selected_rows = []
    for sel in FPGA_SELECTED:
        match = [
            r for r in rows
            if r["mac_count"] == sel["mac_count"]
            and r["bitwidth"] == sel["bitwidth"]
            and r["problem"] == sel["problem"]
        ]
        if match:
            selected_rows.append(match[0])

    # Plot selected configs with large markers (color=MAC, shape=bitwidth)
    for r in selected_rows:
        ax.scatter(
            r["cycles"], r["energy_uj"],
            c=MAC_COLORS[r["mac_count"]],
            marker=BW_MARKERS[r["bitwidth"]],
            s=200,
            edgecolors="k",
            linewidths=1.5,
            zorder=10,
        )

    # Connect configs by bitwidth (shows MAC scaling at fixed bitwidth)
    for bw in [4, 8, 16]:
        bw_sel = sorted(
            [r for r in selected_rows if r["bitwidth"] == bw],
            key=lambda r: r["mac_count"],
        )
        if len(bw_sel) >= 2:
            sx = [r["cycles"] for r in bw_sel]
            sy = [r["energy_uj"] for r in bw_sel]
            ax.plot(sx, sy, color=BW_COLORS[bw], linestyle="--", linewidth=1.5,
                    alpha=0.6, zorder=5)

    # Connect configs by MAC count (shows bitwidth scaling at fixed parallelism)
    for mac in [1, 3, 9]:
        mac_sel = sorted(
            [r for r in selected_rows if r["mac_count"] == mac],
            key=lambda r: r["bitwidth"],
        )
        if len(mac_sel) >= 2:
            sx = [r["cycles"] for r in mac_sel]
            sy = [r["energy_uj"] for r in mac_sel]
            ax.plot(sx, sy, color=MAC_COLORS[mac], linestyle=":", linewidth=1.2,
                    alpha=0.5, zorder=5)

    ax.set_xlabel("Latency (cycles)")
    ax.set_ylabel("Energy per Inference (\u00b5J)")
    ax.set_title("Timeloop DSE \u2014 9 Configurations Selected for FPGA Validation")
    ax.set_xscale("log")
    ax.set_yscale("log")

    # Build legend: MAC colors, bitwidth shapes, connection lines
    legend_handles = []
    for mac in [1, 3, 9]:
        legend_handles.append(Line2D([0], [0], marker="o", color="w",
                                     markerfacecolor=MAC_COLORS[mac], markersize=10,
                                     label=f"{mac}-MAC"))
    legend_handles.append(Line2D([0], [0], color="none", label=""))  # spacer
    for bw in [4, 8, 16]:
        legend_handles.append(Line2D([0], [0], marker=BW_MARKERS[bw], color="w",
                                     markerfacecolor="gray", markersize=10,
                                     markeredgecolor="k", markeredgewidth=0.5,
                                     label=f"INT{bw}"))
    legend_handles.append(Line2D([0], [0], color="none", label=""))  # spacer
    legend_handles.append(Line2D([0], [0], linestyle="--", color="gray",
                                 linewidth=1.5, label="MAC scaling"))
    legend_handles.append(Line2D([0], [0], linestyle=":", color="gray",
                                 linewidth=1.2, label="Bitwidth scaling"))

    ax.legend(handles=legend_handles, loc="upper left", framealpha=0.9, ncol=1)

    fig.tight_layout()
    _save(fig, outdir, "fig4_annotated_pareto")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Plot Timeloop DSE results")
    parser.add_argument(
        "--csv",
        default="timeloop/results/timeloop_dse_full_sweep.csv",
        help="Path to the DSE sweep CSV",
    )
    parser.add_argument(
        "--outdir",
        default="results/figures",
        help="Output directory for figures",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    print(f"Loading {csv_path}...")
    rows = load_csv(csv_path)
    print(f"  {len(rows)} configurations loaded")
    print(f"  Bitwidths: {sorted(set(r['bitwidth'] for r in rows))}")
    print(f"  MAC counts: {sorted(set(r['mac_count'] for r in rows))}")
    print(f"  Problems: {sorted(set(r['problem'] for r in rows))}")
    print()

    print("Generating figures...")
    plot_energy_vs_latency(rows, outdir)
    plot_energy_breakdown(rows, outdir)
    plot_problem_scaling(rows, outdir)
    plot_annotated_pareto(rows, outdir)

    print()
    print(f"All figures saved to {outdir}/")


if __name__ == "__main__":
    main()
