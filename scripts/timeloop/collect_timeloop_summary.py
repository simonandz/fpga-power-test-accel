#!/usr/bin/env python3
"""
Collect summary metrics from Timeloop result directories into a single CSV.

Default behavior looks for the 1/3/9-MAC baseline runs:
  timeloop/results/1mac_16x16
  timeloop/results/3mac_16x16
  timeloop/results/9mac_16x16
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path
from typing import Dict, List, Optional


SUMMARY_PATTERNS = {
    "gflops_at_1ghz": re.compile(r"GFLOPs \(@1GHz\):\s*([0-9.]+)"),
    "utilization_pct": re.compile(r"Utilization:\s*([0-9.]+)%"),
    "cycles": re.compile(r"Cycles:\s*([0-9]+)"),
    "energy_uj": re.compile(r"Energy:\s*([0-9.]+)\s*uJ"),
    "area_mm2_summary": re.compile(r"Area:\s*([0-9.]+)\s*mm\^2"),
    "computes_total": re.compile(r"Computes\s*=\s*([0-9]+)"),
}

FJ_PATTERNS = {
    "fj_per_compute_mac": re.compile(r"^\s*mac\s*=\s*([0-9.]+)\s*$", re.MULTILINE),
    "fj_per_compute_global_buffer": re.compile(r"^\s*global_buffer\s*=\s*([0-9.]+)\s*$", re.MULTILINE),
    "fj_per_compute_ifmap_buffer": re.compile(r"^\s*ifmap_buffer\s*=\s*([0-9.]+)\s*$", re.MULTILINE),
    "fj_per_compute_weight_buffer": re.compile(r"^\s*weight_buffer\s*=\s*([0-9.]+)\s*$", re.MULTILINE),
    "fj_per_compute_ofmap_buffer": re.compile(r"^\s*ofmap_buffer\s*=\s*([0-9.]+)\s*$", re.MULTILINE),
    "fj_per_compute_dram": re.compile(r"^\s*DRAM\s*=\s*([0-9.]+)\s*$", re.MULTILINE),
    "fj_per_compute_total": re.compile(r"^\s*Total\s*=\s*([0-9.]+)\s*$", re.MULTILINE),
}

OI_PATTERNS = {
    "global_buffer_total_scalar_accesses": re.compile(
        r"=== global_buffer ===\s+Total scalar accesses\s*:\s*([0-9]+)", re.MULTILINE
    ),
    "global_buffer_op_per_byte": re.compile(
        r"=== global_buffer ===\s+Total scalar accesses\s*:\s*[0-9]+\s+Op per Byte\s*:\s*([0-9.]+)",
        re.MULTILINE,
    ),
    "ifmap_buffer_total_scalar_accesses": re.compile(
        r"=== ifmap_buffer ===\s+Total scalar accesses\s*:\s*([0-9]+)", re.MULTILINE
    ),
    "ifmap_buffer_op_per_byte": re.compile(
        r"=== ifmap_buffer ===\s+Total scalar accesses\s*:\s*[0-9]+\s+Op per Byte\s*:\s*([0-9.]+)",
        re.MULTILINE,
    ),
    "weight_buffer_total_scalar_accesses": re.compile(
        r"=== weight_buffer ===\s+Total scalar accesses\s*:\s*([0-9]+)", re.MULTILINE
    ),
    "weight_buffer_op_per_byte": re.compile(
        r"=== weight_buffer ===\s+Total scalar accesses\s*:\s*[0-9]+\s+Op per Byte\s*:\s*([0-9.]+)",
        re.MULTILINE,
    ),
    "ofmap_buffer_total_scalar_accesses": re.compile(
        r"=== ofmap_buffer ===\s+Total scalar accesses\s*:\s*([0-9]+)", re.MULTILINE
    ),
    "ofmap_buffer_op_per_byte": re.compile(
        r"=== ofmap_buffer ===\s+Total scalar accesses\s*:\s*[0-9]+\s+Op per Byte\s*:\s*([0-9.]+)",
        re.MULTILINE,
    ),
    "dram_total_scalar_accesses": re.compile(
        r"=== DRAM ===\s+Total scalar accesses\s*:\s*([0-9]+)", re.MULTILINE
    ),
    "dram_op_per_byte": re.compile(
        r"=== DRAM ===\s+Total scalar accesses\s*:\s*[0-9]+\s+Op per Byte\s*:\s*([0-9.]+)",
        re.MULTILINE,
    ),
}

LEVEL_AREA_PATTERNS = {
    "mac_area_um2_total": re.compile(r"=== mac ===.*?Area \(total\)\s*:\s*([0-9.]+)\s*um\^2", re.S),
    "global_buffer_area_um2": re.compile(r"=== global_buffer ===.*?Area\s*:\s*([0-9.]+)\s*um\^2", re.S),
    "ifmap_buffer_area_um2": re.compile(r"=== ifmap_buffer ===.*?Area\s*:\s*([0-9.]+)\s*um\^2", re.S),
    "weight_buffer_area_um2": re.compile(r"=== weight_buffer ===.*?Area\s*:\s*([0-9.]+)\s*um\^2", re.S),
    "ofmap_buffer_area_um2": re.compile(r"=== ofmap_buffer ===.*?Area\s*:\s*([0-9.]+)\s*um\^2", re.S),
}

MAP_LOOP_LINES = re.compile(r"^\|\s+for .+$", re.MULTILINE)


def _parse_number(text: str) -> int | float:
    return float(text) if "." in text else int(text)


def parse_stats(stats_path: Path) -> Dict[str, object]:
    text = stats_path.read_text(encoding="utf-8", errors="replace")
    out: Dict[str, object] = {}

    for key, pattern in SUMMARY_PATTERNS.items():
        m = pattern.search(text)
        if m:
            out[key] = _parse_number(m.group(1))

    for key, pattern in FJ_PATTERNS.items():
        m = pattern.search(text)
        if m:
            out[key] = float(m.group(1))

    # Use the Operational Intensity section (last occurrences in the file)
    oi_matches = {}
    for key, pattern in OI_PATTERNS.items():
        matches = list(pattern.finditer(text))
        if matches:
            oi_matches[key] = matches[-1].group(1)
    for key, val in oi_matches.items():
        out[key] = _parse_number(val)

    for key, pattern in LEVEL_AREA_PATTERNS.items():
        m = pattern.search(text)
        if m:
            out[key] = float(m.group(1))

    # Derived aggregates that work for both legacy single-buffer and newer split-buffer models.
    onchip_fj_keys = [
        "fj_per_compute_global_buffer",
        "fj_per_compute_ifmap_buffer",
        "fj_per_compute_weight_buffer",
        "fj_per_compute_ofmap_buffer",
    ]
    if any(k in out for k in onchip_fj_keys):
        out["fj_per_compute_onchip_buffers_total"] = sum(float(out[k]) for k in onchip_fj_keys if k in out)

    onchip_access_keys = [
        "global_buffer_total_scalar_accesses",
        "ifmap_buffer_total_scalar_accesses",
        "weight_buffer_total_scalar_accesses",
        "ofmap_buffer_total_scalar_accesses",
    ]
    if any(k in out for k in onchip_access_keys):
        out["onchip_buffers_total_scalar_accesses"] = sum(int(out[k]) for k in onchip_access_keys if k in out)

    onchip_area_keys = [
        "global_buffer_area_um2",
        "ifmap_buffer_area_um2",
        "weight_buffer_area_um2",
        "ofmap_buffer_area_um2",
    ]
    if any(k in out for k in onchip_area_keys):
        out["onchip_buffers_area_um2_total"] = sum(float(out[k]) for k in onchip_area_keys if k in out)

    return out


def _split_mapping_blocks(lines: List[str]) -> List[List[str]]:
    blocks: List[List[str]] = []
    current: List[str] = []
    for line in lines:
        if re.match(r"^\s*-\s*target:\s*", line):
            if current:
                blocks.append(current)
            current = [line]
        elif current:
            current.append(line)
    if current:
        blocks.append(current)
    return blocks


def _find_datatype_block(blocks: List[List[str]], target_name: str) -> Optional[List[str]]:
    for block in blocks:
        block_text = "\n".join(block)
        if f"target: {target_name}" in block_text and "type: datatype" in block_text:
            return block
    return None


def _parse_datatype_keep_bypass(block: List[str]) -> Dict[str, List[str]]:
    keep: List[str] = []
    bypass: List[str] = []
    current_list: Optional[str] = None
    for line in block:
        stripped = line.strip()
        if stripped.startswith("keep:"):
            current_list = "keep"
            continue
        if stripped.startswith("bypass:"):
            current_list = "bypass"
            continue
        item = re.match(r"^-\s*(\w+)$", stripped)
        if item and current_list:
            if current_list == "keep":
                keep.append(item.group(1))
            else:
                bypass.append(item.group(1))
        elif stripped and not stripped.startswith("- target:") and not stripped.startswith("type:"):
            # End list if we moved into another scalar field
            if not stripped.startswith("- "):
                current_list = None
    return {"keep": keep, "bypass": bypass}


def parse_map_yaml(map_yaml_path: Path) -> Dict[str, object]:
    lines = map_yaml_path.read_text(encoding="utf-8", errors="replace").splitlines()
    blocks = _split_mapping_blocks(lines)
    out: Dict[str, object] = {}

    # Legacy single-buffer model
    global_buffer_block = _find_datatype_block(blocks, "global_buffer")
    if global_buffer_block is not None:
        parsed = _parse_datatype_keep_bypass(global_buffer_block)
        keep = parsed["keep"]
        bypass = parsed["bypass"]
        out["global_buffer_keep_outputs"] = "Outputs" in keep
        out["global_buffer_bypass_outputs"] = "Outputs" in bypass
        out["global_buffer_keep_list"] = "|".join(keep)
        out["global_buffer_bypass_list"] = "|".join(bypass)

    # Split-buffer model (proper fix)
    for target in ("ifmap_buffer", "weight_buffer", "ofmap_buffer"):
        block = _find_datatype_block(blocks, target)
        if block is None:
            continue
        parsed = _parse_datatype_keep_bypass(block)
        keep = parsed["keep"]
        bypass = parsed["bypass"]
        prefix = target
        out[f"{prefix}_keep_outputs"] = "Outputs" in keep
        out[f"{prefix}_bypass_outputs"] = "Outputs" in bypass
        out[f"{prefix}_keep_list"] = "|".join(keep)
        out[f"{prefix}_bypass_list"] = "|".join(bypass)

    return out


def parse_map_txt(map_txt_path: Path) -> Dict[str, object]:
    text = map_txt_path.read_text(encoding="utf-8", errors="replace")
    loops = MAP_LOOP_LINES.findall(text)
    out: Dict[str, object] = {}
    if loops:
        out["map_loop_nest"] = " ; ".join(l.strip().lstrip("|").strip() for l in loops)
    return out


def detect_config_from_dir(result_dir: Path) -> str:
    name = result_dir.name
    if name.startswith("1mac_"):
        return "1mac"
    if name.startswith("3mac_"):
        return "3mac"
    if name.startswith("9mac_"):
        return "9mac"
    return name


def collect_row(result_dir: Path) -> Dict[str, object]:
    stats_path = result_dir / "timeloop-mapper.stats.txt"
    map_yaml_path = result_dir / "timeloop-mapper.map.yaml"
    map_txt_path = result_dir / "timeloop-mapper.map.txt"

    if not stats_path.exists():
        raise FileNotFoundError(f"Missing {stats_path}")

    row: Dict[str, object] = {
        "config": detect_config_from_dir(result_dir),
        "result_dir": str(result_dir).replace("\\", "/"),
    }
    row.update(parse_stats(stats_path))
    if map_yaml_path.exists():
        row.update(parse_map_yaml(map_yaml_path))
    if map_txt_path.exists():
        row.update(parse_map_txt(map_txt_path))
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "result_dirs",
        nargs="*",
        help="Timeloop result directories to include. Defaults to timeloop/results/{1,3,9}mac_16x16",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="timeloop/results/timeloop_summary_1_3_9mac_16x16.csv",
        help="Output CSV path",
    )
    args = parser.parse_args()

    if args.result_dirs:
        result_dirs = [Path(p) for p in args.result_dirs]
    else:
        result_dirs = [
            Path("timeloop/results/1mac_16x16"),
            Path("timeloop/results/3mac_16x16"),
            Path("timeloop/results/9mac_16x16"),
        ]

    rows = [collect_row(p) for p in result_dirs]
    rows.sort(key=lambda r: str(r.get("config", "")))

    # Stable column order for easy spreadsheet import.
    preferred_columns = [
        "config",
        "result_dir",
        "gflops_at_1ghz",
        "utilization_pct",
        "cycles",
        "energy_uj",
        "computes_total",
        "fj_per_compute_total",
        "fj_per_compute_mac",
        "fj_per_compute_global_buffer",
        "fj_per_compute_ifmap_buffer",
        "fj_per_compute_weight_buffer",
        "fj_per_compute_ofmap_buffer",
        "fj_per_compute_onchip_buffers_total",
        "fj_per_compute_dram",
        "global_buffer_total_scalar_accesses",
        "ifmap_buffer_total_scalar_accesses",
        "weight_buffer_total_scalar_accesses",
        "ofmap_buffer_total_scalar_accesses",
        "onchip_buffers_total_scalar_accesses",
        "dram_total_scalar_accesses",
        "global_buffer_op_per_byte",
        "ifmap_buffer_op_per_byte",
        "weight_buffer_op_per_byte",
        "ofmap_buffer_op_per_byte",
        "dram_op_per_byte",
        "mac_area_um2_total",
        "global_buffer_area_um2",
        "ifmap_buffer_area_um2",
        "weight_buffer_area_um2",
        "ofmap_buffer_area_um2",
        "onchip_buffers_area_um2_total",
        "area_mm2_summary",
        "global_buffer_keep_outputs",
        "global_buffer_bypass_outputs",
        "global_buffer_keep_list",
        "global_buffer_bypass_list",
        "ofmap_buffer_keep_outputs",
        "ofmap_buffer_bypass_outputs",
        "ofmap_buffer_keep_list",
        "ofmap_buffer_bypass_list",
        "map_loop_nest",
    ]
    extra_columns = sorted({k for row in rows for k in row.keys()} - set(preferred_columns))
    fieldnames = preferred_columns + extra_columns

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {output_path} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
